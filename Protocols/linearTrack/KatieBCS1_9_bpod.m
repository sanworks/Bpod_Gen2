function S = KatieBCS1_9_bpod(varargin)


global BpodSystem

idn = 'Katie BCS Matlab version 1.9';

action = varargin{1};

switch action
    case 'init'
        
        %%Internal Parameters
        phase = 1;
        rewardTime = 500; % default manual water delivery time
        
        %one click on the wheel encoder (in mm)
        click = 4*pi*25.4/100;
        
        % Trial phase variables allocation
        S.GUIMeta.tr_duration(25) = nan;
        S.GUIMeta.tr_type(25) = nan;
        S.GUIMeta.tr_length(25) = nan;
        S.GUIMeta.tr_dist1(25) = nan;
        S.GUIMeta.tr_dist1En(25) = nan;
        S.GUIMeta.tr_dist2(25) = nan;
        S.GUIMeta.tr_dist2En(25) = nan;
        S.GUIMeta.tr_dist3(25) = nan;
        S.GUIMeta.tr_dist3En(25) = nan;
        S.GUIMeta.tr_speed(25) = nan;
        S.GUIMeta.tr_pump(25) = nan;
        S.GUIMeta.tr_led(25) = nan;
        S.GUIMeta.tr_lcd(25) = nan;
        S.GUIMeta.tr_next(25) = nan;
        S.GUIMeta.tr_reflector(25) = nan;
        S.GUIMeta.tr_laps(25) = nan;
        
        % Default trial phase definition
        S.GUIMeta.tr_duration(1) = 1; % Phase duration (in minutes)
        S.GUIMeta.tr_type(1) = 1; % Phase type - distance, time, position or timed laps
        S.GUIMeta.tr_length(1) = 1000; % Run length (distance or time depending on phase type
        S.GUIMeta.tr_dist1(1) = 100;
        S.GUIMeta.tr_dist1En(1) = 0;
        S.GUIMeta.tr_dist2(1) = 100;
        S.GUIMeta.tr_dist2En(1) = 0;
        S.GUIMeta.tr_dist3(1) = 100;
        S.GUIMeta.tr_dist3En(1) = 0;
        S.GUIMeta.tr_speed(1) = 100; % Minimum speed needed to accumulate distance or time
        S.GUIMeta.tr_pump(1) = 1000; % Water delivery time (in milliseconds)
        S.GUIMeta.tr_led(1) = 1; % Light state - 1=OFF, 2=ON
        S.GUIMeta.tr_lcd(1) = 1; % LCD state - 1=OFF, 2=ON
        S.GUIMeta.tr_next(1) = 1; % Next phase
        S.GUIMeta.tr_reflector(1) = 1; % Reflector (used in timed laps)
        S.GUIMeta.tr_laps(1) = 1; % Laps
        
        S.GUIMeta.trial.phases = 1; % Number of phases in the current trial
        S.GUIMeta.trial_dirty = 0; % 0=no trial changes, 1=trial has changed (used for trial saving to file)
        S.GUIMeta.trial_loaded = 0; % 0=trial not loaded to BCS, 1=trial loaded to BCS
        S.GUIMeta.trial.fileName = '';
        S.GUIMeta.trial.pathName = '';
        
        % ---------------------------------------------
        % Start of GUI widgets setup
        
        
        % Main window definitions
        BpodSystem.ProtocolFigures.BCSFig = figure('tag','BCS','numbertitle','off','menubar','none','name',idn,'visible','off', ...
            'position',[400,150,600,650]);
        set(BpodSystem.ProtocolFigures.BCSFig,'CloseRequestFcn',@closefcn);
        set(BpodSystem.ProtocolFigures.BCSFig,'Visible','off');
        
        S.GUI.recOn = false;
        
        
        % Create the file pulldown menue
        make_file_menu(BpodSystem.ProtocolFigures.BCSFig)
        
        
        % record and start buttons
        BpodSystem.GUIHandles.BCS.record = uicontrol('Parent', BpodSystem.ProtocolFigures.BCSFig,'Style','togglebutton','Units','normalized','HandleVisibility','callback', ...
            'BackGroundColor','green', ...
            'Value',0,'Position',[0.2 0.05 0.2 0.05],'String','Recording off','Callback', @hRecordingButtonCallback);
        BpodSystem.GUIHandles.BCS.start = uicontrol('Parent', BpodSystem.ProtocolFigures.BCSFig,'Style','togglebutton','Units','normalized','HandleVisibility','callback', ...
            'BackGroundColor','green', ...
            'Value',0,'Position',[0.6 0.05 0.2 0.05],'String','Trial idle','Callback', @hRunButtonCallback);
        
        % trial and rig panels
        BpodSystem.GUIHandles.BCS.trialPanel = uipanel('Parent',BpodSystem.ProtocolFigures.BCSFig,'Title','Trial Phase Definition','Position',[.05 .15 .4 .8]);
        BpodSystem.GUIHandles.BCS.rigPanel = uipanel('Parent',BpodSystem.ProtocolFigures.BCSFig,'Title','Rig','Position',[.50 .15 .45 .8]);
        
        
        % *** trial panel widgets ***
        
        BpodSystem.GUIHandles.BCS.phase = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','Phase:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.1 .94 .3 .04]);
        
        BpodSystem.GUIHandles.BCS.phasePopup = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','popupmenu',...
            'String',{' Phase 1'},...
            'Value',1,...
            'Units','normalized',...
            'Callback',@phasePopupCallback,...
            'Position',[.4 .95 .3 .04]);
        
        BpodSystem.GUIHandles.BCS.phaseDuration = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','Duration:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.1 .88 .3 .04]);
        
        BpodSystem.GUIHandles.BCS.phaseDurationEdit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','edit',...
            'String',num2str(S.GUIMeta.tr_duration(1)),...
            'Units','normalized',...
            'Callback',@phaseDurationCallback,...
            'Position',[.4 .89 .3 .04]);
        
        BpodSystem.GUIHandles.BCS.phaseDurationUnit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','min.',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.75 .88 .15 .04]);
        
        BpodSystem.GUIHandles.BCS.nextPhase = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','Next Phase:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.1 .82 .3 .04]);
        
        BpodSystem.GUIHandles.BCS.nextPhasePopup = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','popupmenu',...
            'String',{' Phase 1'},...
            'Value',1,...
            'Units','normalized',...
            'Callback',@nextPhasePopupCallback,...
            'Position',[.4 .83 .3 .04]);
        
        % trial type selection
        BpodSystem.GUIHandles.BCS.trialType = uibuttongroup('Parent',BpodSystem.GUIHandles.BCS.trialPanel,'Title','Type','Position',[.1 .61 .8 .20]);
        BpodSystem.GUIHandles.BCS.distType = uicontrol(BpodSystem.GUIHandles.BCS.trialType,'Style','radiobutton','String','Distance',...
            'Units','normalized',...
            'Position',[.1 .75 .6 .18]);
        BpodSystem.GUIHandles.BCS.timeType = uicontrol(BpodSystem.GUIHandles.BCS.trialType,'Style','radiobutton','String','Time',...
            'Units','normalized',...
            'Position',[.1 .55 .6 .18]);
        BpodSystem.GUIHandles.BCS.posType = uicontrol(BpodSystem.GUIHandles.BCS.trialType,'Style','radiobutton','String','Position',...
            'Units','normalized',...
            'Position',[.1 .35 .6 .18]);
        BpodSystem.GUIHandles.BCS.newType = uicontrol(BpodSystem.GUIHandles.BCS.trialType,'Style','radiobutton','String','Timed Laps',...
            'Units','normalized',...
            'Position',[.1 .15 .6 .18]);
        set(BpodSystem.GUIHandles.BCS.trialType,'SelectionChangeFcn',@typeselcbk);
        if (S.GUIMeta.tr_type(1) == 1)
            set(BpodSystem.GUIHandles.BCS.trialType,'SelectedObject',BpodSystem.GUIHandles.BCS.distType);
        elseif (S.GUIMetatr_type(1) == 2)
            set(BpodSystem.GUIHandles.BCS.trialType,'SelectedObject',BpodSystem.GUIHandles.BCS.timeType);
        elseif (S.GUIMeta.tr_type(1) == 3)
            set(BpodSystem.GUIHandles.BCS.trialType,'SelectedObject',BpodSystem.GUIHandles.BCS.posType);
        else
            set(BpodSystem.GUIHandles.BCS.trialType,'SelectedObject',BpodSystem.GUIHandles.BCS.newType);
        end
        
        % trial length selection
        BpodSystem.GUIHandles.BCS.trialLength = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','Length:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.1 .53 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialLengthEdit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','edit',...
            'String',num2str(S.GUIMeta.tr_length(1)),...
            'Units','normalized',...
            'Callback',@lengthEditCallback,...
            'Position',[.4 .54 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialLengthUnit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.75 .53 .15 .04]);
        if (S.GUIMeta.tr_type(1) == 1)
            set(BpodSystem.GUIHandles.BCS.trialLength,'String','Distance:');
            set(BpodSystem.GUIHandles.BCS.trialLengthUnit,'String','mm');
        else
            set(BpodSystem.GUIHandles.BCS.trialLength,'String','Time:');
            set(BpodSystem.GUIHandles.BCS.trialLengthUnit,'String','mm');
        end
        
        
        BpodSystem.GUIHandles.BCS.trialDist1 = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','radiobutton',...
            'String','Position 1:',...
            'Units','normalized',...
            'Callback',@dist1SelCallback,...
            'HorizontalAlignment','left',...
            'Position',[.1 .54 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialDist1Edit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','edit',...
            'String',num2str(S.GUIMeta.tr_dist1(1)),...
            'Units','normalized','Enable','off',...
            'Callback',@dist1EditCallback,...
            'Position',[.4 .54 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialDist1Unit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','mm',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.75 .53 .15 .04]);
        
        BpodSystem.GUIHandles.BCS.trialDist2 = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','radiobutton',...
            'String','Position 2:',...
            'Units','normalized',...
            'Callback',@dist2SelCallback,...
            'HorizontalAlignment','left',...
            'Position',[.1 .48 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialDist2Edit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','edit',...
            'String',num2str(S.GUIMeta.tr_dist2(1)),...
            'Units','normalized','Enable','off',...
            'Callback',@dist2EditCallback,...
            'Position',[.4 .48 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialDist2Unit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','mm',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.75 .47 .15 .04]);
        
        BpodSystem.GUIHandles.BCS.trialDist3 = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','radiobutton',...
            'String','Position 3:',...
            'Units','normalized',...
            'Callback',@dist3SelCallback,...
            'HorizontalAlignment','left',...
            'Position',[.1 .42 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialDist3Edit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','edit',...
            'String',num2str(S.GUIMeta.tr_dist3(1)),...
            'Units','normalized','Enable','off',...
            'Callback',@dist3EditCallback,...
            'Position',[.4 .42 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialDist3Unit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','mm',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.75 .41 .15 .04]);
        
        BpodSystem.GUIHandles.BCS.trialReflector = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','Reflector:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.1 .53 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialReflectorEdit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','edit',...
            'String',num2str(S.GUIMeta.tr_reflector(1)),...
            'Units','normalized',...
            'Callback',@reflectorEditCallback,...
            'Position',[.4 .54 .3 .04]);
        
        BpodSystem.GUIHandles.BCS.trialOffset = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','Offset:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.1 .47 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialOffsetEdit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','edit',...
            'String',num2str(S.GUIMeta.tr_dist1(1)),...
            'Units','normalized',...
            'Callback',@dist1EditCallback,...
            'Position',[.4 .48 .3 .04]);
        
        BpodSystem.GUIHandles.BCS.trialLaps = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','Laps:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.1 .41 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialLapsEdit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','edit',...
            'String',num2str(S.GUIMeta.tr_laps(1)),...
            'Units','normalized',...
            'Callback',@lapsEditCallback,...
            'Position',[.4 .42 .3 .04]);
        
        % trial minimum-speed selection
        BpodSystem.GUIHandles.BCS.trialSpeed = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','Min speed:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.1 .47 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialSpeedEdit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','edit',...
            'String',num2str(S.GUIMeta.tr_speed(1)),...
            'Units','normalized',...
            'Callback',@speedEditCallback,...
            'Position',[.4 .48 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialSpeedUnit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','mm/s',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.75 .47 .15 .04]);
        
        % trial water delivery time selection
        BpodSystem.GUIHandles.BCS.trialPump = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','Water time:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.1 .34 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialPumpEdit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','edit',...
            'String',num2str(S.GUIMeta.tr_pump(1)),...
            'Units','normalized',...
            'Callback',@pumpEditCallback,...
            'Position',[.4 .35 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialPumpUnit = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','ms',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.75 .34 .15 .04]);
        
        
        BpodSystem.GUIHandles.BCS.trialLED = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','Cue Light:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.1 .27 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialLEDPopup = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','popupmenu',...
            'String',{' Off',' On'},...
            'Value',1,...
            'Units','normalized',...
            'Callback',@ledPopupCallback,...
            'Position',[.4 .28 .2 .04]);
        
        BpodSystem.GUIHandles.BCS.trialLCD = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','text',...
            'String','LCD Monitor:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.1 .20 .3 .04]);
        BpodSystem.GUIHandles.BCS.trialLCDPopup = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','popupmenu',...
            'String',{' Off',' On'},...
            'Value',1,...
            'Units','normalized',...
            'Callback',@lcdPopupCallback,...
            'Position',[.4 .21 .2 .04]);
        
        % add phase button
        BpodSystem.GUIHandles.BCS.addPhase = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','pushbutton','String','Add phase',...
            'Units','normalized',...
            'Callback', @addPhaseCallback,...
            'Position',[.05 .12 .4 .05]);
        
        % delete phase button
        BpodSystem.GUIHandles.BCS.deletePhase = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','pushbutton','String','Delete phase',...
            'Units','normalized','Enable','off',...
            'Callback', @deletePhaseCallback,...
            'Position',[.55 .12 .4 .05]);
        
        % trial upload button
        BpodSystem.GUIHandles.BCS.trialLoad = uicontrol(BpodSystem.GUIHandles.BCS.trialPanel,'Style','pushbutton','String','Upload trial',...
            'Units','normalized','Enable','off',...
            'Callback', @trialUploadCallback,...
            'Position',[.32 .04 .4 .05]);
        
        
        % *** rig panel widgets ***
        
        BpodSystem.GUIHandles.BCS.beamPanel = uipanel('Parent',BpodSystem.GUIHandles.BCS.rigPanel,'Title','Beams','Position',[.1 .8 .8 .20]);
        BpodSystem.GUIHandles.BCS.beam1 = uicontrol(BpodSystem.GUIHandles.BCS.beamPanel,'Style','radiobutton','String','Beam1',...
            'Units','normalized',...
            'Enable','inactive',...
            'Position',[.1 .72 .3 .3]);
        BpodSystem.GUIHandles.BCS.beam2 = uicontrol(BpodSystem.GUIHandles.BCS.beamPanel,'Style','radiobutton','String','Beam2',...
            'Units','normalized',...
            'Enable','inactive',...
            'Position',[.1 .42 .3 .3]);
        BpodSystem.GUIHandles.BCS.beam3 = uicontrol(BpodSystem.GUIHandles.BCS.beamPanel,'Style','radiobutton','String','Beam3',...
            'Units','normalized',...
            'Enable','inactive',...
            'Position',[.1 .12 .3 .3]);
        
        BpodSystem.GUIHandles.BCS.lickPanel = uipanel('Parent',BpodSystem.GUIHandles.BCS.rigPanel,'Title','Lickport','Position',[.1 .63 .8 .15]);
        BpodSystem.GUIHandles.BCS.llp = uicontrol(BpodSystem.GUIHandles.BCS.lickPanel,'Style','radiobutton','String','Pump',...
            'Units','normalized',...
            'Enable','inactive',...
            'Position',[.1 .65 .3 .3]);
        BpodSystem.GUIHandles.BCS.llb = uicontrol(BpodSystem.GUIHandles.BCS.lickPanel,'Style','radiobutton','String','Lick',...
            'Units','normalized',...
            'Enable','inactive',...
            'Position',[.1 .2 .3 .3]);
        
        BpodSystem.GUIHandles.BCS.reward = uicontrol('Parent', BpodSystem.GUIHandles.BCS.lickPanel,'Style','pushbutton','Units','normalized','HandleVisibility','callback', ...
            'Value',0,'Position',[0.35 0.6 0.25 0.4],'String','Reward','Callback', @hRewardButtonCallback);
        
        BpodSystem.GUIHandles.BCS.rewardEdit = uicontrol(BpodSystem.GUIHandles.BCS.lickPanel,'Style','edit',...
            'String',num2str(rewardTime),...
            'Units','normalized',...
            'Callback',@rewardEditCallback,...
            'Position',[0.65 0.6 0.2 0.4]);
        BpodSystem.GUIHandles.BCS.rewardUnit = uicontrol(BpodSystem.GUIHandles.BCS.lickPanel,'Style','text',...
            'String','ms',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.9 .70 .1 0.2]);
        
        
        BpodSystem.GUIHandles.BCS.cuePanel = uipanel('Parent',BpodSystem.GUIHandles.BCS.rigPanel,'Title','Cue Status/Control','Position',[.1 .46 .8 .15]);
        
        BpodSystem.GUIHandles.BCS.led_cue = uicontrol(BpodSystem.GUIHandles.BCS.cuePanel,'Style','radiobutton','String','Light',...
            'Units','normalized',...
            'Enable','inactive',...
            'Position',[.1 .65 .3 .3]);
        
        BpodSystem.GUIHandles.BCS.led_manual = uicontrol('Parent', BpodSystem.GUIHandles.BCS.cuePanel,'Style','togglebutton','Units','normalized','HandleVisibility','callback', ...
            'Value',0,'Position',[0.5 0.60 0.3 0.4],'String','Manual','Callback', @hManualButton1Callback);
        
        
        BpodSystem.GUIHandles.BCS.lcd_cue = uicontrol(BpodSystem.GUIHandles.BCS.cuePanel,'Style','radiobutton','String','LCD',...
            'Units','normalized',...
            'Enable','inactive',...
            'Position',[.1 .2 .3 .3]);
        
        BpodSystem.GUIHandles.BCS.lcd_manual = uicontrol('Parent', BpodSystem.GUIHandles.BCS.cuePanel,'Style','togglebutton','Units','normalized','HandleVisibility','callback', ...
            'Value',0,'Position',[0.5 0.15 0.3 0.4],'String','Manual','Callback', @hManualButton2Callback);
        
        BpodSystem.GUIHandles.BCS.treadPanel = uipanel('Parent',BpodSystem.GUIHandles.BCS.rigPanel,'Title','Treadmill','Position',[.1 .19 .8 .25]);
        BpodSystem.GUIHandles.BCS.spt = uicontrol(BpodSystem.GUIHandles.BCS.treadPanel,'Style','text',...
            'String','Speed:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.1 .65 .3 .3]);
        BpodSystem.GUIHandles.BCS.speedv = uicontrol(BpodSystem.GUIHandles.BCS.treadPanel,'Style','text',...
            'String','0',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.5 .65 .3 .3]);
        BpodSystem.GUIHandles.BCS.spu = uicontrol(BpodSystem.GUIHandles.BCS.treadPanel,'Style','text',...
            'String','mm/s',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.75 .65 .25 .3]);
        BpodSystem.GUIHandles.BCS.drt = uicontrol(BpodSystem.GUIHandles.BCS.treadPanel,'Style','text',...
            'String','Dir:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.1 .45 .3 .3]);
        BpodSystem.GUIHandles.BCS.dfw = uicontrol(BpodSystem.GUIHandles.BCS.treadPanel,'Style','radiobutton','String','FW',...
            'Units','normalized',...
            'Enable','inactive',...
            'Position',[.47 .52 .25 .3]);
        BpodSystem.GUIHandles.BCS.dbw = uicontrol(BpodSystem.GUIHandles.BCS.treadPanel,'Style','radiobutton','String','BW',...
            'Units','normalized',...
            'Enable','inactive',...
            'Position',[.75 .52 .25 .3]);
        BpodSystem.GUIHandles.BCS.distt = uicontrol(BpodSystem.GUIHandles.BCS.treadPanel,'Style','text',...
            'String','Dist. FW:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.1 .22 .3 .3]);
        BpodSystem.GUIHandles.BCS.distccw = uicontrol(BpodSystem.GUIHandles.BCS.treadPanel,'Style','text',...
            'String','0',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.5 .22 .3 .3]);
        BpodSystem.GUIHandles.BCS.distu = uicontrol(BpodSystem.GUIHandles.BCS.treadPanel,'Style','text',...
            'String','mm',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.75 .22 .25 .3]);
        BpodSystem.GUIHandles.BCS.timet = uicontrol(BpodSystem.GUIHandles.BCS.treadPanel,'Style','text',...
            'String','Time FW:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.1 .00 .3 .3]);
        BpodSystem.GUIHandles.BCS.timeccw = uicontrol(BpodSystem.GUIHandles.BCS.treadPanel,'Style','text',...
            'String','0',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.5 .00 .3 .3]);
        BpodSystem.GUIHandles.BCS.timeu = uicontrol(BpodSystem.GUIHandles.BCS.treadPanel,'Style','text',...
            'String','ms',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.75 .00 .25 .3]);
        
        BpodSystem.GUIHandles.BCS.trialPhase = uicontrol(BpodSystem.GUIHandles.BCS.rigPanel,'Style','text',...
            'String','Trial phase:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.2 .1 .3 .05]);
        
        BpodSystem.GUIHandles.BCS.trialPhaseValue = uicontrol(BpodSystem.GUIHandles.BCS.rigPanel,'Style','text',...
            'String','1',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.6 .1 .15 .05]);
        
        BpodSystem.GUIHandles.BCS.trialPhaseR = uicontrol(BpodSystem.GUIHandles.BCS.rigPanel,'Style','text',...
            'String','Time remaining:',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.2 .05 .3 .05]);
        
        BpodSystem.GUIHandles.BCS.trialPhaseRValue = uicontrol(BpodSystem.GUIHandles.BCS.rigPanel,'Style','text',...
            'String','----',...
            'Units','normalized',...
            'HorizontalAlignment','left',...
            'Position',[.6 .05 .15 .05]);
        
        % End of GUI widgets setup
        % ---------------------------------------------
        
        % Set initial widget visibility state
        
        set(BpodSystem.GUIHandles.BCS.trialDist1,'Visible','off');
        set(BpodSystem.GUIHandles.BCS.trialDist1Edit,'Visible','off');
        set(BpodSystem.GUIHandles.BCS.trialDist1Unit,'Visible','off');
        set(BpodSystem.GUIHandles.BCS.trialDist2,'Visible','off');
        set(BpodSystem.GUIHandles.BCS.trialDist2Edit,'Visible','off');
        set(BpodSystem.GUIHandles.BCS.trialDist2Unit,'Visible','off');
        set(BpodSystem.GUIHandles.BCS.trialDist3,'Visible','off');
        set(BpodSystem.GUIHandles.BCS.trialDist3Edit,'Visible','off');
        set(BpodSystem.GUIHandles.BCS.trialDist3Unit,'Visible','off');
        set(BpodSystem.GUIHandles.BCS.trialOffset,'Visible','off');
        set(BpodSystem.GUIHandles.BCS.trialOffsetEdit,'Visible','off');
        set(BpodSystem.GUIHandles.BCS.trialReflector,'Visible','off');
        set(BpodSystem.GUIHandles.BCS.trialReflectorEdit,'Visible','off');
        set(BpodSystem.GUIHandles.BCS.trialLaps,'Visible','off');
        set(BpodSystem.GUIHandles.BCS.trialLapsEdit,'Visible','off');
        
        % Show the GUI
        set(BpodSystem.ProtocolFigures.BCSFig,'Visible','on');
        
    case 'update'
        %function 'recieveData in original implemntation called when serial data
        %was read from BCS. Now we will let Bpod read, and just
        %write/decode here for uodate
        
        receiveData(varargin)
        
        
end

end

%GUI Update function

% Called every time a CR/LF terminated line is received from the BCS
%----------------------------------------------------------------------
function receiveData(varargin)
%token = fscanf(s,'%s',5);
token  = []; %this will now be a code back from the BPOD firmware
if (strcmp('FREV,', token) == true)
    name = fscanf(s);
    set(BpodSystem.ProtocolFigures.BCSFig,'name',[idn ', ' name]);
    fwrite(s, sprintf('phases, 1\r'));
    cmd = sprintf('values,1,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u\r',...
        S.GUIMeta.tr_duration(1)*60,...
        S.GUIMeta.tr_type(1),...
        S.GUIMeta.tr_length(1),...
        round(S.GUIMeta.tr_length(1)/click),...
        round(S.GUIMeta.tr_dist1(1)/click),...
        S.GUIMeta.tr_dist1En(1),...
        round(S.GUIMeta.tr_dist2(1)/click),...
        S.GUIMeta.tr_dist2En(1),...
        round(S.GUIMeta.tr_dist3(1)/click),...
        S.GUIMeta.tr_dist2En(1),...
        round(S.GUIMeta.tr_speed(1)/click),...
        S.GUIMeta.tr_pump(1),...
        S.GUIMeta.tr_led(1),...
        S.GUIMeta.tr_lcd(1),...
        S.GUIMeta.tr_next(1),...
        S.GUIMeta.tr_reflector(1),...
        S.GUIMeta.tr_laps(1));
    fwrite(s,cmd);
    S.GUIMeta.trial_loaded = 1;
    set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','off');
elseif(strcmp('TRIA,', token) == true)
    inpline = fscanf(s);
    [tstamp,ttime,etype] = strread(inpline,'%u%u%u','delimiter',',');
    if (etype == 1)
        set(BpodSystem.GUIHandles.BCS.start,'BackgroundColor','red');
        set(BpodSystem.GUIHandles.BCS.start,'String','Trial running');
    elseif (etype == 2)
        set(BpodSystem.GUIHandles.BCS.start,'BackgroundColor','green');
        set(BpodSystem.GUIHandles.BCS.start,'String','Trial idle');
        set(BpodSystem.GUIHandles.BCS.trialPhaseValue, 'String', '1');
        set(BpodSystem.GUIHandles.BCS.trialPhaseRValue, 'String', '----');
    end
    if (S.GUI.recOn == true)
        fprintf(S.GUI.logfileID,'TRIAL,%s',inpline);
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
    if (S.GUI.recOn == true)
        fprintf(S.GUI.logfileID,'BEAM,%s',inpline);
    end
elseif(strcmp('PUMP,', token) == true)
    inpline = fscanf(s);
    [tstamp,ttime,pstate] = strread(inpline,'%u%u%u','delimiter',',');
    if pstate == 1
        set(llp,'Value',1);
    else
        set(llp,'Value',0);
    end
    
    if (S.GUI.recOn == true)
        fprintf(S.GUI.logfileID,'PUMP,%s',inpline);
    end
elseif(strcmp('LICK,', token) == true)
    inpline = fscanf(s);
    [tstamp,ttime,lstate] = strread(inpline,'%u%u%u','delimiter',',');
    if lstate == 1
        set(llb,'Value',1);
    else
        set(llb,'Value',0);
    end
    
    if (S.GUI.recOn == true)
        fprintf(S.GUI.logfileID,'LICK,%s',inpline);
    end
elseif(strcmp('TTLS,', token) == true)
    inpline = fscanf(s);
    if (S.GUI.recOn == true)
        fprintf(S.GUI.logfileID,'TTLINPUT,%s',inpline);
    end
elseif(strcmp('TREA,', token) == true)
    inpline = fscanf(s);
    [tstamp,ttime,tspeed,tdist,trtime] = strread(inpline,'%u%u%d%u%u','delimiter',',');
    convertedSpeed = round(tspeed * click);
    convertedDist = round(tdist * click);
    if (tspeed > 1)
        set(BpodSystem.GUIHandles.BCS.dbw,'Value',0);
        set(BpodSystem.GUIHandles.BCS.dfw,'Value',1);
        set(BpodSystem.GUIHandles.BCS.speedv,'String',num2str(convertedSpeed));
    elseif (tspeed < -1)
        set(BpodSystem.GUIHandles.BCS.dbw,'Value',1);
        set(BpodSystem.GUIHandles.BCS.dfw,'Value',0);
        set(BpodSystem.GUIHandles.BCS.speedv,'String',num2str(-convertedSpeed));
    else
        set(BpodSystem.GUIHandles.BCS.dbw,'Value',0);
        set(BpodSystem.GUIHandles.BCS.dfw,'Value',0);
        set(BpodSystem.GUIHandles.BCS.speedv,'String','0');
    end
    set(BpodSystem.GUIHandles.BCS.distccw,'String',num2str(convertedDist));
    set(BpodSystem.GUIHandles.BCS.timeccw,'String',num2str(trtime));
    if (S.GUI.recOn == true)
        fprintf(S.GUI.logfileID,'TREADMILL,%u,%u,%d,%u,%u\n',tstamp,ttime,convertedSpeed,convertedDist,trtime);
    end
elseif(strcmp('CUEL,', token) == true)
    inpline = fscanf(s);
    [tstamp,ttime,pstate] = strread(inpline,'%u%u%u','delimiter',',');
    if pstate == 1
        set(BpodSystem.GUIHandles.BCS.led_cue,'Value',1);
    else
        set(BpodSystem.GUIHandles.BCS.led_cue,'Value',0);
    end
    
    if (S.GUI.recOn == true)
        fprintf(S.GUI.logfileID,'CUELIGHT,%s',inpline);
    end
elseif(strcmp('LCDL,', token) == true)
    inpline = fscanf(s);
    [tstamp,ttime,pstate] = strread(inpline,'%u%u%u','delimiter',',');
    if pstate == 1
        set(BpodSystem.GUIHandles.BCS.lcd_cue,'Value',1);
    else
        set(BpodSystem.GUIHandles.BCS.lcd_cue,'Value',0);
    end
    
    if (S.GUI.recOn == true)
        fprintf(S.GUI.logfileID,'LCD,%s',inpline);
    end
elseif(strcmp('SYNC,', token) == true)
    inpline = fscanf(s);
    [tstamp,ttime,phase,left] = strread(inpline,'%u%u%u%u','delimiter',',');
    
    minLeft = floor(left/60);
    secLeft = left - (minLeft * 60);
    
    set(BpodSystem.GUIHandles.BCS.trialPhaseValue, 'String', num2str(phase));
    set(BpodSystem.GUIHandles.BCS.trialPhaseRValue, 'String', sprintf('%d:%02d',minLeft,secLeft));
    
    if (S.GUI.recOn == true)
        fprintf(S.GUI.logfileID,'SYNC,%s',inpline);
    end
elseif(strcmp('MAXL,', token) == true)
    inpline = fscanf(s);
    [tstamp,ttime,ltime] = strread(inpline,'%u%u%u','delimiter',',');
    if (S.GUI.recOn == true)
        fprintf(S.GUI.logfileID,'MAXL,%s',inpline);
    end
    
else
    %inpline = fscanf(s);
    if (S.GUI.recOn == true)
        %fprintf(S.GUI.logfileID,'%s%s',token,inpline);
    end
end
end
%----------------------------------------------------------------------



% GUI callback functions

%----------------------------------------------------------------------
function setTrial(val)
set(BpodSystem.GUIHandles.BCS.phaseDurationEdit, 'String',num2str(S.GUIMeta.tr_duration(val)));
set(BpodSystem.GUIHandles.BCS.nextPhasePopup, 'Value', S.GUIMeta.tr_next(val));
if (S.GUIMeta.tr_type(val) == 1)
    set(BpodSystem.GUIHandles.BCS.trialType,'SelectedObject',BpodSystem.GUIHandles.BCS.distType);
elseif (S.GUIMeta.tr_type(val) == 2)
    set(BpodSystem.GUIHandles.BCS.trialType,'SelectedObject',BpodSystem.GUIHandles.BCS.timeType);
elseif (S.GUIMeta.tr_type(val) == 3)
    set(BpodSystem.GUIHandles.BCS.trialType,'SelectedObject',BpodSystem.GUIHandles.BCS.posType);
else
    set(BpodSystem.GUIHandles.BCS.trialType,'SelectedObject',BpodSystem.GUIHandles.BCS.newType);
end
set(BpodSystem.GUIHandles.BCS.trialLengthEdit, 'String',num2str(S.GUIMeta.tr_length(val)));
set(BpodSystem.GUIHandles.BCS.trialDist1Edit, 'String',num2str(S.GUIMeta.tr_dist1(val)));
set(BpodSystem.GUIHandles.BCS.trialDist2Edit, 'String',num2str(S.GUIMeta.tr_dist2(val)));
set(BpodSystem.GUIHandles.BCS.trialDist3Edit, 'String',num2str(S.GUIMeta.tr_dist3(val)));
set(BpodSystem.GUIHandles.BCS.trialOffsetEdit, 'String',num2str(S.GUIMeta.tr_dist1(val)));
set(BpodSystem.GUIHandles.BCS.trialReflectorEdit, 'String',num2str(S.GUIMeta.tr_reflector(val)));
set(BpodSystem.GUIHandles.BCS.trialLapsEdit, 'String',num2str(S.GUIMeta.tr_laps(val)));
set(BpodSystem.GUIHandles.BCS.trialSpeedEdit, 'String',num2str(S.GUIMeta.tr_speed(val)));
set(BpodSystem.GUIHandles.BCS.trialPumpEdit, 'String',num2str(S.GUIMeta.tr_pump(val)));
set(BpodSystem.GUIHandles.BCS.trialLEDPopup, 'Value', S.GUIMeta.tr_led(value));
set(BpodSystem.GUIHandles.BCS.trialLCDPopup, 'Value', S.GUIMeta.tr_lcd(value));
if (S.GUIMeta.tr_dist1En(val) == 0)
    set(BpodSystem.GUIHandles.BCS.trialDist1Edit,'Enable','off');
    set(BpodSystem.GUIHandles.BCS.trialDist1,'Value',0);
else
    set(BpodSystem.GUIHandles.BCS.trialDist1Edit,'Enable','on');
    set(BpodSystem.GUIHandles.BCS.trialDist1,'Value',1);
end
if (S.GUIMeta.tr_dist2En(val) == 0)
    set(BpodSystem.GUIHandles.BCS.trialDist2Edit,'Enable','off');
    set(BpodSystem.GUIHandles.BCS.trialDist2,'Value',0);
else
    set(BpodSystem.GUIHandles.BCS.trialDist2Edit,'Enable','on');
    set(BpodSystem.GUIHandles.BCS.trialDist2,'Value',1);
end
if (S.GUIMeta.tr_dist3En(val) == 0)
    set(BpodSystem.GUIHandles.BCS.trialDist3Edit,'Enable','off');
    set(BpodSystem.GUIHandles.BCS.trialDist3,'Value',0);
else
    set(BpodSystem.GUIHandles.BCS.trialDist3Edit,'Enable','on');
    set(BpodSystem.GUIHandles.BCS.trialDist3,'Value',1);
end
if (S.GUIMeta.tr_type(val) == 1)
    set(BpodSystem.GUIHandles.BCS.trialLength,'String','Distance:');
    set(BpodSystem.GUIHandles.BCS.trialLengthUnit,'String','mm');
    set(BpodSystem.GUIHandles.BCS.trialLength,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLengthEdit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLengthUnit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialSpeed,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialSpeedEdit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialSpeedUnit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialDist1,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist1Edit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist1Unit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist2,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist2Edit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist2Unit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist3,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist3Edit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist3Unit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialOffset,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialOffsetEdit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialReflector,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialReflectorEdit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLaps,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLapsEdit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLED,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLEDPopup,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLCD,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLCDPopup,'Visible','on');
elseif (S.GUIMeta.tr_type(val) == 2)
    set(BpodSystem.GUIHandles.BCS.trialLength,'String','Time:');
    set(BpodSystem.GUIHandles.BCS.trialLengthUnit,'String','ms');
    set(BpodSystem.GUIHandles.BCS.trialLength,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLengthEdit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLengthUnit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialSpeed,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialSpeedEdit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialSpeedUnit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialDist1,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist1Edit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist1Unit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist2,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist2Edit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist2Unit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist3,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist3Edit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist3Unit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialOffset,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialOffsetEdit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialReflector,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialReflectorEdit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLaps,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLapsEdit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLED,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLEDPopup,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLCD,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLCDPopup,'Visible','on');
elseif (S.GUIMeta.tr_type(val) == 3)
    set(BpodSystem.GUIHandles.BCS.trialLength,'String','Distance:');
    set(BpodSystem.GUIHandles.BCS.trialLengthUnit,'String','mm');
    set(BpodSystem.GUIHandles.BCS.trialLength,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLengthEdit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLengthUnit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialSpeed,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialSpeedEdit,'Visible','off');
    set(vtrialSpeedUnit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist1,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialDist1Edit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialDist1Unit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialDist2,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialDist2Edit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialDist2Unit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialDist3,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialDist3Edit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialDist3Unit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialOffset,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialOffsetEdit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialReflector,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialReflectorEdit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLaps,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLapsEdit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLED,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLEDPopup,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLCD,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLCDPopup,'Visible','on');
else
    set(BpodSystem.GUIHandles.BCS.trialLength,'String','Distance:');
    set(BpodSystem.GUIHandles.BCS.trialLengthUnit,'String','mm');
    set(BpodSystem.GUIHandles.BCS.trialLength,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLengthEdit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLengthUnit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialSpeed,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialSpeedEdit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialSpeedUnit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist1,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist1Edit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist1Unit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist2,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist2Edit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist2Unit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialDist3,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist3Edit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialDist3Unit,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialOffset,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialOffsetEdit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialReflector,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialReflectorEdit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLaps,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLapsEdit,'Visible','on');
    set(BpodSystem.GUIHandles.BCS.trialLED,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLEDPopup,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLCD,'Visible','off');
    set(BpodSystem.GUIHandles.BCS.trialLCDPopup,'Visible','off');
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
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
S.GUIMeta.tr_next(phase) = val;
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function phaseDurationCallback(hObject, eventdata, handles)
[entry,status] = str2num(get(hObject,'string'));
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
if (status)
    value = round(entry);
    if (value >= 0 && value <= 60)
        set(hObject,'String',num2str(value));
        S.GUIMeta.tr_duration(phase) = value;
        S.GUIMeta.trial_dirty = 1;
        S.GUIMeta.trial_loaded = 0;
        set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
    else
        set(hObject,'String',num2str(S.GUIMeta.tr(phase).duration));
    end
else
    set(hObject,'String',num2str(S.GUIMeta.tr(phase).duration));
end
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function typeselcbk(source,eventdata)
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
if (eventdata.NewValue == distType)
    S.GUIMeta.tr_type(phase) = 1;
    S.GUIMeta.trial_dirty = 1;
    S.GUIMeta.trial_loaded = 0;
    set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
elseif (eventdata.NewValue == timeType)
    S.GUIMeta.tr_type(phase) = 2;
    S.GUIMeta.trial_dirty = 1;
    S.GUIMeta.trial_loaded = 0;
    set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
elseif (eventdata.NewValue == posType)
    S.GUIMeta.tr_type(phase) = 3;
    S.GUIMeta.trial_dirty = 1;
    S.GUIMeta.trial_loaded = 0;
    set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
elseif (eventdata.NewValue == newType)
    S.GUIMeta.tr_type(phase) = 4;
    S.GUIMeta.trial_dirty = 1;
    S.GUIMeta.trial_loaded = 0;
    set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
end
% Update the trial panel
setTrial(S.GUIMeta.tr_phase);
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function lengthEditCallback(hObject, eventdata, handles)
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
[entry,status] = str2num(get(hObject,'string'));
if (status)
    value = round(entry);
    if (value >= 0 && value <= 1000000)
        set(hObject,'String',num2str(value));
        S.GUIMeta.tr(phase).length = value;
        S.GUIMeta.trial_dirty = 1;
        S.GUIMeta.trial_loaded = 0;
        set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
    else
        set(hObject,'String',num2str(S.GUIMeta.tr(phase).length));
    end
else
    set(hObject,'String',num2str(S.GUIMeta.tr(phase).length));
end
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function dist1SelCallback(hObject, eventdata, handles)
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
button_state = get(hObject,'Value');
if button_state == get(hObject,'Max')
    S.GUIMeta.tr(phase).dist1En = 1;
    set(BpodSystem.GUIHandles.BCS.trialDist1Edit,'Enable','on');
else
    S.GUIMeta.tr(phase).dist1En = 0;
    set(BpodSystem.GUIHandles.BCS.trialDist1Edit,'Enable','off');
end
S.GUIMeta.trial_dirty = 1;
S.GUIMeta.trial_loaded = 0;
set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function dist1EditCallback(hObject, eventdata, handles)
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
[entry,status] = str2num(get(hObject,'string'));
if (status)
    value = round(entry);
    if (value >= 0 && value <= 1000000)
        set(hObject,'String',num2str(value));
        S.GUIMeta.tr(phase).dist1 = value;
        S.GUIMeta.trial_dirty = 1;
        S.GUIMeta.trial_loaded = 0;
        set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
    else
        set(hObject,'String',num2str(S.GUIMeta.tr(phase).dist1));
    end
else
    set(hObject,'String',num2str(S.GUIMeta.tr(phase).dist1));
end
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function dist2SelCallback(hObject, eventdata, handles)
phase = get(phasePopup, 'Value');
button_state = get(hObject,'Value');
if button_state == get(hObject,'Max')
    S.GUIMeta.tr(phase).dist2En = 1;
    set(BpodSystem.GUIHandles.BCS.trialDist2Edit,'Enable','on');
else
    S.GUIMeta.tr(phase).dist2En = 0;
    set(BpodSystem.GUIHandles.BCS.trialDist2Edit,'Enable','off');
end
S.GUIMeta.trial_dirty = 1;
S.GUIMeta.trial_loaded = 0;
set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function dist2EditCallback(hObject, eventdata, handles)
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
[entry,status] = str2num(get(hObject,'string'));
if (status)
    value = round(entry);
    if (value >= 0 && value <= 1000000)
        set(hObject,'String',num2str(value));
        S.GUIMeta.tr(phase).dist2 = value;
        S.GUIMeta.trial_dirty = 1;
        S.GUIMeta.trial_loaded = 0;
        set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
    else
        set(hObject,'String',num2str(S.GUIMeta.tr(phase).dist2));
    end
else
    set(hObject,'String',num2str(S.GUIMeta.tr(phase).dist2));
end
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function dist3SelCallback(hObject, eventdata, handles)
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
button_state = get(hObject,'Value');
if button_state == get(hObject,'Max')
    S.GUIMeta.tr(phase).dist3En = 1;
    set(BpodSystem.GUIHandles.BCS.trialDist3Edit,'Enable','on');
else
    S.GUIMeta.tr(phase).dist3En = 0;
    set(BpodSystem.GUIHandles.BCS.trialDist3Edit,'Enable','off');
end
S.GUIMeta.trial_dirty = 1;
S.GUIMeta.trial_loaded = 0;
set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function dist3EditCallback(hObject, eventdata, handles)
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
[entry,status] = str2num(get(hObject,'string'));
if (status)
    value = round(entry);
    if (value >= 0 && value <= 1000000)
        set(hObject,'String',num2str(value));
        S.GUIMeta.tr(phase).dist3 = value;
        S.GUIMeta.trial_dirty = 1;
        S.GUIMeta.trial_loaded = 0;
        set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
    else
        set(hObject,'String',num2str(S.GUIMeta.tr(phase).dist3));
    end
else
    set(hObject,'String',num2str(S.GUIMeta.tr(phase).dist3));
end
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function reflectorEditCallback(hObject, eventdata, handles)
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
[entry,status] = str2num(get(hObject,'string'));
if (status)
    value = round(entry);
    if (value >= 0 && value <= 3)
        set(hObject,'String',num2str(value));
        S.GUIMeta.tr(phase).reflector = value;
        S.GUIMeta.trial_dirty = 1;
        S.GUIMeta.trial_loaded = 0;
        set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
    else
        set(hObject,'String',num2str(S.GUIMeta.tr(phase).reflector));
    end
else
    set(hObject,'String',num2str(S.GUIMeta.tr(phase).reflector));
end
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function lapsEditCallback(hObject, eventdata, handles)
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
[entry,status] = str2num(get(hObject,'string'));
if (status)
    value = round(entry);
    if (value >= 0 && value <= 100)
        set(hObject,'String',num2str(value));
        S.GUIMeta.tr(phase).laps = value;
        S.GUIMeta.trial_dirty = 1;
        S.GUIMeta.trial_loaded = 0;
        set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
    else
        set(hObject,'String',num2str(S.GUIMeta.tr(phase).laps));
    end
else
    set(hObject,'String',num2str(S.GUIMeta.tr(phase).laps));
end
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function speedEditCallback(hObject, eventdata, handles)
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
[entry,status] = str2num(get(hObject,'string'));
if (status)
    value = round(entry);
    if (value >= 0 && value <= 10000)
        set(hObject,'String',num2str(value));
        S.GUIMeta.tr(phase).speed = value;
        S.GUIMeta.trial_dirty = 1;
        S.GUIMeta.trial_loaded = 0;
        set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
    else
        set(hObject,'String',num2str(S.GUIMeta.tr(phase).speed));
    end
else
    set(hObject,'String',num2str(S.GUIMeta.tr(phase).speed));
end
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function pumpEditCallback(hObject, eventdata, handles)
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
[entry,status] = str2num(get(hObject,'string'));
if (status)
    value = round(entry);
    if (value >= 0 && value <= 10000)
        set(hObject,'String',num2str(value));
        S.GUIMeta.tr(phase).pump = value;
        S.GUIMeta.trial_dirty = 1;
        S.GUIMeta.trial_loaded = 0;
        set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
    else
        set(hObject,'String',num2str(S.GUIMeta.tr(phase).pump));
    end
else
    set(hObject,'String',num2str(S.GUIMeta.tr(phase).pump));
end
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function ledPopupCallback(hObject, eventdata, handles)
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
val = get(hObject,'Value');
if (val ~= S.GUIMeta.tr(phase).led)
    S.GUIMeta.tr(phase).led = get(hObject,'Value');
    S.GUIMeta.trial_dirty = 1;
    S.GUIMeta.trial_loaded = 0;
    set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
end
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function lcdPopupCallback(hObject, eventdata, handles)
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
val = get(hObject,'Value');
if (val ~= S.GUIMeta.tr(phase).lcd)
    S.GUIMeta.tr(phase).lcd = get(hObject,'Value');
    S.GUIMeta.trial_dirty = 1;
    S.GUIMeta.trial_loaded = 0;
    set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
end
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function addPhaseCallback(Obj, evt)
phase = get(phasePopup, 'Value');
if (phase < S.GUIMeta.trial.phases)
    for index = S.GUIMeta.trial.phases:-1:phase+1
        for index2 = 1:S.GUIMeta.trial.phases
            if (S.GUIMeta.tr(index2).next == index)
                S.GUIMeta.tr(index2).next = index + 1;
            end
        end
    end
    for index = S.GUIMeta.trial.phases:-1:phase+1
        S.GUIMeta.tr(index+1) = S.GUIMeta.tr(index);
    end
end
S.GUIMeta.trial.phases = S.GUIMeta.trial.phases + 1;
phase = phase + 1;
S.GUIMeta.tr(phase).duration = 1;
S.GUIMeta.tr(phase).type = 1;
S.GUIMeta.tr(phase).length = 1000;
S.GUIMeta.tr(phase).dist1 = 100;
S.GUIMeta.tr(phase).dist1En = 0;
S.GUIMeta.tr(phase).dist2 = 100;
S.GUIMeta.tr(phase).dist2En = 0;
S.GUIMeta.tr(phase).dist3 = 100;
S.GUIMeta.tr(phase).dist3En = 0;
S.GUIMeta.tr(phase).speed = 100;
S.GUIMeta.tr(phase).pump = 1000;
S.GUIMeta.tr(phase).led = 1;
S.GUIMeta.tr(phase).lcd = 1;
S.GUIMeta.tr(phase).reflector = 1;
S.GUIMeta.tr(phase).laps = 1;
S.GUIMeta.tr(phase).next = S.GUIMeta.tr(phase-1).next;
S.GUIMeta.tr(phase-1).next = phase;
C1 = get(BpodSystem.GUIHandles.BCS.phasePopup, 'String');
C2 = [C1 ; ' Phase ',num2str(S.GUIMeta.trial.phases)];
set(BpodSystem.GUIHandles.BCS.phasePopup, 'String', C2);
set(BpodSystem.GUIHandles.BCS.phasePopup, 'Value', phase);
C1 = get(BpodSystem.GUIHandles.BCS.nextPhasePopup, 'String');
C2 = [C1 ; ' Phase ',num2str(S.GUIMeta.trial.phases)];
set(BpodSystem.GUIHandles.BCS.nextPhasePopup, 'String', C2);
set(BpodSystem.GUIHandles.BCS.deletePhase, 'Enable', 'on');
if (S.GUIMeta.trial.phases == 25)
    set(BpodSystem.GUIHandles.BCS.addPhase, 'Enable', 'off');
end
setTrial(BpodSystem.GUIHandles.BCS.phase);
S.GUIMeta.trial_dirty = 1;
S.GUIMeta.trial_loaded = 0;
set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function deletePhaseCallback(Obj, evt)
phase = get(BpodSystem.GUIHandles.BCS.phasePopup, 'Value');
for index = 1:1:S.GUIMeta.trial.phases
    if (S.GUIMeta.tr(index).next == phase)
        if (S.GUIMeta.tr(phase).next == phase)
            S.GUIMeta.tr(index).next = index;
        else
            S.GUIMeta.tr(index).next = S.GUIMeta.tr(phase).next;
        end
    end
end
if (phase < S.GUIMeta.trial.phases)
    for index = phase+1:S.GUIMeta.trial.phases
        for index2 = 1:1:S.GUIMeta.trial.phases
            if (S.GUIMeta.tr(index2).next == index)
                S.GUIMeta.tr(index2).next = index-1;
            end
        end
        S.GUIMeta.tr(index-1) = S.GUIMeta.tr(index);
    end
end

C1 = get(BpodSystem.GUIHandles.BCS.phasePopup, 'String');
C1(S.GUIMeta.trial.phases,:) = [];
set(BpodSystem.GUIHandles.BCS.phasePopup, 'String', C1);

C1 = get(BpodSystem.GUIHandles.BCS.nextPhasePopup, 'String');
C1(S.GUIMeta.trial.phases,:) = [];
set(BpodSystem.GUIHandles.BCS.nextPhasePopup, 'String', C1);

S.GUIMeta.trial.phases = S.GUIMeta.trial.phases - 1;
if (phase > S.GUIMeta.trial.phases)
    phase = phase - 1;
end
set(BpodSystem.GUIHandles.BCS.phasePopup, 'Value', phase);
set(BpodSystem.GUIHandles.BCS.addPhase, 'Enable', 'on');
if (S.GUIMeta.trial.phases == 1)
    set(BpodSystem.GUIHandles.BCS.deletePhase, 'Enable', 'off');
end
setTrial(phase);
S.GUIMeta.trial_dirty = 1;
S.GUIMeta.trial_loaded = 0;
set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
end
%----------------------------------------------------------------------

%----------------------------------------------------------------------
function trialUploadCallback(Obj, evt)
cmd = sprintf('phases,%u\r',S.GUIMeta.trial.phases);
fwrite(s,cmd);
for index = 1:S.GUIMeta.trial.phases
    cmd = sprintf('values,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u\r',...
        index,...
        S.GUIMeta.tr(index).duration*60,...
        S.GUIMeta.tr(index).type,...
        S.GUIMeta.tr(index).length,...
        round(S.GUIMeta.tr(index).length/click),...
        round(S.GUIMeta.tr(index).dist1/click),...
        S.GUIMeta.tr(index).dist1En,...
        round(S.GUIMeta.tr(index).dist2/click),...
        S.GUIMeta.tr(index).dist2En,...
        round(S.GUIMeta.tr(index).dist3/click),...
        S.GUIMeta.tr(index).dist3En,...
        round(S.GUIMeta.tr(index).speed/click),...
        S.GUIMeta.tr(index).pump,...
        S.GUIMeta.tr(index).led,...
        S.GUIMeta.tr(index).lcd,...
        S.GUIMeta.tr(index).next,...
        S.GUIMeta.tr(index).reflector,...
        S.GUIMeta.tr(index).laps);
    fwrite(s,cmd);
    pause (.1);
end
S.GUIMeta.trial_loaded = 1;
set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','off');
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
    S.GUI.logfileID = fopen(fileN,'w');
    S.GUI.recOn = true;
elseif button_state == get(hObject,'Min')
    % Toggle button is not pressed-take appropriate action
    set(hObject,'BackgroundColor','green');
    set(hObject,'String','Recording off');
    S.GUI.recOn = false;
    fclose(S.GUI.logfileID);
end
end
%----------------------------------------------------------------------


%----------------------------------------------------------------------
function hRunButtonCallback(hObject, eventdata)
button_state = get(hObject,'Value');
if button_state == get(hObject,'Max')
    % Toggle button is pressed-take appropriate action
    if (S.GUIMeta.trial_loaded == 0)
        cmd = sprintf('phases,%u\r',S.GUIMeta.trial.phases);
        fwrite(s,cmd);
        for index = 1:S.GUIMeta.trial.phases
            cmd = sprintf('values,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u\r',...
                index,...
                S.GUIMeta.tr(index).duration*60,...
                S.GUIMeta.tr(index).type,...
                S.GUIMeta.tr(index).length,...
                round(S.GUIMeta.tr(index).length/click),...
                round(S.GUIMeta.tr(index).dist1/click),...
                S.GUIMeta.tr(index).dist1En,...
                round(S.GUIMeta.tr(index).dist2/click),...
                S.GUIMeta.tr(index).dist2En,...
                round(S.GUIMeta.tr(index).dist3/click),...
                S.GUIMeta.tr(index).dist3En,...
                round(S.GUIMeta.tr(index).speed/click),...
                S.GUIMeta.tr(index).pump,...
                S.GUIMeta.tr(index).led,...
                S.GUIMeta.tr(index).lcd,...
                S.GUIMeta.tr(index).next,...
                S.GUIMeta.tr(index).reflector,...
                S.GUIMeta.tr(index).laps);
            fwrite(s,cmd);
        end
        S.GUIMeta.trial_loaded = 1;
        set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','off');
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


% *** menu functions ***

%create menu
%----------------------------------------------------------------------
function make_file_menu(figure)
% Creates File Menus for Open, Save, SaveAs and Quit

mh = uimenu(figure,'Label','File');
uimenu(mh,'Label','Open S.GUIMeta.trial...', ...
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
if (S.GUIMeta.trial_dirty == 1)
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
            S.GUIMeta.tr(index).duration = duration;
            S.GUIMeta.tr(index).type = type;
            S.GUIMeta.tr(index).length = length;
            S.GUIMeta.tr(index).dist1 = dist1;
            S.GUIMeta.tr(index).dist1En = dist1En;
            S.GUIMeta.tr(index).dist2 = dist2;
            S.GUIMeta.tr(index).dist2En = dist2En;
            S.GUIMeta.tr(index).dist3 = dist3;
            S.GUIMeta.tr(index).dist3En = dist3En;
            S.GUIMeta.tr(index).speed = speed;
            S.GUIMeta.tr(index).pump = pump;
            S.GUIMeta.tr(index).led = led;
            S.GUIMeta.tr(index).lcd = lcd;
            S.GUIMeta.tr(index).next = next;
            S.GUIMeta.tr(index).reflector = reflector;
            S.GUIMeta.tr(index).laps = laps;
        end
    end
    
    if (badFile == 1)
        errordlg('Not a valid S.GUIMeta.trial.','Cannot use this file','modal')  ;
        set(BpodSystem.GUIHandles.BCS.phasePopup, 'String', ' Phase 1');
        S.GUIMeta.trial.phases = 1;
        S.GUIMeta.tr(1).duration = 1;
        S.GUIMeta.tr(1).type = 1;
        S.GUIMeta.tr(1).length = 1000;
        S.GUIMeta.tr(1).dist1 = 100;
        S.GUIMeta.tr(1).dist1En = 0;
        S.GUIMeta.tr(1).dist2 = 100;
        S.GUIMeta.tr(1).dist2En = 0;
        S.GUIMeta.tr(1).dist3 = 100;
        S.GUIMeta.tr(1).dist3En = 0;
        S.GUIMeta.tr(1).speed = 100;
        S.GUIMeta.tr(1).pump = 1000;
        S.GUIMeta.tr(1).led = 1;
        S.GUIMeta.tr(1).lcd = 1;
        S.GUIMeta.tr(1).next = 1;
        S.GUIMeta.tr(1).reflector = 1;
        S.GUIMeta.tr(1).laps = 1;
    else
        set(BpodSystem.GUIHandles.BCS.phasePopup, 'String', ' Phase 1');
        if (count > 1)
            for (loop = 2:count)
                C1 = get(BpodSystem.GUIHandles.BCS.phasePopup, 'String');
                C2 = [C1 ; ' Phase ',num2str(loop)];
                set(BpodSystem.GUIHandles.BCS.phasePopup, 'String', C2);
                set(BpodSystem.GUIHandles.BCS.nextPhasePopup, 'String', C2);
            end
        end
        S.GUIMeta.trial.phases = count;
        S.GUIMeta.trial.fileName = fileName;
        S.GUIMeta.trial.pathName = pathName;
        S.GUIMeta.trial_dirty = 0;
        S.GUIMeta.trial_loaded = 0;
        set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
    end
    set(phasePopup, 'Value', 1);
    setTrial(1);
    if (S.GUIMeta.trial.phases < 25)
        set(BpodSystem.GUIHandles.BCS.addPhase, 'Enable', 'on');
    else
        set(BpodSystem.GUIHandles.BCS.addPhase, 'Enable', 'off');
    end
    if (S.GUIMeta.trial.phases > 1)
        set(BpodSystem.GUIHandles.BCS.deletePhase, 'Enable', 'on');
    else
        set(BpodSystem.GUIHandles.BCS.deletePhase, 'Enable', 'off');
    end
    S.GUIMeta.trial_dirty = 0;
    S.GUIMeta.trial_loaded = 0;
    set(BpodSystem.GUIHandles.BCS.trialLoad,'Enable','on');
end
end
%----------------------------------------------------------------------

% save
%----------------------------------------------------------------------
function save(hObject,eventdata)
fullName = [S.GUIMeta.trial.pathName S.GUIMeta.trial.fileName];
if isempty(fullName)
    [fileName,pathName,filterIndex] = uiputfile('*.trl', ...
        'Save trial');
    if ~filterIndex         % No file was selected
        return
    else
        fullName = [pathName fileName];
        fh = fopen(fullName,'w');
        for index = 1:S.GUIMeta.trial.phases
            fprintf(fh,'%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u\r',...
                index,...
                S.GUIMeta.tr(index).duration,...
                S.GUIMeta.tr(index).type,...
                S.GUIMeta.tr(index).length,...
                S.GUIMeta.tr(index).dist1,...
                S.GUIMeta.tr(index).dist1En,...
                S.GUIMeta.tr(index).dist2,...
                S.GUIMeta.tr(index).dist2En,...
                S.GUIMeta.tr(index).dist3,...
                S.GUIMeta.tr(index).dist3En,...
                S.GUIMeta.tr(index).speed,...
                S.GUIMeta.tr(index).pump,...
                S.GUIMeta.tr(index).led,...
                S.GUIMeta.tr(index).lcd,...
                S.GUIMeta.tr(index).next,...
                S.GUIMeta.tr(index).reflector,...
                S.GUIMeta.tr(index).laps);
        end
        fclose(fh);
        S.GUIMeta.trial_dirty = 0;
    end
else
    fh = fopen(fullName,'w');
    for index = 1:S.GUIMeta.trial.phases
        fprintf(fh,'%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u\r',...
            index,...
            S.GUIMeta.tr(index).duration,...
            S.GUIMeta.tr(index).type,...
            S.GUIMeta.tr(index).length,...
            S.GUIMeta.tr(index).dist1,...
            S.GUIMeta.tr(index).dist1En,...
            S.GUIMeta.tr(index).dist2,...
            S.GUIMeta.tr(index).dist2En,...
            S.GUIMeta.tr(index).dist3,...
            S.GUIMeta.tr(index).dist3En,...
            S.GUIMeta.tr(index).speed,...
            S.GUIMeta.tr(index).pump,...
            S.GUIMeta.tr(index).led,...
            S.GUIMeta.tr(index).lcd,...
            S.GUIMeta.tr(index).next,...
            S.GUIMeta.tr(index).reflector,...
            S.GUIMeta.tr(index).laps);
    end
    fclose(fh);
    S.GUIMeta.trial_dirty = 0;
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
    for index = 1:S.GUIMeta.trial.phases
        fprintf(fh,'%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u\r',...
            index,...
            S.GUIMeta.tr(index).duration,...
            S.GUIMeta.tr(index).type,...
            S.GUIMeta.tr(index).length,...
            S.GUIMeta.tr(index).dist1,...
            S.GUIMeta.tr(index).dist1En,...
            S.GUIMeta.tr(index).dist2,...
            S.GUIMeta.tr(index).dist2En,...
            S.GUIMeta.tr(index).dist3,...
            S.GUIMeta.tr(index).dist3En,...
            S.GUIMeta.tr(index).speed,...
            S.GUIMeta.tr(index).pump,...
            S.GUIMeta.tr(index).led,...
            S.GUIMeta.tr(index).lcd,...
            S.GUIMeta.tr(index).next,...
            S.GUIMeta.tr(index).reflector,...
            S.GUIMeta.tr(index).laps);
    end
    fclose(fh);
    S.GUIMeta.trial_dirty = 0;
end
end
%----------------------------------------------------------------------

% quit
%----------------------------------------------------------------------
function quit (hObject,eventdata)
if (S.GUIMeta.trial_dirty == 1)
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
%if (S.GUIMeta.trial_dirty == 1)
%    savefile = questdlg('Save current trial before closing?', ...
%        'KatieBCS','Save','Cancel','Close','Save');
%    if strcmp(savefile,'Save')
%        save(obj,evnt);
%    elseif strcmp(savefile,'Cancel')
%        return;
%    end
%end
fclose('all');
%delete(s);
delete(obj);
end
%----------------------------------------------------------------------

