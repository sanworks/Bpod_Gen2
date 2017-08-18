% [x, y] = SMControlSection(obj, action, x, y)
%
% Section that allows GUI-based interaction with the RTLinux state machine.
%
%
% PARAMETERS:
% -----------
%
% obj      Default object argument.
%
% action   One of:
%            'init'      To initialise the section and set up the GUI
%                        for it;
%
%            'reinit'    Delete all of this section's GUIs and data,
%                        and reinit, at the same position on the same
%                        figure as the original section GUI was placed.
%           
%            Several other actions are available (see code of this file).
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
% x        When action = 'get_next_side', x will be either 'l' for
%          left or 'r' for right.
%

function [x, y] = SMControlSection(obj, action, x, y)

GetSoloFunctionArgs;

global state_machine_properties;

switch action

    case 'init',   % ------------ CASE INIT ----------------
        
        % Save the figure and the position in the figure where we are
        % going to start adding GUI elements:
        SoloParamHandle(obj, 'my_gui_info', 'value', [x y gcf]); 
        next_row(y);

        MenuParam(obj, 'sm_control_show', {'view', 'hide'}, 'hide', x, y, 'label', 'SM Control', 'TooltipString', 'Control state machine');
        set_callback(sm_control_show, {mfilename,'hide_show'});

        next_row(y);
        SubheaderParam(obj, 'sectiontitle', 'State Machine Control', x, y);

        parentfig_x = x; parentfig_y = y;

        % ---  Make new window for state machine interaction
        SoloParamHandle(obj, 'smfig', 'saveable', 0);
        smfig.value = figure('Position', [3 750 400 200], 'Menubar', 'none',...
            'Toolbar', 'none','Name','State Machine Control','NumberTitle','off');

        x = 1; y = 1;

        PushbuttonParam(obj, 'force_state_35', x, y, 'label', 'force_state_35');
        set_callback(force_state_35, {mfilename, 'force_state_35'});
        next_row(y);
        
        PushbuttonParam(obj, 'force_state_0', x, y, 'label', 'force_state_0');
        set_callback(force_state_0, {mfilename, 'force_state_0'});
        next_row(y);

        
        SMControlSection(obj,'hide_show');
        
        x = parentfig_x; y = parentfig_y;
        set(0,'CurrentFigure',value(myfig));
        return;

    case 'force_state_35',
        ForceState35(state_machine_properties.sm);
        return;
        
    case 'force_state_0',
        ForceState0(state_machine_properties.sm);
        return;
    
    case 'hide_show'
        if strcmpi(value(sm_control_show), 'hide')
            set(value(smfig), 'Visible', 'off');
        elseif strcmpi(value(sm_control_show),'view')
            set(value(smfig),'Visible','on');
        end;
        return;


    case 'reinit',   % ------- CASE REINIT -------------
        currfig = gcf;

        % Get the original GUI position and figure:
        x = my_gui_info(1); y = my_gui_info(2); figure(my_gui_info(3));

        delete(value(myaxes));

        % Delete all SoloParamHandles who belong to this object and whose
        % fullname starts with the name of this mfile:
        delete_sphandle('owner', ['^@' class(obj) '$'], ...
            'fullname', ['^' mfilename]);

        % Reinitialise at the original GUI position and figure:
        [x, y] = feval(mfilename, obj, 'init', x, y);

        % Restore the current figure:
        figure(currfig);
        return;
end


