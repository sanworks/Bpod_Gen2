%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) Sanworks LLC, Rochester, New York, USA

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

% RunStateMachine() initiates and monitors the execution of a single experimental trial's 
% state machine, previously loaded to the state machine with SendStateMachine(). 
% The function blocks the MATLAB interpreter while the trial is running. 
% 
% Arguments: None
% Returns: rawTrialEvents, a struct containing the states visited, events captured and timestamps.
%
% The format of rawTrialEvents is:
% rawTrialEvents.States - A list of states in the order visited. Units = state index.
% rawTrialEvents.Events - A list of the events captured. Units = event index.
% rawTrialEvents.StateTimestamps - Timestamps for each state visited. Units = seconds after trial start.
% rawTrialEvents.EventTimestamps - Timestamps for each event captured. Units = seconds after trial start.
% rawTrialEvents.TrialStartTimestamp - Time from the Bpod State Machine clock on entering the first state.
% rawTrialEvents.TrialEndTimestamp - Time from the Bpod State Machine clock on exiting the final state.
% rawTrialEvents.ErrorCodes - A list of error codes thrown by the system while executing the trial
% NOTE: A legend of state and event indexes is given on the system info panel of the Bpod Console GUI
%
% Example usage: rawTrialEvents = RunStateMachine;

function rawTrialEvents = RunStateMachine

global BpodSystem % Import the global BpodSystem object

% Setup
timeScaleFactor = (BpodSystem.HW.CyclePeriod/1000); % To convert state machine cycles to seconds
rawTrialEvents = struct; % Struct for returned trial data

% Ensure that a state machine description has been sent to the device
if isempty(BpodSystem.StateMatrixSent)
    error('Error: A state matrix must be sent prior to calling "RunStateMatrix".')
end

% If interfacing with Bonsai via TCP/IP (legacy method) initialize the channel
usingBonsai = 0;
if ~isempty(BpodSystem.BonsaiSocket)
    usingBonsai = 1;
    bonsaiBytesAvailable = BpodSystem.BonsaiSocket.bytesAvailable;
    if bonsaiBytesAvailable > 0 % Clear any remaining bytes from previous sessions
        BpodSystem.BonsaiSocket.read(bonsaiBytesAvailable, 'uint8');
    end
end

% Stop any active module relays
if sum(BpodSystem.Modules.RelayActive) > 0
    BpodSystem.StopModuleRelay();
end

% Prepare trial management variables
BpodSystem.StateMatrix = BpodSystem.StateMatrixSent; % Current state machine
maxEvents = 1000000; % Preallocate anticipating up to 1M events in a single trial.
nEvents = 0; nStates = 1; % Event and state counters
events = zeros(1,maxEvents); states = zeros(1,maxEvents);
liveEventTimestamps = zeros(1,maxEvents); % Timestamps for each event in Events
currentEvent = zeros(1,100); % A machine refresh can capture up to 100 events
stateChangeIndexes = zeros(1,maxEvents); % Indexes of event timestamps that triggered state changes
states(nStates) = 1; % Each trial begins with state 1, the first added with AddState()
stateNames = BpodSystem.StateMatrix.StateNames; % Local copy of StateNames
nTotalStates = BpodSystem.StateMatrix.nStatesInManifest; % Local copy of nStates

% Reset status fields (to be synced with console UI)
BpodSystem.Status.LastStateCode = 0; % Last state (index)
BpodSystem.Status.CurrentStateCode = 1; % Current state (index)
BpodSystem.Status.LastStateName = '---'; % Last state (name)
BpodSystem.Status.CurrentStateName = stateNames{1}; % Current state (name)
BpodSystem.HardwareState.OutputOverride(1:end) = 0; % Reset manual overrides

% Create local vars for current trial's state machine description
inputMatrix = BpodSystem.StateMatrix.InputMatrix;
globalTimerStartMatrix = BpodSystem.StateMatrix.GlobalTimerStartMatrix;
globalTimerEndMatrix = BpodSystem.StateMatrix.GlobalTimerEndMatrix;
globalCounterMatrix = BpodSystem.StateMatrix.GlobalCounterMatrix;
conditionMatrix = BpodSystem.StateMatrix.ConditionMatrix;
stateTimerMatrix = BpodSystem.StateMatrix.StateTimerMatrix;
globalTimerStartOffset = BpodSystem.StateMatrix.meta.InputMatrixSize+1;
globalTimerEndOffset = globalTimerStartOffset+BpodSystem.HW.n.GlobalTimers;
globalCounterOffset = globalTimerEndOffset+BpodSystem.HW.n.GlobalTimers;
conditionOffset = globalCounterOffset+BpodSystem.HW.n.GlobalCounters;
stateTimerOffset = conditionOffset+BpodSystem.HW.n.Conditions;

% Update console GUI time display
timeElapsed = ceil((now*100000) - BpodSystem.ProtocolStartTime);
set(BpodSystem.GUIHandles.TimeDisplay, 'String', secs2hms(timeElapsed));
set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton);

% Start trial
BpodSystem.Status.BeingUsed = 1; BpodSystem.Status.InStateMatrix = 1;
if BpodSystem.Status.SessionStartFlag == 1 % On first run of session
    BpodSystem.Status.SessionStartFlag = 0;
    if BpodSystem.MachineType == 4
        BpodSystem.AnalogSerialPort.flush;
        start(BpodSystem.Timers.AnalogTimer);
    end
end
if BpodSystem.EmulatorMode == 0
    trialStartTimestamp = send_trial_start_command;
else
    RunBpodEmulator('init', []);
    BpodSystem.ManualOverrideFlag = 0;
end
update_hardwarestate_new_state(1);
BpodSystem.RefreshGUI;

% Main loop that runs during trial execution. Events arriving at the USB
% serial port are logged, and displayed on the console GUI. The current
% state is inferred from the sequence of events. Soft codes are
% passed to the current soft code handler function.
while BpodSystem.Status.InStateMatrix
    % Check for events on legacy Bonsai TCP/IP inferface if initialized.
    if usingBonsai
        if BpodSystem.BonsaiSocket.bytesAvailable() > 15 % If a full OSC packet is ready
            oscMsg = BpodSystem.BonsaiSocket.read(16, 'uint8'); % Read the packet
            bonsaiByte = oscMsg(end); % Read the data byte
            if BpodSystem.EmulatorMode == 0
                SendBpodSoftCode(bonsaiByte); % Pass the data byte to the state machine
            else
                BpodSystem.VirtualManualOverrideBytes = ['~' bonsaiByte];
                BpodSystem.ManualOverrideFlag = 1;
            end
        end
    end

    % Check for new messages from the Bpod State Machine
    if BpodSystem.EmulatorMode == 0
        serialPortBytesAvailable = BpodSystem.SerialPort.bytesAvailable;
        if serialPortBytesAvailable > 0
            newMessage = 1;
            opCodeBytes = BpodSystem.SerialPort.read(2, 'uint8');
        else
            newMessage = 0;
        end
    else
        serialPortBytesAvailable = 0;
        if BpodSystem.ManualOverrideFlag == 1
            manualOverrideEvent = virtual_manual_override(BpodSystem.VirtualManualOverrideBytes);
            BpodSystem.ManualOverrideFlag = 0;
        else
            manualOverrideEvent = [];
        end
        [newMessage, opCodeBytes, VirtualCurrentEvents] = RunBpodEmulator('loop', manualOverrideEvent);
    end

    if newMessage % If there are new events or soft codes to read
        opCode = opCodeBytes(1);
        switch opCode
            case 1 % Receive and handle events
                nCurrentEvents = double(opCodeBytes(2));
                if BpodSystem.EmulatorMode == 0
                    if BpodSystem.LiveTimestamps == 1
                        tempCurrentEvents = BpodSystem.SerialPort.read(nCurrentEvents+4, 'uint8');
                        thisTimestamp = double(typecast(tempCurrentEvents(end-3:end), 'uint32'))*timeScaleFactor;
                        tempCurrentEvents = tempCurrentEvents(1:end-4);
                    else
                        tempCurrentEvents = BpodSystem.SerialPort.read(nCurrentEvents, 'uint8');
                    end
                else
                    tempCurrentEvents = VirtualCurrentEvents;
                end
                % Read and convert from c++ index at 0 to MATLAB index at 1
                currentEvent(1:nCurrentEvents) = tempCurrentEvents(1:nCurrentEvents) + 1; 
                transitionEventFound = 0; iEvent = 1;
                newState = BpodSystem.Status.CurrentStateCode;
                while (transitionEventFound == 0) && (iEvent <= nCurrentEvents)
                    if currentEvent(iEvent) == 255
                        BpodSystem.Status.InStateMatrix = 0;
                        break
                    elseif currentEvent(iEvent) < globalTimerStartOffset
                        newState = inputMatrix(BpodSystem.Status.CurrentStateCode, currentEvent(iEvent));
                    elseif currentEvent(iEvent) < globalTimerEndOffset
                        newState = globalTimerStartMatrix(BpodSystem.Status.CurrentStateCode,... 
                            currentEvent(iEvent)-(globalTimerStartOffset-1));
                    elseif currentEvent(iEvent) < globalCounterOffset
                        newState = globalTimerEndMatrix(BpodSystem.Status.CurrentStateCode,... 
                            currentEvent(iEvent)-(globalTimerEndOffset-1));
                    elseif currentEvent(iEvent) < conditionOffset
                        newState = globalCounterMatrix(BpodSystem.Status.CurrentStateCode,... 
                            currentEvent(iEvent)-(globalCounterOffset-1));
                    elseif currentEvent(iEvent) < stateTimerOffset
                        newState = conditionMatrix(BpodSystem.Status.CurrentStateCode,... 
                            currentEvent(iEvent)-(conditionOffset-1));
                    elseif currentEvent(iEvent) == BpodSystem.HW.StateTimerPosition
                        newState = stateTimerMatrix(BpodSystem.Status.CurrentStateCode);
                    else
                        error(['Unknown event code returned: ' num2str(currentEvent(iEvent))]);
                    end
                    if newState ~= BpodSystem.Status.CurrentStateCode
                        transitionEventFound = 1;
                    end
                    iEvent = iEvent + 1;
                end
                update_hardwarestate_new_event(currentEvent);
                if transitionEventFound
                    if BpodSystem.StateMatrix.meta.use255BackSignal == 1
                        if newState == 256
                            newState = BpodSystem.Status.LastStateCode;
                        end
                    end
                    if  newState <= nTotalStates
                        stateChangeIndexes(nStates) = nEvents+1;
                        nStates = nStates + 1;
                        states(nStates) = newState;
                        BpodSystem.Status.LastStateCode = BpodSystem.Status.CurrentStateCode;
                        BpodSystem.Status.CurrentStateCode = newState;
                        BpodSystem.Status.CurrentStateName = stateNames{newState};
                        BpodSystem.Status.LastStateName = stateNames{BpodSystem.Status.LastStateCode};
                        update_hardwarestate_new_state(newState);
                        if BpodSystem.EmulatorMode == 1
                            BpodSystem.Emulator.CurrentState = newState;
                            BpodSystem.Emulator.StateStartTime = BpodSystem.Emulator.CurrentTime;
                            % Set global timer end-time
                            globalTimerTrigByte = BpodSystem.StateMatrix.OutputMatrix(newState,BpodSystem.HW.Pos.GlobalTimerTrig);
                            if globalTimerTrigByte ~= 0
                                timersToTrigger = dec2bin(globalTimerTrigByte) == '1';
                                allGlobalTimers = find(timersToTrigger(end:-1:1));
                                for z = 1:length(allGlobalTimers)
                                    thisGlobalTimer = allGlobalTimers(z);
                                    if BpodSystem.StateMatrix.GlobalTimers.OnsetDelay(thisGlobalTimer) == 0
                                        BpodSystem.Emulator.GlobalTimerEnd(thisGlobalTimer) = BpodSystem.Emulator.CurrentTime + ... 
                                            BpodSystem.StateMatrix.GlobalTimers.Duration(thisGlobalTimer);
                                        BpodSystem.Emulator.GlobalTimersActive(thisGlobalTimer) = 1;
                                        BpodSystem.Emulator.GlobalTimersTriggered(thisGlobalTimer) = 0;
                                    else
                                        BpodSystem.Emulator.GlobalTimerStart(thisGlobalTimer) = BpodSystem.Emulator.CurrentTime + ... 
                                            BpodSystem.StateMatrix.GlobalTimers.OnsetDelay(thisGlobalTimer);
                                        BpodSystem.Emulator.GlobalTimerEnd(thisGlobalTimer) = ... 
                                            BpodSystem.Emulator.GlobalTimerStart(thisGlobalTimer) + ... 
                                            BpodSystem.StateMatrix.GlobalTimers.Duration(thisGlobalTimer);
                                        BpodSystem.Emulator.GlobalTimersTriggered(thisGlobalTimer) = 1;
                                    end
                                end
                            end
                            % Cancel global timers
                            globalTimerCancelByte = BpodSystem.StateMatrix.OutputMatrix(newState,BpodSystem.HW.Pos.GlobalTimerCancel);
                            if globalTimerCancelByte ~= 0
                                timersToCancel = dec2bin(globalTimerCancelByte) == '1';
                                allGlobalTimers = find(timersToCancel(end:-1:1));
                                for z = 1:length(allGlobalTimers)
                                    thisGlobalTimer = allGlobalTimers(z);
                                    BpodSystem.Emulator.GlobalTimersActive(thisGlobalTimer) = 0;
                                end
                            end
                            % Reset global counter counts
                            thisGlobalCounter = BpodSystem.StateMatrix.OutputMatrix(newState,BpodSystem.HW.Pos.GlobalCounterReset);
                            if thisGlobalCounter ~= 0
                                BpodSystem.Emulator.GlobalCounterCounts(thisGlobalCounter) = 0;
                                BpodSystem.Emulator.GlobalCounterHandled(thisGlobalCounter) = 0;
                            end
                            % Update soft code
                            BpodSystem.Emulator.SoftCode = BpodSystem.StateMatrix.OutputMatrix(newState,BpodSystem.HW.Pos.Output_USB);
                        end
                    else
                        if BpodSystem.EmulatorMode == 1
                            stateChangeIndexes(nStates) = nEvents+1;
                            events(nEvents+1:(nEvents+nCurrentEvents)) = currentEvent(1:nCurrentEvents);
                            nEvents = nEvents + nCurrentEvents;
                            break
                        end
                    end
                end
                if BpodSystem.Status.InStateMatrix == 1
                    events(nEvents+1:(nEvents+nCurrentEvents)) = currentEvent(1:nCurrentEvents);
                    if BpodSystem.LiveTimestamps == 1
                        liveEventTimestamps(nEvents+1:(nEvents+nCurrentEvents)) = thisTimestamp;
                    end
                    BpodSystem.Status.LastEvent = currentEvent(1);
                    if serialPortBytesAvailable < 250
                        BpodSystem.RefreshGUI;
                    end
                    currentEvent(1:nCurrentEvents) = 0;
                    nEvents = nEvents + uint32(nCurrentEvents);
                end
            case 2 % Soft-code
                softCode = opCodeBytes(2);
                handle_soft_code(softCode);
            otherwise
                disp('Error: Invalid op code received')
        end
    else
        drawnow;
    end
end

% Execution continues here after a trial exit state was reached.
if BpodSystem.Status.BeingUsed == 1 % If exit was due to manual termination, BeingUsed is 0.
    % Partial trials are not stored, to ensure data uniformity.
    thisTrialErrorCodes = [];
    % Trim unused preallocated data
    events = events(1:nEvents);
    states = states(1:nStates);
    stateChangeIndexes = stateChangeIndexes(1:nStates-1);
    
    if BpodSystem.EmulatorMode == 0
        % Read trial-end timestamps.
        trialEndTimestamps = BpodSystem.SerialPort.read(12, 'uint8');
        nHWTimerCycles = double(typecast(trialEndTimestamps(1:4), 'uint32'));
        trialEndTimestamp = double(typecast(trialEndTimestamps(5:12), 'uint64'))/1000000;

        % Internal check for violations of timing guarantees. Trial time from roll-over compensated
        % micros() is compared with the number of hardware timer callbacks executed. These trial
        % duration metrics should match if timer callbacks did not exceed the hardware timer interval
        trialTimeFromMicros = (trialEndTimestamp - trialStartTimestamp);
        trialTimeFromCycles = (nHWTimerCycles/BpodSystem.HW.CycleFrequency);
        discrepancy = abs(trialTimeFromMicros - trialTimeFromCycles)*1000;
        if discrepancy > 1
            disp([char(10) '***WARNING!***' char(10) 'Bpod missed hardware update deadline(s) on the past trial, by ~' ... 
                num2str(discrepancy) 'ms!' char(10) 'An error code (1) has been added to your trial data.' char(10) '**************'])
            thisTrialErrorCodes(1) = 1;
        end
    end
    if BpodSystem.LiveTimestamps == 1 % FSM 0.7 and newer return event timestamps as they are captured
        timeStamps = liveEventTimestamps(1:nEvents);
    end
    % Read Timestamps
    if BpodSystem.EmulatorMode == 0
        if BpodSystem.LiveTimestamps == 0 % Due to bandwidth constraints, FSM 0.5 returns timestamps following trial-end
            nTimeStamps = double(BpodSystem.SerialPort.read(1, 'uint16'));
            timeStamps = double(BpodSystem.SerialPort.read(nTimeStamps, 'uint32'))*timeScaleFactor;
        end
    else
        trialStartTimestamp = BpodSystem.Emulator.MatrixStartTime-(BpodSystem.Status.BpodStartTime*100000);
        timeStamps = (BpodSystem.Emulator.Timestamps(1:BpodSystem.Emulator.nEvents)*1000);
        trialEndTimestamp = trialStartTimestamp + timeStamps(end);
    end

    % Determine event and state timestamps
    eventTimeStamps = timeStamps;
    stateTimeStamps = zeros(1,nStates);
    stateTimeStamps(2:nStates) = timeStamps(stateChangeIndexes);
    stateTimeStamps(1) = 0;

    % Package trial events, states and timestamps
    rawTrialEvents.States = states;
    rawTrialEvents.Events = events;
    rawTrialEvents.StateTimestamps = round2cycles(stateTimeStamps)/1000; % Convert to seconds
    rawTrialEvents.EventTimestamps = round2cycles(eventTimeStamps)/1000;
    rawTrialEvents.TrialStartTimestamp = round2cycles(trialStartTimestamp);
    rawTrialEvents.TrialEndTimestamp = round2cycles(trialEndTimestamp);
    rawTrialEvents.StateTimestamps(end+1) = rawTrialEvents.EventTimestamps(end);
    rawTrialEvents.ErrorCodes = thisTrialErrorCodes;
end

% Cleanup
update_hardwarestate_new_state(0); % Reset hardware state
BpodSystem.LastStateMatrix = BpodSystem.StateMatrix;
BpodSystem.Status.InStateMatrix = 0;
end

function timeOutput = round2cycles(decimalInput)
% Trims precision of timestamps to match state machine refresh interval
global BpodSystem
freq = BpodSystem.HW.CycleFrequency;
timeOutput = round(decimalInput*(freq))/(freq);
end

function update_hardwarestate_new_state(currentState)
% Updates BpodSystem.HardwareState to reflect entry into a new state
global BpodSystem
if currentState > 0
    newOutputState = BpodSystem.StateMatrix.OutputMatrix(currentState,:);
    outputOverride = BpodSystem.HardwareState.OutputOverride;
    BpodSystem.HardwareState.OutputState(~outputOverride) = newOutputState(~outputOverride);
else
    BpodSystem.HardwareState.InputState(1:end) = 0;
    BpodSystem.HardwareState.OutputState(1:end) = 0;
    BpodSystem.RefreshGUI;
end
end

function update_hardwarestate_new_event(Events)
% Updates BpodSystem.HardwareState to reflect new event(s).
global BpodSystem
nEvents = sum(Events ~= 0);
for i = 1:nEvents
    thisEvent = Events(i);
    if thisEvent ~= 255
        switch BpodSystem.HW.EventTypes(thisEvent)
            case 'I'
                p = ((thisEvent-BpodSystem.HW.IOEventStartposition)/2) + BpodSystem.HW.n.SerialChannels + BpodSystem.HW.n.FlexIO+1;
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
                    eventType = 1; % On
                else
                    timerNumber = timerEvent-BpodSystem.HW.n.GlobalTimers;
                    eventType = 0; % Off
                end
                if BpodSystem.StateMatrix.GlobalTimers.OutputChannel(timerNumber) < 255
                    outputChannel = BpodSystem.StateMatrix.GlobalTimers.OutputChannel(timerNumber);
                    outputChannelType = BpodSystem.HW.Outputs(outputChannel);
                    switch outputChannelType
                        case {'B', 'W', 'P'}
                            BpodSystem.HardwareState.OutputState(outputChannel) = eventType;
                            BpodSystem.HardwareState.OutputOverride(outputChannel) = eventType;
                    end
                end
        end
    end
end
end

function timeString = secs2hms(seconds)
    % Converts seconds to HH:MM:SS string format
    h = floor(seconds / 3600);
    m = floor(mod(seconds, 3600) / 60);
    s = mod(seconds, 60);
    timeString = sprintf('%02d:%02d:%02d', h, m, s);
end

function handle_soft_code(softCode)
% Calls the current soft code handler function, passing it the SoftCode
% received from the state machine
global BpodSystem
eval([BpodSystem.SoftCodeHandlerFunction '(' num2str(softCode) ')'])
end

function manualOverrideEvent = virtual_manual_override(overrideMessage)
% Converts the byte code transmission formatted for the state machine into event codes
global BpodSystem
opCode = overrideMessage(1);
if opCode == 'V'
    inputChannel = overrideMessage(2)+1;
    eventType = BpodSystem.HardwareState.InputType(inputChannel);
    if ~strcmp(eventType, {'U','X'})
        newChannelState = BpodSystem.HardwareState.InputState(inputChannel);
        manualOverrideEvent = BpodSystem.HW.Pos.Event_BNC-1 + 2*(inputChannel-BpodSystem.HW.Pos.Output_USB)-1 + (1-newChannelState);
    else
        switch eventType
            case 'U'
                manualOverrideEvent = [];
            case 'X'
                manualOverrideEvent = [];
        end
    end
elseif opCode == 'S'
    handle_soft_code(uint8(overrideMessage(2)));
    manualOverrideEvent = [];
elseif opCode == '~'
    code = overrideMessage(2);
    if code <= BpodSystem.HW.n.SoftCodes && code ~= 0
        manualOverrideEvent = BpodSystem.HW.Pos.Event_USB-1 + code;
    else
        error(['Error: cannot send soft code ' num2str(code) '; Soft codes must be in range: [1 '... 
            num2str(BpodSystem.HW.n.SoftCodes) '].'])
    end
else
    manualOverrideEvent = [];
end
end

function trialStartTimestamp = send_trial_start_command
% Sends the trial start command to the Bpod State Machine device.
% Reads an acknowledgement if a new state machine description was sent
% previously and successfully received.
% Returns: TrialStartTimestamp (units = s), trial start time measured by
% the state machine clock
global BpodSystem
BpodSystem.SerialPort.flush;
BpodSystem.SerialPort.write('R', 'uint8'); % Send the code to run the loaded matrix (character "R" for Run)
if BpodSystem.Status.NewStateMachineSent % Read confirmation byte = successful state machine transmission
    sma_Confirmed = BpodSystem.SerialPort.read(1, 'uint8');
    if isempty(sma_Confirmed)
        error('Error: The last state machine sent was not acknowledged by the Bpod device.');
    elseif sma_Confirmed ~= 1
        error('Error: The last state machine sent was not acknowledged by the Bpod device.');
    end
    BpodSystem.Status.NewStateMachineSent = 0;
end
trialStartTimestampBytes = BpodSystem.SerialPort.read(8, 'uint8');
trialStartTimestamp = double(typecast(trialStartTimestampBytes, 'uint64'))/1000000; 
end