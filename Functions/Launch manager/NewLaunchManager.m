function NewLaunchManager

global BpodSystem
%% Build UI
BpodSystem.GUIHandles.LaunchManagerFig = figure('Position',[80 50 750 600],'name','Launch Manager','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('LaunchManagerBG2.bmp');
image(BG); axis off;
text(130, 45,'Protocol Launch Manager', 'FontName', 'OCRASTD', 'FontSize', 20, 'Color', [0.8 0.8 0.8]);
line([10 590], [80 80], 'Color', [0.8 0.8 0.8], 'LineWidth', 1);
BpodSystem.GUIHandles.ProtocolSelector = uicontrol('Style', 'listbox','Position', [25 95 200 390], 'String', 'Folder not found', 'Callback', @ProtocolSelectorNavigate, 'FontWeight', 'bold', 'FontSize', 11, 'BackgroundColor', [.8 .8 .8]);
BpodSystem.GUIHandles.SubjectSelector = uicontrol('Style', 'listbox','Position', [265 95 200 390], 'String', 'Folder not found', 'Callback', @SubjectSelectorNavigate, 'FontWeight', 'bold', 'FontSize', 11, 'BackgroundColor', [.8 .8 .8]);
BpodSystem.GUIHandles.SettingsSelector = uicontrol('Style', 'listbox','Position', [505 95 200 390], 'String', 'Folder not found', 'FontWeight', 'bold', 'FontSize', 11, 'BackgroundColor', [.8 .8 .8]);
text(20, 120,'Protocol', 'FontName', 'OCRASTD', 'FontSize', 16, 'Color', [0.8 0.8 0.8]);
text(212, 120,'Subject', 'FontName', 'OCRASTD', 'FontSize', 16, 'Color', [0.8 0.8 0.8]);
text(405, 120,'Settings', 'FontName', 'OCRASTD', 'FontSize', 16, 'Color', [0.8 0.8 0.8]);
BpodSystem.GUIHandles.LaunchButton = uicontrol('Style', 'pushbutton', 'String', ['Launch ' char(187)], 'Position', [590 10 150 65], 'Callback', @LaunchProtocol, 'TooltipString', 'Launch Protocol', 'FontName', 'OCRASTD', 'FontSize', 16, 'BackgroundColor', [.37 .37 .37], 'ForegroundColor', [.8 .8 .8]);
%BpodSystem.GUIHandles.BackButton = uicontrol('Style', 'pushbutton', 'String', [char(171) ' Return'], 'Position', [15 10 150 65], 'Callback', @CloseLaunchManager, 'TooltipString', 'Close Launch Manager', 'FontName', 'OCRASTD', 'FontSize', 16, 'BackgroundColor', [.37 .37 .37], 'ForegroundColor', [.8 .8 .8]);
AddGFX = imread('PlusButton.bmp');
BpodSystem.GUIHandles.AddProtocolButton = uicontrol('Style', 'pushbutton', 'CData', AddGFX, 'Position', [228 459 25 25], 'Callback', @CreateProtocol, 'TooltipString', 'Create Protocol', 'FontName', 'OCRASTD', 'FontSize', 18, 'BackgroundColor', [.5 .5 .5], 'ForegroundColor', [.95 .95 .95]);
DelGFX = imread('MinusButton.bmp');
BpodSystem.GUIHandles.DelProtocolButton = uicontrol('Style', 'pushbutton', 'CData', DelGFX, 'Position', [228 429 25 25], 'Callback', @DeleteProtocol, 'TooltipString', 'Delete Protocol', 'FontName', 'OCRASTD', 'FontSize', 18, 'BackgroundColor', [.5 .5 .5], 'ForegroundColor', [.95 .95 .95]);
EditGFX = imread('EditButton.bmp');
BpodSystem.GUIHandles.EditProtocolButton = uicontrol('Style', 'pushbutton', 'CData', EditGFX, 'Position', [228 399 25 25], 'Callback', @EditProtocol, 'TooltipString', 'Edit Protocol', 'FontName', 'OCRASTD', 'FontSize', 22, 'BackgroundColor', [.5 .5 .5], 'ForegroundColor', [.95 .95 .95]);
ImportGFX = imread('ImportButton.bmp');
BpodSystem.GUIHandles.AddSubjectButton = uicontrol('Style', 'pushbutton', 'CData', AddGFX, 'Position', [468 459 25 25], 'Callback', @AddSubject, 'TooltipString', 'Add Test Subject', 'FontName', 'OCRASTD', 'FontSize', 18, 'BackgroundColor', [.5 .5 .5], 'ForegroundColor', [.95 .95 .95]);
BpodSystem.GUIHandles.DelSubjectButton = uicontrol('Style', 'pushbutton', 'CData', DelGFX, 'Position', [468 429 25 25], 'Callback', @DeleteSubject, 'TooltipString', 'Delete Test Subject', 'FontName', 'OCRASTD', 'FontSize', 18, 'BackgroundColor', [.5 .5 .5], 'ForegroundColor', [.95 .95 .95]);
BpodSystem.GUIHandles.AddSettingsButton = uicontrol('Style', 'pushbutton', 'CData', AddGFX, 'Position', [708 459 25 25], 'Callback', @AddSettings, 'TooltipString', 'Create Session Settings', 'FontName', 'OCRASTD', 'FontSize', 18, 'BackgroundColor', [.5 .5 .5], 'ForegroundColor', [.95 .95 .95]);
DelGFX = imread('MinusButton.bmp');
BpodSystem.GUIHandles.DelSettingsButton = uicontrol('Style', 'pushbutton', 'CData', DelGFX, 'Position', [708 429 25 25], 'Callback', @DeleteSettings, 'TooltipString', 'Delete Session Settings', 'FontName', 'OCRASTD', 'FontSize', 18, 'BackgroundColor', [.5 .5 .5], 'ForegroundColor', [.95 .95 .95]);
EditGFX = imread('EditButton.bmp');
BpodSystem.GUIHandles.EditSettingsButton = uicontrol('Style', 'pushbutton', 'CData', EditGFX, 'Position', [708 399 25 25], 'Callback', @EditSettings, 'TooltipString', 'Edit Session Settings', 'FontName', 'OCRASTD', 'FontSize', 22, 'BackgroundColor', [.5 .5 .5], 'ForegroundColor', [.95 .95 .95]);
ImportGFX = imread('ImportButton.bmp');
BpodSystem.GUIHandles.ImportSettingsButton = uicontrol('Style', 'pushbutton', 'CData', ImportGFX, 'Position', [708 369 25 25], 'Callback', @ImportSettings, 'TooltipString', 'Import Session Settings', 'FontName', 'OCRASTD', 'FontSize', 22, 'BackgroundColor', [.5 .5 .5], 'ForegroundColor', [.95 .95 .95]);
if verLessThan('matlab','9.0')
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
BpodSystem.GUIHandles.DataFilePathDisplay = text(20, 685,'', 'FontName', 'Courier New', 'FontSize', 10, 'Color', [0.9 0.9 0.9]);
BpodSystem.GUIHandles.DataFileLabel = text(20, 665,'Data Folder:', 'FontName', 'Arial', 'FontSize', 10, 'Color', [1 1 1], 'Interpreter', 'None');
BpodSystem.GUIHandles.DataFileDisplay = text(20, 730,'', 'FontName', 'Courier New', 'FontSize', 10, 'Color', [0.9 0.9 0.9], 'Interpreter', 'None');
BpodSystem.GUIHandles.DataFileLabel = text(20, 710,'Data File:', 'FontName', 'Arial', 'FontSize', 10, 'Color', [1 1 1], 'Interpreter', 'None');

%% Populate UI
BpodSystem.Path.ProtocolFolder = BpodSystem.SystemSettings.ProtocolFolder;
loadProtocols;
BpodSystem.GUIData.DummySubjectString = 'FakeSubject';
% Set selected protocol to first non-folder item
ProtocolNames = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
SelectedProtocol = 1;
for i = 1:length(ProtocolNames)
    ThisProtocolName = ProtocolNames{i};
    if ThisProtocolName(1) == '<'
        SelectedProtocol = i+1;
    end
end
set(BpodSystem.GUIHandles.ProtocolSelector, 'Value', SelectedProtocol);
SelectedProtocolName = ProtocolNames{SelectedProtocol};
BpodSystem.Status.CurrentProtocolName = SelectedProtocolName;
DataPath = fullfile(BpodSystem.Path.DataFolder,BpodSystem.GUIData.DummySubjectString);
ProtocolName = BpodSystem.Status.CurrentProtocolName;

%Make standard folders for this protocol.  This will fail silently if the folders exist
mkdir(DataPath, ProtocolName);
mkdir(fullfile(DataPath,ProtocolName,'Session Data'))
mkdir(fullfile(DataPath,ProtocolName,'Session Settings'))

% Ensure that a default settings file exists
DefaultSettingsFilePath = fullfile(DataPath,ProtocolName,'Session Settings', 'DefaultSettings.mat');
if ~exist(DefaultSettingsFilePath)
    ProtocolSettings = struct;
    save(DefaultSettingsFilePath, 'ProtocolSettings')
end
loadSubjects(ProtocolName);
loadSettings(ProtocolName, BpodSystem.GUIData.DummySubjectString);
UpdateDataFile(ProtocolName, BpodSystem.GUIData.DummySubjectString);
BpodSystem.GUIData.ProtocolSelectorLastValue = 1;

function ProtocolSelectorNavigate (~,~)
global BpodSystem
currentValue = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
String = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
if currentValue == BpodSystem.GUIData.ProtocolSelectorLastValue
    Candidate = String{currentValue};
    if Candidate(1) == '<'
        FolderName = Candidate(2:end-1);
        set(BpodSystem.GUIHandles.ProtocolSelector, 'Value', 1);
        if FolderName(1) == '.'
            BpodSystem.Path.ProtocolFolder = BpodSystem.SystemSettings.ProtocolFolder;
        else
            BpodSystem.Path.ProtocolFolder = fullfile(BpodSystem.Path.ProtocolFolder, FolderName);
        end
        loadProtocols;
    end
else
    ProtocolName = String{currentValue};
    if ProtocolName(1) ~= '<'
        % Make sure a default settings file exists
        SettingsFolder = fullfile(BpodSystem.Path.DataFolder,BpodSystem.GUIData.DummySubjectString,ProtocolName, 'Session Settings');
        if ~exist(SettingsFolder)
            mkdir(SettingsFolder);
        end
        DefaultSettingsPath = fullfile(SettingsFolder,'DefaultSettings.mat');
        % Ensure that a default settings file exists
        if ~exist(DefaultSettingsPath)
            ProtocolSettings = struct;
            save(DefaultSettingsPath, 'ProtocolSettings')
        end

        loadSubjects(ProtocolName);
        loadSettings(ProtocolName, BpodSystem.GUIData.DummySubjectString);
        UpdateDataFile(ProtocolName, BpodSystem.GUIData.DummySubjectString);
        BpodSystem.Status.CurrentProtocolName = ProtocolName;
    end
end
BpodSystem.GUIData.ProtocolSelectorLastValue = currentValue;


function SubjectSelectorNavigate (~,~)
global BpodSystem
ProtocolList = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
SelectedProtocol = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
ProtocolName = ProtocolList{SelectedProtocol};
NameList = get(BpodSystem.GUIHandles.SubjectSelector, 'String');
Selected = get(BpodSystem.GUIHandles.SubjectSelector, 'Value');
if iscell(NameList)
    SelectedName = NameList{Selected};
else
    SelectedName = NameList;
end
SettingsPath = fullfile(BpodSystem.Path.DataFolder,SelectedName,ProtocolName,'Session Settings');
Candidates = dir(SettingsPath);
nSettingsFiles = 0;
SettingsFileNames = cell(1);
for x = 3:length(Candidates)
    Extension = Candidates(x).name;
    Extension = Extension(length(Extension)-2:length(Extension));
    if strcmp(Extension, 'mat')
        nSettingsFiles = nSettingsFiles + 1;
        Name = Candidates(x).name;
        SettingsFileNames{nSettingsFiles} = Name(1:end-4);
    end
end
set(BpodSystem.GUIHandles.SettingsSelector, 'String', SettingsFileNames);
set(BpodSystem.GUIHandles.SettingsSelector, 'Value', 1);
BpodSystem.Status.CurrentSubjectName = SelectedName;
UpdateDataFile(ProtocolName, SelectedName);

function loadProtocols
global BpodSystem
if isempty(BpodSystem.Path.ProtocolFolder)
    choice = questdlg('Protocols folder not found.', ...
        'Protocol folder not found', ...
        'Select folder', 'Select folder');
    BpodSystem.setupFolders;
elseif isempty(BpodSystem.Path.DataFolder)
    choice = questdlg('Data folder not found.', ...
        'Data folder not found', ...
        'Select folder', 'Select folder');
    BpodSystem.setupFolders;
else
    if strcmp(BpodSystem.Path.ProtocolFolder, BpodSystem.SystemSettings.ProtocolFolder)
        startPos = 3;
    else
        startPos = 2;
    end
    Candidates = dir(BpodSystem.Path.ProtocolFolder);
    ProtocolNames = cell(1);
    nProtocols = 0;
    for x = startPos:length(Candidates)
        if Candidates(x).isdir
            ProtocolFolder = fullfile(BpodSystem.Path.ProtocolFolder, Candidates(x).name);
            Contents = dir(ProtocolFolder);
            nItems = length(Contents);
            Found = 0;
            for y = 3:nItems
                if strcmp(Contents(y).name, [Candidates(x).name '.m'])
                    Found = 1;
                end
            end
            if Found
                ProtocolName = Candidates(x).name;
            else
                ProtocolName = ['<' Candidates(x).name '>'];
            end
            nProtocols = nProtocols + 1;
            ProtocolNames{nProtocols} = ProtocolName;
        end
    end
    if isempty(ProtocolNames)
        ProtocolNames = {'No Protocols Found'};
    else
        % Sort to put organizing directories first
        Types = ones(1,nProtocols);
        for i = 1:nProtocols
            ProtocolName = ProtocolNames{i};
            if ProtocolName(1) == '<'
                Types(i) = 0;
            end
        end
        [~, Order] = sort(Types);
        ProtocolNames = ProtocolNames(Order);
    end
    set(BpodSystem.GUIHandles.ProtocolSelector, 'String', ProtocolNames);
end

function loadSubjects(ProtocolName)
global BpodSystem
% Make a list of the names of all subjects who already have a folder for this
% protocol.
CandidateSubjects = dir(BpodSystem.Path.DataFolder);
SubjectNames = cell(1);
nSubjects = 1;
SubjectNames{1} = BpodSystem.GUIData.DummySubjectString;
for x = 1:length(CandidateSubjects)
    if x > 2
        if CandidateSubjects(x).isdir
            if ~strcmp(CandidateSubjects(x).name, BpodSystem.GUIData.DummySubjectString)
                Testpath = fullfile(BpodSystem.Path.DataFolder,CandidateSubjects(x).name,ProtocolName);
                if exist(Testpath) == 7
                    nSubjects = nSubjects + 1;
                    SubjectNames{nSubjects} = CandidateSubjects(x).name;
                end
            end
        end
    end
end
set(BpodSystem.GUIHandles.SubjectSelector,'String',SubjectNames);
set(BpodSystem.GUIHandles.SubjectSelector,'Value',1);

function loadSettings(ProtocolName, SubjectName)
global BpodSystem
SettingsPath = fullfile(BpodSystem.Path.DataFolder, SubjectName, ProtocolName, 'Session Settings');
Candidates = dir(SettingsPath);
nSettingsFiles = 0;
SettingsFileNames = cell(1);
for x = 3:length(Candidates)
    Extension = Candidates(x).name;
    Extension = Extension(end-2:end);
    if strcmp(Extension, 'mat')
        nSettingsFiles = nSettingsFiles + 1;
        Name = Candidates(x).name;
        SettingsFileNames{nSettingsFiles} = Name(1:end-4);
    end
end
set(BpodSystem.GUIHandles.SettingsSelector, 'String', SettingsFileNames);
set(BpodSystem.GUIHandles.SettingsSelector,'Value',1);

function UpdateDataFile(ProtocolName, SubjectName)
global BpodSystem
DateInfo = datestr(now, 30); 
DateInfo(DateInfo == 'T') = '_';
LocalDir = BpodSystem.Path.DataFolder(max(find(BpodSystem.Path.DataFolder(1:end-1) == filesep)+1):end);
set(BpodSystem.GUIHandles.DataFilePathDisplay, 'String', [filesep fullfile(LocalDir, SubjectName, ProtocolName, 'Session Data') filesep]);
FileName = [SubjectName '_' ProtocolName '_' DateInfo '.mat'];
set(BpodSystem.GUIHandles.DataFileDisplay, 'String', FileName);
BpodSystem.Path.CurrentDataFile = fullfile(BpodSystem.Path.DataFolder, SubjectName, ProtocolName, 'Session Data', FileName);

function AddSubject(~,~)
global BpodSystem
NewSubjectGFX = imread('NameInputBG.bmp');
NameInputFig = figure('Position',[550 600 200 100],'name','New test subject','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('NameInputBG.bmp');
image(BG); axis off;
text(15, 20,'Subject Name:', 'FontName', 'OCRASTD', 'FontSize', 16, 'Color', [0.8 0.8 0.8]);
NewAnimalName = uicontrol('Style', 'edit', 'String', '', 'Position', [25 25 200 25], 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [1 1 1]);
uicontrol(NewAnimalName)
waitfor(NewAnimalName,'String')
NameList = get(BpodSystem.GUIHandles.SubjectSelector, 'String');
if ~iscell(NameList)
    Temp{1} = NameList;
    NameList = Temp;
end

if isgraphics(NameInputFig)
    NewName = get(NewAnimalName, 'String');
else
    NewName = [];
end
if ~isempty(NewName)
    NewName = Spaces2Underscores(NewName);
    % Check to see if subject already exists
    ProtocolName = BpodSystem.Status.CurrentProtocolName;
    Testpath = fullfile(BpodSystem.Path.DataFolder,NewName);
    Testpath2 = fullfile(Testpath,ProtocolName);
    NewAnimal = 0;
    if exist(Testpath) ~= 7
        mkdir(Testpath);
        NewAnimal = 1;
    end
    if exist(Testpath2) ~= 7
        NameList{length(NameList)+1} = NewName;
        set(BpodSystem.GUIHandles.SubjectSelector, 'String', NameList);
        mkdir( fullfile(Testpath,ProtocolName));
        mkdir( fullfile(Testpath,ProtocolName,'Session Data'))
        mkdir( fullfile(Testpath,ProtocolName,'Session Settings'))
        SettingsPath = fullfile(Testpath,ProtocolName,'Session Settings');
        DefaultSettingsPath = fullfile(SettingsPath,'DefaultSettings.mat');
        % Ensure that a default settings file exists
        if ~exist(DefaultSettingsPath)
            ProtocolSettings = struct;
            save(DefaultSettingsPath, 'ProtocolSettings')
        end
        ProtocolSettings = struct;
        save(DefaultSettingsPath, 'ProtocolSettings')
        close(NameInputFig);
        if NewAnimal == 0
            msgbox(['Existing test subject ' NewName ' has now been registered for ' ProtocolName '.'], 'Modal')
        end
    else
        close(NameInputFig);
        BpodErrorSound;
        msgbox('Subject already exists in this task. No entry made.', 'Modal')
    end
    %catch
    %end
end

function CreateProtocol(~,~)
global BpodSystem
NewSubjectGFX = imread('NameInputBG.bmp');
NameInputFig = figure('Position',[550 600 250 100],'name','New Protocol','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('NameInputBG.bmp');
image(BG); axis off;
text(15, 20,'Protocol Name:', 'FontName', 'OCRASTD', 'FontSize', 16, 'Color', [0.8 0.8 0.8]);
NewProtocolName = uicontrol('Style', 'edit', 'String', '', 'Position', [25 25 200 25], 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [1 1 1]);
uicontrol(NewProtocolName)
waitfor(NewProtocolName,'String')
NameList = get(BpodSystem.GUIHandles.SubjectSelector, 'String');
if ~iscell(NameList)
    Temp{1} = NameList;
    NameList = Temp;
end

if isgraphics(NameInputFig)
    NewName = get(NewProtocolName, 'String');
else
    NewName = [];
end
close(NameInputFig);
if ~isempty(NewName)
    NewProtocolName = Spaces2Underscores(NewName);
    % Check to see if protocol already exists
    ProtocolNameList = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
    if sum(strcmp(NewProtocolName,ProtocolNameList)) > 0
        BpodErrorSound;
        msgbox(['A protocol named ' NewProtocolName ' already exists. Please delete it first.'], 'Modal');
    else
        Path = fullfile(BpodSystem.Path.ProtocolFolder, NewProtocolName);
        mkdir(Path);
        NewProtocolFile = fullfile(Path, [NewProtocolName '.m']);
        copyfile(fullfile(BpodSystem.Path.BpodRoot, 'Examples', 'Protocols', 'ProtocolTemplate', 'ProtocolTemplate.m'), NewProtocolFile);
        File1 = fopen(NewProtocolFile, 'r+');
        fprintf(File1, '                         ');
        fseek(File1, 0, 'bof');
        fprintf(File1, ['function ' NewProtocolName]);
        fclose(File1);
        edit(NewProtocolFile);
        set(BpodSystem.GUIHandles.ProtocolSelector,'Value',1);
        loadProtocols
    end
end

function AddSettings(~,~)
global BpodSystem
NewSubjectGFX = imread('NameInputBG.bmp');
NameInputFig = figure('Position',[550 600 200 100],'name','New settings file','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
image(NewSubjectGFX); axis off;
text(15, 20,'Settings Name:', 'FontName', 'OCRASTD', 'FontSize', 16, 'Color', [0.8 0.8 0.8]);
NewSettingsName = uicontrol('Style', 'edit', 'String', '', 'Position', [25 25 200 25], 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [1 1 1]);
uicontrol(NewSettingsName)
waitfor(NewSettingsName,'String')
SettingsNameList = get(BpodSystem.GUIHandles.SettingsSelector, 'String');
if ~iscell(SettingsNameList)
    Temp{1} = SettingsNameList;
    SettingsNameList = Temp;
end
NewSettingsName = get(NewSettingsName, 'String');
NewSettingsName = Spaces2Underscores(NewSettingsName);
% Check to see if settings file already exists

SubjectNameList = get(BpodSystem.GUIHandles.SubjectSelector, 'String');
SubjectNameValue = get(BpodSystem.GUIHandles.SubjectSelector, 'Value');
if ~iscell(SubjectNameList)
    Temp{1} = SubjectNameList;
    SubjectNameList = Temp;
end
SubjectName = SubjectNameList{SubjectNameValue};
% Check to see if subject already exists
ProtocolName = BpodSystem.Status.CurrentProtocolName;
Testpath = fullfile(BpodSystem.Path.DataFolder,SubjectName,ProtocolName,'Session Settings',[NewSettingsName '.mat' ]);
if exist(Testpath) == 0
    SettingsPath = Testpath;
    ProtocolSettings = struct;
    save(SettingsPath, 'ProtocolSettings')
    SettingsNameList{length(SettingsNameList)+1} = NewSettingsName;
    set(BpodSystem.GUIHandles.SettingsSelector, 'String', SettingsNameList);
    set(BpodSystem.GUIHandles.SettingsSelector, 'Value', length(SettingsNameList));
    close(NameInputFig);
    BpodSystem.Path.Settings = SettingsPath;
    
    % Load struct into workspace and bring user to edit settings file
    BpodSystem.Path.Settings = SettingsPath;
    evalin('base', ['load(''' SettingsPath ''')'])
    clc
    disp(' ')
    disp('---CREATE SESSION SETTINGS---')
    disp(['The settings file ' NewSettingsName '.mat is now an empty struct called "ProtocolSettings" in your workspace.'])
    disp('Modify "ProtocolSettings" as desired, then run the following command to save:')
    disp('SaveProtocolSettings(ProtocolSettings);')
    disp('----------------------------')
commandwindow
else
    close(NameInputFig);
    BpodErrorSound;
    msgbox('A settings file with this name exists. No entry made.', 'Modal')
end

function EditSettings(~,~)
global BpodSystem
SettingsNames = get(BpodSystem.GUIHandles.SettingsSelector, 'String');
SelectedSettingsIndex = get(BpodSystem.GUIHandles.SettingsSelector, 'Value');
SelectedSettingsName = SettingsNames{SelectedSettingsIndex};
ProtocolNames = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
SelectedProtocol = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
SelectedProtocolName = ProtocolNames{SelectedProtocol};
SubjectList = get(BpodSystem.GUIHandles.SubjectSelector,'String');
SubjectIndex = get(BpodSystem.GUIHandles.SubjectSelector,'Value');
SelectedSubjectName = SubjectList{SubjectIndex};
SettingsFile = fullfile(BpodSystem.Path.DataFolder, SelectedSubjectName, SelectedProtocolName, 'Session Settings', [SelectedSettingsName '.mat']);
BpodSystem.Path.Settings = SettingsFile;
evalin('base', ['load(''' SettingsFile ''')'])
clc
disp(' ')
disp('---EDIT SESSION SETTINGS---')
disp(['The settings file ' SelectedSettingsName '.mat is now a struct called "ProtocolSettings" in your workspace.'])
disp('Modify "ProtocolSettings" as desired, then run the following command to save your changes:')
disp('SaveProtocolSettings(ProtocolSettings);')
disp('----------------------------')
commandwindow

function EditProtocol(~,~)
global BpodSystem
ProtocolNames = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
SelectedProtocol = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
SelectedProtocolName = ProtocolNames{SelectedProtocol};
ProtocolPath = fullfile(BpodSystem.Path.ProtocolFolder, SelectedProtocolName, [SelectedProtocolName '.m']);
edit(ProtocolPath);

function DeleteSettings(~,~)
global BpodSystem
SettingsNames = get(BpodSystem.GUIHandles.SettingsSelector, 'String');
SelectedSettingsIndex = get(BpodSystem.GUIHandles.SettingsSelector, 'Value');
DefaultSettingsIndex = find(strcmp('DefaultSettings', SettingsNames));
SelectedSettingsName = SettingsNames{SelectedSettingsIndex};
ProtocolNames = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
SelectedProtocol = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
SelectedProtocolName = ProtocolNames{SelectedProtocol};
SubjectList = get(BpodSystem.GUIHandles.SubjectSelector,'String');
SubjectIndex = get(BpodSystem.GUIHandles.SubjectSelector,'Value');
SelectedSubjectName = SubjectList{SubjectIndex};
SettingsFile = fullfile(BpodSystem.Path.DataFolder, SelectedSubjectName, SelectedProtocolName, 'Session Settings', [SelectedSettingsName '.mat']);
if SelectedSettingsIndex ~= DefaultSettingsIndex
    DeleteFig = figure('Position',[550 600 350 150],'name','Delete settings file','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
    Warning = uicontrol('Style', 'text', 'String', ['Warning! This will delete the settings file: ' SelectedSettingsName '.mat!'], 'Position', [1 110 350 30], 'FontWeight', 'bold', 'FontSize', 8, 'BackgroundColor', [1 0 0]);
    BpodErrorSound;
    IntentCheck = uicontrol('Style', 'checkbox', 'String', ['I really want to do this'], 'Position', [75 50 200 30], 'FontWeight', 'bold', 'FontSize', 8);
    ZapButton = uicontrol('Style', 'togglebutton', 'String', ['Ok'], 'Position', [125 10 100 30], 'FontWeight', 'bold', 'FontSize', 8);
    waitfor(ZapButton, 'Value')
    OkToDelete = 0;
    try
        OkToDelete = sum(get(IntentCheck, 'Value') == 1);
    catch
    end
    if (OkToDelete == 1)
        close(DeleteFig);
        delete(SettingsFile);
        set(BpodSystem.GUIHandles.SettingsSelector,'Value',1);
        loadSettings(SelectedProtocolName, SelectedSubjectName);
    end
end

function DeleteProtocol(~,~)
global BpodSystem
ProtocolNames = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
SelectedProtocol = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
SelectedProtocolName = ProtocolNames{SelectedProtocol};
ProtocolPath = fullfile(BpodSystem.Path.ProtocolFolder, SelectedProtocolName);
if SelectedProtocol ~= 1
    DeleteFig = figure('Position',[550 600 350 150],'name','Delete protocol','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
    Warning = uicontrol('Style', 'text', 'String', ['Warning! The protocol ' SelectedProtocolName ' will be permanently deleted!'], 'Position', [1 110 350 30], 'FontWeight', 'bold', 'FontSize', 8, 'BackgroundColor', [1 0 0]);
    BpodErrorSound;
    BackupCheck = uicontrol('Style', 'checkbox', 'String', ['I have backed up necessary files'], 'Position', [75 80 200 30], 'FontWeight', 'bold', 'FontSize', 8);
    IntentCheck = uicontrol('Style', 'checkbox', 'String', ['I really want to do this'], 'Position', [75 50 200 30], 'FontWeight', 'bold', 'FontSize', 8);
    ZapButton = uicontrol('Style', 'togglebutton', 'String', ['Ok'], 'Position', [125 10 100 30], 'FontWeight', 'bold', 'FontSize', 8);
    waitfor(ZapButton, 'Value')
    OkToDelete = 0;
    try
        OkToDelete = sum(get(BackupCheck, 'Value') + get(IntentCheck, 'Value') == 2);
    catch
    end
    close(DeleteFig);
    if ((OkToDelete == 1) && (~isempty(SelectedProtocolName)))
        rmdir(ProtocolPath, 's');
        set(BpodSystem.GUIHandles.ProtocolSelector,'Value',1);
        loadProtocols
    end
end

function DeleteSubject(~,~)
global BpodSystem
ProtocolNameList = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
ProtocolSelected = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
ProtocolName = ProtocolNameList{ProtocolSelected};
NameList = get(BpodSystem.GUIHandles.SubjectSelector, 'String');
Selected = get(BpodSystem.GUIHandles.SubjectSelector, 'Value');
if Selected > 1
    if iscell(NameList)
        SelectedName = NameList{Selected};
    else
        SelectedName = NameList;
    end
    DeleteFig = figure('Position',[550 600 350 150],'name','Delete test subject','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
    Warning = uicontrol('Style', 'text', 'String', ['Warning! This will delete all data and settings associated with the ' ProtocolName ' protocol for test subject ' SelectedName '!'], 'Position', [1 110 350 30], 'FontWeight', 'bold', 'FontSize', 8, 'BackgroundColor', [1 0 0]);
    BpodErrorSound;
    BackupCheck = uicontrol('Style', 'checkbox', 'String', ['I have backed up necessary files'], 'Position', [75 80 200 30], 'FontWeight', 'bold', 'FontSize', 8);
    IntentCheck = uicontrol('Style', 'checkbox', 'String', ['I really want to do this'], 'Position', [75 50 200 30], 'FontWeight', 'bold', 'FontSize', 8);
    ZapButton = uicontrol('Style', 'togglebutton', 'String', ['Ok'], 'Position', [125 10 100 30], 'FontWeight', 'bold', 'FontSize', 8);
    waitfor(ZapButton, 'Value')
    OkToDelete = 0;
    try
        OkToDelete = sum(get(BackupCheck, 'Value') + get(IntentCheck, 'Value') == 2);
    catch
    end
    if ((OkToDelete == 1) && (~isempty(SelectedName)))
        DeletePath = fullfile(BpodSystem.Path.DataFolder,SelectedName, ProtocolName);
        rmdir(DeletePath,'s')
        RootPath = fullfile(BpodSystem.Path.DataFolder,SelectedName);
        Contents = dir(RootPath);
        if length(Contents) == 2
            rmdir(RootPath,'s');
        end
        BpodErrorSound;
        msgbox(['       Test subject ' SelectedName ' unregistered!'], 'Modal');
        close(DeleteFig);
        Pos = find(strcmp(SelectedName, NameList));
        NameList = NameList([1:Pos-1 Pos+1:length(NameList)]);
        set(BpodSystem.GUIHandles.SubjectSelector, 'String', NameList);
        set(BpodSystem.GUIHandles.SubjectSelector, 'Value', 1);
    else
        BpodErrorSound;
        msgbox('           Data NOT changed.', 'Modal');
        try
            close(DeleteFig);
        catch
        end
    end
else
    msgbox('The default subject cannot be deleted.');
    BpodErrorSound;
end

function ImportSettings(~,~)
global BpodSystem
ProtocolNames = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
SelectedProtocol = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
if ~iscell(ProtocolNames)
    Temp{1} = ProtocolNames;
    ProtocolNames = Temp;
end
SelectedProtocolName = ProtocolNames{SelectedProtocol};
SubjectList = get(BpodSystem.GUIHandles.SubjectSelector,'String');
SubjectIndex = get(BpodSystem.GUIHandles.SubjectSelector,'Value');
SelectedSubjectName = SubjectList{SubjectIndex};
SearchStartPath = BpodSystem.Path.DataFolder;
[Filename Pathname Junk] = uigetfile('*.mat', 'Select settings file to import', SearchStartPath);
SettingsName = Filename(1:(length(Filename)-4));
TargetSettingsPath = [Pathname Filename];
if ~exist(TargetSettingsPath)
    error(['Settings file not found for ' SettingsName])
end
DestinationSettingsPath = fullfile(BpodSystem.Path.DataFolder,SelectedSubjectName,SelectedProtocolName,'Session Settings',[ SettingsName '.mat']);
if (exist(DestinationSettingsPath) == 2)
    msgbox(['"' SettingsName '"' ' already exists in the target folder. Import aborted.'])
    BpodErrorSound
end

% Copy files
copyfile(TargetSettingsPath, DestinationSettingsPath);

% Update UI with new settings
loadSettings(SelectedProtocolName, SelectedSubjectName);

function LaunchProtocol(~,~)
global BpodSystem
ProtocolList = get(BpodSystem.GUIHandles.ProtocolSelector, 'String');
SelectedProtocol = get(BpodSystem.GUIHandles.ProtocolSelector, 'Value');
ProtocolName = ProtocolList{SelectedProtocol};
SubjectList = get(BpodSystem.GUIHandles.SubjectSelector,'String');
SubjectIndex = get(BpodSystem.GUIHandles.SubjectSelector,'Value');
SubjectName = SubjectList{SubjectIndex};
SettingsList = get(BpodSystem.GUIHandles.SettingsSelector, 'String');
SettingsIndex = get(BpodSystem.GUIHandles.SettingsSelector,'Value');
SettingsName = SettingsList{SettingsIndex};
SettingsFileName = fullfile(BpodSystem.Path.DataFolder, SubjectName, ProtocolName, 'Session Settings', [SettingsName '.mat']);
ProtocolFileName = fullfile(BpodSystem.Path.ProtocolFolder, ProtocolName, [ProtocolName '.m']);
DataFolder = fullfile(BpodSystem.Path.DataFolder,SubjectName,ProtocolName,'Session Data');
if ~exist(DataFolder)
    mkdir(DataFolder);
end
BpodSystem.Status.Live = 1;
BpodSystem.GUIData.ProtocolName = ProtocolName;
BpodSystem.GUIData.SubjectName = SubjectName;
BpodSystem.GUIData.SettingsFileName = SettingsFileName;
BpodSystem.Path.Settings = SettingsFileName;
SettingStruct = load(BpodSystem.Path.Settings);
F = fieldnames(SettingStruct);
FieldName = F{1};
BpodSystem.ProtocolSettings = eval(['SettingStruct.' FieldName]);
BpodSystem.Data = struct;
ProtocolPath = fullfile(BpodSystem.Path.ProtocolFolder,ProtocolName,[ProtocolName '.m']);
addpath(ProtocolPath);
set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton, 'TooltipString', 'Press to pause session');
BpodSystem.Status.BeingUsed = 1;
BpodSystem.ProtocolStartTime = now*100000;
close(BpodSystem.GUIHandles.LaunchManagerFig);
run(ProtocolPath);

function OutputString = Spaces2Underscores(InputString)
SpaceIndexes = InputString == ' ';
InputString(SpaceIndexes) = '_';
OutputString = InputString;

function CloseLaunchManager(~,~)
global BpodSystem
close(BpodSystem.GUIHandles.LaunchManagerFig);