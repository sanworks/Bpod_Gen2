function varargout = SoundCalibrationManager(varargin)

% SOUNDCALIBRATIONMANAGER MATLAB code for SoundCalibrationManager.fig
%      SOUNDCALIBRATIONMANAGER, by itself, creates a new SOUNDCALIBRATIONMANAGER or raises the existing
%      singleton*.
%
%      H = SOUNDCALIBRATIONMANAGER returns the handle to a new SOUNDCALIBRATIONMANAGER or the handle to
%      the existing singleton*.
%
%      SOUNDCALIBRATIONMANAGER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SOUNDCALIBRATIONMANAGER.M with the given input arguments.
%
%      SOUNDCALIBRATIONMANAGER('Property','Value',...) creates a new SOUNDCALIBRATIONMANAGER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before SoundCalibrationManager_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to SoundCalibrationManager_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help SoundCalibrationManager

% Last Modified by GUIDE v2.5 18-Sep-2015 10:31:07

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @SoundCalibrationManager_OpeningFcn, ...
                   'gui_OutputFcn',  @SoundCalibrationManager_OutputFcn, ...
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


% --- Executes just before SoundCalibrationManager is made visible.
function SoundCalibrationManager_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to SoundCalibrationManager (see VARARGIN)
global BpodSystem
if ispc % Start the MCC board with PsychToolbox
    BpodSystem.PluginObjects.USB1608G = struct;
    warning off; BpodSystem.PluginObjects.USB1608G.Board = analoginput('mcc', 0); warning on;
    BpodSystem.PluginObjects.USB1608G.Board.SampleRate = 200000;
    BpodSystem.PluginObjects.USB1608G.Board.SamplesPerTrigger = 200000*.3;
    BpodSystem.PluginObjects.USB1608G.Ch0 = addchannel(BpodSystem.PluginObjects.USB1608G.Board, 0);
    BpodSystem.PluginObjects.USB1608G.Ch0.InputRange = [-10 10];
end
% Choose default command line output for SoundCalibrationManager
handles.output = hObject;
    
handles.filename = [];

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes SoundCalibrationManager wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = SoundCalibrationManager_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Executes during object creation, after setting all properties.
function MaxFreq_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes during object creation, after setting all properties.
function SoundType_CreateFcn(hObject, eventdata, handles)
% hObject    handle to SoundType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function TargetSPL_CreateFcn(hObject, eventdata, handles)
% hObject    handle to TargetSPL (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function MinBandLimit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MinBandLimit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function MaxBandLimit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MaxBandLimit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in calibrate.
function calibrate_Callback(hObject, eventdata, handles)
% hObject    handle to calibrate (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% --- Initialize Sound Server ---
global BpodSystem
BpodSystem.PluginObjects.SoundCal = struct;
BpodSystem.PluginObjects.SoundCal.Abort = 0;
C = colormap;
%Get Calibration Parameters
TargetSPL = str2double(get(handles.TargetSPL,'String'));
MinFreq = str2double(get(handles.MinFreq,'String'));
MaxFreq = str2double(get(handles.MaxFreq,'String'));
nFreq = str2double(get(handles.nFreq,'String'));
nSpeakers = str2double(get(handles.nSpeakers,'String'));
nRepeats = str2double(get(handles.edit11,'String'));

MinBandLimit = str2double(get(handles.MinBandLimit,'String'));
MaxBandLimit = str2double(get(handles.MaxBandLimit,'String'));

FrequencyVector =  logspace(log10(MinFreq),log10(MaxFreq),nFreq);

PsychToolboxSoundServer('init')

OutputFileName = ['SoundCalibration'];
[FileName,PathName] = uiputfile('.mat','Save Sound Calibration File',OutputFileName);

handles.filename = fullfile(PathName,FileName);

AttenuationVector = zeros(nFreq,nSpeakers,nRepeats);
SoundCal = struct;

for inds=1:nSpeakers            % --   Loop through speakers  --
    
    switch inds
        case 1
            symb = 'o';
        case 2
            symb = 'x';
    end
    
    uiwait(msgbox({[' Calibrating speaker ' num2str(inds) '.'],' Position microphone and press OK to continue...'},'Sound Calibration','modal'));
        

    Sound.Speaker = inds;
   
        for rep=1:nRepeats
                
            if rep>1
                uiwait(msgbox('Reposition mic for next repetition and press OK','Sound Calibration','modal'));
            end
            
            for indf=1:nFreq            % -- Loop through frequencies --
                
                Sound.Frequency = FrequencyVector(indf);
                BandLimits = Sound.Frequency * [MinBandLimit MaxBandLimit];
            
                AttenuationVector(indf, inds,rep) = find_amplitude(Sound,TargetSPL,BandLimits,handles);
                if AttenuationVector(indf, inds,rep) == 1
                     errordlg('ERROR: The sound recorded was not loud enough to calibrate. Please manually increase the speaker volume and restart.');
                     return;
                end
                axes(handles.attFig);
                hold on
                semilogx(FrequencyVector(1:indf)/1000,AttenuationVector(1:indf,inds,rep),[symb '-'],'Color',C(floor(64/nSpeakers/nRepeats)*(rep-1)+floor(64/nSpeakers)*(inds-1)+1,:));
                New_XTickLabel = get(gca,'xtick');
                set(gca,'XTickLabel',New_XTickLabel);
                grid on;
                ylabel('Attenuation (dB)');
                xlabel('Frequency (kHz)')
                axis([MinFreq/1000 MaxFreq/1000 0 1])
            end
        end
        
        semilogx(FrequencyVector(1:indf)/1000,mean(AttenuationVector(:,inds,:),3),'-','Color',C(floor(64/nSpeakers)*(inds-1)+1,:),'linewidth',1.5);
    
    SoundCal(1,inds).Table = [FrequencyVector' mean(AttenuationVector(:,inds,:),3)];
    SoundCal(1,inds).CalibrationTargetRange = [MinFreq MaxFreq];
    SoundCal(1,inds).TargetSPL = TargetSPL;
    SoundCal(1,inds).LastDateModified = date;
    SoundCal(1,inds).Coefficient = polyfit(FrequencyVector',mean(AttenuationVector(:,inds),3),1);

    drawnow;
end

% -- Saving results --
save(fullfile(PathName,FileName),'SoundCal');
    
uiwait(msgbox({'The Sound Calibration file has been saved in: ', fullfile(PathName,FileName)},'Sound Calibration','modal'));
    
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function MinFreq_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MinFreq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function nFreq_CreateFcn(hObject, eventdata, handles)
% hObject    handle to nFreq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function nSpeakers_CreateFcn(hObject, eventdata, handles)
% hObject    handle to nSpeakers (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function edit8_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MaxBandLimit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function edit9_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MinBandLimit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes during object creation, after setting all properties.
function edit10_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in test_btn.
function test_btn_Callback(hObject, eventdata, handles)
% hObject    handle to test_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
TestSoundManager(handles.filename)

% --- Executes on button press in pause_btn.
function pause_btn_Callback(hObject, eventdata, handles)
% hObject    handle to test_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global BpodSystem
BpodSystem.PluginObjects.SoundCal.Abort = 1;

% --- Executes on button press in test_btn.
function nFreq_Callback(hObject, eventdata, handles)
% hObject    handle to test_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function edit11_Callback(hObject, eventdata, handles)
% hObject    handle to edit11 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit11 as text
%        str2double(get(hObject,'String')) returns contents of edit11 as a double


% --- Executes during object creation, after setting all properties.
function edit11_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit11 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
