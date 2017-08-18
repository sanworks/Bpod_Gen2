%sm = StartDAQ(sm, vector_of_chan_ids, optional_preferred_range_vector)
%
%                SUMMARY: 
%
%                Specify a set of channels for analog data
%                acquisition, and start the acquisition.
%
%                Pass a vector of channel id's which is the set of
%                analog input channels that should appear in each scan.
%                
%                For the purposes of this function, channel id's are
%                indexed from 1.
%
%                RANGE SETTINGS:
%
%                Optionally, there is support for specifying a
%                preferred analog input range (gain) setting for the
%                DAQ card.  This parameter is a vector of the form
%                [minV, maxV] where minV and maxV are the minimum and
%                maximum values of the analog input range desired.
%                It defaults to [0, 5].  For a 0-5V range.
%                
%                Note that the actual set of analog input ranges that
%                are supported is DAQ card-specific.  There is no
%                guarantee that the specified range can be satisfied,
%                since the card may not actually support the specified
%                range.  Additionally, there is a further restriction
%                to range settings: They cannot conflict with the
%                state machine input channel ranges.  State machine
%                input channels always use the implicit range setting
%                of [0,5], and so if you happen to be using 'ai' input
%                channels (see the SetInputEvents function
%                documentation), and you are using a particular
%                channel for both input events and data acquisition,
%                *and* if your range vector specifies a range other
%                than [0,5], the call to StartDAQ() will fail with an
%                error.
%
%                ACQUISITION SCAN RATE:
%
%                The scan rate (sampling rate) for the data
%                acquisition is the same as the clock rate of the FSM,
%                which actually depends on how the FSM kernel module
%                was loaded into the RTLinux kernel.  As a
%                consequence, it is not possible to change the scan
%                rate from Matlab at this time.
%                
%                NOTES:
%
%                The FSM supports data acquisition by reading a set of
%                Analog Input channels from the DAQ hardware and
%                buffering them as a set of scans.  You need to
%                periodically call 'GetDAQScans()' which empties this
%                buffer and returns a matrix of doubles which are the
%                voltages read from the DAQ hardware.  This matrix is
%                M by N where M corresponds to the number of scans in
%                the buffer since the last call to GetDAQScans() and N
%                1 plus the number of channels in each scan (first
%                column is timestamp in seconds which is the same
%                timestamp returned by the statemachine's
%                GetEvents() function).  Note that the order of the
%                channels in each scan is sorted by channel id (so that if
%                you specified [1,5,3] as your channel spec, you will get
%                them in the order of [1,3,5].
%
%                Since the scans are kept in a finitely-sized buffer,
%                you should call GetDAQScans() relatively frequently
%                to ensure you don't have any dropped scans due to
%                buffer overflows.
%
%                EXAMPLES:
%
%                If you want to capture channels 1, 3, and 8 (in
%                that order) using the default range setting of [0,
%                5] you would specify:
%
%                sm = StartDAQ(sm, [1, 3, 8]);
%
%
%                To capture channels 1,2,3 using [-5,5] as the
%                range setting you would specify:
%
%                sm = StartDAQ(sm, [1, 2, 3], [-5, 5])
%
%                To retreive the acquired data, later call:
%
%                scans = GetDAQScans(sm);
%
function sm = StartDAQ(varargin)

    if (nargin < 2 | nargin > 3),
      error(['Usage: StartDAQ(fsm, 1xN_vector,' ...
             ' optional_range_spec)']);
    end;
    
    sm = varargin{1};
    chans = varargin{2};
    range = [0, 5];
    if (nargin == 3),
      % For now, we don't support changing the range setting yet...
      error(sprintf('Sorry, *UNIMPLEMENTED*\nFor now, StartDAQ doesn''t support custom range settings!'));
      % not reached..
      range = varargin{3};
    end;
    
    if (~isa(chans, 'double') | size(chans, 1) ~= 1),
      error(['Chans should be a 1xN vector of integral real values.']);
    end;
    
    if (~isa(range, 'double') | size(range, 1) ~= 1 | size(range, 2) ~= 2),
      error(['Range spec should be a 1x2 vector.']);
    end;
    
    chans = chans - 1; % reindex channels at 0!
    
    chans_str = '';
    for i=1:size(chans,2),
      comma=''; if(i > 1), comma=','; end;
      chans_str = sprintf('%s%s%d', chans_str, comma, chans(i));     
    end;
    range_str = '';
    for i=1:size(range,2), 
      comma=''; if(i > 1), comma=','; end;
      range_str = sprintf('%s%s%d', range_str, comma, range(i));     
    end;
    
    [res] = FSMClient('sendstring', sm.handle, ...
                      sprintf('START DAQ %s %s\n', chans_str, range_str));
    try 
        ReceiveOK(sm, 'START DAQ');
    catch
        error(sprintf('StartDAQ command failed -- the FSM returned an error status.\nPossible source of error:\n - an invalid channel or range is specified\n - the FSM version is too old to support DAQ.'));
    end;
    return;
    
    