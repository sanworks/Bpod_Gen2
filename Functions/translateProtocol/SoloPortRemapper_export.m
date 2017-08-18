function varargout = SoloPortRemapper_export(varargin)
% SOLOPORTREMAPPER_EXPORT MATLAB code for SoloPortRemapper_export.fig
%      SOLOPORTREMAPPER_EXPORT, by itself, creates a new SOLOPORTREMAPPER_EXPORT or raises the existing
%      singleton*.
%
%      H = SOLOPORTREMAPPER_EXPORT returns the handle to a new SOLOPORTREMAPPER_EXPORT or the handle to
%      the existing singleton*.
%
%      SOLOPORTREMAPPER_EXPORT('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SOLOPORTREMAPPER_EXPORT.M with the given input arguments.
%
%      SOLOPORTREMAPPER_EXPORT('Property','Value',...) creates a new SOLOPORTREMAPPER_EXPORT or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before SoloPortRemapper_export_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to SoloPortRemapper_export_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help SoloPortRemapper_export

% Last Modified by GUIDE v2.5 30-Mar-2017 08:59:46

% Begin initialization code - DO NOT EDIT


gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @SoloPortRemapper_export_OpeningFcn, ...
    'gui_OutputFcn',  @SoloPortRemapper_export_OutputFcn, ...
    'gui_LayoutFcn',  @SoloPortRemapper_export_LayoutFcn, ...
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
end


% --- Executes just before SoloPortRemapper_export is made visible.
function SoloPortRemapper_export_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to SoloPortRemapper_export (see VARARGIN)

global BpodSystem

obj=varargin{1};
if numel(varargin)>=2
    obj.outSMA=varargin{2};
end

%%
%%%%create solo input sma data for table

%if sma does not have a 'input_line_map' (physical port mappings)
if isfield(obj.inSMA,'input_line_map')
    
    inTable=[obj.inSMA.input_map(1:end-1,:) obj.inSMA.input_line_map(:,2)...
        cell(size(obj.inSMA.input_line_map(:,2),1),1)];
else
   inTable=[obj.inSMA.input_map(1:end-1,:) cell(size(obj.inSMA.input_map(1:end-1,1)))...
        cell(size(obj.inSMA.input_map(1:end-1,:),1),1)];
   
end

%populate input table
handles.inputRemapTable.Data=inTable;
handles.inputRemapTable.UserData.CurrSelection=1;

%%
%%%%create solo output sma for table

if isfield(obj.settings,'DIOLINES')
    dioNames=fields(obj.settings.DIOLINES);
else
    dioNames=obj.inSMA.output_map(:,1);
end

for b=1:1:numel(dioNames)
    if isfield(obj.settings,'DIOLINES')
        dioChans{b}=obj.settings.DIOLINES.(dioNames{b});
        dioIDs{b}=b; %is this right?
    else
        dioChans{b}=obj.inSMA.output_map{b,1};
        dioIDs{b}=b;
    end
end

outTable=[dioNames dioIDs' dioChans' cell(size(dioNames,1),1)];

%populate output table
handles.outputRemapTable.Data=outTable;
handles.outputRemapTable.UserData.CurrSelection=1;

%%
%create data struct for available INPUT channels on available modules
%for each module, have a struct for changes, and for each chan, a struct
%for pins

%NOTE: active modules are added to the StateMachineInfo.InputChannelNames
%field of the main Bpod Object.
%create list of Bpod modules for input selection
%non-connected module will be gray
activeModuleNames=BpodSystem.Modules.Name(find(BpodSystem.Modules.Connected));
if ~isempty(activeModuleNames)
    activeModuleNames=cat(2,{'Bpod'}, activeModuleNames);
else
    activeModuleNames={'Bpod'};
end

%if someone is active and name is empty, give an empty name
noNameIdxs=find(and(cellfun(@(x) isempty(x), BpodSystem.Modules.Name),...
    BpodSystem.Modules.Connected));
activeModuleNames(noNameIdxs)={repmat('',1,numel(noNameIdxs))};

%input channel type pin names, as defined for the whole system, including
%modules
%JPL - needs to stuffed in a config file somewhere!
inputChanTypePinNames.ChanType{1}='Serial'; inputChanTypePinNames.Name{1}={'Tx','Rx'};
inputChanTypePinNames.ChanType{2}='USB';    inputChanTypePinNames.Name{2}={'Rx','Rx+','TX+','TX-','D+','D-','5VCC'};
inputChanTypePinNames.ChanType{3}='BNC';    inputChanTypePinNames.Name{3}={'1'};
inputChanTypePinNames.ChanType{4}='Wire';   inputChanTypePinNames.Name{4}={'1'};
inputChanTypePinNames.ChanType{5}='Port';   inputChanTypePinNames.Name{5}={'DI','DIO1','DIO2','5VCC','DGnd','12Vcc','12VGnd','""'};
inputChanTypePinNames.ChanType{6}='AI';     inputChanTypePinNames.Name{6}={'1'};
inputChanTypePinNames.ChanType{7}='DI';     inputChanTypePinNames.Name{7}={'1'};


for b=1:1:numel(activeModuleNames)
    if strcmp('Bpod',activeModuleNames{b}) 
        %note: indexing by enabled status here also removes the modules
        input=BpodSystem.StateMachineInfo.InputChannelNames(find(BpodSystem.InputsEnabled));
    else  %return the input channel options we have, and their associated pin maps
        input=BpodSystem.getInputChansAndPinsForModule(activeModuleNames{b});
    end
    
    Name=activeModuleNames{b};
    
    chanStruct=struct('Names',input,...       %name of channel
        'IDs',1:numel(input),...              %numerical id of channel on module(b)
        'Activated',zeros(1,numel(input)),... %enabled flag
        'Enabled',zeros(1,numel(input)),...   %enabled flag
        'Pins', cell(1,numel(input)));        %struct for pin data on channel
    
    %populate pins field of chanstruct according to the input type
    pinStruct=struct( 'Names',{''},...        %name of port/pin
        'IDs',[1],...                         %numerical id of port
        'Activated',{''},...                  %index of ports that are active
        'Assigned', [0]);                     %index of ports assigned
    
    for c=1:1:numel(input)
        chanStruct(c).Pins=pinStruct;
        if ~isempty(strfind(chanStruct(c).Names,'Serial'))
            pins = inputChanTypePinNames.Name{find(strcmp('Serial',inputChanTypePinNames.ChanType))};
        elseif ~isempty(strfind(chanStruct(c).Names,'USB'))
            pins = inputChanTypePinNames.Name{find(strcmp('USB',inputChanTypePinNames.ChanType))};
        elseif ~isempty(strfind(chanStruct(c).Names,'BNC'))
            pins = inputChanTypePinNames.Name{find(strcmp('BNC',inputChanTypePinNames.ChanType))};
        elseif ~isempty(strfind(chanStruct(c).Names,'Wire'))
            pins= inputChanTypePinNames.Name{find(strcmp('Wire',inputChanTypePinNames.ChanType))};
        elseif ~isempty(strfind(chanStruct(c).Names,'Port'))
            pins= inputChanTypePinNames.Name{find(strcmp('Port',inputChanTypePinNames.ChanType))};
        elseif ~isempty(strfind(chanStruct(c).Names,'AI'))
            pins= inputChanTypePinNames.Name{find(strcmp('AI',inputChanTypePinNames.ChanType))};
        elseif ~isempty(strfind(chanStruct(c).Names,'DI'))
            pins= inputChanTypePinNames.Name{find(strcmp('DI',inputChanTypePinNames.ChanType))};
        else
            keyboard %JPL - shouldnt really be here...
        end
        
        chanStruct(c).Pins.Names=pins;
        chanStruct(c).Pins.IDs=1:numel(pins);
        chanStruct(c).Pins.Activated=zeros(1,numel(pins));
        chanStruct(c).Pins.Assigned=zeros(1,numel(pins));
        
    end
    
    handles.inputRemapTable.UserData.availableInputList.Module{b}=struct('Name',Name,...
        'Enabled',[1],...                %enabled flag
        'Channels',{chanStruct});        %struct for channel data on module(b)
    
end

%%
%outputchannel type pin names, as defined for the whole system, including
%modules
outputChanTypePinNames.ChanType{1}  = 'Serial';     outputChanTypePinNames.Name{1}={'Tx','Rx'};
outputChanTypePinNames.ChanType{2}  = 'USB';        outputChanTypePinNames.Name{2}={'Rx','Rx+','TX+','TX-','D+','D-','5VCC'};
outputChanTypePinNames.ChanType{3}  = 'BNC';        outputChanTypePinNames.Name{3}={'1'};
outputChanTypePinNames.ChanType{4}  = 'Wire';       outputChanTypePinNames.Name{4}={'1'};
outputChanTypePinNames.ChanType{5}  = 'Port';       outputChanTypePinNames.Name{5}={'DI','DIO1','DIO2','5VCC','DGnd','12Vcc','12VGnd','""'};
outputChanTypePinNames.ChanType{6}  = 'SoftCode';   outputChanTypePinNames.Name{6}={'1'};
outputChanTypePinNames.ChanType{7}  = 'ValveState'; outputChanTypePinNames.Name{7}={'1'};
outputChanTypePinNames.ChanType{8}  = 'PWM';        outputChanTypePinNames.Name{8}={'1'};
outputChanTypePinNames.ChanType{9}  = 'AO';         outputChanTypePinNames.Name{9}={'1'};
outputChanTypePinNames.ChanType{10} = 'DO';         outputChanTypePinNames.Name{10}={'1'};

for b=1:1:numel(activeModuleNames)
    
    %JPL - added this param to bpod object
    outputsEnabled=find(BpodSystem.OutputsEnabled);
    
    if strcmp('Bpod',activeModuleNames{b}) 
        %note: indexing by enabled status here also removes the modules
        output=BpodSystem.StateMachineInfo.OutputChannelNames(outputsEnabled);
    else  %return the input channel options we have, and their associated pin maps
        output=BpodSystem.getOutputChansAndPinsForModule(activeModuleNames{b});
    end
    
    Name=activeModuleNames{b};

    chanStruct=struct('Names',output,...   %name of channel
        'IDs',1:numel(output),...                    %numerical id of channel on module(b)
        'Activated',zeros(1,numel(output)),...         %enabled flag
        'Enabled',zeros(1,numel(output)),...         %enabled flag
        'Pins', cell(1,numel(output)));            %struct for pin data on channel
    
    %populate pins field of chanstruct according to the input type
    pinStruct=struct( 'Names',{''},...   %name of port/pin
        'IDs',[1],...                     %numerical id of port
        'Activated',{''},...              %index of ports that are active
        'Assigned', [0]);                 %index of ports assigned
    
    for c=1:1:numel(output)
        chanStruct(c).Pins=pinStruct;
        if ~isempty(strfind(chanStruct(c).Names,'Serial'))
            pins = outputChanTypePinNames.Name{find(strcmp('Serial',outputChanTypePinNames.ChanType))};
        elseif ~isempty(strfind(chanStruct(c).Names,'USB'))
            pins = outputChanTypePinNames.Name{find(strcmp('USB',outputChanTypePinNames.ChanType))};
        elseif ~isempty(strfind(chanStruct(c).Names,'BNC'))
            pins = outputChanTypePinNames.Name{find(strcmp('BNC',outputChanTypePinNames.ChanType))};
        elseif ~isempty(strfind(chanStruct(c).Names,'Wire'))
            pins= outputChanTypePinNames.Name{find(strcmp('Wire',outputChanTypePinNames.ChanType))};
        elseif ~isempty(strfind(chanStruct(c).Names,'Port'))
            pins= outputChanTypePinNames.Name{find(strcmp('Port',outputChanTypePinNames.ChanType))};
        elseif ~isempty(strfind(chanStruct(c).Names,'SoftCode'))
            pins= outputChanTypePinNames.Name{find(strcmp('SoftCode',outputChanTypePinNames.ChanType))};
        elseif ~isempty(strfind(chanStruct(c).Names,'ValveState'))
            pins= outputChanTypePinNames.Name{find(strcmp('ValveState',outputChanTypePinNames.ChanType))};
        elseif ~isempty(strfind(chanStruct(c).Names,'PWM'))
            pins= outputChanTypePinNames.Name{find(strcmp('PWM',outputChanTypePinNames.ChanType))};
        elseif ~isempty(strfind(chanStruct(c).Names,'AO'))
            pins= outputChanTypePinNames.Name{find(strcmp('AO',outputChanTypePinNames.ChanType))};
        elseif ~isempty(strfind(chanStruct(c).Names,'DO'))
            pins= outputChanTypePinNames.Name{find(strcmp('DO',outputChanTypePinNames.ChanType))};
        else
            %display('SoloPortRemapper::no global timer/counter assignment in the remapper')
        end
        
        chanStruct(c).Pins.Names=pins;
        chanStruct(c).Pins.IDs=1:numel(pins);
        chanStruct(c).Pins.Activated=zeros(1,numel(pins));
        chanStruct(c).Pins.Assigned=zeros(1,numel(pins));
        
    end
    
    handles.outputRemapTable.UserData.availableOutputList.Module{b}=struct('Name',Name,...
        'Enabled',[1],...                %enabled flag
        'Channels',{chanStruct});        %struct for channel data on module(b)
    
end

%%
%%%BUILD GUI STRINGS FOR INPUTS ON STARTUP

%%%Modules:

%list active modules
for b=1:1:numel(activeModuleNames)

    nameString=activeModuleNames{b};

    %black color
    %will there every be detected but not connected modules that would
    %necessitate a gray color?
    inputModuleStrings{b}=['<HTML><FONT color="' rgb2Hex([0 0 0]) '">' nameString '</FONT></HTML>'];
end

%list inactive modules, but named modules? Maybe useful one day...
inactiveModuleStrings={};
inputModuleStrings=[inputModuleStrings inactiveModuleStrings];

%
handles.bpodInputModuleList.String=inputModuleStrings;
handles.bpodInputModuleList.Value=1;

%%%Channels:
%create list of Bpod channels. Default Module on startup is 1, so
%default selected module on startup is 'bpod', not really a module

%color by ports enabled (black), disabled (grey). Red will mean already
%remapped, but this will be while the GUI is in use
inputsEnabled=BpodSystem.StateMachineInfo.InputChannelNames(find(BpodSystem.InputsEnabled));

for b=1:1:numel(inputsEnabled)
    nameString=inputsEnabled{b};
    if ~isempty(strfind(inputsEnabled,'Serial'))...
            || ~isempty(strfind(inputsEnabled,'USB'))...
            || ~isempty(strfind(inputsEnabled,'BNC'))
        
        inputNameString{b}=['<HTML><FONT color="' rgb2Hex([0 0 0]) '">' nameString '</FONT></HTML>'];
        
    elseif ~isempty(strfind(inputsEnabled{b},'Wire'))
        %if BpodSystem.InputsEnabled(b)==0 %gray color
        %    inputNameString{b}=['<HTML><FONT color="' rgb2Hex([100 100 100]) '">' nameString '</FONT></HTML>'];
        %else %black color
            inputNameString{b}=['<HTML><FONT color="' rgb2Hex([0 0 0]) '">' nameString '</FONT></HTML>'];
        %end
    elseif ~isempty(strfind(inputsEnabled{b},'Port'))
        %if BpodSystem.InputsEnabled(b)==0 %gray color
        %    inputNameString{b}=['<HTML><FONT color="' rgb2Hex([100 100 100]) '">' nameString '</FONT></HTML>'];
        %else %black color
            inputNameString{b}=['<HTML><FONT color="' rgb2Hex([0 0 0]) '">' nameString '</FONT></HTML>'];
        %end
    end
    
end

handles.bpodInputNameList.String=inputNameString;
handles.bpodInputNameList.Value=1;


%%%Pins:
%create list of Bpod pins for default channel. Pins will depend on whats on
%top of the input channels list

idx=find(cellfun(@(x) ~isempty(x), inputNameString),1);   %get idx of first input that is empty (e.g. a module)

if ~isempty(strfind(inputNameString{idx},'Serial'))
    Strings={'Tx','Rx'};
elseif ~isempty(strfind(inputNameString{idx},'USB'))
    Strings={'Rx','Rx+','TX+','TX-','D+','D-','VCC'};
elseif ~isempty(strfind(inputNameString{idx},'BNC'))
    Strings={'1'};
elseif ~isempty(strfind(inputNameString{idx},'Wire'))
    Strings={'1'};
elseif ~isempty(strfind(inputNameString{idx},'Port'))
    Strings={'1','2','3','4','5','6','7','8',};
else
    
end

handles.bpodInputPortNumList.String=Strings;
handles.bpodInputPortNumList.Value=1;

%%%% data structure for tracking the input remap,
for b=1:1:size(inTable,1)
    handles.inputRemapTable.UserData.inputRemapStruct{b}=struct('SoloName' ,inTable{b,1},...
        'SoloId',inTable(b,2),...
        'SoloPort',inTable(b,3),...
        'SoloType',inTable(b,4),...
        'Module',[],...
        'Chan',[],...
        'Pin',[],...
        'Assigned', 0);                     
end

%%
%%%BUILD GUI STRINGS FOR OUTPUTS ON STARTUP

%%%Modules:
%list active modules
for b=1:1:numel(activeModuleNames)

    nameString=activeModuleNames{b};

    %black color
    %will there every be detected but not connected modules that would
    %necessitate a gray color?
    outputModuleStrings{b}=['<HTML><FONT color="' rgb2Hex([0 0 0]) '">' nameString '</FONT></HTML>'];
end

%list inactive modules, but named modules? Maybe useful one day...
inactiveModuleStrings={};
outputModuleStrings=[outputModuleStrings inactiveModuleStrings];

%
handles.bpodOutputModuleList.String=outputModuleStrings;
handles.bpodOutputModuleList.Value=1;

%%%Channels:
%create list of Bpod channels.
%default module on startup is just bpod

%color by ports enabled (black), disabled (grey). Red will mean already
%remapped, but this will be while the GUI is in use

outputsEnabled=BpodSystem.StateMachineInfo.OutputChannelNames(find(BpodSystem.OutputsEnabled));

for b=1:1:numel(outputsEnabled)
    nameString=outputsEnabled{b};

    
    if ~isempty(strfind(outputsEnabled,'Serial'))...
            || ~isempty(strfind(outputsEnabled,'USB'))...
            || ~isempty(strfind(outputsEnabled,'BNC'))
        
        outputNameString{b}=['<HTML><FONT color="' rgb2Hex([0 0 0]) '">' nameString '</FONT></HTML>'];
        
    elseif ~isempty(strfind(outputsEnabled{b},'PWM'))
            outputNameString{b}=['<HTML><FONT color="' rgb2Hex([0 0 0]) '">' nameString '</FONT></HTML>'];
    elseif ~isempty(strfind(outputsEnabled{b},'Port'))
            outputNameString{b}=['<HTML><FONT color="' rgb2Hex([0 0 0]) '">' nameString '</FONT></HTML>'];
    end
end

handles.bpodOutputNameList.String=outputNameString;
handles.bpodOutputNameList.Value=1;

%%%Pins:
%create list of Bpod pins for default channel. Pins will depend on whats on
%top of the output channels list

%JPL - probably want some config file for these trings
if ~isempty(strfind(outputNameString{1},'Serial'))
    Strings={'Tx','Rx'};
elseif ~isempty(strfind(outputNameString{1},'SoftCode'))
    Strings={'1'};
elseif ~isempty(strfind(outputNameString{1},'BNC'))
    Strings={'1'};
elseif ~isempty(strfind(outputNameString{1},'PWM'))
    Strings={'1'};
elseif ~isempty(strfind(outputNameString{1},'ValveState'))
    Strings={'1'};
else
    
end

handles.bpodOutputPortNumList.String=Strings;
handles.bpodOutputPortNumList.Value=1;

%%%% data structure for tracking the input remap, fill with some defaults on start
for b=1:1:size(outTable,1)
    handles.outputRemapTable.UserData.outputRemapStruct{b}=struct('SoloName' ,outTable{b,1},...
        'SoloId',outTable(b,2),...
        'SoloPort',outTable(b,3),...
        'SoloType',outTable(b,4),...
        'Module',[],...
        'Chan',[],...
        'Pin',[],...
        'Assigned', 0);  
end
%%

% Choose default command line output for SoloPortRemapper_export
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes SoloPortRemapper_export wait for user response (see UIRESUME)
% uiwait(handles.figure1);
end


% --- Outputs from this function are returned to the command line.
function varargout = SoloPortRemapper_export_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%   STUFF FOR THE TABLES   %%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%CREATE FUNCTION CALLBACKS

% --- Executes during object creation, after setting all properties.
function inputRemapTable_CreateFcn(hObject, eventdata, handles)
% hObject    handle to inputRemapTable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


end

% --- Executes during object creation, after setting all properties.
function outputRemapTable_CreateFcn(hObject, eventdata, handles)
% hObject    handle to outputRemapTable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
end

%%%%%%%%%%%%%CELL SELECTION CALLBACKS

% --- Executes when selected cell(s) is changed in inputRemapTable.
function inputRemapTable_CellSelectionCallback(hObject, eventdata, handles)
% hObject    handle to inputRemapTable (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) currently selecteds
% handles    structure with handles and user data (see GUIDATA)

global BpodSystem

curSolo=eventdata.Indices(1);
curModule=handles.inputRemapTable.UserData.inputRemapStruct{curSolo}.Module;
curChan=handles.inputRemapTable.UserData.inputRemapStruct{curSolo}.Chan;
curPin=handles.inputRemapTable.UserData.inputRemapStruct{curSolo}.Pin;

%get module idx
mIdx=find(strcmp(curModule,BpodSystem.Modules.Name));

if isempty(mIdx)
    mIdx=1;
end

%set the user data to the current selected id
handles.inputRemapTable.UserData.CurrSelection=curSolo;

%if this is the first selection weve made, enable the rest of the gui
if strcmp('off',get(handles.bpodInputModuleList,'Enable'))
    %module
    set(handles.bpodInputModuleList,'Enable','on');
    set(handles.bpodInputModuleList,'BackgroundColor',[1 1 1]);
    %channel
    set(handles.bpodInputNameList,'Enable','on');
    set(handles.bpodInputNameList,'BackgroundColor',[1 1 1]);
    %pin
    set(handles.bpodInputPortNumList,'Enable','on');
    set(handles.bpodInputPortNumList,'BackgroundColor',[1 1 1]);
end

%%%for this solo selection, set the module string to whatever module weve
%%%assigned

%%%set proper selection for module
idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,curModule)),...
    handles.bpodInputModuleList.String,'UniformOutput',false)),1);
if isempty(idx)
    idx=1;
end
handles.bpodInputModuleList.Value=idx;

%%%populate channels list with assigned channels for this solo channel
chanString={handles.inputRemapTable.UserData.availableInputList.Module{idx}.Channels.Names};

htmlWrap=cellfun(@(x) ['<HTML><FONT color="#*">' x '</FONT></HTML>'],chanString,'UniformOutput',false);
%htmlWrap=['<HTML><FONT color="#*">' chanString '</FONT></HTML>'];

%get the color right...but just make black for now
colorVect=[0 0 0]; %black
htmlWrap=cellfun(@(x) strrep(x,'#*',['#' rgb2Hex(colorVect)]), htmlWrap,'UniformOutput',false);

handles.bpodInputNameList.String=htmlWrap;
    
%and set proper channel selection
idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,curChan)),...
    handles.bpodInputNameList.String,'UniformOutput',false)));
if isempty(idx)
    idx=1;
end
handles.bpodInputNameList.Value=idx;

%%%populate pins list this solo channel's bpod channel;
%%%change port string to match this channel
portString=handles.inputRemapTable.UserData.availableInputList.Module{mIdx}.Channels(idx).Pins.Names;

htmlWrap=cellfun(@(x) ['<HTML><FONT color="#*">' x '</FONT></HTML>'],portString,'UniformOutput',false);
%get the color right...but just make black for now
colorVect=[0 0 0]; %black
htmlWrap=strrep(htmlWrap,'#*',['#' rgb2Hex(colorVect)]);

handles.bpodInputPortNumList.String=htmlWrap;

%and set proper pin selection

idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,curPin)),...
    handles.bpodInputPortNumList.String,'UniformOutput',false)));
if isempty(idx)
    idx=1;
end
handles.bpodInputPortNumList.Value=idx;

end


% --- Executes when selected cell(s) is changed in outputRemapTable.
function outputRemapTable_CellSelectionCallback(hObject, eventdata, handles)
% hObject    handle to outputRemapTable (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) currently selecteds
% handles    structure with handles and user data (see GUIDATA)

global BpodSystem

curSolo=eventdata.Indices(1);
curModule=handles.outputRemapTable.UserData.outputRemapStruct{curSolo}.Module;
curChan=handles.outputRemapTable.UserData.outputRemapStruct{curSolo}.Chan;
curPin=handles.outputRemapTable.UserData.outputRemapStruct{curSolo}.Pin;

%get module idx
mIdx=find(strcmp(curModule,BpodSystem.Modules.Name));

if isempty(mIdx)
    mIdx=1;
end

%set the user data to the current selected id
handles.outputRemapTable.UserData.CurrSelection=curSolo;

%if this is the first selection weve made, enable the rest of the gui
if strcmp('off',get(handles.bpodOutputModuleList,'Enable'))
    %module
    set(handles.bpodOutputModuleList,'Enable','on');
    set(handles.bpodOutputModuleList,'BackgroundColor',[1 1 1]);
    %channel
    set(handles.bpodOutputNameList,'Enable','on');
    set(handles.bpodOutputNameList,'BackgroundColor',[1 1 1]);
    %pin
    set(handles.bpodOutputPortNumList,'Enable','on');
    set(handles.bpodOutputPortNumList,'BackgroundColor',[1 1 1]);
end

%%%for this solo selection, set the module string to whatever module weve
%%%assigned

%%%set proper selection for module
idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,curModule)),...
    handles.bpodOutputModuleList.String,'UniformOutput',false)),1);
if isempty(idx)
    idx=1;
end
handles.bpodOutputModuleList.Value=idx;

%%%populate channels list with assigned channels for this solo channel
chanString={handles.outputRemapTable.UserData.availableOutputList.Module{idx}.Channels.Names};

htmlWrap=cellfun(@(x) ['<HTML><FONT color="#*">' x '</FONT></HTML>'],chanString,'UniformOutput',false);
%htmlWrap=['<HTML><FONT color="#*">' chanString '</FONT></HTML>'];

%get the color right...but just make black for now
colorVect=[0 0 0]; %black
htmlWrap=cellfun(@(x) strrep(x,'#*',['#' rgb2Hex(colorVect)]), htmlWrap,'UniformOutput',false);

handles.bpodOutputNameList.String=htmlWrap;
    
%and set proper channel selection
idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,curChan)),...
    handles.bpodOutputNameList.String,'UniformOutput',false)));
if isempty(idx)
    idx=1;
end
handles.bpodOutputNameList.Value=idx;

%%%populate pins list this solo channel's bpod channel;
%%%change port string to match this channel
portString=handles.outputRemapTable.UserData.availableOutputList.Module{mIdx}.Channels(idx).Pins.Names;

htmlWrap=cellfun(@(x) ['<HTML><FONT color="#*">' x '</FONT></HTML>'],portString,'UniformOutput',false);
%get the color right...but just make black for now
colorVect=[0 0 0]; %black
htmlWrap=strrep(htmlWrap,'#*',['#' rgb2Hex(colorVect)]);

handles.bpodOutputPortNumList.String=htmlWrap;

%and set proper pin selection

idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,curPin)),...
    handles.bpodOutputPortNumList.String,'UniformOutput',false)));
if isempty(idx)
    idx=1;
end
handles.bpodOutputPortNumList.Value=idx;
end


%%%%%%%%%%%%%CELL EDIT CALLBACKS


% --- Executes when entered data in editable cell(s) in inputRemapTable.
function inputRemapTable_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to inputRemapTable (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)
end

% --- Executes when entered data in editable cell(s) in outputRemapTable.
function outputRemapTable_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to outputRemapTable (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%% STUFF FOR THE LISTBOXES %%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%OUTPUT

% --- Executes on selection change in bpodOutputModuleList.
function bpodOutputModuleList_Callback(hObject, eventdata, handles)
% hObject    handle to bpodOutputModuleList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns bpodOutputModuleList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from bpodOutputModuleList


global BpodSystem

%strip formatting from string
pattern= '<[^>]*>';
htmlUnwrap=regexprep(hObject.String{hObject.Value}, pattern, '');

%make indexing look nice
curSoloIdx=handles.outputRemapTable.UserData.CurrSelection; %current solo output chan selection
curModule=handles.outputRemapTable.UserData.outputRemapStruct{curSoloIdx}.Module;
%index of current module selecton
mIdx=hObject.Value;

%update the data struct of channel assignments
if isempty(mIdx)
    mIdx=1;  %for the fact that we are calling bpod a module in this gui
end
%update the data struct of channel assignments
selectedOutputModuleData=handles.outputRemapTable.UserData.availableOutputList.Module{mIdx};
if selectedOutputModuleData.Enabled==1 %module is still available
    %set the datastruct for this solo chan
    handles.outputRemapTable.UserData.outputRemapStruct{curSoloIdx}.Module=selectedOutputModuleData.Name;
else
    display('SoloPortRemapper::either this module is full, or not enabled. Choose another')
end

%change GUI strings as needed
if isempty(strfind(handles.outputRemapTable.UserData.outputRemapStruct...
        {handles.outputRemapTable.UserData.CurrSelection}.Chan,'HTML'))
    
    %%%change string for avaiable channels on module
    %by default, we will use the first channel
    chanString={handles.outputRemapTable.UserData.availableOutputList.Module{mIdx}.Channels.Names};
    
    htmlWrap=cellfun(@(x) ['<HTML><FONT color="#*">' x '</FONT></HTML>'],chanString,'UniformOutput',false);
    %htmlWrap=['<HTML><FONT color="#*">' chanString '</FONT></HTML>'];
    
    %get the color right...but just make black for now
    colorVect=[0 0 0]; %black
    htmlWrap=cellfun(@(x) strrep(x,'#*',['#' rgb2Hex(colorVect)]), htmlWrap,'UniformOutput',false);
    
    handles.bpodOutputNameList.String=htmlWrap;
    
    %%%change port string to match this channel
    portString=handles.outputRemapTable.UserData.availableOutputList.Module{mIdx}.Channels(1).Pins.Names;
    
    htmlWrap=cellfun(@(x) ['<HTML><FONT color="#*">' x '</FONT></HTML>'],portString,'UniformOutput',false);
    %get the color right...but just make black for now
    colorVect=[0 0 0]; %black
    htmlWrap=strrep(htmlWrap,'#*',['#' rgb2Hex(colorVect)]);
    
    handles.bpodOutputPortNumList.String=htmlWrap;
end
end

% --- Executes during object creation, after setting all properties.
function bpodOutputModuleList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to bpodOutputModuleList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%disable on creation since we havent selected a solo chan yet
set(hObject,'Enable','off');
set(hObject,'BackgroundColor',[0.75 0.75 0.75]);

end

% --- Executes on selection change in bpodOutputNameList.
function bpodOutputNameList_Callback(hObject, eventdata, handles)
% hObject    handle to bpodOutputNameList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns bpodOutputNameList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from bpodOutputNameList

global BpodSystem

%strip formatting from string
pattern= '<[^>]*>';
htmlUnwrap=regexprep(hObject.String{hObject.Value}, pattern, '');

%make indexing look nice
curSoloIdx=handles.outputRemapTable.UserData.CurrSelection; %current solo output chan selection
curModule=handles.outputRemapTable.UserData.outputRemapStruct{curSoloIdx}.Module;
%index for the module associated with the current solo channel

mIdx=find(strcmp(curModule,BpodSystem.Modules.Name));
%index of current channel selecton
selIdx=hObject.Value;

%update the data struct of channel assignments
if isempty(mIdx)
    mIdx=1;  %for the fact that we are calling bpod a module in this gui
end

%assigned this channel into the output remapping struct
handles.outputRemapTable.UserData.outputRemapStruct{curSoloIdx}.Chan=htmlUnwrap;

%set the channel assigned flag
handles.outputRemapTable.UserData.outputRemapStruct{curSoloIdx}.Assigned=1;

%change the string for the GUI port/pin list
if isempty(strfind(handles.outputRemapTable.UserData.outputRemapStruct...
        {handles.outputRemapTable.UserData.CurrSelection}.Chan,'HTML'))
    
    %%%string changes for channel name list
    
    %check if port is available, e.g. not already assigned and active
    if ~isempty(strfind(hObject.String{hObject.Value},'color="#000000"'))
        % if its black, we can assign
        %first make red
        %hObject.String{hObject.Value}=strrep(hObject.String{hObject.Value},'color="#000000"','color="#FF0000"');
        
        %set channel name for the currently selected solo channel
        handles.outputRemapTable.UserData.outputRemapStruct{handles.outputRemapTable.UserData.CurrSelection}.Chan=...
            hObject.String{hObject.Value};
        
    elseif ~isempty(strfind(hObject.String{hObject.Value},'color="#646464"'))
        %its gray
        display('SoloPortRemapper::cannot assign this channel, its inactive')
        
    elseif  ~isempty(strfind(hObject.String{hObject.Value},'color="#FF0000"'))
        %its red
        display('SoloPortRemapper::cannot assign this channel, its already been assigned')
    end
    
    %%%string changes for port/pin list
    
    %list the appropriate pins for the selected channel name
    pinString=handles.outputRemapTable.UserData.availableOutputList.Module{mIdx}.Channels(selIdx).Pins.Names;
    
    htmlWrap=cellfun(@(x) ['<HTML><FONT color="#*">' x '</FONT></HTML>'],pinString,'UniformOutput',false);
    %get the color right...but just make black for now
    colorVect=[0 0 0]; %black
    htmlWrap=strrep(htmlWrap,'#*',['#' rgb2Hex(colorVect)]);
    
    handles.bpodOutputPortNumList.Value=1; %weve changed the channel, so port no longer applies    
    %set the string
    handles.bpodOutputPortNumList.String=htmlWrap;
    
else
    display('SoloPortRemapper::this solo channel has aleady been remapped')
    %maybe give option here to replace the mapping?
end
end

% --- Executes during object creation, after setting all properties.
function bpodOutputNameList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to bpodOutputNameList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%disable on creation since we havent selected a solo chan yet
set(hObject,'Enable','off');
set(hObject,'BackgroundColor',[0.75 0.75 0.75]);

end

% --- Executes on selection change in bpodOutputPortNumList.
function bpodOutputPortNumList_Callback(hObject, eventdata, handles)
% hObject    handle to bpodOutputPortNumList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns bpodOutputPortNumList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from bpodOutputPortNumList

global BpodSystem

%strip formatting from string
pattern= '<[^>]*>';
htmlUnwrap=regexprep(hObject.String{hObject.Value}, pattern, '');

%make indexing look nice
curSoloIdx=handles.outputRemapTable.UserData.CurrSelection; %current solo output chan selection
curModule=handles.outputRemapTable.UserData.outputRemapStruct{curSoloIdx}.Module;
%index for the module associated with the current solo channel

mIdx=find(strcmp(curModule,BpodSystem.Modules.Name));
%index of current channel selecton
selIdx=hObject.Value;

%update the data struct of channel assignments
if isempty(mIdx)
    mIdx=1;  %for the fact that we are calling bpod a module in this gui
end

%assigned thispin into the output remapping struct
handles.outputRemapTable.UserData.outputRemapStruct{curSoloIdx}.Pin=htmlUnwrap;

%change string for pin liat GUI
if ~isempty(strfind(hObject.String{hObject.Value},'color="#000000"'))
    % if its black, we can assign
    %first make red
    hObject.String{hObject.Value}=strrep(hObject.String{hObject.Value},'color="#000000"','color="#FF0000"');
    
    %set channel name for the currently selected solo channel
    handles.outputRemapTable.UserData.outputRemapStruct{handles.outputRemapTable.UserData.CurrSelection}.Pin=...
        hObject.String{hObject.Value};
    
elseif ~isempty(strfind(hObject.String{hObject.Value},'color="#646464"'))
    %its gray
    display('SoloPortRemapper::cannot assign this channel, its inactive')
    
elseif  ~isempty(strfind(hObject.String{hObject.Value},'color="#FF0000"'))
    %its red
    display('SoloPortRemapper::cannot assign this channel, its already been assigned')
else
    %something is wrong if there are colors other than red, gray, and black
    
end
end

% --- Executes during object creation, after setting all properties.
function bpodOutputPortNumList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to bpodOutputPortNumList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%disable on creation since we havent selected a solo chan yet
set(hObject,'Enable','off');
set(hObject,'BackgroundColor',[0.75 0.75 0.75]);

end


%%%%%INPUT

% --- Executes on selection change in bpodInputModuleList.
function bpodInputModuleList_Callback(hObject, eventdata, handles)
% hObject    handle to bpodInputModuleList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns bpodInputModuleList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from bpodInputModuleList


global BpodSystem

%strip formatting from string
pattern= '<[^>]*>';
htmlUnwrap=regexprep(hObject.String{hObject.Value}, pattern, '');

%make indexing look nice
curSoloIdx=handles.inputRemapTable.UserData.CurrSelection; %current solo input chan selection
curModule=handles.inputRemapTable.UserData.inputRemapStruct{curSoloIdx}.Module;
%index of current module selecton
mIdx=hObject.Value;

%update the data struct of channel assignments
if isempty(mIdx)
    mIdx=1;  %for the fact that we are calling bpod a module in this gui
end
%update the data struct of channel assignments
selectedInputModuleData=handles.inputRemapTable.UserData.availableInputList.Module{mIdx};
if selectedInputModuleData.Enabled==1 %module is still available
    %set the datastruct for this solo chan
    handles.inputRemapTable.UserData.inputRemapStruct{curSoloIdx}.Module=selectedInputModuleData.Name;
else
    display('SoloPortRemapper::either this module is full, or not enabled. Choose another')
end

%change GUI strings as needed
if isempty(strfind(handles.inputRemapTable.UserData.inputRemapStruct...
        {handles.inputRemapTable.UserData.CurrSelection}.Chan,'HTML'))
    
    %%%change string for avaiable channels on module
    %by default, we will use the first channel
    chanString={handles.inputRemapTable.UserData.availableInputList.Module{mIdx}.Channels.Names};
    
    htmlWrap=cellfun(@(x) ['<HTML><FONT color="#*">' x '</FONT></HTML>'],chanString,'UniformOutput',false);
    %htmlWrap=['<HTML><FONT color="#*">' chanString '</FONT></HTML>'];
    
    %get the color right...but just make black for now
    colorVect=[0 0 0]; %black
    htmlWrap=cellfun(@(x) strrep(x,'#*',['#' rgb2Hex(colorVect)]), htmlWrap,'UniformOutput',false);
    
    handles.bpodInputNameList.String=htmlWrap;
    
    %%%change port string to match this channel
    portString=handles.inputRemapTable.UserData.availableInputList.Module{mIdx}.Channels(1).Pins.Names;
    
    htmlWrap=cellfun(@(x) ['<HTML><FONT color="#*">' x '</FONT></HTML>'],portString,'UniformOutput',false);
    %get the color right...but just make black for now
    colorVect=[0 0 0]; %black
    htmlWrap=strrep(htmlWrap,'#*',['#' rgb2Hex(colorVect)]);
    
    handles.bpodInputPortNumList.String=htmlWrap;
end
end

% --- Executes during object creation, after setting all properties.
function bpodInputModuleList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to bpodInputModuleList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%disable on creation since we havent selected a solo chan yet
set(hObject,'Enable','off');
set(hObject,'BackgroundColor',[0.75 0.75 0.75]);

end

% --- Executes on selection change in bpodInputNameList.
function bpodInputNameList_Callback(hObject, eventdata, handles)
% hObject    handle to bpodInputNameList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns bpodInputNameList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from bpodInputNameList

global BpodSystem



%strip formatting from string
pattern= '<[^>]*>';
htmlUnwrap=regexprep(hObject.String{hObject.Value}, pattern, '');

%make indexing look nice
curSoloIdx=handles.inputRemapTable.UserData.CurrSelection; %current solo input chan selection
curModule=handles.inputRemapTable.UserData.inputRemapStruct{curSoloIdx}.Module;
%index for the module associated with the current solo channel
mIdx=find(strcmp(curModule,BpodSystem.Modules.Name));
%index of current channel selecton
selIdx=hObject.Value;

%update the data struct of channel assignments
if isempty(mIdx)
    mIdx=1;  %for the fact that we are calling bpod a module in this gui
end


%assigned this channel into the input remapping struct
handles.inputRemapTable.UserData.inputRemapStruct{curSoloIdx}.Chan=htmlUnwrap;

%set the channel assigned flag
handles.inputRemapTable.UserData.inputRemapStruct{curSoloIdx}.Assigned=1;


%change the string for the GUI port/pin list

if isempty(strfind(handles.inputRemapTable.UserData.inputRemapStruct...
        {handles.inputRemapTable.UserData.CurrSelection}.Chan,'HTML'))
    
    %%%string changes for channel name list
    
    %check if port is available, e.g. not already assigned and active
    if ~isempty(strfind(hObject.String{hObject.Value},'color="#000000"'))
        % if its black, we can assign
        %first make red
        %hObject.String{hObject.Value}=strrep(hObject.String{hObject.Value},'color="#000000"','color="#FF0000"');
        
        %set channel name for the currently selected solo channel
        handles.inputRemapTable.UserData.inputRemapStruct{handles.inputRemapTable.UserData.CurrSelection}.Chan=...
            hObject.String{hObject.Value};
        
    elseif ~isempty(strfind(hObject.String{hObject.Value},'color="#646464"'))
        %its gray
        display('SoloPortRemapper::cannot assign this channel, its inactive')
        
    elseif  ~isempty(strfind(hObject.String{hObject.Value},'color="#FF0000"'))
        %its red
        display('SoloPortRemapper::cannot assign this channel, its already been assigned')
    end
    
    %%%string changes for port/pin list
    
    %list the appropriate pins for the selected channel name
    pinString=handles.inputRemapTable.UserData.availableInputList.Module{mIdx}.Channels(selIdx).Pins.Names;
    
    htmlWrap=cellfun(@(x) ['<HTML><FONT color="#*">' x '</FONT></HTML>'],pinString,'UniformOutput',false);
    %get the color right...but just make black for now
    colorVect=[0 0 0]; %black
    htmlWrap=strrep(htmlWrap,'#*',['#' rgb2Hex(colorVect)]);
    
    handles.bpodInputPortNumList.Value=1; %weve changed the channel, so port no longer applies    
    %set the string
    handles.bpodInputPortNumList.String=htmlWrap;
    
else
    display('SoloPortRemapper::this solo channel has aleady been remapped')
    %maybe give option here to replace the mapping?
end
end

% --- Executes during object creation, after setting all properties.
function bpodInputNameList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to bpodInputNameList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%disable on creation since we havent selected a solo chan yet
set(hObject,'Enable','off');
set(hObject,'BackgroundColor',[0.75 0.75 0.75]);

end

% --- Executes on selection change in bpodInputPortNumList.
function bpodInputPortNumList_Callback(hObject, eventdata, handles)
% hObject    handle to bpodInputPortNumList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns bpodInputPortNumList contents as cell array
%        contents{get(hObject,'Value')} returns selected item from bpodInputPortNumList

global BpodSystem

%strip formatting from string
pattern= '<[^>]*>';
htmlUnwrap=regexprep(hObject.String{hObject.Value}, pattern, '');

%make indexing look nice
curSoloIdx=handles.inputRemapTable.UserData.CurrSelection; %current solo input chan selection
curModule=handles.inputRemapTable.UserData.inputRemapStruct{curSoloIdx}.Module;
%index for the module associated with the current solo channel

mIdx=find(strcmp(curModule,BpodSystem.Modules.Name));
%index of current channel selecton
selIdx=hObject.Value;

%update the data struct of channel assignments
if isempty(mIdx)
    mIdx=1;  %for the fact that we are calling bpod a module in this gui
end

%assigned thispin into the input remapping struct
handles.inputRemapTable.UserData.inputRemapStruct{curSoloIdx}.Pin=htmlUnwrap;

%change string for pin liat GUI
if ~isempty(strfind(hObject.String{hObject.Value},'color="#000000"'))
    % if its black, we can assign
    %first make red
    hObject.String{hObject.Value}=strrep(hObject.String{hObject.Value},'color="#000000"','color="#FF0000"');
    
    %set channel name for the currently selected solo channel
    handles.inputRemapTable.UserData.inputRemapStruct{handles.inputRemapTable.UserData.CurrSelection}.Pin=...
        hObject.String{hObject.Value};
    
elseif ~isempty(strfind(hObject.String{hObject.Value},'color="#646464"'))
    %its gray
    display('SoloPortRemapper::cannot assign this channel, its inactive')
    
elseif  ~isempty(strfind(hObject.String{hObject.Value},'color="#FF0000"'))
    %its red
    display('SoloPortRemapper::cannot assign this channel, its already been assigned')
else
    %something is wrong if there are colors other than red, gray, and black
    
end
end

% --- Executes during object creation, after setting all properties.
function bpodInputPortNumList_CreateFcn(hObject, eventdata, handles)
% hObject    handle to bpodInputPortNumList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%disable on creation since we havent selected a solo chan yet
set(hObject,'Enable','off');
set(hObject,'BackgroundColor',[0.75 0.75 0.75]);

end

%%%%%%%%%%%%%%BUTTON DOWN FCNS

% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over bpodInputModuleList.
function bpodInputModuleList_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to bpodInputModuleList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
end

% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over bpodInputNameList.
function bpodInputNameList_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to bpodInputNameList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

end

% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over bpodInputPortNumList.
function bpodInputPortNumList_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to bpodInputPortNumList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
end

% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over bpodOutputModuleList.
function bpodOutputModuleList_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to bpodOutputModuleList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
end

% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over bpodOutputNameList.
function bpodOutputNameList_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to bpodOutputNameList (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
end

% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over bpodOutputPortNum.
function bpodOutputPortNumList_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to bpodOutputPortNum (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles an user data (see GUIDATA)
end

function hex=rgb2Hex(rgb)

%% If no value in RGB exceeds unity, scale from 0 to 255:
if max(rgb(:))<=1
    rgb = round(rgb*255);
else
    rgb = round(rgb);
end

%% Convert

hex(:,2:7) = reshape(sprintf('%02X',rgb.'),6,[]).';
hex(:,1) = '#';

end

% --- Creates and returns a handle to the GUI figure.
function h1 = SoloPortRemapper_export_LayoutFcn(policy)
% policy - create a new figure or use a singleton. 'new' or 'reuse'.


persistent hsingleton;
if strcmpi(policy, 'reuse') & ishandle(hsingleton)
    h1 = hsingleton;
    return;
end

%JPL - this cant be found inside package
%load SoloPortRemapper_export.mat %loads as mat{1} and mat{2}
mat{1}=logical([0 0 0 0]);
mat{2}=logical([0 0 0 0]);

appdata = [];
appdata.GUIDEOptions = struct(...
    'active_h', [], ...
    'taginfo', struct(...
    'figure', 2, ...
    'text', 10, ...
    'uitable', 3, ...
    'listbox', 7, ...
    'popupmenu', 2, ...
    'slider', 2, ...
    'pushbutton', 2), ...
    'override', 0, ...
    'release', [], ...
    'resize', 'none', ...
    'accessibility', 'callback', ...
    'mfile', 1, ...
    'callbacks', 1, ...
    'singleton', 1, ...
    'syscolorfig', 1, ...
    'blocking', 0, ...
    'lastSavedFile', '/Users/littlej/Documents/github/Bpod/Functions/+translateProtocol/SoloPortRemapper_export.m', ...
    'lastFilename', '/Users/littlej/Documents/github/Bpod/Functions/SoloPortRemapper_export.fig');
appdata.lastValidTag = 'figure1';
appdata.GUIDELayoutEditor = [];
appdata.initTags = struct(...
    'handle', [], ...
    'tag', 'figure1');

h1 = figure(...
    'Units','characters',...
    'Position',[181 46.8461538461538 134.833333333333 42.6153846153846],...
    'Visible',get(0,'defaultfigureVisible'),...
    'Color',get(0,'defaultfigureColor'),...
    'IntegerHandle','off',...
    'MenuBar','none',...
    'Name','SoloPortRemapper_export',...
    'NumberTitle','off',...
    'Resize','off',...
    'PaperPosition',get(0,'defaultfigurePaperPosition'),...
    'ScreenPixelsPerInchMode','manual',...
    'ParentMode','manual',...
    'HandleVisibility','callback',...
    'Tag','figure1',...
    'CreateFcn', {@local_CreateFcn, blanks(0), appdata} );

appdata = [];
appdata.lastValidTag = 'inputRemapTable';

h2 = uitable(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuitableFontUnits'),...
    'Units','characters',...
    'BackgroundColor',[1 1 1;0.941176470588235 0.941176470588235 0.941176470588235],...
    'ColumnName',{  'Solo Name'; 'Solo ID'; 'Solo Port'; 'Solo Type' },...
    'ColumnWidth',{  'auto' 'auto' 'auto' 'auto' },...
    'RowName',get(0,'defaultuitableRowName'),...
    'Position',[4.83333333333333 21.6153846153846 55.5 17.0769230769231],...
    'ColumnEditable',mat{1},...
    'ColumnFormat',{  [] [] [] [] },...
    'Data',{  blanks(0) blanks(0) blanks(0) blanks(0); blanks(0) blanks(0) blanks(0) blanks(0); blanks(0) blanks(0) blanks(0) blanks(0); blanks(0) blanks(0) blanks(0) blanks(0) },...
    'RearrangeableColumns',get(0,'defaultuitableRearrangeableColumns'),...
    'RowStriping',get(0,'defaultuitableRowStriping'),...
    'CellEditCallback',@(hObject,eventdata)SoloPortRemapper_export('inputRemapTable_CellEditCallback',hObject,eventdata,guidata(hObject)),...
    'CellSelectionCallback',@(hObject,eventdata)SoloPortRemapper_export('inputRemapTable_CellSelectionCallback',hObject,eventdata,guidata(hObject)),...
    'Children',[],...
    'ForegroundColor',get(0,'defaultuitableForegroundColor'),...
    'Enable',get(0,'defaultuitableEnable'),...
    'TooltipString',blanks(0),...
    'Visible',get(0,'defaultuitableVisible'),...
    'KeyPressFcn',blanks(0),...
    'KeyReleaseFcn',blanks(0),...
    'ParentMode','manual',...
    'HandleVisibility',get(0,'defaultuitableHandleVisibility'),...
    'CreateFcn', {@local_CreateFcn, @(hObject,eventdata)SoloPortRemapper_export('inputRemapTable_CreateFcn',hObject,eventdata,guidata(hObject)), appdata} ,...
    'DeleteFcn',blanks(0),...
    'ButtonDownFcn',blanks(0),...
    'Tag','inputRemapTable',...
    'UserData',[],...
    'FontSize',get(0,'defaultuitableFontSize'),...
    'FontName',get(0,'defaultuitableFontName'),...
    'FontAngle',get(0,'defaultuitableFontAngle'),...
    'FontWeight',get(0,'defaultuitableFontWeight'));

appdata = [];
appdata.lastValidTag = 'outputRemapTable';

h3 = uitable(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuitableFontUnits'),...
    'Units','characters',...
    'BackgroundColor',[1 1 1;0.941176470588235 0.941176470588235 0.941176470588235],...
    'ColumnName',{  'Solo Name'; 'Solo ID'; 'Solo Port'; 'Solo Type' },...
    'ColumnWidth',{  'auto' 'auto' 'auto' 'auto' },...
    'RowName',get(0,'defaultuitableRowName'),...
    'Position',[6.33333333333333 0.230769230769231 55.5 17.0769230769231],...
    'ColumnEditable',mat{2},...
    'ColumnFormat',{  [] [] [] [] },...
    'Data',{  blanks(0) blanks(0) blanks(0) blanks(0); blanks(0) blanks(0) blanks(0) blanks(0); blanks(0) blanks(0) blanks(0) blanks(0); blanks(0) blanks(0) blanks(0) blanks(0) },...
    'RearrangeableColumns',get(0,'defaultuitableRearrangeableColumns'),...
    'RowStriping',get(0,'defaultuitableRowStriping'),...
    'CellEditCallback',@(hObject,eventdata)SoloPortRemapper_export('outputRemapTable_CellEditCallback',hObject,eventdata,guidata(hObject)),...
    'CellSelectionCallback',@(hObject,eventdata)SoloPortRemapper_export('outputRemapTable_CellSelectionCallback',hObject,eventdata,guidata(hObject)),...
    'Children',[],...
    'ForegroundColor',get(0,'defaultuitableForegroundColor'),...
    'Enable',get(0,'defaultuitableEnable'),...
    'TooltipString',blanks(0),...
    'Visible',get(0,'defaultuitableVisible'),...
    'KeyPressFcn',blanks(0),...
    'KeyReleaseFcn',blanks(0),...
    'ParentMode','manual',...
    'HandleVisibility',get(0,'defaultuitableHandleVisibility'),...
    'CreateFcn', {@local_CreateFcn, @(hObject,eventdata)SoloPortRemapper_export('outputRemapTable_CreateFcn',hObject,eventdata,guidata(hObject)), appdata} ,...
    'DeleteFcn',blanks(0),...
    'ButtonDownFcn',blanks(0),...
    'Tag','outputRemapTable',...
    'UserData',[],...
    'FontSize',get(0,'defaultuitableFontSize'),...
    'FontName',get(0,'defaultuitableFontName'),...
    'FontAngle',get(0,'defaultuitableFontAngle'),...
    'FontWeight',get(0,'defaultuitableFontWeight'));

appdata = [];
appdata.lastValidTag = 'bpodOutputModuleList';

h4 = uicontrol(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String',{  'Listbox' },...
    'Style','listbox',...
    'Value',1,...
    'ValueMode',get(0,'defaultuicontrolValueMode'),...
    'Position',[64.8333333333333 0.230769230769231 20.1666666666667 16.8461538461538],...
    'Callback',@(hObject,eventdata)SoloPortRemapper_export('bpodOutputModuleList_Callback',hObject,eventdata,guidata(hObject)),...
    'Children',[],...
    'ParentMode','manual',...
    'CreateFcn', {@local_CreateFcn, @(hObject,eventdata)SoloPortRemapper_export('bpodOutputModuleList_CreateFcn',hObject,eventdata,guidata(hObject)), appdata} ,...
    'ButtonDownFcn',@(hObject,eventdata)SoloPortRemapper_export('bpodOutputModuleList_ButtonDownFcn',hObject,eventdata,guidata(hObject)),...
    'Tag','bpodOutputModuleList');

appdata = [];
appdata.lastValidTag = 'bpodOutputNameList';

h5 = uicontrol(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String',{  'Listbox' },...
    'Style','listbox',...
    'Value',1,...
    'ValueMode',get(0,'defaultuicontrolValueMode'),...
    'Position',[89.5 0.230769230769231 20.1666666666667 16.8461538461538],...
    'Callback',@(hObject,eventdata)SoloPortRemapper_export('bpodOutputNameList_Callback',hObject,eventdata,guidata(hObject)),...
    'Children',[],...
    'KeyPressFcn',blanks(0),...
    'ParentMode','manual',...
    'CreateFcn', {@local_CreateFcn, @(hObject,eventdata)SoloPortRemapper_export('bpodOutputNameList_CreateFcn',hObject,eventdata,guidata(hObject)), appdata} ,...
    'DeleteFcn',blanks(0),...
    'ButtonDownFcn',@(hObject,eventdata)SoloPortRemapper_export('bpodOutputNameList_ButtonDownFcn',hObject,eventdata,guidata(hObject)),...
    'Tag','bpodOutputNameList');

appdata = [];
appdata.lastValidTag = 'bpodOutputPortNumList';

h6 = uicontrol(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String',{  'Listbox' },...
    'Style','listbox',...
    'Value',1,...
    'ValueMode',get(0,'defaultuicontrolValueMode'),...
    'Position',[113 0.230769230769231 20.1666666666667 16.8461538461538],...
    'Callback',@(hObject,eventdata)SoloPortRemapper_export('bpodOutputPortNumList_Callback',hObject,eventdata,guidata(hObject)),...
    'Children',[],...
    'KeyPressFcn',blanks(0),...
    'ParentMode','manual',...
    'CreateFcn', {@local_CreateFcn, @(hObject,eventdata)SoloPortRemapper_export('bpodOutputPortNumList_CreateFcn',hObject,eventdata,guidata(hObject)), appdata} ,...
    'DeleteFcn',blanks(0),...
    'ButtonDownFcn',@(hObject,eventdata)SoloPortRemapper_export('bpodOutputPortNumList_ButtonDownFcn',hObject,eventdata,guidata(hObject)),...
    'Tag','bpodOutputPortNumList');

appdata = [];
appdata.lastValidTag = 'bpodInputModuleList';

h7 = uicontrol(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String',{  'Listbox' },...
    'Style','listbox',...
    'Value',1,...
    'ValueMode',get(0,'defaultuicontrolValueMode'),...
    'Position',[63 21.8461538461538 20.1666666666667 16.8461538461538],...
    'Callback',@(hObject,eventdata)SoloPortRemapper_export('bpodInputModuleList_Callback',hObject,eventdata,guidata(hObject)),...
    'Children',[],...
    'KeyPressFcn',blanks(0),...
    'ParentMode','manual',...
    'CreateFcn', {@local_CreateFcn, @(hObject,eventdata)SoloPortRemapper_export('bpodInputModuleList_CreateFcn',hObject,eventdata,guidata(hObject)), appdata} ,...
    'DeleteFcn',blanks(0),...
    'ButtonDownFcn',@(hObject,eventdata)SoloPortRemapper_export('bpodInputModuleList_ButtonDownFcn',hObject,eventdata,guidata(hObject)),...
    'Tag','bpodInputModuleList');

appdata = [];
appdata.lastValidTag = 'bpodInputNameList';

h8 = uicontrol(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String',{  'Listbox' },...
    'Style','listbox',...
    'Value',1,...
    'ValueMode',get(0,'defaultuicontrolValueMode'),...
    'Position',[88 21.8461538461538 20.1666666666667 16.8461538461538],...
    'Callback',@(hObject,eventdata)SoloPortRemapper_export('bpodInputNameList_Callback',hObject,eventdata,guidata(hObject)),...
    'Children',[],...
    'KeyPressFcn',blanks(0),...
    'ParentMode','manual',...
    'CreateFcn', {@local_CreateFcn, @(hObject,eventdata)SoloPortRemapper_export('bpodInputNameList_CreateFcn',hObject,eventdata,guidata(hObject)), appdata} ,...
    'DeleteFcn',blanks(0),...
    'ButtonDownFcn',@(hObject,eventdata)SoloPortRemapper_export('bpodInputNameList_ButtonDownFcn',hObject,eventdata,guidata(hObject)),...
    'Tag','bpodInputNameList');

appdata = [];
appdata.lastValidTag = 'bpodInputPortNumList';

h9 = uicontrol(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String',{  'Listbox' },...
    'Style','listbox',...
    'Value',1,...
    'ValueMode',get(0,'defaultuicontrolValueMode'),...
    'Position',[113 21.8461538461538 20.1666666666667 16.8461538461538],...
    'Callback',@(hObject,eventdata)SoloPortRemapper_export('bpodInputPortNumList_Callback',hObject,eventdata,guidata(hObject)),...
    'Children',[],...
    'KeyPressFcn',blanks(0),...
    'ParentMode','manual',...
    'CreateFcn', {@local_CreateFcn, @(hObject,eventdata)SoloPortRemapper_export('bpodInputPortNumList_CreateFcn',hObject,eventdata,guidata(hObject)), appdata} ,...
    'DeleteFcn',blanks(0),...
    'ButtonDownFcn',@(hObject,eventdata)SoloPortRemapper_export('bpodInputPortNumList_ButtonDownFcn',hObject,eventdata,guidata(hObject)),...
    'Tag','bpodInputPortNumList');

appdata = [];
appdata.lastValidTag = 'inputText';

h10 = uicontrol(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String','Input Remapping',...
    'Style','text',...
    'Position',[2.83333333333333 39.5384615384615 26.5 2.46153846153846],...
    'Children',[],...
    'ParentMode','manual',...
    'CreateFcn', {@local_CreateFcn, blanks(0), appdata} ,...
    'Tag','inputText',...
    'FontSize',20);

appdata = [];
appdata.lastValidTag = 'outputText';

h11 = uicontrol(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String','Output Remapping',...
    'Style','text',...
    'Position',[3.5 18.2307692307692 31.5 2.46153846153846],...
    'Children',[],...
    'ParentMode','manual',...
    'CreateFcn', {@local_CreateFcn, blanks(0), appdata} ,...
    'DeleteFcn',blanks(0),...
    'ButtonDownFcn',blanks(0),...
    'Tag','outputText',...
    'FontSize',20);

appdata = [];
appdata.lastValidTag = 'text4';

h12 = uicontrol(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String','Bpod Name',...
    'Style','text',...
    'Position',[87 39 14.3333333333333 1],...
    'Children',[],...
    'ParentMode','manual',...
    'CreateFcn', {@local_CreateFcn, blanks(0), appdata} ,...
    'Tag','text4');

appdata = [];
appdata.lastValidTag = 'text5';

h13 = uicontrol(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String','Bpod Module',...
    'Style','text',...
    'Position',[64.6666666666667 38.9230769230769 14.3333333333333 1],...
    'Children',[],...
    'ParentMode','manual',...
    'CreateFcn', {@local_CreateFcn, blanks(0), appdata} ,...
    'DeleteFcn',blanks(0),...
    'ButtonDownFcn',blanks(0),...
    'Tag','text5');

appdata = [];
appdata.lastValidTag = 'text6';

h14 = uicontrol(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String','Bpod Port',...
    'Style','text',...
    'Position',[110.833333333333 39.0769230769231 14.3333333333333 1],...
    'Children',[],...
    'ParentMode','manual',...
    'CreateFcn', {@local_CreateFcn, blanks(0), appdata} ,...
    'DeleteFcn',blanks(0),...
    'ButtonDownFcn',blanks(0),...
    'Tag','text6');

appdata = [];
appdata.lastValidTag = 'text7';

h15 = uicontrol(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String','Bpod Name',...
    'Style','text',...
    'Position',[87.1666666666667 17.3846153846154 14.3333333333333 1],...
    'Children',[],...
    'ParentMode','manual',...
    'CreateFcn', {@local_CreateFcn, blanks(0), appdata} ,...
    'DeleteFcn',blanks(0),...
    'ButtonDownFcn',blanks(0),...
    'Tag','text7');

appdata = [];
appdata.lastValidTag = 'text8';

h16 = uicontrol(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String','Bpod Module',...
    'Style','text',...
    'Position',[64.8333333333333 17.3076923076923 14.3333333333333 1],...
    'Children',[],...
    'ParentMode','manual',...
    'CreateFcn', {@local_CreateFcn, blanks(0), appdata} ,...
    'DeleteFcn',blanks(0),...
    'ButtonDownFcn',blanks(0),...
    'Tag','text8');

appdata = [];
appdata.lastValidTag = 'text9';

h17 = uicontrol(...
    'Parent',h1,...
    'FontUnits',get(0,'defaultuicontrolFontUnits'),...
    'Units','characters',...
    'String','Bpod Port',...
    'Style','text',...
    'Position',[111 17.4615384615385 14.3333333333333 1],...
    'Children',[],...
    'ParentMode','manual',...
    'CreateFcn', {@local_CreateFcn, blanks(0), appdata} ,...
    'DeleteFcn',blanks(0),...
    'ButtonDownFcn',blanks(0),...
    'Tag','text9');


appdata = [];
appdata.lastValidTag = 'doneButton';

h18 = uicontrol(...
'Parent',h1,...
'FontUnits',get(0,'defaultuicontrolFontUnits'),...
'Units','characters',...
'String',{  'Done' },...
'Style',get(0,'defaultuicontrolStyle'),...
'Position',[38.8333333333333 17.692307692307692 21.1666666666667 3.38461538461539],...
'Callback',@(hObject,eventdata)SoloPortRemapper_export('doneButton_Callback',hObject,eventdata,guidata(hObject)),...
'Children',[],...
'ParentMode','manual',...
'Tag','doneButton',...
'CreateFcn', {@local_CreateFcn, blanks(0), appdata} );

hsingleton = h1;
end


% --- Handles default GUIDE GUI creation and callback dispatch
function varargout = gui_mainfcn(gui_State, varargin)

gui_StateFields =  {'gui_Name'
    'gui_Singleton'
    'gui_OpeningFcn'
    'gui_OutputFcn'
    'gui_LayoutFcn'
    'gui_Callback'};
gui_Mfile = '';
for i=1:length(gui_StateFields)
    if ~isfield(gui_State, gui_StateFields{i})
        error(message('MATLAB:guide:StateFieldNotFound', gui_StateFields{ i }, gui_Mfile));
    elseif isequal(gui_StateFields{i}, 'gui_Name')
        gui_Mfile = [gui_State.(gui_StateFields{i}), '.m'];
    end
end

numargin = length(varargin);

if numargin == 0
    % SOLOPORTREMAPPER_EXPORT
    % create the GUI only if we are not in the process of loading it
    % already
    gui_Create = true;
elseif local_isInvokeActiveXCallback(gui_State, varargin{:})
    % SOLOPORTREMAPPER_EXPORT(ACTIVEX,...)
    vin{1} = gui_State.gui_Name;
    vin{2} = [get(varargin{1}.Peer, 'Tag'), '_', varargin{end}];
    vin{3} = varargin{1};
    vin{4} = varargin{end-1};
    vin{5} = guidata(varargin{1}.Peer);
    feval(vin{:});
    return;
elseif local_isInvokeHGCallback(gui_State, varargin{:})
    % SOLOPORTREMAPPER_EXPORT('CALLBACK',hObject,eventData,handles,...)
    gui_Create = false;
else
    % SOLOPORTREMAPPER_EXPORT(...)
    % create the GUI and hand varargin to the openingfcn
    gui_Create = true;
end

if ~gui_Create
    % In design time, we need to mark all components possibly created in
    % the coming callback evaluation as non-serializable. This way, they
    % will not be brought into GUIDE and not be saved in the figure file
    % when running/saving the GUI from GUIDE.
    designEval = false;
    if (numargin>1 && ishghandle(varargin{2}))
        fig = varargin{2};
        while ~isempty(fig) && ~ishghandle(fig,'figure')
            fig = get(fig,'parent');
        end
        
        designEval = isappdata(0,'CreatingGUIDEFigure') || (isscalar(fig)&&isprop(fig,'GUIDEFigure'));
    end
    
    if designEval
        beforeChildren = findall(fig);
    end
    
    % evaluate the callback now
    varargin{1} = gui_State.gui_Callback;
    if nargout
        [varargout{1:nargout}] = feval(varargin{:});
    else
        feval(varargin{:});
    end
    
    % Set serializable of objects created in the above callback to off in
    % design time. Need to check whether figure handle is still valid in
    % case the figure is deleted during the callback dispatching.
    if designEval && ishghandle(fig)
        set(setdiff(findall(fig),beforeChildren), 'Serializable','off');
    end
else
    if gui_State.gui_Singleton
        gui_SingletonOpt = 'reuse';
    else
        gui_SingletonOpt = 'new';
    end
    
    % Check user passing 'visible' P/V pair first so that its value can be
    % used by oepnfig to prevent flickering
    gui_Visible = 'auto';
    gui_VisibleInput = '';
    for index=1:2:length(varargin)
        if length(varargin) == index || ~ischar(varargin{index})
            break;
        end
        
        % Recognize 'visible' P/V pair
        len1 = min(length('visible'),length(varargin{index}));
        len2 = min(length('off'),length(varargin{index+1}));
        if ischar(varargin{index+1}) && strncmpi(varargin{index},'visible',len1) && len2 > 1
            if strncmpi(varargin{index+1},'off',len2)
                gui_Visible = 'invisible';
                gui_VisibleInput = 'off';
            elseif strncmpi(varargin{index+1},'on',len2)
                gui_Visible = 'visible';
                gui_VisibleInput = 'on';
            end
        end
    end
    
    % Open fig file with stored settings.  Note: This executes all component
    % specific CreateFunctions with an empty HANDLES structure.
    
    
    % Do feval on layout code in m-file if it exists
    gui_Exported = ~isempty(gui_State.gui_LayoutFcn);
    % this application data is used to indicate the running mode of a GUIDE
    % GUI to distinguish it from the design mode of the GUI in GUIDE. it is
    % only used by actxproxy at this time.
    setappdata(0,genvarname(['OpenGuiWhenRunning_', gui_State.gui_Name]),1);
    if gui_Exported
        gui_hFigure = feval(gui_State.gui_LayoutFcn, gui_SingletonOpt);
        
        % make figure invisible here so that the visibility of figure is
        % consistent in OpeningFcn in the exported GUI case
        if isempty(gui_VisibleInput)
            gui_VisibleInput = get(gui_hFigure,'Visible');
        end
        set(gui_hFigure,'Visible','off')
        
        % openfig (called by local_openfig below) does this for guis without
        % the LayoutFcn. Be sure to do it here so guis show up on screen.
        movegui(gui_hFigure,'onscreen');
    else
        gui_hFigure = local_openfig(gui_State.gui_Name, gui_SingletonOpt, gui_Visible);
        % If the figure has InGUIInitialization it was not completely created
        % on the last pass.  Delete this handle and try again.
        if isappdata(gui_hFigure, 'InGUIInitialization')
            delete(gui_hFigure);
            gui_hFigure = local_openfig(gui_State.gui_Name, gui_SingletonOpt, gui_Visible);
        end
    end
    if isappdata(0, genvarname(['OpenGuiWhenRunning_', gui_State.gui_Name]))
        rmappdata(0,genvarname(['OpenGuiWhenRunning_', gui_State.gui_Name]));
    end
    
    % Set flag to indicate starting GUI initialization
    setappdata(gui_hFigure,'InGUIInitialization',1);
    
    % Fetch GUIDE Application options
    gui_Options = getappdata(gui_hFigure,'GUIDEOptions');
    % Singleton setting in the GUI M-file takes priority if different
    gui_Options.singleton = gui_State.gui_Singleton;
    
    if ~isappdata(gui_hFigure,'GUIOnScreen')
        % Adjust background color
        if gui_Options.syscolorfig
            set(gui_hFigure,'Color', get(0,'DefaultUicontrolBackgroundColor'));
        end
        
        % Generate HANDLES structure and store with GUIDATA. If there is
        % user set GUI data already, keep that also.
        data = guidata(gui_hFigure);
        handles = guihandles(gui_hFigure);
        if ~isempty(handles)
            if isempty(data)
                data = handles;
            else
                names = fieldnames(handles);
                for k=1:length(names)
                    data.(char(names(k)))=handles.(char(names(k)));
                end
            end
        end
        guidata(gui_hFigure, data);
    end
    
    % Apply input P/V pairs other than 'visible'
    for index=1:2:length(varargin)
        if length(varargin) == index || ~ischar(varargin{index})
            break;
        end
        
        len1 = min(length('visible'),length(varargin{index}));
        if ~strncmpi(varargin{index},'visible',len1)
            try set(gui_hFigure, varargin{index}, varargin{index+1}), catch break, end
        end
    end
    
    % If handle visibility is set to 'callback', turn it on until finished
    % with OpeningFcn
    gui_HandleVisibility = get(gui_hFigure,'HandleVisibility');
    if strcmp(gui_HandleVisibility, 'callback')
        set(gui_hFigure,'HandleVisibility', 'on');
    end
    
    feval(gui_State.gui_OpeningFcn, gui_hFigure, [], guidata(gui_hFigure), varargin{:});
    
    if isscalar(gui_hFigure) && ishghandle(gui_hFigure)
        % Handle the default callbacks of predefined toolbar tools in this
        % GUI, if any
        guidemfile('restoreToolbarToolPredefinedCallback',gui_hFigure);
        
        % Update handle visibility
        set(gui_hFigure,'HandleVisibility', gui_HandleVisibility);
        
        % Call openfig again to pick up the saved visibility or apply the
        % one passed in from the P/V pairs
        if ~gui_Exported
            gui_hFigure = local_openfig(gui_State.gui_Name, 'reuse',gui_Visible);
        elseif ~isempty(gui_VisibleInput)
            set(gui_hFigure,'Visible',gui_VisibleInput);
        end
        if strcmpi(get(gui_hFigure, 'Visible'), 'on')
            figure(gui_hFigure);
            
            if gui_Options.singleton
                setappdata(gui_hFigure,'GUIOnScreen', 1);
            end
        end
        
        % Done with GUI initialization
        if isappdata(gui_hFigure,'InGUIInitialization')
            rmappdata(gui_hFigure,'InGUIInitialization');
        end
        
        % If handle visibility is set to 'callback', turn it on until
        % finished with OutputFcn
        gui_HandleVisibility = get(gui_hFigure,'HandleVisibility');
        if strcmp(gui_HandleVisibility, 'callback')
            set(gui_hFigure,'HandleVisibility', 'on');
        end
        gui_Handles = guidata(gui_hFigure);
    else
        gui_Handles = [];
    end
    
    if nargout
        [varargout{1:nargout}] = feval(gui_State.gui_OutputFcn, gui_hFigure, [], gui_Handles);
    else
        feval(gui_State.gui_OutputFcn, gui_hFigure, [], gui_Handles);
    end
    
    if isscalar(gui_hFigure) && ishghandle(gui_hFigure)
        set(gui_hFigure,'HandleVisibility', gui_HandleVisibility);
    end
end
end

function gui_hFigure = local_openfig(name, singleton, visible)

% openfig with three arguments was new from R13. Try to call that first, if
% failed, try the old openfig.
if nargin('openfig') == 2
    % OPENFIG did not accept 3rd input argument until R13,
    % toggle default figure visible to prevent the figure
    % from showing up too soon.
    gui_OldDefaultVisible = get(0,'defaultFigureVisible');
    set(0,'defaultFigureVisible','off');
    gui_hFigure = matlab.hg.internal.openfigLegacy(name, singleton);
    set(0,'defaultFigureVisible',gui_OldDefaultVisible);
else
    % Call version of openfig that accepts 'auto' option"
    gui_hFigure = matlab.hg.internal.openfigLegacy(name, singleton, visible);
    %     %workaround for CreateFcn not called to create ActiveX
    %         peers=findobj(findall(allchild(gui_hFigure)),'type','uicontrol','style','text');
    %         for i=1:length(peers)
    %             if isappdata(peers(i),'Control')
    %                 actxproxy(peers(i));
    %             end
    %         end
end
end

function result = local_isInvokeActiveXCallback(gui_State, varargin)

try
    result = ispc && iscom(varargin{1}) ...
        && isequal(varargin{1},gcbo);
catch
    result = false;
end
end


%JPL - this has some temporary features until the mapping between modules
%and channels is a bit more fleshed out
function getInputChansAndPinsForModule(module)
global BpodSystem

switch module
    case ''
        
    case 'Bpod'
        
    case 'Bpod_AnalogOutput'
        
    case 'Bpod_AnalogInput'
        
    otherwise
        display('SoloPortRemapper:: Dont know this module type')
end

end


% --- Executes on button press in doneButton.
function doneButton_Callback(hObject, eventdata, handles)
% hObject    handle to doneButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global BpodSystem
%% check and see that there are multiply-assigned ports
%If not, flash a warning

%---first the inputs
inchanport=cell(1,numel(handles.inputRemapTable.UserData.inputRemapStruct));
for h=1:1:numel(handles.inputRemapTable.UserData.inputRemapStruct)
    inchanport{h}=[handles.inputRemapTable.UserData.inputRemapStruct{h}.Chan ...
        handles.inputRemapTable.UserData.inputRemapStruct{h}.Pin];
end

inchanport=inchanport(cellfun(@(x) ~isempty(x),inchanport));
inputOverlapChans={};
if numel(unique(inchanport)) ~= numel(inchanport)
    [un idx_last idx] = unique(inchanport);
    unique_idx = accumarray(idx(:),(1:length(idx))',[],@(x) {sort(x)});
    
    inputOverlapChans={handles.inputRemapTable.UserData.inputRemapStruct{cellfun(@(x) numel(x)>1, unique_idx )}.Chan};
    inputOverlapPins={handles.inputRemapTable.UserData.inputRemapStruct{cellfun(@(x) numel(x)>1, unique_idx )}.Pin};
end

instring='';
for b=1:1:numel(inputOverlapChans)
    if b==numel(inputOverlapChans)
        instring=[instring 'Chan ' inputOverlapChans{b} ', Pin ' inputOverlapPins{b} '\n\n'];
    else
        instring=[instring 'Chan ' inputOverlapChans{b} ', Pin ' inputOverlapPins{b} '\n'];
    end
end

%---then the outputs
outchanport=cell(1,numel(handles.outputRemapTable.UserData.outputRemapStruct));
for h=1:1:numel(handles.outputRemapTable.UserData.outputRemapStruct)
    outchanport{h}=[handles.outputRemapTable.UserData.outputRemapStruct{h}.Chan ...
        handles.outputRemapTable.UserData.outputRemapStruct{h}.Pin];
end

outchanport=outchanport(cellfun(@(x) ~isempty(x),outchanport));
outOverlapChans={};
if numel(unique(outchanport)) ~= numel(outchanport)
    [un idx_last idx] = unique(outchanport);
    unique_idx = accumarray(idx(:),(1:length(idx))',[],@(x) {sort(x)});
    
    outputOverlapChans={handles.outputRemapTable.UserData.outputRemapStruct{cellfun(@(x) numel(x)>1, unique_idx )}.Chan};
    outputOverlapPins={handles.outputRemapTable.UserData.outputRemapStruct{cellfun(@(x) numel(x)>1, unique_idx )}.Pin};
end

outstring='';
for b=1:1:numel(outOverlapChans)
    if b==numel(outOverlapChans)
        outstring=[outstring 'Chan ' outputOverlapChans{b} ', Pin ' outputOverlapPins{b} '\n\n'];
    else
        outstring=[outstring 'Chan ' outputOverlapChans{b} ', Pin ' outputOverlapPins{b} '\n'];
    end
end

if ~strcmp(instring, '') || ~strcmp(outstring, '') 
    prompt=sprintf(['Warning! The following Solo INPUT channels are multiply assigned:\n\n       '...
        instring...
        'Warning! The following Solo OUTPUT channels have not yet been assigned:\n\n       '...
        outstring...
        '\n Do you still want to be done (yes/no)? \n']);
    
    answer = inputdlg(prompt, 'Unassigned Solo Channels');
    
end

%% check and see that all Solo channels have been assigned a channel and pin. 
%If not, flash a warning

%inputs
unassignedInputString={};
unassignedInput=zeros(1,numel(handles.inputRemapTable.UserData.inputRemapStruct));
for i=1:1:numel(handles.inputRemapTable.UserData.inputRemapStruct)
    if handles.inputRemapTable.UserData.inputRemapStruct{i}.Assigned==0
        unassignedInput(i)=1;
        unassignedInputString=[unassignedInputString; handles.inputRemapTable.UserData.inputRemapStruct{i}.SoloName];
    end
end

%outputs
unassignedOutputString={};
unassignedOutput=zeros(1,numel(handles.outputRemapTable.UserData.outputRemapStruct));
for i=1:1:numel(handles.outputRemapTable.UserData.outputRemapStruct)
    if handles.outputRemapTable.UserData.outputRemapStruct{i}.Assigned==0
        unassignedOutput(i)=1;
        unassignedOutputString=[unassignedOutputString; handles.outputRemapTable.UserData.outputRemapStruct{i}.SoloName];
    end
end

understood=0;
answer='';
while understood==0;
    if any(unassignedInput) || any(unassignedOutput)
        %create string for unassigned channel display
        tab='       ';
        
        instring='';
        for b=1:1:numel(unassignedInputString)
            if b==numel(unassignedInputString)
                instring=[instring unassignedInputString{b} '\n\n'];
            else
                instring=[instring unassignedInputString{b} '\n' tab];
            end
        end
        
        outstring='';
        for b=1:1:numel(unassignedOutputString)
            if b==numel(unassignedOutputString)
                outstring=[outstring unassignedOutputString{b} '\n\n'];
            else
                outstring=[outstring unassignedOutputString{b} '\n' tab];
            end
        end
        
        prompt=sprintf(['Warning! The following Solo INPUT channels have not yet been assigned:\n\n       '...
            instring...
            'Warning! The following Solo OUTPUT channels have not yet been assigned:\n\n       '...
            outstring...
            '\n Do you still want to be done (yes/no)? \n']);
        
        answer = inputdlg(prompt, 'Unassigned Solo Channels');
        
        if strcmp(answer,'yes')
            understood=1;
            
            %return a data structure with the mappings
            
            BpodSystem.ProtocolTranslation.soloRemapInput=handles.inputRemapTable.UserData.inputRemapStruct;
            BpodSystem.ProtocolTranslation.soloRemapOutput=handles.outputRemapTable.UserData.outputRemapStruct;
            
            close(hObject.Parent) 
        elseif strcmp(answer,'no')
            understood=1;
            %just continue
        else
            understood=0;
        end
    else
        %return a data structure with the mappings
        
        BpodSystem.ProtocolTranslation.soloRemapInput=handles.inputRemapTable.UserData.inputRemapStruct;
        BpodSystem.ProtocolTranslation.soloRemapOutput=handles.outputRemapTable.UserData.outputRemapStruct;
        
        understood=1;
        
        close(hObject.Parent) 

    end
end
end


% --- Set application data first then calling the CreateFcn. 
function local_CreateFcn(hObject, eventdata, createfcn, appdata)

if ~isempty(appdata)
   names = fieldnames(appdata);
   for i=1:length(names)
       name = char(names(i));
       setappdata(hObject, name, getfield(appdata,name));
   end
end

if ~isempty(createfcn)
   if isa(createfcn,'function_handle')
       createfcn(hObject, eventdata);
   else
       eval(createfcn);
   end
end
end



function result = local_isInvokeHGCallback(gui_State, varargin)

try
    fhandle = functions(gui_State.gui_Callback);
    result = ~isempty(findstr(gui_State.gui_Name,fhandle.file)) || ...
             (ischar(varargin{1}) ...
             && isequal(ishghandle(varargin{2}), 1) ...
             && (~isempty(strfind(varargin{1},[get(varargin{2}, 'Tag'), '_'])) || ...
                ~isempty(strfind(varargin{1}, '_CreateFcn'))) );
catch
    result = false;
end


end