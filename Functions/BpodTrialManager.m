%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2022 Sanworks LLC, Rochester, New York, USA

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

classdef BpodTrialManager < handle
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
        LiveEventTimestamps
        MaxEvents = 100000; % Maximum number of events possible in 1 trial (for preallocation)
        TimeScaleFactor
        TrialStartTimestamp
        LastTrialEndTime
        usingBonsai
    end
    methods
        function obj = BpodTrialManager %Constructor
            global BpodSystem
            if isempty(BpodSystem)
                error('You must run Bpod() before creating an instance of BpodTrialManager.')
            end
            if BpodSystem.EmulatorMode == 1
                error('Error: The Bpod emulator does not currently support running state machines with TrialManager.')
            end
            obj.TimeScaleFactor = (BpodSystem.HW.CyclePeriod/1000);
            obj.LastTrialEndTime = 0;
            obj.Timer = timer('TimerFcn',@(h,e)obj.processLiveEvents(), 'ExecutionMode', 'fixedRate', 'Period', 0.01);
            obj.usingBonsai = 0;
            if ~isempty(BpodSystem.BonsaiSocket)
                obj.usingBonsai = 1;
                BonsaiBytesAvailable = BpodSystem.BonsaiSocket.bytesAvailable;
                if BonsaiBytesAvailable > 0
                    BpodSystem.BonsaiSocket.read(BonsaiBytesAvailable, 'uint8');
                end
            end
        end
        function startTrial(obj, varargin)
            global BpodSystem
            smaSent = 1;
            if nargin > 1
                smaSent = 0;
                StateMatrix = varargin{1};
            end
            obj.PrepareNextTrialFlag = 0;
            obj.TrialEndFlag = 0;
            if BpodSystem.Status.SessionStartFlag == 1 % On first run of session
                BpodSystem.Status.SessionStartFlag = 0;
                if BpodSystem.MachineType == 4
                    BpodSystem.AnalogSerialPort.flush;
                    start(BpodSystem.Timers.AnalogTimer);
                end
            end
            if smaSent
                if BpodSystem.Status.SM2runASAP == 0
                    BpodSystem.SerialPort.write('R', 'uint8');
                end
                BpodSystem.Status.BeingUsed = 1;
                BpodSystem.Status.InStateMatrix = 1;
            else
                BpodSystem.Status.BeingUsed = 1;
                SendStateMachine(StateMatrix, 'RunASAP'); 
                BpodSystem.Status.InStateMatrix = 1;
            end
            BpodSystem.Status.SM2runASAP = 0;
            SMA_Confirmed = BpodSystem.SerialPort.read(1, 'uint8');
            if isempty(SMA_Confirmed)
                BpodSystem.Status.BeingUsed = 0;
                BpodSystem.Status.InStateMatrix = 0;
                error('Error: The last state machine sent was not acknowledged by the Bpod device.');
            elseif SMA_Confirmed ~= 1
                BpodSystem.Status.BeingUsed = 0;
                BpodSystem.Status.InStateMatrix = 0;
                error('Error: The last state machine sent was not acknowledged by the Bpod device.');
            end
            TrialStartTimestampBytes = BpodSystem.SerialPort.read(8, 'uint8');
            obj.TrialStartTimestamp = double(typecast(TrialStartTimestampBytes, 'uint64'))/1000000; % Start-time of the trial in microseconds (compensated for 32-bit clock rollover)
            BpodSystem.StateMatrix = BpodSystem.StateMatrixSent;
            BpodSystem.Status.NewStateMachineSent = 0;
            BpodSystem.Status.LastStateCode = 0;
            BpodSystem.Status.CurrentStateCode = 1;
            BpodSystem.Status.LastStateName = '---';
            BpodSystem.Status.CurrentStateName = BpodSystem.StateMatrix.StateNames{1};
            BpodSystem.HardwareState.OutputOverride(1:end) = 0;
            BpodSystem.RefreshGUI;
            TimeElapsed = ceil((now*100000) - BpodSystem.ProtocolStartTime);
            set(BpodSystem.GUIHandles.TimeDisplay, 'String', obj.Secs2HMS(TimeElapsed));
            set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton);
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
            obj.LiveEventTimestamps = zeros(1,obj.MaxEvents);
            obj.CurrentEvent = zeros(1,10);
            obj.StateChangeIndexes = zeros(1,obj.MaxEvents);
            obj.States(obj.nStates) = 1;
            obj.StateNames = BpodSystem.StateMatrix.StateNames;
            obj.nTotalStates = BpodSystem.StateMatrix.nStatesInManifest;
            start(obj.Timer);
            if obj.LastTrialEndTime > 0
                LastTrialDeadTime = obj.TrialStartTimestamp - obj.LastTrialEndTime;
                if BpodSystem.MachineType > 2
                    Threshold = 0.00051;
                    Micros = num2str(500);
                else
                    Threshold = 0.00075;
                    Micros = num2str(750);
                end
                if LastTrialDeadTime > Threshold
                    disp(' ');
                    disp('*********************************************************************');
                    disp('*                            WARNING                                *');
                    disp('*********************************************************************');
                    disp(['TrialManager reported an inter-trial dead time of >' Micros ' microseconds.']);
                    disp('This may indicate that inter-trial code (e.g. plotting, saving data)');
                    disp('took MATLAB more than 1 trial duration to execute. MATLAB must reach');
                    disp('TrialManager.getTrialData() before trial end. Please check lines of');
                    disp('your protocol main loop (e.g. with tic/toc) and optimize accordingly.');
                    disp('*********************************************************************');
                end
            end
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
                TrialEndTimestamps = BpodSystem.SerialPort.read(12, 'uint8');
                nHWTimerCycles = double(typecast(TrialEndTimestamps(1:4), 'uint32'));
                TrialEndTimestamp = double(typecast(TrialEndTimestamps(5:12), 'uint64'))/1000000;
                % Accept Timestamps
                if BpodSystem.EmulatorMode == 0
                    if BpodSystem.LiveTimestamps == 0
                        nTimeStamps = double(BpodSystem.SerialPort.read(1, 'uint16'));
                        TimeStamps = double(BpodSystem.SerialPort.read(nTimeStamps, 'uint32'));
                        TimeStamps = TimeStamps*(BpodSystem.HW.CyclePeriod/1000);
                    else
                        TimeStamps = obj.LiveEventTimestamps(1:obj.nEvents);
                    end
                else
                    obj.TrialStartTimestamp = BpodSystem.Emulator.MatrixStartTime-(BpodSystem.Status.BpodStartTime*100000);
                    TimeStamps = (BpodSystem.Emulator.Timestamps(1:BpodSystem.Emulator.nEvents)*1000);
                end
                ThisTrialErrorCodes = [];
                TrialTimeFromMicros = (TrialEndTimestamp - obj.TrialStartTimestamp);
                TrialTimeFromCycles = (nHWTimerCycles/BpodSystem.HW.CycleFrequency);
                Discrepancy = abs(TrialTimeFromMicros - TrialTimeFromCycles)*1000;
                if Discrepancy > 1
                    disp([char(10) '***WARNING!***' char(10) 'Bpod missed hardware update deadline(s) on the past trial, by ~' num2str(Discrepancy)...
                        'ms!' char(10) 'An error code (1) has been added to your trial data.' char(10) '**************'])
                    ThisTrialErrorCodes(1) = 1;
                end
                obj.StateChangeIndexes = obj.StateChangeIndexes(1:obj.nStates-1);
                EventTimeStamps = TimeStamps;
                StateTimeStamps = zeros(1,obj.nStates);
                StateTimeStamps(2:obj.nStates) = TimeStamps(obj.StateChangeIndexes); % Figure out StateChangeIndexes has a "change" event for sma start (longer than nEvents)
                StateTimeStamps(1) = 0;
                RawTrialEvents.States = obj.States;
                RawTrialEvents.Events = obj.Events;
                RawTrialEvents.StateTimestamps = obj.Round2Cycles(StateTimeStamps)/1000; % Convert to seconds
                RawTrialEvents.EventTimestamps = obj.Round2Cycles(EventTimeStamps)/1000;
                RawTrialEvents.TrialStartTimestamp = obj.Round2Cycles(obj.TrialStartTimestamp);
                RawTrialEvents.TrialEndTimestamp = obj.Round2Cycles(TrialEndTimestamp);
                RawTrialEvents.StateTimestamps(end+1) = RawTrialEvents.EventTimestamps(end);
                RawTrialEvents.ErrorCodes = ThisTrialErrorCodes;
                obj.LastTrialEndTime = RawTrialEvents.TrialEndTimestamp;
            else
                stop(obj.Timer);
                delete(obj.Timer);
                obj.Timer = [];
            end
            obj.SetBpodHardwareMirror2CurrentState(0);
            BpodSystem.LastStateMatrix = BpodSystem.StateMatrix;
            BpodSystem.Status.InStateMatrix = 0;
        end
        function CurrentEvents = getCurrentEvents(obj, triggerStates)
            global BpodSystem
            if ~isempty(triggerStates)
                if ischar(triggerStates)
                    triggerStates = {triggerStates};
                elseif ~iscell(triggerStates)
                    error('Error running BpodTrialManager.getCurrentEvents() - triggerStates argument must be a cell array of strings')
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
                        if BpodSystem.LiveTimestamps == 1
                            CurrentEvents.RawData.EventTimestamps = obj.LiveEventTimestamps(1:obj.nEvents);
                        end
                        CurrentEvents.StatesVisited = BpodSystem.StateMatrix.StateNames(CurrentEvents.RawData.StatesVisited);
                        CurrentEvents.EventsCaptured = BpodSystem.StateMachineInfo.EventNames(CurrentEvents.RawData.EventsCaptured);
                    else
                        stop(obj.Timer);
                        delete(obj.Timer);
                        obj.Timer = [];
                    end
                else
                    error('Error running BpodTrialManager.getCurrentEvents() - triggerStates argument contains at least 1 invalid state name.')
                end
            else
                error('Error running BpodTrialManager.getCurrentEvents() - triggerStates argument must be a cell array of strings')
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
            if obj.usingBonsai
                if BpodSystem.BonsaiSocket.bytesAvailable() > 15
                    OscMsg = BpodSystem.BonsaiSocket.read(16, 'uint8');
                    BonsaiByte = OscMsg(end);
                    if BpodSystem.EmulatorMode == 0
                        SendBpodSoftCode(BonsaiByte);
                    else
                        BpodSystem.VirtualManualOverrideBytes = ['~' BonsaiByte];
                        BpodSystem.ManualOverrideFlag = 1;
                    end
                end
            end
            if BpodSystem.EmulatorMode == 0
                NewMessage = 0; nBytesRead = 0;
                MaxBytesToRead = BpodSystem.SerialPort.bytesAvailable;
                if MaxBytesToRead > 0
                    NewMessage = 1;
                end
            else
                if BpodSystem.ManualOverrideFlag == 1
                    ManualOverrideEvent = VirtualManualOverride(BpodSystem.VirtualManualOverrideBytes);
                    BpodSystem.ManualOverrideFlag = 0;
                else
                    ManualOverrideEvent = [];
                end
                MaxBytesToRead = 3;
                [NewMessage, opCodeBytes, VirtualCurrentEvents] = RunBpodEmulator('loop', ManualOverrideEvent);
            end
            if NewMessage
                while (MaxBytesToRead - nBytesRead > 1) && obj.TrialEndFlag == 0
                    if BpodSystem.EmulatorMode == 0
                        opCodeBytes = BpodSystem.SerialPort.read(2, 'uint8');
                        nBytesRead = nBytesRead + 2;
                    end
                    opCode = opCodeBytes(1);
                    switch opCode
                        case 1 % Receive and handle events
                            nCurrentEvents = double(opCodeBytes(2));
                            if BpodSystem.EmulatorMode == 0
                                if BpodSystem.LiveTimestamps == 1
                                    TempCurrentEvents = BpodSystem.SerialPort.read(nCurrentEvents+4, 'uint8');
                                    nBytesRead = nBytesRead + nCurrentEvents + 4;
                                    ThisTimestamp = double(typecast(TempCurrentEvents(end-3:end), 'uint32'))*obj.TimeScaleFactor;
                                    TempCurrentEvents = TempCurrentEvents(1:end-4);
                                else
                                    TempCurrentEvents = BpodSystem.SerialPort.read(nCurrentEvents, 'uint8');
                                end
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
                            if TransitionEventFound
                                if BpodSystem.StateMatrix.meta.use255BackSignal == 1
                                    if NewState == 256
                                        NewState = BpodSystem.Status.LastStateCode;
                                    end
                                end
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
                                BpodSystem.Status.LastEvent = obj.CurrentEvent(1);
                                if MaxBytesToRead < 250 % Disable time-costly console GUI updates if data is backed up
                                    BpodSystem.RefreshGUI;
                                end
                                obj.Events(obj.nEvents+1:(obj.nEvents+nCurrentEvents)) = obj.CurrentEvent(1:nCurrentEvents);
                                if BpodSystem.LiveTimestamps == 1
                                    obj.LiveEventTimestamps(obj.nEvents+1:(obj.nEvents+nCurrentEvents)) = ThisTimestamp;
                                end
                                obj.CurrentEvent(1:nCurrentEvents) = 0;
                                %set(BpodSystem.GUIHandles.LastEventDisplay, 'string', obj.EventNames{BpodSystem.Status.LastEvent});
                                obj.nEvents = obj.nEvents + uint32(nCurrentEvents);
                            end
                        case 2 % Soft-code
                            SoftCode = opCodeBytes(2);
                            obj.HandleSoftCode(SoftCode);
                        otherwise
                            disp('Error: Invalid op code received')
                    end
                    if BpodSystem.EmulatorMode == 1
                        nBytesRead = MaxBytesToRead;
                    end
                end
            end
        end
        function TimeString = Secs2HMS(a, Seconds)
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
        function HandleSoftCode(a,SoftCode)
            global BpodSystem
            eval([BpodSystem.SoftCodeHandlerFunction '(' num2str(SoftCode) ')'])
        end
        function ManualOverrideEvent = VirtualManualOverride(a,OverrideMessage)
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
            elseif OpCode == '~'
                Code = OverrideMessage(2);
                if Code <= BpodSystem.HW.n.SoftCodes && Code ~= 0
                    ManualOverrideEvent = BpodSystem.HW.Pos.Event_USB-1 + Code;
                else
                    error(['Error: cannot send soft code ' num2str(Code) '; Soft codes must be in range: [1 ' num2str(BpodSystem.HW.n.SoftCodes) '].'])
                end
            else
                ManualOverrideEvent = [];
            end
        end
        function SetBpodHardwareMirror2ReflectEvent(a,Events)
            global BpodSystem
            nEvents = sum(Events ~= 0);
            for i = 1:nEvents
                thisEvent = Events(i);
                if thisEvent ~= 255
                    switch BpodSystem.HW.EventTypes(thisEvent)
                        case 'I'
                            p = ((thisEvent-BpodSystem.HW.IOEventStartposition)/2)+BpodSystem.HW.n.SerialChannels+BpodSystem.HW.n.FlexIO+1;
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
        function SetBpodHardwareMirror2CurrentState(a,CurrentState)
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
        function MilliOutput = Round2Cycles(a,DecimalInput)
            MilliOutput = round(DecimalInput*(10000))/(10000);
        end
    end
end
