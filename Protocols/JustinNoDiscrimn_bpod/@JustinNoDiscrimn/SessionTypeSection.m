% [x, y] = SessionTypeSection(obj, action, x, y)
%
% Section that takes care of choosing the stage of training.
%
% PARAMETERS:
% -----------
%
% obj      Default object argument.
%
% action   One of:
%            'init'      To initialise the section and set up the GUI
%                        for it.
%
%            'reinit'    Delete all of this section's GUIs and data,
%                        and reinit, at the same position on the same
%                        figure as the original section GUI was placed.
%
%            'get_session_type'  Returns string giving session type.
%
%
% RETURNS:
% --------
%
% [x, y]   When action == 'init', returns x and y, pixel positions on
%          the current figure, updated after placing of this section's GUI. 
%
% x        When action = 'get_session_type', x will be string giving name of
%          session type.
%

function [x, y] = SessionTypeSection(obj, action, x, y)
   
   GetSoloFunctionArgs;
   
   switch action
    
    case 'init',   % ------------ CASE INIT ----------------
      % Save the figure and the position in the figure where we are
      % going to start adding GUI elements:
      fnum=gcf;
      SoloParamHandle(obj, 'my_gui_info', 'value', [x y fnum.Name]);

      %JPL - 20160701 - only need types for testing, and the main protocol 'noDiscrimn', a misnomer
      %everything else handled in the settings and in embed C
      %MenuParam(obj, 'SessionType', {'Licking','Touch_Test','Discrim_Sounds','Discrim_Poles',...
      %    'Water_Valve_Calibration','Sound_Calibration','Beam_Break_Indicator','FlashLED',...
      %    'noDiscrim','continuousTouch'},'noDiscrim', x, y);
      MenuParam(obj, 'SessionType', {'Touch_Test','Water_Valve_Calibration',...
          'Sound_Calibration','Beam_Break_Test','noDiscrim','test'},'noDiscrim', x, y);     
      
      %Give the approriate functions access to SessionType
      SoloFunctionAddVars('StateMatrixSection', 'ro_args', {'SessionType'});
      SoloFunctionAddVars('TrialStructureSection', 'ro_args', {'SessionType'});
      SoloFunctionAddVars('MotorsSection', 'ro_args', {'SessionType'});
      
      next_row(y, 1);
      SubheaderParam(obj, 'title', 'Type of Session', x, y);
      
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
   end;
   
   
      