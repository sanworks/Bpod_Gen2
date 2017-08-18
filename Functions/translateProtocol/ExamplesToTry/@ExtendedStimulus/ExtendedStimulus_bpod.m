% ExtendedStimulus_bpod is a protocol that can cycle f1/f2 stimuli repeatedly
% until a decision is made; it is designed to train on the Romo and
% Romo-like tasks (for example, the same-different task)

% BWB, August 2007

function [obj] = ExtendedStimulus_bpod(varargin)

% Default object is of our own class (mfilename); 
% we inherit only from Plugins

obj = class(struct, mfilename, saveload, water, ...
    pokesplot, sessionmodel, soundmanager, soundui, f1f2plot, punishui, ...
    comments, sqlsummary);

%---------------------------------------------------------------
%   BEGIN SECTION COMMON TO ALL PROTOCOLS, DO NOT MODIFY
%---------------------------------------------------------------

% If creating an empty object, return without further ado:
if nargin==0 || (nargin==1 && ischar(varargin{1}) && strcmp(varargin{1}, 'empty')), 
   return; 
end;

if isa(varargin{1}, mfilename), % If first arg is an object of this class itself, we are 
                                % Most likely responding to a callback from  
                                % a SoloParamHandle defined in this mfile.
  if length(varargin) < 2 || ~ischar(varargin{2}), 
    error(['If called with a "%s" object as first arg, a second arg, a ' ...
      'string specifying the action, is required\n']);
  else action = varargin{2}; varargin = varargin(3:end); %#ok<NASGU>
  end;
else % Ok, regular call with first param being the action string.
       action = varargin{1}; varargin = varargin(2:end); %#ok<NASGU>
end;

GetSoloFunctionArgs(obj);

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
%   'prepare_next_trial'  Called when a trial has ended and your protocol is expected
%              to produce the StateMachine diagram for the next trial;
%              i.e., somewhere in your protocol's response to this call, it
%              should call "dispatcher('send_assembler', sma,
%              prepare_next_trial_set);" where sma is the
%              StateMachineAssembler object that you have prepared and
%              prepare_next_trial_set is either a single string or a cell
%              with elements that are all strings. These strings should
%              correspond to names of states in sma.
%                 Note that after the prepare_next_trial call, further
%              events may still occur while your protocol is thinking,
%              before the new StateMachine diagram gets sent. These events
%              will be available to you when 'state0' is called on your
%              protocol (see below).
%
%   'trial_completed'   Called when the any of the prepare_next_trial set
%              of states is reached.
%
%   'close'    Called when the protocol is to be closed.
%
%
% VARIABLES THAT DISPATCHER WILL ALWAYS INSTANTIATE FOR YOU AS READ_ONLY
% GLOBALS IN YOUR PROTOCOL:
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
% dispatcher.m. 
%
% 


switch action,

  %---------------------------------------------------------------
  %          CASE INIT
  %---------------------------------------------------------------
  
  case 'init'
	getSessID(obj);
    dispatcher('set_trialnum_indicator_flag');
    %   Make default figure. We remember to make it non-saveable; on next run
    %   the handle to this figure might be different, and we don't want to
    %   overwrite it when someone does load_data and some old value of the
    %   fig handle was stored as SoloParamHandle "myfig"
    SoloParamHandle(obj, 'myfig', 'saveable', 0); myfig.value = figure;

    %   Make the title of the figure be the protocol name, and if someone tries
    %   to close this figure, call dispatcher's close_protocol function, so 
    %   it'll know to take it off the list of open protocols.
    name = mfilename;
    set(value(myfig), 'Name', name, 'Tag', name, ...
      'closerequestfcn', 'dispatcher(''close_protocol'')', 'MenuBar', 'none');


    % Ok, gotta figure out what this hack variable is doing here, why we need
    % it, and how to do without it. For now, though, if you want to use
    % SessionModel...
    hackvar = 10; SoloFunctionAddVars('SessionModel', 'ro_args', 'hackvar'); %#ok<NASGU>

    %   Put the figure where we want it and give it a reasonable size
    set(value(myfig), 'Position', [400 100   850 570]);

    %   ----------------------
    %   Let's declare some globals that everybody is likely to want to know about.
    %   ----------------------    
    
    %   History of hit/miss:
    SoloParamHandle(obj, 'hit_history',      'value', []);
    DeclareGlobals(obj, 'ro_args', 'hit_history');

    %   Let RewardsSection, the part that parses what happened at the end of
    %   a trial, write to hit_history:
    SoloFunctionAddVars('RewardsSection', 'rw_args', 'hit_history');

    % From Plugins/@soundmanager:
    SoundManagerSection(obj, 'init');
    
    
    %   ----------------------
    %   Set up the main GUI window
    %   ----------------------
    x = 5; y = 5; maxy=5;     % Initial position on main GUI window
    
    % COLUMN 1
    %   From Plugins/@saveload:
    [x, y] = SavingSection(obj, 'init', x, y);

    %   From Plugins/@water:
    [x, y] = WaterValvesSection(obj, 'init', x, y, 'streak_gui', 1);
    
    [x, y] = SidesSection(obj, 'init', x, y);
    
    maxy = max(y, maxy); next_column(x); y=5;
    
    % COLUMN 2
    % From Plugins/@antibias:
    [x, y] = AntibiasSection(obj, 'init', x, y);
    
    [x, y] = RewardsSection(obj, 'init', x, y);
    
    maxy = max(y, maxy); next_column(x); y=5;

    % COLUMN 3
    [x, y] = StimulusSection(obj, 'init', x, y);
    
    maxy = max(y, maxy); next_column(x); y=5;
        
    % COLUMN 4
    [x, y] = TimesSection(obj, 'init', x, y);
    
    [x, y] = PenaltySection(obj, 'init', x, y);
    
    SC = state_colors(obj);
    [x, y] = PokesPlotSection(obj, 'init', x, y, ...
      struct('states',  SC));
    PokesPlotSection(obj, 'set_alignon', 'center_to_side_gap(1,1)');
  
    [x, y] = F1F2PlotSection(obj, 'init', x, y);
    ToggleParam(obj, 'skip_f1f2_auto_redraw', 0, x, y, ...
      'position', [x y 120 20], 'OnString', ...
      'Skip F1F2 redraw', 'OffString', 'Normal F1F2', 'TooltipString', ...
      sprintf(['\nF1F2PlotSection currently plots each different frequency separately.' ...
      '\nWhen adaptively changing frequencies, every trial is different and that can make' ...
      '\nfor VERY slow plotting. Setting this toggle to ON skips the suto plotting. Click' ...
      '\nredraw to make it plot.'])); next_row(y);
    
    next_row(y);      
    
    [x, y] = CommentsSection(obj, 'init', x, y);
    SessionDefinition(obj, 'init', x, y, value(myfig));
    
    
%     maxy = 700;
%     
%     % Make the main figure window as wide as it needs to be and as tall as
%     % it needs to be; that way, no matter what each plugin requires in terms of
%     % space, we always have enough space for it.
%     pos = get(value(myfig), 'Position');
%     set(value(myfig), 'Position', [pos(1:2) x+240 maxy+25]);



    figpos = get(gcf, 'Position');
    [expmtr, rname]=SavingSection(obj, 'get_info');
    HeaderParam(obj, 'prot_title', ['ExtendedStimulus_bpod: ' expmtr ', ' rname], ...
            x, y, 'position', [10 figpos(4)-25, 800 20]);
    
    StateMatrixSection(obj, 'init');
    
    
  %---------------------------------------------------------------
  %          CASE PREPARE_NEXT_TRIAL
  %---------------------------------------------------------------
  case 'prepare_next_trial'
    nTrials.value = n_done_trials;
    
    [e, r] = SavingSection(ExtendedStimulus_bpod, 'get_info');
    if isequal(e, 'Carlos') && ismember(r, {'C009' 'C010'}),
      debugging = 0;
      if debugging, 
          datadir = bSettings('get', 'GENERAL', 'Main_Data_Directory');
          fp = fopen([datadir filesep 'Data' filesep e filesep r filesep 'debugging.log'], 'a');
          if n_done_trials == 1,
             fprintf(fp, '\n\n------------------------------\n\n');
             fprintf(fp, 'Starting rat %s/%s, date %s, rig %s\n\n\n', e, r, yearmonthday, get_hostname);
          end;
          fprintf(fp, '*** n_done_trials = %d ***\n', n_done_trials);
          start_time = clock;
      end;
    else
      debugging = 0;
    end;
    % counting trials and hits
    if debugging, fprintf(fp, 'About to do RewardsSection, etime=%g\n', etime(clock, start_time)); end;
    RewardsSection(obj, 'update');
    if debugging, fprintf(fp, 'About to do StimulusSection, etime=%g\n', etime(clock, start_time)); end;
    if StimulusSection(obj, 'get_sounds_on') && n_done_trials > 0,
      if debugging, fprintf(fp, 'About to do F1F2PlotSection, etime=%g\n', etime(clock, start_time)); end;
        F1F2PlotSection(obj, 'add_trial', StimulusSection(obj, 'get_this_side_pair'), ...
            SidesSection(obj, 'get_current_side'), hit_history(n_done_trials), ...
            'skip_auto_redraw', value(skip_f1f2_auto_redraw));
    end;
    
    % evaluates the training string to prepare for the next trial
    if debugging, fprintf(fp, 'About to do SessionDefinition, etime=%g\n', etime(clock, start_time)); end;
    SessionDefinition(obj, 'next_trial');
        
    if debugging, fprintf(fp, 'About to do AntibiasSection, etime=%g\n', etime(clock, start_time)); end;
    AntibiasSection(obj, 'update');
    if debugging, fprintf(fp, 'About to do TimeSection, etime=%g\n', etime(clock, start_time)); end;
    TimesSection(obj, 'compute_iti');

    
    % choose next side after antibias has computed posterior prob
    if debugging, fprintf(fp, 'About to do SidesSection, etime=%g\n', etime(clock, start_time)); end;
    SidesSection(obj, 'next_trial');
    if debugging, fprintf(fp, 'About to do StimulusSection, etime=%g\n', etime(clock, start_time)); end;
    StimulusSection(obj, 'next_trial');
    
    if debugging, fprintf(fp, 'About to do SidesSection, etime=%g\n', etime(clock, start_time)); end;
    SidesSection(obj, 'update_plot');

    if debugging, fprintf(fp, 'About to do SoundManagerSection, etime=%g\n', etime(clock, start_time)); end;
    SoundManagerSection(obj, 'send_not_yet_uploaded_sounds');
 
    % make next state matrix
    if debugging, fprintf(fp, 'About to do StateMatrixSection, etime=%g\n', etime(clock, start_time)); end;
    StateMatrixSection(obj, 'next_trial');
    
    % invoke autosave
    if debugging, fprintf(fp, 'About to do SavingSection, etime=%g\n', etime(clock, start_time)); end;
    SavingSection(obj, 'autosave_data');

    if n_done_trials==1
        [expmtr, rname]=SavingSection(obj, 'get_info');
        prot_title.value=['ExtendedStimulus_bpod on rig ' get_hostname ' : ' expmtr ', ' rname  '.  Started at ' datestr(now, 'HH:MM')];
    end

    if debugging, 
      fprintf(fp, 'Done with prepare_next_trial, etime=%g\n\n\n', etime(clock, start_time)); 
      fclose(fp);
    end;
    
  %---------------------------------------------------------------
  %          CASE TRIAL_COMPLETED
  %---------------------------------------------------------------
  case 'trial_completed'  
     
    % And PokesPlot needs completing the trial:
    PokesPlotSection(obj, 'trial_completed');

    if n_done_trials==1,
      CommentsSection(obj, 'append_date');
      CommentsSection(obj, 'append_line', '');
    end;
    CommentsSection(obj, 'clear_history'); % Make sure we're not storing unnecessary history
    
  %---------------------------------------------------------------
  %          CASE UPDATE
  %---------------------------------------------------------------
  case 'update'
    PokesPlotSection(obj, 'update');

    
    
  %---------------------------------------------------------------
  %          CASE CLOSE
  %---------------------------------------------------------------
  case 'close'
    PenaltySection(obj, 'close');
    StimulusSection(obj, 'close');
    PokesPlotSection(obj, 'close');
    F1F2PlotSection(obj, 'close');
    SessionDefinition(obj, 'delete');
    
    if exist('myfig', 'var') && isa(myfig, 'SoloParamHandle') && ishandle(value(myfig)), %#ok<NODEF>
      delete(value(myfig));
    end;
    
    try
        delete_sphandle('owner', ['^@' class(obj) '$']);
    catch
        warning('Some SoloParams were not properly cleaned up');
    end

  %---------------------------------------------------------------
  %          CASE END_SESSION
  %---------------------------------------------------------------
  case 'end_session'
     prot_title.value = [value(prot_title) ', Ended at ' datestr(now, 'HH:MM')]; %#ok<NODEF>
     StimulusSection(obj, 'end_session');  
          
     
     
  %---------------------------------------------------------------
  %          CASE PRE_SAVING_SETTINGS
  %---------------------------------------------------------------
  case 'pre_saving_settings'
    SessionDefinition(obj, 'run_eod_logic_without_saving');
    SidesSection(obj, 'make_and_send_summary');
    sendtrial(obj);
%     prev_sides = get_sphandle('name', 'previous_sides');
%     prev_sides = prev_sides{1}(1:length(hit_history));
%     sendsummary(obj, 'sides', prev_sides);
    
     
  %---------------------------------------------------------------
  %          CASE ????
  %---------------------------------------------------------------
    
  otherwise,
    warning('Unknown action! "%s"\n', action);
end;

return;


