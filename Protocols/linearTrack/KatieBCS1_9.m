function varargout = KatieBCS(varargin)
delete(instrfind)
clc
global gui

idn = 'Katie BCS Matlab version 1.9';

% Serial communication (with BCS) setup
s=serial('COM4');
s.baudrate=115200;
s.flowcontrol='none';
s.inputbuffersize=10000;
s.bytesavailablefcnmode = 'terminator';
s.bytesavailablefcn=@receiveData; % receive data callback function
set(s,'Terminator','CR/LF');
set(s,'DataBits',8);
set(s,'StopBits',2);
set(s,'DataTerminalReady','off');
fopen(s);

% Main window definitions
gui.fig = figure('tag','KatieBCS','numbertitle','off','menubar','none','name',idn,'visible','off', ...
                 'position',[400,150,600,650]);
set(gui.fig,'CloseRequestFcn',@closefcn);
set(gui.fig,'Visible','off');
gui.recOn = false;

% Create the file pulldown menue
make_file_menu(gui.fig)

% Reset the BCS
set(s,'DataTerminalReady','on');

phase = 1;
rewardTime = 500; % default manual water delivery time

%one click on the wheel encoder (in mm)
click = 4*pi*25.4/100;

% Trial phase variables allocation
tr(25).duration = [];
tr(25).type = [];
tr(25).length = [];
tr(25).dist1 = [];
tr(25).dist1En = [];
tr(25).dist2 = [];
tr(25).dist2En = [];
tr(25).dist3 = [];
tr(25).dist3En = [];
tr(25).speed = [];
tr(25).pump = [];
tr(25).led = [];
tr(25).lcd = [];
tr(25).next = [];
tr(25).reflector = [];
tr(25).laps = [];

% Default trial phase definition
tr(1).duration = 1; % Phase duration (in minutes)
tr(1).type = 1; % Phase type - distance, time, position or timed laps 
tr(1).length = 1000; % Run length (distance or time depending on phase type
tr(1).dist1 = 100;
tr(1).dist1En = 0;
tr(1).dist2 = 100;
tr(1).dist2En = 0;
tr(1).dist3 = 100;
tr(1).dist3En = 0;
tr(1).speed = 100; % Minimum speed needed to accumulate distance or time
tr(1).pump = 1000; % Water delivery time (in milliseconds)
tr(1).led = 1; % Light state - 1=OFF, 2=ON
tr(1).lcd = 1; % LCD state - 1=OFF, 2=ON
tr(1).next = 1; % Next phase
tr(1).reflector = 1; % Reflector (used in timed laps)
tr(1).laps = 1; % Laps

trial.phases = 1; % Number of phases in the current trial
trial.dirty = 0; % 0=no trial changes, 1=trial has changed (used for trial saving to file)
trial.loaded = 0; % 0=trial not loaded to BCS, 1=trial loaded to BCS
trial.fileName = '';
trial.pathName = '';

% ---------------------------------------------
% Start of GUI widgets setup

% record and start buttons
record = uicontrol('Parent', gui.fig,'Style','togglebutton','Units','normalized','HandleVisibility','callback', ...
                      'BackGroundColor','green', ...
                      'Value',0,'Position',[0.2 0.05 0.2 0.05],'String','Recording off','Callback', @hRecordingButtonCallback);
start = uicontrol('Parent', gui.fig,'Style','togglebutton','Units','normalized','HandleVisibility','callback', ...
                      'BackGroundColor','green', ...
                      'Value',0,'Position',[0.6 0.05 0.2 0.05],'String','Trial idle','Callback', @hRunButtonCallback);

% trial and rig panels
trialPanel = uipanel('Parent',gui.fig,'Title','Trial Phase Definition','Position',[.05 .15 .4 .8]);
rigPanel = uipanel('Parent',gui.fig,'Title','Rig','Position',[.50 .15 .45 .8]);


% *** trial panel widgets ***

phase = uicontrol(trialPanel,'Style','text',...
                'String','Phase:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.1 .94 .3 .04]);

phasePopup = uicontrol(trialPanel,'Style','popupmenu',...
                'String',{' Phase 1'},...
                'Value',1,...
                'Units','normalized',...
                'Callback',@phasePopupCallback,...
                'Position',[.4 .95 .3 .04]);

phaseDuration = uicontrol(trialPanel,'Style','text',...
                'String','Duration:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.1 .88 .3 .04]);

phaseDurationEdit = uicontrol(trialPanel,'Style','edit',...
                'String',num2str(tr(1).duration),...
                'Units','normalized',...
                'Callback',@phaseDurationCallback,...
                'Position',[.4 .89 .3 .04]);

phaseDurationUnit = uicontrol(trialPanel,'Style','text',...
                'String','min.',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.75 .88 .15 .04]);

nextPhase = uicontrol(trialPanel,'Style','text',...
                'String','Next Phase:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.1 .82 .3 .04]);

nextPhasePopup = uicontrol(trialPanel,'Style','popupmenu',...
                'String',{' Phase 1'},...
                'Value',1,...
                'Units','normalized',...
                'Callback',@nextPhasePopupCallback,...
                'Position',[.4 .83 .3 .04]);

% trial type selection
trialType = uibuttongroup('Parent',trialPanel,'Title','Type','Position',[.1 .61 .8 .20]);
distType = uicontrol(trialType,'Style','radiobutton','String','Distance',...
                'Units','normalized',...
                'Position',[.1 .75 .6 .18]);
timeType = uicontrol(trialType,'Style','radiobutton','String','Time',...
                'Units','normalized',...
                'Position',[.1 .55 .6 .18]);
posType = uicontrol(trialType,'Style','radiobutton','String','Position',...
                'Units','normalized',...
                'Position',[.1 .35 .6 .18]);
newType = uicontrol(trialType,'Style','radiobutton','String','Timed Laps',...
                'Units','normalized',...
                'Position',[.1 .15 .6 .18]);
set(trialType,'SelectionChangeFcn',@typeselcbk);
if (tr(1).type == 1)
    set(trialType,'SelectedObject',distType);
elseif (tr(1).type == 2)
    set(trialType,'SelectedObject',timeType);
elseif (tr(1).type == 3)
    set(trialType,'SelectedObject',posType);
else
    set(trialType,'SelectedObject',newType);
end

% trial length selection
trialLength = uicontrol(trialPanel,'Style','text',...
                'String','Length:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.1 .53 .3 .04]);
trialLengthEdit = uicontrol(trialPanel,'Style','edit',...
                'String',num2str(tr(1).length),...
                'Units','normalized',...
                'Callback',@lengthEditCallback,...
                'Position',[.4 .54 .3 .04]);
trialLengthUnit = uicontrol(trialPanel,'Style','text',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.75 .53 .15 .04]);
if (tr(1).type == 1)
    set(trialLength,'String','Distance:');
    set(trialLengthUnit,'String','mm');
else
    set(trialLength,'String','Time:');
    set(trialLengthUnit,'String','mm');
end


trialDist1 = uicontrol(trialPanel,'Style','radiobutton',...
                'String','Position 1:',...
                'Units','normalized',...
                'Callback',@dist1SelCallback,...
                'HorizontalAlignment','left',...
                'Position',[.1 .54 .3 .04]);
trialDist1Edit = uicontrol(trialPanel,'Style','edit',...
                'String',num2str(tr(1).dist1),...
                'Units','normalized','Enable','off',...
                'Callback',@dist1EditCallback,...
                'Position',[.4 .54 .3 .04]);
trialDist1Unit = uicontrol(trialPanel,'Style','text',...
                'String','mm',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.75 .53 .15 .04]);

trialDist2 = uicontrol(trialPanel,'Style','radiobutton',...
                'String','Position 2:',...
                'Units','normalized',...
                'Callback',@dist2SelCallback,...
                'HorizontalAlignment','left',...
                'Position',[.1 .48 .3 .04]);
trialDist2Edit = uicontrol(trialPanel,'Style','edit',...
                'String',num2str(tr(1).dist2),...
                'Units','normalized','Enable','off',...
                'Callback',@dist2EditCallback,...
                'Position',[.4 .48 .3 .04]);
trialDist2Unit = uicontrol(trialPanel,'Style','text',...
                'String','mm',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.75 .47 .15 .04]);

trialDist3 = uicontrol(trialPanel,'Style','radiobutton',...
                'String','Position 3:',...
                'Units','normalized',...
                'Callback',@dist3SelCallback,...
                'HorizontalAlignment','left',...
                'Position',[.1 .42 .3 .04]);
trialDist3Edit = uicontrol(trialPanel,'Style','edit',...
                'String',num2str(tr(1).dist3),...
                'Units','normalized','Enable','off',...
                'Callback',@dist3EditCallback,...
                'Position',[.4 .42 .3 .04]);
trialDist3Unit = uicontrol(trialPanel,'Style','text',...
                'String','mm',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.75 .41 .15 .04]);

trialReflector = uicontrol(trialPanel,'Style','text',...
                'String','Reflector:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.1 .53 .3 .04]);
trialReflectorEdit = uicontrol(trialPanel,'Style','edit',...
                'String',num2str(tr(1).reflector),...
                'Units','normalized',...
                'Callback',@reflectorEditCallback,...
                'Position',[.4 .54 .3 .04]);

trialOffset = uicontrol(trialPanel,'Style','text',...
                'String','Offset:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.1 .47 .3 .04]);
trialOffsetEdit = uicontrol(trialPanel,'Style','edit',...
                'String',num2str(tr(1).dist1),...
                'Units','normalized',...
                'Callback',@dist1EditCallback,...
                'Position',[.4 .48 .3 .04]);
            
trialLaps = uicontrol(trialPanel,'Style','text',...
                'String','Laps:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.1 .41 .3 .04]);
trialLapsEdit = uicontrol(trialPanel,'Style','edit',...
                'String',num2str(tr(1).laps),...
                'Units','normalized',...
                'Callback',@lapsEditCallback,...
                'Position',[.4 .42 .3 .04]);
            
% trial minimum-speed selection
trialSpeed = uicontrol(trialPanel,'Style','text',...
                'String','Min speed:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.1 .47 .3 .04]);
trialSpeedEdit = uicontrol(trialPanel,'Style','edit',...
                'String',num2str(tr(1).speed),...
                'Units','normalized',...
                'Callback',@speedEditCallback,...
                'Position',[.4 .48 .3 .04]);
trialSpeedUnit = uicontrol(trialPanel,'Style','text',...
                'String','mm/s',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.75 .47 .15 .04]);
            
% trial water delivery time selection
trialPump = uicontrol(trialPanel,'Style','text',...
                'String','Water time:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.1 .34 .3 .04]);
trialPumpEdit = uicontrol(trialPanel,'Style','edit',...
                'String',num2str(tr(1).pump),...
                'Units','normalized',...
                'Callback',@pumpEditCallback,...
                'Position',[.4 .35 .3 .04]);
trialPumpUnit = uicontrol(trialPanel,'Style','text',...
                'String','ms',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.75 .34 .15 .04]);


trialLED = uicontrol(trialPanel,'Style','text',...
                'String','Cue Light:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.1 .27 .3 .04]);
trialLEDPopup = uicontrol(trialPanel,'Style','popupmenu',...
                'String',{' Off',' On'},...
                'Value',1,...
                'Units','normalized',...
                'Callback',@ledPopupCallback,...
                'Position',[.4 .28 .2 .04]);

trialLCD = uicontrol(trialPanel,'Style','text',...
                'String','LCD Monitor:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.1 .20 .3 .04]);
trialLCDPopup = uicontrol(trialPanel,'Style','popupmenu',...
                'String',{' Off',' On'},...
                'Value',1,...
                'Units','normalized',...
                'Callback',@lcdPopupCallback,...
                'Position',[.4 .21 .2 .04]);

% add phase button
addPhase = uicontrol(trialPanel,'Style','pushbutton','String','Add phase',...
                'Units','normalized',...
                'Callback', @addPhaseCallback,...
                'Position',[.05 .12 .4 .05]);

% delete phase button
deletePhase = uicontrol(trialPanel,'Style','pushbutton','String','Delete phase',...
                'Units','normalized','Enable','off',...
                'Callback', @deletePhaseCallback,...
                'Position',[.55 .12 .4 .05]);

% trial upload button
trialLoad = uicontrol(trialPanel,'Style','pushbutton','String','Upload trial',...
                'Units','normalized','Enable','off',...
                'Callback', @trialUploadCallback,...
                'Position',[.32 .04 .4 .05]);


% *** rig panel widgets ***

beamPanel = uipanel('Parent',rigPanel,'Title','Beams','Position',[.1 .8 .8 .20]);
beam1 = uicontrol(beamPanel,'Style','radiobutton','String','Beam1',...
                'Units','normalized',...
                'Enable','inactive',...
                'Position',[.1 .72 .3 .3]);
beam2 = uicontrol(beamPanel,'Style','radiobutton','String','Beam2',...
                'Units','normalized',...
                'Enable','inactive',...
                'Position',[.1 .42 .3 .3]);
beam3 = uicontrol(beamPanel,'Style','radiobutton','String','Beam3',...
                'Units','normalized',...
                'Enable','inactive',...
                'Position',[.1 .12 .3 .3]);

lickPanel = uipanel('Parent',rigPanel,'Title','Lickport','Position',[.1 .63 .8 .15]);
llp = uicontrol(lickPanel,'Style','radiobutton','String','Pump',...
                'Units','normalized',...
                'Enable','inactive',...
                'Position',[.1 .65 .3 .3]);
llb = uicontrol(lickPanel,'Style','radiobutton','String','Lick',...
                'Units','normalized',...
                'Enable','inactive',...
                'Position',[.1 .2 .3 .3]);

reward = uicontrol('Parent', lickPanel,'Style','pushbutton','Units','normalized','HandleVisibility','callback', ...
                 'Value',0,'Position',[0.35 0.6 0.25 0.4],'String','Reward','Callback', @hRewardButtonCallback);

rewardEdit = uicontrol(lickPanel,'Style','edit',...
                'String',num2str(rewardTime),...
                'Units','normalized',...
                'Callback',@rewardEditCallback,...
                'Position',[0.65 0.6 0.2 0.4]);
rewardUnit = uicontrol(lickPanel,'Style','text',...
                'String','ms',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.9 .70 .1 0.2]);


cuePanel = uipanel('Parent',rigPanel,'Title','Cue Status/Control','Position',[.1 .46 .8 .15]);

led_cue = uicontrol(cuePanel,'Style','radiobutton','String','Light',...
                'Units','normalized',...
                'Enable','inactive',...
                'Position',[.1 .65 .3 .3]);

led_manual = uicontrol('Parent', cuePanel,'Style','togglebutton','Units','normalized','HandleVisibility','callback', ...
                   'Value',0,'Position',[0.5 0.60 0.3 0.4],'String','Manual','Callback', @hManualButton1Callback);


lcd_cue = uicontrol(cuePanel,'Style','radiobutton','String','LCD',...
                'Units','normalized',...
                'Enable','inactive',...
                'Position',[.1 .2 .3 .3]);

lcd_manual = uicontrol('Parent', cuePanel,'Style','togglebutton','Units','normalized','HandleVisibility','callback', ...
                   'Value',0,'Position',[0.5 0.15 0.3 0.4],'String','Manual','Callback', @hManualButton2Callback);

treadPanel = uipanel('Parent',rigPanel,'Title','Treadmill','Position',[.1 .19 .8 .25]);
spt = uicontrol(treadPanel,'Style','text',...
                'String','Speed:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.1 .65 .3 .3]);
speedv = uicontrol(treadPanel,'Style','text',...
                'String','0',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.5 .65 .3 .3]);
spu = uicontrol(treadPanel,'Style','text',...
                'String','mm/s',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.75 .65 .25 .3]);
drt = uicontrol(treadPanel,'Style','text',...
                'String','Dir:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.1 .45 .3 .3]);
dfw = uicontrol(treadPanel,'Style','radiobutton','String','FW',...
                'Units','normalized',...
                'Enable','inactive',...
                'Position',[.47 .52 .25 .3]);
dbw = uicontrol(treadPanel,'Style','radiobutton','String','BW',...
                'Units','normalized',...
                'Enable','inactive',...
                'Position',[.75 .52 .25 .3]);
distt = uicontrol(treadPanel,'Style','text',...
                'String','Dist. FW:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.1 .22 .3 .3]);
distccw = uicontrol(treadPanel,'Style','text',...
                'String','0',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.5 .22 .3 .3]);
distu = uicontrol(treadPanel,'Style','text',...
                'String','mm',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.75 .22 .25 .3]);
timet = uicontrol(treadPanel,'Style','text',...
                'String','Time FW:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.1 .00 .3 .3]);
timeccw = uicontrol(treadPanel,'Style','text',...
                'String','0',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.5 .00 .3 .3]);
timeu = uicontrol(treadPanel,'Style','text',...
                'String','ms',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.75 .00 .25 .3]);

trialPhase = uicontrol(rigPanel,'Style','text',...
                'String','Trial phase:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.2 .1 .3 .05]);

trialPhaseValue = uicontrol(rigPanel,'Style','text',...
                'String','1',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.6 .1 .15 .05]);

trialPhaseR = uicontrol(rigPanel,'Style','text',...
                'String','Time remaining:',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.2 .05 .3 .05]);

trialPhaseRValue = uicontrol(rigPanel,'Style','text',...
                'String','----',...
                'Units','normalized',...
                'HorizontalAlignment','left',...
                'Position',[.6 .05 .15 .05]);

% End of GUI widgets setup
% ---------------------------------------------

% Set initial widget visibility state

set(trialDist1,'Visible','off');
set(trialDist1Edit,'Visible','off');
set(trialDist1Unit,'Visible','off');
set(trialDist2,'Visible','off');
set(trialDist2Edit,'Visible','off');
set(trialDist2Unit,'Visible','off');
set(trialDist3,'Visible','off');
set(trialDist3Edit,'Visible','off');
set(trialDist3Unit,'Visible','off');
set(trialOffset,'Visible','off');
set(trialOffsetEdit,'Visible','off');
set(trialReflector,'Visible','off');
set(trialReflectorEdit,'Visible','off');
set(trialLaps,'Visible','off');
set(trialLapsEdit,'Visible','off');

% Show the GUI
set(gui.fig,'Visible','on');


% GUI callback functions

    %----------------------------------------------------------------------
    function setTrial(val)
        set(phaseDurationEdit, 'String',num2str(tr(val).duration));
        set(nextPhasePopup, 'Value', tr(val).next);
        if (tr(val).type == 1)
             set(trialType,'SelectedObject',distType);
        elseif (tr(val).type == 2)
            set(trialType,'SelectedObject',timeType);
        elseif (tr(val).type == 3)
            set(trialType,'SelectedObject',posType);
        else
            set(trialType,'SelectedObject',newType);
        end
        set(trialLengthEdit, 'String',num2str(tr(val).length));
        set(trialDist1Edit, 'String',num2str(tr(val).dist1));
        set(trialDist2Edit, 'String',num2str(tr(val).dist2));
        set(trialDist3Edit, 'String',num2str(tr(val).dist3));
        set(trialOffsetEdit, 'String',num2str(tr(val).dist1));
        set(trialReflectorEdit, 'String',num2str(tr(val).reflector));
        set(trialLapsEdit, 'String',num2str(tr(val).laps));
        set(trialSpeedEdit, 'String',num2str(tr(val).speed));
        set(trialPumpEdit, 'String',num2str(tr(val).pump));
        set(trialLEDPopup, 'Value', tr(val).led);
        set(trialLCDPopup, 'Value', tr(val).lcd);
        if (tr(val).dist1En == 0)
            set(trialDist1Edit,'Enable','off');
            set(trialDist1,'Value',0);
        else
            set(trialDist1Edit,'Enable','on');
            set(trialDist1,'Value',1);
        end
        if (tr(val).dist2En == 0)
            set(trialDist2Edit,'Enable','off');
            set(trialDist2,'Value',0);
        else
            set(trialDist2Edit,'Enable','on');
            set(trialDist2,'Value',1);
        end
        if (tr(val).dist3En == 0)
            set(trialDist3Edit,'Enable','off');
            set(trialDist3,'Value',0);
        else
            set(trialDist3Edit,'Enable','on');
            set(trialDist3,'Value',1);
        end
        if (tr(val).type == 1)
            set(trialLength,'String','Distance:');
            set(trialLengthUnit,'String','mm');
            set(trialLength,'Visible','on');
            set(trialLengthEdit,'Visible','on');
            set(trialLengthUnit,'Visible','on');
            set(trialSpeed,'Visible','on');
            set(trialSpeedEdit,'Visible','on');
            set(trialSpeedUnit,'Visible','on');
            set(trialDist1,'Visible','off');
            set(trialDist1Edit,'Visible','off');
            set(trialDist1Unit,'Visible','off');
            set(trialDist2,'Visible','off');
            set(trialDist2Edit,'Visible','off');
            set(trialDist2Unit,'Visible','off');
            set(trialDist3,'Visible','off');
            set(trialDist3Edit,'Visible','off');
            set(trialDist3Unit,'Visible','off');
            set(trialOffset,'Visible','off');
            set(trialOffsetEdit,'Visible','off');
            set(trialReflector,'Visible','off');
            set(trialReflectorEdit,'Visible','off');
            set(trialLaps,'Visible','off');
            set(trialLapsEdit,'Visible','off');
            set(trialLED,'Visible','on');
            set(trialLEDPopup,'Visible','on');
            set(trialLCD,'Visible','on');
            set(trialLCDPopup,'Visible','on');
        elseif (tr(val).type == 2)
            set(trialLength,'String','Time:');
            set(trialLengthUnit,'String','ms');
            set(trialLength,'Visible','on');
            set(trialLengthEdit,'Visible','on');
            set(trialLengthUnit,'Visible','on');
            set(trialSpeed,'Visible','on');
            set(trialSpeedEdit,'Visible','on');
            set(trialSpeedUnit,'Visible','on');
            set(trialDist1,'Visible','off');
            set(trialDist1Edit,'Visible','off');
            set(trialDist1Unit,'Visible','off');
            set(trialDist2,'Visible','off');
            set(trialDist2Edit,'Visible','off');
            set(trialDist2Unit,'Visible','off');
            set(trialDist3,'Visible','off');
            set(trialDist3Edit,'Visible','off');
            set(trialDist3Unit,'Visible','off');
            set(trialOffset,'Visible','off');
            set(trialOffsetEdit,'Visible','off');
            set(trialReflector,'Visible','off');
            set(trialReflectorEdit,'Visible','off');
            set(trialLaps,'Visible','off');
            set(trialLapsEdit,'Visible','off');
            set(trialLED,'Visible','on');
            set(trialLEDPopup,'Visible','on');
            set(trialLCD,'Visible','on');
            set(trialLCDPopup,'Visible','on');
        elseif (tr(val).type == 3)
            set(trialLength,'String','Distance:');
            set(trialLengthUnit,'String','mm');
            set(trialLength,'Visible','off');
            set(trialLengthEdit,'Visible','off');
            set(trialLengthUnit,'Visible','off');
            set(trialSpeed,'Visible','off');
            set(trialSpeedEdit,'Visible','off');
            set(trialSpeedUnit,'Visible','off');
            set(trialDist1,'Visible','on');
            set(trialDist1Edit,'Visible','on');
            set(trialDist1Unit,'Visible','on');
            set(trialDist2,'Visible','on');
            set(trialDist2Edit,'Visible','on');
            set(trialDist2Unit,'Visible','on');
            set(trialDist3,'Visible','on');
            set(trialDist3Edit,'Visible','on');
            set(trialDist3Unit,'Visible','on');
            set(trialOffset,'Visible','off');
            set(trialOffsetEdit,'Visible','off');
            set(trialReflector,'Visible','off');
            set(trialReflectorEdit,'Visible','off');
            set(trialLaps,'Visible','off');
            set(trialLapsEdit,'Visible','off');
            set(trialLED,'Visible','on');
            set(trialLEDPopup,'Visible','on');
            set(trialLCD,'Visible','on');
            set(trialLCDPopup,'Visible','on');
        else
            set(trialLength,'String','Distance:');
            set(trialLengthUnit,'String','mm');
            set(trialLength,'Visible','off');
            set(trialLengthEdit,'Visible','off');
            set(trialLengthUnit,'Visible','off');
            set(trialSpeed,'Visible','off');
            set(trialSpeedEdit,'Visible','off');
            set(trialSpeedUnit,'Visible','off');
            set(trialDist1,'Visible','off');
            set(trialDist1Edit,'Visible','off');
            set(trialDist1Unit,'Visible','off');
            set(trialDist2,'Visible','off');
            set(trialDist2Edit,'Visible','off');
            set(trialDist2Unit,'Visible','on');
            set(trialDist3,'Visible','off');
            set(trialDist3Edit,'Visible','off');
            set(trialDist3Unit,'Visible','off');
            set(trialOffset,'Visible','on');
            set(trialOffsetEdit,'Visible','on');
            set(trialReflector,'Visible','on');
            set(trialReflectorEdit,'Visible','on');
            set(trialLaps,'Visible','on');
            set(trialLapsEdit,'Visible','on');
            set(trialLED,'Visible','off');
            set(trialLEDPopup,'Visible','off');
            set(trialLCD,'Visible','off');
            set(trialLCDPopup,'Visible','off');
        end
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function phasePopupCallback(hObject, eventdata, handles)
        val = get(hObject,'Value');
        setTrial(val);
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function nextPhasePopupCallback(hObject, eventdata, handles)
        val = get(hObject,'Value');
        phase = get(phasePopup, 'Value');
        tr(phase).next = val;
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function phaseDurationCallback(hObject, eventdata, handles)
        [entry,status] = str2num(get(hObject,'string'));
        phase = get(phasePopup, 'Value');
        if (status)
            value = round(entry);
            if (value >= 0 && value <= 60)
                set(hObject,'String',num2str(value));
                tr(phase).duration = value;
                trial.dirty = 1;
                trial.loaded = 0;
                set(trialLoad,'Enable','on');
            else
                set(hObject,'String',num2str(tr(phase).duration));
            end
        else
            set(hObject,'String',num2str(tr(phase).duration));
        end
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function typeselcbk(source,eventdata)
        phase = get(phasePopup, 'Value');
        if (eventdata.NewValue == distType)
            tr(phase).type = 1;
            trial.dirty = 1;
            trial.loaded = 0;
            set(trialLoad,'Enable','on');
        elseif (eventdata.NewValue == timeType)
            tr(phase).type = 2;
            trial.dirty = 1;
            trial.loaded = 0;
            set(trialLoad,'Enable','on');
        elseif (eventdata.NewValue == posType)
            tr(phase).type = 3;
            trial.dirty = 1;
            trial.loaded = 0;
            set(trialLoad,'Enable','on');
        elseif (eventdata.NewValue == newType)
            tr(phase).type = 4;
            trial.dirty = 1;
            trial.loaded = 0;
            set(trialLoad,'Enable','on');
        end
        % Update the trial panel
        setTrial(phase);
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function lengthEditCallback(hObject, eventdata, handles)
        phase = get(phasePopup, 'Value');
        [entry,status] = str2num(get(hObject,'string'));
        if (status)
            value = round(entry);
            if (value >= 0 && value <= 1000000)
                set(hObject,'String',num2str(value));
                tr(phase).length = value;
                trial.dirty = 1;
                trial.loaded = 0;
                set(trialLoad,'Enable','on');
            else
                set(hObject,'String',num2str(tr(phase).length));
            end
        else
            set(hObject,'String',num2str(tr(phase).length));
        end
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function dist1SelCallback(hObject, eventdata, handles)
        phase = get(phasePopup, 'Value');
        button_state = get(hObject,'Value');
        if button_state == get(hObject,'Max')
            tr(phase).dist1En = 1;
            set(trialDist1Edit,'Enable','on');
        else
            tr(phase).dist1En = 0;
            set(trialDist1Edit,'Enable','off');
        end
        trial.dirty = 1;
        trial.loaded = 0;
        set(trialLoad,'Enable','on');
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function dist1EditCallback(hObject, eventdata, handles)
        phase = get(phasePopup, 'Value');
        [entry,status] = str2num(get(hObject,'string'));
        if (status)
            value = round(entry);
            if (value >= 0 && value <= 1000000)
                set(hObject,'String',num2str(value));
                tr(phase).dist1 = value;
                trial.dirty = 1;
                trial.loaded = 0;
                set(trialLoad,'Enable','on');
            else
                set(hObject,'String',num2str(tr(phase).dist1));
            end
        else
            set(hObject,'String',num2str(tr(phase).dist1));
        end
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function dist2SelCallback(hObject, eventdata, handles)
        phase = get(phasePopup, 'Value');
        button_state = get(hObject,'Value');
        if button_state == get(hObject,'Max')
            tr(phase).dist2En = 1;
            set(trialDist2Edit,'Enable','on');
        else
            tr(phase).dist2En = 0;
            set(trialDist2Edit,'Enable','off');
        end
        trial.dirty = 1;
        trial.loaded = 0;
        set(trialLoad,'Enable','on');
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function dist2EditCallback(hObject, eventdata, handles)
        phase = get(phasePopup, 'Value');
        [entry,status] = str2num(get(hObject,'string'));
        if (status)
            value = round(entry);
            if (value >= 0 && value <= 1000000)
                set(hObject,'String',num2str(value));
                tr(phase).dist2 = value;
                trial.dirty = 1;
                trial.loaded = 0;
                set(trialLoad,'Enable','on');
            else
                set(hObject,'String',num2str(tr(phase).dist2));
            end
        else
            set(hObject,'String',num2str(tr(phase).dist2));
        end
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function dist3SelCallback(hObject, eventdata, handles)
        phase = get(phasePopup, 'Value');
        button_state = get(hObject,'Value');
        if button_state == get(hObject,'Max')
            tr(phase).dist3En = 1;
            set(trialDist3Edit,'Enable','on');
        else
            tr(phase).dist3En = 0;
            set(trialDist3Edit,'Enable','off');
        end
        trial.dirty = 1;
        trial.loaded = 0;
        set(trialLoad,'Enable','on');
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function dist3EditCallback(hObject, eventdata, handles)
        phase = get(phasePopup, 'Value');
        [entry,status] = str2num(get(hObject,'string'));
        if (status)
            value = round(entry);
            if (value >= 0 && value <= 1000000)
                set(hObject,'String',num2str(value));
                tr(phase).dist3 = value;
                trial.dirty = 1;
                trial.loaded = 0;
                set(trialLoad,'Enable','on');
            else
                set(hObject,'String',num2str(tr(phase).dist3));
            end
        else
            set(hObject,'String',num2str(tr(phase).dist3));
        end
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function reflectorEditCallback(hObject, eventdata, handles)
        phase = get(phasePopup, 'Value');
        [entry,status] = str2num(get(hObject,'string'));
        if (status)
            value = round(entry);
            if (value >= 0 && value <= 3)
                set(hObject,'String',num2str(value));
                tr(phase).reflector = value;
                trial.dirty = 1;
                trial.loaded = 0;
                set(trialLoad,'Enable','on');
            else
                set(hObject,'String',num2str(tr(phase).reflector));
            end
        else
            set(hObject,'String',num2str(tr(phase).reflector));
        end
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function lapsEditCallback(hObject, eventdata, handles)
        phase = get(phasePopup, 'Value');
        [entry,status] = str2num(get(hObject,'string'));
        if (status)
            value = round(entry);
            if (value >= 0 && value <= 100)
                set(hObject,'String',num2str(value));
                tr(phase).laps = value;
                trial.dirty = 1;
                trial.loaded = 0;
                set(trialLoad,'Enable','on');
            else
                set(hObject,'String',num2str(tr(phase).laps));
            end
        else
            set(hObject,'String',num2str(tr(phase).laps));
        end
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function speedEditCallback(hObject, eventdata, handles)
        phase = get(phasePopup, 'Value');
        [entry,status] = str2num(get(hObject,'string'));
        if (status)
            value = round(entry);
            if (value >= 0 && value <= 10000)
                set(hObject,'String',num2str(value));
                tr(phase).speed = value;
                trial.dirty = 1;
                trial.loaded = 0;
                set(trialLoad,'Enable','on');
            else
                set(hObject,'String',num2str(tr(phase).speed));
            end
        else
            set(hObject,'String',num2str(tr(phase).speed));
        end
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function pumpEditCallback(hObject, eventdata, handles)
        phase = get(phasePopup, 'Value');
        [entry,status] = str2num(get(hObject,'string'));
        if (status)
            value = round(entry);
            if (value >= 0 && value <= 10000)
                set(hObject,'String',num2str(value));
                tr(phase).pump = value;
                trial.dirty = 1;
                trial.loaded = 0;
                set(trialLoad,'Enable','on');
            else
                set(hObject,'String',num2str(tr(phase).pump));
            end
        else
            set(hObject,'String',num2str(tr(phase).pump));
        end
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function ledPopupCallback(hObject, eventdata, handles)
        phase = get(phasePopup, 'Value');
        val = get(hObject,'Value');
        if (val ~= tr(phase).led)
            tr(phase).led = get(hObject,'Value');
            trial.dirty = 1;
            trial.loaded = 0;
            set(trialLoad,'Enable','on');
        end
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function lcdPopupCallback(hObject, eventdata, handles)
        phase = get(phasePopup, 'Value');
        val = get(hObject,'Value');
        if (val ~= tr(phase).lcd)
            tr(phase).lcd = get(hObject,'Value');
            trial.dirty = 1;
            trial.loaded = 0;
            set(trialLoad,'Enable','on');
        end
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function addPhaseCallback(Obj, evt)
        phase = get(phasePopup, 'Value');
        if (phase < trial.phases)
            for index = trial.phases:-1:phase+1
                for index2 = 1:trial.phases
                    if (tr(index2).next == index)
                        tr(index2).next = index + 1;
                    end
                end
            end
            for index = trial.phases:-1:phase+1
                tr(index+1) = tr(index);
            end
        end
        trial.phases = trial.phases + 1;
        phase = phase + 1;
        tr(phase).duration = 1;
        tr(phase).type = 1;
        tr(phase).length = 1000;
        tr(phase).dist1 = 100;
        tr(phase).dist1En = 0;
        tr(phase).dist2 = 100;
        tr(phase).dist2En = 0;
        tr(phase).dist3 = 100;
        tr(phase).dist3En = 0;
        tr(phase).speed = 100;
        tr(phase).pump = 1000;
        tr(phase).led = 1;
        tr(phase).lcd = 1;
        tr(phase).reflector = 1;
        tr(phase).laps = 1;
        tr(phase).next = tr(phase-1).next;
        tr(phase-1).next = phase;
        C1 = get(phasePopup, 'String');
        C2 = [C1 ; ' Phase ',num2str(trial.phases)];
        set(phasePopup, 'String', C2);
        set(phasePopup, 'Value', phase);
        C1 = get(nextPhasePopup, 'String');
        C2 = [C1 ; ' Phase ',num2str(trial.phases)];
        set(nextPhasePopup, 'String', C2);
        set(deletePhase, 'Enable', 'on');
        if (trial.phases == 25)
            set(addPhase, 'Enable', 'off');
        end
        setTrial(phase);
        trial.dirty = 1;
        trial.loaded = 0;
        set(trialLoad,'Enable','on');
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function deletePhaseCallback(Obj, evt)
        phase = get(phasePopup, 'Value');
        for index = 1:1:trial.phases
            if (tr(index).next == phase)
                if (tr(phase).next == phase)
                    tr(index).next = index;
                else
                    tr(index).next = tr(phase).next;
                end
            end
        end
        if (phase < trial.phases)
            for index = phase+1:trial.phases
                for index2 = 1:1:trial.phases
                    if (tr(index2).next == index)
                        tr(index2).next = index-1;
                    end
                end
                tr(index-1) = tr(index);
            end
        end

        C1 = get(phasePopup, 'String');
        C1(trial.phases,:) = [];
        set(phasePopup, 'String', C1);
        
        C1 = get(nextPhasePopup, 'String');
        C1(trial.phases,:) = [];
        set(nextPhasePopup, 'String', C1);

        trial.phases = trial.phases - 1;
        if (phase > trial.phases)
            phase = phase - 1;
        end
        set(phasePopup, 'Value', phase);
        set(addPhase, 'Enable', 'on');
        if (trial.phases == 1)
            set(deletePhase, 'Enable', 'off');
        end
        setTrial(phase);
        trial.dirty = 1;
        trial.loaded = 0;
        set(trialLoad,'Enable','on');
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function trialUploadCallback(Obj, evt)
        cmd = sprintf('phases,%u\r',trial.phases);
        fwrite(s,cmd);
        for index = 1:trial.phases
            cmd = sprintf('values,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u\r',...
                  index,...
                  tr(index).duration*60,...
                  tr(index).type,...
                  tr(index).length,...
                  round(tr(index).length/click),...
                  round(tr(index).dist1/click),...
                  tr(index).dist1En,...
                  round(tr(index).dist2/click),...
                  tr(index).dist2En,...
                  round(tr(index).dist3/click),...
                  tr(index).dist3En,...
                  round(tr(index).speed/click),...
                  tr(index).pump,...
                  tr(index).led,...
                  tr(index).lcd,...
                  tr(index).next,...
                  tr(index).reflector,...
                  tr(index).laps);
            fwrite(s,cmd);
            pause (.1);
        end
        trial.loaded = 1;
        set(trialLoad,'Enable','off');
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function hRecordingButtonCallback(hObject, eventdata)
        button_state = get(hObject,'Value');
        if button_state == get(hObject,'Max')
            % Toggle button is pressed-take appropriate action
            set(hObject,'BackgroundColor','red');
            set(hObject,'String','Recording on');
            fileN = sprintf('%s_%s.%s','trial',datestr(now,30),'txt');
            gui.logfileID = fopen(fileN,'w');
            gui.recOn = true;
        elseif button_state == get(hObject,'Min')
            % Toggle button is not pressed-take appropriate action
            set(hObject,'BackgroundColor','green');
            set(hObject,'String','Recording off');
            gui.recOn = false;
            fclose(gui.logfileID);
        end
    end
    %----------------------------------------------------------------------


    %----------------------------------------------------------------------
    function hRunButtonCallback(hObject, eventdata)
        button_state = get(hObject,'Value');
        if button_state == get(hObject,'Max')
            % Toggle button is pressed-take appropriate action
            if (trial.loaded == 0)
                cmd = sprintf('phases,%u\r',trial.phases);
                fwrite(s,cmd);
                for index = 1:trial.phases
                    cmd = sprintf('values,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u\r',...
                          index,...
                          tr(index).duration*60,...
                          tr(index).type,...
                          tr(index).length,...
                          round(tr(index).length/click),...
                          round(tr(index).dist1/click),...
                          tr(index).dist1En,...
                          round(tr(index).dist2/click),...
                          tr(index).dist2En,...
                          round(tr(index).dist3/click),...
                          tr(index).dist3En,...
                          round(tr(index).speed/click),...
                          tr(index).pump,...
                          tr(index).led,...
                          tr(index).lcd,...
                          tr(index).next,...
                          tr(index).reflector,...
                          tr(index).laps);
                    fwrite(s,cmd);
                end
                trial.loaded = 1;
                set(trialLoad,'Enable','off');
            end
            fwrite(s,sprintf('%s\r','start'));
        elseif button_state == get(hObject,'Min')
            % Toggle button is not pressed-take appropriate action
            fwrite(s,sprintf('%s\r','stop'));
        end
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function hRewardButtonCallback(hObject, eventdata)
        fwrite(s,sprintf('reward,%u\r',rewardTime));
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function rewardEditCallback(hObject, eventdata, handles)
        [entry,status] = str2num(get(hObject,'string'));
        if (status)
            value = round(entry);
            if (value >= 0 && value <= 10000)
                set(hObject,'String',num2str(value));
                rewardTime = value;
            else
                set(hObject,'String',num2str(rewardTime));
            end
        else
            set(hObject,'String',num2str(rewardTime));
        end
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function hManualButton1Callback(hObject, eventdata)
        button_state = get(hObject,'Value');
        if button_state == get(hObject,'Max')
            % Toggle button is pressed-take appropriate action
            fwrite(s,sprintf('%s\r','ledOn'));
        elseif button_state == get(hObject,'Min')
            % Toggle button is not pressed-take appropriate action
            fwrite(s,sprintf('%s\r','ledOff'));
        end
    end
    %----------------------------------------------------------------------

    %----------------------------------------------------------------------
    function hManualButton2Callback(hObject, eventdata)
        button_state = get(hObject,'Value');
        if button_state == get(hObject,'Max')
            % Toggle button is pressed-take appropriate action
            fwrite(s,sprintf('%s\r','lcdOn'));
        elseif button_state == get(hObject,'Min')
            % Toggle button is not pressed-take appropriate action
            fwrite(s,sprintf('%s\r','lcdOff'));
        end
    end
    %----------------------------------------------------------------------

% *** End of GUI callback functions ***


% Revceive data function
% Called every time a CR/LF terminated line is received from the BCS
    %----------------------------------------------------------------------
    function receiveData(obj,evnt)
        token = fscanf(s,'%s',5);
        if (strcmp('FREV,', token) == true)
            name = fscanf(s);
            set(gui.fig,'name',[idn ', ' name]);
            fwrite(s, sprintf('phases, 1\r'));
            cmd = sprintf('values,1,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u\r',...
                  tr(1).duration*60,...
                  tr(1).type,...
                  tr(1).length,...
                  round(tr(1).length/click),...
                  round(tr(1).dist1/click),...
                  tr(1).dist1En,...
                  round(tr(1).dist2/click),...
                  tr(1).dist2En,...
                  round(tr(1).dist3/click),...
                  tr(1).dist2En,...
                  round(tr(1).speed/click),...
                  tr(1).pump,...
                  tr(1).led,...
                  tr(1).lcd,...
                  tr(1).next,...
                  tr(1).reflector,...
                  tr(1).laps);
            fwrite(s,cmd);
            trial.loaded = 1;
            set(trialLoad,'Enable','off');
        elseif(strcmp('TRIA,', token) == true)
            inpline = fscanf(s);
            [tstamp,ttime,etype] = strread(inpline,'%u%u%u','delimiter',',');
            if (etype == 1)
                set(start,'BackgroundColor','red');
                set(start,'String','Trial running');
            elseif (etype == 2)
                set(start,'BackgroundColor','green');
                set(start,'String','Trial idle');
                set(trialPhaseValue, 'String', '1');
                set(trialPhaseRValue, 'String', '----');
            end
            if (gui.recOn == true)
                fprintf(gui.logfileID,'TRIAL,%s',inpline);
            end
        elseif(strcmp('BEAM,', token) == true)
            inpline = fscanf(s);
            [tstamp,ttime,ebb,estate] = strread(inpline,'%u%u%u%u','delimiter',',');
            if ebb == 1
                if estate == 0
                    set(beam1,'Value',1);
                else
                    set(beam1,'Value',0);
                end
            elseif ebb == 2
                if estate == 0
                    set(beam2,'Value',1);
                else
                    set(beam2,'Value',0);
                end
            elseif ebb == 3
                if estate == 0
                    set(beam3,'Value',1);
                else
                    set(beam3,'Value',0);
                end
            end
            if (gui.recOn == true)
                fprintf(gui.logfileID,'BEAM,%s',inpline);
            end
        elseif(strcmp('PUMP,', token) == true)
            inpline = fscanf(s);
            [tstamp,ttime,pstate] = strread(inpline,'%u%u%u','delimiter',',');
            if pstate == 1
                set(llp,'Value',1);
            else
                set(llp,'Value',0);
            end

            if (gui.recOn == true)
                fprintf(gui.logfileID,'PUMP,%s',inpline);
            end
        elseif(strcmp('LICK,', token) == true)
            inpline = fscanf(s);
            [tstamp,ttime,lstate] = strread(inpline,'%u%u%u','delimiter',',');
            if lstate == 1
                set(llb,'Value',1);
            else
                set(llb,'Value',0);
            end

            if (gui.recOn == true)
                fprintf(gui.logfileID,'LICK,%s',inpline);
            end    
        elseif(strcmp('TTLS,', token) == true)
            inpline = fscanf(s);
            if (gui.recOn == true)
                fprintf(gui.logfileID,'TTLINPUT,%s',inpline);
            end    
        elseif(strcmp('TREA,', token) == true)
            inpline = fscanf(s);
            [tstamp,ttime,tspeed,tdist,trtime] = strread(inpline,'%u%u%d%u%u','delimiter',',');
            convertedSpeed = round(tspeed * click);
            convertedDist = round(tdist * click);
            if (tspeed > 1)
                set(dbw,'Value',0);
                set(dfw,'Value',1);
                set(speedv,'String',num2str(convertedSpeed));
            elseif (tspeed < -1)
                set(dbw,'Value',1);
                set(dfw,'Value',0);
                set(speedv,'String',num2str(-convertedSpeed));
            else
                set(dbw,'Value',0);
                set(dfw,'Value',0);
                set(speedv,'String','0');    
            end
            set(distccw,'String',num2str(convertedDist));
            set(timeccw,'String',num2str(trtime));
            if (gui.recOn == true)
                fprintf(gui.logfileID,'TREADMILL,%u,%u,%d,%u,%u\n',tstamp,ttime,convertedSpeed,convertedDist,trtime);
            end        
        elseif(strcmp('CUEL,', token) == true)
            inpline = fscanf(s);
            [tstamp,ttime,pstate] = strread(inpline,'%u%u%u','delimiter',',');
            if pstate == 1
                set(led_cue,'Value',1);
            else
                set(led_cue,'Value',0);
            end

            if (gui.recOn == true)
                fprintf(gui.logfileID,'CUELIGHT,%s',inpline);
            end
        elseif(strcmp('LCDL,', token) == true)
            inpline = fscanf(s);
            [tstamp,ttime,pstate] = strread(inpline,'%u%u%u','delimiter',',');
            if pstate == 1
                set(lcd_cue,'Value',1);
            else
                set(lcd_cue,'Value',0);
            end

            if (gui.recOn == true)
                fprintf(gui.logfileID,'LCD,%s',inpline);
            end
        elseif(strcmp('SYNC,', token) == true)
            inpline = fscanf(s);
            [tstamp,ttime,phase,left] = strread(inpline,'%u%u%u%u','delimiter',',');
            
            minLeft = floor(left/60);
            secLeft = left - (minLeft * 60);

            set(trialPhaseValue, 'String', num2str(phase));
            set(trialPhaseRValue, 'String', sprintf('%d:%02d',minLeft,secLeft));

            if (gui.recOn == true)
                fprintf(gui.logfileID,'SYNC,%s',inpline);
            end        
        elseif(strcmp('MAXL,', token) == true)
            inpline = fscanf(s);
            [tstamp,ttime,ltime] = strread(inpline,'%u%u%u','delimiter',',');
            if (gui.recOn == true)
                fprintf(gui.logfileID,'MAXL,%s',inpline);
            end        
    
        else
            inpline = fscanf(s);
            if (gui.recOn == true)
                fprintf(gui.logfileID,'%s%s',token,inpline);
            end
        end
    end
    %----------------------------------------------------------------------



% *** menu functions ***

    %create menu
    %----------------------------------------------------------------------
    function make_file_menu(figure)
        % Creates File Menus for Open, Save, SaveAs and Quit

        mh = uimenu(figure,'Label','File');
        uimenu(mh,'Label','Open trial...', ...
               'Callback', @open);
        uimenu(mh,'Label','Save trial', ...
               'Callback',{@save});
        uimenu(mh,'Label','Save trial as...', ...
               'Callback',{@saveas});
        uimenu(mh,'Label','Quit', ...
               'Callback',@quit);
    end
    %----------------------------------------------------------------------

    % open
    %----------------------------------------------------------------------
    function open(hObject,eventdata)
        if (trial.dirty == 1)
            savefile = questdlg('Save current trial?', ...
                        'KatieBCS','Yes','Cancel','No','Yes');
            if strcmp(savefile,'Save')
                save(obj,evnt);
            elseif strcmp(savefile,'Cancel')
                return;
            end
        end
        trialFile = '';
        [fileName,pathName,filterIndex] = uigetfile('*.trl', ...
            'Select a trial',trialFile);
        if ~filterIndex         % No file was selected
            return
        else
            fullName = [pathName fileName];
            fh = fopen(fullName,'r');
            badFile = 0;
            count = 0;
            %load trial
            while ~feof(fh)
                line = fgetl(fh);
                if isempty(line) || ~ischar(line)
                    badFile = 1;
                    break
                end
                count = count + 1;
                [index,duration,type,length,dist1,dist1En,dist2,dist2En,dist3,dist3En,speed,pump,led,lcd,next,reflector,laps] = ...
                    strread(line,'%u%u%u%u%u%u%u%u%u%u%u%u%u%u%u%u%u','delimiter',',');
                if ((index ~= count) || (duration == 0) || (duration > 60) || ...
                    (type == 0) || (type > 4) || ...
                    (length == 0) || (length > 10000) || ...
                    (dist1 > 10000) || (dist2 > 10000) || (dist3 > 10000) || ...
                    (dist1En > 1) || (dist2En > 1) || (dist3En > 1) || ...
                    (reflector > 3) || (laps > 100) || ...
                    (speed > 1000) || (led == 0) || (led > 2))
                    badFile = 1;
                else
                    tr(index).duration = duration;
                    tr(index).type = type;
                    tr(index).length = length;
                    tr(index).dist1 = dist1;
                    tr(index).dist1En = dist1En;
                    tr(index).dist2 = dist2;
                    tr(index).dist2En = dist2En;
                    tr(index).dist3 = dist3;
                    tr(index).dist3En = dist3En;
                    tr(index).speed = speed;
                    tr(index).pump = pump;
                    tr(index).led = led;
                    tr(index).lcd = lcd;
                    tr(index).next = next;
                    tr(index).reflector = reflector;
                    tr(index).laps = laps;
                end 
            end

            if (badFile == 1)
                errordlg('Not a valid trial.','Cannot use this file','modal')  ;
                set(phasePopup, 'String', ' Phase 1');
                trial.phases = 1;
                tr(1).duration = 1;
                tr(1).type = 1;
                tr(1).length = 1000;
                tr(1).dist1 = 100;
                tr(1).dist1En = 0;
                tr(1).dist2 = 100;
                tr(1).dist2En = 0;
                tr(1).dist3 = 100;
                tr(1).dist3En = 0;
                tr(1).speed = 100;
                tr(1).pump = 1000;
                tr(1).led = 1;
                tr(1).lcd = 1;
                tr(1).next = 1;
                tr(1).reflector = 1;
                tr(1).laps = 1;
            else
                set(phasePopup, 'String', ' Phase 1');
                if (count > 1)
                    for (loop = 2:count)
                        C1 = get(phasePopup, 'String');
                        C2 = [C1 ; ' Phase ',num2str(loop)];
                        set(phasePopup, 'String', C2);
                        set(nextPhasePopup, 'String', C2);
                    end
                end
                trial.phases = count;
                trial.fileName = fileName;
                trial.pathName = pathName;
                trial.dirty = 0;
                trial.loaded = 0;
                set(trialLoad,'Enable','on');
            end
            set(phasePopup, 'Value', 1);
            setTrial(1);
            if (trial.phases < 25)
                set(addPhase, 'Enable', 'on');
            else
                set(addPhase, 'Enable', 'off');
            end
            if (trial.phases > 1)
                set(deletePhase, 'Enable', 'on');
            else
                set(deletePhase, 'Enable', 'off');
            end
            trial.dirty = 0;
            trial.loaded = 0;
            set(trialLoad,'Enable','on');
        end
    end
    %----------------------------------------------------------------------

    % save
    %----------------------------------------------------------------------
    function save(hObject,eventdata)
        fullName = [trial.pathName trial.fileName];
        if isempty(fullName) 
            [fileName,pathName,filterIndex] = uiputfile('*.trl', ...
                'Save trial');
            if ~filterIndex         % No file was selected
                return
            else
                fullName = [pathName fileName];
                fh = fopen(fullName,'w');
                for index = 1:trial.phases
                    fprintf(fh,'%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u\r',...
                          index,...
                          tr(index).duration,...
                          tr(index).type,...
                          tr(index).length,...
                          tr(index).dist1,...
                          tr(index).dist1En,...
                          tr(index).dist2,...
                          tr(index).dist2En,...
                          tr(index).dist3,...
                          tr(index).dist3En,...
                          tr(index).speed,...
                          tr(index).pump,...
                          tr(index).led,...
                          tr(index).lcd,...
                          tr(index).next,...
                          tr(index).reflector,...
                          tr(index).laps);
                end
                fclose(fh);
                trial.dirty = 0;
            end
        else
            fh = fopen(fullName,'w');
            for index = 1:trial.phases
                fprintf(fh,'%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u\r',...
                      index,...
                      tr(index).duration,...
                      tr(index).type,...
                      tr(index).length,...
                      tr(index).dist1,...
                      tr(index).dist1En,...
                      tr(index).dist2,...
                      tr(index).dist2En,...
                      tr(index).dist3,...
                      tr(index).dist3En,...
                      tr(index).speed,...
                      tr(index).pump,...
                      tr(index).led,...
                      tr(index).lcd,...
                      tr(index).next,...
                      tr(index).reflector,...
                      tr(index).laps);
            end
            fclose(fh);
            trial.dirty = 0;
        end
    end
    %----------------------------------------------------------------------

    % save-as
    %----------------------------------------------------------------------
    function saveas(hObject,eventdata)
        [fileName,pathName,filterIndex] = uiputfile('*.trl', ...
            'Save trial');
        if ~filterIndex         % No file was selected
            return
        else
            fullName = [pathName fileName];
            fh = fopen(fullName,'w');
            for index = 1:trial.phases
                fprintf(fh,'%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u\r',...
                      index,...
                      tr(index).duration,...
                      tr(index).type,...
                      tr(index).length,...
                      tr(index).dist1,...
                      tr(index).dist1En,...
                      tr(index).dist2,...
                      tr(index).dist2En,...
                      tr(index).dist3,...
                      tr(index).dist3En,...
                      tr(index).speed,...
                      tr(index).pump,...
                      tr(index).led,...
                      tr(index).lcd,...
                      tr(index).next,...
                      tr(index).reflector,...
                      tr(index).laps);
            end
            fclose(fh);
            trial.dirty = 0;
        end
    end
    %----------------------------------------------------------------------

    % quit
    %----------------------------------------------------------------------
    function quit (hObject,eventdata)
        if (trial.dirty == 1)
          savefile = questdlg('Save current trial before closing?', ...
                        'KatieBCS','Save','Cancel','Close','Save');
          if strcmp(savefile,'Save')
             save(hObject,eventdata);
          elseif strcmp(savefile,'Cancel')
              return;
          end
        end
        fclose('all');
        delete(s);
        delete(ancestor(hObject,'figure'));
    end
    %----------------------------------------------------------------------

    % GUI close function
    %----------------------------------------------------------------------
    function closefcn(obj,evnt)
        if (trial.dirty == 1)
          savefile = questdlg('Save current trial before closing?', ...
                        'KatieBCS','Save','Cancel','Close','Save');
          if strcmp(savefile,'Save')
             save(obj,evnt);
          elseif strcmp(savefile,'Cancel')
              return;
          end
        end
        fclose('all');
        delete(s);
        delete(obj);
    end
    %----------------------------------------------------------------------

end
