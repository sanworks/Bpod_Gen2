%     The following helper functions are at the end of this file:
%          function [] = script_hooks(hook,OpenProtocolObject)
%
function [x, y] = RunningSection(obj, action, x, y)

EVNT_COLS_N =5;
% added a function wide variable for number of columns in event matrix so
% that in the future if we change this, we only have to change it in once
% place. -JCE Aug, 28 2007
%
% added a try catch to the running loop for error catching in runrats.
% Chuck Kopec November 2011
GetSoloFunctionArgs;

switch action,


    case 'init',
        % ------------------------------------------------------------------
        %%                       INIT
        % ------------------------------------------------------------------
        SoloParamHandle(obj, 'my_gui_info', 'value', [x y gcf]);

        SoloParamHandle(obj, 'Running', 'value', 0);
        PushbuttonParam(obj, 'RunButton', x, y, ...
            'position', [x+20 y 340 100],...
            'label', 'Click to Run', ...
            'BackgroundColor', [0 1 0]);
            set_callback(RunButton, {mfilename, 'RunButtonCallback'});
        SoloParamHandle(obj, 'Lock_RunButtonCallback', 'value', 0);
        SoloParamHandle(obj, 'stop_after_next_update', 'value', 0);
        SoloParamHandle(obj, 'stopping_process_completed', 'value', 1);
        SoloFunctionAddVars('runrats','func_owner','@runrats','ro_args','stopping_process_completed'); %     This is a bit unpleasant. We give ro access to the flag denoting the stop process as complete to runrats so that runrats can wait on it using a timer. :P
        SoloFunctionAddVars('TowerWaterDelivery','func_owner','@TowerWaterDelivery','ro_args','stopping_process_completed'); %     This is a bit unpleasant. We give ro access to the flag denoting the stop process as complete to runrats so that runrats can wait on it using a timer. :P

        set(get_ghandle(RunButton), 'FontSize', 20); % (defined by GetSoloFunctionArgs)
        y = y+110;

        NumeditParam(obj, 'UpdatePeriod', 350, x, y, 'position', [x+80 y, 220 20], 'TooltipString', ...
            'minimum time (ms) between update calls when running'); next_row(y, 1.5);

        set_callback(UpdatePeriod,{mfilename,'setUpdatePeriod'});

        DispParam(obj, 'LastState', '',   x,     y, 'labelfraction', 0.3);
        DispParam(obj, 'LastStateNum', 0, x+200, y); next_row(y);
        DispParam(obj, 'LastEvent', '',   x,     y, 'labelfraction', 0.3);
        DispParam(obj, 'LastEventTime',0, x+200, y); next_row(y);
        DispParam(obj, 'CurrState', '',   x,     y, 'labelfraction', 0.3);
        DispParam(obj, 'CurrStateNum', 0, x+200, y); next_row(y);
        DispParam(obj, 'Time', '',        x,     y, 'labelfraction', 0.3); next_row(y);
        DispParam(obj, 'nEvents', 0,      x,     y, 'labelfraction', 0.3); next_row(y);
        DispParam(obj, 'nTrials', 0,      x,     y, 'labelfraction', 0.3); next_row(y);

        SoloParamHandle(obj, 'last_trial_ending_pokes_state',  'value', []);
        SoloParamHandle(obj, 'in_iti_states_flag',             'value', 0);
        SoloParamHandle(obj, 'last_update_time', 'value', -Inf);

        %     Create Timer for update cycles.
        %     This is not used if GENERAL;use_timers is 0.
        ut=timer;
        set(ut, 'Period', UpdatePeriod/1000, ...
            'ExecutionMode','FixedRate', ...
            'ErrorFcn', {@timer_error,lasterror},...
            'BusyMode', 'drop', ...                 % <~> line added in working directory on 2007.09.14; for a given timer T with Interruptible setting 'off', if timer event i+1 occurs during execution of callback started by timer event i, event i+1 does not generate a callback at all. Default is to queue the callback instead. Note that this timer is not currently uninterruptible, though.
            'TimerFcn', 'dispatcher(''update'');');
        SoloParamHandle(obj, 'update_timer', 'value', ut);

        %     The wait-for-timer scheme I tried failed because
        %       waitfor(timer) does not actually wait until the timer is
        %       stopped, but rather for a fixed time calculated from the
        %       current state of the timer when waitfor is called!
        %       EVIL MATLAB! Instead, I'm using the variable
        %       "stopping_process_completed" and a pausing loop.
        %
        %         %     Create Timer for stop coordination. This is always used if
        %         %       QueueStopAndWait is called, but it is only a timer - no
        %         %       dispatcher code executes in its TimerFcn; instead, it is
        %         %       waited for, and stop is called on it when the experiment
        %         %       has been completely stopped.
        %         st=timer;
        %         set(st, 'Period', 1, ...
        %             'ExecutionMode','FixedRate',...
        %             'TimerFcn', 'display(''Still waiting for experiment to finish stopping....'');',...
        %             'TasksToExecute',1000000);     %     Hack for a reason (can't be inf of waitfor not permitted)
        %         SoloParamHandle(obj, 'doneStopping_timer', 'value', st);

        % %     %     I'm leaving this code out for now - but take note of it as a
        % %     %       suggestion.
        % %     %     %     If we're using an emulator, we should probably drive it at a
        % %     %     %       higher frequency than the update frequency.
        % %     %     if ismember(bSettings('get','RIGS','fake_rp_box'), [3 4]) || ismember(fake_rp_box, [3 4]),
        % %     %         set(ut,'TimerFcn','dispatcher(''drive_emulator_and_update'');');
        % %     %     end;



        feval(mfilename, obj, 'fresh_initialization');

    case 'fresh_initialization',
        % ------------------------------------------------------------------
        %%                 FRESH_INITIALIZATION
        % ------------------------------------------------------------------
        ForceState0(state_machine);
        freshly_initialized_machines.value = 0;

        LastState.value = ''; LastStateNum.value  = NaN;
        LastEvent.value = ''; LastEventTime.value = NaN;
        CurrState.value = ''; CurrStateNum.value  = NaN;
        Time.value      = 0;
        nEvents.value   = 0;
        nTrials.value   = 0;

        raw_events.value = zeros(0, EVNT_COLS_N);
        parsed_events.value = zeros(0, EVNT_COLS_N);
        last_trial_ending_pokes_state.value = [];
        in_iti_states_flag.value = 0;

        last_update_time.value   = -Inf;

    case 'Stop',
        % -----------------------------------------------------------------
        %%                 Stop
        % -----------------------------------------------------------------
        %     For backward compatibility, we'll keep this case name around.
        %     It will queue a stop.
        %
        %     Note that there is technically a hole in this construction:
        %       We should check to make sure we're not already stopping
        %       (e.g. user pressed dispatcher stop and runrats then calls
        %       for stop. This should never happen, really. :P)
        Lock_RunButtonCallback.value = 1;
        set(get_ghandle(RunButton),'Enable', 'off');
        pause(0.2); %     Pause to clear extra buttonpresses.
        feval(mfilename,obj,'QueueStop');

    case 'Run',
        % -----------------------------------------------------------------
        %%                 Run
        % -----------------------------------------------------------------
        %     For backward compatibility, we'll keep this case name around.
        %     It will start dispatcher.
        %
        %     Note that there is technically a hole in this construction:
        %     We should check to make sure we're not already running (e.g.
        %       user pressed dispatcher run and runrats then calls for
        %       run). This should  never happen, really. :P)
        Lock_RunButtonCallback.value = 1;
        set(get_ghandle(RunButton),'Enable', 'off');
        pause(0.2); %     Pause to clear extra buttonpresses.
        feval(mfilename,obj,'RunLoop');

    case 'RunButtonCallback',
        % -----------------------------------------------------------------
        %%                 RunButtonCallback
        % -----------------------------------------------------------------
        if Lock_RunButtonCallback, return; end; Lock_RunButtonCallback.value = 1; %#ok<NODEF>
        set(get_ghandle(RunButton),'Enable', 'off');
        %     set informative label here?
        pause(0.2); %     Pause to clear extra buttonpresses.


        if Running, %#ok<NODEF>
            feval(mfilename,obj,'QueueStop'); %     stop  experiment
        else
            feval(mfilename,obj,'RunLoop');   %     start experiment
        end;

    case 'QueueStop',
        % -----------------------------------------------------------------
        %%                 QueueStop
        % -----------------------------------------------------------------
        set(get_ghandle(RunButton),...
            'String','Stopping...',...
            'BackgroundColor',[0.9,0.3,0.3]);
        stopping_process_completed.value    = 0;
        stop_after_next_update.value        = 1;

    case 'QueueStopAndWait',
        % -----------------------------------------------------------------
        %%                 QueueStopAndWait
        % -----------------------------------------------------------------
        feval(mfilename,obj,'QueueStop');
        %         start(value(doneStopping_timer));
        %         waitfor(value(doneStopping_timer));
        while ~value(stopping_process_completed), %#ok<NODEF>
            pause(1); display('Waiting for stopping process to complete'); %     temporary debug message
        end;

    case 'RunStop',
        % -----------------------------------------------------------------
        %%                 RunStop
        % -----------------------------------------------------------------

        %     If script hooks are set up, run the end-of-experiment script
        %       (e.g. to stop video).
        script_hooks('On_End',OpenProtocolObject);
        
        Halt(value(state_machine)); %     stop the state machine
        stop(value(update_timer));  %     stop updates (if using timers)

        %     Set dispatcher state to stopped, then relabel and unlock the
        %       run button and indicate completion of stop process to
        %       anyone waiting for it.
        stop_after_next_update.value        = 0;
        Running.value                       = 0;
        set(get_ghandle(RunButton),...
            'BackgroundColor',[0,1,0],...
            'String','Click to Run',...
            'Enable','on');
        %         stop(value(doneStopping_timer));
        stopping_process_completed.value    = 1;display('Flagged stopping process as complete.'); %     temporary debug message
        Lock_RunButtonCallback.value        = 0;
        RunningSection(obj,'video','stop');

    case 'RunLoop',
        % -----------------------------------------------------------------
        %%                 RunLoop
        % -----------------------------------------------------------------

        %     Make sure that a protocol is selected.
        if isempty(OpenProtocolObject),
            %<~>TODO:     At this point, make sure that the run button has the
            %               right label. (Labeling will be added later.)
            set(get_ghandle(RunButton),'Enable', 'on');
            Lock_RunButtonCallback.value = 0;
            warning('*** will not run without a protocol ***'); %#ok<WNTAG> (This line OK.)
            return;
        end;

        %     1st: Initialize run variables / machines.
        if freshly_initialized_machines==1, %#ok<NODEF> (defined by GetSoloFunctionArgs)
            feval(mfilename, obj, 'fresh_initialization');
            n_started_trials.value   = 1;
        end;

        %     2nd: Unlock the state machine.
        Run(value(state_machine));

        %     3rd: If script hooks are set up, run the start-of-experiment script
        %            (e.g. to start video).
        script_hooks('On_Run',OpenProtocolObject);

        %     4th: Set state variable and button label to indicate that
        %            we're now running.
        Running.value = 1;
        Lock_RunButtonCallback.value = 0;
        set(get_ghandle(RunButton),...
            'String','Running...',...
            'BackgroundColor',[1 0 0],...
            'Enable', 'on');

        %     5th: Begin looping updates.
              RunningSection(obj,'video','start');

        %     Unless use_timers setting exists and is 0, we use timers.
        if ~bSettings('compare','GENERAL','use_timers',0),
            start(value(update_timer));

        else %     Otherwise, we loop.
            iColorToggle = 0;
            while Running==1,
                %Let's put this in a try catch loop that runrats can use
                %for error catching
                try
                    last_update_time.value = clock; %     to maintain update frequency despite update costs, we clock the update itself
                    % <~> Some code to make the run button flicker while it's
                    %       working so it's visible if it halts.
                    if     iColorToggle==1, set(get_ghandle(RunButton),'BackgroundColor',[1 , 0 , 0]);
                    elseif iColorToggle==3, set(get_ghandle(RunButton),'BackgroundColor',[.7, .6, 0]); iColorToggle=0; end;
                    iColorToggle = iColorToggle+1;

                    %If runrats is running, let's flicker it's button as well
                    if runrats('is_running')
                        runrats('flicker_multibutton');
                    end

                    %     Here's the real update call.
                    RunningSection(obj,'update');
                    pausetime = max(0.1, UpdatePeriod/1000 - etime(clock,value(last_update_time)));
                    pause(pausetime);

                catch me %#ok<CTCH>
                    if runrats('is_running');
                        runrats('crashed',me);
                        Running.value = 0;
                    else
                        rethrow(me);
                    end
                    
                end
            end;
        end; %     end if-else using timers

    case 'update',
        % -----------------------------------------------------------------
        %%              Update
        % -----------------------------------------------------------------

        %     If we're running an emulator, we're responsible for driving
        %       the cycles of the emulator itself. We're going to do this
        %       at a low frequency (the update rate).
        if ismember(bSettings('get','RIGS','fake_rp_box'),[3 4]),
            FlushQueue(state_machine);
        end;
        
        nevents_last_update = value(nEvents); %#ok<NODEF> (defined by GetSoloFunctionArgs)
        nEvents.value       = GetEventCounter(state_machine);
        newevents           = GetEvents2(state_machine, nevents_last_update+1, nEvents+0); % <~> GetEvents -> GetEvents2 2008.July.24 locally
        % Keep processing obtained events until we've dealt with them all:
        p2 = cell(0,1);
%         if ~isempty(newevents)
%             disp(newevents)
%         end
        [newevents, p2] = RunningSection(obj, 'deal_with_remaining_events', newevents);
        while ~isempty(newevents),
            [newevents, p2] = RunningSection(obj, 'deal_with_remaining_events', newevents);
        end;
        if ~isempty(p2),
            LastEvent.value     = p2{end,2};
            LastEventTime.value = p2{end,3};
            CurrState.value     = p2{end,4};
            CurrStateNum.value  = p2{end,6};
            LastState.value     = p2{end,1};
            LastStateNum.value  = p2{end,5};
        end;
        
        if stop_after_next_update, %#ok<NODEF>
            feval(mfilename,obj,'RunStop');
        end;
        
    %% video ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    
    case 'video',
        return;
        % Added by Jeff on June 30, 2014
        % Trying to use SQL tables to control video instead of ssh from
        % rigs.
        try
        % Check if video server is defined in bSettings
        
        [vid_ip]=bSettings('get','RIGS','video_server_ip');
        [vid_num]=bSettings('get','RIGS','video_server_port');
        
        if isnan(vid_num) && ~ischar(vid_ip)
            return;
        end
        
        % Get the relevant parameters from the protocol
        protobj=dispatcher(obj,'get_protocol_object');
        [experimenter,ratname]=SavingSection(protobj,'get_info');
        
        % Check if there has already been a session for this rat today
        
        [run_before]=bdata('select sessid from sessions where ratname="{S}" and sessiondate=date(now())',ratname);
        setdiff(run_before,getSessID(protobj));
        if numel(run_before)<25 
        suffix = char('a' + numel(run_before));
        else
            suffix=sprintf('_%d',numel(run_before));
            warning('Unusually large # of sessions for this rat')
        end
        % call the server script
        
        
        if ispc
            switch x,
             case 'start',
                evalcmd='/ratter/Rigscripts/VSStartRecord.sh';
                evalstr=sprintf('ssh %s "%s %d %s %s %s %d &"',vid_ip,evalcmd,vid_num,experimenter,ratname,suffix,getSessID(protobj));
             case 'stop',
                   %  this_dir=cd;
                  %   cd('\ratter\Rigscripts');
                evalstr=sprintf('\\ratter\\Rigscripts\\VCStopRecord.bat %s %d %s %s %s %d &',vid_ip,vid_num,experimenter,ratname,suffix,getSessID(protobj));   
          %   cd(this_dir);
            end 
        else
            switch x,
             case 'start',
                evalcmd='/ratter/Rigscripts/VSStartRecord.sh';
             case 'stop',
                evalcmd='/ratter/Rigscripts/VSStopRecord.sh';   
            end
         evalstr=sprintf('ssh -f brodylab@%s "%s %d %s %s %s %d"',vid_ip,evalcmd,vid_num,experimenter,ratname,suffix,getSessID(protobj));
        end
        system(evalstr);
        catch me
            fprintf(2,'Failed to connect to video server\n')
            showerror(me);
        end
        
    case 'runstart_enable',
        % ------------------------------------------------------------------
        %%                 RUNSTART_ENABLE
        % ------------------------------------------------------------------
        if Running==0,  %#ok<NODEF> (defined by GetSoloFunctionArgs)
            % <~> I've separated these set calls because it appears that things
            %       aren't done atomically or even in order if multiple
            %       parameters are used.
            set(get_ghandle(RunButton),'BackgroundColor',[0,1,0], 'String','Click to Run');
            set(get_ghandle(RunButton),'Enable','On');
            drawnow;
        end;

    case 'runstart_disable',
        % ------------------------------------------------------------------
        %%                 RUNSTART_DISABLE
        % ------------------------------------------------------------------
        if Running==0,  %#ok<NODEF> (defined by GetSoloFunctionArgs)
            set(get_ghandle(RunButton),'BackgroundColor', [0.5 1 0.5]);
            set(get_ghandle(RunButton),'Enable', 'off');
            drawnow;
        end;

    case 'disassemble',
        % ------------------------------------------------------------------
        %%                 DISASSEMBLE
        % ------------------------------------------------------------------
        trials = x;
        rawh = get_history(raw_events); %#ok<NODEF>
        smah = get_history(MachinesSection(obj, 'get_current_assembler'));

        % Following hack is to account for  bug that was fixed Aug 31 2007.
        % (For fix, see CVS comments for Plugins/@saveload/SavingSection.m)
        % In that bug, some assemblers could be saved to the history even when
        % they weren't run, and this happened before the session started. So,
        % we throw away any early assemblers, on the assumption that they came
        % from that bug. -- CDB fixed the bug described above and added hack
        % below:
        delta = length(smah) - length(rawh);
        smah = smah(1:end-delta); % smah  = smah(delta+1:end);
        % end hack

        for i=1:length(trials),
            fprintf(1, '\n\n ----- Trial %d ------\n', trials(i));
            if trials(i) < 1 || trials(i) > length(rawh)+1,
                warning('DISPATCHER:Out_of_range', 'Don''t have history data for trial #%d, not disassembling', ...
                    trials(i));
            elseif trials <= length(rawh),
                % It's in the history:
                % (Below, we wrap smah{trials(i)} in a call to StateMachineAssembler in case it is a struct, 
                % from loading an older version of the StateMachineAssembler class).
                disassemble(StateMachineAssembler(smah{trials(i)}), rawh{trials(i)});
            else % Only remaining possibility is trials = length(rawh)+1, i.e., it is the current trial:
                disassemble(value(MachinesSection(obj, 'get_current_assembler')), value(raw_events));
            end;
        end;

    case  'setUpdatePeriod',
        % ------------------------------------------------------------------
        %%                 setUpdatePeriod
        % ------------------------------------------------------------------

        ut=value(update_timer);
        stop(ut);
        set(ut,'Period',UpdatePeriod/1000);
        start(ut);

    case 'get_time',
        % ------------------------------------------------------------------
        %%                 GET_TIME
        % ------------------------------------------------------------------
        x = value(Time); %#ok<NODEF> (defined by GetSoloFunctionArgs)

    case 'get_currentstatenum',
        % ------------------------------------------------------------------
        %%                 GET_TIME
        % ------------------------------------------------------------------
        x = value(CurrStateNum); %#ok<NODEF>

        
    case 'is_running',
        % -----------------------------------------------------------------
        %%                 IS_RUNNING
        % -----------------------------------------------------------------
        if ~exist('Running', 'var'); x=0; return; end;
        x = (Running==1); %#ok<NODEF>
 
  case 'deal_with_remaining_events',    
      % ------------------------------------------------------------------
      %%              DEAL_WITH_REMAINING_EVENTS
      % ------------------------------------------------------------------
    events = x;
    if isempty(value(parsed_events)), poke_state_hint = value(last_trial_ending_pokes_state); %#ok<NODEF> (defined by GetSoloFunctionArgs)
    else                              poke_state_hint = parsed_events.pokes.ending_state; % <~> unnecessary value() call on ending_state removed 2007_09_21 early morning; ending_state is a struct
    end;

    if in_iti_states_flag==0, %#ok<NODEF> (defined by GetSoloFunctionArgs)
      % Within regular portion of trial, check to see whether trial has ended:
      u = find(ismember(events(:,4), prepare_next_trial_ids), 1, 'first');
      if isempty(u),
        % No prepare_next_trial state reached, just do a regular update:
        if ~isempty(events)
          if isempty(value(raw_events)) %#ok<NODEF>
            raw_events.value=events;
          else
            raw_events.value = [value(raw_events) ; events]; %#ok<NODEF> (defined by GetSoloFunctionArgs)
          end
        end
		
        [newparsed, p2] = disassemble(current_assembler, events, ...
          'parsed_structure', 1, 'also_non_parsed', 1, 'pokes_starting_state', poke_state_hint);
        tot_pe = stitch_chunks(current_assembler, value(parsed_events), newparsed);
        parsed_events.value        = tot_pe;
        latest_parsed_events.value = newparsed;

        Time.value = GetTime(state_machine);
        feval(class(OpenProtocolObject), 'update');
        % All events have been processed, none left to hand back:
        x = zeros(0,EVNT_COLS_N); y = p2;
      else
        % prepare_next_trial state was found, process up to there and call state35 in the
        % protocol. Events included will be up to and including the event
        % that caused the transition to state35, but no further.
        raw_events.value = [value(raw_events) ; events(1:u,:)]; %#ok<NODEF> (defined by GetSoloFunctionArgs)
        [newparsed, p2] = disassemble(current_assembler, events(1:u,:), ...
          'parsed_structure', 1, 'also_non_parsed', 1, 'pokes_starting_state', poke_state_hint);
        tot_pe = stitch_chunks(current_assembler, value(parsed_events), newparsed);
        parsed_events.value        = tot_pe;
        latest_parsed_events.value = newparsed;
        
        in_iti_states_flag.value = 1;

        % We're going to hand back remaining events:
        x = events(u+1:end,:); y = p2;  
        if isempty(x), Time.value = GetTime(state_machine); 
        else           Time.value = p2{end,3};
        end;

        % First make sure all events are processed as in a regular update call:       
        feval(class(OpenProtocolObject), 'update');

        % Then blank out latest_parsed_events -- they've already been processed:
        % Call used here ensures latest_parsed_events will have all the
        % right structures, but all content will be empty
        [latest_parsed_events] = disassemble(current_assembler, zeros(0, size(events,2)), ...
          'parsed_structure', 1, 'pokes_starting_state', poke_state_hint); %#ok<NASGU>

        % Finally, call 'prepare_next_trial' on the protocol:
        n_done_trials.value = n_done_trials + 1; %#ok<NODEF> (defined by GetSoloFunctionArgs)
        feval(class(OpenProtocolObject), 'prepare_next_trial');
        nTrials.value = nTrials + 1; %#ok<NODEF> (defined by GetSoloFunctionArgs)
                
      end;
    else
      % Within iti; look for a state 0 that indicates next trial has really started:
      u = find(events(:,1)==0, 1, 'first');
      if isempty(u),
        % No state0, still assembler from previous trial for update:
        if ~isempty(events)
        raw_events.value = [value(raw_events) ; events]; %#ok<NODEF> (defined by GetSoloFunctionArgs)
        end
        if ~isempty(previous_assembler), 
          [newparsed, p2] = disassemble(value(previous_assembler), events, ...
            'parsed_structure', 1, 'also_non_parsed', 1, 'pokes_starting_state', poke_state_hint);
        else
          [newparsed, p2] = disassemble(current_assembler, events, ...
            'parsed_structure', 1, 'also_non_parsed', 1, 'pokes_starting_state', poke_state_hint);
        end;
        tot_pe = stitch_chunks(current_assembler, value(parsed_events), newparsed);
        parsed_events.value        = tot_pe; 
        latest_parsed_events.value = newparsed;
        
        Time.value = GetTime(state_machine);        
        feval(class(OpenProtocolObject), 'update');
        % All events have been processed, none left to hand back:
        x = zeros(0, EVNT_COLS_N); y = p2;        
      else
        % State 0 was found, process up to there, call 'state0' in the
        % protocol (events included will be up to and including the last
        % event *before* transitioning to state 0), and then turn
        % in_iti_states_flag off and hand back. Note that the transition to
        % state 0 is not always done by an event that is registeres, since
        % both the autojump from state35 to state0 (when ReadyToStartTrial
        % has been set) and ForceState0.m do not register an event. 
        raw_events.value = [value(raw_events) ; events(1:u-1,:)]; %#ok<NODEF> (defined by GetSoloFunctionArgs)
        if ~isempty(previous_assembler), 
          [newparsed, p2] = disassemble(value(previous_assembler), events(1:u-1,:), ...
            'parsed_structure', 1, 'also_non_parsed', 1, 'pokes_starting_state', poke_state_hint);
        else
          [newparsed, p2] = disassemble(current_assembler, events(1:u-1,:), ...
            'parsed_structure', 1, 'also_non_parsed', 1, 'pokes_starting_state', poke_state_hint);
        end;
        tot_pe = stitch_chunks(current_assembler, value(parsed_events), newparsed);
        parsed_events.value        = tot_pe; 
        latest_parsed_events.value = newparsed;

        in_iti_states_flag.value = 0;

        % We're going to hand back remaining events:
        x = events(u:end,:); y = p2;  
        if isempty(x), Time.value = GetTime(state_machine); error('Programming error. This condition should be impossible. Please consult a developer.'); % <~>
        else
            %Time.value = p2{end,3}; % <~> old line, removed 2007.09.21 noon             
            Time.value = parsed_events.states.(parsed_events.states.ending_state)(end,1); % <~> new line added 2007.09.21 noon
        end;

        feval(class(OpenProtocolObject), 'trial_completed');

        % Now, after state 0, we can clear up for new trial, with a new
        % assembler and new meanings. First event in the new trial will be
        % the one in which a transition from state 0 occurs.
        push_history(raw_events); push_history(parsed_events);
        last_trial_ending_pokes_state.value = parsed_events.pokes.ending_state;
        raw_events.value = zeros(0, EVNT_COLS_N);
        
        %     Initialize parsed_events for the next state so that it
        %       implements the dispatcher specifications.
        parsed_events.value = disassemble(current_assembler, zeros(0, EVNT_COLS_N), ...
          'parsed_structure', 1, 'pokes_starting_state', poke_state_hint); %#ok<NASGU>
        parsed_events.states.starting_state = 'state_0';
        parsed_events.states.ending_state = 'state_0';
        parsed_events.states.state_0 = [NaN value(Time)];
        
        latest_parsed_events.value  = [];  
        n_started_trials.value   = n_started_trials + 1; %#ok<NODEF> (defined by GetSoloFunctionArgs)
        n_completed_trials.value = n_started_trials - 1;
      end;
    end;




    case 'reinit',
        % ------------------------------------------------------------------
        %                    REINIT
        % ------------------------------------------------------------------
        currfig = gcf;

        % Get the original GUI position and figure:
        x = my_gui_info(1); y = my_gui_info(2); figure(my_gui_info(3));

        % Delete all SoloParamHandles who belong to this object and whose
        % fullname starts with the name of this mfile:
        delete(value(update_timer));
        delete_sphandle('owner', ['^@' class(obj) '$'], 'fullname', ['^' mfilename]);

        % Reinitialise at the original GUI position and figure:
        [x, y] = feval(mfilename, obj, 'init', x, y);

        % Restore the current figure:
        figure(currfig);

    case 'close'
        % ------------------------------------------------------------------
        %                    CLOSE
        % ------------------------------------------------------------------
        try % Try/Catch added by J.S. to avoid need to force-quit MATLAB when B-control errors out before loading
            delete(value(update_timer));
        catch
        end
   %     delete(value(doneStopping_timer));

    otherwise

end;



end % end method RunningSection








%     Code to handle the third-party scripts to be triggered on stop & run.
%     hook should only be 'On_Run' or 'On_End' for now.
function [] = script_hooks(hook,OpenProtocolObject)


%     Extremely ugly hack to skip all script hooks on rig testing
%       (protocols with names including the string 'Rigtest' or 'Calibration').
% Update: 20th October, 2009: slight modification to look for inclusion of
% the string throughout the classname, using strfind, and not strmatch
if         ~isempty(strmatch('Rigtest',class(OpenProtocolObject))) ...
        || ~isempty(strfind(lower(class(OpenProtocolObject)), 'calibration')),
    return;
end;

if ~strcmp(hook,{'On_Run','On_End'}),
    warning(['script_hooks helper function in @dispatcher/RunningSection.m'...
        ' has been called with an argument other than "On_Run" or ' ...
        ' "On_End". It was: "' hook '". No script was run.']); %#ok<WNTAG> (This line OK.)
    return;
end;

%     We only run the script if the do-not-run flag exists and is 0,
%       the flag to enable scripting on this hook is 1, and
%       the file is specified and exists.
[run_third_party_scripts errID1] = ...
    bSettings('compare','AUX_SCRIPT','Disable_Aux_Scripts', false);
[run_script_on_this_hook errID2] = ...
    bSettings('compare','AUX_SCRIPT',['Enable_' hook '_Script'], true); %e.g. Enable_On_Run_Script
[script_to_run errID3] = ...
    bSettings('get','AUX_SCRIPT',[hook '_Script']);
[script_args errID4] = ...
    bSettings('get','AUX_SCRIPT',[hook '_Args']);
if errID1 || errID2 || errID3 || errID4 ...
        || ~run_third_party_scripts ...
        || ~run_script_on_this_hook,
    return;
elseif ~ischar(script_to_run) ...
        ||  isempty(script_to_run) ...
        || ~exist(script_to_run, 'file'),
    warning([hook ' script hook is enabled, but the script is not' ...
        ' specified or the file specified does not exist. Please' ...
        ' check your settings.']); %#ok<WNTAG> (This line OK.)
    return;
end;

% Otherwise, we're set to run the script.

%     Base command string + given args.


evalstring = [script_to_run ' ' script_args];

%     Add default arguments afterwards.
%     (The problem here is that we could add... SO MANY.)
%     (If I didn't mind EVIL HACKS, I could interpret tags of the
%        form <experimenter>, <left_weight>, etc. in the
%        script_args string and use sp_gethandles to
%        just insert the value of every SPH named.......)

%     For now, we only add:
%         1-  experimenter  (if SavingSection is defined)
%         2-  ratname       (if SavingSection is defined)
%         3-  protocol name
%         4-  the rig ID of the current machine if defined (Brodylab)
%
if find(strcmp('SavingSection',methods(OpenProtocolObject,'-full'))),
    [experimenter_v ratname_v] = SavingSection(OpenProtocolObject,'get_info');
    evalstring = [evalstring ' ' experimenter_v ' ' ratname_v];
end;
evalstring = [evalstring ' ' class(OpenProtocolObject)]; %     add protocol name

[hostnameStr errID] = bSettings('get','RIGS','Rig_ID');
if ~errID, evalstring = [evalstring ' ' int2str(hostnameStr)]; end;

%     There may be a more delicate way to do this....
eval(['!' evalstring ' &']); %     fork

     %     end helper function script_hooks
end