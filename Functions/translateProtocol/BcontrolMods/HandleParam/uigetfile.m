function [filename, pathname, filterindex] = uigetfile(varargin)

%UIGETFILE Standard open file dialog box.
%   [FILENAME, PATHNAME, FILTERINDEX] = UIGETFILE(FILTERSPEC, TITLE)
%   displays a dialog box for the user to fill in, and returns the filename
%   and path strings and the index of the selected filter. A successful
%   return occurs only if the file exists.  If the user  selects a file
%   that does not exist, an error message is displayed,  and control
%   returns to the dialog box. The user may then enter  another filename,
%   or press the Cancel button.
%
%   The FILTERSPEC parameter determines the initial display of files in
%   the dialog box.  For example '*.m' lists all the MATLAB M-files.  If
%   FILTERSPEC is a cell array, the first column is used as the list of
%   extensions, and the second column is used as the list of descriptions.
%
%   When FILTERSPEC is a string or a cell array, "All files" is  appended
%   to the list.
%
%   When FILTERSPEC is empty the default list of file types is used.
%
%   Parameter TITLE is a string containing the title of the dialog box.
%
%   The output variable FILENAME is a string containing the name of the
%   file selected in the dialog box.  If the user presses Cancel, it is set
%   to 0.
%
%   The output variable PATHNAME is a string containing the path of the
%   file selected in the dialog box.  If the user presses Cancel, it is set
%   to 0.
%
%   The output variable FILTERINDEX returns the index of the filter
%   selected in the dialog box. The indexing starts at 1. If the user
%   presses Cancel, it is set to 0.
%
%   [FILENAME, PATHNAME, FILTERINDEX] = UIGETTFILE(FILTERSPEC, TITLE, FILE)
%   FILE is a string containing the name to use as the default selection.
%
%   [FILENAME, PATHNAME] = UIGETFILE(..., 'Location', [X Y]) places the
%   dialog box at screen position [X,Y] in pixel units. This option is
%   supported on UNIX platforms only.
%
%   [FILENAME, PATHNAME] = UIGETFILE(..., 'MultiSelect', SELECTMODE)
%   specifies if multiple file selection is enabled for the UIGETFILE
%   dialog. Valid values for SELECTMODE are 'on' and 'off'. If the value of
%   'MultiSelect' is set to 'on', the dialog box supports multiple file
%   selection. 'MultiSelect' is set to 'off' by default.
%
%   The output variable FILENAME is a cell array of strings if multiple
%   filenames are selected. Otherwise, it is a string representing
%   the selected filename.
%
%   [FILENAME, PATHNAME] = UIGETFILE(..., X, Y) places the dialog box at
%   screen position [X,Y] in pixel units. This option is supported on UNIX
%   platforms only.  THIS SYNTAX IS OBSOLETE AND WILL BE REMOVED. PLEASE
%   USE THE FOLLOWING SYNTAX INSTEAD:
%       [FILENAME, PATHNAME] = UIGETFILE(..., 'Location', [X Y])
%
%
%   Examples:
%
%   [filename, pathname, filterindex] = uigetfile('*.m', 'Pick an M-file');
%
%   [filename, pathname, filterindex] = uigetfile( ...
%      {'*.m;*.fig;*.mat;*.mdl', 'All MATLAB Files (*.m, *.fig, *.mat, *.mdl)';
%       '*.m',  'M-files (*.m)'; ...
%       '*.fig','Figures (*.fig)'; ...
%       '*.mat','MAT-files (*.mat)'; ...
%       '*.mdl','Models (*.mdl)'; ...
%       '*.*',  'All Files (*.*)'}, ...
%       'Pick a file');
%
%   [filename, pathname, filterindex] = uigetfile( ...
%      {'*.mat','MAT-files (*.mat)'; ...
%       '*.mdl','Models (*.mdl)'; ...
%       '*.*',  'All Files (*.*)'}, ...
%       'Pick a file', 'Untitled.mat');
%
%   Note, multiple extensions with no descriptions must be separated by semi-
%   colons.
%
%   [filename, pathname] = uigetfile( ...
%      {'*.m';'*.mdl';'*.mat';'*.*'}, ...
%       'Pick a file');
%
%   Associating multiple extensions with one description:
%
%   [filename, pathname] = uigetfile( ...
%      {'*.m;*.fig;*.mat;*.mdl', 'All MATLAB Files (*.m, *.fig, *.mat, *.mdl)'; ...
%       '*.*',                   'All Files (*.*)'}, ...
%       'Pick a file');
%
%   Enabling multiple file selection in the dialog:
%
%   [filename, pathname, filterindex] = uigetfile( ...
%      {'*.mat','MAT-files (*.mat)'; ...
%       '*.mdl','Models (*.mdl)'; ...
%       '*.*',  'All Files (*.*)'}, ...
%       'Pick a file', ...
%       'MultiSelect', 'on');
%
%   This code checks if the user pressed cancel on the dialog.
%
%   [filename, pathname] = uigetfile('*.m', 'Pick an M-file');
%   if isequal(filename,0) || isequal(pathname,0)
%      disp('User pressed cancel')
%   else
%      disp(['User selected ', fullfile(pathname, filename)])
%   end
%
%
%   See also UIPUTFILE, UIGETDIR.

%   Copyright 1984-2004 The MathWorks, Inc.
%   $Revision: 1.3 $  $Date: 2005/09/26 04:17:10 $
%   Built-in function.


%%%%%%%%%%%%%%%%
% Error messages
%%%%%%%%%%%%%%%%

badLocMessage     = 'The Location parameter value must be a 2 element vector.' ;
badMultiMessage   = 'The MultiSelect parameter value must be a string specifying on/off.' ;
badFirstMessage   = 'Ill formed first arguement to uigetfile' ;
badArgsMessage    = 'Unrecognized input arguments.' ;
bad2ndArgMessage  = 'Expecting a string as 2nd arg' ;
bad3rdArgMessage  = 'Expecting a string as 3rd arg' ;
badFilterMessage  = 'FILTERSPEC argument must be a string or an M by 1 or M by 2 cell array.' ;
badNumArgsMessage = 'Too many input arguments.' ;

badLastArgsMessage    = 'MultiSelect and Location args must be the last args' ;
badMultiPosMessage    = '''MultiSelect'' , ''on/off'' can only be followed by Location args' ;
badLocationPosMessage = '''Location'' , [ x y ] can only be followed by MultiSelect args' ;

caErr1Message = 'Illegal filespec';
caErr2Message = 'Illegal filespec - can have at most two cols';
caErr3Message = 'Illegal file extension - ''' ;

maxArgs = 7 ;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% check the number of args - must be <= maxArgs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

numArgs = nargin ;

if( numArgs > maxArgs )
    error( badNumArgsMessage )
end


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Restrict new version to the mac
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% If we are on the mac, default to using non-native
% dialog. If the root property UseNativeSystemDialogs
% is false, use the non-native version instead.

useNative = true;

% If we are on the Mac & swing is available, set useNative to false,
% i.e., we are going to use Java dialogs not native dialogs.

% Comment the following line to disable java dialogs on Mac.
% useNative = ~( isequal( 'MAC' , computer ) && isempty( javachk('swing') ) ) ;
% Line above commented out by CDB 4-Sep-05

% If the root appdata is set and swing is available,
% honor that overriding all other prefs.

if isequal(0, getappdata(0,'UseNativeSystemDialogs')) && isempty( javachk('swing') )
    useNative = false ;
end

%JPL 
%note this will break if matlab natively overloads a builtin...
if useNative

    %find native function
    t=which('uigetfile','-all');
    idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,matlabroot)),t,'UniformOutput',false)));
    
    try
        if nargin == 0
            [filename, pathname, filterindex] = run(t{idx});
        else
            [pth,fle,~]=fileparts(t{idx});
            pd=pwd;
            cd(pth);
            [filename, pathname, filterindex]= uigetfile(varargin{1},varargin{2});
            cd(pd);

        end
    catch
        rethrow(lasterror)
    end

    return

end % end useNative


%%%%%%%%%%%%%%%%%
% General globals
%%%%%%%%%%%%%%%%%

multiPosition    = '' ;
locationPosition = '' ;

fileSeparator = filesep ;
pathSeparator = pathsep ;
remainderArgs = '' ;
newFilter = '' ;

locationPosition    = '' ; % position of 'Location' arg
multiSelectPosition = '' ; % position of 'MultiSelect' arg

theError = '' ;

userTitle = '' ;

extError = 'mExtError' ; % returned from dFilter if there is an error

selectionFilter = '' ; % File Filter used by the user in the dialog

%%%%%%%
% Flags
%%%%%%%

filespecError     = false ;
cellArrayOk       = false ;
locationError     = false ;
multiSelectOn     = false ;
multiSelectError  = false ;
argUsedAsFileName = false ;
multiSelectFound  = false ;
locationFound     = false ;

%%%%%%%%%%%%%%%%%%%%%
% Filter descriptions
%%%%%%%%%%%%%%%%%%%%%

allMDesc = 'All MATLAB Files' ;
mDesc    = 'M-files (*.m)' ;
figDesc  = 'Figures (*.fig)' ;
matDesc  = 'MAT-files (*.mat)' ;
simDesc  = 'Simulink Models (*.mdl)' ;
staDesc  = 'Stateflow Files (*.cdr)' ;
wksDesc  = 'Real-Time Workshop files (*.rtw,*.tmf,*.tlc,*.c,*.h)' ;
rptDesc  = 'Report Generator Files (*.rpt)' ;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Extention "specs" for our default filters
% These strings are used by filters to match file extensions
% NOTE that they do NOT contian a '.' character
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mSpec   = 'm' ;
figSpec = 'fig' ;
matSpec = 'mat' ;
simSpec = 'mdl' ;
staSpec = 'cdr' ;
rtwSpec = 'rtw' ;
tmfSpec = 'tmf' ;
tlcSpec = 'tlc' ;
rptSpec = 'rpt' ;
cSpec   = 'c' ;
hSpec   = 'h' ;

%%%%%%%%%%%%%%%%%
% Default filters
%%%%%%%%%%%%%%%%%

% A filter for all Matlab files

allMatlabFilter = '' ;

% A filter for .m files

mFilter = '' ;

% A filter for .fig files

figFilter = '' ;

% A filter for .mat files

matFilter = '' ;

% A filter for Simulink files - .mdl
simFilter = '' ;

% A filter for Stateflow files - .cdr

staFilter = '' ;

% A filter for Real Time Workshop files - .rtw, .tmf, .tlc, .c, .h

wksFilter = '' ;

% A filter for Report Generator files - .rpt

rptFilter = '' ;

% A filter for all files - *.*

allFilter = '' ;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% The dialog that holds our file chooser
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Title is set later

d = mydialog( ...
    'Visible','off', ...
    'DockControls','off', ...
    'Color',get(0,'defaultUicontrolBackgroundColor'), ...
    'Windowstyle','modal', ...
    'Resize','on' ...
    );

% Create a JPanel and put it into the dialog - this is for resizing

[panel, container] = javacomponent( handle(com.mathworks.mwswing.MJPanel(java.awt.BorderLayout())),[10 10 20 20],d);

% Create a JFileChooser

sys = char( computer ) ;

jfc = com.mathworks.hg.util.dFileChooser();

awtinvoke( jfc , 'init(ZLjava/lang/String;)' , false , java.lang.String(sys) ) ;
%jfc.init( false , sys ) ;

% We're going to use our own "all" file filter

awtinvoke( jfc , 'setAcceptAllFileFilterUsed(Z)' , false ) ;
%jfc.setAcceptAllFileFilterUsed( false ) ;

% Set the chooser's current directory

awtinvoke( jfc , 'setCurrentDirectory(Ljava/io/File;)' , java.io.File(pwd) ) ;
%jfc.setCurrentDirectory( java.io.File(pwd) ) ;

% Make sure multi select is initially disabled

awtinvoke( jfc , 'setMultiSelectionEnabled(Z)' , false ) ;
%jfc.setMultiSelectionEnabled( false ) ;

panel.add(jfc);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Eliminate "built-in" args such as 'multiselect', 'location' and
% their values.  As a side effect, create the array remainderArgs.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

eliminateBuiltIns() ;

% Exit if there was an error with MultiSelect or Location

numArgs = nargin ;

if( multiSelectError |  locationError )
    error( theError ) ;
end

% Check to see that there are no extra args.
% 'MultiSelect', 'location' and their values
% must be the last args.

if( multiSelectFound  & ~locationFound )

    if( ~( multiSelectPosition == ( numArgs - 1 ) ) )
        error( badMultiPosMessage ) ;
    end % end  if( ~( multiSelectPosition ...

end % end if( multiSelectFound )

if( locationFound  & ~multiSelectFound )

    if( ~( locationPosition == ( numArgs - 1 ) ) )
        error( badLocationPosMessage ) ;
    end % end  if( ~( locationPosition ...

end % end if( locationFound )

if( multiSelectFound & locationFound )

    if( ( ~( ( numArgs - 1 ) == multiSelectPosition ) & ~( ( numArgs - 3 ) == multiSelectPosition ) ) | ...
            ( ~( ( numArgs - 1 ) == locationPosition ) & ~( ( numArgs - 3 ) == locationPosition ) ) )
        error( badLastArgsMessage ) ;
    end
end % end if( multiSelectFound & locationFound )

% Set the chooser to multi select if required

% if( multiSelectFound )
%     warning('MATLAB:UIGETFILE:MultiSelectIg','MultiSelect is being ignored temporally.');
% end

if( locationFound )
    warning('MATLAB:UIGETFILE:LocationIgnore','Location is being ignored.');
end

if( multiSelectOn )
    awtinvoke( jfc , 'setMultiSelectionEnabled(Z)' , true ) ;
    %    jfc.setMultiSelectionEnabled( true ) ;
end

% Reset the content of varargin & numArgs

varargin = remainderArgs ;

numArgs = numel( remainderArgs ) ;

% At this point we can have at most 3 remaining args

if( numArgs > 3 )
    error( badArgsMessage )
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Handle the case of no args.  In this case
% we load and use the default filters.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if( 0 == numArgs )

    buildDefaultFilters() ;

    % Load our filters into the JFileChooser

    loadDefaultFilters( jfc , 1 ) ;

    % Set our "allMatlabFilter" to be the active filter

    awtinvoke( jfc , 'setFileFilter(Ljavax/swing/filechooser/FileFilter;)' , allMatlabFilter ) ;
    %jfc.setFileFilter( allMatlabFilter ) ;

end % end if( 0 == numArgs )


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Handle the case of exactly one remaining arg.
% The argument must be a string or a cell array.
%
% If it's a cell array we try to use it as a filespec.
%
% If it's a string, there are 2 options:
%
% If it's a legit description of a file ext, we use it
% to create a filter and a description.  We then add
% that filter and the "all" filter to the file chooser.
% Example - '*.txt' or '.txt'
%
% FOR COMPATABILITY,
% if it's not an ext we understand, we use it as a
% "selected file name."  We then set up the file chooser
% to use our default filters including the "all" filter.
% Example - 'x'
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if( 1 == numArgs )

    spec = varargin{ 1 } ;

    if ~( ischar( spec ) ) & ~( iscellstr( spec ) )
        error( badFilterMessage )
    end

    % OK - the type is correct

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Handle the case where the arg is a string
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if isempty(spec) || ( ischar( spec ) & isvector( spec ) )

        if( ~( 1 == size( spec , 1 ) ) )
            spec = spec' ;
        end

        handleStringFilespec( jfc , spec , 1 ) ;

        if( filespecError )
            error( theError ) ;
        end

    end % end if( ischar( spec ) ) ...

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Handle the case where the arg is a cell array
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if( iscellstr( spec ) )

        cellArrayOk = false ;

        handleCellArrayFilespec( spec , jfc ) ;

        if ~cellArrayOk
            error( theError ) ;
        end

    end % if( iscellstr( spec ) )

end % end if( 1 == numArgs )


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Handle the case of two remaining args.
%
% If arg 1 is a good filespec, use it
% and interpret the 2nd arg as a title.
%
% FOR COMPATABILITY,
% if arg1 is a string but not a legit
% filespec, we use it as a file name
% and interpret the 2nd arg as a title.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if( 2 == numArgs )

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Error check the types of the args.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % The 2nd arg must be a string
    arg2 = varargin{ 2 } ;

    if ~isempty(arg2) && ~( ischar( arg2 ) & isvector( arg2 ) )
        % Not a string
        error( bad2ndArgMessage )
    end

    % Transpose if necessary

    if( ~( 1 == size( arg2 , 1 ) ) )
        arg2 = arg2' ;
    end

    % Use arg2 as title
    userTitle = char(arg2);
    
    % Check out the first arg
    spec = varargin{ 1 } ;

    if ~( ischar( spec ) ) & ~( iscellstr( spec ) )
        error( badFilterMessage )
    end

    % OK - the types are correct

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Handle the case where the 1st arg is a string
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if isempty(spec) || ( ischar( spec ) & isvector( spec ) )

        if( ~( 1 == size( spec , 1 ) ) )
            spec = spec' ;
        end
        
        handleStringFilespec( jfc, spec, '1' );

        if( filespecError )
            error( theError ) ;
        end

    else
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Handle the case where first arg is a cell array
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        handleCellArrayFilespec( spec , jfc ) ;
        
        if( ~cellArrayOk )
            error( theError ) ;
        end

    end %if( ischar( spec ) & isvector( spec ) )

end % if( 2 == numArgs )


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Handle the case of three remaining arguements.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if( 3 == numArgs )

    % The 2nd and 3rd args must be strings

    arg2 = varargin{ 2 } ;

    if ~isempty(arg2) && ~( ischar( arg2 ) & isvector( arg2 ) )
        % Not a string
        error( bad2ndArgMessage )
    end

    if( ~( 1 == size( arg2 , 1 ) ) )
        arg2 = arg2' ;
    end

    % Use arg2 as title
    userTitle = char(arg2);
    
    arg3 = varargin{ 3 } ;

    if ~isempty(arg3) && ~( ischar( arg3 ) & isvector( arg3 ) )
        % Not a string
        error( bad3rdArgMessage )
    end

    if( ~( 1 == size( arg3 , 1 ) ) )
        arg3 = arg3' ;
    end

    % Use arg3 as file after handling arg1

    % Check out the first arg
    spec = varargin{ 1 } ;

    % The first arg must be a string or cell array

    if ~( ischar( spec ) ) & ~( iscellstr( spec ) )
        error( badFilterMessage )
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Handle the case where the 1st arg is a string
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if isempty(char) || ( ischar( spec ) & isvector( spec ) )

        if( ~( 1 == size( spec , 1 ) ) )
            spec = spec' ;
        end

        handleStringFilespec( jfc , spec , '1' ) ;
        
        if( filespecError )
            error( theError ) ;
        end
        
    else
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Handle case where 1st arg is a cell array
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        handleCellArrayFilespec( spec , jfc ) ;
        
        if( ~cellArrayOk )
            error( theError ) ;
        end
        
    end % if( ischar( spec ) & isvector( spec ) )

    % Use arg3 as file after handling arg1
    awtinvoke( jfc , 'setSelectedFile(Ljava/io/File;)' , java.io.File( arg3 ) ) ;

end % if( 3 == numargs )


% Set the title of the dialog

if( ~( strcmp( char(userTitle) , '' ) ) )
    set( d , 'Name' , userTitle )
else
    set( d , 'Name' , char( jfc.getDefaultGetfileTitle() ) )
end

set(container,'Units','normalized','position',[0 0 1 1]);

jfcHandle = handle(jfc , 'callbackproperties' );

% these will get  set by the callback
filename = 0 ;
pathname = 0 ;
filterindex = 0 ;

set(jfcHandle,'PropertyChangeCallback', {@callbackHandler, d , multiSelectOn , sys })

figure(d)
refresh(d)

awtinvoke( jfc , 'listen()' ) ;
%jfc.listen() ;

waitfor(d);

% Retrieve the data stored by the callback

if isappdata( 0 , 'uigetfileData' )
    uigetfileData = getappdata( 0 , 'uigetfileData' ) ;

    filename    = uigetfileData.filename ;
    pathname    = uigetfileData.pathname ;
    filterindex = uigetfileData.filterindex ;

    rmappdata( 0 , 'uigetfileData' ) ;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Build all the default filters.  Each filter handles
% one or more extension.  Each filter also has a
% description string which appears in the file selection
% dialog.  Each filter can also be assigned a string "id."
% Filters are Java objects.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function buildDefaultFilters()

        allMatlabFilter = com.mathworks.hg.util.dFilter ;
        allMatlabFilter.setDescription( allMDesc ) ;
        allMatlabFilter.addExtension( mSpec ) ;
        allMatlabFilter.addExtension( figSpec ) ;
        allMatlabFilter.addExtension( matSpec ) ;

        % Filter for files

        mFilter = com.mathworks.hg.util.dFilter ;
        mFilter.setDescription( mDesc ) ;
        mFilter.addExtension( mSpec ) ;

        % Filter for .fig files

        figFilter = com.mathworks.hg.util.dFilter ;
        figFilter.setDescription( figDesc ) ;
        figFilter.addExtension( figSpec ) ;

        % Filter for MAT-files

        matFilter = com.mathworks.hg.util.dFilter ;
        matFilter.setDescription( matDesc ) ;
        matFilter.addExtension( matSpec ) ;

        % Filter for Simulink Models

        simFilter = com.mathworks.hg.util.dFilter ;
        simFilter.setDescription( simDesc ) ;
        simFilter.addExtension( simSpec ) ;

        % Filter for Stateflow files

        staFilter = com.mathworks.hg.util.dFilter ;
        staFilter.setDescription( staDesc ) ;
        staFilter.addExtension( staSpec ) ;

        % Filter for Real-Time Workshop files

        wksFilter = com.mathworks.hg.util.dFilter ;
        wksFilter.setDescription( wksDesc ) ;
        wksFilter.addExtension( rtwSpec ) ;
        wksFilter.addExtension( tmfSpec ) ;
        wksFilter.addExtension( tlcSpec ) ;
        wksFilter.addExtension( cSpec ) ;
        wksFilter.addExtension( hSpec ) ;

        % Filter for Report Generator files

        rptFilter = com.mathworks.hg.util.dFilter ;
        rptFilter.setDescription( rptDesc ) ;
        rptFilter.addExtension( rptSpec ) ;

        % Filter for "All Files"

        allFilter = com.mathworks.hg.util.AllFileFilter ;

    end % end buildDefaultFilters


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Load all the default filters into the jFileChooser.
    % Give each filter an id starting at "startId."  We'll
    % later use the id to determine which filter was active
    % when the user made the selection.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function loadDefaultFilters( chooser , startId )
        j = startId ;

        allMatlabFilter.setIdentifier( int2str( j ) ) ;
        awtinvoke( chooser , 'addFileFilter(Ljavax/swing/filechooser/FileFilter;)' , allMatlabFilter ) ;
        awtinvoke( chooser , 'noteFilter(Ljavax/swing/filechooser/FileFilter;)' , allMatlabFilter ) ;
        %         chooser.addFileFilter( allMatlabFilter ) ;
        %         chooser.noteFilter( allMatlabFilter ) ;

        j = j + 1 ;

        mFilter.setIdentifier( int2str( j ) ) ;
        awtinvoke( chooser , 'addFileFilter(Ljavax/swing/filechooser/FileFilter;)' , mFilter ) ;
        awtinvoke( chooser , 'noteFilter(Ljavax/swing/filechooser/FileFilter;)' , mFilter ) ;
        %       chooser.addFileFilter( mFilter ) ;
        %      chooser.noteFilter( mFilter ) ;
        j = j + 1 ;

        figFilter.setIdentifier( int2str( j ) ) ;
        awtinvoke( chooser , 'addFileFilter(Ljavax/swing/filechooser/FileFilter;)' , figFilter ) ;
        awtinvoke( chooser , 'noteFilter(Ljavax/swing/filechooser/FileFilter;)' , figFilter ) ;
        %         chooser.addFileFilter( figFilter ) ;
        %         chooser.noteFilter( figFilter ) ;
        j = j + 1 ;

        matFilter.setIdentifier( int2str( j ) ) ;
        awtinvoke( chooser , 'addFileFilter(Ljavax/swing/filechooser/FileFilter;)' , matFilter ) ;
        awtinvoke( chooser , 'noteFilter(Ljavax/swing/filechooser/FileFilter;)' , matFilter ) ;
        %         chooser.addFileFilter( matFilter ) ;
        %         chooser.noteFilter( matFilter ) ;
        j = j + 1 ;

        simFilter.setIdentifier( int2str( j ) ) ;
        awtinvoke( chooser , 'addFileFilter(Ljavax/swing/filechooser/FileFilter;)' , simFilter ) ;
        awtinvoke( chooser , 'noteFilter(Ljavax/swing/filechooser/FileFilter;)' , simFilter ) ;
        %         chooser.addFileFilter( simFilter ) ;
        %         chooser.noteFilter( simFilter ) ;
        j = j + 1 ;

        staFilter.setIdentifier( int2str( j ) ) ;
        awtinvoke( chooser , 'addFileFilter(Ljavax/swing/filechooser/FileFilter;)' , staFilter ) ;
        awtinvoke( chooser , 'noteFilter(Ljavax/swing/filechooser/FileFilter;)' , staFilter ) ;
        %         chooser.addFileFilter( staFilter ) ;
        %         chooser.noteFilter( staFilter ) ;
        j = j + 1 ;

        wksFilter.setIdentifier( int2str( j ) ) ;
        awtinvoke( chooser , 'addFileFilter(Ljavax/swing/filechooser/FileFilter;)' , wksFilter ) ;
        awtinvoke( chooser , 'noteFilter(Ljavax/swing/filechooser/FileFilter;)' , wksFilter ) ;
        %         chooser.addFileFilter( wksFilter ) ;
        %         chooser.noteFilter( wksFilter ) ;
        j = j + 1 ;

        rptFilter.setIdentifier( int2str( j ) ) ;
        awtinvoke( chooser , 'addFileFilter(Ljavax/swing/filechooser/FileFilter;)' , rptFilter ) ;
        awtinvoke( chooser , 'noteFilter(Ljavax/swing/filechooser/FileFilter;)' , rptFilter ) ;
        %         chooser.addFileFilter( rptFilter ) ;
        %         chooser.noteFilter( rptFilter ) ;
        j = j + 1 ;

        allFilter.setIdentifier( int2str( j ) ) ;
        awtinvoke( chooser , 'addFileFilter(Ljavax/swing/filechooser/FileFilter;)' , allFilter ) ;
        awtinvoke( chooser , 'noteFilter(Ljavax/swing/filechooser/FileFilter;)' , allFilter ) ;
        %         chooser.addFileFilter( allFilter )
        %         chooser.noteFilter( allFilter ) ;


        % We shouldn't need the pause or the following drawnow -
        % But it doesn't work without them

        pause(.5) ;
        awtinvoke( chooser, 'setFileFilter(Ljavax/swing/filechooser/FileFilter;)' , allMatlabFilter ) ;
        drawnow() ;

    end % end loadDefaultFilters

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Build a new filter containing an extension and a description
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function buildFilter(  desc , ext )
        newFilter = com.mathworks.hg.util.dFilter ;
        newFilter.setDescription( desc ) ;
        newFilter.addExtension( ext ) ;
    end % buildFilter

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Add a filter to the indicated JFileChooser
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function addFilterToChooser( chooser , filter )
        awtinvoke( chooser , 'addFileFilter(Ljavax/swing/filechooser/FileFilter;)' , filter ) ;
        awtinvoke( chooser , 'noteFilter(Ljavax/swing/filechooser/FileFilter;)' , filter ) ;
        %         chooser.addFileFilter( filter ) ;
        %         chooser.noteFilter( filter ) ;
    end % end addFilterToChooser

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Set the indicated filter's identifier (must be a string)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function setFilterIdentifier( filter , id )
        filter.setIdentifier( id ) ;
    end % setFilterIdentifier

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Build a filter that "accepts" all files
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function buildAllFilter()
        allFilter = com.mathworks.hg.util.AllFileFilter ;
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This handles the case where the filespec is a string
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function handleStringFilespec( chooser , str , id )
        argUsedAsFileName = false ;
        useDefaultFilter = false;

        if( isempty( str ) )
            % If the filter string is empty use defaults.
            useDefaultFilter = true;
        else
            filterspec = str ;

            extStr = '' ;
            extStr = char(com.mathworks.hg.util.dFilter.returnExtensionString( str )) ;

            if( strcmpi( extStr , extError ) )
                % This isn't a "legal" extension we know about.
                % Treat it as the name of a file or a path with fiter
                % for COMPATABILITY with the current release. So, it can be:
                % 'filename.m'
                % 'H:\filename.m' or '/home/user/filename.m'
                % 'H:\*.m' or '/home/user/*.m'

                % Do a fileparts to analyse the string. This returns us the
                % path, file and ext.
                [p n e] = fileparts(str);
                
                filename = '';
                if ~isempty(p)
                    filename = [p, filesep];
                end
                if isempty(strfind(n, '*'))
                    % There is no wildcard in the file name
                    filename = [filename, n, e];
                end
                % Set the file
                % test = java.io.File( str ) ;
                % if( test.isFile() )
                awtinvoke( chooser , 'setSelectedFile(Ljava/io/File;)' , java.io.File( filename ) ) ;
                
                if isempty(e)
                    % If no file extension was specified to be used as a 
                    % filter, use defaults
                    useDefaultFilter = true;
                else
                    % extStr is the extension w/o the '.'
                    extStr = e(2:end);
                    % filterspec is *.<ext>
                    filterspec = ['*', e];
                end
                
            end
        end
            
        if (useDefaultFilter)
            buildDefaultFilters() ;
            loadDefaultFilters( chooser , id ) ;
            awtinvoke( chooser , 'setFileFilter(Ljavax/swing/filechooser/FileFilter;)' , allMatlabFilter ) ;
            argUsedAsFileName = true ;
            %             else
            %                 theError = caErr1Message ;
            %                 filespecError = true ;
            %                 return ;
            %             end

        else
            % Build a new filter.
            % Load the new filter and the "all" filter
            buildFilter( filterspec, extStr ) ;
            setFilterIdentifier( newFilter , '1' ) ;
            addFilterToChooser( chooser , newFilter ) ;

            if ~( strcmp( char( spec ) , '*.*' ) )
                buildAllFilter() ;
                setFilterIdentifier( allFilter , '2' ) ;
                addFilterToChooser( chooser , allFilter ) ;
            end

            % We shouldn't need the pause or the following drawnow -
            % But it doesn't work without them

            pause(.5) ;
            awtinvoke( chooser, 'setFileFilter(Ljavax/swing/filechooser/FileFilter;)' , newFilter ) ;
            drawnow() ;
            %chooser.setFileFilter( newFilter ) ;

        end % end if/else

    end % end handleStringFilespec


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % This handles the case where the filespec is a cell array
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function handleCellArrayFilespec( theCellArray , chooser )

        cellArrayOk = false ;

        t = '' ;
        rows = '' ;
        cols = '' ;
        allFound = '' ;

        firstFilter = '' ;

        try
            t = size( theCellArray ) ;
            rows = t(1) ;
            cols = t(2) ;
        catch
            theError = caErr1Message ;
            return
        end

        if( 2 < cols )
            theError = caErr2Message ;
            return
        end


        % The first col is supposed to hold an extension array

        extArray = '' ;
        descrArray = '' ;
        ext = '' ;

        for i = 1:rows

            ext = theCellArray{ i , 1 } ;

            % Format the extension for our filter

            s = com.mathworks.hg.util.dFilter.returnExtensionString( char(ext) ) ;

            s = char( s ) ;

            if~( strcmpi( s , extError ) )
                extArray{i} = s ;
            else
                theError = strcat( caErr3Message , ext , '''' )  ;
                cellArrayOk = false ;
                return
            end

        end % end for

        % If there are two cols, the 2nd col is
        % supposed to be descriptions for 1st col

        if( 2 == cols )

            for i = 1 : rows

                descrArray{ i } = theCellArray{ i , 2 }  ;

            end % end for i = 1 : rows

        end % end if( 2 == cols )

        % Create the filters for file selection

        ii = 0 ;

        for i = 1:rows

            %disp( extArray{i} )

            if( strcmp( char( extArray{i} ) , '*.*' ))
                buildAllFilter() ;
                allFilter.setIdentifier( int2str( i ) ) ;
                awtinvoke( chooser , 'addFileFilter(Ljavax/swing/filechooser/FileFilter;)' , allFilter ) ;
                awtinvoke( chooser , 'noteFilter(Ljavax/swing/filechooser/FileFilter;)' , allFilter ) ;
                allFound = true ;
            end

            if ~( strcmp( char( extArray{i} ) , '*.*' ) )

                usrFilter = com.mathworks.hg.util.dFilter ;
                usrFilter.addExtension( extArray{i} ) ;
                usrFilter.setIdentifier( int2str(i) ) ;

                if( 2 == cols )
                    usrFilter.setDescription( descrArray{i} ) ;
                else
                    usrFilter.setDescription( theCellArray{i,1} ) ;
                end % end if( 2 == cols )

                % Add the filter

                awtinvoke( chooser , 'addFileFilter(Ljavax/swing/filechooser/FileFilter;)' , usrFilter ) ;
                awtinvoke( chooser , 'noteFilter(Ljavax/swing/filechooser/FileFilter;)' , usrFilter ) ;

                % Set a current filter

                if( 1 == i )
                    firstFilter = usrFilter ;
                    %awtinvoke( chooser , 'setFileFilter(Ljavax/swing/filechooser/FileFilter;)' , usrFilter ) ;
                end % end if( 1 == i )

                ii = i ;

            end % end if ~( strcmp( char( extArray{i} ) , '*.*' ) )

        end % end for i = 1:rows

        % Add in the "all" filter

        if( ~allFound )
            buildAllFilter() ;
            allFilter.setIdentifier( int2str( ii+1 ) ) ;
            awtinvoke( chooser , 'addFileFilter(Ljavax/swing/filechooser/FileFilter;)' , allFilter ) ;
            awtinvoke( chooser , 'noteFilter(Ljavax/swing/filechooser/FileFilter;)' , allFilter ) ;
        end

        % Set the user's first filter as the active filter
        % Shouldn't need the pause and drawnow, but things
        % don't work without them.

        pause(.5) ;
        awtinvoke( chooser , 'setFileFilter(Ljavax/swing/filechooser/FileFilter;)' , firstFilter ) ;
        drawnow() ;

        cellArrayOk = true ;

    end % end handleCellArrayFilespec

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Scan the input arguements for 'MultiSelect' and 'Location'.
    % If either is present, check that the next arg has an
    % appropriate value.  If not, set an appropriate error flag.
    %
    % Also, store all the other arguments in the array "remainderArgs".
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function eliminateBuiltIns()

        args = varargin ;

        numberOfArgs = numel( args ) ;

        remainderArgIndex = 1 ;

        i = 1 ;

        while( i <= numberOfArgs )

            theArg = args{i} ;

            % Add to remainder args if its not a string

            if( ~( ischar( theArg ) ) | ~( isvector( theArg ) ) )
                remainderArgs{ remainderArgIndex } = theArg ;
                remainderArgIndex = remainderArgIndex + 1 ;
                i = i + 1 ;
                %end % end if( ~( ischar( theArg ) ) | ~( isvector( theArg ) ) )

                if( i > numberOfArgs )
                    return
                end

                continue
            end % end if( ~( ischar( theArg ) ) | ~( isvector( theArg ) ) )

            % Transpose if necessary

            if( ~( 1 == size( theArg , 1 ) ) )
                theArg = theArg' ;
            end

            % Check to see if we have an interesting string

            lowArg = lower( theArg ) ;

            if( ~strcmp( 'multiselect' , lowArg ) & ~strcmp( 'location' , lowArg ) )
                remainderArgs{ remainderArgIndex } = theArg ;
                remainderArgIndex = remainderArgIndex + 1 ;
                i = i + 1 ;
                continue ;

            end % end if( ~strcmp( 'multiselect' , lowArg ) ...

            % Check the next arg - we have found 'multiselect' or 'location'

            i = i + 1 ;

            if( i > numberOfArgs )
                % oops - missing arg
                switch( lowArg )
                    case 'multiselect'
                        theError = badMultiMessage ;
                        multiSelectError = true ;
                        return
                    case 'location'
                        theError = badLocMessage  ;
                        locationError = true ;
                        return
                end % end switch

                return
            end % end if( i  > numberOfArgs )


            nextArg = args{ i } ;

            switch( lowArg )

                case 'multiselect'

                    % nextArg must be 'on' or 'off'

                    if( ~( ischar( nextArg ) ) | ~( isvector( nextArg ) ) )
                        theError = badMultiMessage  ;
                        multiSelectError = true ;
                        return
                    end

                    if( ~( 1 == size( nextArg , 1 ) ) )
                        nextArg = nextArg' ;
                    end

                    if( ~( strcmp( 'on', lower( nextArg ) ) ) & ~( strcmp( 'off' , lower( nextArg )  ) ) )
                        theError = badMultiMessage  ;
                        multiSelectError = true ;
                        return
                    end

                    multiSelectFound    = true ;
                    multiSelectPosition = i - 1 ;

                    if( strcmp( 'on' , lower( nextArg ) ) )
                        multiSelectOn = true ;
                    end

                    i = i + 1 ;

                    if( i > numberOfArgs )
                        return
                    end

                case 'location'

                    % nextArg must be a numeric vector

                    if( ~( isvector( nextArg ) ) | ...
                            ~( isnumeric( nextArg ) ) )
                        theError = badLocMessage ;
                        locationError = true ;
                        return
                    end

                    % Transpose if necessary

                    if( ~( 1 == size( nextArg , 1 ) ) )
                        nextArg = nextArg' ;
                    end

                    % Check size

                    if( ~( 1 == size( nextArg , 1 ) ) | ...
                            ~( 2 == size( nextArg , 2 ) ) )
                        theError = badLocMessage  ;
                        locationError = true ;
                        return
                    end

                    % Record the fact that we've found 'location'

                    locationFound = true ;
                    locationPosition = i - 1 ;

                    % skip to the next arg

                    i = i + 1 ;

                    if( i > numberOfArgs )
                        return
                    end

            end % end switch

        end % end while

    end % eliminateBuiltIns

    function out = mydialog(varargin)

        out = [];

        oldjf = feature('javafigures');

        if ~oldjf
            feature('javafigures',1)
        end

        try
            out = dialog(varargin{:}) ;
        catch
            rethrow(lasterror)
        end
        feature('javafigures',oldjf)

    end % end myDialog

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Handle the callback from the JFileChooser.  If the user
% selected "Open", return the name of the selected file,
% the full pathname and the index of the current filter.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function callbackHandler(obj, evd, d , multiSelectOn , sys )

fileSeparator = filesep ;
pathSeparator = pathsep ;

jfc = obj;

cmd = char(evd.getPropertyName()) ;

switch(cmd)
    case 'mathworksHgCancel'
        if ishandle(d)
            close(d)
        end
    case 'mathworksHgOk'

        selectionFilter = jfc.getFileFilter() ;

        if( ~multiSelectOn )
            [pathname, fn, ext ] = fileparts(char(jfc.getSelectedFile.toString));

            filename = [fn ext];

            pathname = strcat( pathname , fileSeparator ) ;

        else % Multi Select is On

            fileObjArray = jfc.getSelectedFiles ;

            fileNames = jfc.getSelectedFileNames() ;

            rows = size( fileNames , 1 ) ;

            cols = size( fileNames , 2 ) ;

            x = '' ;%( 1 , rows ) ;

            j = 1 ;

            for i = 1 : rows

                %x{ 1 , i } = char( fileNames( i , 1 ) ) ;xxxxxx

                if( ~( strcmp( 'MAC' , sys ) ) )
                    x{ 1 , i } = char( fileNames( i , 1 ) ) ;
                else
                    name = char( fileNames( i , 1 ) ) ;
                    if( selectionFilter.accept( java.io.File( name ) ) )
                        x{ 1 , j } = name ;
                        j = j + 1 ;
                    end
                end

            end % end for i = 1 : rows

            filename = x ;

            fileObj = fileObjArray(1) ;

            [pathname, fn, ext ] = fileparts(char(fileObj.getAbsolutePath()));

            pathname = strcat( pathname , fileSeparator ) ;

        end % end if( ~multiSelectOn )

        uigetfileData.filename    = filename ;
        uigetfileData.pathname    = pathname ; 
        uigetfileData.filterindex = str2double( selectionFilter.getIdentifier() ) ;

        setappdata( 0 , 'uigetfileData' , uigetfileData ) ;
        
        close(d);

end % end switch
end % end callbackHandler

