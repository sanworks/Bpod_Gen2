% [x, y] = SavingSection(obj, action, x, y)
%
% Section that takes care of saving/loading data and settings.
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
%            'savesets'  Save GUI settings only to a file
%
%            'loadsets'  Load GUI settings from a file
%
%            'savedata'  Save all SoloParamHandles to a file. 
%                           Also deletes previous _ASV.mat files from same
%                        protocol, experimenter, ratname, date. (They are
%                        presumably now unnecessary.)  Does not erase any
%                        other _ASV.mat files.
%
%            'autosave_data'    Every autosave_frequency calls with this
%                        action string, save a data file with _ASV.mat suffix, 
%                        no commit, non-interactive. autosave_frequency is
%                        20 by default; it can be changed by a call with 
%                        'set_autosave_frequency' as its action.
%                           Typically, you might do an 'autosave_data' call
%                        after every trial, and that way every
%                        autosave_frequency trials, the data gets saved.
%                           If a regular 'savedata' with the same filename
%                        is completed, the _ASV.mat file is deemed
%                        unnecessary and is deleted.
%
%            'set_autosave_frequency'  n      Requires one more extra
%                        parameter, n, a scalar positive integer. Ssts
%                        autosave_frequency to n.
%
%            'get_autosave_frequency'   Returns the current value of
%                        autosave_frequency.
%
%            'loaddata'  Load all SoloParamHandles from a file
%
%            'get_info'  Returns the experimenter, rat name, and date
%                          when this data was saved (yymmdd string). Date
%                          string is '.' if this data was saved before date
%                          information started being stored.
%
%            'set_info' experimenter ratname.  Takes two strings and sets
%                          the experimenter and ratname to thos values.
%
% x, y     Only relevant to action = 'init'; they indicate the initial
%          position to place the GUI at, in the current figure window
%
% RETURNS:
% --------
%
% [x,y,z]  When action == 'init', returns x and y, pixel positions on
%          the current figure, updated after placing of this section's GUI.
%          When action == 'get_info', returns experimenter, rat name, and
%            date when this data was saved (string yymmdd).
%

function [x, y, z] = SavingSection(obj, action, x, y, varargin)
   z = '.'; %     added to allow for the extra return val without complaint
   
   GetSoloFunctionArgs(obj);
   
   
   %     Why would you put this here instead of in the saving cases?
   %       No. The variable is now updated below, ON DATA SAVE ONLY (i.e.
   %       not on settings save). Naturally, it then corresponds to
   %       the saved date from loaded data as well.
   %
   %    if exist('SaveTime', 'var') && isa(SaveTime, 'SoloParamHandle'),
   %        SaveTime.value = datestr(now);
   %    end;
   
   switch action
    case 'init',      % ------------ CASE INIT --------------------
      % Save the figure and the position in the figure where we are
      % going to start adding GUI elements:
      SoloParamHandle(obj, 'my_gui_info', 'value', [x y gcf]);
      SoloParamHandle(obj, 'data_file', 'value', '');
      
      %Sundeep Tuteja, 22nd December, 2009: Adding a SoloParamHandle called
      %settings_file to store the full path to the currently loaded settings file.
      try
          [dummy, settings_file_str] = runrats('get_settings_file_path');
          clear('dummy');
      catch %#ok<CTCH>
          settings_file_str = '';
      end
      SoloParamHandle(obj, 'settings_file', 'value', settings_file_str);
      try
          [dummy, settings_file_load_time_num] = runrats('get_settings_file_load_time');
          clear('dummy');
      catch %#ok<CTCH>
          settings_file_load_time_num = 0;
      end
      SoloParamHandle(obj, 'settings_file_load_time', 'value', settings_file_load_time_num);
      
      EditParam(obj, 'experimenter', 'experimenter', x, y); next_row(y, 1.5);
      EditParam(obj, 'ratname', 'ratname', x, y); next_row(y, 1.5);
      
      PushbuttonParam(obj, 'loadsets', x, y, 'label', 'Load Settings');
      set_callback(loadsets, {mfilename, 'loadsets'});
      next_row(y);     
      PushbuttonParam(obj, 'savesets', x, y, 'label', 'Save Settings');
      set_callback(savesets, {mfilename, 'savesets'});
      next_row(y, 1.5);     
      
      PushbuttonParam(obj, 'loaddata', x, y, 'label', 'Load Data');      
      set_callback(loaddata, {mfilename, 'loaddata'});
      next_row(y);     
      PushbuttonParam(obj, 'savedata', x, y, 'label', 'Save Data');
      set_callback(savedata, {mfilename, 'savedata'});
      next_row(y);     
      %--- JS 2017, to permit running B-control outside of Brody lab 
      try   
          usingBdata = bSettings('get', 'GENERAL', 'use_bdata');
      catch 
          usingBdata = 1;
      end
      if usingBdata == 1
         SoloParamHandle(obj, 'hostname', 'value', get_hostname);
      else
         SoloParamHandle(obj, 'hostname', 'value', 'localhost'); 
      end
      %--- end JS 2017
      SoloParamHandle(obj, 'SaveTime', 'value', '_'); %     Changed from init val datestr(now) to init val '.'. The time this is initialized is NOT the time data was saved. This default value should be something more reasonable, perhaps, but any changes should be mirrored in the documentation at the top of this file and in sensitive code in PokesPlot and dispatcher script hook code.

      SoloParamHandle(obj, 'n_autosave_calls', 'value', 0);    % How many 'autosave_data' calls have been done since init
      SoloParamHandle(obj, 'autosave_frequency', 'value', 20); % Every autosave_frequency 'autosave_data' calls, save the data with _ASV.mat suffix, no commit, not interactive
      
	  SoloParamHandle(obj, 'save_all_data_to_sql','value',0);
      % <~> Addition of new interactivity toggle to make life a little
      %       faster for experimenters and technicians. The banner has also
      %       been shrunk horizontally. Oct 25 2007, -s
      SubheaderParam(obj, 'title', mfilename, x, y, 'width',110);
      ToggleParam(obj, 'interactive_by_default',1,x+111,y, ...
          'position',           [x+111,y,88,20], ...
          'OnString',           'interactive', ...
          'OffString',          'noninteractive', ...
          'TooltipString',      sprintf(['When this is "interactive",\n' ...
          '  a save dialog pops up when save is pressed.\n' ...
          'When this is "noninteractive",\n' ...
          '  the default filename is used without confirmation.']));
      next_row(y, 1.5);

      
      return;

      
    case 'set'      
      parname = x; parval = y;
      switch parname
          case 'ratname',
              ratname.value = parval;
          case 'experimenter',
              experimenter.value = parval;
          case 'data_file',
              data_file.value = parval;
		  case 'save_all_data_to_sql'
			  save_all_data_to_sql.value=parval;

          otherwise,
              warning('SAVELOAD:InvalidParam', 'Don''t know how to set "%s", not doing anything', parname);
      end;
      
      
      % ------------ CASE GET_ALL_INFO --------------------
      %Sundeep Tuteja, 22nd December, 2009: Adding a case to get
      %experimenter name, rat name, settings file loaded, if any, and data file. Case
      %'get_info' preserved
      
       case 'get_all_info'
           x = struct([]);
           x(1).experimenter = value(experimenter);
           x(1).ratname = value(ratname);
           [dummy, settings_file_from_runrats] = runrats('get_settings_file_path'); clear('dummy');
           %Giving preference to runrats (this should be changed, since it
           %is possible to load a settings file even while running runrats.
           if ~isempty(settings_file_from_runrats)
               settings_file.value = settings_file_from_runrats;
           end
           x(1).settings_file = value(settings_file);
           x(1).data_file = value(data_file);
           y = [];
           z = [];
           return;
      
      
    case 'get_info',        % ------------ CASE GET_INFO --------------------
    y=value(ratname);
    x=value(experimenter);
    z=value(SaveTime); %#ok<NODEF> (This line OK. SPH initialized above)
    return;

    case 'set_info',        % ------------ CASE SET_INFO --------------------
       ratname.value=y; %#ok<STRNU>
       experimenter.value=x; %#ok<STRNU> 
       return;
    
    case 'savesets',       % ------------ CASE SAVESETS --------------------
      if     nargin == 3, varargin = {x}; 
      elseif nargin == 4, varargin = {x y};
      elseif nargin >= 5, varargin = [{x y} varargin];
      end;
      pairs = { ...
        'interactive'    value(interactive_by_default)   ; ...
        'commit'         1   ; ... % <~> turned back on (settings>>server)
      }; parseargs(varargin, pairs);
      
      % <~> New functionality for saving settings for multiple rats at
      %       once by accepting a comma-separated list of rat names in the
      %       ratname field.   25 Oct 2007,   -s
      full_rat_str = value(ratname);
      commas_in_ratname = strfind(full_rat_str,',');
      commas_in_ratname = [0, commas_in_ratname, length(full_rat_str)+1];
      for i=2:length(commas_in_ratname),
          this_ratname = strtrim(full_rat_str(commas_in_ratname(i-1)+1:commas_in_ratname(i)-1));
          if ~isempty(this_ratname),
              ratname.value = this_ratname;
              save_solouiparamvalues(   this_ratname, ...
                  'experimenter',       value(experimenter), ...
                  'interactive',        interactive, ...
                  'owner',              class(obj), ...
                  'commit',             commit);
              ratname.value = full_rat_str;
          end;
      end;

      return;
      
    case 'loadsets',       % ------------ CASE LOADSETS --------------------
      % Disallow starting to run until settings finish loading:
      dispatcher('runstart_disable');
      [sets_were_loaded, settings_file.value]= load_solouiparamvalues(value(ratname), 'experimenter', value(experimenter), 'owner', class(obj));
      %     TESTING
      if sets_were_loaded && ~dispatcher('is_running'),
          settings_file_load_time.value = now;
        % If we're not yet running, then current stored values for this
        % trial will be overriden by the settings that are being loaded
        % before the trial starts. Pop the history.  Added by CDB to fix
        % bug introduced by 'prepare_next_trial' below.
        pop_history(class(obj), 'include_non_gui', 1);
        feval(class(obj), obj, 'prepare_next_trial');
        % added by jerlich to flush the default SM loaded at 'init'.
      end;  % If we *are* already running a trial, then prepare_next_trial will be run when the trial ends; 
            % and that is the right time to run it. 
          
      %     end TESTING
      dispatcher('runstart_enable');
      
      return;
      
       case 'get_settings_file_load_time'
           [dummy, x1] = runrats('get_settings_file_load_time'); clear('dummy');
           x2 = value(settings_file_load_time);
           x = max(x1, x2); settings_file_load_time.value = x;
           y = [];
           z = [];
           return;

      
    case 'savedata',       % ------------ CASE SAVEDATA --------------------
      if     nargin == 3, varargin = {x}; 
      elseif nargin == 4, varargin = {x y};
      elseif nargin >= 5, varargin = [{x y} varargin];
      end;
      pairs = { ...
        'interactive'    value(interactive_by_default)   ; ...
        'commit'         1   ; ...
        'asv'            0   ; ...
      }; parseargs(varargin, pairs);
  
      SaveTime.value = datestr(now); % <~> added 2007.08.08
      
      x=save_soloparamvalues(value(ratname),  'experimenter', value(experimenter), ...
      						 'interactive', interactive, ...
                             'owner', class(obj), ...
                             'commit', commit, 'asv', asv);
	  data_file.value=x;

      return;
      
      
    case 'autosave_data',  % ------------ CASE AUTOSAVE_DATA --------------------
      n_autosave_calls.value = n_autosave_calls + 1;
      if rem(n_autosave_calls(1), autosave_frequency(1)) == 0,
        SavingSection(obj, 'savedata', 'interactive', 0, 'commit', 0, 'asv', 1);
      end;
      
    case 'set_autosave_frequency',  % ------------ CASE SET_AUTOSAVE_FREQUENCY --------------------
      if nargin < 3,
        warning('%s : %s : need an extra argument, \na scalar positive integer\nautosave_frequency not changed.', mfilename, action); %#ok<WNTAG>
        return;
      end;
      arg = x; 
      if isscalar(arg) && isnumeric(arg) && arg>=1, 
        autosave_frequency.value = ceil(arg);
        return;
      end; 
      
      warning('%s : %s : argument must be numeric,\na scalar positive integer\nautosave_frequency not changed.', mfilename, action); %#ok<WNTAG>
      

    case 'get_autosave_frequency',  % ------------ CASE GET_AUTOSAVE_FREQUENCY --------------------
      x = value(autosave_frequency);
	  
	  
    case 'get_data_file',  % ------------ CASE GET_AUTOSAVE_FREQUENCY --------------------
      x = value(data_file);
      
    case 'loaddata',       % ------------ CASE LOADDATA --------------------
      if     nargin == 3, varargin = {x}; 
      elseif nargin == 4, varargin = {x y};
      elseif nargin >= 5, varargin = [{x y} varargin];
      end;
      pairs = { ...
        'interactive'    1   ; ...
      }; parseargs(varargin, pairs);
      %     Although this shouldn't happen, we should be consistent and
      %       restrict running here, too.
      % Disallow starting to run until data finish loading:
      dispatcher('runstart_disable');
      load_soloparamvalues(value(ratname), 'experimenter', value(experimenter) ,...
          'owner', class(obj), 'interactive', interactive);
      dispatcher('runstart_enable');      
      
      return;
    
      
    case 'check_autosave',
      if rem(n_done_trials,19) == 0 && n_done_trials>1,
         SavingSection(obj, 'savedata', 'interactive', 0, 'commit', 0, ...
                       'asv', 1);
      end;
    
    case 'reinit',       % ------------ CASE REINIT --------------------
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
   
   
      