%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2021 Sanworks LLC, Stony Brook, New York, USA

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
classdef BpodClientObject < handle
    properties
        DIOChannelMap = struct; % Maps DIO channels to Bpod channels
        DINChannelMap = struct; % Maps DIN channels to Bpod channels
    end
    properties (SetAccess = protected)
        
    end
    properties (Access = private)
        ReplyBuffer
        usePsychToolbox
        host
        port
        nDOlines
        nDIlines
        SMmeta
        CurrentEvents
        CurrentEventTimestamps
        nUnreadEvents
        nTotalEvents
        TrialStartTimestamp
        MaxEvents = 10000;
        TimeScaleFactor
        NewSMLoaded
        TrialDoneFlag
        nTrialsCompleted
        usesSPIValves
        usingHappenings % 1 if using, 0 if not
        happeningSpec
        hapMap % Map of Bpod input event codes to happSpec indexes
        LastEventTime % Actual last event time returned from SM
        LastEventTime_MATLAB % Last event time, as recorded using now()
        isPaused % True if paused, False if not
    end
    methods
        function obj = BpodClientObject(host, port)
            global BpodSystem
            obj.host = host;
            obj.port = port;
            obj.usePsychToolbox = BpodSystem.SerialPort.UsePsychToolbox;
            % Generate channel map
            output_lines = bSettings('get','DIOLINES','all');
            names = output_lines(:,1);
            binCodes = cell2mat(output_lines(:,2))';
            obj.nDOlines = length(dec2bin(max(binCodes)));
            obj.DIOChannelMap.Chan = zeros(1,obj.nDOlines);
            obj.DIOChannelMap.Index = zeros(1,obj.nDOlines);
            obj.DIOChannelMap.Type = zeros(1,obj.nDOlines);
            nPorts = 0; nBNC = 0; nWires = 0; nValves = 0;
            portPos = find(BpodSystem.HW.Outputs == 'P');
            bncPos = find(BpodSystem.HW.Outputs == 'B');
            wirePos = find(BpodSystem.HW.Outputs == 'W');
            obj.usesSPIValves = sum(BpodSystem.HW.Outputs == 'S') > 0;
            if obj.usesSPIValves
                valvePos = find(BpodSystem.HW.Outputs == 'S');
            else
                valvePos = find(BpodSystem.HW.Outputs == 'V');
            end
            for i = 1:obj.nDOlines
                if (i <= (BpodSystem.HW.n.Ports*2))
                    if rem(i,2) > 0
                        if obj.usesSPIValves
                            obj.DIOChannelMap.Type(i) = 'S';
                            obj.DIOChannelMap.Index(i) = 1;
                            obj.DIOChannelMap.Chan(i) = valvePos;
                        else
                            obj.DIOChannelMap.Type(i) = 'V';
                            nValves = nValves + 1;
                            obj.DIOChannelMap.Index(i) = nValves;
                            obj.DIOChannelMap.Chan(i) = valvePos(nValves);
                        end
                    else
                        obj.DIOChannelMap.Type(i) = 'P';
                        nPorts = nPorts + 1;
                        obj.DIOChannelMap.Index(i) = nPorts; %PortChannels(nPorts);
                        obj.DIOChannelMap.Chan(i) = portPos(nPorts);
                    end
                elseif (i <= (BpodSystem.HW.n.Ports*2)+BpodSystem.HW.n.BNCOutputs)
                    obj.DIOChannelMap.Type(i) = 'B';
                    nBNC = nBNC + 1;
                    obj.DIOChannelMap.Index(i) = nBNC; %PortChannels(nBNC);
                    obj.DIOChannelMap.Chan(i) = bncPos(nBNC);
                elseif (i <= (BpodSystem.HW.n.Ports*2)+BpodSystem.HW.n.BNCOutputs+BpodSystem.HW.n.WireOutputs)
                    obj.DIOChannelMap.Type(i) = 'W';
                    nWires = nWires + 1;
                    obj.DIOChannelMap.Index(i) = nWires; %PortChannels(nWires);
                    obj.DIOChannelMap.Chan(i) = wirePos(nWires);
                else
                    error('Error: your Settings_Custom.conf file specifies more output channels than your Bpod state machine supports.')
                end
            end
            % Generate Input channel map
            input_lines = bSettings('get','INPUTLINES','all');
            namesIn = input_lines(:,1); % Should always be {'C'; 'L'; 'R'} regardless of order in Settings_Custom.conf
            lineCodesIn = cell2mat(input_lines(:,2))';
            portPosIn = find(BpodSystem.HW.Inputs == 'P');
            obj.nDIlines = length(lineCodesIn);
            obj.DINChannelMap.Type = zeros(1,obj.nDOlines);
            obj.DINChannelMap.Index = zeros(1,obj.nDIlines);
            obj.DINChannelMap.Chan = zeros(1,obj.nDIlines);
            portPosIn = portPosIn(1:obj.nDIlines);
            nPortsIn = 0;
            for i = 1:obj.nDIlines
                nPortsIn = nPortsIn + 1;
                thisLine = lineCodesIn(nPortsIn);
                obj.DINChannelMap.Type(i) = 'P';
                obj.DINChannelMap.Index(i) = thisLine;
                obj.DINChannelMap.Chan(i) = portPosIn(thisLine);
            end
            
            % Generate reference map for quick Bcontrol dout channel -> Bpod output channel conversion
            DIO = [valvePos; portPos];
            DIO = DIO(1:end);
            BpodSystem.PluginObjects.Bcontrol2Bpod_DO_Map = [DIO bncPos];
            
            % Generate reference map for quick Bcontrol din channel -> Bpod input channel conversion 
            % Note: This is simply the order specified in Settings_Custom,
            % not an analog of the DO_MAP
            BpodSystem.PluginObjects.Bcontrol2Bpod_DI_Map = namesIn(lineCodesIn)';
            
            % Check for waveplayer - if it exists, initialize it
            if ~isfield(BpodSystem.PluginObjects, 'WavePlayer')
                if sum(strcmp('WavePlayer1', BpodSystem.Modules.Name)) > 0
                    if isfield(BpodSystem.ModuleUSB, 'WavePlayer1')
                        BpodSystem.PluginObjects.WavePlayer = BpodWavePlayer(BpodSystem.ModuleUSB.WavePlayer1);
                        BpodSystem.PluginObjects.WavePlayer.SamplingRate = BpodSystem.HW.CycleFrequency;
                        BpodSystem.PluginObjects.WavePlayer.OutputRange = '0V:10V';
                        % Setup trigger messages from state machine
                        nChannels = length(BpodSystem.PluginObjects.WavePlayer.BpodEvents);
                        TriggerMessages = cell(1,nChannels);
                        for i = 1:nChannels
                            TriggerMessages{i} = ['P' 2^(i-1) i-1];
                        end
                        LoadSerialMessages('WavePlayer1', TriggerMessages);
                    else
                        error('Error setting up Bpod WavePlayer for B-control: the WavePlayer''s USB port must be paired with its Bpod serial port. Use the USB menu on the Bpod console.')
                    end
                else
                    disp('############################################################');
                    disp(['ALERT! No WavePlayer module detected!' char(10) 'Protocols will error out if analog scheduled waves are used.'])
                    disp('############################################################');
                end
            end
            % Generate generic state names in advance (to speed up SM translation)
            BpodSystem.PluginObjects.DefaultStateNames = cell(1,BpodSystem.StateMachineInfo.MaxStates);
            for i = 1:BpodSystem.StateMachineInfo.MaxStates
               BpodSystem.PluginObjects.DefaultStateNames{i} = ['State#' num2str(i)]; 
            end
            obj.TrialStartTimestamp = 0;
            obj.nUnreadEvents = 0;
            obj.NewSMLoaded = 0;
            obj.TrialDoneFlag = 0;
            obj.usingHappenings = 0;
            obj.isPaused = 0;
            obj.TimeScaleFactor = (BpodSystem.HW.CyclePeriod/1000000);
        end
        function connect(obj)
            % Already connected, do nothing
        end
        function ok = sendstring(obj, string, varargin)
            global BpodSystem
            CommandDivs = find(string == sprintf('\n'));
            nCommands = length(CommandDivs);
            if nCommands == 0
                nCommands = 1;
                Commands = {string};
            else
                Commands = cell(1,nCommands);
                Pos = 1;
                for cmd = 1:nCommands
                    Commands{cmd} = string(Pos:CommandDivs(cmd)-1);
                    Pos = Pos + length(Commands{cmd}) + 1;
                end
            end
            for cmd = 1:nCommands
                thisCommand = Commands{cmd};
                %disp(thisCommand); % Uncomment to view commands sent from BControl to the state machine
                if ~isempty(strfind(thisCommand, 'BYPASS'))
                    msg = thisCommand(8:end);
                    spacePos = find(msg == ' ');
                    Target = msg(1:spacePos-1);
                    Value = msg(spacePos+1:end);
                    switch Target
                        case 'DOUT'
                            binValue = dec2bin(str2double(Value));
                            binValue = binValue(end:-1:1);
                            if length(binValue) < obj.nDOlines
                                binValue = [binValue repmat('0', 1, obj.nDOlines-length(binValue))];
                            end
                            nValves = 0;
                            for i = 1:obj.nDOlines
                                thisBit = str2double(binValue(i));
                                channelType = obj.DIOChannelMap.Type(i);
                                thisChannelIndex = obj.DIOChannelMap.Index(i);
                                thisChannel = obj.DIOChannelMap.Chan(i);
                                HWstate = thisBit;
                                if channelType == 'P'
                                    HWstate = HWstate*255;
                                end
                                if channelType == 'S'
                                    nValves = nValves + 1;
                                    if bitget(BpodSystem.HardwareState.OutputState(thisChannel),nValves) ~= HWstate
                                        ManualOverride('OS', thisChannelIndex, nValves);
                                    end
                                else
                                    if BpodSystem.HardwareState.OutputState(thisChannel) ~= HWstate
                                        ManualOverride(['O' channelType], thisChannelIndex);
                                    end
                                end
                            end
                    end
                    
                elseif ~isempty(strfind(thisCommand, 'SET STATE MATRIX'))
                    % set stuff
                    obj.SMmeta = varargin{1};
                    obj.ReplyBuffer = 'READY';
                else
                    switch thisCommand
                        case 'NOOP'
                            obj.ReplyBuffer = 'OK';
                        case 'VERSION'
                            obj.ReplyBuffer = num2str(BpodSystem.FirmwareVersion);
                        case 'INITIALIZE'
                           BpodSystem.Status.Live = 0;
                            if BpodSystem.EmulatorMode == 0
                                BpodSystem.SerialPort.write('X', 'uint8');
                                pause(.1);
                                nBytes = BpodSystem.SerialPort.bytesAvailable;
                                if nBytes > 0
                                    BpodSystem.SerialPort.read(nBytes, 'uint8');
                                end 
                            end
                            BpodSystem.Status.InStateMatrix = 0;
                            BpodSystem.Status.NewStateMachineSent = 0;
                            if obj.isPaused == 1
                                BpodSystem.SerialPort.write(['$' 1], 'uint8');
                                obj.isPaused = 0;
                            end
                            obj.nTrialsCompleted = 0;
                            obj.TrialStartTimestamp = 0;
                            BpodSystem.SerialPort.write('*', 'uint8'); % Reset session clock
                            OK = BpodSystem.SerialPort.read(1, 'uint8');
                            if OK ~= 1
                                error('Error: Did not receive confirmation after resetting Bpod session clock');
                            end
                        case 'SET STATE MACHINE 0'
                            % Done.
                        case 'GET TIME'
                            % Cannot actually ping Bpod for time; add MATLAB clock to last Bpod event timestamp
                            if obj.usePsychToolbox
                                currentTime = obj.LastEventTime+(GetSecs-obj.LastEventTime_MATLAB);
                            else
                                currentTime = obj.LastEventTime+((now-obj.LastEventTime_MATLAB)*100000);
                            end
                            obj.ReplyBuffer = num2str(currentTime);
                        case 'USE HAPPENINGS'
                            obj.usingHappenings = 1;
                        case 'DO NOT USE HAPPENINGS'
                            obj.usingHappenings = 0;
                        case 'SET HAPPENING SPEC'
                            obj.happeningSpec = varargin{1};
                            obj.usingHappenings = 1;
                        case 'HALT'
                            BpodSystem.SerialPort.write(['$' 0], 'uint8');
                            obj.isPaused = 1;
                        case 'RUN'
                            if obj.isPaused == 0
                                BpodSystem.SerialPort.write('R', 'uint8'); % Send the code to run the loaded matrix (character "R" for Run)
                                if BpodSystem.Status.NewStateMachineSent % Read confirmation byte = successful state machine transmission
                                    SMA_Confirmed = BpodSystem.SerialPort.read(1, 'uint8');
                                    if isempty(SMA_Confirmed) 
                                        error('Error: The last state machine sent was not acknowledged by the Bpod device.');
                                    elseif SMA_Confirmed ~= 1
                                        error('Error: The last state machine sent was not acknowledged by the Bpod device.');
                                    end
                                    BpodSystem.Status.NewStateMachineSent = 0;
                                end
                                TrialStartTimestampBytes = BpodSystem.SerialPort.read(8, 'uint8');
                                obj.TrialStartTimestamp = double(typecast(TrialStartTimestampBytes, 'uint64'))/1000000; % Start-time of the trial in microseconds (compensated for 32-bit clock rollover)
                                BpodSystem.StateMatrix = BpodSystem.StateMatrixSent;
                                BpodSystem.Status.LastStateCode = 0;
                                BpodSystem.Status.CurrentStateCode = 1;
                                BpodSystem.Status.LastStateName = 'None';
                                BpodSystem.Status.CurrentStateName = BpodSystem.StateMatrix.StateNames{1};
                                BpodSystem.HardwareState.OutputOverride(1:end) = 0;
                                obj.SetBpodHardwareMirror2CurrentState(1);
                                BpodSystem.Status.InStateMatrix = 1;
                                obj.CurrentEvents = zeros(1,obj.MaxEvents); 
                                obj.CurrentEventTimestamps = zeros(1,obj.MaxEvents);
                                obj.NewSMLoaded = 1;
                                obj.nTotalEvents = 0;
                                obj.TrialDoneFlag = 0;
                                obj.LastEventTime = 0;
                                obj.LastEventTime_MATLAB = now;
                                BpodSystem.PluginObjects.BcontrolEventCodeMap = BpodSystem.PluginObjects.BcontrolEventCodeMapBuffer;
                             else
                                 BpodSystem.SerialPort.write(['$' 1], 'uint8');
                                 obj.isPaused = 0;
                             end
                        case 'GET EVENT COUNTER'
                            obj.nUnreadEvents = 0;
                            nBytesAvailable = BpodSystem.SerialPort.bytesAvailable;
                            if (obj.TrialDoneFlag == 1) && (nBytesAvailable > 0)
                                if (BpodSystem.Status.NewStateMachineSent == 1)
                                    SMconfirmed = BpodSystem.SerialPort.read(1, 'uint8');
                                    if SMconfirmed ~= 1
                                        error('Error: a state machine sent to Bpod was not confirmed.')
                                    end
                                    BpodSystem.Status.NewStateMachineSent = 0;
                                    nBytesAvailable = BpodSystem.SerialPort.bytesAvailable;
                                end
                                if nBytesAvailable > 7
                                    TrialStartTimestampBytes = BpodSystem.SerialPort.read(8, 'uint8');
                                    obj.TrialStartTimestamp = double(typecast(TrialStartTimestampBytes, 'uint64'))/1000000; % Start-time of the trial in microseconds (compensated for 32-bit clock rollover)
                                    nBytesAvailable = BpodSystem.SerialPort.bytesAvailable;
                                end
                            end
                            if (nBytesAvailable > 3)
                                obj.TrialDoneFlag = 0;
                                while nBytesAvailable > 6 && obj.TrialDoneFlag == 0
                                    opCodeBytes = BpodSystem.SerialPort.read(2, 'uint8');
                                    opCode = opCodeBytes(1);
                                    switch opCode
                                        case 1 % Receive and handle events
                                            nEvents2Read = double(opCodeBytes(2));
                                            NewMessage = BpodSystem.SerialPort.read(nEvents2Read+4, 'uint8');
                                            NewEvents = NewMessage(1:nEvents2Read)+1;
                                            NewTimestamp = double(typecast(NewMessage(end-3:end), 'uint32'))*obj.TimeScaleFactor;
                                            % Filter out events unsupported by B-control (e.g. module events)
                                            ValidBcontrolEvents = NewEvents >= BpodSystem.HW.Pos.Event_Port;
                                            NewEvents = NewEvents(ValidBcontrolEvents);
                                            nCurrentEvents = length(NewEvents);
                                            % Update object
                                            if nCurrentEvents > 0
                                                obj.CurrentEvents(obj.nUnreadEvents+1:obj.nUnreadEvents+nCurrentEvents) = NewEvents;
                                                obj.CurrentEventTimestamps(obj.nUnreadEvents+1:obj.nUnreadEvents+nCurrentEvents) = NewTimestamp;
                                                obj.nUnreadEvents = obj.nUnreadEvents + nCurrentEvents;
                                                obj.nTotalEvents = obj.nTotalEvents + nCurrentEvents;
                                                for i = 1:nCurrentEvents
                                                    if NewEvents(i) == 255 % Exit code
                                                        obj.TrialDoneFlag = 1;
                                                        obj.nTotalEvents = obj.nTotalEvents - 1;
                                                        TrialEndTimestamps = BpodSystem.SerialPort.read(12, 'uint8');
                                                        nHWTimerCycles = double(typecast(TrialEndTimestamps(1:4), 'uint32'));
                                                        TrialEndTimestamp = double(typecast(TrialEndTimestamps(5:12), 'uint64'))/1000000;                                                        
                                                        TrialTimeFromMicros = (TrialEndTimestamp - obj.TrialStartTimestamp);
                                                        TrialTimeFromCycles = (nHWTimerCycles/BpodSystem.HW.CycleFrequency)+0.001; % Add 1ms to adjust for bias due to placement of millis() in start+end code
                                                        Discrepancy = round(abs(TrialTimeFromMicros - TrialTimeFromCycles)*1000);
                                                        if Discrepancy > 1
                                                            disp([char(10) '***WARNING!***' char(10) 'Bpod missed hardware update deadline(s) on the past trial, by ~' num2str(Discrepancy)...
                                                            'ms!' char(10) 'An error code (1) has been added to your trial data.' char(10) '**************'])
                                                        end
                                                    end
                                                end
                                            end
                                            obj.LastEventTime = obj.TrialStartTimestamp+NewTimestamp;
                                            if obj.usePsychToolbox
                                                obj.LastEventTime_MATLAB = GetSecs;
                                            else
                                                obj.LastEventTime_MATLAB = now;
                                            end
                                            nBytesAvailable = nBytesAvailable - (6+nEvents2Read); % 6 = 4 timestamp bytes + 2 op bytes
                                        case 2
                                            error('Error: Bpod soft code returned from state machine. Soft codes are not supported for B-control protocols.')
                                    end
                                end
                            end
                            obj.ReplyBuffer = num2str(obj.nTotalEvents); %num2str(obj.nUnreadEvents);
                        case 'GET EVENTS_II'
                            if obj.nUnreadEvents > 0
                                CEprestates = zeros(1,obj.nUnreadEvents);
                                CEevents = ones(1,obj.nUnreadEvents)*-1;
                                CETimestamps = zeros(1,obj.nUnreadEvents);
                                CEpoststates = zeros(1,obj.nUnreadEvents);
                                FifthCol = zeros(1,obj.nUnreadEvents);

                                GlobalTimerStartOffset = BpodSystem.StateMatrix.meta.InputMatrixSize+1;
                                GlobalTimerEndOffset = GlobalTimerStartOffset+BpodSystem.HW.n.GlobalTimers;
                                GlobalCounterOffset = GlobalTimerEndOffset+BpodSystem.HW.n.GlobalTimers;
                                ConditionOffset = GlobalCounterOffset+BpodSystem.HW.n.GlobalCounters;
                                JumpOffset = ConditionOffset+BpodSystem.HW.n.Conditions;
                                if obj.NewSMLoaded == 1 % The GET EVENT COUNTER function always returns up to trial end, so on the next call this is added first
                                    if obj.nTrialsCompleted == 0
                                        PreTrialRows = [0 -1 obj.TrialStartTimestamp-0.0001 0 0; 0 -1 obj.TrialStartTimestamp 40 0];
                                        %PreTrialRows = [0 -1 obj.TrialStartTimestamp-0.0001 0 0];
                                    else
                                        PreTrialRows = [0 -1 obj.TrialStartTimestamp 39 0];
                                        %PreTrialRows = [];
                                    end
                                    BpodSystem.StateMatrix = BpodSystem.StateMatrixSent;
                                    BpodSystem.PluginObjects.BcontrolEventCodeMap = BpodSystem.PluginObjects.BcontrolEventCodeMapBuffer;
                                    BpodSystem.Status.LastStateCode = 0;
                                    BpodSystem.Status.CurrentStateCode = 1;
                                    obj.NewSMLoaded = 0;
                                else
                                    PreTrialRows = [];
                                end
                                i = 1; ExitEventFound = 0;
                                nCurrentEvents = obj.nUnreadEvents;
                                while i <= obj.nUnreadEvents
                                    if obj.CurrentEvents(i) ~= 255
                                        CEprestates(i) = BpodSystem.Status.CurrentStateCode;
                                        thisEvent = obj.CurrentEvents(i);
                                        if thisEvent >= BpodSystem.HW.Pos.Event_Port
                                            CEevents(i) = BpodSystem.PluginObjects.BcontrolEventCodeMap(thisEvent);
                                        else
                                            error(['Error: Bpod event ' BpodSystem.StateMachineInfo.EventNames{thisEvent} ' occurred, but is not supported by B-control'])
                                        end
                                        CETimestamps(i) = obj.CurrentEventTimestamps(i) + obj.TrialStartTimestamp;
                                    end
                                    if obj.CurrentEvents(i) == 255
                                        if nCurrentEvents == 1 % Only a trial-end code was sent
                                            EndTimestamp = CETimestamps(1); % Save timestamp of trial-end code
                                        end
                                        nCurrentEvents = nCurrentEvents-1;
                                        CEprestates = CEprestates(1:nCurrentEvents);
                                        CEevents = CEevents(1:nCurrentEvents);
                                        CETimestamps = CETimestamps(1:nCurrentEvents);
                                        FifthCol = FifthCol(1:nCurrentEvents);
                                        ExitEventFound = 1;
                                        obj.NewSMLoaded = 1; % Flag to add trial init states on next call to GET_Events2
                                        obj.nTrialsCompleted = obj.nTrialsCompleted + 1;
                                        if ~(BpodSystem.Status.NewStateMachineSent && BpodSystem.Status.SM2runASAP)
                                            BpodSystem.Status.InStateMatrix = 0;
                                        end
                                    elseif obj.CurrentEvents(i) < GlobalTimerStartOffset
                                        BpodSystem.Status.CurrentStateCode = BpodSystem.StateMatrix.InputMatrix(BpodSystem.Status.CurrentStateCode, obj.CurrentEvents(i));
                                    elseif obj.CurrentEvents(i) < GlobalTimerEndOffset
                                        BpodSystem.Status.CurrentStateCode = BpodSystem.StateMatrix.GlobalTimerStartMatrix(BpodSystem.Status.CurrentStateCode, obj.CurrentEvents(i)-(GlobalTimerStartOffset-1));
                                    elseif obj.CurrentEvents(i) < GlobalCounterOffset
                                        BpodSystem.Status.CurrentStateCode = BpodSystem.StateMatrix.GlobalTimerEndMatrix(BpodSystem.Status.CurrentStateCode, obj.CurrentEvents(i)-(GlobalTimerEndOffset-1));
                                    elseif obj.CurrentEvents(i) < ConditionOffset
                                        BpodSystem.Status.CurrentStateCode = BpodSystem.StateMatrix.GlobalCounterMatrix(BpodSystem.Status.CurrentStateCode, obj.CurrentEvents(i)-(GlobalCounterOffset-1));
                                    elseif obj.CurrentEvents(i) < JumpOffset
                                        BpodSystem.Status.CurrentStateCode = BpodSystem.StateMatrix.ConditionMatrix(BpodSystem.Status.CurrentStateCode, obj.CurrentEvents(i)-(ConditionOffset-1));
                                    elseif obj.CurrentEvents(i) == BpodSystem.HW.StateTimerPosition
                                        BpodSystem.Status.CurrentStateCode = BpodSystem.StateMatrix.StateTimerMatrix(BpodSystem.Status.CurrentStateCode);
                                    else
                                        error(['Error: Unknown event code returned: ' num2str(CurrentEvent(i))]);
                                    end
                                    if ~ExitEventFound
                                        CEpoststates(i) = BpodSystem.Status.CurrentStateCode;
                                    end
                                    i = i + 1;
                                end
                                CEpoststates = CEpoststates(1:nCurrentEvents);
                                if ExitEventFound
                                    if nCurrentEvents > 0
                                        PostTrialRow = [35 -1 CETimestamps(end) 0 0];
                                    else
                                        % Only a trial-end code was captured in this update; use its timestamp
                                        % (identical to timestamp of final event)
                                        PostTrialRow = [35 -1 EndTimestamp 0 0];
                                    end
                                else
                                    PostTrialRow = [];
                                end
                                CEprestates = CEprestates + 38;
                                CEpoststates = CEpoststates + 38;
                                CEpoststates(CEpoststates == BpodSystem.StateMatrix.nStatesInManifest+39) = 35;
                                ReplyMatrix = [CEprestates' CEevents' CETimestamps' CEpoststates' FifthCol'];
                                ReplyMatrix = [PreTrialRows; ReplyMatrix; PostTrialRow];
                                obj.ReplyBuffer = ReplyMatrix;
                                obj.nUnreadEvents = 0;
                                obj.CurrentEvents = zeros(1,obj.MaxEvents); 
                                obj.CurrentEventTimestamps = zeros(1,obj.MaxEvents);
                            else
                                obj.ReplyBuffer = zeros(0,4);
                            end
                    end
                end
            end
            ok = 1;
        end
        function message = readlines(obj)
            message = obj.ReplyBuffer;
            obj.ReplyBuffer = [];
        end
        function message = readmatrix(obj)
            message = obj.ReplyBuffer;
            obj.ReplyBuffer = [];
        end
        
        function ok = sendmatrix(obj, sma)
            
            
            ok = 1;
        end
        
        function SetBpodHardwareMirror2CurrentState(obj,CurrentState)
            global BpodSystem
            if CurrentState > 0
                NewOutputState = BpodSystem.StateMatrix.OutputMatrix(CurrentState,:);
                OutputOverride = BpodSystem.HardwareState.OutputOverride;
                BpodSystem.HardwareState.OutputState(~OutputOverride) = NewOutputState(~OutputOverride);
            else
                BpodSystem.HardwareState.InputState(1:end) = 0;
                BpodSystem.HardwareState.OutputState(1:end) = 0;
                BpodSystem.RefreshGUI;
            end
        end
        
        function disconnect(obj)
            % Already disconnected, do nothing
        end
        function delete(obj)
            
        end
    end
end