%     .../newstartup.m
%     Initialization file for Dispatcher-BControl; BControl system;
%
%    ----------------------- INSTRUCTIONS FOR USERS -----------------------
%
%       To START Dispatcher-BControl, simply type:
%
%               >> newstartup; dispatcher('init');
%
%                   and pick your protocol from the pull-down list.
%
%
%       To START the simplified RunRats GUI for techs instead, type:
%
%               >> newstartup; runrats('init');
%
%
%      These commands must be run from the root BControl code directory!
%      Newstarup will fail if critical files or directories are not found
%        in the current directory.
%
%      This file is not meant to be modified and should be kept UP TO DATE.
%      Use the SETTINGS FILE (Settings/Settings_Custom.conf) created on
%        first run of the system to control settings for BControl.
%
%      BControl DOCUMENTATION is available in the wiki at:
%               http://brodylab.princeton.edu/bcontrol
%
%
%     ------------------------- TECHNICAL DETAILS -------------------------
%
%     Outline for newstartup.m:
%       - CHECK FOR SEVERAL REQUIRED FILES
%    	- FIRST RUN?
%    	- ADD PATHS
%    	- LOAD SETTINGS
%    	- CHECK A FEW SETTINGS
%    	- LOAD SOME SETTINGS INTO GLOBALS for backward compatibility
%
%
%
%      HELPER FUNCTIONS at the end of this file:
%           HandleNewstartupError
%           BControl_First_Run
%           Verify_Settings
%           Compatibility_Globals
%
function [] = newstartup()
global BpodSystem
if isempty(BpodSystem)
    clear global BpodSystem
    error('Error: You must run Bpod() at the command line, before you can open B-control');
end
%     This startup script will always dbstop on error - but near the end,
%       we clear this and set dbstop based on Settings files.
dbstop if error;
dbstop if caught error 'TIMERERROR:catcherror'; 
% This allows debugging runtime errors that occur within the dispatcher
% timer loop

%cd into ExperPort so newstartup doesn't break if you aren't there already
try cd(bSettings('get','GENERAL','Main_Code_Directory'));
catch %#ok<CTCH>
end



%     -------------------------------------------------------------
%     -------  DEFINE CONSTANTS (SETTINGS FILENAMES)
%     -------------------------------------------------------------
%     It is currently the case that these filenames are separately
%       specified in Modules/Settings.m and newstartup.m.
%
%     THEY MUST BE THE SAME!
%
%     Such things should not be separately defined, but I haven't decided
%       on a clean way to do this without limiting features yet.... ):
%<~>TODO: consolidation, see above
FILENAME__SETTINGS_DIR              = 'Settings';
FILENAME__DEFAULT_SETTINGS          = [ FILENAME__SETTINGS_DIR filesep ...
    'Settings_Default.conf'                                             ];
FILENAME__CUSTOM_SETTINGS           = [ FILENAME__SETTINGS_DIR filesep ...
    'Settings_Custom.conf'                                              ];
FILENAME__SETTINGS_TEMPLATE         = [ FILENAME__SETTINGS_DIR filesep ...
    'Settings_Template.conf'                                            ];



%     -------------------------------------------------------------
%     -------  CHECK FOR SEVERAL REQUIRED FILES
%     -------------------------------------------------------------
%     Check to see if a default settings file exists in this directory. If
%       not, treat as if we are not in the proper directory.
cd(fullfile(BpodSystem.Path.BcontrolRootFolder, 'ExperPort'));
if		   ~exist([pwd filesep 'bin'],          'dir')				...
        || ~exist([pwd filesep 'HandleParam'],  'dir')				...
        || ~exist([pwd filesep 'Protocols'],    'dir')				...
        || ~exist([pwd filesep 'Modules'],      'dir')				...
        || ~exist([pwd filesep 'Utility'],		'dir')				...
        || ~exist([pwd filesep 'Plugins'],		'dir')  			...
        || ~exist([pwd filesep 'Settings'],		'dir')				...
        || ~exist([pwd filesep 'SoloUtility'],  'dir')  			...
        || ~exist([pwd filesep FILENAME__DEFAULT_SETTINGS], 'file')	,
    errID = 1;
    errmsg = ['BControl must be started from its root directory,' ...
        ' and the following directories and files must exist there:' ...
        sprintf('\n') 'bin, HandleParam, Protocols, Modules, Utility,'...
        ' Plugins, Settings, SoloUtility, and ' FILENAME__DEFAULT_SETTINGS...
        '.' sprintf('\n') ...
        'If you are missing files, please use cvs to update your code' ...
        ' from our repository.'];

    HandleNewstartupError(errID, errmsg);
    % HandleNewstartupError is a helper fn in this file for code brevity.
    % If errID is nonzero, it displays errmsg in a pop-up dialog and also
    %   calls error(errmsg). It's used all over this file.
    return;

end;


%     -------------------------------------------------------------
%     -------  FIRST RUN?
%     -------------------------------------------------------------
%     If the custom settings file does not exist, assume that this is
%       BControl's first run and create it from the settings template.
%     Also display a welcome pop-up with the WIKI address.
if ~exist(FILENAME__CUSTOM_SETTINGS,'file'),
    [errID errmsg] = BControl_First_Run(FILENAME__CUSTOM_SETTINGS, FILENAME__SETTINGS_TEMPLATE);
    HandleNewstartupError(errID, errmsg);
end;



%     -------------------------------------------------------------
%     -------  ADD BCONTROL CODE PATHS
%     -------------------------------------------------------------
%     Note that when added in one call, the paths are added such that the
%       first path listed is at the "top" of the MATLAB path, and the last
%       path listed is the "bottom" path of the added paths, just above the
%       paths previosly in the MATLAB path.
%       If these were separate calls, the first call's path argument would
%       end up below the path in the next call, etc.
%     For now, path order is, unfortunately, important for us.... There are
%       functions with the same names that are not methods.
%       This is a problem.
addpath([pwd filesep 'bin']   ...
    ,   [pwd filesep 'HandleParam'] ...
    ,   [pwd filesep 'Analysis' filesep 'dual_disc'] ...
    ,   [pwd filesep 'Analysis' filesep 'duration_disc'] ...
    ... % <~> removed addpath for the following deleted directory that was causing CVS problems:    ,   [pwd filesep 'Analysis' filesep 'Event_Analysis'] ...
	,   [pwd filesep 'Analysis' filesep 'ProAnti'] ...
	,   [pwd filesep 'Analysis' filesep 'NeuraLynx'] ...
    ,   [pwd filesep 'Analysis' filesep 'Video_Tracker'] ...
    ,   [pwd filesep 'Analysis' filesep 'SameDifferent'] ...
    ,   [pwd filesep 'Analysis'] ...
    ,   [pwd filesep 'soundtools'] ...
    ,   [pwd filesep 'Protocols'] ...
    ,   [pwd filesep 'Modules' filesep 'TCPClient'] ...
    ,   [pwd filesep 'Modules' filesep 'SoundTrigClient'] ...
    ... % <~> Removing this line 2008.June.25. There are two NetClient directories now, and we decide which one to add separately just below. old line:     ,   [pwd filesep 'Modules' filesep 'NetClient'] ...
    ,   [pwd filesep 'Modules'] ...
    ,   [pwd filesep 'Utility'] ...
    ,   [pwd filesep 'Utility' filesep 'Zut' ] ... % <~> Rat Scheduler, etc. etc.
    ,   [pwd filesep 'Plugins'] ...
    ,   [pwd filesep 'SoloUtility'] ...
    ... % <~> Removing this line 2020.03.19. There are multiple windows compiled versions and only 1 should be in the path   [pwd filesep 'MySQLUtility' filesep 'win64'] ...
    ... % <~> Removing this line 2020.03.19. This should already be in the path and it needs to be after the one above,      [pwd filesep 'MySQLUtility'] ...
    ,   pwd ...
    );

% <~> Improved timer. This code added 2008.Sep.01.
%     The modified timer code housed in Utility/provisional/@timer was
%       added several days before - but is never on the path unless the
%       setting below matches.
if bSettings('compare','GENERAL','use_timers',2),
    addpath([pwd filesep 'Utility' filesep 'provisional']);
end;

% <~> New code, 2008.Sep.04. Allows for separate Protocols
%       directory outside of Exper directory.
% Matlab doesn't like relative paths for debugging purposes.
% So, just step out of experport and add the Protocols path.
if exist([pwd filesep '..' filesep 'Protocols'],'dir'),
    olddir=pwd;
    cd('..');
    addpath([pwd filesep 'Protocols']);
    cd(olddir);
end;

% <~> WARNING: NetClient has not been added to the path at this point in
%       the code. It is added a few lines below, after the
%       bSettings('load') call, so that we can look at the RIGS;fake_rp_box
%       setting.  (2008.June.25)



%     -------------------------------------------------------------
%     -------  ADD JAVA CLASS FOR MATLABCONTROL
%     -------------------------------------------------------------
%  
% if usejava('jvm')
%     javaaddpath([pwd filesep 'jar' filesep 'mc.jar']);
% end
    



%     -------------------------------------------------------------
%     -------  SETTINGS - LOAD SETTINGS FILES
%     -------------------------------------------------------------
%     Load BControl settings files:
%               first	...Settings/Settings_Default.conf
%               then	...Settings/Settings_Custom.conf
%
%     Values set in the custom file override values set in the default
%       file.
%
[errID errmsg] = bSettings('load');
HandleNewstartupError(errID, errmsg);



%     -------------------------------------------------------------
%     -------  SETTINGS - MINIMAL VERIFICATION
%     -------------------------------------------------------------
%     Check for data&code directory settings, issuing warnings and
%       creating data directory if necessary. (helper fn in this file)
[errID errmsg] = Verify_Settings();
HandleNewstartupError(errID, errmsg);



%     -------------------------------------------------------------
%     -------  SETTINGS - BACKWARD COMPATIBILITY (loaded->globals)
%     -------------------------------------------------------------
%     Old code used to use globals to store what is now stored in settings.
%     For backward compatibility, we load certain settings back into
%       globals.

%     This compare always returns false unless the setting exists, is
%       defined, and is logical true or 1 - so we only skip this step if
%       the skip flag is explicitly set.
skip_globals = bSettings('compare','COMPATIBILITY', ...
    'Skip_Loading_Old_Settings_Into_Globals', true);
if ~skip_globals,   % Otherwise, do fill the globals.
    [errID errmsg] = Compatibility_Globals();
    HandleNewstartupError(errID, errmsg);
end;


%     -------------------------------------------------------------
%     -------  DETERMINE RTLSM VERSION AND ADD NETCLIENT PATH
%     -------  2008.June.25
%     -------------------------------------------------------------
% <~> Determine which NetClient directory to add to the path.
%     The old RTLSM  requires Modules/NetClient.
%     The new RTLSM2 requires Modules/newrt_mods/NetClient.
%     Autodetection will be added later, but for now we'll use the
%       fake_rp_box setting set to 20 instead of 2 to denote RTLSM2
%       instead of old RTLSM. (New is version 100+ of Calin's RTFSM
%       project.)
if bSettings('compare','RIGS','fake_rp_box',20),
    addpath([pwd filesep 'Modules' filesep 'newrt_mods' filesep 'NetClient']);
else
    addpath([pwd filesep 'Modules' filesep 'NetClient']);
end;

    
    
%     -------------------------------------------------------------
%     -------  INTERPRET EXECUTION SETTINGS
%     -------------------------------------------------------------
%     Above we temporarily set dbstop if error. Here we clear that ...
dbclear if error;
%     ... and then set dbstop based on the settings files.
[dbstop_setting errID] = bSettings('get','GENERAL','dbstop_if');
if errID,
    %     If the setting didn't exist, default to dbstop if error.
    dbstop if error;
elseif strcmpi(dbstop_setting,'never')  ...
        || strcmpi(dbstop_setting,'NULL')   ...
        || isempty(dbstop_setting),
    %     If empty, 'never', or 'null', leave 'dbstop if' clear.
else
    %     Set dbstop to whatever the setting says.
    eval(['dbstop if ' dbstop_setting]);
    %     ... there's a minor problem here, actually.
    %     Suppose dbstop_setting is some inappropriate value. Because we've
    %       just cleared dbstop if error, we won't dbstop on this
    %       inappropriate command. This isn't a big deal, but it's worth
    %       noting.
end;


%     -------------------------------------------------------------
%     -------  Select a renderer for compatibility
%     -------------------------------------------------------------
% Different renderers have different behaviors-- but OpenGL appears to be
% buggy, at least as of the Matlab release used on 18-Jul-07. So, we use
% painters, which seems to work:
set(0, 'DefaultFigureRenderer', 'painters');


end  %     end function newstartup







%     ---------------------------------------------------------------------
%     ---------------------------------------------------------------------
%     ---------------------------------------------------------------------
%     ---------------------------------------------------------------------
%     ------------------ HERE BEGIN THE HELPER FUNCTIONS ------------------
%     ---------------------------------------------------------------------
%     ---------------------------------------------------------------------
%     ---------------------------------------------------------------------
%     ---------------------------------------------------------------------


%     -------------------------------------------------------------
%     -------------------------------------------------------------
%     -------  HandleNewstartupError (helper function for newstartup)
%     -------------------------------------------------------------
%     -------------------------------------------------------------
function [] = HandleNewstartupError(errID, errmsg)
if errID,
    errordlg(errmsg);
    error(errmsg);
end;
return;

end  %     end helper function HandleNewstartupError



%     -------------------------------------------------------------
%     -------------------------------------------------------------
%     -------  BControl_First_Run (helper function for newstartup)
%     -------------------------------------------------------------
%     -------------------------------------------------------------
%     on-first-run-of-system tasks; BControl system;
%
%
%     This was only intended to be run by newstartup.
%
%
%     Performs tasks on the first run of the system.
%     Currently:
%       - creates custom settings file from template (simple copy)
%       - presents simple welcome dialog
%
%
%     Suggestions for the future:
%        ? settings selection dialogs for rig type and cvs settings?
%
%
%     ARGUMENTS:
%       - FILENAME__CUSTOM_SETTINGS
%           string - filename of custom settings file to create
%       - FILENAME__SETTINGS_TEMPLATE
%           string - filename of settings template to copy from
%
%     RETURNS:	[errID errmsg]
%         errmsg:   '' if OK, else an informative error message
%         errID:
%           0:      no problem
%           1:      error creating custom settings file
%           -1:     LOGICAL ERROR IN THIS CODE (e.g. errID never set)
%
function [errID, errmsg] = BControl_First_Run(FILENAME__CUSTOM_SETTINGS, FILENAME__SETTINGS_TEMPLATE)
errID = -1; errmsg = ''; %#ok<NASGU> (errID=-1 OK despite unused)
errorlocation = 'ERROR in BControl_First_Run.m';

%     Generate an error iff* we have n args where n~=2.
error(nargchk(2, 2, nargin, 'struct'));

%     Newline character for convenience.
nl     = sprintf('\n');            %     :P

Welcome_String  = [ 'Welcome to BControl!' nl ...
    'Help can be found at "http://brodylab.princeton.edu/bcontrol"'];



if ~exist(FILENAME__CUSTOM_SETTINGS,'file'),
    if ~exist(FILENAME__SETTINGS_TEMPLATE,'file'),
        errID = 1;
        errmsg = [errorlocation ': Could not find settings template file at "' FILENAME__SETTINGS_TEMPLATE '".'];
        return;
    else
        [copysuccess,copymessage] = ...
            copyfile(FILENAME__SETTINGS_TEMPLATE,FILENAME__CUSTOM_SETTINGS,'f');
        if ~copysuccess,
            errID = 1;
            errmsg = [errorlocation ': Copying template settings file to custom settings file failed. Copy error message:  ' copymessage];
            return;
        else
            Welcome_String = [Welcome_String nl ...
                'A custom settings file has been created for you at "' ...
                FILENAME__CUSTOM_SETTINGS '".' nl ...
                'See instructions there and edit as desired.'];
        end;        %end if/else copy successful
    end;            %end if/else sample exists, copying
end;                %end if/else custom doesn't exist, copying


%     Other first-time tasks?


errID = 0;
msgbox(Welcome_String, 'First Run? - WELCOME TO BCONTROL!', 'help');



return;

end             % end helper function BControl_First_Run








%     -------------------------------------------------------------
%     -------------------------------------------------------------
%     -------  Verify_Settings (helper function for newstartup)
%     -------------------------------------------------------------
%     -------------------------------------------------------------
%     Verifies a small number of critical settings; BControl system;
%
%
%     This was only intended to be run by newstartup.
%
%
%     Currently:
%       - Checks that Main_Data_Directory is defined and exists (It is
%           created if it does not exist but is defined.).
%       - Checks that Main_Code_Directory is defined, exists, and is the
%           current directory (issuing warnings otherwise).
%       - Checks that value of fake_rp_box is 0-4 or 20. (Consult dispatcher
%           assumptions.)
%       - If fake_rp_box is 1,2, or 20, then checks for defined state_machine_server
%           string setting.
%
%     Suggestions for the future:
%       ? Affirm that all DIOLines that are assumed to be specified are
%           actually specified?
%       ? Check that fake_rp_box is a reasonable value?
%       ? Make sure that the DIOLINES settings are all numeric and unique
%           powers of two (unless 0 or NaN)?
%
%
%     ARGUMENTS:    NONE
%
%     RETURNS:      [errID errmsg]
%         errID:    0 if OK, else 1; see errmsg
%         errmsg:   '' if OK, else an informative error message
%
function [errID errmsg] = Verify_Settings()
errID = -1; errmsg = ''; %#ok<NASGU> (errID=-1 OK despite unused)
errorlocation = 'ERROR in Verify_Settings';

%     Newline character for convenience.
nl = sprintf('\n');

%     Be sure that we're running from the indicated code directory.
%     The warning below will trigger until hand-editing of the custom
%       settings file.
[Main_Code_Directory errID errmsg] = ...
    bSettings('get','GENERAL','Main_Code_Directory');
if errID, return; end;
if	isempty(Main_Code_Directory) || strcmpi(Main_Code_Directory,'NULL'),
    warning(['\nWARNING in Verify_Settings: Main_Code_Directory' ...
        ' setting was left blank.\n' ...
        'Though BControl may not break, it is best to set this value\n' ...
        'to avoid unusual behavior.\n'...
        'Old code will see Solo_rootdir = %s'],pwd);
elseif ispc &&  ~strcmpi(Main_Code_Directory, pwd) ...
      || isunix && ~strcmp(Main_Code_Directory, pwd),
    warning(['\n\nWARNING in Verify_Settings: Main_Code_Directory specified\n'...
        'in settings files is not the current directory.\n' ...
        'Please set Main_Code_Directory in the custom settings file\n'...
        'file to match the directory you will run BControl from.\n'...
        'Strange behavior in old code MAY result.\n'...
        '(This warning may also occur due to OS case insensitivity\n'...
        'or softlinks.)\n' ...
        'This run:\nMain_Code_Directory:  %s\nCurrent Directory:  %s\n\n'],...
        Main_Code_Directory, pwd);
end


%     See if the main data directory is specified.
[Main_Data_Directory errID errmsg] = ...
    bSettings('get','GENERAL','Main_Data_Directory');
if errID, return; end;
if isempty(Main_Data_Directory) || strcmpi(Main_Data_Directory, 'NULL'),
    warning(['\n\nWARNING in Verify_Settings: Main_Data_Directory not \n'...
        'specified in the custom settings file\n'...
        '(Settings/Settings_Custom.conf)\n' ...
        'This value is heavily used and the behavior of code that\n'...
        'uses it is not well defined when it is empty or "NULL".\n'...
        'Old code will see Solo_datadir = %s\n\n'], ...
        [pwd filesep '..' filesep 'SoloData']);
end;


%     Create data directory at specified location if necessary.
if ~isempty(Main_Data_Directory) && ~strcmp(Main_Data_Directory,'NULL'),
    if ~exist(Main_Data_Directory, 'dir'),
        [success message] = mkdir(Main_Data_Directory);
        if ~success,
            errID = 1000;
            errmsg = [errorlocation ': Directory specified in' ...
                ' Main_Data_Directory setting did not exist in' ...
                ' filesystem and an attempt to create it failed.' ...
                ' Check permissions?' ...
                nl 'Directory: "' Main_Data_Directory '".' ...
                nl 'mkdir error message: ' nl '"' message '"'];
            return;
        end;    %  end if unsuccessful mkdir
    end;        %  end if data dir does not already exist
end;            %  end if Main_Data_Directory variable is not meaningless


%     Check for meaningful fake_rp_box (0-4 or 20).
[fake_rp_box errID errmsg] = ...
    bSettings('get','RIGS','fake_rp_box');
if errID, return; end;
if ~ismember(fake_rp_box, [0 1 2 3 4 20]), % <~> added 20 2008.July.04
    warn = [nl nl 'WARNING in Verify_Settings:' nl 'The setting' ...
        ' RIGS;fake_rp_box is not an integer in the set [0 1 2 3 4].' nl...
        'It is expected to be. See documentation in settings files.' nl];
    warning(warn); %#ok<WNTAG> (Ignore the meaningless MATLAB warning that marks this line.)
end;

%     Check selected addresses of state and sound machine servers.
[steMS errID errmsg] = ...
    bSettings('get','RIGS','state_machine_server');
if errID, return; end;
[sndMS errID errmsg] = ...
    bSettings('get','RIGS','sound_machine_server');
if errID, return; end;
% <~> 2008.July.4: added 20 in the fake_rp_box check below
if ~ischar(steMS) || ~ischar(sndMS) ...
        || (ismember(fake_rp_box,[0 1 2 20]) && (isempty(steMS) || isempty(sndMS))),
    warn = [nl nl 'WARNING in Verify_Settings:' nl ...
        'The settings RIGS;state_machine_server and' nl...
        'RIGS;sound_machine_server specify the address(es) of the' nl...
        'controlling (e.g. RTLSM) machine that sound and state' nl...
        'matrix information should be sent to. If a software' nl...
        'virtual behavior box is in use, they may be blank;' nl...
        'otherwise, they should be IP or DNS addresses - e.g.' nl...
        'rtlsm43.princeton.edu and 192.1.1.1 are fine.' nl nl];
    warning(warn); %#ok<WNTAG> (Ignore the meaningless MATLAB warning that marks this line.)
    return;
end;


%     If we've reached this point, everything should be okay.
errID = 0;
return;

end  %     end helper function Verify_Settings







%     -------------------------------------------------------------
%     -------------------------------------------------------------
%     -------  Compatibility_Globals (helper function for newstartup)
%     -------------------------------------------------------------
%     -------------------------------------------------------------
%     loads old settings into globals; BControl system;
%
%     This was only intended to be run by newstartup.
%
%     Because old code depends on certain settings being defined as
%       globals, after loading settings via the new settings system, we
%       load certain settings into globals.
%
%
%     Notes on each setting can be found in the default settings file.
%
%     ARGUMENTS:    NONE
%
%     RETURNS:      [errID errmsg]
%         errID:    0 if OK, else see errmsg
%         errmsg:   '' if OK, else an informative error message
%
function [errID errmsg] = Compatibility_Globals()
errID = -1; errmsg = ''; %#ok<NASGU> (errID=-1 OK despite unused)
errorlocation = 'ERROR in Compatibility_Globals (newstartup helper function)';

global fake_rp_box;
[fake_rp_box errID errmsg] = bSettings('get','RIGS','fake_rp_box');
if errID, return; end;

global state_machine_server;
[state_machine_server errID errmsg] = ...
    bSettings('get','RIGS','state_machine_server'); if errID, return; end;

global sound_machine_server;
[sound_machine_server errID errmsg] = ...
    bSettings('get','RIGS','sound_machine_server'); if errID, return; end;

global cvsroot_string;
[cvsroot_string errID errmsg] = bSettings('get','CVS','CVSROOT_STRING');
if errID, return; end;


%     Grab the DIO line names and values from Settings and create globals
%       from them.

[outputs errID_i errmsg_i] = bSettings('get','DIOLINES','all');
if errID_i,
    errID = 1;
    errmsg = [errorlocation ': Attempt to retrieve DIOLINES settings group failed. bSettings(''get'',''DIOLINES'',''all'') returned the following error (ID: ' int2str(errID_i) '): ' errmsg_i ];
    return;
end;
%     The Settings call above returns a cell matrix of the form:
%       {nameofoutput1  channelvalueofoutput1    DIOLINES;
%        nameofoutput2  channelvalueofoutput2    DIOLINES;
%        etc...}

%     Iterate over the DIOLINES settings and create globals with names
%       equal to the setting names, and values equal to the setting values.
%       This results in each channel name declared as a global, and the
%       channel's value in the outputs bitfield assigned to the global.
for i = 1:size(outputs,1),
    chan_name =     outputs{i,1};
    chan_val  =     outputs{i,2};
    eval(['global ' chan_name ';']);        % e.g.      global center1led;
    eval([chan_name ' = ' num2str(chan_val) ';']);   % e.g.      center1led = 3;
end;

global softsound_play_sounds;
softsound_play_sounds = bSettings('get','EMULATOR','softsound_play_sounds');

global pump_ontime;
[pump_ontime errID errmsg]      = bSettings('get','PUMPS','pump_ontime');
if errID, return; end;

global pump_offtime;
[pump_offtime errID errmsg]     = bSettings('get','PUMPS','pump_offtime');
if errID, return; end;

global sound_sample_rate;
[sound_sample_rate errID errmsg] = bSettings('get','SOUND','sound_sample_rate');
if errID, return; end;

global Solo_Try_Catch_Flag;
[Solo_Try_Catch_Flag errID] = bSettings('get','GENERAL','Solo_Try_Catch_Flag');
if errID || ~isnumeric(Solo_Try_Catch_Flag) || ...
        (Solo_Try_Catch_Flag ~= 0 && Solo_Try_Catch_Flag ~= 1),
    Solo_Try_Catch_Flag = 1;
end;


global Solo_rootdir;
Solo_rootdir = pwd;     %     NOTE THIS LINE!


global Solo_datadir;
[Solo_datadir errID errmsg] = bSettings('get','GENERAL','Main_Data_Directory');
if errID, return; end;
if isempty(Solo_datadir) || strcmpi(Solo_datadir, 'NULL'),
    %     If the setting is blank, old code still gets what it expects.
    Solo_datadir = [Solo_rootdir filesep '..' filesep 'SoloData']; %     NOTE THIS LINE!
end;


%     I don't know what to do with this yet, so I'm leaving it entirely as
%       is. Shraddha's protocols will need this, I expect, and cell arrays
%       are not recognized as such in the settings system (only as
%       strings), so we have to do some negotiating.
% Names of protocols built using protocolobj
global Super_Protocols;
Super_Protocols = {'duration_discobj','dual_discobj'};



%     If we've reached this point, everything should be okay.
errID = 0;
return;



end %     end helper function Compatibility_Globals
