function varargout = OlfactometerConfig(varargin)
% OLFACTOMETERCONFIG M-file for OlfactometerConfig.fig
%      OLFACTOMETERCONFIG, by itself, creates a new OLFACTOMETERCONFIG or raises the existing
%      singleton*.
%
%      H = OLFACTOMETERCONFIG returns the handle to a new OLFACTOMETERCONFIG or the handle to
%      the existing singleton*.
%
%      OLFACTOMETERCONFIG('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in OLFACTOMETERCONFIG.M with the given input arguments.
%
%      OLFACTOMETERCONFIG('Property','Value',...) creates a new OLFACTOMETERCONFIG or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before OlfactometerConfig_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to OlfactometerConfig_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help OlfactometerConfig

% Last Modified by GUIDE v2.5 01-May-2011 21:28:48

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @OlfactometerConfig_OpeningFcn, ...
    'gui_OutputFcn',  @OlfactometerConfig_OutputFcn, ...
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


% --- Executes just before OlfactometerConfig is made visible.
function OlfactometerConfig_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to OlfactometerConfig (see VARARGIN)
global BpodSystem
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('OlfControlPanel.bmp');
image(BG); axis off;
if exist(fullfile(BpodSystem.Path.BpodRoot,'Bpod System Files','OlfConfig.mat'))
    load OlfConfig
else
    load OlfConfig_Template
    SavePath = fullfile(BpodPath,'Bpod System Files','OlfConfig.mat');
    save(SavePath, 'OlfConfig');
end
OlfServerIP = OlfConfig.OlfServerIP;
IPString = [num2str(OlfServerIP(1)) '.' num2str(OlfServerIP(2)) '.' num2str(OlfServerIP(3)) '.' num2str(OlfServerIP(4))];
set(handles.edit1, 'String', IPString);
Offset = OlfConfig.BankPairOffset;
switch Offset
    case 0
        set(handles.radiobutton1, 'Value', 1); set(handles.radiobutton2, 'Value', 0);  set(handles.radiobutton3, 'Value', 0);  set(handles.radiobutton4, 'Value', 0);
    case 2
        set(handles.radiobutton1, 'Value', 0); set(handles.radiobutton2, 'Value', 1);  set(handles.radiobutton3, 'Value', 0);  set(handles.radiobutton4, 'Value', 0);
    case 4
        set(handles.radiobutton1, 'Value', 0); set(handles.radiobutton2, 'Value', 0);  set(handles.radiobutton3, 'Value', 1);  set(handles.radiobutton4, 'Value', 0);
    case 6
        set(handles.radiobutton1, 'Value', 0); set(handles.radiobutton2, 'Value', 0);  set(handles.radiobutton3, 'Value', 0);  set(handles.radiobutton4, 'Value', 1);
end
Mbox = msgbox('     Attempting connection...', 'Modal');
BpodErrorSound;
OlfServerIP = OlfConfig.OlfServerIP;
IPString = [num2str(OlfServerIP(1)) '.' num2str(OlfServerIP(2)) '.' num2str(OlfServerIP(3)) '.' num2str(OlfServerIP(4))];
try
    Response = TCPWrite(IPString, 3336, 'NOOP');
    Response = strtrim(Response);
        if strcmp(Response, 'OK')
            k = 5;
        else 
            k = ckjhbskdbv;
        end
    set(handles.text1, 'String', 'Connected');
    set(handles.text1, 'BackgroundColor', [0 1 0]);
    set(handles.listbox1, 'Enable', 'on');
    set(handles.listbox2, 'Enable', 'on');
    set(handles.edit5, 'Enable', 'on');
    set(handles.edit6, 'Enable', 'on');
    set(handles.edit7, 'Enable', 'on');
    set(handles.edit8, 'Enable', 'on');
    handles.output = hObject;
    guidata(hObject, handles);
    Mbox = msgbox('              Connected!', 'Modal');
    pause(.5)
    close(Mbox)
catch
    Mbox = msgbox('  Connection error at previous IP. Searching for olfactometer...', 'Modal');
    BpodErrorSound;
    NewIP = FindOlfactometer;
    if ~isempty(NewIP)
        load OlfConfig
        IPString = NewIP;
        BinString = IPString ~= '.';
        Temp = '';
        FormattedIP = '';
        nSections = 0;
        for x = 1:length(IPString)
            if BinString(x) == 1
                Temp = [Temp IPString(x)];
            else
                nSections = nSections + 1;
                FormattedIP(nSections) = str2double(Temp);
                Temp = '';
            end
        end
        nSections = nSections + 1;
        FormattedIP(nSections) = str2double(Temp);
        Temp = '';
        FormattedIP = uint8(FormattedIP);
        OlfConfig.OlfServerIP = FormattedIP;
        SavePath = fullfile(BpodSystem.Path.BpodRoot,'Bpod System Files','OlfConfig.mat');
        save(SavePath, 'OlfConfig');
        Mbox = msgbox('       New IP address found and saved', 'Modal');
        pause(1);
        close(Mbox);
        BpodErrorSound;
        set(handles.text1, 'String', 'Disconnected');
        set(handles.text1, 'BackgroundColor', [1 0 0]);
        set(handles.listbox1, 'Enable', 'off');
        set(handles.listbox2, 'Enable', 'off');
        set(handles.edit5, 'Enable', 'off');
        set(handles.edit6, 'Enable', 'off');
        set(handles.edit7, 'Enable', 'off');
        set(handles.edit8, 'Enable', 'off');
        handles.output = hObject;
        guidata(hObject, handles);
        OlfServerIP = OlfConfig.OlfServerIP;
        IPString = [num2str(OlfServerIP(1)) '.' num2str(OlfServerIP(2)) '.' num2str(OlfServerIP(3)) '.' num2str(OlfServerIP(4))];
        try
            TCPWrite(IPString, 3336, 'NOOP');
            set(handles.text1, 'String', 'Connected');
            set(handles.text1, 'BackgroundColor', [0 1 0]);
            set(handles.listbox1, 'Enable', 'on');
            set(handles.listbox2, 'Enable', 'on');
            set(handles.edit5, 'Enable', 'on');
            set(handles.edit6, 'Enable', 'on');
            set(handles.edit7, 'Enable', 'on');
            set(handles.edit8, 'Enable', 'on');
            set(handles.edit1, 'String', IPString);
            handles.output = hObject;
            guidata(hObject, handles);
        catch
            msgbox('          Unable to connect.', 'Modal')
            BpodErrorSound;
        end
        
    else
        Mbox = msgbox('Automatic search failed. Try entering the IP manually.', 'Modal');
        BpodErrorSound;
    end
    
end
% Choose default command line output for OlfactometerConfig
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes OlfactometerConfig wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = OlfactometerConfig_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function edit1_Callback(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit1 as text
%        str2double(get(hObject,'String')) returns contents of edit1 as a double
global BpodSystem
load OlfConfig
IPString = get(handles.edit1, 'String');
BinString = IPString ~= '.';
Temp = '';
FormattedIP = '';
nSections = 0;
for x = 1:length(IPString)
    if BinString(x) == 1
        Temp = [Temp IPString(x)];
    else
        nSections = nSections + 1;
        FormattedIP(nSections) = str2double(Temp);
        Temp = '';
    end
end
nSections = nSections + 1;
FormattedIP(nSections) = str2double(Temp);
Temp = '';
FormattedIP = uint8(FormattedIP);
OlfConfig.OlfServerIP = FormattedIP;
SavePath = fullfile(BpodSystem.Path.BpodRoot,'Bpod System Files','OlfConfig.mat');
save(SavePath, 'OlfConfig');
msgbox('  Olfactometer IP saved. Attempting connection...', 'Modal')
BpodErrorSound;
set(handles.text1, 'String', 'Disconnected');
set(handles.text1, 'BackgroundColor', [1 0 0]);
set(handles.listbox1, 'Enable', 'off');
set(handles.listbox2, 'Enable', 'off');
set(handles.edit5, 'Enable', 'off');
set(handles.edit6, 'Enable', 'off');
set(handles.edit7, 'Enable', 'off');
set(handles.edit8, 'Enable', 'off');
handles.output = hObject;
guidata(hObject, handles);
OlfServerIP = OlfConfig.OlfServerIP;
IPString = [num2str(OlfServerIP(1)) '.' num2str(OlfServerIP(2)) '.' num2str(OlfServerIP(3)) '.' num2str(OlfServerIP(4))];
try
    TCPWrite(IPString, 3336, 'NOOP');
    set(handles.text1, 'String', 'Connected');
    set(handles.text1, 'BackgroundColor', [0 1 0]);
    set(handles.listbox1, 'Enable', 'on');
    set(handles.listbox2, 'Enable', 'on');
    set(handles.edit5, 'Enable', 'on');
    set(handles.edit6, 'Enable', 'on');
    set(handles.edit7, 'Enable', 'on');
    set(handles.edit8, 'Enable', 'on');
    handles.output = hObject;
    guidata(hObject, handles);
    msgbox('          Connected!', 'Modal')
catch
    msgbox('          Unable to connect.', 'Modal')
    BpodErrorSound;
end

% --- Executes during object creation, after setting all properties.
function edit1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
% --- Executes on selection change in listbox1.
function listbox1_Callback(hObject, eventdata, handles)
% hObject    handle to listbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns listbox1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from listbox1
SelectedValve1 = get(handles.listbox1, 'Value');
load OlfConfig
OlfServerIP = OlfConfig.OlfServerIP;
BankPairOffset = OlfConfig.BankPairOffset;
IPString = [num2str(OlfServerIP(1)) '.' num2str(OlfServerIP(2)) '.' num2str(OlfServerIP(3)) '.' num2str(OlfServerIP(4))];
try
    TCPWrite(IPString, 3336, ['WRITE Bank' num2str(1+BankPairOffset) ' ' num2str(SelectedValve1-1)]);
catch
    error('Connection Error!')
end

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
SelectedValve2 = get(handles.listbox2, 'Value');
load OlfConfig
OlfServerIP = OlfConfig.OlfServerIP;
BankPairOffset = OlfConfig.BankPairOffset;
IPString = [num2str(OlfServerIP(1)) '.' num2str(OlfServerIP(2)) '.' num2str(OlfServerIP(3)) '.' num2str(OlfServerIP(4))];
try
    TCPWrite(IPString, 3336, ['WRITE Bank' num2str(2+BankPairOffset) ' ' num2str(SelectedValve2-1)]);
catch
    error('Connection Error!')
end

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



function edit2_Callback(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit2 as text
%        str2double(get(hObject,'String')) returns contents of edit2 as a double


% --- Executes during object creation, after setting all properties.
function edit2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit3_Callback(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit3 as text
%        str2double(get(hObject,'String')) returns contents of edit3 as a double


% --- Executes during object creation, after setting all properties.
function edit3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit4_Callback(hObject, eventdata, handles)
% hObject    handle to edit4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit4 as text
%        str2double(get(hObject,'String')) returns contents of edit4 as a double


% --- Executes during object creation, after setting all properties.
function edit4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit5_Callback(hObject, eventdata, handles)
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit5 as text
%        str2double(get(hObject,'String')) returns contents of edit5 as a double

load OlfConfig
OlfServerIP = OlfConfig.OlfServerIP;
BankPairOffset = OlfConfig.BankPairOffset;
NewValue = get(handles.edit5, 'String');
if isnan(str2double(NewValue))
    msgbox('Error. Entry must be numeric.');
    BpodErrorSound;
else
    NewValue = str2double(NewValue);
    NewValue = ceil(NewValue);
    NewValue = abs(NewValue);
    if NewValue < 1
        NewValue = 1;
    end
    if NewValue > 100
        NewValue = 100;
    end
    set(handles.edit5, 'String', num2str(NewValue))
    handles.output = hObject;
    guidata(hObject, handles);
    IPString = [num2str(OlfServerIP(1)) '.' num2str(OlfServerIP(2)) '.' num2str(OlfServerIP(3)) '.' num2str(OlfServerIP(4))];
    try
        TCPWrite(IPString, 3336, ['WRITE BankFlow' num2str(1+BankPairOffset) '_Actuator ' num2str(NewValue)]);
    catch
        error('Connection Error!')
    end
end
% --- Executes during object creation, after setting all properties.
function edit5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit6_Callback(hObject, eventdata, handles)
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit6 as text
%        str2double(get(hObject,'String')) returns contents of edit6 as a double
load OlfConfig
OlfServerIP = OlfConfig.OlfServerIP;
NewValue = get(handles.edit6, 'String');
if isnan(str2double(NewValue))
    msgbox('Error. Entry must be numeric.');
    BpodErrorSound;
else
    NewValue = str2double(NewValue);
    NewValue = ceil(NewValue);
    NewValue = abs(NewValue);
    if NewValue < 100
        NewValue = 100;
    end
    if NewValue > 1000
        NewValue = 1000;
    end
    set(handles.edit8, 'String', num2str(NewValue))
    handles.output = hObject;
    guidata(hObject, handles);
    IPString = [num2str(OlfServerIP(1)) '.' num2str(OlfServerIP(2)) '.' num2str(OlfServerIP(3)) '.' num2str(OlfServerIP(4))];
    try
        TCPWrite(IPString, 3336, ['WRITE Carrier4_Actuator ' num2str(NewValue)]);
    catch
        error('Connection Error!')
    end
end

% --- Executes during object creation, after setting all properties.
function edit6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit7_Callback(hObject, eventdata, handles)
% hObject    handle to edit7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit7 as text
%        str2double(get(hObject,'String')) returns contents of edit7 as a double
load OlfConfig
OlfServerIP = OlfConfig.OlfServerIP;
BankPairOffset = OlfConfig.BankPairOffset;
NewValue = get(handles.edit7, 'String');
if isnan(str2double(NewValue))
    msgbox('Error. Entry must be numeric.');
    BpodErrorSound;
else
    NewValue = str2double(NewValue);
    NewValue = ceil(NewValue);
    NewValue = abs(NewValue);
    if NewValue < 1
        NewValue = 1;
    end
    if NewValue > 100
        NewValue = 100;
    end
    set(handles.edit7, 'String', num2str(NewValue))
    handles.output = hObject;
    guidata(hObject, handles);
    IPString = [num2str(OlfServerIP(1)) '.' num2str(OlfServerIP(2)) '.' num2str(OlfServerIP(3)) '.' num2str(OlfServerIP(4))];
    try
        TCPWrite(IPString, 3336, ['WRITE BankFlow' num2str(2+BankPairOffset) '_Actuator ' num2str(NewValue)]);
    catch
        error('Connection Error!')
    end
end

% --- Executes during object creation, after setting all properties.
function edit7_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit8_Callback(hObject, eventdata, handles)
% hObject    handle to edit8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit8 as text
%        str2double(get(hObject,'String')) returns contents of edit8 as a double
load OlfConfig
OlfServerIP = OlfConfig.OlfServerIP;
NewValue = get(handles.edit8, 'String');
if isnan(str2double(NewValue))
    msgbox('Error. Entry must be numeric.');
    BpodErrorSound;
else
    NewValue = str2double(NewValue);
    NewValue = ceil(NewValue);
    NewValue = abs(NewValue);
    if NewValue < 100
        NewValue = 100;
    end
    if NewValue > 1000
        NewValue = 1000;
    end
    set(handles.edit8, 'String', num2str(NewValue))
    handles.output = hObject;
    guidata(hObject, handles);
    IPString = [num2str(OlfServerIP(1)) '.' num2str(OlfServerIP(2)) '.' num2str(OlfServerIP(3)) '.' num2str(OlfServerIP(4))];
    try
        TCPWrite(IPString, 3336, ['WRITE Carrier3_Actuator ' num2str(NewValue)]);
    catch
        error('Connection Error!')
    end
end

% --- Executes during object creation, after setting all properties.
function edit8_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes when selected object is changed in uipanel1.
function uipanel1_SelectionChangeFcn(hObject, eventdata, handles)
% hObject    handle to the selected object in uipanel1
% eventdata  structure with the following fields (see UIBUTTONGROUP)
%	EventName: string 'SelectionChanged' (read only)
%	OldValue: handle of the previously selected object or empty if none was selected
%	NewValue: handle of the currently selected object
% handles    structure with handles and user data (see GUIDATA)
global BpodSystem
Offset = 0;
if get(handles.radiobutton1, 'Value') == 1
    Offset = 0;
elseif get(handles.radiobutton2, 'Value') == 1
    Offset = 2;
elseif get(handles.radiobutton3, 'Value') == 1
    Offset = 4;
elseif get(handles.radiobutton4, 'Value') == 1
    Offset = 6;
end
load OlfConfig
OlfConfig.BankPairOffset = Offset;
SavePath = fullfile(BpodSystem.Path.BpodRoot,'Bpod System Files','OlfConfig.mat');
save(SavePath, 'OlfConfig');
Mbox = msgbox('            Selection saved.', 'Modal');
BpodErrorSound;