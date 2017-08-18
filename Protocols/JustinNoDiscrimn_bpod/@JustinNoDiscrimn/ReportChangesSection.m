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
%
%%% CVS version control block - do not edit manually
%%%  $Revision: 984 $
%%%  $Date: 2007-12-18 17:03:37 -0500 (Tue, 18 Dec 2007) $
%%%  $Source$


function [x, y] = ReportChangesSection(obj, action, varargin)
   
GetSoloFunctionArgs;
%%% Imported objects (see protocol constructor):
%%%  'MaxTrials'
%%%  'RewardSideList' (created empty on protocol constructor)
%%%  'DistractorList' (created empty on protocol constructor)

switch action
  case 'init',
    % Save the figure and the position in the figure where we are
    % going to start adding GUI elements:
    x = varargin{1};
    y = varargin{2};
    
    SoloParamHandle(obj, 'my_gui_info', 'value', [x y get(gcf,'Number')]);
    PushbuttonParam(obj, 'ShowLastChanges', x,y, 'label', 'Show last changes', 'position', [x y 200 20]);
    set_callback(ShowLastChanges,{mfilename, 'show_report'});

    next_row(y);
    
    
  case 'show_report'
    ThisSPH = get_sphandle('name', 'RelevantSideSPH');% ThisSPH{1}.value = 3;
    ThisSPHhistory = get_history(ThisSPH{1});
    ChangesInThisSPH = [];
    for indtrial = 2:length(ThisSPHhistory)
        if(~strcmp(ThisSPHhistory{indtrial},ThisSPHhistory{indtrial-1}))
            ChangesInThisSPH = [ChangesInThisSPH;indtrial];
        end
    end
    fprintf('=================== Changes report =================\n');
    for indchange = 1:length(ChangesInThisSPH)
        TrialNumber = ChangesInThisSPH(indchange);
        ActualTrialNumber = TrialNumber-1; % WHY is there a trial 0? I'm not sure (sjara 2007.09.11)
        fprintf('Trial %d : %s \t\t Trial %d : %s\n',ActualTrialNumber-1,ThisSPHhistory{TrialNumber-1},...
                                                   ActualTrialNumber,ThisSPHhistory{TrialNumber});
    end
    fprintf('=============== End of changes report ==============\n');
    
    
  case 'reinit',
    currfig = get(gcf,'Number');

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


