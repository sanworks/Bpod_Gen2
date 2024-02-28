%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) Sanworks LLC, Rochester, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}
function LaunchManager

global BpodSystem% Import the global BpodSystem object

drawFig = 1;
if isfield(BpodSystem.GUIHandles, 'LaunchManagerFig') && ~verLessThan('MATLAB', '8.4')
    if isgraphics(BpodSystem.GUIHandles.LaunchManagerFig)
        clf(BpodSystem.GUIHandles.LaunchManagerFig);
        figure(BpodSystem.GUIHandles.LaunchManagerFig);
        drawFig = 0;
    end
end

% Build UI
if (drawFig)
    BpodSystem.GUIHandles.LaunchManagerFig = figure('Position',[80 50 750 600],'name','Launch Manager',...
                                                    'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
end
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
bg = imread('LaunchManagerBG2.bmp');
image(bg); axis off;
if ispc
    lmYpos = 150; selectorFontSize = 11; pathFontSize = 10;
elseif ismac
    lmYpos = 160; selectorFontSize = 14; pathFontSize = 14;
else
    lmYpos = 130; selectorFontSize = 11; pathFontSize = 10;
end
fontName = 'Courier New';

text(lmYpos, 45,'Protocol Launch Manager', 'FontName', fontName, 'FontSize', 20, 'Color', [0.8 0.8 0.8]);
line([10 590], [80 80], 'Color', [0.8 0.8 0.8], 'LineWidth', 1);
BpodSystem.GUIHandles.ProtocolSelector = uicontrol('Style', 'listbox','Position', [25 95 200 390],... 
                                         'String', 'Folder not found', 'Callback', @ProtocolSelectorNavigate, 'FontWeight', 'bold',... 
                                         'FontSize', selectorFontSize, 'BackgroundColor', [.8 .8 .8]);
BpodSystem.GUIHandles.SubjectSelector = uicontrol('Style', 'listbox','Position', [265 95 200 390],... 
                                         'String', 'Folder not found', 'Callback', @subject_selector_navigate, 'FontWeight', 'bold',... 
                                         'FontSize', selectorFontSize, 'BackgroundColor', [.8 .8 .8]);
BpodSystem.GUIHandles.SettingsSelector = uicontrol('Style', 'listbox','Position', [505 95 200 390],... 
                                         'String', 'Folder not found', 'FontWeight', 'bold', 'FontSize', selectorFontSize,... 
                                         'BackgroundColor', [.8 .8 .8]);
text(20, 120,'Protocol', 'FontName', fontName, 'FontSize', 16, 'Color', [0.8 0.8 0.8]);
text(212, 120,'Subject', 'FontName', fontName, 'FontSize', 16, 'Color', [0.8 0.8 0.8]);
text(405, 120,'Settings', 'FontName', fontName, 'FontSize', 16, 'Color', [0.8 0.8 0.8]);
BpodSystem.GUIHandles.LaunchButton = uicontrol('Position', [590 10 150 65], 'Style', 'pushbutton',... 
                                     'String', ['Launch ' char(187)], 'FontName', fontName, 'FontSize', 16,... 
                                     'Callback', @launch_protocol, 'TooltipString', 'Launch Protocol',... 
                                     'BackgroundColor', [.37 .37 .37], 'ForegroundColor', [.8 .8 .8]);
addGFX = imread('PlusButton.bmp');
BpodSystem.GUIHandles.AddProtocolButton = uicontrol('Style', 'pushbutton', 'CData', addGFX, 'Position', [228 459 25 25],... 
                                          'Callback', @create_protocol, 'TooltipString', 'Create Protocol', 'FontName', fontName,... 
                                          'FontSize', 18, 'BackgroundColor', [.5 .5 .5], 'ForegroundColor', [.95 .95 .95]);
delGFX = imread('MinusButton.bmp');
BpodSystem.GUIHandles.DelProtocolButton = uicontrol('Style', 'pushbutton', 'CData', delGFX, 'Position', [228 429 25 25],... 
                                          'Callback', @delete_protocol, 'TooltipString', 'Delete Protocol', 'FontName', fontName,... 
                                          'FontSize', 18, 'BackgroundColor', [.5 .5 .5], 'ForegroundColor', [.95 .95 .95]);
editGFX = imread('EditButton.bmp');
BpodSystem.GUIHandles.EditProtocolButton = uicontrol('Style', 'pushbutton', 'CData', editGFX, 'Position', [228 399 25 25],... 
                                           'Callback', @edit_protocol, 'TooltipString', 'Edit Protocol', 'FontName', fontName,... 
                                           'FontSize', 22, 'BackgroundColor', [.5 .5 .5], 'ForegroundColor', [.95 .95 .95]);
importGFX = imread('ImportButton.bmp');
BpodSystem.GUIHandles.AddSubjectButton = uicontrol('Style', 'pushbutton', 'CData', addGFX, 'Position', [468 459 25 25],... 
                                         'Callback', @add_subject, 'TooltipString', 'Add Test Subject', 'FontName', fontName,... 
                                         'FontSize', 18, 'BackgroundColor', [.5 .5 .5], 'ForegroundColor', [.95 .95 .95]);
BpodSystem.GUIHandles.DelSubjectButton = uicontrol('Style', 'pushbutton', 'CData', delGFX, 'Position', [468 429 25 25],... 
                                         'Callback', @delete_subject, 'TooltipString', 'Delete Test Subject', 'FontName', fontName,... 
                                         'FontSize', 18, 'BackgroundColor', [.5 .5 .5], 'ForegroundColor', [.95 .95 .95]);
BpodSystem.GUIHandles.AddSettingsButton = uicontrol('Style', 'pushbutton', 'CData', addGFX, 'Position', [708 459 25 25],... 
                                         'Callback', @add_settings, 'TooltipString', 'Create Session Settings', 'FontName', fontName,... 
                                         'FontSize', 18, 'BackgroundColor', [.5 .5 .5], 'ForegroundColor', [.95 .95 .95]);
delGFX = imread('MinusButton.bmp');
BpodSystem.GUIHandles.DelSettingsButton = uicontrol('Style', 'pushbutton', 'CData', delGFX, 'Position', [708 429 25 25],... 
                                          'Callback', @delete_settings, 'TooltipString', 'Delete Session Settings',... 
                                          'FontName', fontName, 'FontSize', 18, 'BackgroundColor', [.5 .5 .5],... 
                                          'ForegroundColor', [.95 .95 .95]);
editGFX = imread('EditButton.bmp');
BpodSystem.GUIHandles.EditSettingsButton = uicontrol('Style', 'pushbutton', 'CData', editGFX, 'Position', [708 399 25 25],... 
                                           'Callback', @edit_settings, 'TooltipString', 'Edit Session Settings',... 
                                           'FontName', fontName, 'FontSize', 22, 'BackgroundColor', [.5 .5 .5],... 
                                           'ForegroundColor', [.95 .95 .95]);
importGFX = imread('ImportButton.bmp');
BpodSystem.GUIHandles.ImportSettingsButton = uicontrol('Style', 'pushbutton', 'CData', importGFX, 'Position', [708 369 25 25],... 
                                            'Callback', @import_settings, 'TooltipString', 'Import Session Settings',... 
                                            'FontName', fontName, 'FontSize', 22, 'BackgroundColor', [.5 .5 .5],... 
                                            'ForegroundColor', [.95 .95 .95]);
if isempty(strfind(BpodSystem.HostOS, 'Linux')) && ~verLessThan('matlab', '8.0.0') && verLessThan('matlab', '9.5.0')
    jButton = java(findjobj(BpodSystem.GUIHandles.EditProtocolButton));
    jButton.setBorderPainted(false);
    jButton = java(findjobj(BpodSystem.GUIHandles.AddProtocolButton));
    jButton.setBorderPainted(false);
    jButton = java(findjobj(BpodSystem.GUIHandles.ImportSettingsButton));
    jButton.setBorderPainted(false);
    jButton = java(findjobj(BpodSystem.GUIHandles.AddSubjectButton));
    jButton.setBorderPainted(false);
    jButton = java(findjobj(BpodSystem.GUIHandles.DelProtocolButton));
    jButton.setBorderPainted(false);
    jButton = java(findjobj(BpodSystem.GUIHandles.DelSubjectButton));
    jButton.setBorderPainted(false);
    jButton = java(findjobj(BpodSystem.GUIHandles.AddSettingsButton));
    jButton.setBorderPainted(false);
    jButton = java(findjobj(BpodSystem.GUIHandles.DelSettingsButton));
    jButton.setBorderPainted(false);
    jButton = java(findjobj(BpodSystem.GUIHandles.EditSettingsButton));
    jButton.setBorderPainted(false);
end
BpodSystem.GUIHandles.DataFilePathDisplay = text(20, 685,'', 'FontName', 'Courier New', 'FontSize', pathFontSize,... 
                                            'Color', [0.9 0.9 0.9]);
BpodSystem.GUIHandles.DataFileLabel = text(20, 665,'Data Folder:', 'FontName', 'Arial', 'FontSize', pathFontSize,... 
                                      'Color', [1 1 1], 'Interpreter', 'None');
BpodSystem.GUIHandles.DataFileDisplay = text(20, 730,'', 'FontName', 'Courier New', 'FontSize', pathFontSize,... 
                                        'Color', [0.9 0.9 0.9], 'Interpreter', 'None');
BpodSystem.GUIHandles.DataFileLabel = text(20, 710,'Data File:', 'FontName', 'Arial', 'FontSize', pathFontSize,... 
                                      'Color', [1 1 1], 'Interpreter', 'None');

%% Populate UI
if isfield(BpodSystem.SystemSettings, 'ProtocolFolder')
    BpodSystem.Path.ProtocolFolder = BpodSystem.SystemSettings.ProtocolFolder;
end

if isempty(BpodSystem.Path.ProtocolFolder)
    choice = questdlg('Protocols folder not found.', ...
        'Protocol folder not found', ...
        'Select folder', 'Select folder');
    BpodSystem.setupFolders;
    close(BpodSystem.GUIHandles.LaunchManagerFig);
elseif isempty(BpodSystem.Path.DataFolder)
    choice = questdlg('Data folder not found.', ...
        'Data folder not found', ...
        'Select folder', 'Select folder');
    BpodSystem.setupFolders;
    close(BpodSystem.GUIHandles.LaunchManagerFig);
else
    loadProtocols;
    BpodSystem.GUIData.DummySubjectString = 'FakeSubject';
    % Set selected protocol to first non-folder item
    protocolNames = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
    selectedProtocol = 1;
    for iName = 1:length(protocolNames)
        thisProtocolName = protocolNames{iName};
        if thisProtocolName(1) == '<'
            selectedProtocol = iName+1;
        end
    end

    if selectedProtocol > length(protocolNames)
        % If somehow our counter is higher than the number of protocols
        % The last thing in the list must have been a folder
        % Reset to first item in list
        selectedProtocol = 1;
        set(BpodSystem.GUIHandles.ProtocolSelector, 'Value', selectedProtocol);
        return;
    end

    set(BpodSystem.GUIHandles.ProtocolSelector, 'Value', selectedProtocol);
    selectedProtocolName = protocolNames{selectedProtocol};
    BpodSystem.Status.CurrentProtocolName = selectedProtocolName;
    dataPath = fullfile(BpodSystem.Path.DataFolder,BpodSystem.GUIData.DummySubjectString);
    protocolName = BpodSystem.Status.CurrentProtocolName;
    %Make standard folders for this protocol.  This will fail silently if the folders exist
    warning off % Suppress warning that directory already exists
    mkdir(dataPath, protocolName);
    mkdir(fullfile(dataPath,protocolName,'Session Data'))
    mkdir(fullfile(dataPath,protocolName,'Session Settings'))
    warning on
    % Ensure that a default settings file exists
    defaultSettingsFilePath = fullfile(dataPath,protocolName,'Session Settings', 'DefaultSettings.mat');
    if ~exist(defaultSettingsFilePath)
        ProtocolSettings = struct;
        save(defaultSettingsFilePath, 'ProtocolSettings')
    end
    loadSubjects(protocolName);
    loadSettings(protocolName, BpodSystem.GUIData.DummySubjectString);
    update_datafile(protocolName, BpodSystem.GUIData.DummySubjectString);
    BpodSystem.GUIData.ProtocolSelectorLastValue = 1;
end

function ProtocolSelectorNavigate (a,b)
global BpodSystem % Import the global BpodSystem object
isNewFolder = false;
currentValue = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
String = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
if currentValue == BpodSystem.GUIData.ProtocolSelectorLastValue
    candidate = String{currentValue};
    if candidate(1) == '<'
        folderName = candidate(2:end-1);
        set(BpodSystem.GUIHandles.ProtocolSelector, 'Value', 1);
        if folderName(1) == '.'
            BpodSystem.Path.ProtocolFolder = BpodSystem.SystemSettings.ProtocolFolder;
        else
            BpodSystem.Path.ProtocolFolder = fullfile(BpodSystem.Path.ProtocolFolder, folderName);
        end
        isNewFolder = true;
        loadProtocols;
    end
else
    protocolName = String{currentValue};
    if protocolName(1) ~= '<'
        % Make sure a default settings file exists
        settingsFolder = fullfile(BpodSystem.Path.DataFolder,BpodSystem.GUIData.DummySubjectString,protocolName, 'Session Settings');
        if ~exist(settingsFolder)
            mkdir(settingsFolder);
        end
        defaultSettingsPath = fullfile(settingsFolder,'DefaultSettings.mat');
        % Ensure that a default settings file exists
        if ~exist(defaultSettingsPath)
            ProtocolSettings = struct;
            save(defaultSettingsPath, 'ProtocolSettings')
        end

        loadSubjects(protocolName);
        loadSettings(protocolName, BpodSystem.GUIData.DummySubjectString);
        update_datafile(protocolName, BpodSystem.GUIData.DummySubjectString);
        BpodSystem.Status.CurrentProtocolName = protocolName;
    end
end
if isNewFolder
    BpodSystem.GUIData.ProtocolSelectorLastValue = 1;
else
    BpodSystem.GUIData.ProtocolSelectorLastValue = currentValue;
end


function subject_selector_navigate(a,b)
global BpodSystem % Import the global BpodSystem object
protocolList = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
selectedProtocol = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
protocolName = protocolList{selectedProtocol};
nameList = get(BpodSystem.GUIHandles.SubjectSelector, 'String');
selected = get(BpodSystem.GUIHandles.SubjectSelector, 'Value');
if iscell(nameList)
    selectedName = nameList{selected};
else
    selectedName = nameList;
end
settingsPath = fullfile(BpodSystem.Path.DataFolder,selectedName,protocolName,'Session Settings');
candidates = dir(settingsPath);
nSettingsFiles = 0;
settingsFileNames = cell(1);
for i = 3:length(candidates)
    extension = candidates(i).name;
    extension = extension(length(extension)-2:length(extension));
    if strcmp(extension, 'mat')
        nSettingsFiles = nSettingsFiles + 1;
        name = candidates(i).name;
        settingsFileNames{nSettingsFiles} = name(1:end-4);
    end
end
set(BpodSystem.GUIHandles.SettingsSelector, 'String', settingsFileNames);
set(BpodSystem.GUIHandles.SettingsSelector, 'Value', 1);
BpodSystem.Status.CurrentSubjectName = selectedName;
update_datafile(protocolName, selectedName);

function loadProtocols
global BpodSystem % Import the global BpodSystem object
if strcmp(BpodSystem.Path.ProtocolFolder, BpodSystem.SystemSettings.ProtocolFolder)
    startPos = 3;
else
    startPos = 2;
end
candidates = dir(BpodSystem.Path.ProtocolFolder);
protocolNames = cell(0);
nProtocols = 0;
for x = startPos:length(candidates)
    if candidates(x).isdir
        protocolFolder = fullfile(BpodSystem.Path.ProtocolFolder, candidates(x).name);
        contents = dir(protocolFolder);
        nItems = length(contents);
        found = 0;
        for y = 3:nItems
            if strcmp(contents(y).name, [candidates(x).name '.m'])
                found = 1;
            end
        end
        if found
            protocolName = candidates(x).name;
        else
            protocolName = ['<' candidates(x).name '>'];
        end
        nProtocols = nProtocols + 1;
        protocolNames{nProtocols} = protocolName;
    end
end

if isempty(protocolNames)
    protocolNames = {'No Protocols Found'};
else
    % Sort to put organizing directories first
    Types = ones(1,nProtocols);
    for i = 1:nProtocols
        protocolName = protocolNames{i};
        if protocolName(1) == '<'
            Types(i) = 0;
        end
    end
    [a, Order] = sort(Types);
    protocolNames = protocolNames(Order);
end
set(BpodSystem.GUIHandles.ProtocolSelector, 'String', protocolNames);

function loadSubjects(ProtocolName)
global BpodSystem % Import the global BpodSystem object
% Make a list of the names of all subjects who already have a folder for this
% protocol.
candidateSubjects = dir(BpodSystem.Path.DataFolder);
subjectNames = cell(1);
nSubjects = 1;
subjectNames{1} = BpodSystem.GUIData.DummySubjectString;
for x = 1:length(candidateSubjects)
    if x > 2
        if candidateSubjects(x).isdir
            if ~strcmp(candidateSubjects(x).name, BpodSystem.GUIData.DummySubjectString)
                testpath = fullfile(BpodSystem.Path.DataFolder,candidateSubjects(x).name,ProtocolName);
                if exist(testpath) == 7
                    nSubjects = nSubjects + 1;
                    subjectNames{nSubjects} = candidateSubjects(x).name;
                end
            end
        end
    end
end
set(BpodSystem.GUIHandles.SubjectSelector,'String',subjectNames);
set(BpodSystem.GUIHandles.SubjectSelector,'Value',1);

function loadSettings(ProtocolName, SubjectName)
global BpodSystem % Import the global BpodSystem object
settingsPath = fullfile(BpodSystem.Path.DataFolder, SubjectName, ProtocolName, 'Session Settings');
candidates = dir(settingsPath);
nSettingsFiles = 0;
settingsFileNames = cell(1);
for x = 3:length(candidates)
    extension = candidates(x).name;
    extension = extension(end-2:end);
    if strcmp(extension, 'mat')
        nSettingsFiles = nSettingsFiles + 1;
        name = candidates(x).name;
        settingsFileNames{nSettingsFiles} = name(1:end-4);
    end
end
set(BpodSystem.GUIHandles.SettingsSelector, 'String', settingsFileNames);
set(BpodSystem.GUIHandles.SettingsSelector,'Value',1);

function update_datafile(protocolName, subjectName)
global BpodSystem % Import the global BpodSystem object
dateInfo = datestr(now, 30);
dateInfo(dateInfo == 'T') = '_';
localDir = BpodSystem.Path.DataFolder(max(find(BpodSystem.Path.DataFolder(1:end-1) == filesep)+1):end);
set(BpodSystem.GUIHandles.DataFilePathDisplay, 'String',... 
    [filesep fullfile(localDir, subjectName, protocolName, 'Session Data') filesep],'interpreter','none');
fileName = [subjectName '_' protocolName '_' dateInfo '.mat'];
set(BpodSystem.GUIHandles.DataFileDisplay, 'String', fileName);
BpodSystem.Path.CurrentDataFile = fullfile(BpodSystem.Path.DataFolder, subjectName, protocolName, 'Session Data', fileName);

function add_subject(a,b)
global BpodSystem % Import the global BpodSystem object
nameInputFig = figure('Position',[550 600 250 100],'name','New test subject','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
bg = imread('NameInputBG.bmp');
image(bg); axis off;
text(15, 20,'Subject Name:', 'FontName', 'Courier New', 'FontSize', 16, 'Color', [0.8 0.8 0.8]);
if ispc
    nameEntryYwidth = 200;
elseif ismac
    nameEntryYwidth = 150;
else
    nameEntryYwidth = 200;
end
newAnimalName = uicontrol('Style', 'edit', 'String', '', 'Position', [25 25 nameEntryYwidth 25],... 
                          'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [1 1 1]);
uicontrol(newAnimalName)
waitfor(newAnimalName,'String')
nameList = get(BpodSystem.GUIHandles.SubjectSelector, 'String');
if ~iscell(nameList)
    temp{1} = nameList;
    nameList = temp;
end

if isgraphics(nameInputFig)
    newName = get(newAnimalName, 'String');
else
    newName = [];
end
if ~isempty(newName)
    newName = spaces2underscores(newName);

    % Check to see if subject already exists
    protocolName = BpodSystem.Status.CurrentProtocolName;
    testpath = fullfile(BpodSystem.Path.DataFolder,newName);
    testpath2 = fullfile(testpath,protocolName);
    newAnimal = 0;
    if exist(testpath) ~= 7
        mkdir(testpath);
        newAnimal = 1;
    end
    if exist(testpath2) ~= 7
        nameList{length(nameList)+1} = newName;
        set(BpodSystem.GUIHandles.SubjectSelector, 'String', nameList);
        mkdir( fullfile(testpath,protocolName));
        mkdir( fullfile(testpath,protocolName,'Session Data'))
        mkdir( fullfile(testpath,protocolName,'Session Settings'))
        settingsPath = fullfile(testpath,protocolName,'Session Settings');
        defaultSettingsPath = fullfile(settingsPath,'DefaultSettings.mat');

        % Ensure that a default settings file exists
        if ~exist(defaultSettingsPath)
            ProtocolSettings = struct;
            save(defaultSettingsPath, 'ProtocolSettings')
        end
        ProtocolSettings = struct;
        save(defaultSettingsPath, 'ProtocolSettings')
        close(nameInputFig);
        if newAnimal == 0
            msgbox(['Existing test subject ' newName ' has now been registered for ' protocolName '.'], 'Modal')
        end
    else
        close(nameInputFig);
        BpodErrorSound;
        msgbox('Subject already exists in this task. No entry made.', 'Modal')
    end
end

function create_protocol(a,b)
global BpodSystem % Import the global BpodSystem object
nameInputFig = figure('Position',[550 600 250 100],'name','New Protocol','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
bg = imread('NameInputBG.bmp');
image(bg); axis off;
text(15, 20,'Protocol Name:', 'FontName', 'Courier New', 'FontSize', 16, 'Color', [0.8 0.8 0.8]);
newProtocolName = uicontrol('Style', 'edit', 'String', '', 'Position', [25 25 200 25], 'FontWeight', 'bold', 'FontSize', 12,... 
                            'BackgroundColor', [1 1 1]);
uicontrol(newProtocolName)
waitfor(newProtocolName,'String')
nameList = get(BpodSystem.GUIHandles.SubjectSelector, 'String');
if ~iscell(nameList)
    Temp{1} = nameList;
    nameList = Temp;
end

if isgraphics(nameInputFig)
    newName = get(newProtocolName, 'String');
else
    newName = [];
end
try
    close(nameInputFig);
catch
end
if ~isempty(newName)
    newProtocolName = spaces2underscores(newName);
    % Check to see if protocol already exists
    protocolNameList = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
    if sum(strcmp(newProtocolName,protocolNameList)) > 0
        BpodErrorSound;
        msgbox(['A protocol named ' newProtocolName ' already exists. Please delete it first.'], 'Modal');
    else
        path = fullfile(BpodSystem.Path.ProtocolFolder, newProtocolName);
        mkdir(path);
        newProtocolFile = fullfile(path, [newProtocolName '.m']);
        copyfile(fullfile(BpodSystem.Path.BpodRoot, 'Examples', 'Protocols', 'ProtocolTemplate', 'ProtocolTemplate.m'), newProtocolFile);
        file1 = fopen(newProtocolFile, 'r+');
        fprintf(file1, '                         ');
        fseek(file1, 0, 'bof');
        fprintf(file1, ['function ' newProtocolName]);
        fclose(file1);
        edit(newProtocolFile);
        set(BpodSystem.GUIHandles.ProtocolSelector,'Value',1);
        loadProtocols
    end
end

function add_settings(a,b)
global BpodSystem % Import the global BpodSystem object
if ispc
    nameEntryYwidth = 200;
elseif ismac
    nameEntryYwidth = 150;
else
    nameEntryYwidth = 200;
end
newSubjectGFX = imread('NameInputBG.bmp');
nameInputFig = figure('Position',[550 600 250 100],'name','New settings file','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
image(newSubjectGFX); axis off;
text(15, 20,'Settings Name:', 'FontName', 'Courier New', 'FontSize', 16, 'Color', [0.8 0.8 0.8]);
newSettingsName = uicontrol('Style', 'edit', 'String', '', 'Position', [25 25 nameEntryYwidth 25], 'FontWeight', 'bold',... 
                            'FontSize', 12, 'BackgroundColor', [1 1 1]);
uicontrol(newSettingsName)
waitfor(newSettingsName,'String')
settingsNameList = get(BpodSystem.GUIHandles.SettingsSelector, 'String');
if ~iscell(settingsNameList)
    temp{1} = settingsNameList;
    settingsNameList = temp;
end
newSettingsName = get(newSettingsName, 'String');
newSettingsName = spaces2underscores(newSettingsName);
% Check to see if settings file already exists

subjectNameList = get(BpodSystem.GUIHandles.SubjectSelector, 'String');
subjectNameValue = get(BpodSystem.GUIHandles.SubjectSelector, 'Value');
if ~iscell(subjectNameList)
    temp{1} = subjectNameList;
    subjectNameList = temp;
end
subjectName = subjectNameList{subjectNameValue};
% Check to see if subject already exists
protocolName = BpodSystem.Status.CurrentProtocolName;
testpath = fullfile(BpodSystem.Path.DataFolder,subjectName,protocolName,'Session Settings',[newSettingsName '.mat' ]);
if exist(testpath) == 0
    settingsPath = testpath;
    ProtocolSettings = struct;
    save(settingsPath, 'ProtocolSettings')
    settingsNameList{length(settingsNameList)+1} = newSettingsName;
    set(BpodSystem.GUIHandles.SettingsSelector, 'String', settingsNameList);
    set(BpodSystem.GUIHandles.SettingsSelector, 'Value', length(settingsNameList));
    close(nameInputFig);
    BpodSystem.Path.Settings = settingsPath;

    % Load struct into workspace and bring user to edit settings file
    BpodSystem.Path.Settings = settingsPath;
    evalin('base', ['load(''' settingsPath ''')'])
    clc
    disp(' ')
    disp('---CREATE SESSION SETTINGS---')
    disp(['The settings file ' newSettingsName '.mat is now an empty struct called "ProtocolSettings" in your workspace.'])
    disp('Modify "ProtocolSettings" as desired, then run the following command to save:')
    disp('SaveProtocolSettings(ProtocolSettings);')
    disp('----------------------------')
    commandwindow
else
    close(nameInputFig);
    BpodErrorSound;
    msgbox('A settings file with this name exists. No entry made.', 'Modal')
end

function edit_settings(a,b)
global BpodSystem % Import the global BpodSystem object
settingsNames = get(BpodSystem.GUIHandles.SettingsSelector, 'String');
selectedSettingsIndex = get(BpodSystem.GUIHandles.SettingsSelector, 'Value');
selectedSettingsName = settingsNames{selectedSettingsIndex};
protocolNames = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
selectedProtocol = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
selectedProtocolName = protocolNames{selectedProtocol};
subjectList = get(BpodSystem.GUIHandles.SubjectSelector,'String');
subjectIndex = get(BpodSystem.GUIHandles.SubjectSelector,'Value');
selectedSubjectName = subjectList{subjectIndex};
settingsFile = fullfile(BpodSystem.Path.DataFolder, selectedSubjectName, selectedProtocolName, 'Session Settings',... 
                       [selectedSettingsName '.mat']);
BpodSystem.Path.Settings = settingsFile;
evalin('base', ['load(''' settingsFile ''')'])
clc
disp(' ')
disp('---EDIT SESSION SETTINGS---')
disp(['The settings file ' selectedSettingsName '.mat is now a struct called "ProtocolSettings" in your workspace.'])
disp('Modify "ProtocolSettings" as desired, then run the following command to save your changes:')
disp('SaveProtocolSettings(ProtocolSettings);')
disp('----------------------------')
commandwindow

function edit_protocol(a,b)
global BpodSystem % Import the global BpodSystem object
protocolNames = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
selectedProtocol = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
selectedProtocolName = protocolNames{selectedProtocol};
protocolPath = fullfile(BpodSystem.Path.ProtocolFolder, selectedProtocolName, [selectedProtocolName '.m']);
edit(protocolPath);

function delete_settings(a,b)
global BpodSystem % Import the global BpodSystem object
settingsNames = get(BpodSystem.GUIHandles.SettingsSelector, 'String');
selectedSettingsIndex = get(BpodSystem.GUIHandles.SettingsSelector, 'Value');
defaultSettingsIndex = find(strcmp('DefaultSettings', settingsNames));
selectedSettingsName = settingsNames{selectedSettingsIndex};
protocolNames = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
selectedProtocol = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
selectedProtocolName = protocolNames{selectedProtocol};
subjectList = get(BpodSystem.GUIHandles.SubjectSelector,'String');
subjectIndex = get(BpodSystem.GUIHandles.SubjectSelector,'Value');
selectedSubjectName = subjectList{subjectIndex};
settingsFile = fullfile(BpodSystem.Path.DataFolder, selectedSubjectName, selectedProtocolName, 'Session Settings',... 
                        [selectedSettingsName '.mat']);
if selectedSettingsIndex ~= defaultSettingsIndex
    deleteFig = figure('Position',[550 600 350 150],'name','Delete settings file','numbertitle','off', 'MenuBar', 'none',... 
                       'Resize', 'off');
    Warning = uicontrol('Style', 'text', 'String', ['Warning! This will delete the settings file: ' selectedSettingsName '.mat!'],... 
                        'Position', [1 110 350 30], 'FontWeight', 'bold', 'FontSize', 8, 'BackgroundColor', [1 0 0]);
    BpodErrorSound;
    intentCheck = uicontrol('Style', 'checkbox', 'String', ['I really want to do this'], 'Position', [75 50 200 30],... 
                            'FontWeight', 'bold', 'FontSize', 8);
    zapButton = uicontrol('Style', 'togglebutton', 'String', ['Ok'], 'Position', [125 10 100 30], 'FontWeight', 'bold', 'FontSize', 8);
    waitfor(zapButton, 'Value')
    okToDelete = 0;
    try
        okToDelete = sum(get(intentCheck, 'Value') == 1);
    catch
    end
    if (okToDelete == 1)
        close(deleteFig);
        delete(settingsFile);
        set(BpodSystem.GUIHandles.SettingsSelector,'Value',1);
        loadSettings(selectedProtocolName, selectedSubjectName);
    end
end

function delete_protocol(a,b)
global BpodSystem % Import the global BpodSystem object
protocolNames = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
selectedProtocol = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
selectedProtocolName = protocolNames{selectedProtocol};
protocolPath = fullfile(BpodSystem.Path.ProtocolFolder, selectedProtocolName);
if selectedProtocol ~= 1
    deleteFig = figure('Position',[550 600 350 150],'name','Delete protocol','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
    uicontrol('Style', 'text', 'String', ['Warning! The protocol ' selectedProtocolName ' will be permanently deleted!'],... 
              'Position', [1 110 350 30], 'FontWeight', 'bold', 'FontSize', 8, 'BackgroundColor', [1 0 0]);
    BpodErrorSound;
    backupCheck = uicontrol('Style', 'checkbox', 'String', ['I have backed up necessary files'], 'Position', [75 80 200 30],... 
                            'FontWeight', 'bold', 'FontSize', 8);
    intentCheck = uicontrol('Style', 'checkbox', 'String', ['I really want to do this'], 'Position', [75 50 200 30],... 
                            'FontWeight', 'bold', 'FontSize', 8);
    zapButton = uicontrol('Style', 'togglebutton', 'String', ['Ok'], 'Position', [125 10 100 30], 'FontWeight', 'bold', 'FontSize', 8);
    waitfor(zapButton, 'Value')
    okToDelete = 0;
    try
        okToDelete = sum(get(backupCheck, 'Value') + get(intentCheck, 'Value') == 2);
    catch
    end
    try
        close(deleteFig);
    catch
    end
    if ((okToDelete == 1) && (~isempty(selectedProtocolName)))
        rmdir(protocolPath, 's');
        set(BpodSystem.GUIHandles.ProtocolSelector,'Value',1);
        loadProtocols
    end
end

function delete_subject(a,b)
global BpodSystem % Import the global BpodSystem object
protocolNameList = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
protocolSelected = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
protocolName = protocolNameList{protocolSelected};
nameList = get(BpodSystem.GUIHandles.SubjectSelector, 'String');
selected = get(BpodSystem.GUIHandles.SubjectSelector, 'Value');
if selected > 1
    if iscell(nameList)
        selectedName = nameList{selected};
    else
        selectedName = nameList;
    end
    deleteFig = figure('Position',[550 600 350 150],'name','Delete test subject','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
    uicontrol('Style', 'text', 'String', ['Warning! This will delete all data and settings associated with the ' protocolName... 
              ' protocol for test subject ' selectedName '!'], 'Position', [1 110 350 30], 'FontWeight', 'bold', 'FontSize', 8,... 
              'BackgroundColor', [1 0 0]);
    BpodErrorSound;
    backupCheck = uicontrol('Style', 'checkbox', 'String', ['I have backed up necessary files'], 'Position', [75 80 200 30],... 
                            'FontWeight', 'bold', 'FontSize', 8);
    intentCheck = uicontrol('Style', 'checkbox', 'String', ['I really want to do this'], 'Position', [75 50 200 30],... 
                            'FontWeight', 'bold', 'FontSize', 8);
    zapButton = uicontrol('Style', 'togglebutton', 'String', ['Ok'], 'Position', [125 10 100 30], 'FontWeight', 'bold', 'FontSize', 8);
    waitfor(zapButton, 'Value')
    okToDelete = 0;
    try
        okToDelete = sum(get(backupCheck, 'Value') + get(intentCheck, 'Value') == 2);
    catch
    end
    if ((okToDelete == 1) && (~isempty(selectedName)))
        deletePath = fullfile(BpodSystem.Path.DataFolder,selectedName, protocolName);
        rmdir(deletePath,'s')
        rootPath = fullfile(BpodSystem.Path.DataFolder,selectedName);
        contents = dir(rootPath);
        if length(contents) == 2
            rmdir(rootPath,'s');
        end
        BpodErrorSound;
        msgbox(['       Test subject ' selectedName ' unregistered!'], 'Modal');
        close(deleteFig);
        pos = find(strcmp(selectedName, nameList));
        nameList = nameList([1:pos-1 pos+1:length(nameList)]);
        set(BpodSystem.GUIHandles.SubjectSelector, 'String', nameList);
        set(BpodSystem.GUIHandles.SubjectSelector, 'Value', 1);
    else
        BpodErrorSound;
        msgbox('           Data NOT changed.', 'Modal');
        try
            close(deleteFig);
        catch
        end
    end
else
    msgbox('The default subject cannot be deleted.');
    BpodErrorSound;
end

function import_settings(a,b)
global BpodSystem % Import the global BpodSystem object
protocolNames = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
selectedProtocol = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
if ~iscell(protocolNames)
    temp{1} = protocolNames;
    protocolNames = temp;
end
selectedProtocolName = protocolNames{selectedProtocol};
subjectList = get(BpodSystem.GUIHandles.SubjectSelector,'String');
subjectIndex = get(BpodSystem.GUIHandles.SubjectSelector,'Value');
selectedSubjectName = subjectList{subjectIndex};
searchStartPath = BpodSystem.Path.DataFolder;
[Filename Pathname Junk] = uigetfile('*.mat', 'Select settings file to import', searchStartPath);
settingsName = Filename(1:(length(Filename)-4));
targetSettingsPath = [Pathname Filename];
if ~exist(targetSettingsPath)
    error(['Settings file not found for ' settingsName])
end
destinationSettingsPath = fullfile(BpodSystem.Path.DataFolder,selectedSubjectName,selectedProtocolName,...
                          'Session Settings',[ settingsName '.mat']);
if (exist(destinationSettingsPath) == 2)
    msgbox(['"' settingsName '"' ' already exists in the target folder. Import aborted.'])
    BpodErrorSound
end

% Copy files
copyfile(targetSettingsPath, destinationSettingsPath);

% Update UI with new settings
loadSettings(selectedProtocolName, selectedSubjectName);

function launch_protocol(a,b)
global BpodSystem % Import the global BpodSystem object
protocolList = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
selectedProtocol = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
protocolName = protocolList{selectedProtocol};
subjectList = get(BpodSystem.GUIHandles.SubjectSelector,'String');
subjectIndex = get(BpodSystem.GUIHandles.SubjectSelector,'Value');
subjectName = subjectList{subjectIndex};
settingsList = get(BpodSystem.GUIHandles.SettingsSelector, 'String');
settingsIndex = get(BpodSystem.GUIHandles.SettingsSelector,'Value');
settingsName = settingsList{settingsIndex};
settingsFileName = fullfile(BpodSystem.Path.DataFolder, subjectName, protocolName, 'Session Settings', [settingsName '.mat']);
dataFolder = fullfile(BpodSystem.Path.DataFolder,subjectName,protocolName,'Session Data');
if ~exist(dataFolder)
    mkdir(dataFolder);
end

% On Bpod r2+, if FlexIO channels are configured as analog,
% setup binary data file
if BpodSystem.MachineType > 3
    nAnalogChannels = sum(BpodSystem.HW.FlexIO_ChannelTypes == 2);
    if nAnalogChannels > 0
        analogFilename = [BpodSystem.Path.CurrentDataFile(1:end-4) '_ANLG.dat'];
        if BpodSystem.Status.RecordAnalog == 1
            BpodSystem.AnalogDataFile = fopen(analogFilename,'w');
            if BpodSystem.AnalogDataFile == -1
                error(['Error: Could not open the analog data file: ' analogFilename])
            end
        end
        BpodSystem.Status.nAnalogSamples = 0;
    end
end

BpodSystem.Status.Live = 1;
BpodSystem.Status.LastEvent = 0;
BpodSystem.GUIData.ProtocolName = protocolName;
BpodSystem.GUIData.SubjectName = subjectName;
BpodSystem.GUIData.SettingsFileName = settingsFileName;
BpodSystem.Path.Settings = settingsFileName;
settingStruct = load(BpodSystem.Path.Settings);
F = fieldnames(settingStruct);
fieldName = F{1};
BpodSystem.ProtocolSettings = eval(['settingStruct.' fieldName]);
BpodSystem.Data = struct;
if BpodSystem.MachineType > 3
    if nAnalogChannels > 0
        BpodSystem.Data.Analog = struct;
        BpodSystem.Data.Analog.info = struct;
        BpodSystem.Data.Analog.FileName = analogFilename;
        BpodSystem.Data.Analog.nChannels = nAnalogChannels;
        BpodSystem.Data.Analog.channelNumbers = find(BpodSystem.HW.FlexIO_ChannelTypes == 2);
        BpodSystem.Data.Analog.SamplingRate = BpodSystem.HW.FlexIO_SamplingRate;
        BpodSystem.Data.Analog.nSamples = 0;
        % Add human-readable info about data fields to 'info struct
        BpodSystem.Data.Analog.info.FileName = 'Complete path and filename of the binary file to which the raw data was logged';
        BpodSystem.Data.Analog.info.nChannels = 'The number of Flex I/O channels configured as analog input';
        BpodSystem.Data.Analog.info.channelNumbers = 'The indexes of Flex I/O channels configured as analog input';
        BpodSystem.Data.Analog.info.SamplingRate = 'The sampling rate of the analog data. Units = Hz';
        BpodSystem.Data.Analog.info.nSamples = 'The total number of analog samples captured during the behavior session';
        BpodSystem.Data.Analog.info.Samples = 'Analog measurements captured. Rows are separate analog input channels. Units = Volts';
        BpodSystem.Data.Analog.info.Timestamps = 'Time of each sample (computed from sample index and sampling rate)';
        BpodSystem.Data.Analog.info.TrialNumber = 'Experimental trial during which each analog sample was captured';
        BpodSystem.Data.Analog.info.TrialData = 'A cell array of Samples. Each cell contains samples captured during a single trial.';
    end
end
protocolFolderPath = fullfile(BpodSystem.Path.ProtocolFolder,protocolName);
protocolPath = fullfile(BpodSystem.Path.ProtocolFolder,protocolName,[protocolName '.m']);
addpath(protocolFolderPath);
set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton, 'TooltipString', 'Press to pause session');

% % Send metadata to Bpod Phone Home program (disabled pending a more stable server)
% isOnline = BpodSystem.check4Internet();
% if (isOnline == 1) && (BpodSystem.SystemSettings.PhoneHome == 1)
%     BpodSystem.BpodPhoneHome(1);
% end

if BpodSystem.Status.AnalogViewer
    set(BpodSystem.GUIHandles.RecordButton, 'Enable', 'off')
end

BpodSystem.Status.BeingUsed = 1;
BpodSystem.Status.SessionStartFlag = 1;
BpodSystem.ProtocolStartTime = now*100000;
BpodSystem.resetSessionClock();
close(BpodSystem.GUIHandles.LaunchManagerFig);
disp(' ');
disp(['Starting ' protocolName]);
set(BpodSystem.GUIHandles.CurrentStateDisplay, 'String', '---');
set(BpodSystem.GUIHandles.PreviousStateDisplay, 'String', '---');
set(BpodSystem.GUIHandles.LastEventDisplay, 'String', '---');
set(BpodSystem.GUIHandles.TimeDisplay, 'String', '0:00:00');
if sum(BpodSystem.InputsEnabled(BpodSystem.HW.Inputs == 'P')) == 0
    warning(['All Bpod behavior ports are currently disabled.'... 
             'If your protocol requires behavior ports, enable them from the settings menu.'])
end
run(protocolPath);

function outputString = spaces2underscores(inputString)
spaceIndexes = inputString == ' ';
inputString(spaceIndexes) = '_';
outputString = inputString;

function close_launch_manager(a,b)
global BpodSystem % Import the global BpodSystem object
close(BpodSystem.GUIHandles.LaunchManagerFig);