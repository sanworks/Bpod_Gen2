% [x, y] = NotesSection(obj, action, x, y)
%
% Text box for taking notes during the experiment.
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

function [x, y] = StimParamSection(obj, action, x, y)

GetSoloFunctionArgs;


switch action

    case 'init',   % ------------ CASE INIT ----------------
        
        % Save the figure and the position in the figure where we are
        % going to start adding GUI elements:
        fnum = gcf;
        SoloParamHandle(obj, 'my_gui_info', 'value', [x y fnum.Name]); 
        next_row(y);

        MenuParam(obj, 'stim_type', {'rand_with_go', 'rand_all_trials', 'always_on', 'Off'}, 'Off', x, y, 'label', 'Stim type', 'TooltipString', 'Stim on / off');
        % set_callback(notes_show, {mfilename,'hide_show'});

        next_row(y);
        SubheaderParam(obj, 'sectiontitle', 'Stim Param', x, y);

        
        % Flag for switch on or off the light stimulation
        SoloParamHandle(obj, 'next_trial_stim', 'value', 0);
        
        SoloFunctionAddVars('make_and_upload_state_matrix', 'ro_args', {'next_trial_stim'});
        
        % StimParamSection(obj,'next_trial_stim');
         
        return;


    case 'next_trial_stim'
        next_side = SidesSection(obj,'get_next_side');
        switch value(stim_type)
            case 'rand_with_go'
                if next_side == 'r'
                    next_trial_stim.value = round(rand); %1; %
                end
            case 'rand_all_trials'
                next_trial_stim.value = round(rand);
            case 'always_on'
                next_trial_stim.value = 1;
            case 'Off'
                next_trial_stim.value = 0;
        end
        
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


