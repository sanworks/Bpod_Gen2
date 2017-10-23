function [ret, ret2] = MachinesSection(obj, varargin)

global fake_rp_box;
global state_machine_server;
global sound_machine_server;
global BpodSystem

GetSoloFunctionArgs;

if nargin < 2, return; end;

action = varargin{1};

switch action,

  % ------------------------------------------------------------------
  %                       INIT
  % ------------------------------------------------------------------
  case 'init'
      
    SoloParamHandle(obj, 'server_slot', 'value', NaN);
    SoloParamHandle(obj, 'card_slot',   'value', NaN);
    try   server_slot.value = bSettings('get', 'RIGS', 'server_slot');
    catch 
    end;
    if isnan(value(server_slot)), server_slot.value = 0; end;
    try   card_slot.value = bSettings('get', 'RIGS', 'card_slot');
    catch 
    end;
    if isnan(value(card_slot)), card_slot.value = 0; end;
      
	not_connected=true;
% 	while not_connected
% 		
% 		try
			% --- Setting up the state machine:
			SoloParamHandle(obj, 'state_machine');
			if     fake_rp_box==2,
				state_machine.value = RTLSM( state_machine_server, 3333, value(server_slot));
			elseif fake_rp_box==20,
				state_machine.value = RTLSM2(state_machine_server, 3333, value(server_slot)); % <~> line added to head branch 2008.June.25
            elseif fake_rp_box== 30,
                state_machine.value = BpodSM();
            elseif fake_rp_box==3,
				state_machine.value = SoftSMMarkII;
			else
				error('Sorry, can only work with fake_rp_box (from mystartup.m or Settings) equal to 2, 20, or 3'); % <~> added 20, 2008.June.25
			end;
			% if we have reached this point without an error, we have successfully
			% connected to an FSM
			not_connected=false;
% 		catch
% 			if fake_rp_box==2
% 				rethrow(lasterror);
% 			elseif fake_rp_box==20
% 				ready=questdlg({'We failed to connect to an FSM.'...
% 					'If you intended to connect to an emulator please start the emulator and hit continue after the emulator has started.'...
% 					'Otherwise hitting cancel will error out of dispatcher'},...
% 					'Ready to Continue?','Continue','Use software Emulator', 'Cancel','Cancel');
% 			    if ready(1)=='U'
% 					fake_rp_box=3;
% 				elseif ~strcmp(ready,'Continue')
% 					rethrow(lasterror);	
% 				end
% 				
% 			end
% 		end
%	end
		

  
    % --- Setting up the sound server:
    SoloParamHandle(obj, 'sound_machine');
    if     fake_rp_box==2 || fake_rp_box==20,   sound_machine.value = RTLSoundMachine(sound_machine_server); % <~> added 20, 2008.June.25
        if GetNumCards(value(sound_machine))-1 < value(card_slot),
            error('Have sound card slots 0 through %d, yet setting "RIGS; card_slot" asks for slot %d\n', ...
                GetNumCards(value(sound_machine))-1, value(card_slot));
        end;
        SetCard(value(sound_machine), value(card_slot));
    elseif fake_rp_box==3,   
        sound_machine.value = softsound;
    elseif fake_rp_box==30,
        sound_machine.value = bpodSound;
    else
      error('Sorry, can only work with fake_rp_box (from mystartup.m) equal to 2, 20, or 3'); % <~> added 20, 2008.June.25
    end;
    
    SoloParamHandle(obj, 'freshly_initialized_machines', 'value', 0);
    SoloParamHandle(obj, 'previous_assembler', 'value', []);
    SoloParamHandle(obj, 'prepare_next_trial_ids', 'value', []);
    SoloFunctionAddVars('RunningSection', 'rw_args', {'previous_assembler' ...
      'freshly_initialized_machines'}, 'ro_args', 'prepare_next_trial_ids');
    
    DeclareGlobals(obj, 'ro_args', {'state_machine', 'sound_machine'});

    SoloParamHandle(obj, 'trialnum_indicator_flag', 'value', 0); % if set to 1, a trialnum signal
    % will be sent in a digital output line immediately after state_0. See
    % @StateMachineAssembler/add_trialnum_indicator.m

    
    feval(mfilename, obj, 'initialize_machines');
    
    %     We now send a meaningless matrix simply because channel bypassing
    %       will not work until some matrix has been sent. This allows us
    %       to (for example) flush water valves before loading a protocol.
    %     temp_sma = StateMachineAssembler('full_trial_structure');
    %     temp_sma = add_state(temp_sma,'name','vapid_state_in_vapid_matrix');
    %     [inL outL] = feval(mfilename,obj,'determine_io_maps');
    %     send(temp_sma,value(state_machine),'run_trial_asap',0,...
    %         'input_lines',inL,'dout_lines',outL,...
    %         'sound_card_slot', int2str(value(card_slot)));

  % ------------------------------------------------------------------
  %                       INITIALIZE_MACHINES
  % ------------------------------------------------------------------
  case 'initialize_machines',
    
    state_machine.value = Initialize(value(state_machine)); %#ok<NODEF>
    sound_machine.value = Initialize(value(sound_machine)); %#ok<NODEF>
    % --- connect StateMachine and SoundMachine if necessary:       
    if fake_rp_box == 3,
      SetTrigoutCallback(value(state_machine), @playsound, value(sound_machine));
    end;
    freshly_initialized_machines.value = 1;
    
  % ------------------------------------------------------------------
  %                       GET_SOUND_MACHINE
  % ------------------------------------------------------------------
    
  case {'get_sound_machine' 'getsoundmachine'},   
    ret = value(sound_machine); %#ok<NODEF>
    
    
  % ------------------------------------------------------------------
  %                       GET_STATE_MACHINE
  % ------------------------------------------------------------------
  case {'get_state_machine' 'getstatemachine'},  
    ret = value(state_machine); %#ok<NODEF>

    
  % ------------------------------------------------------------------
  %                       GET_CURRENT_ASSEMBLER
  % ------------------------------------------------------------------
    
  case {'get_current_assembler'},   
    ret = current_assembler; %#ok<NODEF>
    
  % ------------------------------------------------------------------
  %                       SET_TRIALNUM_INDICATOR_FLAG
  % ------------------------------------------------------------------
  case 'set_trialnum_indicator_flag',
    trialnum_indicator_flag.value = 1;

  % ------------------------------------------------------------------
  %                       UNSET_TRIALNUM_INDICATOR_FLAG
  % ------------------------------------------------------------------
  case 'unset_trialnum_indicator_flag',
    trialnum_indicator_flag.value = 0;


  % ------------------------------------------------------------------
  %                       SEND_ASSEMBLER
  % ------------------------------------------------------------------
  case 'send_assembler', 
    sma = varargin{2};
    if length(varargin)<3,
      warning(['Wasn''t given "prepare_next_trial" set as 3rd arg-- assuming "check_next_trial_ready" ' ...
        'is only member of that set']); %#ok<WNTAG>
      prepare_next_trial_set.value = {'check_next_trial_ready'};
    else
      prepare_next_trial_set.value = varargin{3};
      if ischar(value(prepare_next_trial_set)), prepare_next_trial_set.value = {value(prepare_next_trial_set)}; end;
      prepare_next_trial_set.value = prepare_next_trial_set(:);      
    end;
    
    
    if ~is_no_dead_time_technology(sma) && ~is_full_trial_structure(sma),
      error(['Sorry, dispatcher only works with StateMachineAssembler\n' ...
        'objects defined with the ''no_dead_time_technology'' or ''full_trial_structure'' flags']);
    end;
    if trialnum_indicator_flag==1 && ~is_full_trial_structure(sma), %#ok<NODEF>
      error(['Sorry, the trialnum_indicator_flag can only be used if your StateMachineAssembler\n' ...
        'was defined with the ''full_trial_structure'' flag.\n']);
    end;
    
    if trialnum_indicator_flag==1,
      sma = add_trialnum_indicator(sma, n_done_trials+1);
      % fprintf(1, 'Sending trialnum %d\n', n_done_trials+1);
    end;
    
    %     input_channels and dio_channels determination pushed into here so
    %       that it can be used in other places as well (and for clarity).
    [input_lines dout_lines] = feval(mfilename,obj,'determine_io_maps');
    
    previous_assembler.value = value(current_assembler);     %#ok<NODEF>
    if freshly_initialized_machines == 1,                    %#ok<NODEF>
      % The very first jump to state 0 isn't done through ReadyToStartTrial
      [ret, ret2, smach] = send(sma, value(state_machine), 'run_trial_asap', 0, ...
          'input_lines', input_lines, 'dout_lines', dout_lines, ...
          'sound_card_slot', int2str(value(card_slot))); %#ok<NODEF>
      state_machine.value = smach;
    else
      % But the next are; ask send to do ReadyToStartTrial
      [ret, ret2, smach] = send(sma, value(state_machine), 'run_trial_asap', 1, ...
          'input_lines', input_lines, 'dout_lines', dout_lines, ...
          'sound_card_slot', int2str(value(card_slot))); %#ok<NODEF>
      state_machine.value = smach;
    end;
    try
      prepare_next_trial_ids.value = label2statenum(sma, value(prepare_next_trial_set));
      if isempty(prepare_next_trial_ids),
        error('The prepare_next_trial_set you gave me doesn''t seem to be correct');
      end;
    catch
      fprintf(1, 'Something wrong with the prepare_next_trial_set you gave me!\n');
      rethrow(lasterror);
    end;
      
    current_assembler.value = compressed(sma);
    push_history(current_assembler);
    push_history(value(OpenProtocolObject));
    push_history(prepare_next_trial_set);
    
  % ------------------------------------------------------------------
  %                       REPEAT_TRIAL
  % ------------------------------------------------------------------

    case  'repeat_trial',
    ret=obj;    
    ret2 = ReadyToStartTrial(value(state_machine)); %#ok<NODEF>
    
    % <~> Bugfix by Bing and Sebastien:
    %     This code used to say curr = prev.
    %     To illustrate the problem, imagine we're in trial X and the rat
    %       performs some violation of trial rules and we want to repeat
    %       trial X in trial X+1.
    %     At this point in the code,
    %           current_assembler         refers to trial X
    %           previous_assembler        refers to trial X-1
    %     After this point in the code,
    %           current_assembler  SHOULD REFER  to trial X+1
    %           previous_assembler SHOULD REFER  to trial X
    %     Therefore, the correct procedure is, as below, to set
    %           current = current    (i.e. do nothing)
    %           prev    = current    
    %
    %     The old code was flawed in that it assigned the value of
    %       previous_assembler (i.e. information from trial X-1) to
    %       current_assembler (which saves information for the next trial).
    %       In short, we were using information from trial X-1 to interpret
    %       the events of trial X+1.
    previous_assembler.value = value(current_assembler); %#ok<NODEF>
    push_history(current_assembler);
    push_history(value(OpenProtocolObject));
    push_history(prepare_next_trial_set); %#ok<NODEF>
    
    
  % ------------------------------------------------------------------
  %                       SEND_STATENAMES
  % <~> I can't find any usage of this. Am I missing something? Who's
  %       performing this role instead? SMA? This code should be removed if
  %       it's not being used, or at least properly commented.
  % ------------------------------------------------------------------
  case 'send_statenames', 
    theStruct = varargin{2};
    if(isa(theStruct,'SoloParamHandle')), theStruct = value(theStruct); end;
    if (~isa(theStruct, 'struct')), error('Expected struct for state names!'); end;
    mapping = [fieldnames(theStruct) struct2cell(theStruct)];
    SetStateNames(value(state_machine), mapping); %#ok<NODEF>

    
    
  % ------------------------------------------------------------------
  %                       CLOSE
  % ------------------------------------------------------------------
  case 'close', 
    Close(value(state_machine)); %#ok<NODEF>
    if isfield(BpodSystem.PluginObjects, 'SoundServer')
        BpodSystem.PluginObjects = rmfield(BpodSystem.PluginObjects, 'SoundServer');
    end
    
    
    
    % ------------------------------------------------------------------
    %                       DETERMINE_IO_MAPS
    % <~> It appears that this is only used in the assignment of IO mapping
    %       during the load of the pre-SMA in dispatcher initialization.
    %       When SMA is readapted to extract access to the state machine
    %       server clients from the SMA into dispatcher proper exclusively,
    %       this should be employed.
    % ------------------------------------------------------------------
    case 'determine_io_maps',
        lone_rig=bSettings('compare','RIGS','lone_rig','1');

        %     Input Line Mapping
        %
        %     Here we determine the input line mapping. This is critical
        %       all over dispatcher, and may differ based on particular
        %       experimental setup, or the number of rigs mapped to one
        %       state machine server. In a multiple-rig setup, one
        %       experimental rig may use the first x digital output lines,
        %       the next machine the next x, etc....
        %     If we're using an emulated (fake) rig, or a rig designated as
        %       a "lone rig", we assume that there are only three classes
        %       of inputs corresponding to the center, left, and right
        %       pokes, and that they will be the first, second, and third
        %       set of channels that the state machine server/emulator
        %       controls.
        %     Otherwise, we extract the input mapping straight from the
        %       settings files (see Settings/Settings_Default.conf)
        %     If we're not on an emulator, lone_rig is not defined, AND the
        %       input map settings aren't defined, we set the input map
        %       based on the RIGS;server_slot setting.
        if fake_rp_box==3,
            input_lines = struct('C', 1, 'L', 2, 'R', 3);
        elseif lone_rig==1,
            input_lines = struct('C', 1, 'L', 2, 'R', 3);
        else
            [input_lines  errIL  msgIL ] = bSettings('get','INPUTLINES','all');
            [IL_offset    errILO       ] = bSettings('get','INPUTLINES_MISC','offset');
            if errILO || isnan(IL_offset), IL_offset = 0; end;
            if ~errIL,
                for i=1:size(input_lines,1), input_lines{i,2} = input_lines{i,2}+IL_offset; end;
                input_lines = cell2struct(input_lines(:,2),input_lines(:,1),1); %     Convert to struct with fieldnames== input line names && values== input line numbers
            else
                warning(['     Warning! Error encountered in @dispatcher/MachinesSection while trying to retrieve input lines map settings. We will proceed using old fixed input map (based on server_slot). Error was: ' msgIL]); %#ok<WNTAG>
                switch value(server_slot), %#ok<NODEF>
                    case 0, input_lines = struct('C', 1, 'L', 2, 'R', 3);
                    case 1, input_lines = struct('C', 4, 'L', 5, 'R', 6);
                    case 2, input_lines = struct('C', 7, 'L', 8, 'R', 9);
                    otherwise
                        % Assume this is an unknown setup and use traditional values.
                        input_lines = struct('C', 1, 'L', 2, 'R', 3);
                        warning('DISPATCHER:MachinesSection','Value of server slot not set.  Assuming only one box running. Input lines assumed to be: C-1, L-2, R-3. Dout range assumed to be 0-15.');
                end;
            end;
        end;

        %     Output Line Mapping
        %
        % <~>TODO: IMPORTANT! If output map bounds can change here, then
        %            DIOLINES assignments should also be checked here
        %            (because in any scenario where changing the bounds
        %            would be useful, it would be inappropriate not to
        %            check for changes in the mapping within those bounds).
        % <~>TODO: Remove redundancies.
        %
        %     Here we determine (only) the range of output lines to control
        %       on the state machine server. In a multiple-rig setup, one
        %       experimental rig may use the first 5 digital output lines,
        %       the next machine the next 5, etc....
        %     If we're using an emulated (fake) rig, we assume we're not
        %       multiple rigs. (Why emulate that? o.O) The range is set to
        %       0-15 because that is the range the SoftSMMarkII emulator
        %       supports.
        %     If the "lone rig" setting is set, we assume we're using only
        %       one rig per state machine server, and set all 18 standard
        %       output lines as our range (backward compatibility and most
        %       freedom).
        %     Otherwise, we determine the range of output lines we intend
        %       to be responsible for based on the DIOLINES_MISC;offset
        %       setting in the settings files. (See
        %       Settings/Settings_Default.conf) The offset is the minimum,
        %       and the offset plus the max channel number is the maximum
        %       in the range.
        %     If we're not on an emulator, lone_rig is not defined, AND the
        %       offsets aren't set, we reserve an arbitrary 6 output lines
        %       positioned based on the RIGS;server_slot setting.
        if fake_rp_box==3,
            dout_lines = '0-15';
        elseif lone_rig==1,
            dout_lines = '0-17';
        else
            [dout_lines errOL  msgOL ] = bSettings('get','DIOLINES','all');
            [OL_offset    errOLO       ] = bSettings('get','DIOLINES_MISC','offset');
            if errOLO || isnan(OL_offset), OL_offset = 0; end;
            if ~errOL,
                dout_lines_array     = cell2num(dout_lines(:,2));
                %     The min of the range is specified by the offset,
                %       and we reserve a range large enough to cover all
                %       specified douts.
                dout_lines_min_chan  = OL_offset;                   
                dout_lines_max_chan  = OL_offset + log2(max(dout_lines_array));
                dout_lines = [ int2str(dout_lines_min_chan) '-' int2str(dout_lines_max_chan) ]; %     format the string
            else
                warning(['     Warning! Error encountered in @dispatcher/MachinesSection while trying to output (DIO) lines map settings. We will proceed using old fixed output map (based on server_slot). Error was: ' msgOL]); %#ok<WNTAG>
                switch value(server_slot), %#ok<NODEF>
                    case 0, dout_lines = '0-5';
                    case 1, dout_lines = '6-11';
                    case 2, dout_lines = '12-17';
                    otherwise
                        % Assume this is an unknown setup and use traditional values.
                        dout_lines = '0-15';
                        warning('DISPATCHER:MachinesSection','Value of server slot not set.  Assuming only one box running. Input lines assumed to be: C-1, L-2, R-3. Dout range assumed to be 0-15.');
                end;
            end;
        end;
        
        ret  = input_lines;
        ret2 = dout_lines;
    
    
  otherwise,
      error(['MachinesSection call includes unrecognized action ("' action '").']);
      
end;
