% Typical section code-- this file may be used as a template to be added 
% on to. The code below stores the current figure and initial position when
% the action is 'init'; and, upon 'reinit', deletes all SoloParamHandles 
% belonging to this section, then calls 'init' at the proper GUI position 
% again.


% [x, y] = YOUR_SECTION_NAME(obj, action, x, y)
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


function [x, y] = PenaltySection(obj, action, x, y)
   
GetSoloFunctionArgs;

switch action
  case 'init',
    % Save the figure and the position in the figure where we are
    % going to start adding GUI elements:
    fig = gcf;
    SoloParamHandle(obj, 'my_gui_info', 'value', [x y fig]);

    % this is the only thing that shows up on the main GUI window:
    ToggleParam(obj, 'penalty_button', 0, x, y, ...
        'OnString', 'Penalties Panel Showing', ...
        'OffString', 'Penalties Panel Hidden', ...
        'TooltipString', 'Show/Hide the window that controls penalties for the protocol');
    next_row(y);
    set_callback(penalty_button, {mfilename, 'window_toggle'});

    origx = x; origy = y;
    

    % Now we set up the window that pops up to specify penalties
    SoloParamHandle(obj, 'mypfig', 'saveable', 0, 'value', ...
        figure('position', [409   316   420 360], ...
            'MenuBar', 'none',  ...
            'NumberTitle', 'off', ...
            'Name','ExtendedStimulus Penalty Settings', ...
            'CloseRequestFcn', [mfilename ...
            '(' class(obj) ', ''hide_window'');']));

        
    x = 5; y = 5; boty = 5; topy = 450;
    
    
    [x, y] = PunishInterface(obj, 'add', 'CenterLightPun', x, y);
    PunishInterface(obj, 'set', 'CenterLightPun', 'SoundsPanel', 0);
    
    ToggleParam(obj, 'PunishCL1BadPokes', 0, x, y, ...
        'OffString', 'do not punish wrong pokes in c light', ...
        'OnString',  'punish wrong pokes in center light', ...
        'TooltipString', sprintf(['\nIf brown, poking in a bad port during center light has no effect;' ...
                                  '\nIf black, poking emits Violation1Sound and center light reinits']));
    
    
    next_row(y,2);
    
    [x, y] = PunishInterface(obj, 'add', 'C2SPun', x, y);
    PunishInterface(obj, 'set', 'C2SPun', 'SoundsPanel', 0);   
    
    ToggleParam(obj, 'PunishC2SSidePokes', 0, x, y, ...
        'OffString', 'do not punish side pokes in c2s gap', ...
        'OnString',  'punish side pokes in c2s gap', ...
        'TooltipString', sprintf(['\nIf brown, poking during center to side gap has no effect;' ...
                                  '\nIf black, poking emits Violation2Sound and c2s gap reinits']));
    next_row(y);
    
    ToggleParam(obj, 'PunishC2SCenterPokes', 0, x, y, ...
        'OffString', 'do not punish center pokes in c2s gap', ...
        'OnString',  'punish center pokes in c2s gap', ...
        'TooltipString', sprintf(['\nIf brown, poking during center to side gap has no effect;' ...
                                  '\nIf black, poking emits Violation2Sound and c2s gap reinits']));
    next_row(y);
    MenuParam(obj, 'first_pk_in_c2sgap', {'anything', 'L', 'R'}, 1, x, y, ...
      'TooltipString', sprintf(['\nThis setting defines what the first poke WITHIN center2sidegap' ...
      'should be. If the menu is set to "anything", then behavior follows the setting of "PunishC2SidePokes"' ...
      '\nbutton below. If set to "L", then the PunishC2SidePokes button is ignored. If the first poke' ...
      '\nwithin center2sidegap is an Rin event, jump to Error. If the first poke is an Lin' ...
      '\nevent, then allow any pokes thereafter has no effect. Vice versa for "R".'])); next_row(y);
    SoloFunctionAddVars('StateMatrixSection', 'ro_args', 'first_pk_in_c2sgap');
    set_callback(first_pk_in_c2sgap, {mfilename, 'first_pk_in_c2sgap'});
    next_row(y,2);
    
    [x, y] = PunishInterface(obj, 'add', 'ITIPun', x, y);
    PunishInterface(obj, 'set', 'ITIPun', 'SoundsPanel', 0);
    
    ToggleParam(obj, 'PunishITIPokes', 0, x, y, ...
        'OffString', 'do not punish pokes during ITI', ...
        'OnString',  'punish pokes during ITI', ...
        'TooltipString', 'if black, punish pokes during ITI with Violation3Sound');    
                     
    next_column(x); y = boty;
    
    ToggleParam(obj, 'SoftDrinkTime', 1, x, y, 'position', [x y 120 20], ...
        'OffString', 'no soft drink time', ...
        'OnString',  'allow soft drink time', ...
        'TooltipString', sprintf(['soft drink time delays the start of next trial until the rat' ...
                                  '\nhas finished drinking. SoftDrinkGrace is how much time the rat' ...
                                  '\ncan spend outside the reward port before the system thinks' ...
                                  '\nhe''s finished drinking.']));
    ToggleParam(obj, 'WD_in_sdt', 0, x, y, 'position', [x+130 y 70 20], ...
        'OffString', 'no WD in softDT', ...
        'OnString',  'WD in softDT', ...
        'TooltipString', sprintf(['\nIf on (black bg), soft drinktime ends with warning and danger' ...
                                  '\nnoises. Otherwise, soft drinktime ends by going straight to new trial']));
    next_row(y);
    NumeditParam(obj, 'SoftDrinkGrace', 1, x, y, 'position', [x y 100 20], ...
        'TooltipString', 'After this amount of time has passed without licks, we assume he is done drinking and go on');
    NumeditParam(obj, 'SoftDrinkCap', 20, x, y, 'position', [x+100 y 100 20], ...
        'TooltipString', 'Maximum time cap for drinking, including DrinkTime'); next_row(y);
    NumeditParam(obj, 'DrinkTime', 15, x, y, 'TooltipString', sprintf('\nTime over which drinking is ok')); next_row(y);
    ToggleParam(obj, 'WarningSoundPanel', 0, x, y, 'OnString', 'warn show', 'OffString', 'warn hide', 'position', [x y 80 20]); 
    NumeditParam(obj, 'WarnDur',   4, x, y, 'labelfraction', 0.6, 'TooltipString', 'Warning sound duration in secs', 'position', [x+80 y 60 20]);
    NumeditParam(obj, 'DangerDur',15, x, y, 'labelfraction', 0.6, 'TooltipString', sprintf('\nDuration of post-drink period where poking is punished'), 'position', [x+140 y 60 20]); next_row(y);
    set_callback(WarningSoundPanel, {mfilename, 'WarningSoundPanel'});
    % start subpanel
      oldx = x; oldy = y; oldfigure = gcf;
      SoloParamHandle(obj, 'WarningSoundPanelFigure', 'saveable', 0, 'value', figure('Position', [120 120 430 156]));
      sfig = value(WarningSoundPanelFigure);
      set(sfig, 'MenuBar', 'none', 'NumberTitle', 'off', ...
        'Name', 'Warning sound', 'CloseRequestFcn', 'Classical(classical, ''closeWarningSoundPanel'')');
      SoundInterface(obj, 'add', 'WarningSound', 10,  10);
      SoundInterface(obj, 'set', 'WarningSound', 'Vol',   0.0002);
      SoundInterface(obj, 'set', 'WarningSound', 'Vol2',  0.004);
      SoundInterface(obj, 'set', 'WarningSound', 'Dur1',  4);
      SoundInterface(obj, 'set', 'WarningSound', 'Loop',  0);
      SoundInterface(obj, 'set', 'WarningSound', 'Style', 'WhiteNoiseRamp');
      
      SoundInterface(obj, 'add', 'DangerSound',  215,  10);
      SoundInterface(obj, 'set', 'DangerSound', 'Vol',   0.004);
      SoundInterface(obj, 'set', 'DangerSound', 'Dur1',  1);
      SoundInterface(obj, 'set', 'DangerSound', 'Loop',  1);
      SoundInterface(obj, 'set', 'DangerSound', 'Style', 'WhiteNoise');

      x = oldx; y = oldy; figure(oldfigure);
    % end subpanel
    feval(mfilename, obj, 'WarningSoundPanel');
    SoloFunctionAddVars('StateMatrixSection', 'ro_args', {'DrinkTime', 'WarnDur', 'DangerDur'});
    [x, y] = PunishInterface(obj, 'add', 'PostDrinkPun', x, y);
    PunishInterface(obj, 'set', 'PostDrinkPun', 'SoundsPanel', 0);
    
    next_row(y,2);
    
    [x, y] = PunishInterface(obj, 'add', 'ErrorPun', x, y);
    PunishInterface(obj, 'set', 'ErrorPun', 'SoundsPanel', 0);
    
    [x, y] = PunishInterface(obj, 'add', 'TimeOutPun', x, y);
    PunishInterface(obj, 'set', 'TimeOutPun', 'SoundsPanel', 0);

    ToggleParam(obj, 'SideChoicePunishmentType', 0, x, y, ...
        'OffString', 'trial terminates -> error sound', ...
        'OnString',  'temporary time out', ...
        'TooltipString', sprintf(['\nIf brown, upon wrong side choice the trial is terminated and TimeOutSound plays' ...
                                  '\nIf black, wrong side choice plays TempTOSound; stimulus sound is not turned off']));
    next_row(y);
    
    ToggleParam(obj, 'PunishSideChoice', 1, x, y, ...
        'OffString', 'do not punish wrong side choice', ...
        'OnString',  'punish wrong side choice', ...
        'TooltipString', 'If black, punish wrong side choice: choose type of punishment');

    next_row(y);
    

    
    SoloFunctionAddVars('StateMatrixSection', 'ro_args', ...
          {'PunishCL1BadPokes'; ...
          'PunishC2SSidePokes'; ...
          'PunishC2SCenterPokes'; ...
          'PunishSideChoice'; 'SideChoicePunishmentType';...
          'PunishITIPokes'; 'SoftDrinkTime'; 'WD_in_sdt' ; ...
          'SoftDrinkGrace'; 'SoftDrinkCap'});
    
      
      
    SoundManagerSection(obj, 'send_not_yet_uploaded_sounds');
    feval(mfilename, obj, 'window_toggle');    
    
    x = origx; y = origy; figure(fig);
    return;
    
  case 'window_toggle', 
    if value(penalty_button) == 1, 
            set(value(mypfig), 'Visible', 'on');    
    else
            set(value(mypfig), 'Visible', 'off');
    end;
    
    
  case 'hide_window', 
    penalty_button.value_callback = 0;
    
    
  case 'WarningSoundPanel'
    if WarningSoundPanel==0, set(value(WarningSoundPanelFigure), 'Visible', 'off');
    else                     set(value(WarningSoundPanelFigure), 'Visible', 'on');
    end;
    
  case 'close',
    if exist('WarningSoundPanelFigure', 'var'),
      delete(value(WarningSoundPanelFigure));
    end;  
    delete(value(mypfig));    
    
    

      
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


