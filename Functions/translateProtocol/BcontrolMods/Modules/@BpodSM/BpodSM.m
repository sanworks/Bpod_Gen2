% function [sm] = RTLSM2(host,port,which_sm)
%                Create a new RTLinux state machine handle that
%                connects to the state machine server running on
%                host, port.  Since a state machine server can
%                handle more than one virtual state machine,
%                which_state_machine specifies which of the 6 state
%                machines on the server to use.  See
%                GetStateMachine.m for more details. 
%
%                Parameter #2, port, defaults  to 3333 if not
%                specified.  
%
%                Parameter #3, which_state_machine defaults to 0
%
%                The new state machine will have the following
%                default properties set:
%
%                  fsm = SetOutputRouting(fsm, struct('type', 'dout', ...
%                                         'data', '0-15') ; ...
%                                         struct('type', 'sound', ...
%                                         'data', sprintf('%d', which_state_machine)))
%                  fsm = SetInputEvents(sm, 6);
%
%                The sm will not have any SchedWave matrix, or any
%                state matrix.
%
function [sm] = BpodSM(host,port,which_sm)
  sm.MIN_SERVER_VERSION = 14; % now refers to bpod firmware version
  sm.CLIENT_VERSION = 14;  %
  sm.server_version = [];            % This value is obtained from the server on Initialize(sm);
  sm.host = 'localhost';
  sm.port = 3333;
  sm.fsm_id = 0;
  sm.in_chan_type = 'ai'; % use analog input for input
  sm.sched_waves = zeros(0,8); % default to no scheduled waves % <~> Modified to 0,8 since there is an additional column - the sound trigger - ... odd that this isn't already 0,8 in Calin's new code.... I suppose the initialization doesn't matter.
  sm.sched_waves_ao = cell(0,4); % default to no ao sched waves
  sm.input_event_mapping = []; % input_event_mapping is written-to by SetInputEvents below..
  sm.ready_for_trial_jumpstate = 35; %not actually supported for now
  sm.in_chkconn = 1;
  sm.happSpec = struct('name', {}, 'detectorFunctionName', {}, 'inputNumber', {}, 'happId', {});
  sm.happList = cell(0,1);
  sm.use_happenings = 0;

  switch nargin
    case 0
      error('Please pass a hostname to BpodSM constructor');
    case 1
      if (isa(host,'BpodSM'))
          sm = host; 
          return; 
      end;
      sm.host = host;
    case 2
      sm.host = host;
      sm.port = port;
    case 3
      sm.host = host;
      sm.port = port;
      sm.fsm_id = which_sm;
    otherwise
      error('Please pass 3 or fewer arguments to BpodSM');
  end;

  sm.output_routing = { struct('type', 'dout', ...
                               'data', '0-15') ; ...
                        struct('type', 'ext', ... % NB: ext means sound
                               'data', sprintf('%d', sm.fsm_id)) };
  
  %sm.handle = FSMClient('create', sm.host, sm.port);
  sm.handle = 0;
  % bless this to be a class
  sm = class(sm, 'BpodSM');
  
  % just to make sure to explode here if the connection failed
  %FSMClient('connect', sm.handle);
  ChkConn(sm);
  ChkVersion(sm);
  sm = SetStateMachine(sm, sm.fsm_id);
  sm = SetInputEvents(sm, 6, 'ai'); % 6 input events, two for each nosecone

  return;
%end


