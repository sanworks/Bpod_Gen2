%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2021 Sanworks LLC, Rochester, New York, USA

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
function RawTrialEvents = RunStateMachine
global BpodSystem
TimeScaleFactor = (BpodSystem.HW.CyclePeriod/1000);
if isempty(BpodSystem.StateMatrixSent)
    error('Error: A state matrix must be sent prior to calling "RunStateMatrix".')
end
usingBonsai = 0;
if ~isempty(BpodSystem.BonsaiSocket)
    usingBonsai = 1;
    BonsaiBytesAvailable = BpodSystem.BonsaiSocket.bytesAvailable;
    if BonsaiBytesAvailable > 0
        BpodSystem.BonsaiSocket.read(BonsaiBytesAvailable, 'uint8');
    end
end
if sum(BpodSystem.Modules.RelayActive) > 0
    BpodSystem.StopModuleRelay();
end
RawTrialEvents = struct;
if BpodSystem.EmulatorMode == 0
    if BpodSystem.Status.SessionStartFlag == 1 % On first run of session
        BpodSystem.Status.SessionStartFlag = 0;
        if BpodSystem.MachineType == 4
            BpodSystem.AnalogSerialPort.flush;
            start(BpodSystem.Timers.AnalogTimer);
        end
    end
    BpodSystem.SerialPort.flush;
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
    TrialStartTimestamp = double(typecast(TrialStartTimestampBytes, 'uint64'))/1000000; % Start-time of the trial in microseconds (compensated for 32-bit clock rollover)
end
BpodSystem.StateMatrix = BpodSystem.StateMatrixSent;
EventNames = BpodSystem.StateMachineInfo.EventNames;
MaxEvents = 100000;
nEvents = 0; nStates = 1;
Events = zeros(1,MaxEvents); States = zeros(1,MaxEvents);
LiveEventTimestamps = zeros(1,MaxEvents);
CurrentEvent = zeros(1,10);
StateChangeIndexes = zeros(1,MaxEvents);
States(nStates) = 1;
StateNames = BpodSystem.StateMatrix.StateNames;
BpodSystem.Status.LastStateCode = 0;
BpodSystem.Status.CurrentStateCode = 1;
BpodSystem.Status.LastStateName = '---';
BpodSystem.Status.CurrentStateName = StateNames{1};
BpodSystem.HardwareState.OutputOverride(1:end) = 0;
InputMatrix = BpodSystem.StateMatrix.InputMatrix;
GlobalTimerStartMatrix = BpodSystem.StateMatrix.GlobalTimerStartMatrix;
GlobalTimerEndMatrix = BpodSystem.StateMatrix.GlobalTimerEndMatrix;
GlobalCounterMatrix = BpodSystem.StateMatrix.GlobalCounterMatrix;
ConditionMatrix = BpodSystem.StateMatrix.ConditionMatrix;
StateTimerMatrix = BpodSystem.StateMatrix.StateTimerMatrix;
GlobalTimerStartOffset = BpodSystem.StateMatrix.meta.InputMatrixSize+1;
GlobalTimerEndOffset = GlobalTimerStartOffset+BpodSystem.HW.n.GlobalTimers;
GlobalCounterOffset = GlobalTimerEndOffset+BpodSystem.HW.n.GlobalTimers;
ConditionOffset = GlobalCounterOffset+BpodSystem.HW.n.GlobalCounters;
JumpOffset = ConditionOffset+BpodSystem.HW.n.Conditions;

nTotalStates = BpodSystem.StateMatrix.nStatesInManifest;
% Update time display
TimeElapsed = ceil((now*100000) - BpodSystem.ProtocolStartTime);
set(BpodSystem.GUIHandles.TimeDisplay, 'String', Secs2HMS(TimeElapsed));
set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton);

BpodSystem.Status.BeingUsed = 1; BpodSystem.Status.InStateMatrix = 1;
if BpodSystem.EmulatorMode == 1
    RunBpodEmulator('init', []);
    BpodSystem.ManualOverrideFlag = 0;
end
SetBpodHardwareMirror2CurrentState(1);
BpodSystem.RefreshGUI;
BpodSystem.Status.InStateMatrix = 1;
while BpodSystem.Status.InStateMatrix
    if usingBonsai
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
        SerialPortBytesAvailable = BpodSystem.SerialPort.bytesAvailable;
        if SerialPortBytesAvailable > 0
            NewMessage = 1;
            opCodeBytes = BpodSystem.SerialPort.read(2, 'uint8');
        else
            NewMessage = 0;
        end
    else
        SerialPortBytesAvailable = 0;
        if BpodSystem.ManualOverrideFlag == 1
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
                    if BpodSystem.LiveTimestamps == 1
                        TempCurrentEvents = BpodSystem.SerialPort.read(nCurrentEvents+4, 'uint8');
                        ThisTimestamp = double(typecast(TempCurrentEvents(end-3:end), 'uint32'))*TimeScaleFactor;
                        TempCurrentEvents = TempCurrentEvents(1:end-4);
                    else
                        TempCurrentEvents = BpodSystem.SerialPort.read(nCurrentEvents, 'uint8');
                    end
                else
                    TempCurrentEvents = VirtualCurrentEvents;
                end
                CurrentEvent(1:nCurrentEvents) = TempCurrentEvents(1:nCurrentEvents) + 1; % Read and convert from c++ index at 0 to MATLAB index at 1
                TransitionEventFound = 0; i = 1;
                NewState = BpodSystem.Status.CurrentStateCode;
                while (TransitionEventFound == 0) && (i <= nCurrentEvents)
                    if CurrentEvent(i) == 255
                        BpodSystem.Status.InStateMatrix = 0;
                        break
                    elseif CurrentEvent(i) < GlobalTimerStartOffset
                        NewState = InputMatrix(BpodSystem.Status.CurrentStateCode, CurrentEvent(i));
                    elseif CurrentEvent(i) < GlobalTimerEndOffset
                        NewState = GlobalTimerStartMatrix(BpodSystem.Status.CurrentStateCode, CurrentEvent(i)-(GlobalTimerStartOffset-1));
                    elseif CurrentEvent(i) < GlobalCounterOffset
                        NewState = GlobalTimerEndMatrix(BpodSystem.Status.CurrentStateCode, CurrentEvent(i)-(GlobalTimerEndOffset-1));
                    elseif CurrentEvent(i) < ConditionOffset
                        NewState = GlobalCounterMatrix(BpodSystem.Status.CurrentStateCode, CurrentEvent(i)-(GlobalCounterOffset-1));
                    elseif CurrentEvent(i) < JumpOffset
                        NewState = ConditionMatrix(BpodSystem.Status.CurrentStateCode, CurrentEvent(i)-(ConditionOffset-1));
                    elseif CurrentEvent(i) == BpodSystem.HW.StateTimerPosition
                        NewState = StateTimerMatrix(BpodSystem.Status.CurrentStateCode);
                    else
                        error(['Error: Unknown event code returned: ' num2str(CurrentEvent(i))]);
                    end
                    if NewState ~= BpodSystem.Status.CurrentStateCode
                        TransitionEventFound = 1;
                    end
                    i = i + 1;
                end
                SetBpodHardwareMirror2ReflectEvent(CurrentEvent);
                if TransitionEventFound
                    if BpodSystem.StateMatrix.meta.use255BackSignal == 1
                        if NewState == 256
                            NewState = BpodSystem.Status.LastStateCode;
                        end
                    end
                    if  NewState <= nTotalStates
                        StateChangeIndexes(nStates) = nEvents+1;
                        nStates = nStates + 1;
                        States(nStates) = NewState;
                        BpodSystem.Status.LastStateCode = BpodSystem.Status.CurrentStateCode;
                        BpodSystem.Status.CurrentStateCode = NewState;
                        BpodSystem.Status.CurrentStateName = StateNames{NewState};
                        BpodSystem.Status.LastStateName = StateNames{BpodSystem.Status.LastStateCode};
                        SetBpodHardwareMirror2CurrentState(NewState);
                        if BpodSystem.EmulatorMode == 1
                            BpodSystem.Emulator.CurrentState = NewState;
                            BpodSystem.Emulator.StateStartTime = BpodSystem.Emulator.CurrentTime;
                            % Set global timer end-time
                            GlobalTimerTrigByte = BpodSystem.StateMatrix.OutputMatrix(NewState,BpodSystem.HW.Pos.GlobalTimerTrig);
                            if GlobalTimerTrigByte ~= 0
                                timersToTrigger = dec2bin(GlobalTimerTrigByte) == '1';
                                AllGlobalTimers = find(timersToTrigger(end:-1:1));
                                for z = 1:length(AllGlobalTimers)
                                    ThisGlobalTimer = AllGlobalTimers(z);
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
                            end
                            % Cancel global timers
                            GlobalTimerCancelByte = BpodSystem.StateMatrix.OutputMatrix(NewState,BpodSystem.HW.Pos.GlobalTimerCancel);
                            if GlobalTimerCancelByte ~= 0
                                timersToCancel = dec2bin(GlobalTimerCancelByte) == '1';
                                AllGlobalTimers = find(timersToCancel(end:-1:1));
                                for z = 1:length(AllGlobalTimers)
                                    ThisGlobalTimer = AllGlobalTimers(z);
                                    BpodSystem.Emulator.GlobalTimersActive(ThisGlobalTimer) = 0;
                                end
                            end
                            % Reset global counter counts
                            ThisGlobalCounter = BpodSystem.StateMatrix.OutputMatrix(NewState,BpodSystem.HW.Pos.GlobalCounterReset);
                            if ThisGlobalCounter ~= 0
                                BpodSystem.Emulator.GlobalCounterCounts(ThisGlobalCounter) = 0;
                                BpodSystem.Emulator.GlobalCounterHandled(ThisGlobalCounter) = 0;
                            end
                            % Update soft code
                            BpodSystem.Emulator.SoftCode = BpodSystem.StateMatrix.OutputMatrix(NewState,BpodSystem.HW.Pos.Output_USB);
                        end
                    else
                        if BpodSystem.EmulatorMode == 1
                            StateChangeIndexes(nStates) = nEvents+1;
                            Events(nEvents+1:(nEvents+nCurrentEvents)) = CurrentEvent(1:nCurrentEvents);
                            nEvents = nEvents + nCurrentEvents;
                            break
                        end
                    end
                end
                if BpodSystem.Status.InStateMatrix == 1
                    Events(nEvents+1:(nEvents+nCurrentEvents)) = CurrentEvent(1:nCurrentEvents);
                    if BpodSystem.LiveTimestamps == 1
                        LiveEventTimestamps(nEvents+1:(nEvents+nCurrentEvents)) = ThisTimestamp;
                    end
                    BpodSystem.Status.LastEvent = CurrentEvent(1);
                    if SerialPortBytesAvailable < 250
                        BpodSystem.RefreshGUI;
                    end
                    CurrentEvent(1:nCurrentEvents) = 0;
                    nEvents = nEvents + uint32(nCurrentEvents);
                end
            case 2 % Soft-code
                SoftCode = opCodeBytes(2);
                HandleSoftCode(SoftCode);
            otherwise
                disp('Error: Invalid op code received')
        end
    else
        drawnow;
    end
end

if BpodSystem.Status.BeingUsed == 1
    ThisTrialErrorCodes = [];
    Events = Events(1:nEvents);
    States = States(1:nStates);
    if BpodSystem.EmulatorMode == 0
        TrialEndTimestamps = BpodSystem.SerialPort.read(12, 'uint8');
        nHWTimerCycles = double(typecast(TrialEndTimestamps(1:4), 'uint32'));
        TrialEndTimestamp = double(typecast(TrialEndTimestamps(5:12), 'uint64'))/1000000;
        TrialTimeFromMicros = (TrialEndTimestamp - TrialStartTimestamp);
        TrialTimeFromCycles = (nHWTimerCycles/BpodSystem.HW.CycleFrequency); % Add 1ms to adjust for bias due to placement of millis() in start+end code
        Discrepancy = abs(TrialTimeFromMicros - TrialTimeFromCycles)*1000;
        if Discrepancy > 1
            disp([char(10) '***WARNING!***' char(10) 'Bpod missed hardware update deadline(s) on the past trial, by ~' num2str(Discrepancy)...
                'ms!' char(10) 'An error code (1) has been added to your trial data.' char(10) '**************'])
            ThisTrialErrorCodes(1) = 1;
        end
    end
    if BpodSystem.LiveTimestamps == 1
        TimeStamps = LiveEventTimestamps(1:nEvents);
    end
    % Accept Timestamps
    if BpodSystem.EmulatorMode == 0
        if BpodSystem.LiveTimestamps == 0
            nTimeStamps = double(BpodSystem.SerialPort.read(1, 'uint16'));
            TimeStamps = double(BpodSystem.SerialPort.read(nTimeStamps, 'uint32'))*TimeScaleFactor;
        end
    else
        TrialStartTimestamp = BpodSystem.Emulator.MatrixStartTime-(BpodSystem.Status.BpodStartTime*100000);
        TimeStamps = (BpodSystem.Emulator.Timestamps(1:BpodSystem.Emulator.nEvents)*1000);
        TrialEndTimestamp = TrialStartTimestamp + TimeStamps(end);
    end
    StateChangeIndexes = StateChangeIndexes(1:nStates-1);
    EventTimeStamps = TimeStamps;
    StateTimeStamps = zeros(1,nStates);
    StateTimeStamps(2:nStates) = TimeStamps(StateChangeIndexes); % Figure out StateChangeIndexes has a "change" event for sma start (longer than nEvents)
    StateTimeStamps(1) = 0;
    RawTrialEvents.States = States;
    RawTrialEvents.Events = Events;
    RawTrialEvents.StateTimestamps = Round2Cycles(StateTimeStamps)/1000; % Convert to seconds
    RawTrialEvents.EventTimestamps = Round2Cycles(EventTimeStamps)/1000;
    RawTrialEvents.TrialStartTimestamp = Round2Cycles(TrialStartTimestamp);
    RawTrialEvents.TrialEndTimestamp = Round2Cycles(TrialEndTimestamp);
    RawTrialEvents.StateTimestamps(end+1) = RawTrialEvents.EventTimestamps(end);
    RawTrialEvents.ErrorCodes = ThisTrialErrorCodes;
end
SetBpodHardwareMirror2CurrentState(0);
BpodSystem.LastStateMatrix = BpodSystem.StateMatrix;
BpodSystem.Status.InStateMatrix = 0;

function MilliOutput = Round2Cycles(DecimalInput)
MilliOutput = round(DecimalInput*(10000))/(10000);

function SetBpodHardwareMirror2CurrentState(CurrentState)
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

function SetBpodHardwareMirror2ReflectEvent(Events)
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

function TimeString = Secs2HMS(Seconds)
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

function HandleSoftCode(SoftCode)
global BpodSystem
eval([BpodSystem.SoftCodeHandlerFunction '(' num2str(SoftCode) ')'])

function ManualOverrideEvent = VirtualManualOverride(OverrideMessage)
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