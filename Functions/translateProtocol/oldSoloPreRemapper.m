function varargout = oldSoloPreRemapper(varargin)
% OLDSOLOPREREMAPPER MATLAB code for oldSoloPreRemapper.fig
%      OLDSOLOPREREMAPPER, by itself, creates a new OLDSOLOPREREMAPPER or raises the existing
%      singleton*.
%
%      H = OLDSOLOPREREMAPPER returns the handle to a new OLDSOLOPREREMAPPER or the handle to
%      the existing singleton*.
%
%      OLDSOLOPREREMAPPER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in OLDSOLOPREREMAPPER.M with the given input arguments.
%
%      OLDSOLOPREREMAPPER('Property','Value',...) creates a new OLDSOLOPREREMAPPER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before oldSoloPreRemapper_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to oldSoloPreRemapper_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help oldSoloPreRemapper

% Last Modified by GUIDE v2.5 09-Aug-2017 07:35:38

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @oldSoloPreRemapper_OpeningFcn, ...
                   'gui_OutputFcn',  @oldSoloPreRemapper_OutputFcn, ...
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


% --- Executes just before oldSoloPreRemapper is made visible.
function oldSoloPreRemapper_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to oldSoloPreRemapper (see VARARGIN)

% Choose default command line output for oldSoloPreRemapper
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);


global BpodSystem

obj=varargin{1};
if numel(varargin)>=2
    obj.outSMA=varargin{2};
end

handles.soloInputTable.ColumnEditable  = logical([1 1]);
handles.soloOutputTable.ColumnEditable = logical([1 1]);

%%%%create default inputs for old solo
defaultInputNames    = {'Cin','Cout','Lin','Lout','Rin','Rout'};
defaultInputEventIds = {1    ,-1    ,2    ,-2    ,3    ,-3    };

%%%%create default outputs for old solo
defaultOutputNames    = {''};
defaultOutputEventIds = {2^0};

%populate the tables
handles.soloInputTable.Data(1:numel(defaultInputNames),1)=defaultInputNames;
handles.soloInputTable.Data(1:numel(defaultInputNames),2)=defaultInputEventIds;
handles.soloInputTable.UserData.CurrSelection=1;

handles.soloOutputTable.Data(1:numel(defaultOutputNames),1)=defaultOutputNames;
handles.soloOutputTable.Data(1:numel(defaultOutputNames),2)=defaultOutputEventIds;
handles.soloOutputTable.UserData.CurrSelection=1;

% UIWAIT makes oldSoloPreRemapper wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = oldSoloPreRemapper_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;




% --- Executes when entered data in editable cell(s) in soloInputTable.
function soloInputTable_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to soloInputTable (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)

global BpodSystem

if eventdata.Indices(2)
    %second column in table must be numeric
    if ~isnumeric(eventdata.NewData)
        warndlg('Entries to ID column must be numeric','Numeric IDs only')
    end
end


% --- Executes when selected cell(s) is changed in soloInputTable.
function soloInputTable_CellSelectionCallback(hObject, eventdata, handles)
% hObject    handle to soloInputTable (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) currently selecteds
% handles    structure with handles and user data (see GUIDATA)



% --------------------------------------------------------------------
function soloInputTable_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to soloInputTable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function soloOutputTable_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to soloOutputTable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes when entered data in editable cell(s) in soloOutputTable.
function soloOutputTable_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to soloOutputTable (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)
global BpodSystem

global BpodSystem

if eventdata.Indices(2)
    %second column in table must be numeric
    if ~isnumeric(eventdata.NewData)
        warndlg('Entries to ID column must be numeric','Numeric IDs only')
    end
end

% --- Executes when selected cell(s) is changed in soloOutputTable.
function soloOutputTable_CellSelectionCallback(hObject, eventdata, handles)

% hObject    handle to soloOutputTable (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) currently selecteds
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in DoneButton.
function DoneButton_Callback(hObject, eventdata, handles)
% hObject    handle to DoneButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over DoneButton.
function DoneButton_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to DoneButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global BpodSystem

%read data in to the appropriate spots of the inSMA.
