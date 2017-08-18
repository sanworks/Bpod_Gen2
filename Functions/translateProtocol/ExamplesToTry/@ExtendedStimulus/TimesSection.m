% @ExtendedStimulus/TimesSection.m
% Bing, August 2007


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


function [x, y] = TimesSection(obj, action, x, y)
   
GetSoloFunctionArgs;

switch action
  case 'init',
    % Save the figure and the position in the figure where we are
    % going to start adding GUI elements:
    SoloParamHandle(obj, 'my_gui_info', 'value', [x y gcf]);

    NumeditParam(obj, 'water_wait', 0.15, x, y, 'position', [x y 145 20], ...
        'TooltipString', ['How long to wait, in secs, after a correct' ...
        'poke and before giving water']);
    ToggleParam(obj, 'water_wait_lights', 1, x, y, 'position', [x+150 y 50 20], ...
      'OnString', 'Light ON', 'OffString', 'Light OFF', 'TooltipString', ...
      sprintf(['\nIf ON (black bg), reward port light is on during the water_wait and water delivery.' ...
      '\nIf OFF (brown bg), reward port light stays off during water_wait and water delivery.'])); next_row(y);

    NumeditParam(obj, 'mu_ITI', 2, x, y, 'position', [x y 100 20], ...
        'labelfraction', 0.7, 'TooltipString', 'mean inter-trial-interval, in secs');
    NumeditParam(obj, 'sd_ITI', 0.1, x, y, 'position', [x+100 y 100 20], ...
        'labelfraction', 0.7, 'TooltipString', 'st dev ITI, in secs'); next_row(y);
    NumeditParam(obj, 'miss_ITI', 0, x, y, ...
        'TooltipString', 'additional ITI on incorrect side choice trials');
    next_row(y);
    DispParam(obj, 'ITI', 4, x, y, ...
        'TooltipString', 'Inter Trial Interval, secs pause before next center light comes on'); 
    next_row(y, 1);   
    
    next_row(y, 0.5);
    SubheaderParam(obj, 'title', 'Times Section', x, y);
    next_row(y, 1.5);
    
    SoloFunctionAddVars('StateMatrixSection', 'ro_args', ...
                        {'water_wait'; 'water_wait_lights'; 'ITI'});
    
  case 'compute_iti',
    ITI.value = mu_ITI + sd_ITI*randn(1);
    if ITI < 0.5, ITI.value = 0.5; end;  
    if ~isempty(hit_history),
        if hit_history(n_done_trials) == 0, ITI.value = ITI + miss_ITI; end;
    end
    
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


