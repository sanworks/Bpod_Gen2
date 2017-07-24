classdef TrialManagerObject < handle
    properties
        Timer % MATLAB timer object to check for new events from the state machine
    end
    properties (Access = private)
        TrialEndFlag = 0; % 1 if trial reached an exit state, 0 if not
        PrepareNextTrialFlag = 0; % 1 if trial reached an exit state, 0 if not
        NextTrialTriggerStates % Vector of indexes of states that trigger MATLAB to prepare next trial
        InputMatrix
        GlobalTimerStartMatrix
        GlobalTimerEndMatrix
        GlobalCounterMatrix
        ConditionMatrix
        StateTimerMatrix
        GlobalTimerStartOffset
        GlobalTimerEndOffset
        GlobalCounterOffset
        ConditionOffset
        JumpOffset
        EventNames
        nEvents
        Events
        CurrentEvent
        StateChangeIndexes
        nStates
        nTotalStates
        States
        StateNames
        MaxEvents = 10000; % Maximum number of events possible in 1 trial (for preallocation)
    end
    methods
        function obj = TrialManagerObject %Constructor
            global BpodSystem
            if BpodSystem.EmulatorMode == 1
                error('Error: The Bpod emulator does not currently support running state machines with TrialManager.') 
            end
            obj.Timer = timer('TimerFcn',@(h,e)obj.processLiveEvents(), 'ExecutionMode', 'fixedRate', 'Period', 0.001);
        end
        function startTrial(obj, StateMatrix)
            global BpodSystem
            obj.PrepareNextTrialFlag = 0;
            obj.TrialEndFlag = 0;
            if BpodSystem.BonsaiSocket.Connected == 1
                BonsaiBytesAvailable = BpodSocketServer('bytesAvailable');
                if BonsaiBytesAvailable > 0
                    BpodSocketServer('read', BonsaiBytesAvailable);
                end
            end
            SendStateMachine(StateMatrix, 'RunImmediately');
            SMA_Confirmed = BpodSystem.SerialPort.read(1, 'uint8');
            if isempty(SMA_Confirmed)
                error('Error: The last state machine sent was not acknowledged by the Bpod device.');
            elseif SMA_Confirmed ~= 1
                error('Error: The last state machine sent was not acknowledged by the Bpod device.');
            end
            %toc
            BpodSystem.Status.NewStateMachineSent = 0;
            BpodSystem.Status.LastStateCode = 0;
            BpodSystem.Status.CurrentStateCode = 1;
            BpodSystem.Status.LastStateName = 'None';
            BpodSystem.Status.CurrentStateName = BpodSystem.StateMatrix.StateNames{1};
            BpodSystem.HardwareState.OutputOverride(1:end) = 0;
            BpodSystem.RefreshGUI;
            TimeElapsed = ceil((now*100000) - BpodSystem.ProtocolStartTime);
            set(BpodSystem.GUIHandles.TimeDisplay, 'String', obj.Secs2HMS(TimeElapsed));
            set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton);
            BpodSystem.Status.BeingUsed = 1;
            BpodSystem.Status.InStateMatrix = 1;
            if BpodSystem.EmulatorMode == 1
                RunBpodEmulator('init', []);
                BpodSystem.ManualOverrideFlag = 0;
            end
            obj.InputMatrix = BpodSystem.StateMatrix.InputMatrix;
            obj.GlobalTimerStartMatrix = BpodSystem.StateMatrix.GlobalTimerStartMatrix;
            obj.GlobalTimerEndMatrix = BpodSystem.StateMatrix.GlobalTimerEndMatrix;
            obj.GlobalCounterMatrix = BpodSystem.StateMatrix.GlobalCounterMatrix;
            obj.ConditionMatrix = BpodSystem.StateMatrix.ConditionMatrix;
            obj.StateTimerMatrix = BpodSystem.StateMatrix.StateTimerMatrix;
            obj.GlobalTimerStartOffset = BpodSystem.StateMatrix.meta.InputMatrixSize+1;
            obj.GlobalTimerEndOffset = obj.GlobalTimerStartOffset+BpodSystem.HW.n.GlobalTimers;
            obj.GlobalCounterOffset = obj.GlobalTimerEndOffset+BpodSystem.HW.n.GlobalTimers;
            obj.ConditionOffset = obj.GlobalCounterOffset+BpodSystem.HW.n.GlobalCounters;
            obj.JumpOffset = obj.ConditionOffset+BpodSystem.HW.n.Conditions;
            obj.EventNames = BpodSystem.StateMachineInfo.EventNames;
            obj.nEvents = 0; obj.nStates = 1;
            obj.Events = zeros(1,obj.MaxEvents); obj.States = zeros(1,obj.MaxEvents);
            obj.CurrentEvent = zeros(1,10);
            obj.StateChangeIndexes = zeros(1,obj.MaxEvents);
            obj.States(obj.nStates) = 1;
            obj.StateNames = BpodSystem.StateMatrix.StateNames;
            obj.nTotalStates = BpodSystem.StateMatrix.nStatesInManifest;
            start(obj.Timer);
        end
        function RawTrialEvents = getTrialData(obj)
            global BpodSystem
            RawTrialEvents = struct;
            while ~obj.TrialEndFlag && BpodSystem.Status.BeingUsed == 1 % Hang until trial is over
                drawnow;
            end
            if BpodSystem.Status.BeingUsed == 1
                obj.Events = obj.Events(1:obj.nEvents);
                obj.States = obj.States(1:obj.nStates);
                % Accept Timestamps
                if BpodSystem.EmulatorMode == 0
                    TrialStartTimestamp =  double(BpodSystem.SerialPort.read(1, 'uint32'))/1000; % Start-time of the trial in milliseconds (immune to 32-bit clock rollover)
                    nTimeStamps = double(BpodSystem.SerialPort.read(1, 'uint16'));
                    TimeStamps = double(BpodSystem.SerialPort.read(nTimeStamps, 'uint32'));
                    TimeScaleFactor = (BpodSystem.HW.CyclePeriod/1000);
                    TimeStamps = TimeStamps*TimeScaleFactor;
                else
                    TrialStartTimestamp = BpodSystem.Emulator.MatrixStartTime-(BpodSystem.Status.BpodStartTime*100000);
                    TimeStamps = (BpodSystem.Emulator.Timestamps(1:BpodSystem.Emulator.nEvents)*1000);
                end
                obj.StateChangeIndexes = obj.StateChangeIndexes(1:obj.nStates-1);
                EventTimeStamps = TimeStamps;
                StateTimeStamps = zeros(1,obj.nStates);
                StateTimeStamps(2:obj.nStates) = TimeStamps(obj.StateChangeIndexes); % Figure out StateChangeIndexes has a "change" event for sma start (longer than nEvents)
                StateTimeStamps(1) = 0;
                RawTrialEvents.States = obj.States;
                RawTrialEvents.Events = obj.Events;
                RawTrialEvents.StateTimestamps = obj.Round2Millis(StateTimeStamps)/1000; % Convert to seconds
                RawTrialEvents.EventTimestamps = obj.Round2Millis(EventTimeStamps)/1000;
                RawTrialEvents.TrialStartTimestamp = obj.Round2Millis(TrialStartTimestamp);
                RawTrialEvents.StateTimestamps(end+1) = RawTrialEvents.EventTimestamps(end);
            else
                stop(obj.Timer);
                delete(obj.Timer);
                obj.Timer = [];
            end
            obj.SetBpodHardwareMirror2CurrentState(0);
            BpodSystem.Status.InStateMatrix = 0;
        end
        function CurrentEvents = getCurrentEvents(obj, triggerStates)
            global BpodSystem
            if ~isempty(triggerStates)
                if ischar(triggerStates)
                    triggerStates = {triggerStates};
                elseif ~iscell(triggerStates)
                    error('Error running TrialManagerObject.getCurrentEvents() - triggerStates argument must be a cell array of strings')
                end
                obj.NextTrialTriggerStates = find(ismember(BpodSystem.StateMatrix.StateNames, triggerStates));
                if length(obj.NextTrialTriggerStates) == length(triggerStates)
                    CurrentEvents = struct;
                    while ~obj.PrepareNextTrialFlag && BpodSystem.Status.BeingUsed == 1 && BpodSystem.Status.InStateMatrix == 1
                        pause(.001); % Hang until a prepare next trial trigger state is reached
                    end
                    if BpodSystem.Status.BeingUsed == 1
                        CurrentEvents.RawData = struct;
                        CurrentEvents.RawData.StatesVisited = obj.States(1:obj.nStates);
                        CurrentEvents.RawData.EventsCaptured = obj.Events(1:obj.nEvents);
                        CurrentEvents.StatesVisited = BpodSystem.StateMatrix.StateNames(CurrentEvents.RawData.StatesVisited);
                        CurrentEvents.EventsCaptured = BpodSystem.StateMachineInfo.EventNames(CurrentEvents.RawData.EventsCaptured);
                    else
                        stop(obj.Timer);
                        delete(obj.Timer);
                        obj.Timer = [];
                    end
                else
                    error('Error running TrialManagerObject.getCurrentEvents() - triggerStates argument contains at least 1 invalid state name.')
                end
            else
                error('Error running TrialManagerObject.getCurrentEvents() - triggerStates argument must be a cell array of strings')
            end
        end
        function delete(obj)
            if ~isempty(obj.Timer)
                stop(obj.Timer);
                delete(obj.Timer);
                obj.Timer = [];
            end
        end
    end
    methods (Access = private)
        function processLiveEvents(obj, e)
            global BpodSystem
            if BpodSystem.EmulatorMode == 0
                NewMessage = 0;
                if BpodSystem.SerialPort.bytesAvailable > 0
                    NewMessage = 1;
                    opCodeBytes = BpodSystem.SerialPort.read(2, 'uint8');
                end
            else
                if BpodSystem.BonsaiSocket.Connected == 1
                    if BpodSocketServer('bytesAvailable') > 0
                        Byte = ReadOscByte;
                        OverrideMessage = ['VS' Byte];
                        BpodSystem.VirtualManualOverrideBytes = OverrideMessage;
                        BpodSystem.ManualOverrideFlag = 1;
                    end
                end
                if BpodSystem.ManualOverrideFlag == 1;
                    ManualOverrideEvent = VirtualManualOverride(BpodSystem.VirtualManualOverrideBytes);
                    BpodSystem.ManualOverrideFlag = 0;
                else
                    ManualOverrideEvent = [];
                end
                [NewMessage, opCodeBytes, VirtualCurrentEvents] = RunBpodEmulator('loop', ManualOverrideEvent);
            end
            if NewMessage
                opCode = opCodeBytes(1);
                switch opCode
                    case 1 % Receive and handle events
                        nCurrentEvents = double(opCodeBytes(2));
                        if BpodSystem.EmulatorMode == 0
                            TempCurrentEvents = BpodSystem.SerialPort.read(nCurrentEvents, 'uint8');
                        else
                            TempCurrentEvents = VirtualCurrentEvents;
                        end
                        obj.CurrentEvent(1:nCurrentEvents) = TempCurrentEvents(1:nCurrentEvents) + 1; % Read and convert from c++ index at 0 to MATLAB index at 1
                        TransitionEventFound = 0; i = 1;
                        NewState = BpodSystem.Status.CurrentStateCode;
                        while (TransitionEventFound == 0) && (i <= nCurrentEvents)
                            if obj.CurrentEvent(i) == 255
                                obj.TrialEndFlag = 1;
                                stop(obj.Timer);
                                BpodSystem.Status.InStateMatrix = 0;
                                break
                            elseif obj.CurrentEvent(i) < obj.GlobalTimerStartOffset
                                NewState = obj.InputMatrix(BpodSystem.Status.CurrentStateCode, obj.CurrentEvent(i));
                            elseif obj.CurrentEvent(i) < obj.GlobalTimerEndOffset
                                NewState = obj.GlobalTimerStartMatrix(BpodSystem.Status.CurrentStateCode, obj.CurrentEvent(i)-(obj.GlobalTimerStartOffset-1));
                            elseif obj.CurrentEvent(i) < obj.GlobalCounterOffset
                                NewState = obj.GlobalTimerEndMatrix(BpodSystem.Status.CurrentStateCode, obj.CurrentEvent(i)-(obj.GlobalTimerEndOffset-1));
                            elseif obj.CurrentEvent(i) < obj.ConditionOffset
                                NewState = obj.GlobalCounterMatrix(BpodSystem.Status.CurrentStateCode, obj.CurrentEvent(i)-(obj.GlobalCounterOffset-1));
                            elseif obj.CurrentEvent(i) < obj.JumpOffset
                                NewState = obj.ConditionMatrix(BpodSystem.Status.CurrentStateCode, obj.CurrentEvent(i)-(obj.ConditionOffset-1));
                            elseif obj.CurrentEvent(i) == BpodSystem.HW.StateTimerPosition
                                NewState = obj.StateTimerMatrix(BpodSystem.Status.CurrentStateCode);
                            else
                                error(['Error: Unknown event code returned: ' num2str(obj.CurrentEvent(i))]);
                            end
                            if NewState ~= BpodSystem.Status.CurrentStateCode
                                TransitionEventFound = 1;
                            end
                            i = i + 1;
                        end
                        obj.SetBpodHardwareMirror2ReflectEvent(obj.CurrentEvent);
                        if NewState ~= BpodSystem.Status.CurrentStateCode
                            if  NewState <= obj.nTotalStates
                                if sum(obj.NextTrialTriggerStates == NewState) > 0
                                    obj.PrepareNextTrialFlag = 1;
                                end
                                obj.StateChangeIndexes(obj.nStates) = obj.nEvents+1;
                                obj.nStates = obj.nStates + 1;
                                obj.States(obj.nStates) = NewState;
                                BpodSystem.Status.LastStateCode = BpodSystem.Status.CurrentStateCode;
                                BpodSystem.Status.CurrentStateCode = NewState;
                                BpodSystem.Status.CurrentStateName = obj.StateNames{NewState};
                                BpodSystem.Status.LastStateName = obj.StateNames{BpodSystem.Status.LastStateCode};
                                obj.SetBpodHardwareMirror2CurrentState(NewState);
                                if BpodSystem.EmulatorMode == 1
                                    BpodSystem.Emulator.CurrentState = NewState;
                                    BpodSystem.Emulator.StateStartTime = BpodSystem.Emulator.CurrentTime;
                                    % Set global timer end-time
                                    ThisGlobalTimer = BpodSystem.StateMatrix.OutputMatrix(NewState,BpodSystem.HW.Pos.GlobalTimerTrig);
                                    if ThisGlobalTimer ~= 0
                                        if BpodSystem.StateMatrix.GlobalTimers.OnsetDelay(ThisGlobalTimer) == 0
                                            BpodSystem.Emulator.GlobalTimerEnd(ThisGlobalTimer) = BpodSystem.Emulator.CurrentTime + BpodSystem.StateMatrix.GlobalTimers.Duration(ThisGlobalTimer);
                                            BpodSystem.Emulator.GlobalTimersActive(ThisGlobalTimer) = 1;
                                            BpodSystem.Emulator.GlobalTimersTriggered(ThisGlobalTimer) = 0;
                                        else
                                            BpodSystem.Emulator.GlobalTimerStart(ThisGlobalTimer) = BpodSystem.Emulator.CurrentTime + BpodSystem.StateMatrix.GlobalTimers.OnsetDelay(ThisGlobalTimer);
                                            BpodSystem.Emulator.GlobalTimerEnd(ThisGlobalTimer) = BpodSystem.Emulator.GlobalTimerStart(ThisGlobalTimer) + BpodSystem.StateMatrix.GlobalTimers.Duration(ThisGlobalTimer);
                                            BpodSystem.Emulator.GlobalTimersTriggered(ThisGlobalTimer) = 1;
                                        end
                                    end
                                    % Cancel global timers
                                    ThisGlobalTimer = BpodSystem.StateMatrix.OutputMatrix(NewState,BpodSystem.HW.Pos.GlobalTimerCancel);
                                    if ThisGlobalTimer ~= 0
                                        BpodSystem.Emulator.GlobalTimersActive(ThisGlobalTimer) = 0;
                                    end
                                    % Reset global counter counts
                                    ThisGlobalCounter = BpodSystem.StateMatrix.OutputMatrix(NewState,BpodSystem.HW.Pos.GlobalCounterReset);
                                    if ThisGlobalCounter ~= 0
                                        BpodSystem.Emulator.GlobalCounterCounts(ThisGlobalCounter) = 0;
                                    end
                                    % Update soft code
                                    BpodSystem.Emulator.SoftCode = BpodSystem.StateMatrix.OutputMatrix(NewState,BpodSystem.HW.Pos.Output_USB);
                                end
                            else
                                if BpodSystem.EmulatorMode == 1
                                    obj.StateChangeIndexes(obj.nStates) = obj.nEvents+1;
                                    obj.Events(obj.nEvents+1:(obj.nEvents+nCurrentEvents)) = obj.CurrentEvent(1:nCurrentEvents);
                                    obj.nEvents = obj.nEvents + nCurrentEvents;
                                    obj.TrialEndFlag = 1;
                                    stop(obj.Timer);
                                end
                            end
                        end
                        if BpodSystem.Status.InStateMatrix == 1
                            BpodSystem.RefreshGUI;
                            obj.Events(obj.nEvents+1:(obj.nEvents+nCurrentEvents)) = obj.CurrentEvent(1:nCurrentEvents);
                            BpodSystem.Status.LastEvent = obj.CurrentEvent(1);
                            obj.CurrentEvent(1:nCurrentEvents) = 0;
                            set(BpodSystem.GUIHandles.LastEventDisplay, 'string', obj.EventNames{BpodSystem.Status.LastEvent});
                            obj.nEvents = obj.nEvents + uint16(nCurrentEvents);
                        end
                    case 2 % Soft-code
                        SoftCode = opCodeBytes(2);
                        obj.HandleSoftCode(SoftCode);
                    otherwise
                        disp('Error: Invalid op code received')
                end
            else
                if BpodSystem.EmulatorMode == 0
                    if BpodSystem.BonsaiSocket.Connected == 1
                        if BpodSocketServer('bytesAvailable') > 0
                            Byte = ReadOscByte;
                            OverrideMessage = ['VS' Byte];
                            BpodSystem.SerialPort.write(OverrideMessage, 'uint8');
                        end
                    end
                end
            end
        end
        function TimeString = Secs2HMS(~, Seconds)
            H = floor(Seconds/3600);
            Seconds = Seconds-(H*3600);
            M = floor(Seconds/60);
            S = Seconds - (M*60);
            if M < 10
                MPad = '0';
            else
                MPad = '';
            end
            if S < 10
                SPad = '0';
            else
                SPad = '';
            end
            TimeString = [num2str(H) ':' MPad num2str(M) ':' SPad num2str(S)];
        end
        function HandleSoftCode(~,SoftCode)
            global BpodSystem
            eval([BpodSystem.SoftCodeHandlerFunction '(' num2str(SoftCode) ')'])
        end
        function ManualOverrideEvent = VirtualManualOverride(~,OverrideMessage)
            % Converts the byte code transmission formatted for the state machine into event codes
            global BpodSystem
            OpCode = OverrideMessage(1);
            if OpCode == 'V'
                InputChannel = OverrideMessage(2)+1;
                EventType = BpodSystem.HardwareState.InputType(InputChannel);
                if ~strcmp(EventType, {'U','X'})
                    NewChannelState = BpodSystem.HardwareState.InputState(InputChannel);
                    ManualOverrideEvent = BpodSystem.HW.Pos.Event_BNC-1 + 2*(InputChannel-BpodSystem.HW.Pos.Output_USB)-1 + (1-NewChannelState);
                else
                    switch EventType
                        case 'U'
                            ManualOverrideEvent = [];
                        case 'X'
                            ManualOverrideEvent = [];
                    end
                end
            elseif OpCode == 'S'
                HandleSoftCode(uint8(OverrideMessage(2)));
                ManualOverrideEvent = [];
            else
                ManualOverrideEvent = [];
            end
        end
        function SetBpodHardwareMirror2ReflectEvent(~,Events)
            global BpodSystem
            nEvents = sum(Events ~= 0);
            for i = 1:nEvents
                thisEvent = Events(i);
                if thisEvent ~= 255
                    switch BpodSystem.HW.EventTypes(thisEvent)
                        case 'I'
                            p = ((thisEvent-BpodSystem.HW.IOEventStartposition)/2)+BpodSystem.HW.n.SerialChannels+1;
                            thisChannel = floor(p);
                            isOdd = rem(p,1);
                            if isOdd == 0
                                BpodSystem.HardwareState.InputState(thisChannel) = 1;
                            else
                                BpodSystem.HardwareState.InputState(thisChannel) = 0;
                            end
                        case 'T'
                            timerEvent = thisEvent-BpodSystem.HW.GlobalTimerStartposition+1;
                            if timerEvent <= BpodSystem.HW.n.GlobalTimers
                                timerNumber = timerEvent;
                                EventType = 1; % On
                            else
                                timerNumber = timerEvent-BpodSystem.HW.n.GlobalTimers;
                                EventType = 0; % Off
                            end
                            if BpodSystem.StateMatrix.GlobalTimers.OutputChannel(timerNumber) < 255
                                outputChannel = BpodSystem.StateMatrix.GlobalTimers.OutputChannel(timerNumber);
                                outputChannelType = BpodSystem.HW.Outputs(outputChannel);
                                switch outputChannelType
                                    case {'B', 'W', 'P'}
                                        BpodSystem.HardwareState.OutputState(outputChannel) = EventType;
                                        BpodSystem.HardwareState.OutputOverride(outputChannel) = EventType;
                                end
                            end
                    end
                end
            end
        end
        function SetBpodHardwareMirror2CurrentState(~,CurrentState)
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
        function MilliOutput = Round2Millis(~,DecimalInput)
            MilliOutput = round(DecimalInput*(1000))/(1000);
        end
    end
end
