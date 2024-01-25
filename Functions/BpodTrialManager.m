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

% BpodTrialManager() is a class that manages execution of experimental
% trials without blocking the MATLAB command interpreter.
% It has three user-facing methods (more detail in the method comments):
%
% 1. startTrial() begins monitoring events from the Bpod State Machine, and
% starts the state machine if it was not already running a trial. A MATLAB
% timer callback is started to read and parse incoming events, track the
% current state, manage USB soft codes and update the Bpod Console GUI.
%
% 2. getCurrentEvents() blocks the MATLAB interpreter until specific state(s)
% are reached. It returns a trial event structure for the trial up to that point,
% that can be used to compute the next trial's state machine description.
%
% 3. getTrialData() blocks execution until the Bpod State Machine reaches an exit
% state. It returns a complete set of events and states for the trial just
% completed, which can be added to the session dataset with AddTrialEvents().
%
% Usage example:
% B = BpodTrialManager; % Create an instance of BpodTrialManager
% B.startTrial(sma); % Send sma and start running the trial
% --- Run commands here during the trial ---
% rawEvents = B.getTrialData(); % Wait for the trial to end and return data
% clear B; % Clear the instance of BpodTrialManager
% Also see: /Bpod_Gen2/Examples/Protocols/Light/Light2AFC_TrialManager/

classdef BpodTrialManager < handle
    properties
        timer % MATLAB timer object to check for new events from the state machine
    end
    properties (Access = private)
        trialEndFlag = 0; % 1 if trial reached an exit state, 0 if not
        prepareNextTrialFlag = 0; % 1 if trial reached an exit state, 0 if not
        nextTrialTriggerStates % Indexes of states that trigger MATLAB to prepare the next trial
        inputMatrix % State to transfer to if event (col) occurs in state (row)
        globalTimerStartMatrix % State to enter if global timer (col) starts during state (row)
        globalTimerEndMatrix % State to enter if global timer (col) ends during state (row)
        globalCounterMatrix % State to enter if global counter (col) exceeds threshold during state (row)
        conditionMatrix % State to enter if condition (col) is true during state (row)
        stateTimerMatrix % For each state, the state to enter if each state timer elapses
        globalTimerStartOffset % Position of the first global-timer-start in the list of possible events
        globalTimerEndOffset % Position of the first global-timer-end in the list of possible events
        globalCounterOffset % Position of the first global counter in the list of possible events
        conditionOffset % Position of the first condition in the list of possible events
        stateTimerOffset % Position of the state timer event in the list of possible events
        eventNames % List of event names
        nEvents % Counts the number of events captured during the current trial
        trialEvents % List of events captured during the current trial
        currentEvent % List of events captured during the most recent state machine cycle
        stateChangeIndexes % List of event indexes in currentEvent that caused state changes
        nStates % Number of states visited in the current trial
        nTotalStates % Number of possible states in the current trial's state machine
        states % List of states visited in the current trial
        stateNames % List of names of each state in the current trial's state machine
        liveEventTimestamps % List of timestamps for events captured during the trial
        maxEvents = 1000000; % Maximum number of events possible in 1 trial (for preallocation)
        timeScaleFactor % Factor to convert multiples of the state machine cycle period into seconds
        trialStartTimestamp % Time the current trial started, measured from the state machine clock
        lastTrialEndTime % Time the previous trial ended, measured from the state machine clock
        usingBonsai % A flag, true if the legacy Bonsai TCP/IP port is enabled
        cycleFrequency % State machine cycle frequency
    end
    methods
        function obj = BpodTrialManager
            % BpodTrialManager() is the constructor for the BpodTrialManager class.
            %
            % Arguments: None
            %
            % Returns: None
            %
            % Usage example:
            % B = BpodTrialManager; % Create B, an instance of BpodTrialManager

            global BpodSystem % Import the global BpodSystem object

            % Ensure that the system was initialized
            if isempty(BpodSystem)
                error('You must run Bpod() before creating an instance of BpodTrialManager.')
            end

            % Ensure that the user is not using emulator mode
            if BpodSystem.EmulatorMode == 1
                error('Error: The Bpod emulator does not currently support running state machines with TrialManager.')
            end

            % Set up session variables
            obj.timeScaleFactor = (BpodSystem.HW.CyclePeriod/1000);
            obj.lastTrialEndTime = 0;
            obj.usingBonsai = 0;
            obj.cycleFrequency = BpodSystem.HW.CycleFrequency;

            % Initialize a timer object. The callback processLiveEvents() will poll the
            % USB serial port and handle incoming events during the trial.
            obj.timer = timer('TimerFcn',@(h,e)obj.processLiveEvents(), 'ExecutionMode', 'fixedRate', 'Period', 0.01);

            % If using the legacy Bonsai TCP/IP socket, clear any bytes remaining from the trial interval
            if ~isempty(BpodSystem.BonsaiSocket)
                obj.usingBonsai = 1;
                bonsaiBytesAvailable = BpodSystem.BonsaiSocket.bytesAvailable;
                if bonsaiBytesAvailable > 0
                    BpodSystem.BonsaiSocket.read(bonsaiBytesAvailable, 'uint8');
                end
            end
        end

        function startTrial(obj, varargin)
            % startTrial() begins monitoring events from the Bpod State Machine. If the
            % 'RunASAP' flag was not passed on the previous call to SendStateMachine(),
            % startTrial sends the 'R' command to the Bpod State Machine to start the
            % trial before BpodTrialManager begins monitoring.
            %
            % Arguments:
            % sma (optional), a state machine description struct to send to the state
            % machine before running the trial. This is not necessary if a state machine
            % description was previously sent with a call to SendStateMachine().
            %
            % Returns: None
            %
            % Usage Example:
            % B = BpodTrialManager; % Create an instance of BpodTrialManager
            % B.startTrial(sma); % Send sma to the Bpod State Machine, send the 'R'
            % command and begin monitoring events.

            global BpodSystem % Import the global BpodSystem object

            % Raise a flag a state machine description was passed in, to send to the machine
            smaSent = 1;
            if nargin > 1
                smaSent = 0;
                stateMatrix = varargin{1};
            end

            % Initialize flags
            obj.prepareNextTrialFlag = 0;
            obj.trialEndFlag = 0;

            % Initialize the Flex I/O analog interface if this is the first trial in session
            if BpodSystem.Status.SessionStartFlag == 1
                BpodSystem.Status.SessionStartFlag = 0;
                if BpodSystem.MachineType == 4
                    BpodSystem.AnalogSerialPort.flush;
                    start(BpodSystem.Timers.AnalogTimer);
                end
            end

            % Send the run command to the state machine and load the current trial's
            % state machine description if necessary
            if smaSent
                if BpodSystem.Status.SM2runASAP == 0
                    BpodSystem.SerialPort.write('R', 'uint8');
                end
                BpodSystem.Status.BeingUsed = 1;
            else
                BpodSystem.Status.BeingUsed = 1;
                SendStateMachine(stateMatrix, 'RunASAP');
            end
            BpodSystem.Status.InStateMatrix = 1; % Flag indicating that a trial is running
            BpodSystem.Status.SM2runASAP = 0; % Reset runASAP flag, previously set by SendStateMachine()

            % Confirm that if a state machine description was sent, it was received by
            % the Bpod State Machine device prior to trial start
            smaConfirmed = BpodSystem.SerialPort.read(1, 'uint8');
            if isempty(smaConfirmed) || smaConfirmed ~= 1
                BpodSystem.Status.BeingUsed = 0;
                BpodSystem.Status.InStateMatrix = 0;
                error('Error: The last state machine sent was not acknowledged by the Bpod device.');
            end

            % Read and format trial start timestamp
            trialStartTimestampBytes = BpodSystem.SerialPort.read(8, 'uint8');
            obj.trialStartTimestamp = double(typecast(trialStartTimestampBytes, 'uint64'))/1000000;
            % Start-time of the trial in microseconds (compensated for 32-bit clock rollover)

            % Set current state machine description
            BpodSystem.StateMatrix = BpodSystem.StateMatrixSent;

            % Reset status fields (to be synced with console UI)
            BpodSystem.Status.NewStateMachineSent = 0;
            BpodSystem.Status.LastStateCode = 0; % Last state (index)
            BpodSystem.Status.CurrentStateCode = 1; % Current state (index)
            BpodSystem.Status.LastStateName = '---'; % Last state (name)
            BpodSystem.Status.CurrentStateName = BpodSystem.StateMatrix.StateNames{1}; % Current state (name)
            BpodSystem.HardwareState.OutputOverride(1:end) = 0; % Reset manual overrides

            % Reset Console GUI
            BpodSystem.RefreshGUI;
            timeElapsed = ceil((now*100000) - BpodSystem.ProtocolStartTime);
            set(BpodSystem.GUIHandles.TimeDisplay, 'String', obj.secs2hms(timeElapsed));
            set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton);

            % Reset emulator
            if BpodSystem.EmulatorMode == 1
                RunBpodEmulator('init', []);
                BpodSystem.ManualOverrideFlag = 0;
            end

            % Populate local copy of state machine description
            obj.inputMatrix = BpodSystem.StateMatrix.InputMatrix;
            obj.globalTimerStartMatrix = BpodSystem.StateMatrix.GlobalTimerStartMatrix;
            obj.globalTimerEndMatrix = BpodSystem.StateMatrix.GlobalTimerEndMatrix;
            obj.globalCounterMatrix = BpodSystem.StateMatrix.GlobalCounterMatrix;
            obj.conditionMatrix = BpodSystem.StateMatrix.ConditionMatrix;
            obj.stateTimerMatrix = BpodSystem.StateMatrix.StateTimerMatrix;
            obj.stateNames = BpodSystem.StateMatrix.StateNames;
            obj.nTotalStates = BpodSystem.StateMatrix.nStatesInManifest;

            % Populate local copy of event offsets
            obj.globalTimerStartOffset = BpodSystem.StateMatrix.meta.InputMatrixSize+1;
            obj.globalTimerEndOffset = obj.globalTimerStartOffset+BpodSystem.HW.n.GlobalTimers;
            obj.globalCounterOffset = obj.globalTimerEndOffset+BpodSystem.HW.n.GlobalTimers;
            obj.conditionOffset = obj.globalCounterOffset+BpodSystem.HW.n.GlobalCounters;
            obj.stateTimerOffset = obj.conditionOffset+BpodSystem.HW.n.Conditions;
            obj.eventNames = BpodSystem.StateMachineInfo.EventNames;

            % Initialize trial variables
            obj.nEvents = 0;
            obj.nStates = 1;
            obj.trialEvents = zeros(1,obj.maxEvents);
            obj.states = zeros(1,obj.maxEvents);
            obj.liveEventTimestamps = zeros(1,obj.maxEvents);
            obj.currentEvent = zeros(1,100);
            obj.stateChangeIndexes = zeros(1,obj.maxEvents);
            obj.states(obj.nStates) = 1;

            % Start the timer. This will call processLiveEvents() every 10ms
            start(obj.timer);

            % Check for excess inter-trial dead time
            if obj.lastTrialEndTime > 0
                lastTrialDeadTime = obj.trialStartTimestamp - obj.lastTrialEndTime;
                if BpodSystem.MachineType > 2
                    threshold = 0.00051;
                    micros = num2str(500);
                else
                    threshold = 0.00075;
                    micros = num2str(750);
                end
                if lastTrialDeadTime > threshold
                    disp(' ');
                    disp('*********************************************************************');
                    disp('*                            WARNING                                *');
                    disp('*********************************************************************');
                    disp(['TrialManager reported an inter-trial dead time of >' micros ' microseconds.']);
                    disp('This may indicate that inter-trial code (e.g. plotting, saving data)');
                    disp('took MATLAB more than 1 trial duration to execute. MATLAB must reach');
                    disp('TrialManager.getTrialData() before trial end. Please check lines of');
                    disp('your protocol main loop (e.g. with tic/toc) and optimize accordingly.');
                    disp('*********************************************************************');
                end
            end
        end

        function rawTrialEvents = getTrialData(obj)
            % getTrialData() blocks the MATLAB interpreter until the Bpod State Machine reaches
            % an exit state. It returns a complete set of events and states for the trial just
            % completed, which can be added to the session dataset with AddTrialEvents().
            %
            % Arguments: None
            %
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
            % Usage example:
            % B = BpodTrialManager; % Create an instance of BpodTrialManager
            % --- start trial with B.startTrial() and execute MATLAB-side user code during the trial ---
            % rawEvents = B.getTrialData();

            global BpodSystem % Import the global BpodSystem object

            rawTrialEvents = struct; % Create struct for trial data

            % Wait until state machine exits the current trial
            while ~obj.trialEndFlag && BpodSystem.Status.BeingUsed == 1
                drawnow;
            end

            if BpodSystem.Status.BeingUsed == 1 % If exit was due to manual termination, BeingUsed is 0.
                % Trim unused preallocated data
                obj.trialEvents = obj.trialEvents(1:obj.nEvents);
                obj.states = obj.states(1:obj.nStates);
                obj.stateChangeIndexes = obj.stateChangeIndexes(1:obj.nStates-1);

                % Read trial-end timestamps.
                trialEndTimestamps = BpodSystem.SerialPort.read(12, 'uint8');
                nHWTimerCycles = double(typecast(trialEndTimestamps(1:4), 'uint32'));
                trialEndTimestamp = double(typecast(trialEndTimestamps(5:12), 'uint64'))/1000000;

                % Read and format Timestamps
                if BpodSystem.EmulatorMode == 0
                    if BpodSystem.LiveTimestamps == 0
                        nTimeStamps = double(BpodSystem.SerialPort.read(1, 'uint16'));
                        timeStamps = double(BpodSystem.SerialPort.read(nTimeStamps, 'uint32'));
                        timeStamps = timeStamps*(BpodSystem.HW.CyclePeriod/1000);
                    else
                        timeStamps = obj.liveEventTimestamps(1:obj.nEvents);
                    end
                else
                    obj.trialStartTimestamp = BpodSystem.Emulator.MatrixStartTime-(BpodSystem.Status.BpodStartTime*100000);
                    timeStamps = (BpodSystem.Emulator.Timestamps(1:BpodSystem.Emulator.nEvents)*1000);
                end

                thisTrialErrorCodes = [];

                % Internal check for violations of timing guarantees. Trial time from roll-over compensated
                % micros() is compared with the number of hardware timer callbacks executed. These trial
                % duration metrics should match if timer callbacks did not exceed the hardware timer interval
                trialTimeFromMicros = (trialEndTimestamp - obj.trialStartTimestamp);
                trialTimeFromCycles = (nHWTimerCycles/BpodSystem.HW.CycleFrequency);
                discrepancy = abs(trialTimeFromMicros - trialTimeFromCycles)*1000;
                if discrepancy > 1
                    disp([char(10) '***WARNING!***' char(10) 'Bpod missed hardware update deadline(s) on the past trial, by ~'...
                        num2str(discrepancy)...
                        'ms!' char(10) 'An error code (1) has been added to your trial data.' char(10) '**************'])
                    thisTrialErrorCodes(1) = 1;
                end

                % Determine event and state timestamps
                eventTimeStamps = timeStamps;
                stateTimeStamps = zeros(1,obj.nStates);
                stateTimeStamps(2:obj.nStates) = timeStamps(obj.stateChangeIndexes);
                stateTimeStamps(1) = 0;

                % Package trial events, states and timestamps
                rawTrialEvents.States = obj.states;
                rawTrialEvents.Events = obj.trialEvents;
                rawTrialEvents.StateTimestamps = obj.round2cycles(stateTimeStamps)/1000; % Convert to seconds
                rawTrialEvents.EventTimestamps = obj.round2cycles(eventTimeStamps)/1000;
                rawTrialEvents.TrialStartTimestamp = obj.round2cycles(obj.trialStartTimestamp);
                rawTrialEvents.TrialEndTimestamp = obj.round2cycles(trialEndTimestamp);
                rawTrialEvents.StateTimestamps(end+1) = rawTrialEvents.EventTimestamps(end);
                rawTrialEvents.ErrorCodes = thisTrialErrorCodes;
                obj.lastTrialEndTime = rawTrialEvents.TrialEndTimestamp;
            else
                % Trial was terminated manually. Clear the timer object
                stop(obj.timer);
                delete(obj.timer);
                obj.timer = [];
            end

            % Cleanup
            obj.update_hardwarestate_new_state(0);
            BpodSystem.LastStateMatrix = BpodSystem.StateMatrix;
            BpodSystem.Status.InStateMatrix = 0;
        end

        function currentEvents = getCurrentEvents(obj, triggerStates)
            % getCurrentEvents() blocks the MATLAB interpreter until specific state(s)
            % are reached. It returns a trial event structure for the trial up to that point,
            % that can be used to compute the next trial's state machine description.
            %
            % Arguments:
            % triggerStates, a cell array with target state name(s) that trigger return of currentEvents.
            %
            % Returns: currentEvents, a struct containing the states visited, events captured and timestamps.
            %
            % The format of currentEvents is:
            % currentEvents.RawData - A struct with a list of states visited, events captured and timestamps.
            % currentEvents.StatesVisited - A human-readable cell array listing state names in the order they were visited
            % currentEvents.EventsCaptured - A human-readable cell array listing event names in the order they occurred
            % NOTE: A legend of state and event indexes is given on the system info panel of the Bpod Console GUI
            %
            % Usage example:
            % B = BpodTrialManager; % Create an instance of BpodTrialManager
            % --- start trial with B.startTrial() and execute MATLAB-side user code during the trial ---
            % currentEvents = B.getCurrentEvents();

            global BpodSystem % Import the global BpodSystem object

            if ~isempty(triggerStates)

                % Ensure format of triggerStates
                if ischar(triggerStates) % If a single state was passed as a string, package to cell
                    triggerStates = {triggerStates};
                elseif ~iscell(triggerStates)
                    error('Error running BpodTrialManager.getCurrentEvents() - triggerStates argument must be a cell array of strings')
                end

                % Find state numbers corresponding to state names provided
                obj.nextTrialTriggerStates = find(ismember(BpodSystem.StateMatrix.StateNames, triggerStates));

                % If state numbers were found, proceed:
                if length(obj.nextTrialTriggerStates) == length(triggerStates)
                    currentEvents = struct; % Initialize trial data struct to return

                    % Wait until a prepare next trial trigger state is reached
                    while ~obj.prepareNextTrialFlag && BpodSystem.Status.BeingUsed == 1 && BpodSystem.Status.InStateMatrix == 1
                        pause(.001);
                    end

                    % If the user has not manually exited the trial, proceed:
                    if BpodSystem.Status.BeingUsed == 1
                        % Compile raw state, event and timestamp data
                        currentEvents.RawData = struct;
                        currentEvents.RawData.StatesVisited = obj.states(1:obj.nStates);
                        currentEvents.RawData.EventsCaptured = obj.trialEvents(1:obj.nEvents);
                        if BpodSystem.LiveTimestamps == 1
                            currentEvents.RawData.EventTimestamps = obj.liveEventTimestamps(1:obj.nEvents);
                        end

                        % Add human-readable lists of states and events
                        currentEvents.StatesVisited = BpodSystem.StateMatrix.StateNames(currentEvents.RawData.StatesVisited);
                        currentEvents.EventsCaptured = BpodSystem.StateMachineInfo.EventNames(currentEvents.RawData.EventsCaptured);
                    else
                        % Trial was terminated manually. Clear the timer object
                        stop(obj.timer);
                        delete(obj.timer);
                        obj.timer = [];
                    end
                else
                    error(['Error running BpodTrialManager.getCurrentEvents() - '''...
                        'triggerStates argument contains at least 1 invalid state name.'])
                end
            else
                error('Error running BpodTrialManager.getCurrentEvents() - triggerStates argument must be a cell array of strings')
            end
        end

        function delete(obj)
            % The object is being deleted. Clear the timer object.
            if ~isempty(obj.timer)
                stop(obj.timer);
                delete(obj.timer);
                obj.timer = [];
            end
        end
    end

    methods (Access = private)
        function processLiveEvents(obj, ev)
            % Reads and handles incoming events and timestamps from the
            % Bpod State Machine. This function is called every 10ms by a
            % timer object initialized in the BpodTrialManager constructor.

            global BpodSystem % Import the global BpodSystem object

            % Check for events on legacy Bonsai TCP/IP inferface if initialized.
            if obj.usingBonsai
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
                newMessage = 0; nBytesRead = 0;
                maxBytesToRead = BpodSystem.SerialPort.bytesAvailable;
                if maxBytesToRead > 0
                    newMessage = 1;
                end
            else
                if BpodSystem.ManualOverrideFlag == 1
                    manualOverrideEvent = VirtualManualOverride(BpodSystem.VirtualManualOverrideBytes);
                    BpodSystem.ManualOverrideFlag = 0;
                else
                    manualOverrideEvent = [];
                end
                maxBytesToRead = 3;
                [newMessage, opCodeBytes, VirtualCurrentEvents] = RunBpodEmulator('loop', manualOverrideEvent);
            end

            if newMessage % If there are new events or soft codes to read
                while (maxBytesToRead - nBytesRead > 1) && obj.trialEndFlag == 0
                    if BpodSystem.EmulatorMode == 0
                        opCodeBytes = BpodSystem.SerialPort.read(2, 'uint8');
                        nBytesRead = nBytesRead + 2;
                    end
                    opCode = opCodeBytes(1);
                    switch opCode
                        case 1 % Receive and handle events
                            nCurrentEvents = double(opCodeBytes(2)); % Determine number of events that follow
                            if BpodSystem.EmulatorMode == 0
                                if BpodSystem.LiveTimestamps == 1
                                    % Read available events
                                    tempCurrentEvents = BpodSystem.SerialPort.read(nCurrentEvents+4, 'uint8');
                                    nBytesRead = nBytesRead + nCurrentEvents + 4;
                                    thisTimestamp = double(typecast(tempCurrentEvents(end-3:end), 'uint32'))*obj.timeScaleFactor;
                                    tempCurrentEvents = tempCurrentEvents(1:end-4);
                                else
                                    tempCurrentEvents = BpodSystem.SerialPort.read(nCurrentEvents, 'uint8');
                                end
                            else
                                tempCurrentEvents = VirtualCurrentEvents;
                            end

                            % Convert from c++ index at 0 to MATLAB index at 1
                            obj.currentEvent(1:nCurrentEvents) = tempCurrentEvents(1:nCurrentEvents) + 1;

                            % Find and compute state transitions
                            transitionEventFound = 0; i = 1;
                            newState = BpodSystem.Status.CurrentStateCode;
                            while (transitionEventFound == 0) && (i <= nCurrentEvents)
                                if obj.currentEvent(i) == 255
                                    obj.trialEndFlag = 1;
                                    stop(obj.timer);
                                    BpodSystem.Status.InStateMatrix = 0;
                                    break
                                elseif obj.currentEvent(i) < obj.globalTimerStartOffset
                                    newState = obj.inputMatrix(BpodSystem.Status.CurrentStateCode, obj.currentEvent(i));
                                elseif obj.currentEvent(i) < obj.globalTimerEndOffset
                                    newState = obj.globalTimerStartMatrix(BpodSystem.Status.CurrentStateCode,...
                                        obj.currentEvent(i)-(obj.globalTimerStartOffset-1));
                                elseif obj.currentEvent(i) < obj.globalCounterOffset
                                    newState = obj.globalTimerEndMatrix(BpodSystem.Status.CurrentStateCode,...
                                        obj.currentEvent(i)-(obj.globalTimerEndOffset-1));
                                elseif obj.currentEvent(i) < obj.conditionOffset
                                    newState = obj.globalCounterMatrix(BpodSystem.Status.CurrentStateCode,...
                                        obj.currentEvent(i)-(obj.globalCounterOffset-1));
                                elseif obj.currentEvent(i) < obj.stateTimerOffset
                                    newState = obj.conditionMatrix(BpodSystem.Status.CurrentStateCode,...
                                        obj.currentEvent(i)-(obj.conditionOffset-1));
                                elseif obj.currentEvent(i) == BpodSystem.HW.StateTimerPosition
                                    newState = obj.stateTimerMatrix(BpodSystem.Status.CurrentStateCode);
                                else
                                    error(['Error: Unknown event code returned: ' num2str(obj.currentEvent(i))]);
                                end
                                if newState ~= BpodSystem.Status.CurrentStateCode
                                    transitionEventFound = 1;
                                end
                                i = i + 1;
                            end

                            % Update hardware mirror to reflect new event
                            obj.update_hardwarestate_new_event(obj.currentEvent);

                            % Execute state transitions if found
                            if transitionEventFound
                                if BpodSystem.StateMatrix.meta.use255BackSignal == 1
                                    if newState == 256
                                        newState = BpodSystem.Status.LastStateCode;
                                    end
                                end
                                if newState <= obj.nTotalStates
                                    if sum(obj.nextTrialTriggerStates == newState) > 0
                                        obj.prepareNextTrialFlag = 1;
                                    end
                                    obj.stateChangeIndexes(obj.nStates) = obj.nEvents+1;
                                    obj.nStates = obj.nStates + 1;
                                    obj.states(obj.nStates) = newState;
                                    BpodSystem.Status.LastStateCode = BpodSystem.Status.CurrentStateCode;
                                    BpodSystem.Status.CurrentStateCode = newState;
                                    BpodSystem.Status.CurrentStateName = obj.stateNames{newState};
                                    BpodSystem.Status.LastStateName = obj.stateNames{BpodSystem.Status.LastStateCode};
                                    obj.update_hardwarestate_new_state(newState);
                                    if BpodSystem.EmulatorMode == 1
                                        BpodSystem.Emulator.CurrentState = newState;
                                        BpodSystem.Emulator.StateStartTime = BpodSystem.Emulator.CurrentTime;
                                        % Set global timer end-time
                                        thisGlobalTimer =... 
                                            BpodSystem.StateMatrix.OutputMatrix(newState,BpodSystem.HW.Pos.GlobalTimerTrig);
                                        if thisGlobalTimer ~= 0
                                            if BpodSystem.StateMatrix.GlobalTimers.OnsetDelay(thisGlobalTimer) == 0
                                                BpodSystem.Emulator.GlobalTimerEnd(thisGlobalTimer) =... 
                                                    BpodSystem.Emulator.CurrentTime +...
                                                    BpodSystem.StateMatrix.GlobalTimers.Duration(thisGlobalTimer);
                                                BpodSystem.Emulator.GlobalTimersActive(thisGlobalTimer) = 1;
                                                BpodSystem.Emulator.GlobalTimersTriggered(thisGlobalTimer) = 0;
                                            else
                                                BpodSystem.Emulator.GlobalTimerStart(thisGlobalTimer) =... 
                                                    BpodSystem.Emulator.CurrentTime +...
                                                    BpodSystem.StateMatrix.GlobalTimers.OnsetDelay(thisGlobalTimer);
                                                BpodSystem.Emulator.GlobalTimerEnd(thisGlobalTimer) =...
                                                    BpodSystem.Emulator.GlobalTimerStart(thisGlobalTimer) +...
                                                    BpodSystem.StateMatrix.GlobalTimers.Duration(thisGlobalTimer);
                                                BpodSystem.Emulator.GlobalTimersTriggered(thisGlobalTimer) = 1;
                                            end
                                        end
                                        % Cancel global timers
                                        thisGlobalTimer = ...
                                            BpodSystem.StateMatrix.OutputMatrix(newState,BpodSystem.HW.Pos.GlobalTimerCancel);
                                        if thisGlobalTimer ~= 0
                                            BpodSystem.Emulator.GlobalTimersActive(thisGlobalTimer) = 0;
                                        end
                                        % Reset global counter counts
                                        thisGlobalCounter = ...
                                            BpodSystem.StateMatrix.OutputMatrix(newState,BpodSystem.HW.Pos.GlobalCounterReset);
                                        if thisGlobalCounter ~= 0
                                            BpodSystem.Emulator.GlobalCounterCounts(thisGlobalCounter) = 0;
                                        end
                                        % Update soft code
                                        BpodSystem.Emulator.SoftCode = ...
                                            BpodSystem.StateMatrix.OutputMatrix(newState,BpodSystem.HW.Pos.Output_USB);
                                    end
                                else
                                    if BpodSystem.EmulatorMode == 1
                                        obj.stateChangeIndexes(obj.nStates) = obj.nEvents+1;
                                        obj.trialEvents(obj.nEvents+1:(obj.nEvents+nCurrentEvents)) = obj.currentEvent(1:nCurrentEvents);
                                        obj.nEvents = obj.nEvents + nCurrentEvents;
                                        obj.trialEndFlag = 1;
                                        stop(obj.timer);
                                    end
                                end
                            end

                            % Add captured events to data structure
                            if BpodSystem.Status.InStateMatrix == 1
                                BpodSystem.Status.LastEvent = obj.currentEvent(1);
                                if maxBytesToRead < 250 % Disable time-costly console GUI updates if data is backed up
                                    BpodSystem.RefreshGUI;
                                end
                                obj.trialEvents(obj.nEvents+1:(obj.nEvents+nCurrentEvents)) = obj.currentEvent(1:nCurrentEvents);
                                if BpodSystem.LiveTimestamps == 1
                                    obj.liveEventTimestamps(obj.nEvents+1:(obj.nEvents+nCurrentEvents)) = thisTimestamp;
                                end
                                obj.currentEvent(1:nCurrentEvents) = 0;
                                obj.nEvents = obj.nEvents + uint32(nCurrentEvents);
                            end
                        case 2 % Soft-code
                            softCode = opCodeBytes(2);
                            obj.handle_soft_code(softCode);
                        otherwise
                            disp('Error: Invalid op code received')
                    end
                    if BpodSystem.EmulatorMode == 1
                        nBytesRead = maxBytesToRead;
                    end
                end
            end
        end

        function timeString = secs2hms(obj,seconds)
            % Converts seconds to HH:MM:SS string format
            h = floor(seconds / 3600);
            m = floor(mod(seconds, 3600) / 60);
            s = mod(seconds, 60);
            timeString = sprintf('%02d:%02d:%02d', h, m, s);
        end

        function handle_soft_code(obj,softCode)
            % Calls the current soft code handler function, passing it the SoftCode
            % received from the state machine
            global BpodSystem % Import the global BpodSystem object
            eval([BpodSystem.SoftCodeHandlerFunction '(' num2str(softCode) ')'])
        end

        function manualOverrideEvent = VirtualManualOverride(a,overrideMessage)
            % Converts the byte code transmission formatted for the state machine into event codes
            global BpodSystem % Import the global BpodSystem object
            opCode = overrideMessage(1);
            if opCode == 'V'
                inputChannel = overrideMessage(2)+1;
                eventType = BpodSystem.HardwareState.InputType(inputChannel);
                if ~strcmp(eventType, {'U','X'})
                    newChannelState = BpodSystem.HardwareState.InputState(inputChannel);
                    manualOverrideEvent = BpodSystem.HW.Pos.Event_BNC-1 +...
                        2*(inputChannel-BpodSystem.HW.Pos.Output_USB)-1 + (1-newChannelState);
                else
                    switch eventType
                        case 'U'
                            manualOverrideEvent = [];
                        case 'X'
                            manualOverrideEvent = [];
                    end
                end
            elseif opCode == 'S'
                obj.handle_soft_code(uint8(overrideMessage(2)));
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

        function update_hardwarestate_new_event(a,events)
            % Updates BpodSystem.HardwareState to reflect new event(s).
            global BpodSystem % Import the global BpodSystem object
            for i = 1:sum(events ~= 0)
                thisEvent = events(i);
                if thisEvent ~= 255
                    switch BpodSystem.HW.EventTypes(thisEvent)
                        case 'I'
                            p = ((thisEvent-BpodSystem.HW.IOEventStartposition)/2) +...
                                BpodSystem.HW.n.SerialChannels+BpodSystem.HW.n.FlexIO+1;
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

        function update_hardwarestate_new_state(obj,currentState)
            % Updates BpodSystem.HardwareState to reflect entry into a new state
            global BpodSystem % Import the global BpodSystem object
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

        function timeOutput = round2cycles(obj,decimalInput)
            % Trims precision of timestamps to match state machine refresh interval
            timeOutput = round(decimalInput*(obj.cycleFrequency))/(obj.cycleFrequency);
        end
    end
end
