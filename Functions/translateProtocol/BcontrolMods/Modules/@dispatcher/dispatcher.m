% [obj, ret2] = dispatcher({'init'}, {'empty'}, {'runstart_enable'}, {'runstart_disable}, ...
%                    {'close_protocol'}, {'set_protocol}, ...
%                    {'get_state_machine | getstatemachine'}, {'get_sound_machine' | 'getsoundmachine'}, ...
%                    {'send_assembler', sma}, {'send_statenames', cellstr})
%
%
% Dispatcher serves as a central gateway between Matlab code and the
% RTLinux server. It allows opening and closing protocols, starts and
% stops running the State Machine, and coordinates interaction between the
% protocol code and the State Machine. 
%
% In terms of interaction between the protocol and the State Machine,
% dispatcher receives StateMachineAssembler objects from the protocol;
% assembles and sends them to the State Machine; and from the State
% Machine, dispatcher gets raw (numerically encoded) events, which it
% parses and patches together into trials. The parsed information then gets
% passed back to the protocol.
%
% For information on writing a protocol that works with dispatcher, see
% @dispatcher/howto.txt. 
%
% OPTIONAL PARAMETERS:
% --------------------
%
% none         If called with no parameters, dispatcher returns an empty
%              object of class 'dispatcher'.
%
% 'empty'      If called with the string 'empty' as its single parameter,
%              dispatcher returns an empty object of class 'dispatcher'.
%
% 'init'       If passed this string as single parameter, dispatcher closes
%              out any previous instances of dispatcher, and initializes a
%              dispatcher window.
%
% 'runstart_disable'   Disables the "run" button. This is called by default
%             called before a new protocol is started; when the protocol
%             finshes loading, dispatcher('runstart_enable') is called.
%             That way users can't start a protocol while it is only
%             half-built.
%
% 'runstart_enable'   Enables the "run" button.
%
% 'run'         Starts execution of the loaded protocol.
%
% 'stop'        Pauses the state machine.
%
% 'close_protocol'  Can be used as a command-line way of closing the
%             current protocol, i.e., call >> dispatcher('close_protocol');
%
% 'set_protocol' protname   The second arg, protname, must be a string
%             that is part of the current list of protocols. If it is such
%             a name, then the current protocol (if any is open) is closed,
%             and the protocol "protname" is opened.
%
% 'rescan_protocols'   Rereads the list of protocols found in Protocols/
%
% 'restart_protocol'   If a protocol is open, closes it, then reopens it.
%
% 'get_protocol_list'  Returns a cell column vector, each entry of which is
%             one of the currently existing protocols.
%
% 'get_protocol_object'  Returns an object of the same class as the
%             currently open protocol object. If no protocol is open,
%             returns an empty string.
%
% 'send_assembler' sma        The second arg, sma, must be a
%             StateMachineAssembler object. This will be assembled, send to
%             the State Machine Server, and the ReadyToStartTrial flag will
%             be set on the server.
%
% 'get_time'  Returns the current time, as last measured from the State
%             Machine.
% 
% 'set_trialnum_indicator_flag'   After this call,
%             @StateMachineAssembler/add_trialnum_indicator.m will be run
%             on every StateMachineAssembler before it is actually sent to
%             the RTLSM. This code modifies the state diagram so that
%             immediately after state_0, a time sync signal and a signal
%             indicating the current trial number are sent out a DIO line.
%             The DIO line to be used is defined using the Settings.m
%             system-- the setting is called "DIOLINES; trialnum_indicator;"
%             See @StateMachineAssembler/add_trialnum_indicator.m for
%             details.  Can only be used with StateMachineAssemblers which
%             were initialised with the 'full_trial_structure' flag.
%
% 'unset_trialnum_indicator_flag'   After this call, no trialnum indicator
%             sequence will be added -- i.e., opposite of
%             'set_trialnum_indicator_flag'.
%
% 'disassemble' trialnums    Runs the step-by-step disassembler on the
%             history of trials and state machines. Needs an extra
%             PARAMETER, trialnums, which must be a numeric vector of integers, 
%             indicating which trials are to be disassembled. E.g., [1:4]
%             means trials one through four. [1 5] means only trials one
%             and five, etc.
%
% 'toggle_bypass' Given a bypass channel number (e.g. 1,2,3,4,5...) or an
%                 array of bypass channel numbers, toggles those bypass
%                 lines to their opposite setting (on to off, off to on).


% Written by Carlos Brody May 2007
% modifications by various authors


function [obj, ret2] = dispatcher(varargin)

obj = class(struct, mfilename);
if nargin==0 || nargin==1 && ischar(varargin{1}) && strcmp(varargin{1}, 'empty'),
  return;
end;


GetSoloFunctionArgs;

if nargin==1 && ischar(varargin{1}) && strcmp(varargin{1}, 'init'),
   
	v=version;
	v=str2double(v(1:3));
	if v>=7.4
		rand('twister',bitand(round(now*1E10),2^16-1));
	else
		rand('state',bitand(round(now*1E10),2^16-1));
	end
	
	randn('state', bitand(round(now*1E10),2^16-1));
	
  if exist('myfig', 'var'),
    if isa(myfig, 'SoloParamHandle') && ishandle(value(myfig)), delete(value(myfig)); end;
  end;
  if exist('state_machine', 'var'), try Close(value(state_machine)), catch end; end;
  if exist('sound_machine', 'var'), try Close(value(sound_machine)), catch end; end;
  delete_sphandle('owner', ['^@', mfilename '$']);
  
  SoloParamHandle(obj, 'myfig', ...
      'value', figure('Position', [100 100 405 515], 'Name', 'dispatcher'));
  

      
  set(value(myfig), 'CloseRequestFcn', 'dispatcher(''close'')');
  
  MachinesSection(obj, 'init');
  
  % --- Setting up the figure:
  x = 5; y= 15; figure(value(myfig));
 
  [x, y] = feval(mfilename, 'init_bypass', x, y); %     Initialize the bypass buttons (moved down to make init tidy).
   
  [x, y] = RunningSection(obj, 'init', x, y);
  
  [x, y] = ProtocolsSection(obj, 'init', x, y);
  
  HeaderParam(obj,'bypass_header','Dispatcher', x,y, 'position', [x y+8 396 20]);
  
  %JPL - if doing protocol translation, hide the dispatcher
  if ~isempty(BpodSystem.ProtocolTranslation)
    set(value(myfig), 'Visible', 'off');
  end
  
  return;
end;

if nargin>=2 && isa(varargin{1}, class(obj)), action = varargin{2}; varargin = varargin(3:end);
else                                          action = varargin{1}; varargin = varargin(2:end);
end;

switch action,
  
   %     If we are running with timers, the timer calls this case on each
   %       timer event. Herein is the code run on every update cycle.
  case {'update'},
    RunningSection(obj, 'update');

    % --- GENERAL  ----
  case 'close'
    ProtocolsSection(obj, 'close_protocol');
    MachinesSection(obj, 'close');
    RunningSection(obj, 'close');
    delete(value(myfig));
    delete_sphandle('owner', ['^@', mfilename '$']);
    obj = [];
    
    % --- MACHINES ----
  case {'get_sound_machine' 'getsoundmachine', 'get_state_machine' 'getstatemachine'},
    obj = MachinesSection(obj, action);    
  case 'send_statenames', % ----- send_state_names ----
    MachinesSection(obj, action, varargin{1});
  case {'set_trialnum_indicator_flag', 'unset_trialnum_indicator_flag'},
    MachinesSection(obj, action);

  case 'send_assembler', % ----- send_assembler ----
    if length(varargin)==1,     [obj, ret2] = MachinesSection(obj, action, varargin{1});
    elseif length(varargin)==2, [obj, ret2] = MachinesSection(obj, action, varargin{1}, varargin{2});
    else error('The send_assembler action requires a state machine assembler object and, optionally, a set of states that will compose the prepare_next_trial state set. The call should look like this: ''dispatcher(''send_assembler'',<<sma object here>>,<<optional cell array of strings specifying the prepare_next_trial states>>);');
    end;

  case 'repeat_trial', % ----- send_assembler ----
        if numel(varargin)==0
        [obj, ret2] = MachinesSection(obj, action);
        else
            error('repeat_trial does not take any arguments');
        end
        
    
    % --- RUNNING ---
  case {'runstart_enable', 'runstart_disable', 'Run', 'Stop'}, 
    RunningSection(obj, action);
  case {'get_time', 'is_running'},
    obj = RunningSection(obj, action);
  case 'disassemble',
    RunningSection(obj, action, varargin{1});
    
    
    % --- PROTOCOLS ---
  case {'close_protocol' 'rescan_protocols' 'restart_protocol'},   
      ProtocolsSection(obj, action);
  case {'set_protocol'},   
      ProtocolsSection(obj, action, varargin{1});
  case {'get_protocol_list' 'get_protocol_object'} 
    obj = ProtocolsSection(obj, action);

    
    
    
  case 'init_bypass',
      %     -------------------------------------------------------------
      %     -------  OUTPUT LINE BYPASS - VARIABLE AND GUI ELEMENTS
      %     -------------------------------------------------------------
      %     This is part of the init process, but it was very long, so it
      %       was moved down and out of the way.
      
      if length(varargin)~=2,
          error('Wrong number of args. Need x and y after init_bypass.');
      end;
      
      x = varargin{1}; %     Note that the first arg (action) was already shifted off the arg list.
      y = varargin{2};

      %     A variable to store the total Bypass bitfield.
      SoloParamHandle(obj,'DOut_Bypass_Bitfield','value',0, 'saveable', 0);
      %     Give the recalculate function rw access to it as an argument.
      SoloFunctionAddVars('RecalculateBypass','rw_args','DOut_Bypass_Bitfield');

      %     Gather the names (and IDs) of the output channels.
      [unsorted_channels errID] = bSettings('get','DIOLINES', 'all');
      if errID,
          error(['In Dispatcher, request for DIOLINES group has failed with bSettings(''get'',''DIOLINES'',''all'') returning error ID ' int2str(errID) ' and error message: ' errmsg]);
      end;
      %     EXAMPLE output_channels (cell matrix):
      %     'right1water'       [16]    'DIOLINES'
      %     'center1water'      [1]     'DIOLINES'
      %     'left1water'        [4]     'DIOLINES'
      %     'left1led'          [8]     'DIOLINES'
      %     'center1led'        [2]     'DIOLINES'
      %     'right1led'         [NaN]   'DIOLINES'
      %    etc...

      %     temp variables for sorting and counting
      num_channels	= length(unsorted_channels);
      %     DO NOT PREALLOCATE variable "channels" to length num_channels
      %       (because it may be smaller, and we need to use its size -
      %       see below).
      chan_vals     = zeros(num_channels,1);	%temp var for the channel values (2^channel_id).
      channels      = {};                       %temp var for sorted channels (col1: chan #, col2: chan name)


      %     ~~~~~ Second, we sort the channels by their channel number. ~~~~~
      %     Extract the channel number column (col 2) of output_channels.
      for i = 1:num_channels,
          chan_vals(i,1) = unsorted_channels{i,2};
      end;


      %     Find out what order the channels would be in if sorted.
      [trash sorted_indices] = sort(chan_vals);

      %     Arrange the channels in a new matrix, sorted in order of channel ID
      %       (bitfield position), and labeled with bitfield position (chan #)
      %       (0,1,2,3,...) instead of bitfield value (1,2,4,6,...).
      %     We skip channels with NaN as their channel ID. These channels are
      %       not tied to channel IDs, and so are not used by the Real-Time
      %       State machine we're running on this machine.
      j = 1;
      for i = 1:num_channels,
          cVal  = unsorted_channels{sorted_indices(i),2};
          cName = unsorted_channels{sorted_indices(i),1};
          if isnumeric(cVal) && ~isnan(cVal),
              cNum = log2(cVal);
              channels{j,1} = cNum;
              channels{j,2} = cName;
              j = j + 1;
          end;
      end;
      clear j;

      %     After excluding output channels not tied to channel IDs (not used
      %       by the Real-Time State Machine), we may have fewer channels, and
      %       so need fewer toggles.
      num_channels = size(channels,1);


      %     EXAMPLE sorted_channels (cell matrix):
      %     [0]     'center1water'
      %     [1]     'center1led'
      %     [2]     'left1water'
      %     [3]     'left1led'
      %     [4]     'right1water'
      %     [5]     'right1led'
      %    etc...

      %     ~~~~~ Third, we set positions ~~~~~
      %     We're going to use two columns of buttons.
      y_bottom	= y;                                        % bottom of box
      y_bh      = 20;                                       % button height
      y_rh      = 21;                                       % button+spacing height
      y_start	= y_bottom + y_rh*ceil(num_channels/2);    % starting pos y
      x_left	= x+44;                                     % starting pos x
      x_bw      = 155;                                      % button width
      x_cw      = 156;                                      % button+spacing width
      x_right	= x_left + x_cw;                            % 2nd col start x
      %     Positions for the banner at the top.
      x_banner      = x_left;
      y_banner      = y_start + y_rh + 1;
      x_banner_w	= 280;
      y_banner_h	= 20;
      %     Values to set x and y to after we're done with all the toggles.
      y_after	= y_banner + y_banner_h + 10;
      x_after	= x;
      %     Set x and y to starting positions for the top of the first column.
      y = y_start;
      x = x_left;
      %     temp variables for SoloParamHandles
      toggle_handles	= cell(num_channels,1);	%stores handles of toggles for callback assignment after gui element creation
      toggle_names      = cell(num_channels,1);    %stores names of toggles for privilege assignment after gui element creation

      %     ~~~~~ Fourth, we produce the actual GUI elements. ~~~~~
      %     Iterate over all the output channels, producing GUI elements in two
      %       columns.
      for i = 1:num_channels,
          cNum      = channels{i,1};        % channel number (position in bitfield, 0 and up)
          cName     = channels{i,2};        % channel name (e.g. 'left1water')
          cNum_Char	= int2str(cNum);        % channel number as a character

          position = [x y x_bw y_bh];
          toggle_names{i}	= ['override_output' cNum_Char];
          toggle_handles{i}	= ToggleParam(obj, toggle_names{i}, 0, x, y,    ...
              'position',           position,                               ...
              'OnString',       [cNum_Char ':' cName ' MANUALLY ON'],       ...
              'OffString',      [cNum_Char ':' cName ' unconstrained'],     ...
              'TooltipString','Press the  ?  above for help.');

          if i == ceil(num_channels/2),     % next column?
              y = y_start;
              x = x_right;
          else
              y = y - y_rh;                 % else move up
          end;

      end; %end for all output channels

      %     Assign buttonpress callback action to the toggles that recalculates
      %       the bitfield that overrides output control, and assign read
      %       access to the function that does this.
      set_callback(toggle_handles, {'RecalculateBypass'});
      SoloFunctionAddVars('RecalculateBypass','ro_args',toggle_names)


      SubheaderParam(obj,'bypassbanner','Manually Activate Output Lines', x, y, ...
          'position', [x_banner, y_banner, x_banner_w, y_banner_h], ...
          'BackgroundColor', [0.4 0.3 0.7], ...
          'TooltipString','activates an this output regardless of current state');

      PushbuttonParam(obj,'bypasshelp',x,y,'label','?','position',[x_banner+x_banner_w+2,y_banner,27,y_banner_h]);
      set_callback(bypasshelp, {mfilename,'help_bypass'});

      y = y_after;
      x = x_after;
      obj = x;  %     dispatcher returns [obj, ret2]. In this case, they're
      ret2 = y; %       holding x and y.... I know it's strange.

  % end of case init_bypass
    
  
    case 'help_bypass',
        helpstring = sprintf([ ...
            'When one of these toggles is turned on (depressed),\n'...
            'the corresponding output line (e.g. water valve, light, ...)\n', ...
            'is turned on REGARDLESS of its normal value in the current state.\n', ...
            'Toggling one of these off SHOULD only release the output line to\n', ...
            'behave as normal for the current state, not necessarily turn the\n', ...
            'output line off. Unfortunately, it appears that this feature has\n', ...
            'always been broken, and toggling bypass off actually turns off the\n', ...
            'channel.']);
        helpdlg(helpstring,'Bypass Buttons Help');
        % end of case help_bypass
        
    case 'toggle_bypass',
        error(nargchk(2,2,nargin));

        %     If dispatcher was not yet initialized, just return.
        if ~exist('myfig', 'var'),
            display(' ');
            display('     Dispatcher is not running! Can''t toggle.');
            display(' ');
            return;
        end;
        
        %     Toggle each specified output channel's button in turn.
        for i=varargin{1},
            output = ['override_output' int2str(i)];
            eval([output '.value = ~value(' output ');']);
        end;
        
        %     Communicate the toggling to the underlying hardware.
        RecalculateBypass(obj);
        
        % end of case toggle_bypass

  otherwise
    warning('Unknown action "%s" !', action); %#ok<WNTAG> (line OK)
end;

end  %end function

