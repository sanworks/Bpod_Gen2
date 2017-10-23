% fsm = SetOutputRouting(fsm, routing)
%                Modify the output routing for a state machine.
%                Output routing is the specification that the state
%                machine uses for doing output when a new state is
%                entered.  Using this call, you can specify the
%                precise number and meaning of the last few columns of
%                the state machine (which are typically output
%                columns).  New output routings take effect after the
%                next call to SetStateMatrix.
%
%                The format for the output routing is an ordered (M x
%                1) cell array of structs.  The structs correspond to
%                columns at the end of the state matrix.  Each struct
%                needs to have the following fields: 'type' and
%                'data'.  'data' is interpreted in such a way as to
%                depend on the 'type' field.  The default output
%                routing for a new state machine object is the
%                following:
%
%                { struct('type', 'dout', ...
%                         'data', '0-15') ; ...
%                  struct('type', 'sound', ...
%                         'data', sprintf('%d', fsm.fsm_id)) };
%
%                Which means that the last two columns of the state
%                machine are to be used for 'dout' and 'sound'
%                respectively.  The 'dout' column is to write data to DIO
%                lines 0-15 on the DAQ card, and 'sound' column is to trigger
%                soundfiles to be played.
%
%                OUTPUT ROUTING TYPES:
%
%                'dout' -  The state machine writes the bitpattern
%                          (of the number converted to UINT32)
%                          appearing in this column to DIO lines.
%                          Each bit in this number corresponds to a
%                          DIO line.  0 means all low (off), 1 means
%                          the first line is high (the rest are off),
%                          2 the second is high, 3 the first *two* are
%                          high, etc.  The 'data' field of the struct
%                          indicates which channels to use. The
%                          example above has '0-15' in the data
%                          filed meaning use 16 channels from
%                          channel 0-15 inclusive.
%                          
%                'trig' -  Identical to the 'dout' type above, however
%                          the 'trig' type uses a TTL pulse that stays
%                          on for 1 ms and then automatically turns
%                          off.  So for instance where a 'dout' output
%                          of '1' would turn channel 0 on indefinitely
%                          (until explicitly turned off by a different
%                          state with that bit cleared) a 'trig'
%                          output of '1' would always issue a 1ms TTL
%                          pulse on the first channel (automatically
%                          setting that channel low after 1 ms of time
%                          has elapsed).
%
%                'sound' - The state machine triggers a sound file
%                          to play by communicating with the
%                          RT-SoundMachine and giving it the number
%                          appearing in this column as a sound id to
%                          trigger.  Note that sounds can be
%                          untriggered by using a negative number for
%                          the sound id.
%
%                          The 'data' field is a number string and
%                          specifies which sound card to use.
%                          Default is the same number as the fsm_id
%                          at RTLSM2 object creation.  Note: when
%                          changing FSM id via SetStateMachine.m, be
%                          sure to update this number!
%                          Note that 'sound' is implemented using 'ext' 
%                          so the two may not be used at the same time!
%
%                'ext'   - The state machine triggers an external module.
%                          By calling its function pointer.  See
%                          include/FSMExternalTrig.h and kernel/fsm.c.  
%                          Note that 'sound' is implemented using 'ext' 
%                          so the two may not be used at the same time!
%
%                'sched_wave' -
%                          The state machine uses this column to
%                          trigger a scheduled wave (analog or
%                          digital sched wave).  The 'data' field
%                          of the struct is ignored.
%
%                  'tcp' - The state machine uses this column to
%                          trigger a TCP message to be sent in
%                          soft-realtime using regular linux
%                          networking services.  The 'data' field
%                          should be of the form: 'host:port:My data
%                          packet %v' Where host is the hostname to
%                          contact via TCP, port is the port number of
%                          the host, and the last field is an
%                          arbitrary text string to be sent to the
%                          host (a trailing newline is automatically
%                          appended if missing).
%
%                          The %v format specifier tells the state
%                          machine to place the number from the state
%                          machine column (value) in this %v
%                          position.  In this way it is possible to
%                          tell some external host *what* the state
%                          machine column contained (for example to
%                          trigger some external device on the
%                          network, etc).  Note that the TCP packet is
%                          only sent when the output value *changes*.
%                          This way you don't always get a TCP packet
%                          being sent for all of your state matrix
%                          states -- you only get 1 TCP packet sent
%                          for each change in value of this column.
%                          
%                          Note about 'tcp': This mechanism is useful
%                          for triggering the olfactometer.  You can
%                          use the following format to trigger an
%                          external olfactometer (at eg IP address
%                          143.48.30.39) to switch odors during the
%                          course of an experiment trial:
%
%                          struct('type', 'tcp', ...
%                                 'data', '143.48.30.39:3336:SET ODOR Bank1 %v');
%
%                          Thus, for this state machine column,
%                          whenever it changes value a TCP
%                          message will be sent to 143.48.30.39 on
%                          port 3336 (the olfactometer port) with
%                          the olfactometer command SET ODOR Bank1
%                          %v where %v is the value of the state
%                          matrix entry that triggered the output.
%                       
%                          NOTE: A new connection is initiated each
%                          time a TCP message is sent, and then it
%                          is immediately closed when the message
%                          is finished sending.  There is no way
%                          to know from Matlab if the connection
%                          failed.  One must instead check the
%                          console log on the Linux FSM Server.
%
%                          NOTE2: in addition to the state machine
%                          column value being placed whenever a %v
%                          is encountered in the string, the
%                          following other % format codes are also
%                          interpreted:
%
%                          %t - Timestamp_seconds (a floating point number)
%                          %T - Timestamp_nanos  (a fixed point integer)
%                          %s - State machine state (a fixed point integer)
%                          %c - State machine column(a fixed point integer)
%                          %% - Literal '%' character
%                          (Every other %-code gets consumed and
%                          produces no output).
%
%                          Examples:
%
%                          Input string to 'data' field of struct:
%
%                          '143.48.30.39:3336:The timestamp was %t seconds (%T nanoseconds) for state %s, col %c the value was %v.'
%       
%                           Sends (to port 3336 at IP 143.48.30.39): 
%
%                          'The timestamp was 25.6 seconds (2560000000 nanoseconds) for state 10, col 1 the value was 13.'
%
%                          
%
%                  'udp' - Identical to 'tcp' above but the
%                          protocol used is UDP (a less reliable but
%                          faster connectionless version of TCP). UDP
%                          doesn't work for olfactometers, though. It
%                          is only useful for network servers
%                          that support UDP, and is implemented
%                          here for completeness.
%
%               'noop'   - The state machine column is to be
%                          ignored, it is just a placeholder.  This
%                          defines a state machine column as
%                          existing, but it is never used for
%                          anything other than to take up space in
%                          the state matrix.
function [fsm] = SetOutputRouting(fsm, routing)
    if (~isa(routing, 'cell') | size(routing, 2) ~= 1),
      error('Arg 2 needs to be an Mx1 cell array');
    end;
    for i = 1:size(routing,1),      
      s = routing{i};
      if (~isa(s, 'struct') || ~isfield(s, 'type') || ~isfield(s, 'data')),
        error(['Arg 2 needs to contain only structs with two fields:' ...
               '''type'' and ''data''']);
      end;
      % make type be all lowercase
      routing{i}.type = lower(s.type);
      s = routing{i};
      extct = 0;
      switch(s.type)
       case { 'dout', 'trig' }
        rng = sscanf(s.data, '%d-%d',2);
        if (isempty(rng)), 
          error(sprintf(['%s .data field seems to be improperly formatted'], ...
                        s.type));
        end;
        if (length(rng) == 1),
            first = floor(rng);
            last = floor(rng);
            routing{i}.data = sprintf('%d-%d', first, last); % reformat it since server expects string of the form A-B
        else
            first = floor(rng(1));
            last = floor(rng(2));
        end;
        if ( first < 0 || first > last || last > 31),
          error(sprintf(['%s .data field needs two non-negative integers ' ...
                         'with the first being less than the second and ' ...
                         ' the second being less than 32!'], s.type));
        end;
       case 'sound'
         % Server protocol expects 'ext' instead of 'sound' here..
      %   warning(sprintf('The FSM now expects ''ext'' as the output routing type for sound triggering --  ''sound'' is still supported but is deprecated.\nPlease change the calling code to say ''ext'' instead of ''sound'''));
         s.type = 'ext';
         routing{i} = s; % re-save translated type to the routing spec
         extct = extct + 1;
       case 'ext'
         extct = extct + 1;
       case 'sched_wave'
       case 'noop'
       case { 'tcp', 'udp' }
        r=s.data; 
        try
          [host,r] = strtok(r,':');
          [port,r] = strtok(r, ':');
          port = str2num(port);
          txt = r(2:size(r,2));
%          disp(sprintf(['DEBUG: got %s routing: host: %s port: %d text:' ...
%                        ' %s\n'], upper(s.type), host, port, txt));
        catch
          error('tcp .data field appears to be invalid.');
        end;
        if (isempty(port) | isempty(txt) | isempty(host)),
          error('tcp .data field appears to be invalid.');
        end;
       otherwise
        error(sprintf('Unknown output type: %s', s.type));
      end;
    end;
    if (extct > 1),
        error(sprintf('Cannot use this output routing spec as type ''ext'' appears %d times!  For now, only 1 ''ext'' trigger per state is allowed.', extct));
    end;
    fsm.output_routing = routing;
