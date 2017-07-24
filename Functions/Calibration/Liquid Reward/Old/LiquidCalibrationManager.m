%{
----------------------------------------------------------------------------

This file is part of the Bpod Project
Copyright (C) 2014 Joshua I. Sanders, Cold Spring Harbor Laboratory, NY, USA

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
function varargout = LiquidCalibrationManager(varargin)
% LIQUIDCALIBRATIONMANAGER M-file for LiquidCalibrationManager.fig
%      LIQUIDCALIBRATIONMANAGER, by itself, creates a new LIQUIDCALIBRATIONMANAGER or raises the existing
%      singleton*.
%
%      H = LIQUIDCALIBRATIONMANAGER returns the handle to a new LIQUIDCALIBRATIONMANAGER or the handle to
%      the existing singleton*.
%
%      LIQUIDCALIBRATIONMANAGER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in LIQUIDCALIBRATIONMANAGER.M with the given input arguments.
%
%      LIQUIDCALIBRATIONMANAGER('Property','Value',...) creates a new LIQUIDCALIBRATIONMANAGER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before LiquidCalibrationManager_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to LiquidCalibrationManager_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help LiquidCalibrationManager

% Last Modified by GUIDE v2.5 30-Dec-2015 13:11:18

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @LiquidCalibrationManager_OpeningFcn, ...
    'gui_OutputFcn',  @LiquidCalibrationManager_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before LiquidCalibrationManager is made visible.
function LiquidCalibrationManager_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to LiquidCalibrationManager (see VARARGIN)
if ~isfield(handles, 'PendingMeasurements') % The OpeningFcn is being called for the first time (is also called whenever handles are imported to another function. WTF, MATLAB???)
    ha = axes('units','normalized', 'position',[0 0 1 1]);
    uistack(ha,'bottom');
    BG = imread('RewardCalMain.bmp');
    image(BG); axis off;
    AddAnimalButtonGFX = imread('PlusButton.bmp');
    DelAnimalButtonGFX = imread('MinusButton.bmp');
    set(handles.pushbutton1, 'CData', AddAnimalButtonGFX);
    set(handles.pushbutton2, 'CData', DelAnimalButtonGFX);
    set(gcf, 'DockControls', 'off');
    handles.PendingMeasurements = cell(1,8);
    % Load existing liquid cal into handles structure
    CalibrationFilePath = fullfile(BpodSystem.Path.BpodRoot, 'Calibration Files', 'LiquidCalibration.mat');
    if exist(CalibrationFilePath) ~= 2
        % Calibration files were not found. Load template.
        CalibrationFilePath = fullfile(BpodPath, 'Bpod System Files', 'Main Functions', 'LiquidCalibrator', 'CalibrationFileTemplate.mat');
    end
    load(CalibrationFilePath);
    handles.LiquidCal = LiquidCal;
    if ~isfield(handles.LiquidCal(1), 'CalibrationTargetRange')
        handles.LiquidCal(1).CalibrationTargetRange = [2 50];
    end
    
    % Choose default command line output for LiquidCalibrationManager
    handles.output = hObject;
    
    % Update handles structure
    guidata(hObject, handles);
    
    % Display valve 1's entries
    DisplayValveEntries(1, hObject, handles);
    
end


% --- Outputs from this function are returned to the command line.
function varargout = LiquidCalibrationManager_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on selection change in listbox1.
function listbox1_Callback(hObject, eventdata, handles)
% hObject    handle to listbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox1
CurrentValve = get(handles.listbox1, 'Value');
if size(CurrentValve > 1) % If multiselect mode, show first valve in selection
    CurrentValve = CurrentValve(1);
end
DisplayValveEntries(CurrentValve, hObject, handles)

% --- Executes during object creation, after setting all properties.
function listbox1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in listbox2.
function listbox2_Callback(hObject, eventdata, handles)
% hObject    handle to listbox2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox2 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox2


% --- Executes during object creation, after setting all properties.
function listbox2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to listbox2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton1.
function pushbutton1_Callback(hObject, eventdata, handles)
global Measurement2add 
% pushbutton1 adds a calibration entry to a specific valve.
ThisValveCalEntries = get(handles.listbox2,'String');
CurrentValve = get(handles.listbox1, 'Value');
nValvesSelected = length(CurrentValve);
CurrentValveShown = CurrentValve(1);
if ~iscell(ThisValveCalEntries)
    nEntries = 0;
    TempEntry = ThisValveCalEntries;
    ThisValveCalEntries = cell(1,1);
    ThisValveCalEntries{1} = TempEntry;
elseif strcmp(ThisValveCalEntries{1}, 'No calibration measurements found.')
    nEntries = 0;
else
    nEntries = length(ThisValveCalEntries);
end
handles.ValueEntryFig = figure('Position', [540 400 400 200],'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off' );
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('RewardCalEnterValue.bmp');
image(BG); axis off;
handles.AmountEntry = uicontrol('Style', 'edit', 'String', '0', 'Position', [75 15 115 50], 'FontWeight', 'bold', 'FontSize', 20);
CalOkButtonGFX = imread('CalOkButton.bmp');
OkButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [250 15 80 50], 'Callback', 'AddPendingMeasurement', 'CData', CalOkButtonGFX, 'TooltipString', 'Confirm entry');
guidata(hObject, handles);
uiwait(gcf);
Value2measure = Measurement2add;
if ~isnan(Value2measure)
    Exists = 0;
    for x = 1:nValvesSelected
        % Check to make sure value doesn't already exist in pending measurements
        Pending = handles.PendingMeasurements{CurrentValve(x)};
        if ~isempty(Pending)
            if sum(Pending == Value2measure) > 0
                Exists = 1;
            end
        end
        % Check to make sure value doesn't already exist in table
        ValveData = handles.LiquidCal(CurrentValve(x)).Table;
        if ~isempty(ValveData)
            ValuesPresent = ValveData(1,:);
            if sum(Value2measure == ValuesPresent) > 0
                Exists = 1;
            end
        end
    end
    if Exists == 0
        for x = 1:nValvesSelected
            handles.PendingMeasurements{CurrentValve(x)} = [handles.PendingMeasurements{CurrentValve(x)} Value2measure];
        end
        ThisValveCalEntries{nEntries+1} = ['<html><FONT COLOR="#ff0000">**PENDING MEASUREMENT: ' num2str(Value2measure) 'ms</FONT></html>'];
    else
        warndlg(['A measurement for ' num2str(Value2measure) 'ms exists. Please delete it first.'], 'Error', 'modal');
    end
end
set(handles.listbox2,'String',ThisValveCalEntries);
guidata(hObject, handles);
clearvars -global Measurement2add
% --- Executes on button press in pushbutton2.
function pushbutton2_Callback(hObject, eventdata, handles)
global BpodSystem
% This button removes a calibration entry.

CurrentValve = get(handles.listbox1, 'Value');
ThisValveCalEntries = get(handles.listbox2,'String');
if ~iscell(ThisValveCalEntries)
    TempEntry = ThisValveCalEntries;
    ThisValveCalEntries = cell(1,1);
    ThisValveCalEntries{1} = TempEntry;
end
SelectedEntry = get(handles.listbox2,'Value');
SelectedEntryText = ThisValveCalEntries{SelectedEntry};
isPendingMeasurement = 0;
if SelectedEntryText(1) == '<'
    isPendingMeasurement = 1;
    % remove pending measurement and skip subsequent script to remove table
    % values
    ValveData = handles.LiquidCal(CurrentValve).Table;
    [nActualMeasurements trash] = size(ValveData);
    PendingEntryIndex = SelectedEntry - nActualMeasurements;
    CurrentValvePendingMeasurements = handles.PendingMeasurements{CurrentValve};
    nPendingEntries = length(CurrentValvePendingMeasurements);
    if nPendingEntries > 1
        if PendingEntryIndex > 1
            Entries_pre = CurrentValvePendingMeasurements(1:(PendingEntryIndex-1));
        else
            Entries_pre = [];
        end
        if PendingEntryIndex < nPendingEntries
            Entries_post = CurrentValvePendingMeasurements(PendingEntryIndex+1:nPendingEntries);
        else
            Entries_post = [];
        end
        handles.PendingMeasurements{CurrentValve} = [Entries_pre Entries_post];
    else
        handles.PendingMeasurements{CurrentValve} = [];
    end
end
ThisValveCalEntries = ThisValveCalEntries(~ismember(ThisValveCalEntries,SelectedEntryText));
[nEntries,Trash] = size(ThisValveCalEntries);
if SelectedEntry > nEntries
    set(handles.listbox2, 'Value', SelectedEntry-1);
end
if isempty(ThisValveCalEntries)
    ThisValveCalEntries{1} = 'No calibration measurements found.';
    set(handles.listbox2, 'Value', 1);
end
set(handles.listbox2,'String',ThisValveCalEntries);
if isPendingMeasurement == 0
    % Remove entry from calibration table copy in handles struct
    ValveData = handles.LiquidCal(CurrentValve).Table;
    Coeff = handles.LiquidCal(CurrentValve).Coeffs;
    [nMeasurements trash] = size(ValveData);
    if nMeasurements > 1
        Vtemp_pre = ValveData(1:SelectedEntry-1,1:2);
        if SelectedEntry < nMeasurements
            Vtemp_post = ValveData(SelectedEntry+1:nMeasurements,1:2);
        else
            Vtemp_post = [];
        end
        ValveData = [Vtemp_pre; Vtemp_post];
        % Recalculate trinomial coeffs
        handles.LiquidCal(CurrentValve).Table = ValveData;
        warning off % To suppress warnings about fits with 3 datapoints
        if nMeasurements > 1
            handles.LiquidCal(CurrentValve).Coeffs = polyfit(handles.LiquidCal(CurrentValve).Table(:,2),handles.LiquidCal(CurrentValve).Table(:,1),2);
        else
            handles.LiquidCal(CurrentValve).Coeffs = [];
        end
        warning on
        % Move selected value in listbox if that value no longer exists
        if SelectedEntry > nMeasurements
            set(handles.listbox2, 'Value', nMeasurements);
        elseif SelectedEntry == nMeasurements
            set(handles.listbox2, 'Value', nMeasurements-1);
        end
    else
        handles.LiquidCal(CurrentValve).Table = [];
        handles.LiquidCal(CurrentValve).Coeffs = [];
    end
end
guidata(hObject, handles);
% Save file
TestSavePath = fullfile(BpodSystem.Path.BpodRoot, 'Calibration Files');
if exist(TestSavePath) ~= 7
    mkdir(TestSavePath);
end
SavePath = fullfile(BpodPath, 'Calibration Files', 'LiquidCalibration.mat');
LiquidCal = handles.LiquidCal;
LiquidCal(1).LastDateModified = now;
save(SavePath, 'LiquidCal');
% --------------------------------------------------------------------
function CommandMenu_Callback(hObject, eventdata, handles)
% hObject    handle to CommandMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function RunPendingMeasurements_Callback(hObject, eventdata, handles)
% hObject    handle to RunPendingMeasurements (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Create a vector of measurements to test
ValveIDs = [];
PulseDurations = [];
for x = 1:8
    if ~isempty(handles.PendingMeasurements{x})
        ValveIDs = [ValveIDs x];
        PulseDurations = [PulseDurations (handles.PendingMeasurements{x}(1))/1000];
    end
end
nValidMeasurements = length(ValveIDs);
if ~isempty(ValveIDs)
    % Deliver liquid
    k = msgbox('Please refill liquid reservoirs and click Ok to begin.', 'modal');
    waitfor(k);
    LiquidRewardCal(str2double(handles.nPulses_edit.String), ValveIDs, PulseDurations, .2)
    
    % Enter measurements:
    
    % Set up window
    handles.RunMeasurementsFig = figure('Position', [540 300 317 530],'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off', 'Name', 'Enter pending measurements');
    ha = axes('units','normalized', 'position',[0 0 1 1]);
    uistack(ha,'bottom');
    BG = imread('CuedMeasurementEntry.bmp');
    image(BG); axis off;
    handles.CB1b = uicontrol('Style', 'edit', 'Position', [155 379 80 35], 'TooltipString', 'Enter liquid weight for valve 1', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
    handles.CB2b = uicontrol('Style', 'edit', 'Position', [155 336 80 35], 'TooltipString', 'Enter liquid weight for valve 2', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
    handles.CB3b = uicontrol('Style', 'edit', 'Position', [155 293 80 35], 'TooltipString', 'Enter liquid weight for valve 3', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
    handles.CB4b = uicontrol('Style', 'edit', 'Position', [155 250 80 35], 'TooltipString', 'Enter liquid weight for valve 4', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
    handles.CB5b = uicontrol('Style', 'edit', 'Position', [155 207 80 35], 'TooltipString', 'Enter liquid weight for valve 5', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
    handles.CB6b = uicontrol('Style', 'edit', 'Position', [155 164 80 35], 'TooltipString', 'Enter liquid weight for valve 6', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
    handles.CB7b = uicontrol('Style', 'edit', 'Position', [155 121 80 35], 'TooltipString', 'Enter liquid weight for valve 7', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
    handles.CB8b = uicontrol('Style', 'edit', 'Position', [155 78 80 35], 'TooltipString', 'Enter liquid weight for valve 8', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
    MeasurementButtonGFX2 = imread('MeasurementEntryOkButtonBG.bmp');
    handles.EnterMeasurementButton2 = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [120 7 80 50], 'Callback', 'EnterCalMeasurements', 'TooltipString', 'Enter measurement', 'CData', MeasurementButtonGFX2);
    
    % Prompt for each valid measurement in order, un-hiding the GUI box and
    % displaying a cursor triangle on the correct row
    for y = 1:8
        if isempty(find(y == ValveIDs))
            eval(['set(handles.CB' num2str(y) 'b, ''Enable'', ''off'')'])
        else
            eval(['set(handles.CB' num2str(y) 'b, ''Enable'', ''on'', ''BackgroundColor'', [.6 .9 .6])'])
        end
    end
    guidata(hObject, handles);
    drawnow;
end

% --------------------------------------------------------------------
function AddRecommendedMeasurements_Callback(hObject, eventdata, handles)
% hObject    handle to RunPendingMeasurements (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.RecommendedMeasureFig = figure('Position', [540 400 400 200],'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off' );
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('RewardCalAddRecommends.bmp');
image(BG); axis off;
handles.CB1 = uicontrol('Style', 'checkbox', 'Position', [13 140 15 15]);
handles.CB2 = uicontrol('Style', 'checkbox', 'Position', [64 140 15 15]);
handles.CB3 = uicontrol('Style', 'checkbox', 'Position', [116 140 15 15]);
handles.CB4 = uicontrol('Style', 'checkbox', 'Position', [168 140 15 15]);
handles.CB5 = uicontrol('Style', 'checkbox', 'Position', [220 140 15 15]);
handles.CB6 = uicontrol('Style', 'checkbox', 'Position', [271 140 15 15]);
handles.CB7 = uicontrol('Style', 'checkbox', 'Position', [324 140 15 15]);
handles.CB8 = uicontrol('Style', 'checkbox', 'Position', [375 140 15 15]);

if ~isempty(handles.LiquidCal(1).Table);
    set(handles.CB1, 'Value', 1);
end
if ~isempty(handles.LiquidCal(2).Table);
    set(handles.CB2, 'Value', 1);
end
if ~isempty(handles.LiquidCal(3).Table);
    set(handles.CB3, 'Value', 1);
end
if ~isempty(handles.LiquidCal(4).Table);
    set(handles.CB4, 'Value', 1);
end
if ~isempty(handles.LiquidCal(5).Table);
    set(handles.CB5, 'Value', 1);
end
if ~isempty(handles.LiquidCal(6).Table);
    set(handles.CB6, 'Value', 1);
end
if ~isempty(handles.LiquidCal(7).Table);
    set(handles.CB7, 'Value', 1);
end
if ~isempty(handles.LiquidCal(8).Table);
    set(handles.CB8, 'Value', 1);
end
handles.LowRangeEdit = uicontrol('Style', 'edit', 'String', '2', 'Position', [248 71 35 30], 'FontWeight', 'bold', 'FontSize', 12, 'TooltipString', 'Enter a non-zero value for range minimum');
handles.HighRangeEdit = uicontrol('Style', 'edit', 'String', '50', 'Position', [329 71 35 30], 'FontWeight', 'bold', 'FontSize', 12, 'TooltipString', 'Enter a non-zero value for range maximum');
set(handles.LowRangeEdit, 'String', num2str(handles.LiquidCal(1).CalibrationTargetRange(1)));
set(handles.HighRangeEdit, 'String', num2str(handles.LiquidCal(1).CalibrationTargetRange(2)));
SuggestButtonGFX = imread('SuggestButton.bmp');
SuggestButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [150 10 120 50], 'Callback', 'AddSuggestions', 'CData', SuggestButtonGFX, 'TooltipString', 'Confirm');


guidata(hObject, handles);
% uiwait(gcf);
% Value2measure = Measurement2add;

% --------------------------------------------------------------------
function TestSpecificAmount_Callback(hObject, eventdata, handles)
% hObject    handle to TestSpecificAmount (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.TestSpecificAmtFig = figure('Position', [540 300 400 600],'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off', 'Name', 'Test specific amount');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('SpecificAmountEntry.bmp');
image(BG); axis off;
handles.CB1b = uicontrol('Style', 'checkbox', 'Position', [13 535 15 15], 'TooltipString', 'Test valve 1');
handles.CB2b = uicontrol('Style', 'checkbox', 'Position', [64 535 15 15], 'TooltipString', 'Test valve 2');
handles.CB3b = uicontrol('Style', 'checkbox', 'Position', [116 535 15 15], 'TooltipString', 'Test valve 3');
handles.CB4b = uicontrol('Style', 'checkbox', 'Position', [168 535 15 15], 'TooltipString', 'Test valve 4');
handles.CB5b = uicontrol('Style', 'checkbox', 'Position', [220 535 15 15], 'TooltipString', 'Test valve 5');
handles.CB6b = uicontrol('Style', 'checkbox', 'Position', [271 535 15 15], 'TooltipString', 'Test valve 6');
handles.CB7b = uicontrol('Style', 'checkbox', 'Position', [324 535 15 15], 'TooltipString', 'Test valve 7');
handles.CB8b = uicontrol('Style', 'checkbox', 'Position', [375 535 15 15], 'TooltipString', 'Test valve 8');

if ~isempty(handles.LiquidCal(1).Table);
    set(handles.CB1b, 'Value', 1);
end
if ~isempty(handles.LiquidCal(2).Table);
    set(handles.CB2b, 'Value', 1);
end
if ~isempty(handles.LiquidCal(3).Table);
    set(handles.CB3b, 'Value', 1);
end
if ~isempty(handles.LiquidCal(4).Table);
    set(handles.CB4b, 'Value', 1);
end
if ~isempty(handles.LiquidCal(5).Table);
    set(handles.CB5b, 'Value', 1);
end
if ~isempty(handles.LiquidCal(6).Table);
    set(handles.CB6b, 'Value', 1);
end
if ~isempty(handles.LiquidCal(7).Table);
    set(handles.CB7b, 'Value', 1);
end
if ~isempty(handles.LiquidCal(8).Table);
    set(handles.CB8b, 'Value', 1);
end
handles.SpecificAmtEdit = uicontrol('Style', 'edit', 'String', '0', 'Position', [256 478 40 25], 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
handles.nPulsesDropmenu = uicontrol('Style', 'popupmenu', 'String', {'100' '150' '200'}, 'Position', [289 447 50 25], 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9], 'TooltipString', 'Use more pulses with small water volumes for improved accuracy');
handles.ToleranceDropmenu = uicontrol('Style', 'popupmenu', 'String', {'5' '10'}, 'Position', [289 416 50 25], 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9], 'TooltipString', 'Percent of intended amount by which measured amount can differ');
handles.ResultsListbox = uicontrol('Style', 'listbox', 'String', {''}, 'Position', [25 28 355 130], 'FontWeight', 'bold', 'FontSize', 10, 'BackgroundColor', [.85 .85 .85], 'SelectionHighlight', 'off');

jScrollPane = findjobj(handles.ResultsListbox); % get the scroll-pane object
jListbox = jScrollPane.getViewport.getComponent(0);
set(jListbox, 'SelectionBackground',[.85 .85 .85]);

DeliverButtonGFX = imread('TestDeliverButton.bmp');
handles.DeliverButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [40 300 325 50], 'Callback', 'DeliverSpecificAmt;', 'TooltipString', 'Start liquid delivery', 'CData', DeliverButtonGFX);
handles.MeasuredAmtEdit = uicontrol('Style', 'edit', 'String', '---', 'Position', [202 238 55 30], 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.88 .88 .88], 'Enable', 'off');
handles.MeasuredValveText = uicontrol('Style', 'edit', 'String', '1', 'Position', [123 238 55 30], 'FontWeight', 'bold', 'FontSize', 14, 'enable', 'off', 'BackgroundColor', [.85 .85 .85]);
MeasurementButtonGFX = imread('NextMeasurement.bmp');
handles.EnterMeasurementButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [295 233 60 40], 'Callback', 'EnterTestCalMeasurement', 'TooltipString', 'Enter measurement', 'CData', MeasurementButtonGFX);
guidata(hObject, handles);
% --------------------------------------------------------------------
function ViewCalibrationCurves_Callback(hObject, eventdata, handles)

% Make a list of all valves with calibration data to plot
ValveData = handles.LiquidCal;
[Trash, nValves] = size(ValveData);
nValidValves = 0;
for x = 1:nValves
    if ~isempty(ValveData(x).Table)
        nValidValves = nValidValves + 1;
        ValveList(nValidValves) = x;
    end
end
if nValidValves > 0
    CalFig = figure('Name', 'Valve Calibration Curve-fits','numbertitle','off', 'MenuBar', 'none');
    switch nValidValves
        case 1
            set(CalFig, 'Position', [150 200 600 450]);
        case 2
            set(CalFig, 'Position', [150 200 1200 450]);
        case 3
            set(CalFig, 'Position', [150 200 1200 400]);
        case 4
            set(CalFig, 'Position', [50 278 1200 300]);
        case 5
            set(CalFig, 'Position', [50 278 1200 200]);
        case 6
            set(CalFig, 'Position', [50 378 1200 200]);
        case 7
            set(CalFig, 'Position', [50 378 1200 200]);
        case 8
            set(CalFig, 'Position', [50 378 1200 150]);
    end
    Xincrement = (1/nValidValves);
    if nValidValves > 5
        Xsize = (1/nValidValves)*.5;
        Xoffset = .05;
        Yoffset = .3; Ysize = .5;
    elseif nValidValves > 2
        Xsize = (1/nValidValves)*.6;
        Xoffset = .07;
        Yoffset = .2; Ysize = .6;
    elseif nValidValves == 2
        Xsize = (1/nValidValves)*.7;
        Xoffset = .08;
        Yoffset = .12; Ysize = .75;
    else
        Xsize = (1/nValidValves)*.8;
        Xoffset = .12;
        Yoffset = .12; Ysize = .75;
    end
    Xpositions = (Xoffset:Xincrement:1);
    for x = 1:nValidValves
        subplot('Position',[Xpositions(x) Yoffset Xsize Ysize]);
        p = ValveData(ValveList(x)).Coeffs;
        if ~isempty(p)
            Vector = polyval(p,0:.1:150);
            plot(Vector, 0:.1:150, 'k-', 'LineWidth', 1.5);
        end
        title(['Valve ' num2str(ValveList(x))], 'FontWeight', 'bold', 'FontSize', 12)
        hold on
        scatter(ValveData(ValveList(x)).Table(:,1), ValveData(ValveList(x)).Table(:,2), 'LineWidth', 2)
        set(gca, 'tickdir', 'out', 'box', 'off');
        Ymax = max(ValveData(ValveList(x)).Table(:,2))+.1*max(ValveData(ValveList(x)).Table(:,2));
        % Add pending measurement datapoints
        PendingMeasurements = handles.PendingMeasurements{ValveList(x)};
        if ~isempty(PendingMeasurements)
            nPendingMeasurements = length(PendingMeasurements);
            for y = 1:nPendingMeasurements
                line([PendingMeasurements(y) PendingMeasurements(y)],[0 Ymax], 'Color', 'r', 'LineStyle', ':')
            end
        end
        if Ymax > 0
            set(gca, 'YLim', [0 Ymax]);
        else
            set(gca, 'YLim', [0 1]);
        end
        MaxPlotX = max(ValveData(ValveList(x)).Table(:,1)) + min(ValveData(ValveList(x)).Table(:,1));
        set(gca, 'XLim', [0 MaxPlotX]);
        set(get(gca, 'Ylabel'), 'String', 'Liquid delivered (ul)');
        set(get(gca, 'Xlabel'), 'String', 'Valve duration (ms)');
    end
else
    warndlg('No calibration data available to plot', 'Error', 'modal');
end


function DisplayValveEntries(ValveToShow, hObject, handles)

ValveData = handles.LiquidCal(ValveToShow).Table;
[nMeasurements trash] = size(ValveData);
if isempty(ValveData)
    ThisValveCalEntries = cell(1,1);
    nMeasurements = 1;
    if isempty(handles.PendingMeasurements{ValveToShow})
        ThisValveCalEntries{1} =  'No calibration measurements found.';
        set(handles.listbox2,'Value', 1)
    else
        for x = 1:length(handles.PendingMeasurements{ValveToShow})
            ThisValveCalEntries{x} = ['<html><FONT COLOR="#ff0000">**PENDING MEASUREMENT: '  num2str(handles.PendingMeasurements{ValveToShow}(x)) 'ms</FONT></html>'];
        end
    end
else
    for x = 1:nMeasurements
        Pad = '';
        if ValveData(x,1) < 100
            Pad = [Pad '  '];
        end
        if ValveData(x,1) < 10
            Pad = [Pad '  '];
        end
        ThisValveCalEntries{x} = [num2str(ValveData(x,1)) 'ms pulse ' Pad '=  ' num2str(ValveData(x,2)) 'ul liquid'];
    end
    if ~isempty(handles.PendingMeasurements{ValveToShow})
        for x = 1:length(handles.PendingMeasurements{ValveToShow})
            ThisValveCalEntries{nMeasurements+x} = ['<html><FONT COLOR="#ff0000">**PENDING MEASUREMENT: '  num2str(handles.PendingMeasurements{ValveToShow}(x)) 'ms</FONT></html>'];
        end
    end
end
% If selected entry index exceeds total entries, set current highlighted
% entry to equal the last entry available
SelectedEntry = get(handles.listbox2,'Value');
if SelectedEntry == 0
    set(handles.listbox2,'Value', 1)
elseif SelectedEntry > nMeasurements
    set(handles.listbox2,'Value', nMeasurements)
end
set(handles.listbox2,'String',ThisValveCalEntries);

guidata(hObject, handles);



function nPulses_edit_Callback(hObject, eventdata, handles)
% hObject    handle to nPulses_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of nPulses_edit as text
%        str2double(get(hObject,'String')) returns contents of nPulses_edit as a double


% --- Executes during object creation, after setting all properties.
function nPulses_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to nPulses_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
