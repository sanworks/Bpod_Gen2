%     .../Modules/Settings.m
%     Interface for global BControl settings; BControl system;
%     this file written by Sebastien Awwad, 2007
%
%
%   SETTINGS SYSTEM BASIC INSTRUCTIONS:
%       
%       Think of this interface as a way to read settings files.
%
%       The SIMPLEST WAY TO USE IT:
%
%           setting = bSettings('get','SETTINGGROUP','settingname');
%       
%       You can do that without doing anything else first, and you'll get
%         back the setting value - as a double if it looks like a number
%         (str2double), and as a string otherwise.
%       
%       (If settings haven't been loaded already, the "Default" and
%          "Custom" files are loaded on the fly with bSettings('load').)
%
%       See the default settings file Settings/Settings_Default.conf for
%         settings file format.
%
%       Additional features and details follow.
%
%
%
%
%   INTERFACE DESCRIPTION:
%
%     The first argument to this function is the Action to perform
%       (case-insensitive).
%     POSSIBLE ACTIONS:
%
%           GET                 <-- useful          for normal users
%           COMPARE             <-- useful          for normal users
%           LOAD                <-- not necessary   for normal users
%           NOTLOADED           <-- not necessary   for normal users
%           GETALL              <-- not recommended for normal users
%           CLEAR               <-- not recommended for normal users!
%
%
%     All functions also return error IDs (0 if OK) and error messages (''
%       if okay).
%       
%
%     Descriptions of the actions & required additional arguments:
%
%
%     - get
%         GET retrieves the initialized setting with the given name, or all
%           settings in the group if setting name 'any' is given.
%
%         If no setting exists with the given name, errID will be as
%           shown below, and an informative error message should be
%           provided.
%
%         If no settings files have been loaded yet, bSettings('load') is
%           called first.
%
%         ADDITIONAL ARGS:	2
%              - Arg#1:             name of target setting's group
%              - Arg#2:             name of target setting, or 'all' for
%                                     all settings in the group (returns
%                                     cell array of format:
%                                        {s1name, s1value, s1groupname;
%                                         s2name, s2value, s2groupname;
%                                          ...}
%         RETURNS:	[settingval errID errmsg]
%              - settingval:        requested setting value, or cell array
%                                     of settings if multiple settings are
%                                     requested
%              - errmsg:            '' if OK, error string otherwise
%              - errID:             0  if setting was found,
%                                   1  if setting was not found (and value
%                                          returned should be ignored)
%                                   3  if group was not found
%                                   8  if settings were not loaded
%                                        beforehand and attempt to load
%                                        settings using bSettings('load')
%                                        failed
%                                   -1 if programming error (errID not set)
%                                          PLEASE CONTACT DEVELOPER.
%         SAMPLE CALLS:
%               [maindir errID errmsg] = bSettings('get', 'MAIN', 'Main_Directory');
%               cvs_username = bSettings('get','CVS','CVS_Username');
%               [DIOLines err msg] = bSettings('get', 'DIOLINES', 'ALL');
%
%
%
%     - compare
%         COMPARE compares the setting with the given name to a specified
%           value. If no setting exists with the given name, errID is as
%           shown below, and an informative error message is provided.
%
%           If no settings files have been loaded, bSettings('load') is
%             called first.
%
%         ADDITIONAL ARGS:	3
%              - Arg#1:             name of target setting's group
%              - Arg#2:             name of target setting
%              - Arg#3:             value to compare the setting to
%                      
%         RETURNS:              [settingval errID errmsg]
%              - are_equal:         logical true if the loaded setting
%                                     value matches the given value, false
%                                     in all other cases
%              - errmsg:            '' if OK, error string otherwise
%              - errID:             0  if setting was found and is valid,
%                                   1  if setting was not found (and value
%                                          returned should be ignored)
%                                   3  if group was not found
%                                   8  if settings were not loaded
%                                        beforehand and attempt to load
%                                        settings using default filenames
%                                        failed
%                                   -1 if programming error (errID not set)
%         SAMPLE CALL:
%               [playsounds errID errmsg] = ...
%                   bSettings('compare', 'EMULATOR', 'softsound_play_sounds', 1);
%
%
%
%     - load
%         Load reads settings files into memory and reports success.
%
%         Load can work TWO WAYS:
%           0 ARGS. Loads the "Default" and "Custom" settings files.
%           N ARGS. Loads specified settings files in order, first to last.
%
%
%         ADDITIONAL ARGS:	0 OR any number of nonempty strings
%              - Optional Arg#N:	filename of a settings file to load
%
%         RETURNS:	[errID errmsg]
%               - errmsg:            '' if OK, error string otherwise
%               - errID:            0  if successful
%                                   10 if bad arguments (e.g. fname '')
%                                   1  if file was not found
%                                   2  if file is not correctly formatted
%                                        or could not be opened for reading
%                                   -1 if programming error (errID not set)
%                                          PLEASE CONTACT DEVELOPER.
%         SAMPLE CALLS:
%                   bSettings('load');
%                   [errID errmsg] = bSettings('load');
%                   [errID errmsg] = bSettings('load','some_settings.conf');
%                   [errID errmsg] = ...
%                       bSettings('load','set1.conf','set2.conf', ...
%                   	'set3.conf', 'set4.conf');
%     
%         NOTES ON SPECIAL CASES:
%         - ORDER:
%           If a setting being loaded has the same name as one previously
%             loaded, the previously loaded value is overwritten, so later
%             files prevail.
%
%
%
%
%
%
%     - notloaded
%         NOTLOADED checks to see if any settings have been loaded into the
%           SettingsObject.
%         ADDITIONAL ARGS:      0
%         RETURNS:              notloaded
%              - notloaded:         0  if settings have been loaded into
%                                        SettingsObject
%                                   1  if no settings are loaded
%              - errID:             always 0
%              - errmsg:            always ''
%         SAMPLE CALL:
%               if bSettings('notloaded'), error('Weird!'); end;
%
%
%
%
%     - getall
%         GETALL returns the settings data as internally represented:
%               in a struct ('settings') with fields corresponding to
%               settings groups with internal fields corresponding to
%               individual settings, e.g.:
%                   settings.GROUP.settingname      = 'blah value'
%                   settings.OTHERGROUP.mrsetting   = '0'
%
%
%           If no settings files have been loaded, bSettings('load') is
%             called first. See comments there.
%
%         ADDITIONAL ARGS:      0
%         RETURNS:              [setsstruct errID errmsg]
%              - setsstruct:        a struct with format as above
%              - errmsg:            '' if OK, error string otherwise
%              - errID:             0  if no problems
%                                   1  if error ??? (should not happen)
%                                   8  if settings were not loaded
%                                        beforehand and attempt to load
%                                        settings using default filenames
%                                        failed
%                                   -1 if programming error (errID not set)
%                                          PLEASE CONTACT DEVELOPER.
%         SAMPLE CALLS:
%               [settingsstruct errID errmsg] = bSettings('getall');
%               settingsstruct = bSettings('getall');
%
%
%
%
%
%     - clear
%         CLEAR replaces the global settings object with a fresh one that
%           has no settings loaded.
%         ADDITIONAL ARGS:      0
%         RETURNS:              [errID errmsg]
%              - errID:         0   currently
%              - errmsg:        ''  currently
%         SAMPLE CALL:
%               bSettings('clear')
%
%
%
%
%     Helper functions in this file:
%        - err_and_errdlg(error_string)
%
%
function varargout = bSettings(action, varargin)

global BControl_Settings; %    the global settings object that this function instantiates and interfaces on
errID = -1; errmsg = ''; %#ok<NASGU> (errID=-1 OK despite unused)
errorlocation = 'Settings Interface (/Modules/Settings.m)';



%     -------------------------------------------------------------
%     -------  DEFINE CONSTANTS (SETTINGS FILENAMES)
%     -------------------------------------------------------------
%     It is currently the case that these filenames are separately
%       specified in Modules/Settings.m and newstartup.m.
%
%     THEY MUST BE THE SAME!
%
%     Such things should not be separately defined, but I haven't decided
%       on a clean way to do this otherwise yet.... ):
%<~>TODO: consolidation, see above
FILENAME__SETTINGS_DIR              = '/Users/littlej/Documents/ExperPortNewClient_ORIGINAL_DONT_MODIFY/Settings';
if ~any(strcmp(strsplit(path,':'),FILENAME__SETTINGS_DIR))
    error('bSettings: please change your default path to "Settings" in "/Modules/bSettings"!')
end
FILENAME__DEFAULT_SETTINGS          = [ FILENAME__SETTINGS_DIR filesep ...
    'Settings_Default.conf'                                             ];
FILENAME__CUSTOM_SETTINGS           = [ FILENAME__SETTINGS_DIR filesep ...
    'Settings_Justin2PRig.conf'                                              ];
FILENAME__SETTINGS_TEMPLATE         = [ FILENAME__SETTINGS_DIR filesep ...
   'Settings_Template.conf'                                            ]; %#ok<NASGU> (value not used, OK)

%'Settings_Default.conf' 
%'Settings_Template.conf'

action = lower(action); %     make lowercase for case insensitivity

switch action,
    
    
    
    case 'notloaded',
        %     emptiness = bSettings('notloaded')
        %     Generate an error iff* we have n args where n~=1.
        error(nargchk(1, 1, nargin, 'struct'));
        notloaded = ~exist('BControl_Settings', 'var')        ...
            || isempty(BControl_Settings)                   ...
            || ~isa(BControl_Settings,'SettingsObject')     ...
            || NoSettingsLoaded(BControl_Settings);
        errID = 0;
        varargout = {notloaded errID errmsg};
        return;
        
        
        
    case 'clear',
        %     [errID errmsg] = bSettings('clear')
        %     Generate an error iff* we have n args where n~=1.
        error(nargchk(1, 1, nargin, 'struct'));
        BControl_Settings = SettingsObject();
        errID = 0;
        varargout = {errID errmsg};
        return;
        
    
        
    case 'get',
        %     [settingval errID errmsg]  = bSettings('get', <setting_group_name>, <setting_name>)
        %     Generate an error iff* we have n args where n~=3.
        error(nargchk(3, 3, nargin, 'struct'));
        groupname       = varargin{1};
        settingname     = varargin{2};
        settingvalue    = NaN;
        

        
        %     -------------------------------------------------------------
        %     -------  GET:    auto-load settings if not yet loaded
        %     -------------------------------------------------------------
        %     If global SettingsObject does not exist or does not have
        %       settings loaded, load using standard settings file names.
        if isempty(BControl_Settings) || NoSettingsLoaded(BControl_Settings),
            [errID_internal errmsg_internal] = bSettings('load');
            if errID_internal,
                errID = 8;
                errmsg = [errorlocation ' :  GET failed. No settings had yet been loaded. Attempt to load settings first using default filenames failed. Nested settings load error (ID: ' int2str(errID_internal) ') generated:   ' errmsg_internal];
                varargout = {settingvalue errID errmsg};
                %err_and_errdlg(errmsg);
                return;
            end;
        end;            %     end if-settings-must-be-loaded-first
        
        %     -------------------------------------------------------------
        %     -------  GET:    retrieving requested setting
        %     -------------------------------------------------------------
        [settingvalue errID_internal errmsg_internal] = ...
            GetSetting(BControl_Settings,groupname,settingname);

        if errID_internal,
            if errID_internal == 7,
                err_and_errdlg([errorlocation ' : PROGRAMMING ERROR: We just made sure that settings were loaded, but GetSettings says they are not!']);
            end;
            errID = errID_internal;
            errmsg = [errorlocation ' :  GET failed. GetSetting error (ID: ' int2str(errID_internal) ') generated:   ' errmsg_internal];
            %err_and_errdlg(errmsg);
        else
            errID = 0;
        end;
        
        varargout = {settingvalue errID errmsg};
        return;

        
        
        
        
        
        
    case 'getall',
        %     [settingsstruct errID errmsg] = bSettings('getall')
        %     Generate an error iff* we have n args where n~=1.
        error(nargchk(1, 1, nargin, 'struct'));
        settings = struct;

        %     -------------------------------------------------------------
        %     -------  GETALL:    auto-load settings if not yet loaded
        %     -------------------------------------------------------------
        %     If global SettingsObject does not exist or does not have
        %       settings loaded, load using standard settings file names.
        if isempty(BControl_Settings) || NoSettingsLoaded(BControl_Settings),
            [errID_internal errmsg_internal] = bSettings('load');
            if errID_internal,
                errID = 8;
                errmsg = [errorlocation ' : GETALL failed. No settings had yet been loaded. Attempt to load settings first using default filenames failed. Nested settings load error (ID: ' int2str(errID_internal) ') generated:   ' errmsg_internal];
                varargout = {settings errID errmsg};
                %err_and_errdlg(errmsg);
                return;
            end;
        end;            %     end if-settings-must-be-loaded-first
        
        %     -------------------------------------------------------------
        %     -------  GETALL:    retrieving all settings
        %     -------------------------------------------------------------
        [settings errID_internal errmsg_internal] = ...
            GetAllSettings(BControl_Settings);

        if errID_internal,
            if errID_internal == 1,
                err_and_errdlg([errorlocation ' : PROGRAMMING ERROR: We just made sure that settings were loaded, but GetSettings says they are not!']);
            end;
            errID = errID_internal;
            errmsg = [errorlocation ' : GETALL failed. GetAllSettings error (ID: ' int2str(errID_internal) ') generated:   ' errmsg_internal];
            %err_and_errdlg(errmsg);
        else
            errID = 0;
        end;
        
        varargout = {settings errID errmsg};
        return;

        
        
        
        
        
    case 'compare',
        %     [are_equal errID errmsg]  = ...
        %       bSettings('compare', <setting_group_name>, <setting_name>, <comparison_val>)
        %     Generate an error iff* we have n args where n~=3.
        error(nargchk(4, 4, nargin, 'struct'));
        groupname       = varargin{1};
        settingname     = varargin{2};
        comparisonval   = varargin{3};
        settingvalue    = NaN;
        are_equal       = false;

        %     -------------------------------------------------------------
        %     -------  COMPARE:    auto-load settings if not yet loaded
        %     -------------------------------------------------------------
        %     If global SettingsObject does not exist or does not have
        %       settings loaded, load using standard settings file names.
        if isempty(BControl_Settings) || NoSettingsLoaded(BControl_Settings),
            [errID_internal errmsg_internal] = bSettings('load');
            if errID_internal,
                errID = 8;
                errmsg = [errorlocation ' : COMPARE failed. No settings had yet been loaded. Attempt to load settings first using default filenames failed. Nested settings load error (ID: ' int2str(errID_internal) ') generated:   ' errmsg_internal];
                varargout = {settingvalue errID errmsg};
                %err_and_errdlg(errmsg);
                return;
            end;
        end;            %     end if-settings-must-be-loaded-first

        %     -------------------------------------------------------------
        %     -------  COMPARE:    retrieving & comparing requested setting
        %     -------------------------------------------------------------
        [settingvalue errID_internal errmsg_internal] = ...
            GetSetting(BControl_Settings,groupname,settingname);

        if errID_internal,
            if errID_internal == 7,
                err_and_errdlg([errorlocation ' : PROGRAMMING ERROR: We just made sure that settings were loaded, but GetSettings says they are not!']);
            end;
            errID = errID_internal;
            errmsg = [errorlocation ' : COMPARE failed. GetSetting error (ID: ' int2str(errID_internal) ') generated:   ' errmsg_internal];
            %err_and_errdlg(errmsg);
        else
            [are_equal errID errmsg] = ...
                TestSetting(BControl_Settings,groupname,settingname,comparisonval);
        end;

        varargout = {are_equal errID errmsg};
        return;

        
        
        
        
    case 'load',
        
        %     [errID errmsg] = bSettings('load', <name_of_settings_file>)
        %     Generate an error iff* we have n args where n<1 (not possible).
        error(nargchk(1, Inf, nargin, 'struct'));
        filenames = {};
        %load_rig_settings_based_on_RTSM_Settings_value = false;
        if nargin>1,
            for i = 1:length(varargin),
                filenames{i} = varargin{i};
                if isempty(filenames{i}) || ~ischar(filenames{i}),
                    errID = 10;
                    errmsg = [errorlocation ' : LOAD called incorrectly. Requires no additional arguments OR any number of additional nonempty filename strings. Sample calls: bSettings(''load'') or bSettings(''load'',''mr_settings_file.conf'', ''customsettings.conf'',''randomsettings.conf'')'];
                    varargout = {errID errmsg};
                    %err_and_errdlg(errmsg);
                    return;
                end;
            end;
        else
            %     If no filenames are specified, use the default
            %       set of filenames and turn on loading of rig settings
            %       based on the RTSM_Server_Type setting.
            filenames{1} = FILENAME__DEFAULT_SETTINGS;
            filenames{2} = FILENAME__CUSTOM_SETTINGS;
            %load_rig_settings_based_on_RTSM_Settings_value = true;
        end;
        
        %     -------------------------------------------------------------
        %     -------  LOAD:    settings object verification
        %     -------------------------------------------------------------
        %     Does global SettingsObject exist? If not, create it.
        if isempty(BControl_Settings),
            BControl_Settings = SettingsObject();
        end;
        
        %     -------------------------------------------------------------
        %     -------  LOAD:    settings loading
        %     -------------------------------------------------------------
        for i = 1:length(filenames),
            
            [BControl_Settings errID_internal errmsg_internal] = ...
                LoadSettings(BControl_Settings, filenames{i});
            if errID_internal,
                errID = errID_internal;
                errmsg = [errorlocation ' : LOAD failed. LoadSettings call on the settings file "' filenames{i} '" generated error (ID: ' int2str(errID_internal) '):   ' errmsg_internal];
                varargout = {errID errmsg};
                %err_and_errdlg(errmsg);
                return;
            end;
        end;            %     end iterate over settings files

        
        %         %     -------------------------------------------------------------
        %         %     -------  LOAD:    load RTSM settings based on RTSM_Settings
        %         %     -------------------------------------------------------------
        %         if load_rig_settings_based_on_RTSM_Settings_value,
        %             errorsublocation = ['LOAD failed. After loading default and custom settings, attempt to load settings for the real-time state machine type in use failed. Check the RTSM_Settings setting in ' FILENAME__CUSTOM_SETTINGS '.'];
        %             %     Get RTSM_Settings setting loaded from default/custom.
        %             [RTSM_Settings errID_internal errmsg_internal] = ...
        %                 GetSetting(BControl_Settings,'RIGS','RTSM_Settings');
        %             if errID_internal,
        %                 errID = 1;
        %                 errmsg = [errorlocation ' : ' errorsublocation ' The "RTSM_Settings" setting could not be retrieved. Error received from GetSetting call: ERRID was ' int2str(errID_internal) ', message was: ' errmsg_internal];
        %                 varargout = {errID errmsg};
        %                 %err_and_errdlg(errmsg);
        %                 return;
        %             elseif ~ischar(RTSM_Settings) || isempty(RTSM_Settings),
        %                 errID = 1;
        %                 errmsg = [errorlocation ' : ' errorsublocation ' RTSM_Settings was empty or numeric/not-a-string.' ];
        %                 varargout = {errID errmsg};
        %                 %err_and_errdlg(errmsg);
        %                 return;
        %             else
        %                 %     Translate RTSM_Settings into filename.
        %                 RTSM_Settings_File = [ FILENAME__SETTINGS_DIR filesep ...
        %                     'Settings_' RTSM_Settings '.conf'];
        %                 if ~exist(RTSM_Settings_File,'file'),
        %                     errID = 1;
        %                     errmsg = [errorlocation ' : ' errorsublocation ' RTSM_Settings was "' RTSM_Settings '", but file "' RTSM_Settings_File '" did not exist. Set RTSM_Settings value to an accepted value.'];
        %                     varargout = {errID errmsg};
        %                     %err_and_errdlg(errmsg);
        %                     return;
        %                 else
        %                     %     Load settings from the indicated file.
        %                     [BControl_Settings errID_internal errmsg_internal] = ...
        %                         LoadSettings(BControl_Settings,RTSM_Settings_File);
        %                     if errID_internal,
        %                         errID = errID_internal;
        %                         errmsg = [errorlocation ' : ' errorsublocation ' LoadSettings call on the specified RTSM settings file "' RTSM_Settings_File '" generated error (ID: ' int2str(errID_internal) '):   ' errmsg_internal];
        %                         varargout = {errID errmsg};
        %                         %err_and_errdlg(errmsg);
        %                         return;
        %                     end;%     end if RTSM settings file load failed
        %                 end;    %     end if/else RTSM settings file does not exist
        %             end;        %     end if/else... problem with RTSM_Settings
        %         end;            %     end if loading RTSM settings
        
        
        %     If we've made it here, loading succeeded.
        errID = 0;
        
        varargout = {errID errmsg};
        return;
        
        
        
    otherwise
        errmsg = [errorlocation ' : invalid action ("' action '") called. Please see documentation at top of file specified in this error.'];
        err_and_errdlg(errmsg);

end; %     end switch action

errmsg = [errorlocation ' : PROGRAMMING ERROR. It should not be possible to reach this point in the code. Were changes made to the code? Contact a developer.'];
err_and_errdlg(errmsg);



%     REDUNDANT BELOW
%     must decide where to put them in the end

%     Helper function that simply prints a string in an error dialog and
%       also calls error(<that string>).
function [] = err_and_errdlg(error_string)
errordlg(error_string);
error(error_string);

