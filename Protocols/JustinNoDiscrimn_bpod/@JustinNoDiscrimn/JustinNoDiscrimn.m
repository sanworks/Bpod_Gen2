function [obj] = JustinNoDiscrimn(varargin)

global n_completed_trials
global n_started_trials
n_completed_trials = 0;
n_started_trials = 1;
global state_machine

% -------- BEGIN Magic code that all protocol objects must have ---
%
% No need to alter this code: will work for every protocol. Jump to
% "END Magic code" to start your own code part.
%

% load a bunch of useful plugins to this object
obj = class(struct, mfilename, soundmanager,sessionmodel,distribui,...
    soundtable,soundui,reinforcement,clickstable,water,saveload,pokesplot);

%in case you dont want to use all of these plugins:
USE_SOUNDMANAGER  = 1;
USE_SESSIONMODEL  = 1;
USE_DISTRIBUI     = 0;
USE_SOUNDTABLE    = 0;
USE_SOUNDUI       = 0;
USE_REINFORCEMENT = 0;
USE_CLICKSTABLE   = 0;
USE_POKESPLOT     = 1;
SHOW_ELAPSED_TIME = 1;

%---------------------------------------------------------------
%   BEGIN SECTION COMMON TO ALL PROTOCOLS, DO NOT MODIFY
%---------------------------------------------------------------

%---------------------------------------------------------------
%   END OF SECTION COMMON TO ALL PROTOCOLS, MODIFY AFTER THIS LINE
%---------------------------------------------------------------


% ---- From here on is where you can put the code you like.
%
% Your protocol will be called, at the appropriate times, with the
% following possible actions:
%
%   'init'     To initialize -- make figure windows, variables, etc.
%
%   'update'   Called periodically within a trial
%
%   'prepare_next_trial'  Called when a trial has ended and your protocol
%              is expected to produce the StateMachine diagram for the next
%              trial; i.e., somewhere in your protocol's response to this
%              call, it should call "dispatcher('send_assembler', sma,
%              prepare_next_trial_set);" where sma is the
%              StateMachineAssembler object that you have prepared and
%              prepare_next_trial_set is either a single string or a cell
%              with elements that are all strings. These strings should
%              correspond to names of states in sma.
%                 Note that after the 'prepare_next_trial' call, further
%              events may still occur in the RTLSM while your protocol is thinking,
%              before the new StateMachine diagram gets sent. These events
%              will be available to you when 'trial_completed' is called on your
%              protocol (see below).
%
%   'trial_completed'   Called when 'state_0' is reached in the RTLSM,
%              marking final completion of a trial (and the start of
%              the next).
%
%   'close'    Called when the protocol is to be closed.
%
%
% VARIABLES THAT DISPATCHER WILL ALWAYS INSTANTIATE FOR YOU IN YOUR
% PROTOCOL:
%
% (These variables will be instantiated as regular Matlab variables,
% not SoloParamHandles. For any method in your protocol (i.e., an m-file
% within the @your_protocol directory) that takes "obj" as its first argument,
% calling "GetSoloFunctionArgs(obj)" will instantiate all the variables below.)
%
%
% n_done_trials     How many trials have been finished; when a trial reaches
%                   one of the prepare_next_trial states for the first
%                   time, this variable is incremented by 1.
%
% n_started trials  How many trials have been started. This variable gets
%                   incremented by 1 every time the state machine goes
%                   through state 0.
%
% parsed_events     The result of running disassemble.m, with the
%                   parsed_structure flag set to 1, on all events from the
%                   start of the current trial to now.
%
% latest_events     The result of running disassemble.m, with the
%                   parsed_structure flag set to 1, on all new events from
%                   the last time 'update' was called to now.
%
% raw_events        All the events obtained in the current trial, not parsed
%                   or disassembled, but raw as gotten from the State
%                   Machine object.
%
% current_assembler The StateMachineAssembler object that was used to
%                   generate the State Machine diagram in effect in the
%                   current trial.
%
% Trial-by-trial history of parsed_events, raw_events, and
% current_assembler, are automatically stored for you in your protocol by
% dispatcher.m. See the wiki documentation for information on how to access
% those histories from within your protocol and for information.
%
%

% -- Define globals for hardware --
%global sound_machine_server;
%global sound_sample_rate;


% If creating an empty object, return without further ado:
if nargin==0 || (nargin==1 && ischar(varargin{1}) && strcmp(varargin{1}, 'empty')),
    return;
end;

if isa(varargin{1}, mfilename), % If first arg is an object of this class itself, we are
    % Most likely responding to a callback from
    % a SoloParamHandle defined in this mfile.
    if length(varargin) < 2 || ~isstr(varargin{2}),
        error(['If called with a "%s" object as first arg, a second arg, a ' ...
            'string specifying the action, is required\n']);
    else action = varargin{2}; varargin = varargin(3:end);
    end;
else % Ok, regular call with first param being the action string.
    action = varargin{1}; varargin = varargin(2:end);
end;
if ~isstr(action), error('The action parameter must be a string'); end;

GetSoloFunctionArgs(obj);

%---------------------------------------------------------------
%   END OF SECTION COMMON TO ALL PROTOCOLS, MODIFY AFTER THIS LINE
%---------------------------------------------------------------
%

%Every time we call this protocol, check for any updates to the pole
%properties that the user has made in the MotorsSection table
if strcmp(action, 'init')==0
    %check for table updates
    MotorsSection(obj,'poll_table_and_update');
end

switch action
    
    case 'init'
        
        % Make default figure. We remember to make it non-saveable; on next run
        % the handle to this figure might be different, and we don't want to
        % overwrite it when someone does load_data and some old value of the
        % fig handle was stored as SoloParamHandle "myfig"
        SoloParamHandle(obj, 'myfig', 'saveable', 0); myfig.value = figure;
        
        % Give close.m access to myfig, so that upon closure the figure may be
        % deleted:
        SoloFunctionAddVars('close', 'rw_args', 'myfig');
        
        % Give MotorsSection.m, SMControlSection.m, etc access to myfig, so that they can switch active fig back
        % upon opening/closing their own windows:
        SoloFunctionAddVars('MotorsSection', 'rw_args', 'myfig');
        SoloFunctionAddVars('AnalysisSection', 'rw_args', 'myfig');
        SoloFunctionAddVars('NotesSection', 'rw_args', 'myfig');
        SoloFunctionAddVars('TrialStructureSection', 'rw_args', 'myfig');
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%make a default (empty) set of active pole positions%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        
        active_locations.thetapoint = [0 0];
        %active_locations.current= [0 0]; %deprecated?
        active_locations.coords{1} = [0 0]; %deprecated?
        active_locations.axial_positions{1}=[0]; %one active point at the origin
        active_locations.radial_positions{1}=[0]; %one active point at the origin
        active_locations.id{1}=1;
        active_locations.thetapos{1}=[0];
        active_locations.name{1} = ['pos_' num2str(1)];
        active_locations.cue_name{1} = 'cue_1';
        active_locations.cue_id{1} = 1;
        active_locations.go_nogo{1} = 'go';
        active_locations.pr{1} = 1; %default is uniform sampling. change in motor gui
        active_locations.mismatch_pr{1} = [0 0 0 0]; %values for location, reward, action threshold, cue
        active_locations.handle_name{1} = 'handle';
        active_locations.handle_num{1} = [];
        active_locations.appearances{1} = 0;
        active_locations.hits{1} = 0;
        active_locations.miss{1} = 0;
        active_locations.CRs{1} = 0;
        active_locations.FAs{1} = 0;
        active_locations.responses{1} = 0;
        active_locations.rewXr{1} = 1;
        active_locations.actionThreshXr{1} = 1;
        active_locations.punishOn{1} = 0;
        active_locations.enabled{1} = 1;
        active_locations.answerAction{1} = 'lick';
        active_locations.sampleAction{1} = 'none';
        active_locations.isStimTrial{1} = 0;
        active_locations.stimEpochId{1}=0;
        active_locations.isMismatchTrial{1} = [0 0 0 0]; %values for location, reward, and action threshold, and cue
        active_locations.mismatchId{1} = [0 0 0 0]; %values for id of mismatched location, reward, action thresholds, and cues
        
        %make this a SoloParamHAndle, and give the protocal access to it
        
        SoloParamHandle(obj,'active_locations','value',active_locations,'type','saveable_nonui','saveable',1);
        
        %make it global
        %DeclareGlobals(obj, 'rw_args', {'active_locations'});
        SoloFunctionAddVars('TrialStructureSection','rw_args','active_locations');
        SoloFunctionAddVars('MotorsSection','rw_args','active_locations');
        SoloFunctionAddVars('StateMatrixSection','rw_args','active_locations');
        SoloFunctionAddVars('SoundSection','rw_args','active_locations');
        SoloFunctionAddVars('AnalysisSection','rw_args','active_locations');
        
        %make a handle for the index of the current position
        SoloParamHandle(obj,'current_location_index','value',1,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'currentPolePosition','value',[0 0],'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'currentPoleId','value',1,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'currentPoleCueId','value',1,'type','saveable_nonui','saveable',1);
        %make them global
        DeclareGlobals(obj, 'rw_args', ...
            {'active_locations','current_location_index', 'currentPolePosition','currentPoleId','currentPoleCueId'});
        
        %TESTING MLTABLEPARAM
        %set params for mltable creation
        tblval.cell_data = {...
            'posn_1',  0, 0, 'go','cue_1', 1, 1, 0, 1, 0, 0, 0, 0;...
            '', [], [], '', '', [], [], [], [], [], [], [], [];...
            };
        
        tblval.columninfo.titles={'Name','Axial','Radial','Go-NoGo', 'Cue','Pr','Mism. Pr.','RewXr','TxThrshXr,' '# Appear.','Touch Pr.','Hit Pr.','Punish On'};
        tblval.columninfo.formats = {'%4.4g','%4.4g','%4.4g','%4.4g', '%4.4g', '%4.4g', '%4.4g','%4.4g','%4.4g','%4.4g','%4.4g','%4.4g', '%4.4g'};
        tblval.columninfo.weight =      [ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
        tblval.columninfo.multipliers = [ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
        tblval.columninfo.isEditable =  [ 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1];
        tblval.columninfo.isNumeric =   [ 0, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1];
        tblval.columninfo.withCheck = true; % optional to put checkboxes along left side
        tblval.columninfo.chkLabel = 'Use'; % optional col header for checkboxes
        tblval.rowHeight = 5;
        tblval.gFont.size=7;
        tblval.gFont.name='Helvetica';
        tblval.position = [20 40 200 500];
        
        x=50; y=50;
        
        %create a var table to display/store all pole properties in Motor
        %Secton
        
        %polesTbl will be a SoloParamHandle, which is an axis handle for the mltable
        % mlTableParam(obj,'polesTbl', 'tblval',tblval,x,y)
        
        %create a var for this tables handle too
        SoloParamHandle(obj,'tbl','value',tblval,'type','saveable_nonui','saveable',1); %table axis object  -
        
        % Make the title of the figure be the protocol name, and if someone tries
        % to close this figure, call Exper's ModuleClose function, so it'll know
        % to take it off Exper's list of open protocols.
        name = mfilename;
        set(value(myfig), 'Name', name, 'Tag', name, ...
            'closerequestfcn', ['ModuleClose(''' name ''')'], ...
            'NumberTitle', 'off', 'MenuBar', 'none');
        
        % Ok, at this point we have one SoloParamHandle, myfig
        
        % Let's put the figure where we want it and give it a reasonable size:
        set(value(myfig), 'Position', [100   400   1000   550]);
        figpos = get(gcf, 'Position');
        
        x=5; y=5; maxy=5;   %initial positions on main GUI window
        
        % SETTING SOME VARIABLES WITH HISTORY...DO THESE AUTO GET A
        % _history var in the save struct?
        
        SoloParamHandle(obj, 'MaxTrials','value',4000);
        SoloParamHandle(obj, 'HitHistory','value', [],'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'MissHistory','value', [],'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'FAHistory','value', [],'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'CRHistory','value', [],'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'SamplePeriodActionHistory','value', [],'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'ResponseHistory','value',[],'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'PunishHistory','value',[],'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'AnswerPeriodActionHistory','value',[],'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'AnswerHistory','value', [],'type','saveable_nonui','saveable',1);
        
        SoloFunctionAddVars('TrialStructureSection', 'rw_args', {'MaxTrials','SamplePeriodActionHistory'});
        
        SoloFunctionAddVars('AnalysisSection', 'rw_args', {'HitHistory', 'MissHistory','FAHistory',...
            'CRHistory', 'SamplePeriodActionHistory', 'ResponseHistory',...
            'PunishHistory','AnswerPeriodActionHistory','AnswerHistory'});
        
        SoloParamHandle(obj, 'AnswerMode','value',[],'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'ActionMode','value',[],'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'EmbCLogItemCounter','value',0,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'LastTrialEmbCLogItems','value',{},'type','saveable_nonui','saveable',1);
        
        %%SAVING SECTION
        %original
        %%REPORT CHANGES SECTION
        [x, y] = ReportChangesSection(obj,'init',x,y);
        next_row(y);
        
        [x,y]=SavingSection(obj,'init',x,y);
        SavingSection(obj,'set_autosave_frequency',1);
        
        %%NOTES SECTION
        [x,y]=NotesSection(obj,'init',x,y);
        next_row(y);
        
        %%SESSION MODEL SECTION
        if(USE_SESSIONMODEL)
            hackvar = 10; SoloFunctionAddVars('SessionModel', 'ro_args', 'hackvar');
            SessionDefinition(obj, 'init', x,y,value(myfig));
            thisbutton = get_ghandle(get_sphandle('name','savetom'));
            set(thisbutton,'Position',get(thisbutton,'Position')+[0,-20,0,0])
            next_row(y);
            next_row(y);
            SubheaderParam(obj, 'title', 'Session Model', x, y);
        end
        
        %%PLOTTING SECTION (USING PLUGINS/@pokesplit) STUFF, and ANALYSIS (DHO)
        %JPL - eventually want to wrap these into a single plot function
        
        next_row(y);
        
        if USE_POKESPLOT
            my_state_colors = struct(...
                'delay',                      [0.75 0.75 1],...
                'cue_and_sample',             [0 0.5 1],...
                'answer_delay',               [0 1 0],...
                'answer_period',              [1 1 0.5],...
                'valve',                      [0 1 0.5],...
                'drink',                      [1 0 1],...
                'hit',                        [1 1 1],...
                'miss',                       [0.5 0 0],...
                'false_alarm',                [0 0 0],...
                'correct_rejection',          [0.5 1 0.5],...
                'punish',                     [0.25 0.75 1]);
            
            my_poke_colors=struct( ...
                'Lin',                      0.6*[1 0.66 0],    ...
                'Rin',                      [0 0 0],       ...
                'TouchIn',                  0.9*[1 0.66 0]);
            
            [x, y] = PokesPlotSection(obj, 'init', x, y, ...
                struct('states',  my_state_colors, 'pokes', my_poke_colors));
            
            ThisSPH=get_sphandle('owner', mfilename, 'name','trial_limits'); ThisSPH{1}.value = 'last n';
            ThisSPH=get_sphandle('owner', mfilename, 'name','alignon'); ThisSPH{1}.value = 'play_cue(1,1)';
            ThisSPH=get_sphandle('owner', mfilename, 'name','t0'); ThisSPH{1}.value = 0;
            ThisSPH=get_sphandle('owner', mfilename, 'name','t1'); ThisSPH{1}.value = 16;
            
        end
        
        SubheaderParam(obj, 'title', 'Plotting', x, y);
        
        %%ANALYSIS SECTION
        [x, y] = AnalysisSection(obj, 'init', x, y);
        
        
        %%REINFORCEMENT SECTION
        if(USE_REINFORCEMENT)
            %not supported yet - JPL
            %SoloFunctionAddVars('reinforcement', 'rw_args', 1);
        end
        
        %%DISTRIBUTION SECTION
        if(USE_DISTRIBUI)
            %not supported yet - JPL
            %SoloFunctionAddVars('distribui', 'rw_args', 1);
        end
        
        y=5;x=220;
        
        %Timeout/Punishment control - WRAP INTO A SEPERATE FUNCTION
        MenuParam(obj, 'InitFail', {'do nothing' 'timeout' 'timeout (persist)' 'noise' 'puff' 'noise+ITI'}, 'do nothing', x, y,...
            'label','InitFail');
        next_row(y);
        MenuParam(obj, 'SampleDelayFail', {'do nothing' 'timeout' 'timeout (persist)' 'noise' 'puff' 'noise+ITI'}, 'do nothing', x, y,...
            'label','SampleDelayFail');
        next_row(y);
        MenuParam(obj, 'SampleFail', {'do nothing' 'timeout' 'timeout (persist)' 'noise' 'puff' 'noise+ITI'}, 'do nothing', x, y,...
            'label','SampleFail');
        next_row(y);
        MenuParam(obj, 'AnswerDelayFail', {'do nothing' 'timeout' 'timeout (persist)' 'noise' 'puff' 'noise+ITI'}, 'do nothing', x, y,...
            'label','AnswerDelayFail');
        next_row(y);
        MenuParam(obj, 'AnswerFail', {'do nothing' 'timeout' 'timeout (persist)' 'noise' 'puff' 'noise+ITI'}, 'do nothing', x, y,...
            'label','AnswerFail');
        next_row(y);
        
        
        %%SESSION TYPE SECTION
        %get the session type into this function
        [x, y] = SessionTypeSection(obj, 'init', x, y);
        next_row(y);
        
        %%STIM PARAM SECTION
        [x, y] = StimParamSection(obj, 'init', x, y);
        next_row(y,1.5);
        
        
        % ----------------------- TrialStructureSection ----------------------
        %SoloParamHandle(obj, 'previous_stim_types', 'value', [] ,'type','saveable_nonui');   %for stimulus type
        SoloParamHandle(obj, 'previous_stim_types', 'value', {} ,'type','saveable_nonui','saveable',1);   %for stimulus type
        SoloParamHandle(obj, 'previous_types', 'value', {},'type','saveable_nonui','saveable',1);      %go/no-go, predict or mismatch, etc
        SoloParamHandle(obj, 'previous_sides', 'value', {},'type','saveable_nonui','saveable',1);      %left/right, e.g. 'relevance'
        SoloParamHandle(obj, 'previous_positions', 'value', {},'type','saveable_nonui','saveable',1);   %previous pole positions
        SoloParamHandle(obj, 'previous_positions_id', 'value', {},'type','saveable_nonui','saveable',1);%numerical id of positions oin the active positions list
        SoloParamHandle(obj, 'previous_predictions', 'value', {},'type','saveable_nonui','saveable',1); %previous prediction trials
        SoloParamHandle(obj, 'previous_predictions_actionXr', 'value', {},'type','saveable_nonui','saveable',1); %previous prediction trials
        SoloParamHandle(obj, 'previous_predictions_rewXr', 'value', {},'type','saveable_nonui','saveable',1); %previous prediction trials
        SoloParamHandle(obj, 'previous_predictions_cue', 'value', {},'type','saveable_nonui','saveable',1); %previous prediction trials
        SoloParamHandle(obj, 'previous_trial_types', 'value', {},'type','saveable_nonui','saveable',1);  %all together no
        
        SoloParamHandle(obj, 'next_side','type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'next_type','type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'next_axial_pos','type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'next_radial_pos','type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'next_init_pos','type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'next_stim_type','type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'next_stim_epoch','type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'next_predict','type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'next_predict_actionXr','type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'next_predict_rewXr','type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'next_predict_cue','type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'next_pos_id','type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'next_mismatch_id','type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'next_cue_mismatch_id','type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'next_rewXr_mismatch_id','type','saveable_nonui','saveable',1);
        SoloParamHandle(obj, 'next_actXr_mismatch_id','type','saveable_nonui','saveable',1);

        SoloParamHandle(obj, 'next_trial_type','type','saveable_nonui','saveable',1);
        
        %Give StateMatrixSection acces to what it needs
        SoloFunctionAddVars('StateMatrixSection', 'rw_args', {'next_side'...
            ,'next_type','next_stim_type','next_stim_epoch','next_predict','next_predict_rewXr',...
            'next_predict_actionXr','next_predict_cue','next_axial_pos','next_cue_mismatch_id',...
            'next_radial_pos','next_init_pos','next_pos_id'});
        
        %Give MotorsSection acces to what it needs
        SoloFunctionAddVars('MotorsSection', 'rw_args', {'next_axial_pos',...
            'next_radial_pos','next_init_pos','next_side','next_type','next_pos_id','next_predict','next_mismatch_id','next_stim_type'});
        
        %Give read-only access to AnalysisSection.m:
        SoloFunctionAddVars('AnalysisSection', 'rw_args', {'previous_trial_types'...
            ,'previous_types','previous_sides','previous_positions',...
            'previous_predictions','previous_positions_id'});
        
        %Give TrialStuctureSection acces to what it needs
        SoloFunctionAddVars('TrialStructureSection', 'rw_args', {'next_side',...
            'next_type','next_stim_type','next_predict','next_predict_rewXr',...
            'next_predict_actionXr','next_predict_cue','next_axial_pos','next_side',...
            'next_radial_pos','next_init_pos','next_pos_id','next_mismatch_id','next_trial_type','next_stim_epoch',...
            'next_rewXr_mismatch_id','next_actXr_mismatch_id','next_cue_mismatch_id',...
            'previous_sides','previous_stim_types','previous_types','previous_positions',...
            'previous_positions_id','previous_predictions','previous_predictions_rewXr',...
            'previous_predictions_actionXr','previous_predictions_cue','previous_trial_types'});
        
        [x, y] = TrialStructureSection(obj, 'init', x, y);
        next_row(y);
        SubheaderParam(obj, 'title', 'Trial Structure', x, y);
        x_for_motor=x;y_for_motor=y;
        
        next_column(x);y=2;
        
        %%TIMES SECTION
        [x, y] = TimesSection(obj, 'init', x, y);
        
        SubheaderParam(obj, 'title', 'Times Section', x, y);
        next_row(y,1.5);
        
        %SMALL SECTION FOR SETTING SOME ONLINE WHISKER SETTINS
        %maybe need more eventually?
        
        NumeditParam(obj, 'AngularRange', 120, x, y, 'TooltipString',...
            'Range of whisker angles we are computing, in degrees.');
        next_row(y,1.5);
        
        NumeditParam(obj, 'VelocityThresh', 0.1, x, y, 'TooltipString',...
            'whisker velocity threshold, in degress/S.');
        
        next_row(y,1.5);
        SubheaderParam(obj, 'title', 'Whisker Track Settings', x, y);
        
        %%AUTOMATION SECTION
        %SoloParamHandle(obj, 'AutomationCommands', 'value', '');
        %SoloFunctionAddVars('AutomationSection', 'rw_args', {'AutomationCommands'});
        %[x, y] = AutomationSection(obj,'init',x,y);
        %SubheaderParam(obj, 'title', 'Automated Changes', x, y);
        
        next_column(x); y = 2;
        
        %JPL - hide/sjow option for this, seperate gui, eventually!
        
        SoloFunctionAddVars('SoundSection', 'rw_args',{'MaxTrials','active_locations'});
        
        [x, y] = SoundSection(obj, 'init', x, y);
        
        %%%SOUND TOOLS SUBSECTION
        %SOUNDTABLE
        if(USE_SOUNDTABLE)
            %not supported yet - JPL
            %SoloFunctionAddVars('soundtable', 'rw_args', 1);
        end
        
        %SOUNDUI
        if(USE_SOUNDUI)
            %not supported yet - JPL
            %SoloFunctionAddVars('soundui', 'rw_args', 1);
        end
        
        %CLICKSTABLE
        if(USE_CLICKSTABLE)
            %not supported yet - JPL
            %SoloFunctionAddVars('clickstable', 'rw_args', 1);
        end
        
        %%%MOTORS SECTION
        SoloFunctionAddVars('MotorsSection', 'rw_args',...
            {'MaxTrials','current_location_index', ...
            'currentPolePosition','currentPoleId','currentPoleCueId',...
            'tbl'});
        
        [x, y] = MotorsSection(obj, 'init', x_for_motor, y_for_motor);
        %next_column(x); y = 2;
        
        
        %%SET UP VARS FOR RETURNING STUFF FROM EMBC LOG
        %SoloParamHandle(obj,'absdiff1', 'value', 0,'type','saveable_nonui');
        %SoloParamHandle(obj,'absdiff1_t', 'value', 0,'type','saveable_nonui');
        SoloParamHandle(obj,'whiskang', 'value', 0,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'whiskang_t', 'value', 0,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'whiskang_trial', 'value', 0,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'touch_pro_on', 'value', 0,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'touch_pro_on_t', 'value', 0,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'touch_pro_on_trial', 'value', 0,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'touch_pro_off', 'value', 0,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'touch_pro_off_t', 'value', 0,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'touch_pro_off_trial', 'value', 0,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'touch_ret_on', 'value', 0,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'touch_ret_on_t', 'value', 0,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'touch_ret_on_trial', 'value', 0,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'touch_ret_off', 'value', 0,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'touch_ret_off_t', 'value', 0,'type','saveable_nonui','saveable',1);
        SoloParamHandle(obj,'touch_ret_off_trial', 'value', 0,'type','saveable_nonui','saveable',1);
        
        %%%-------- %PREPARE FOR TRIAL INITATION
        SoloFunctionAddVars('StateMatrixSection', 'rw_args',...
            {'AnswerMode','ActionMode','InitFail','SampleDelayFail','SampleFail',...
            'AnswerDelayFail','AnswerFail'});
        
        % ----------------------  Prepare first (empty) trial ---------------------
        sma = StateMachineAssembler('full_trial_structure');
        sma = add_state(sma, 'name', 'final_state', ...
            'self_timer', 2, 'input_to_statechange', {'Tup', 'check_next_trial_ready'});
        %dispatcher('send_assembler', sma, 'check_next_trial_ready');
        
        % Make the main figure window as wide as it needs to be and as tall as
        % it needs to be; that way, no matter what each plugin requires in terms of
        % space, we always have enough space for it.
        maxy = max(y, maxy);
        pos = get(value(myfig), 'Position');
        
    case 'trial_completed'  %AKA state35??
        
        %update Analysis Section, and get varLog data
        %       tmpVarLog= get_value('varLog');
        
        if(value(n_completed_trials)>=1)
            
%            AnalysisSection(obj,'update');
            
            %embc stuff
            
            %             whiskang.value = cell2mat(tmpVarLog(strcmp('whiskang',tmpVarLog(:,2)),3));
            %             whiskang_t.value = cell2mat(tmpVarLog(strcmp('whiskang',tmpVarLog(:,2)),1));
            %             %convert from 0:3.3V signal to +/- degrees, as set in Arduino
            %             %rescale, and then zero bu subtrating off half the full range
            %             whiskang.value=((value(whiskang)./(3.3)).*value(AngularRange))-(value(AngularRange))/2;
            %             whiskang_trial.value = repmat(n_completed_trials, size(cell2mat(tmpVarLog(strcmp('whiskang',tmpVarLog(:,2)),1))));
            %             %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %
            %             touch_pro_on.value = cell2mat(tmpVarLog(strcmp('touch_pro_on',tmpVarLog(:,2)),3));
            %             touch_pro_on_t.value = cell2mat(tmpVarLog(strcmp('touch_pro_on',tmpVarLog(:,2)),1));
            %             touch_pro_on_trial.value = repmat(n_completed_trials, size(cell2mat(tmpVarLog(strcmp('touch_pro_on',tmpVarLog(:,2)),3))));
            %             %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %
            %             touch_pro_off.value = cell2mat(tmpVarLog(strcmp('touch_pro_off',tmpVarLog(:,2)),3));
            %             touch_pro_off_t.value = cell2mat(tmpVarLog(strcmp('touch_pro_off',tmpVarLog(:,2)),1));
            %             touch_pro_off_trial.value = repmat(n_completed_trials, size(cell2mat(tmpVarLog(strcmp('touch_pro_off',tmpVarLog(:,2)),3))));
            %             %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %
            %             touch_ret_on.value = cell2mat(tmpVarLog(strcmp('touch_ret_on',tmpVarLog(:,2)),3));
            %             touch_ret_on_t.value = cell2mat(tmpVarLog(strcmp('touch_ret_on',tmpVarLog(:,2)),1));
            %             touch_ret_on_trial.value = repmat(n_completed_trials, size(cell2mat(tmpVarLog(strcmp('touch_ret_on',tmpVarLog(:,2)),3))));
            %             %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %
            %             touch_ret_off.value = cell2mat(tmpVarLog(strcmp('touch_ret_off',tmpVarLog(:,2)),3));
            %             touch_ret_off_t.value = cell2mat(tmpVarLog(strcmp('touch_ret_off',tmpVarLog(:,2)),1));
            %             touch_ret_off_trial.value = repmat(n_completed_trials, size(cell2mat(tmpVarLog(strcmp('touch_ret_off',tmpVarLog(:,2)),3))));
            
            
            %figure(1000);scatter(value(n_completed_trials),median(value(whiskang)),'k');hold on;
            %scatter(value(n_completed_trials),mean(value(whiskang)),'r');hold on;
            %axis([0 700 -30 30])
            
        end
        
        %save data...maybe better to do this ealier?
        %SavingSection(obj,'autosave_data');
        tic
        EndTimeCount = toc;
        if(SHOW_ELAPSED_TIME)
            fprintf('Elapsed Time [prepare_next_trial]: %0.6f sec\n',EndTimeCount);
        end
        
    case 'prepare_next_trial'
        tic;
        
        %update all active plots
        feval(mfilename, 'update');
        
        %push_history(active_locations) %this works for indiv vars
        active_locations_tmp=value(active_locations);
        
        %really annoying behavior...why??? fix it here as a hack for now
        if  iscell(value(previous_positions_id))
            previous_positions_id.value=1;
        end
        
        
        if(value(n_completed_trials)>=1)
            my_parsed_events = disassemble(current_assembler, raw_events, 'parsed_structure', 1);
            
            if(~isempty(parsed_events.states.hit))
                HitHistory.value = 1;
                MissHistory.value = 0;
                FAHistory.value = 0;
                CRHistory.value = 0;
                active_locations_tmp.hits{value(previous_positions_id)}= active_locations_tmp.hits{value(previous_positions_id)}+1;
            elseif(~isempty(parsed_events.states.false_alarm))
                HitHistory.value = 0;
                MissHistory.value = 0;
                FAHistory.value = 1;
                CRHistory.value = 0;
                active_locations_tmp.FAs{value(previous_positions_id)}= active_locations_tmp.FAs{value(previous_positions_id)}+1;
            elseif(~isempty(parsed_events.states.miss))
                HitHistory.value = 0;
                MissHistory.value = 1;
                FAHistory.value = 0;
                CRHistory.value = 0;
                active_locations_tmp.miss{value(previous_positions_id)}= active_locations_tmp.miss{value(previous_positions_id)}+1;
            elseif(~isempty(parsed_events.states.correct_rejection))
                HitHistory.value = 0;
                MissHistory.value = 0;
                FAHistory.value = 0;
                CRHistory.value = 1;
                active_locations_tmp.CRs{value(previous_positions_id)}= active_locations_tmp.CRs{value(previous_positions_id)}+1;
            elseif (~isempty(parsed_events.states.noresponse))
                HitHistory.value = 0;
                MissHistory.value = 0;
                FAHistory.value = 0;
                CRHistory.value = 0;
            else
                HitHistory.value = 0;
                MissHistory.value = 0;
                FAHistory.value = 0;
                CRHistory.value = 0;
            end
            if(~isempty(parsed_events.states.punish))
                PunishHistory.value = 1;
            else
                PunishHistory.value = 0;
            end
            
            %actions made during the sample period, that led to the
            %sampling period not timing out?
            
            if ~isempty(parsed_events.states.answer_delay)
                SamplePeriodActionHistory.value = 1;
                active_locations_tmp.responses(value(previous_positions_id))={cell2mat(value(active_locations_tmp.responses(value(previous_positions_id))))+1};
            else isempty(parsed_events.states.answer_delay)
                SamplePeriodActionHistory.value = 0;
            end
            
            %Did he make a RESPONSE (e.g. do something in the ANSWER
            %PERIOD)
            if ~isempty(parsed_events.states.noresponse)
                ResponseHistory.value = 0;
            else
                ResponseHistory.value = 1;
            end
        end
        
        active_locations.value=active_locations_tmp;
        
        %figure out params for next truials
        TrialStructureSection(obj,'choose_next_trial_type');
        
        %move motors
        MotorsSection(obj,'move_next_side');
        EndTimeCount = toc;
        
        if EndTimeCount<get_value('MinimumITI')
            %JPL - adding in a small random pause from 0 to 1s to ensure
            %there is a random ITI, which helps scan image alingn to ephus
            pause(get_value('MinimumITI') - EndTimeCount+ (0+1*rand(1)));
        end
        
        % -- Create and send state matrix for next trial --
        StateMatrixSection(obj,'update');
        
        
        if(SHOW_ELAPSED_TIME)
            fprintf('Elapsed Time [trial_completed]: %0.6f sec\n',EndTimeCount);
            fprintf('---------------- Ready for Trial #%d ----------------\n',n_done_trials);
        end
        
        
    case 'update'
        if(USE_POKESPLOT)
            PokesPlotSection(obj, 'update');
        end
        
    case 'close'
        PokesPlotSection(obj, 'close');
        if exist('myfig', 'var') && isa(myfig, 'SoloParamHandle') && ishandle(value(myfig)),
            delete(value(myfig));
        end;
        delete_sphandle('owner', ['^@' class(obj) '$']);
        
    otherwise
        warning(['Unknown action! "%s"\n', action]);
end



