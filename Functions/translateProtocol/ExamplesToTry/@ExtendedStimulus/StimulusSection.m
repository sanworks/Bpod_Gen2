% @ExtendedStimulus/StimulusSection.m
% Bing, August 2007

% [x, y] = YOUR_SECTION_NAME(obj, action, varargin)
%
% Section that takes care of YOUR HELP DESCRIPTION
%
% PARAMETERS:
% -----------
%
% obj      Default object argument.
%
% action   One of:
%            'init'      To initialise the section and set up the GUI
%                        for it
%
%            'reinit'    Delete all of this section's GUIs and data,
%                        and reinit, at the same position on the same
%                        figure as the original section GUI was placed.
%
% x, y     Relevant to action = 'init'; they indicate the initial
%          position to place the GUI at, in the current figure window
%
% RETURNS:
% --------
%
% [x, y]   When action == 'init', returns x and y, pixel positions on
%          the current figure, updated after placing of this section's GUI. 
%


function [x, y] = StimulusSection(obj, action, varargin)
   
GetSoloFunctionArgs;

switch action
  case 'init',
      x = varargin{1};
      y = varargin{2};
      
      % Save the figure and the position in the figure where we are going
      % to start adding GUI elements:
      SoloParamHandle(obj, 'my_gui_info', 'value', [x y gcf]);
      
%       % temporary counter variable, here until the Helper Var function in
%       % sessiondefinition is restored
%       SoloParamHandle(obj, 'counter', 'saveable', 0,'value', 0);
%       
%       % keeps track of block number during blocked sessions
%       SoloParamHandle(obj, 'n_block', 'saveable', 1, 'value', 0);
      
      
      % number of center pokes
      MenuParam(obj, 'n_center_pokes', {'0', '1', '2'}, 1, x, y, ...
          'labelfraction', 0.4, ...
          'TooltipString', 'Number of center pokes'); 
      next_row(y);
      set_callback(n_center_pokes, {mfilename, 'n_center_pokes'});
      
      MenuParam(obj, 'side_lights', {'correct side only', 'both sides on', 'both sides off'}, ...
          1, x, y, ...
          'labelfraction', 0.4, ...
          'TooltipString', 'Which side lights are turned on');
      next_row(y);
      
      % specify the stimuli
      NumeditParam(obj, 'InterCycleGap', 0.25, x, y, ...
          'TooltipString', sprintf(['Duration (in sec) of silent gap between the end of f2' ...
                                    '\nand the reinitiation of f1']));
      next_row(y);     
      NumeditParam(obj, 'f1f2Gap', 0.25, x, y, ...
          'TooltipString', 'Duration (in sec) of silent gap between f1 and f2 stimuli');
      next_row(y);

%       DispParam(obj, 'CycleDuration', 1, x, y, ...
%           'TooltipString', sprintf(['The total duration of one stimulus cycle' ...
%                                     '\n = f1_Dur + f1f2Gap + f2_Dur + InterCycleGap']));
%       next_row(y);
      
      NumeditParam(obj, 'Center2CenterGap', 0, x, y, ...
          'TooltipString', sprintf(['\nDuration (in sec) of pause between 1st center poke and turning ' ...
          '\non center light for 2nd center poke'])); next_row(y);
      disable(Center2CenterGap);  
      NumeditParam(obj, 'Center2SideGap', 0, x, y, ...
          'TooltipString', 'Duration (in sec) of pause between center poke and turning on side lights');
      next_row(y);
      NumeditParam(obj, 'Center2SideGap2', 0, x, y, ...
          'TooltipString', sprintf(['\nDuration (in sec) of a pause that follows Center2SideGap.' ...
          '\nDuring this pause, no punishments for pokings occur; which is in contrast to Center2SideGap,' ...
          '\nduring which punishments *can* be defined if so desired (see Penalties Panel).' ...
          '\n   If Center2SideGap2 is set to 0, the corresponding state never occurs.']));
      next_row(y);
      
      NumeditParam(obj, 'n_stimulus_cycles', 2, x, y, ...
          'TooltipString', sprintf(['Number of cycles the stimuli are repeated before they' ...
                                    '\nare turned off.']));
      next_row(y);
      DispParam(obj, 'StimulusDuration', 1.5, x, y, ...
          'TooltipString', sprintf(['Duration (in sec) that sounds are played before they are turned off' ...
                                    '\n = CycleDuration * n_stimulus_cycles']));
      next_row(y, 1);
      set_callback({InterCycleGap; f1f2Gap}, ...
                   {mfilename, 'make_sounds'; ...
                    mfilename, 'compute_cycle_repeats'});
      set_callback(n_stimulus_cycles, { ...
        mfilename, 'n_stimulus_cycles' ; ...
        mfilename, 'make_sounds' ; ...
        mfilename, 'compute_cycle_repeats' ; ...
        });   %#ok<NODEF>
      ToggleParam(obj, 'StimOffAtCpoke2', 0, x, y, ...
          'OffString', 'stim continues after cpoke2', ...
          'OnString',  'stim turns off at cpoke2', ...
          'TooltipString', 'If ON, the stimulus is turned off upon cpoke2; if OFF, stimulus off is governed by StimTimeStart toggle.');
      next_row(y);
      set_callback(StimOffAtCpoke2, {mfilename, 'StimOffAtCpoke2'});
      ToggleParam(obj, 'StimTimeStart', 0, x, y, 'position', [x+100 y 100 20], ...
        'OffString', 'FromStimStart', 'OnString', 'FromAnswerPoke', ...
        'TooltipString', sprintf(['\nFromStimStart means stimulus is timed by n_stimulus_cycles', ...
        '\nwhich start counting when the stimulus start. FromAnswerPoke means stimulus playes until' ...
        '\nthe number of seconds indicated at left after the correct response have elapsed.' ...
        '\nStimulus always ends when the error state is entered.']));
      NumeditParam(obj, 'FromAnswerPoke', 2, x, y, 'position', [x y 100 20], ...
        'labelfraction', 0.6, ...
        'TooltipString', sprintf(['\nNumber of seconds after correct response after which stimulus' ...
        '\nsound stops. Only valid if StimTimeStart (at right) is set to FromAnswerPoke']));
      set_callback(StimTimeStart, {mfilename, 'StimTimeStart'});
      SoloFunctionAddVars('StateMatrixSection', 'ro_args', {'StimTimeStart', 'FromAnswerPoke'});
      next_row(y);
      
      DispParam(obj, 'WaterMultiplier', 1, x, y, ...
          'TooltipString', 'The amount of water rewarded for a correct response to \nthis stimulus pair is the regular amount multiplied by this number');
%      ToggleParam(obj, 'LoopSound', 0, x, y, 'position', [x y 80 20], ...
%        'OnString', 'LoopSound', 'OffString', 'No loop sound', 'TooltipString', ...
%        sprintf(['\nLoopSound ==> Sound loops indefinitely!! Can''t be used unless you also set' ...
%        '\nStimTimeStart to FromAnswerPoke. No loop sound ==> sound plays only for specified num of cycles']));
      next_row(y);
        DispParam(obj, 'Durations', '', x, y, ...
          'TooltipString', 'f1_dur, f2_dur');
      next_row(y);    DispParam(obj, 'Frequencies', '', x, y, ...
          'TooltipString', 'f1_frq, f2_frq');
      next_row(y)
      
                
      DispParam(obj, 'PriProb', 0, x, y, 'position', [x y 100 20], ...
          'labelfraction', 0.5, ...
          'TooltipString', 'Prior probability of choosing this stimulus pair');
      DispParam(obj, 'PostProb', 0, x, y, 'position', [x+100 y 100 20], ...
          'labelfraction', 0.5, ...
          'TooltipString', 'Posterior probability of choosing this stimulus pair, taking antibias into account');
      next_row(y);
      
      DispParam(obj, 'CurrentPair', 1, x, y, ...
          'position', [x y 100 20], ...
          'labelfraction', 0.7, ...
          'TooltipString', 'Current stimulus pair used, corresponds to ttable in Sounds Panel');
      DispParam(obj, 'Side', 'l', x, y, 'position', [x+100 y 80 20], ...
          'labelfraction', 0.7);
      ToggleParam(obj, 'SoundsOn', 1, x, y, ...
          'position', [x+180, y, 20, 20], ...
          'OnString',  'On', ...
          'OffString', 'Off', ...
          'TooltipString', 'Turns stimulus sounds on/off');
      
      next_row(y);
      
      % This button shows up on the main window to open the SoundsPanel:
      ToggleParam(obj, 'sounds_button', 0, x, y, ...
          'OnString',  'Sounds Panel Showing', ...
          'OffString', 'Sounds Panel Hidden', ...
          'TooltipString', 'Show/Hide the window that controls stimulus sounds for the protocol');
      next_row(y);
      set_callback(sounds_button, {mfilename, 'window_toggle'});
      
      fig = gcf;
      oldx = x; oldy = y;
      
      % Now we set up the window that pops up to specify sounds:
      % --------------------------------------------------------
          SoloParamHandle(obj, 'mysoundfig', 'saveable', 0, 'value', ...
              figure('position', [409 500 630 285], ...
                     'MenuBar', 'none', ...
                     'NumberTitle', 'off', ...
                     'Name', 'ExtendedStimulus Sound Settings', ...
                     'CloseRequestFcn', [mfilename ...
                     '(' class(obj) ', ''hide_sound_window'');']));      

          y = 5; boty = 5;
      
          x = 10;
          PushbuttonParam(obj, 'add', x, y, 'position', [x y 100 20], ...
              'label', 'Add Pair');
          PushbuttonParam(obj, 'del', x, y, 'position', [x+100 y 100 20], ...
              'label', 'Delete Pair');
          PushbuttonParam(obj, 'up', x, y, 'position', [x+200 y 100 20], ...
              'label', 'Update Pair', ...
              'TooltipString', 'replaces the currently selected row with values in the gui elements above');
          PushbuttonParam(obj, 'play_snd', x, y, 'position', [x+310 y 80 20], ...
              'label', 'Play Sound');
          PushbuttonParam(obj, 'stop_snd', x, y, 'position', [x+390 y 80 20], ...
              'label', 'Stop Sound');
          NumeditParam(obj, 'snd_amp', 0.03, x, y, 'position', [x+510 y 100 20], ...
              'TooltipString', 'all sounds multiplied by this amplifying factor');
          set_callback(add, {mfilename, 'add_pair'});
          set_callback(del, {mfilename, 'delete_pair'});
          set_callback(up,  {mfilename, 'update_pair'});
          set_callback(play_snd, {mfilename, 'play_sound'});
          set_callback(stop_snd, {mfilename, 'stop_sound'});
          next_row(y);
          
          x = 5;
          col_wid = 90;
          NumeditParam(obj, 'pprob', 0.5, x, y, 'position', [x y col_wid 20], ...
              'labelfraction', 0.6, ...
              'TooltipString', 'Prior probability of choosing this stimulus pair; must be [0,1]');
          set_callback(pprob, {mfilename, 'pprob'});
          EditParam(obj, 'side', 'l', x, y, 'position', [x+col_wid y col_wid 20], ...
              'labelfraction', 0.6, ...
              'TooltipString', 'Correct side choice for this stimulus pair');
          set_callback(side, {mfilename, 'side'});
          NumeditParam(obj, 'f1_frq', 25, x, y, 'position', [x+2*col_wid y col_wid 20], ...
              'labelfraction', 0.6);
          NumeditParam(obj, 'f1_dur', 0.2, x, y, 'position', [x+3*col_wid y col_wid 20], ...
              'labelfraction', 0.6);
          NumeditParam(obj, 'f2_frq', 25, x, y, 'position', [x+4*col_wid y col_wid 20], ...
              'labelfraction', 0.6);
          NumeditParam(obj, 'f2_dur', 0.2, x, y, 'position', [x+5*col_wid y col_wid 20], ...
              'labelfraction', 0.6);
          NumeditParam(obj, 'wtr_ml', 1, x, y, 'position', [x+6*col_wid y col_wid 20], ...
              'labelfraction', 0.6, ...
              'TooltipString', 'The amount of reward water will be multiplied by this number for this stimulus pair');
          next_row(y,1.5);
          
          % the sph 'ttable' holds the rows of the sttable as a character
          % array
          % 'stttable' is the gui that displays what's held in ttable
          % 'stims' is a cell array that stores all the stimulus pairs in
          % use in a reasonable format
          SoloParamHandle(obj, 'ttable', 'value', ...
              {'PProb   R/L   f1_frq     f1_dur     f2_frq     f2_dur    wtr_mul'}, ...
              'saveable', 0);
          ListboxParam(obj, 'stttable', value(ttable), ...
              rows(value(ttable)), ...
              x, y, 'position', [x y 620 200], ...
              'FontName', 'Courier', 'FontSize', 14, ...
              'saveable', 0);
          set(get_ghandle(stttable), 'BackgroundColor', [255 240 255]/255);
          SoloParamHandle(obj, 'stims', 'value', {}, 'save_with_settings', 1);
          set_callback(stims, {mfilename, 'display_ttable'});
          set_callback_on_load(stims, 1);
          set_callback(stttable, {mfilename, 'stttable'});
          
          
          y = y+210;
          HeaderParam(obj, 'panel_title', 'Sound Stimulus Pairs', x, y, ...
            'position', [x y 140 20]);
          set(get_ghandle(panel_title), 'BackgroundColor', [215 190 200]/255);
          
          MenuParam(obj, 'sounds_type', {'Bups (Hz)', 'Pure Tones (KHz)', 'S Bups (Hz)'}, 1, x, y, ...
            'position', [x+145 y 200 20], ...
            'TooltipString', sprintf(['\nselects whether stimuli in the sounds panel' ...
            '\nare Bups or Pure Tones' ...
            '\nS Bups are 3 ms in width instead of the regular 5 ms']), 'labelfraction', 0.35, 'labelpos', 'left');
          set_callback(sounds_type, {mfilename, 'make_sounds'});      
          PushbuttonParam(obj, 'normal', x, y, 'position', [x+360 y 80 20], ...
              'label', 'Normalize PProb', ...
              'TooltipString', 'Normalizes the PProb (prior probabilities) column so that it sums to unity \nWhen RED, the sum is incorrect and this button needs to be pressed!'); 
          PushbuttonParam(obj, 'fsave', x, y, 'position', [x+460 y 80 20], ...
              'label', 'Save to File', ...
              'TooltipString', 'not yet implemented');
          PushbuttonParam(obj, 'fload', x, y, 'position', [x+540 y 80 20], ...
              'label', 'Load from File',...
              'TooltipString', 'not yet implemented');
          set_callback(normal, {mfilename, 'normalize'});
          
      % --------------------------------------------------------
           
      x = oldx; y = oldy; figure(fig);
      % This button shows up on the main window to open the BlocksPanel:
      ToggleParam(obj, 'blocks_button', 0, x, y, ...
          'OnString',  'Blocks Panel Showing', ...
          'OffString', 'Blocks Panel Hidden', ...
          'TooltipString', 'Show/Hide the window that contains block parameters');
      next_row(y);
      set_callback(blocks_button, {mfilename, 'window_toggle'});
      
      fig = gcf;
      oldx = x; oldy = y;
      
      % Now we set up the window that pops up to specify sounds:
      % --------------------------------------------------------
          SoloParamHandle(obj, 'myblockfig', 'saveable', 0, 'value', ...
              figure('position', [409 800 610 330], ...
                     'MenuBar', 'none', ...
                     'NumberTitle', 'off', ...
                     'Name', 'ExtendedStimulus Block Settings', ...
                     'CloseRequestFcn', [mfilename ...
                     '(' class(obj) ', ''hide_block_window'');']));      

          x = 5; y = 5; boty = 5;
         
          
          NumeditParam(obj, 'blk2_min_len', 18, x, y, ...
              'position', [x y 100 20], 'labelfraction', 0.65, ...
              'TooltipString', 'min length (in trials) of block 2');
          NumeditParam(obj, 'blk2_max_len', 18, x, y, ...
              'position', [x+100 y 100 20], 'labelfraction', 0.65, ...
              'TooltipString', 'max length (in trials) of block 2');  
          NumeditParam(obj, 'blk2_pprob', [0.5 0.5], x, y, ...
              'position', [x+200 y 200 20], ...
              'TooltipString', sprintf(['prior probabilities of the sounds in this block.' ...
                                        'should have as many elements as there are sounds']));
          EditParam(obj, 'blk2_antibias', 4, x, y, ...
              'position', [x+400 y 200 20], ...
              'TooltipString', sprintf(['Antibias beta value for this block']));
          next_row(y);
          SubheaderParam(obj, 'blk2_title', 'Block 2', x, y);
          NumeditParam(obj, 'blk2_thrshld', 0.8, x, y, ...
              'position', [x+150 y 150 20], ...
              'TooltipString', 'hit frac threshold for getting out of this block');
          next_row(y, 1.5);

          NumeditParam(obj, 'blk1_min_len', 18, x, y, ...
              'position', [x y 100 20], 'labelfraction', 0.65, ...
              'TooltipString', 'min length (in trials) of block 1');
          NumeditParam(obj, 'blk1_max_len', 18, x, y, ...
              'position', [x+100 y 100 20], 'labelfraction', 0.65, ...
              'TooltipString', 'max length (in trials) of block 1');  
          NumeditParam(obj, 'blk1_pprob', [0 1], x, y, ...
              'position', [x+200 y 200 20], ...
              'TooltipString', sprintf(['prior probabilities of the sounds in this block.' ...
                                        'should have as many elements as there are sounds']));
          EditParam(obj, 'blk1_antibias', 4, x, y, ...
              'position', [x+400 y 200 20], ...
              'TooltipString', sprintf(['Antibias beta value for this block']));
          next_row(y);
          SubheaderParam(obj, 'blk1_title', 'Block 1', x, y);
          NumeditParam(obj, 'blk1_thrshld', 0.8, x, y, ...
              'position', [x+150 y 150 20], ...
              'TooltipString', 'hit frac threshold for getting out of this block');
          next_row(y, 1.5);

          
          NumeditParam(obj, 'blk0_min_len', 18, x, y, ...
              'position', [x y 100 20], 'labelfraction', 0.65, ...
              'TooltipString', 'min length (in trials) of block 0');
          NumeditParam(obj, 'blk0_max_len', 18, x, y, ...
              'position', [x+100 y 100 20], 'labelfraction', 0.65, ...
              'TooltipString', 'max length (in trials) of block 0');  
          NumeditParam(obj, 'blk0_pprob', [1 0], x, y, ...
              'position', [x+200 y 200 20], ...
              'TooltipString', sprintf(['prior probabilities of the sounds in this block.' ...
                                        'should have as many elements as there are sounds']));
          EditParam(obj, 'blk0_antibias', 4, x, y, ...
              'position', [x+400 y 200 20], ...
              'TooltipString', sprintf(['Antibias beta value for this block']));
          next_row(y);          SubheaderParam(obj, 'blk0_title', 'Block 0', x, y);
          NumeditParam(obj, 'blk0_thrshld', 0.8, x, y, ...
              'position', [x+150 y 150 20], ...
              'TooltipString', 'hit frac threshold for getting out of this block');
          next_row(y, 1.5);
          
          
          NumeditParam(obj, 'temperror_len', 3, x, y, ...
              'position', [x y 100 20], ...
              'TooltipString', 'length of temp error');
          NumeditParam(obj, 'error_timeout', 10, x, y, ...
              'position', [x+100 y 100 20], ...
              'TooltipString', 'length of timeout up trial termination at error');
          next_row(y);
          NumeditParam(obj, 'goto_trial_terminates_at', 1, x, y, ...
              'TooltipString', 'in each block, goto trial termantes at this trial number');
          next_row(y);
          NumeditParam(obj, 'random_max_same', 5, x, y, ...
              'TooltipString', 'during random sides trial, set max_same to this value');
          NumeditParam(obj, 'random_pprob', [0.5 0.5], x, y, ...
              'position', [x+200 y 200 20], ...
              'TooltipString', 'pprob for random trials');
          EditParam(obj, 'random_antibias', 4, x, y, ...
              'position', [x+400 y 200 20], ...
              'TooltipString', sprintf(['Antibias beta value for random trials']));
          next_row(y);
          NumeditParam(obj, 'goto_blocks_at', 0, x, y, ...
              'TooltipString', 'after this many trials, go to blocks');
          next_row(y);
          NumeditParam(obj, 'goto_random_at', 0, x, y, ...
              'TooltipString', 'after this many trials, go to random sides');
          next_row(y);
          DispParam(obj, 'counter', 0, x, y, ...
              'TooltipString', 'keeps track of how many trials we are into the current block');
          next_row(y);
          DispParam(obj, 'n_block', 0, x, y, 'save_with_settings', 1, ...
              'TooltipString', 'block that is currently active');
            
          DispParam(obj, 'last_session_n_probe_trials', 0, x, y, ...
              'position', [x+300 y 200 20], 'labelfraction', 0.7, ...
              'TooltipString', 'probe trials done in last session', 'save_with_settings', 1);
          DispParam(obj, 'last_session_probe_hitfrac', 0, x, y, ...
              'position', [x+300 y-20 200 20], 'labelfraction', 0.7, ...
              'TooltipString', 'hit frac on probe trials done in last session', 'save_with_settings', 1);
            
          HeaderParam(obj, 'block_panel_title', 'Blocked Session Settings', x, y, ...
              'position', [5, 310, 300, 20]);
      % --------------------------------------------------------
   
      feval(mfilename, obj, 'window_toggle');  
      x = oldx; y = oldy; figure(fig);
      
      % flag to keep track if all stimuli defined in the sounds panel are
      % valid.  The status of the system is displayed as a mmessage in the
      % main protocol window.  The flag and the mmessage are set by action
      % 'check_norm'
      SoloParamHandle(obj, 'go_flg', 'value', 0);  
      SubheaderParam(obj, 'mmessage', '', x, y);
      set(get_ghandle(mmessage), 'BackgroundColor', 'r'); next_row(y);
      SubheaderParam(obj, 'title', 'Stimulus Section', x, y);    
      
      
      SoloFunctionAddVars('StateMatrixSection', 'ro_args', ...
          {'n_center_pokes'; 'side_lights'; ...
          'SoundsOn'; 'Center2SideGap'; 'Center2CenterGap'; 'Center2SideGap2';...
          'StimOffAtCpoke2'; 'StimulusDuration' ; 'n_stimulus_cycles'});
      SoloFunctionAddVars('SidesSection', 'ro_args', ...
          {'go_flg'});
      SoloFunctionAddVars('AntibiasSection', 'ro_args', ...
          {'stims'});
      
      feval(mfilename, obj, 'check_norm');
      feval(mfilename, obj, 'make_sounds');
      SoundManagerSection(obj, 'send_not_yet_uploaded_sounds');

      
% ---------------------------------------------------------------------
%
%          STIMTIMESTART
%
% ---------------------------------------------------------------------

  case 'StimTimeStart'
    if n_center_pokes == 2 && StimTimeStart == 0, %#ok<NODEF>
      StimTimeStart.value = 1;
      warndlg(sprintf(['Current configuration allows using StimTimeStart=="FromStimStart" *ONLY* ' ...
        '\nif you first set n_center_pokes below to less than 2.' ...
        '\nn_center_pokes is currently set to 2, so StimTimeStart stay at "FromAnswerPoke".' ...
        '\n   Sorry.']), mfilename);
    end;
      
    if StimTimeStart == 0,
      disable(FromAnswerPoke);
      enable(n_stimulus_cycles); %#ok<NODEF>
      enable(StimulusDuration);      
    else
      enable(FromAnswerPoke);
      disable(n_stimulus_cycles); %#ok<NODEF>
      disable(StimulusDuration);      
    end;


% ---------------------------------------------------------------------
%
%          NEXT_TRIAL
%
% ---------------------------------------------------------------------

  case 'next_trial',      
      %feval(mfilename, obj, 'make_sounds');     
      feval(mfilename, obj, 'compute_cycle_repeats');
      feval(mfilename, obj, 'check_norm');
      
      if value(go_flg),
          CurrentPair.value = SidesSection(obj, 'get_current_pair');
          Side.value = stims{value(CurrentPair), 1};
          PriProb.value = stims{value(CurrentPair), 5};
          post = AntibiasSection(obj, 'get_posterior_probs');
          PostProb.value = post(value(CurrentPair));
          Frequencies.value = stims{value(CurrentPair), 2};
          Durations.value = stims{value(CurrentPair), 3};
          WaterMultiplier.value = stims{value(CurrentPair), 4};
          
      end;
      
      Side.value = SidesSection(obj, 'get_current_side');

% ---------------------------------------------------------------------
%
%          N_CENTER_POKES
%
% ---------------------------------------------------------------------      
  case 'n_center_pokes',
      if n_center_pokes==2 && StimTimeStart == 0, %#ok<NODEF>
        n_center_pokes.value = 1;
        warndlg(sprintf(['Current configuration allows using n_center_pokes=2 *ONLY* ' ...
          '\nif you first set StimTimeStart toggle above to "FromAnswerPoke".' ...
          '\nThe toggle is currently set to "FromStimStart", and we can''t deal with that.' ...
          '\n   Sorry.']), mfilename);
      end;
    
      if n_center_pokes < 2, 
          disable(Center2CenterGap);
          disable(StimOffAtCpoke2);
      else
          enable(Center2CenterGap);
          enable(StimOffAtCpoke2);
      end;
      
% ---------------------------------------------------------------------
%
%          StimOffAtCpoke2
%
% ---------------------------------------------------------------------      
  case 'StimOffAtCpoke2',
      if StimOffAtCpoke2 == 1,
          disable(StimTimeStart);
      else
          enable(StimTimeStart);
      end;
      
% ---------------------------------------------------------------------
%
%          N_STIMULUS_CYCLES
%
% ---------------------------------------------------------------------
  case 'n_stimulus_cycles',
      if n_stimulus_cycles < 1, n_stimulus_cycles.value = 1; end; %#ok<NODEF>
      
% ---------------------------------------------------------------------
%
%          COMPUTE_CYCLE_REPEATS
%
% ---------------------------------------------------------------------
  case 'compute_cycle_repeats',
%       CycleDuration.value = SoundManagerSection(obj, 'get_sound_duration', 'LeftSound');
%       StimulusDuration.value = CycleDuration * n_stimulus_cycles;
  
% ---------------------------------------------------------------------
%
%          DISPLAY_ttable
%
% ---------------------------------------------------------------------
  case 'display_ttable',
      if isempty(stims), return; end;
      
      temp = value(ttable);
      temp = temp(1);
      for k = 1:rows(stims),
          frq = stims{k,2};
          dur = stims{k,3};
          newrow = format_newrow(obj, stims{k,5}, stims{k,1}, frq(1), dur(1), ...
              frq(2), dur(2), stims{ k,4});
          temp = [temp; cell(1,1)];
          temp{end} = newrow;
      end;     
      ttable.value = temp;
      
      set(get_ghandle(stttable), 'string', value(ttable));
      stttable.value = length(value(ttable));

% ---------------------------------------------------------------------
%
%          STttable
%
% ---------------------------------------------------------------------
  case 'stttable',
      n = get(get_ghandle(stttable), 'value');
      n = n(1);
      if n==1, return; end;  %if the label row was selected, do nothing
      k = n-1;
      
      frq = stims{k,2};
      dur = stims{k,3};
      pprob.value  = stims{k,5};
      side.value   = stims{k,1};
      f1_frq.value = frq(1);
      f1_dur.value = dur(1);
      f2_frq.value = frq(2);
      f2_dur.value = dur(2);
      wtr_ml.value = stims{k,4};
     
% ---------------------------------------------------------------------
%
%          SIDE
%
% ---------------------------------------------------------------------
  case 'side',
      side.value = lower(value(side)); %convert to upper case
      if length(value(side)) > 1 || ~(strcmp(value(side),'l') || strcmp(value(side),'r')),
          msgbox('Enter ''r'' or ''l'' for the side parameter!', 'Warning');
          return;
      end;
      
      
% ---------------------------------------------------------------------
%
%          PPROB
%
% ---------------------------------------------------------------------
  case 'pprob',
      if pprob > 1, pprob.value = 1; 
      elseif pprob < 0, pprob.value = 0;
      end;
      
% ---------------------------------------------------------------------
%
%          SET
%
% ---------------------------------------------------------------------
  case 'set',
      if nargin < 5,
          warning('STIMULUSSECTION:Invalid', 'not enough arguments for ''set'' action');
          return;
      end;
      modified_snd_ids = [];  % List of actual sounds that were changed, to then call make_sounds on

      while ~isempty(varargin),
        snd_id = varargin{1};
        param = varargin{2};
        newvalue = varargin{3};
        varargin = varargin(4:end);
        if rem(length(varargin),3) ~= 0,
          warning('STIMULUSSECTION:Invalid', 'wrong # of args for action ''set''');
          varargin = {};
        end;
      
        if snd_id > rows(stims),
          warning('STIMULUSSECTION:Invalid', 'Sound %d does not exist!', snd_id);
          return;
        end;
      
        switch param,
          case 'side',
            stims{snd_id,1} = newvalue;

          case 'f1_frq',
            frq = stims{snd_id,2};
            stims{snd_id, 2} = [newvalue frq(2)];
            modified_snd_ids = [modified_snd_ids ; snd_id];

          case 'f1_dur',
            dur = stims{snd_id, 3};
            stims{snd_id, 3} = [newvalue dur(2)];
            modified_snd_ids = [modified_snd_ids ; snd_id];

          case 'f2_frq',
            frq = stims{snd_id,2};
            stims{snd_id, 2} = [frq(1) newvalue];
            modified_snd_ids = [modified_snd_ids ; snd_id];

          case 'f2_dur',
            dur = stims{snd_id, 3};
            stims{snd_id, 3} = [dur(1) newvalue];
            modified_snd_ids = [modified_snd_ids ; snd_id];

          case 'wtr_ml',
            stims{snd_id, 4} = newvalue;

          case 'pprob',
            stims{snd_id, 5} = newvalue;

          otherwise,
            error([param 'does not exist!']);
        end;
      end;
      
      feval(mfilename, obj, 'display_ttable');
      feval(mfilename, obj, 'check_norm');
      modified_snd_ids = unique(modified_snd_ids);
      for i=1:length(modified_snd_ids),
        frq = stims{i, 2};
        dur = stims{i, 3};
        feval(mfilename, obj, 'make_sounds', modified_snd_ids(i), frq, dur);
      end;
   
% ---------------------------------------------------------------------
%
%          GET
%
% ---------------------------------------------------------------------   
  case 'get',
      if nargin==3
        switch varargin{1},
          case 'nstims',
            x = size(value(stims),1); %#ok<NODEF>
          case 'all_sides',
            %x = stims(:,1);
            x = size(value(stims),1);
          otherwise,
            warning('EXTENDEDSTIMULUS:StimulusSection', 'Don''t know how to ''get'' %s', varargin{1});
            x = [];
        end;
        return;
      end;
      
      if nargin < 4,
          warning('EXTENDEDSTIMULUS:StimulusSection', 'not enough arguments for ''get'' action');
          return;
      end;
      
      snd_id = varargin{1};
      param = varargin{2};
      
      %JPL
      if isempty(value(stims))
          stims.value={0 0 0 0 0};
      end
      
      switch param,
          case 'side',
              x = value(stims{snd_id,1});
              
          case 'f1_frq',
              frq = value(stims{snd_id,2});
              x = frq(1);
              
          case 'f1_dur', 
              dur = value(stims{snd_id, 3});
              x = dur(1);
              
          case 'f2_frq',
              frq = value(stims{snd_id,2});
              x = frq;
              
          case 'f2_dur', 
              dur = value(stims{snd_id, 3});
              x = dur;
              
          case 'wtr_ml',
              x = value(stims{snd_id, 4});
          case 'pprob',
              x = value(stims{snd_id, 5});
              
          otherwise,
              error([param 'does not exist!']);
      end;
      
      
% ---------------------------------------------------------------------
%
%          ADD_PAIR
%
% ---------------------------------------------------------------------
  case 'add_pair',
      side.value = lower(value(side)); %convert to lower case
      if length(value(side)) > 1 || ~(strcmp(value(side),'l') || strcmp(value(side),'r')),
          msgbox('Enter ''r'' or ''l'' for the side parameter!', 'Warning');
          return;
      end;

      newrow = format_newrow(obj, value(pprob), value(side), value(f1_frq), value(f1_dur), ...
          value(f2_frq), value(f2_dur), value(wtr_ml));
      ttable.value = [value(ttable); cell(1,1)];  % make empty row where newrow will go
      ttable{rows(ttable)} = newrow;

      set(get_ghandle(stttable), 'string', value(ttable));
      stttable.value = length(value(ttable));
      
      if ~isempty(stims),
          new = rows(stims)+1;
      else
          new = 1;
      end;
      
      stims.value = [value(stims); cell(1, 5)];
      stims{new,1} = value(side);
      stims{new,2} = [value(f1_frq) value(f2_frq)];
      stims{new,3} = [value(f1_dur) value(f2_dur)];
      stims{new,4} = value(wtr_ml);
      stims{new,5} = value(pprob);
    
      feval(mfilename, obj, 'check_norm');
      feval(mfilename, obj, 'make_sounds');
       
% ---------------------------------------------------------------------
%
%          DELETE_PAIR
%
% --------------------------------------------------------------------- 
  case 'delete_pair',    
      n = get(get_ghandle(stttable), 'value');
      n = n(1);
      if n==1, return; end;  %if the label row was selected, do nothing
      temp = value(ttable);
      ttable.value = temp([1:n-1 n+1:end],:);
      
      cellttable = cellstr(value(ttable));
      set(get_ghandle(stttable), 'string', cellttable);
      stttable.value = min(n, rows(ttable));
      
      % the nth row in ttable corresponds to the (n-1)th row in stims
      k = n-1;
      stims.value = stims([1:k-1 k+1:rows(stims)],:);
      
      feval(mfilename, obj, 'check_norm');
      feval(mfilename, obj, 'make_sounds');
      
% ---------------------------------------------------------------------
%
%          UPDATE_PAIR
%
% ---------------------------------------------------------------------
  case 'update_pair',
      n = get(get_ghandle(stttable), 'value');
      n = n(1);
      if n==1, return; end;  %if the label row was selected, do nothing
      
      side.value = lower(value(side)); %convert to lower case
      if length(value(side)) > 1 || ~(strcmp(value(side),'l') || strcmp(value(side),'r')),
          msgbox('Enter ''r'' or ''l'' for the side parameter!', 'Warning');
          return;
      end;
      
      temp = value(ttable);
      newrow = format_newrow(obj, value(pprob), value(side), value(f1_frq), value(f1_dur), ...
          value(f2_frq), value(f2_dur), value(wtr_ml));
      ttable.value = [temp([1:n-1]); cell(1,1); temp(n+1:end)];
      ttable{n} = newrow;
      
      set(get_ghandle(stttable), 'string', value(ttable));
      stttable.value = length(value(ttable));
      
      % the nth row in ttable corresponds to the (n-1)th row in stims
      k = n-1;
      stims{k,1} = value(side);
      stims{k,2} = [value(f1_frq) value(f2_frq)];
      stims{k,3} = [value(f1_dur) value(f2_dur)];
      stims{k,4} = value(wtr_ml);
      stims{k,5} = value(pprob);
      
      feval(mfilename, obj, 'check_norm');
      feval(mfilename, obj, 'make_sounds', k);      
      
% ---------------------------------------------------------------------
%
%          MAKE_SOUNDS
%
% ---------------------------------------------------------------------
  case 'make_sounds',
      if isempty(stims), return; end; %#ok<NODEF>
      
      % make silent gaps to go in between stimuli
      srate = SoundManagerSection(obj, 'get_sample_rate');
%       gap1 = 0:1/srate:value(f1f2Gap);
%       gap1 = gap1(1:(end-1));
       gap2 = 0:1/srate:value(InterCycleGap);
       gap2 = gap2(1:(end-1));
      
      if value(n_stimulus_cycles) == 1,  %#ok<NODEF>
          loop_flg = 0;
      elseif value(n_stimulus_cycles) > 1,
          loop_flg = 1;
      else
          loop_flg = 0;
          warning('What''s n_stimulus_cycles???'); %#ok<WNTAG>
      end;
      
      if nargin > 3,
          k = varargin{1};
          frq = stims{k, 2};
          dur = stims{k, 3};
          switch value(sounds_type)
            case 'Bups (Hz)'   
                snd = MakeBupperSwoop(srate, 10, frq(1), frq(2), ...
                    dur(1)*1000, dur(2)*1000, value(f1f2Gap)*1000, 0.1, ...
                    'F1_volume_factor', snd_amp, 'F2_volume_factor', snd_amp);
            case 'S Bups (Hz)'
                snd = MakeBupperSwoop(srate, 10, frq(1), frq(2), ...
                    dur(1)*1000, dur(2)*1000, value(f1f2Gap)*1000, 0.1, ...
                    'F1_volume_factor', snd_amp, 'F2_volume_factor', snd_amp, ...
                    'bup_width', 3);
            case 'Pure Tones (KHz)'
                snd = MakeSigmoidSwoop3(srate, 10, frq(1)*1000, frq(2)*1000, ...
                dur(1)*1000, dur(2)*1000, value(f1f2Gap)*1000, 0.1, 3, ... 
                'F1_volume_factor', snd_amp, 'F2_volume_factor', snd_amp);
            otherwise
              error('StimulusSection:Invalid', 'Don''t know how to make sounds type %s', value(sounds_type));
          end;

          snd = [snd zeros(1, length(gap2))];
          snd = [snd; snd]; % make stereo
          
          if ~SoundManagerSection(obj, 'sound_exists', sprintf('Sound%d', k)),
              SoundManagerSection(obj, 'declare_new_sound', sprintf('Sound%d', k));
              SoundManagerSection(obj, 'set_sound', sprintf('Sound%d', k), snd, loop_flg);
          else
              snd_prev = SoundManagerSection(obj, 'get_sound', sprintf('Sound%d', k));
              if ~isequal(snd, snd_prev),
                  SoundManagerSection(obj, 'set_sound', sprintf('Sound%d', k), snd, loop_flg);
              end;
          end;
      else
          for k = 1:rows(stims),
              frq = stims{k, 2};
              dur = stims{k, 3};
              switch value(sounds_type)
                case 'Bups (Hz)'   
                    snd = MakeBupperSwoop(srate, 10, frq(1), frq(2), ...
                        dur(1)*1000, dur(2)*1000, value(f1f2Gap)*1000, 0.1, ...
                        'F1_volume_factor', snd_amp, 'F2_volume_factor', snd_amp);
                case 'S Bups (Hz)'
                    snd = MakeBupperSwoop(srate, 10, frq(1), frq(2), ...
                        dur(1)*1000, dur(2)*1000, value(f1f2Gap)*1000, 0.1, ...
                        'F1_volume_factor', snd_amp, 'F2_volume_factor', snd_amp, ...
                        'bup_width', 3);
                case 'Pure Tones (KHz)'
                    snd = MakeSigmoidSwoop3(srate, 10, frq(1)*1000, frq(2)*1000, ...
                    dur(1)*1000, dur(2)*1000, value(f1f2Gap)*1000, 0.1, 3, ... 
                    'F1_volume_factor', snd_amp, 'F2_volume_factor', snd_amp);
                otherwise
                  error('StimulusSection:Invalid', 'Don''t know how to make sounds type %s', value(sounds_type));
              end;

              snd = [snd zeros(1, length(gap2))];
              snd = [snd; snd]; % make stereo

              if ~SoundManagerSection(obj, 'sound_exists', sprintf('Sound%d', k)),
                  SoundManagerSection(obj, 'declare_new_sound', sprintf('Sound%d', k));
                  SoundManagerSection(obj, 'set_sound', sprintf('Sound%d', k), snd, loop_flg);
              else
                  snd_prev = SoundManagerSection(obj, 'get_sound', sprintf('Sound%d', k));
                  if ~isequal(snd, snd_prev),
                      SoundManagerSection(obj, 'set_sound', sprintf('Sound%d', k), snd, loop_flg);
                  end;
              end;
          end;

          % if there's an extra sound declared, delete it
          SoundManagerSection(obj, 'delete_sound', sprintf('Sound%d', rows(stims)+1));
      end;

% ---------------------------------------------------------------------
%
%          CHECK_NORM
%
% ---------------------------------------------------------------------
  case 'check_norm',
      go_flg.value = 1;  % assume all system go
      if isempty(stims),  % if no sounds defined
          mmessage.value = 'No sounds defined!!';
          set(get_ghandle(mmessage), 'BackgroundColor', 'r');
          go_flg.value = 0;
          return;
      end;
      
      prb = cell2mat(stims(:,5));
      if abs(sum(prb) - 1) < 1e-10, 
          set(get_ghandle(normal), 'BackgroundColor', [30 200 30]/255);
      else % if pprob's do not sum to unity
          set(get_ghandle(normal), 'BackgroundColor', 'r');
          mmessage.value = 'PProb does not sum to 1';
          set(get_ghandle(mmessage), 'BackgroundColor', 'r');
          go_flg.value = 0;
          return;
      end;
      
      s = cell2mat(stims(:,1));
      if all(s == 'l'),  % if all choices are left
          mmessage.value = 'No right choices defined!!';
          set(get_ghandle(mmessage), 'BackgroundColor', 'r');
          go_flg.value = 0;
      elseif all(s == 'r'), % if all choices are right
          mmessage.value = 'No left choices defined!!';
          set(get_ghandle(mmessage), 'BackgroundColor', 'r');
          go_flg.value = 0;
      end;
      
      if value(go_flg),
          mmessage.value = 'All Sounds Valid';
          set(get_ghandle(mmessage), 'BackgroundColor', 'g');
      end;
      
% ---------------------------------------------------------------------
%
%          GET_GO_FLG
%
% ---------------------------------------------------------------------
  case 'get_go_flg',
      x = value(go_flg);  
      
% ---------------------------------------------------------------------
%
%          NORMALIZE
%
% ---------------------------------------------------------------------
  case 'normalize',
      normalize_pprob(obj, stims);
      feval(mfilename, obj, 'display_ttable');
      feval(mfilename, obj, 'check_norm');
      
% ---------------------------------------------------------------------
%
%          PLAY_SOUND
%
% ---------------------------------------------------------------------
  case 'play_sound',
      n = get(get_ghandle(stttable), 'value'); % get selected row
      n = n(1);
      if n==1, return; end;  %if the label row was selected, do nothing
      k = n-1;
      
      SoundManagerSection(obj, 'play_sound', sprintf('Sound%d', k));
      
% ---------------------------------------------------------------------
%
%          STOP_SOUND
%
% ---------------------------------------------------------------------
  case 'stop_sound',
      n = get(get_ghandle(stttable), 'value'); % get selected row
      n = n(1);
      if n==1, return; end;  %if the label row was selected, do nothing
      k = n-1;
      
      SoundManagerSection(obj, 'stop_sound', sprintf('Sound%d', k));
      
% ---------------------------------------------------------------------
%
%          GET_THIS_SIDE_PAIR
%
% ---------------------------------------------------------------------
  case 'get_this_side_pair'
      k = value(CurrentPair);
      x = stims{k, 2};

      
% ---------------------------------------------------------------------
%
%          GET_THIS_SIDE_PAIR_AND_STIM_ID
%
% ---------------------------------------------------------------------
  case 'get_this_side_pair_and_stim_id'
      k = value(CurrentPair); %#ok<NODEF>
      x = [stims{k, 2} k]; %#ok<NODEF>
      
      
% ---------------------------------------------------------------------
%
%          GET_N_SOUND_PAIRS
%
% ---------------------------------------------------------------------
  case 'get_n_sound_pairs',
      x = rows(stims);
      
% ---------------------------------------------------------------------
%
%          GET_SOUNDS_ON
%
% ---------------------------------------------------------------------
  case 'get_sounds_on',
      if SoundsOn, x = 1;
      else         x = 0;
      end;

% ---------------------------------------------------------------------
%
%          WINDOW_TOGGLE
%
% ---------------------------------------------------------------------      
  case 'window_toggle', 
    if value(sounds_button) == 1, 
            set(value(mysoundfig), 'Visible', 'on');    
    else
            set(value(mysoundfig), 'Visible', 'off');
    end;
    
    if value(blocks_button) == 1,
        set(value(myblockfig), 'Visible', 'on');
    else
        set(value(myblockfig), 'Visible', 'off');
    end;
    
    
% ---------------------------------------------------------------------
%
%          HIDE_SOUND_WINDOW
%
% ---------------------------------------------------------------------
  case 'hide_sound_window', 
      sounds_button.value_callback = 0;
    
% ---------------------------------------------------------------------
%
%          HIDE_BLOCK_WINDOW
%
% ---------------------------------------------------------------------
  case 'hide_block_window',
      blocks_button.value_callback = 0;
      
% ---------------------------------------------------------------------
%
%          CLOSE
%
% ---------------------------------------------------------------------
  case 'close',
      delete(value(mysoundfig));
      delete(value(myblockfig));

% ---------------------------------------------------------------------
%
%          END_SESSION
%
% ---------------------------------------------------------------------
  case 'end_session',
        

% ---------------------------------------------------------------------
%
%          REINIT
%
% ---------------------------------------------------------------------        
  case 'reinit',
    currfig = gcf;

    % Get the original GUI position and figure:
    x = my_gui_info(1); y = my_gui_info(2); figure(my_gui_info(3));

    % Delete all SoloParamHandles who belong to this object and whose
    % fullname starts with the name of this mfile:
    delete_sphandle('owner', ['^@' class(obj) '$'], ...
      'fullname', ['^' mfilename]);

    % Reinitialise at the original GUI position and figure:
    [x, y] = feval(mfilename, obj, 'init', x, y);

    % Restore the current figure:
    figure(currfig);
end;


function [stims] = normalize_pprob(obj, stims)
    prb = cell2mat(stims(:,5));
    prb = prb./sum(prb);
    
    for i = 1:rows(stims)
        stims{i,5} = prb(i);
    end;
	return;
    
function newrow = format_newrow(obj, pprob, side, f1_frq, f1_dur, f2_frq, f2_dur, water) 
    newrow = [sprintf('%5.3g   ', pprob) ' ' side ...
          sprintf('     %5.3g      %5.3g      %5.3g      %5.3g     %6.3g', ...
          f1_frq, f1_dur, f2_frq, f2_dur, water)];
    return;