function varargout = TestSoundManager(varargin)
% TESTSOUNDMANAGER MATLAB code for TestSoundManager.fig
%      TESTSOUNDMANAGER, by itself, creates a new TESTSOUNDMANAGER or raises the existing
%      singleton*.
%
%      H = TESTSOUNDMANAGER returns the handle to a new TESTSOUNDMANAGER or the handle to
%      the existing singleton*.
%
%      TESTSOUNDMANAGER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in TESTSOUNDMANAGER.M with the given input arguments.
%
%      TESTSOUNDMANAGER('Property','Value',...) creates a new TESTSOUNDMANAGER or raises
%      the existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before TestSoundManager_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to TestSoundManager_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help TestSoundManager

% Last Modified by GUIDE v2.5 18-Sep-2015 12:21:16

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @TestSoundManager_OpeningFcn, ...
                   'gui_OutputFcn',  @TestSoundManager_OutputFcn, ...
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

% --- Executes just before TestSoundManager is made visible.
function TestSoundManager_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to TestSoundManager (see VARARGIN)



% --- Outputs from this function are returned to the command line.
function varargout = TestSoundManager_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure



% --- Executes during object creation, after setting all properties.
function frequency_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to frequency_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function volume_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to volume_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function volume_edit_Callback(hObject, eventdata, handles)
% hObject    handle to volume_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of volume_edit as text
%        str2double(get(hObject,'String')) returns contents of volume_edit as a double


% --- Executes on button press in play.
function play_Callback(hObject, eventdata, handles)
% hObject    handle to play (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --- Parameters of the test ---
toneDuration = 1;
fsOut = 192000;
tvec = 0:1/fsOut:toneDuration;

CalFilePath = get(handles.filename_edit, 'String');
try
    open(CalFilePath); % Creates local variable "SoundCal", a struct with the cal table and coefficients
catch
    error('Could not open calibration file');
end
frequency = str2double(get(handles.frequency_edit, 'String'));
speaker = get(handles.speaker1, 'Value');
if speaker == 0 % Other radio button is selected
    speaker = 2;
end
% Attenuation for this frequency at Target SPL
toneAtt = polyval(SoundCal(1,handles.speaker).Coefficient,frequency);

diffSPL = str2double(handles.volume_edit.String) - SoundCal(1,speaker).TargetSPL;
attFactor = sqrt(10^(diffSPL/10));

amplitude = toneAtt*attFactor;

SoundVec = amplitude * sin(2*pi*frequency*tvec);

if handles.speaker==1
    SoundVec = [ SoundVec; zeros(1,length(SoundVec)) ];
end
if handles.speaker==2
    SoundVec = [ zeros(1,length(SoundVec)); SoundVec ];
end

% Load sound
PsychToolboxSoundServer('Load', 1, SoundVec);
% --- Play the sound ---
PsychToolboxSoundServer('Play', 1);


% --- Executes on button press in close.
function close_Callback(hObject, eventdata, handles)
% hObject    handle to close (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
close(handles.gui)

% --- Executes when selected object changed in unitgroup.
function unitgroup_SelectionChangedFcn(hObject, eventdata, handles)
% hObject    handle to the selected object in unitgroup 
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if (hObject == handles.speaker1)
    handles.speaker=1;
else
    handles.speaker=2;
end
guidata(hObject,handles)

function filename_edit_Callback(hObject, eventdata, handles)
% hObject    handle to filename_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of filename_edit as text
%        str2double(get(hObject,'String')) returns contents of filename_edit as a double


% --- Executes during object creation, after setting all properties.
function filename_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to filename_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in file.
function file_Callback(hObject, eventdata, handles)
% hObject    handle to file (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[FileName,PathName] = uigetfile;
handles.calfile = fullfile(PathName,FileName);
handles.filename_edit.String = handles.calfile;
load(handles.calfile)
handles.SoundCal = SoundCal;
guidata(hObject,handles)



function frequency_edit_Callback(hObject, eventdata, handles)
% hObject    handle to frequency_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of frequency_edit as text
%        str2double(get(hObject,'String')) returns contents of frequency_edit as a double
