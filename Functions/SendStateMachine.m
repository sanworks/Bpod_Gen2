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

% SendStateMachine() transfers a state machine description to the Bpod
% Finite State Machine device. The most recent state machine sent can then
% be run with RunStateMachine() or TrialManager.startTrial().
%
% Arguments:
% sma, a state machine description created with NewStateMachine() and
% populated with the other functions in /Functions/State Machine Assembler/
%
% runASAP (optional). If while running a trial the state machine
% receives a state machine description sent with SendStateMachine, if
% runASAP = 1 the new state machine will begin running immediately
% following the end of the current trial. If runASAP = 0 (default), the state machine
% will wait for the 'R' command. runASAP is only required if using TrialManager.
%
% Returns:
% confirmed (depricated). To preserve compatibility with existing user code, a 1
% is returned. This does not indicate successful transmission of the state
% machine description. Successful transmission is verified later, in
% RunStateMachine() or BpodTrialManager.startTrial()
%
% Example usage: SendStateMachine(sma);

function confirmed = SendStateMachine(sma, varargin)

global BpodSystem % Import the global BpodSystem object

% Determine runASAP, a flag indicating whether to auto-run the state matrix when the current one exits
runASAP = 0; 
if nargin > 1
    argin = varargin{1};
    if strcmp(argin, 'RunASAP')
        runASAP = 1;
    else
        error(['Error: ' argin ' is not a valid argument for SendStateMachine.'])
    end
end

% If '>back' operator was provided by the user in AddState(), going to
% state 255 returns the system back to the previous state
use255BackSignal = sma.meta.use255BackSignal;

% Shut down any active module relays
if sum(BpodSystem.Modules.RelayActive) > 0
    BpodSystem.StopModuleRelay();
end

nStates = length(sma.StateNames); % Determine number of states

% Check to make sure the Placeholder state was replaced
if strcmp(sma.StateNames{1},'Placeholder')
    error('Error: could not send an empty matrix. You must define at least one state first.')
end

% Check to make sure the state machine description doesn't have undefined states
if sum(sma.StatesDefined == 0) > 0
    disp('Error: The state machine contains references to the following undefined states: ');
    undefinedStates = find(sma.StatesDefined == 0);
    nUndefinedStates = length(undefinedStates);
    undefinedStateNames = cell(1,nUndefinedStates);
    for x = 1:nUndefinedStates
        undefinedStateNames{x} = [sma.StateNames{undefinedStates(x)} ' '];
    end
    error(['Please define the following states using the AddState function before sending the state machine: '... 
          cell2mat(undefinedStateNames)])
end

% Ensure that the state machine description does not exceed the maximum number of states
MaxStates = BpodSystem.StateMachineInfo.MaxStates;
if sma.meta.use255BackSignal
    MaxStates = MaxStates - 1;
end
if nStates > MaxStates
    error(['Error: the current state matrix can have a maximum of ' num2str(MaxStates) ' states.'])
end

% Check to make sure the sync channel is not used as a state output. The sync
% channel can be configured from the settings menu in the Bpod Console GUI.
if BpodSystem.SyncConfig.Channel ~= 255
    SyncChanOutputStates = sma.OutputMatrix(:,BpodSystem.SyncConfig.Channel+1) > 0;
    if (sum(SyncChanOutputStates) > 0) > 0
        ProblemStateNames = sma.StateNames(SyncChanOutputStates);
        nProblemStates = length(ProblemStateNames);
        ErrorMessage = ('Error: The sync channel cannot simultaneously be used as a state output.');
        ErrorMessage = [ErrorMessage char(13) 'Check the following states:'];
        for i = 1:nProblemStates
            ErrorMessage = [ErrorMessage char(13) ProblemStateNames{i}];
        end
        error(ErrorMessage);
    end
    GTSyncChannels = sma.GlobalTimers.OutputChannel == BpodSystem.SyncConfig.Channel+1;
    if sum(GTSyncChannels) > 0
        error(['Error: The sync channel cannot be used as a global timer output channel.' char(10)...
            'Please check global timer number(s): ' num2str(find(GTSyncChannels))...
            char(10) 'OR change the sync channel from the Bpod console.'])
    end
end

% Rearrange states to reflect order they were added 
% (by default, they are numbered as referenced by name in iterative calls to AddState()).
sma.Manifest = sma.Manifest(1:sma.nStatesInManifest);
StateOrder = zeros(1,sma.nStatesInManifest);
OriginalInputMatrix = sma.InputMatrix;
OriginalTimerStartMatrix = sma.GlobalTimerStartMatrix;
OriginalTimerEndMatrix = sma.GlobalTimerEndMatrix;
OriginalCounterMatrix = sma.GlobalCounterMatrix;
OriginalConditionMatrix = sma.ConditionMatrix;
OriginalStateTimerMatrix = sma.StateTimerMatrix;
for i = 1:sma.nStatesInManifest
    StateOrder(i) = find(strcmp(sma.StateNames, sma.Manifest{i}));
    if StateOrder(i) ~= i
        sma.InputMatrix(OriginalInputMatrix==StateOrder(i)) = i;
        sma.StateTimerMatrix(OriginalStateTimerMatrix==StateOrder(i)) = i;
        sma.GlobalTimerStartMatrix(OriginalTimerStartMatrix==StateOrder(i)) = i;
        sma.GlobalTimerEndMatrix(OriginalTimerEndMatrix==StateOrder(i)) = i;
        sma.GlobalCounterMatrix(OriginalCounterMatrix==StateOrder(i)) = i;
        sma.ConditionMatrix(OriginalConditionMatrix==StateOrder(i)) = i;
    end
end
sma.InputMatrix = sma.InputMatrix(StateOrder,:);
sma.OutputMatrix = sma.OutputMatrix(StateOrder,:);
sma.StateTimerMatrix = sma.StateTimerMatrix(StateOrder);
sma.GlobalTimerStartMatrix = sma.GlobalTimerStartMatrix(StateOrder,:);
sma.GlobalTimerEndMatrix = sma.GlobalTimerEndMatrix(StateOrder,:);
sma.GlobalCounterMatrix = sma.GlobalCounterMatrix(StateOrder,:);
sma.ConditionMatrix = sma.ConditionMatrix(StateOrder,:);
sma.StateNames = sma.StateNames(StateOrder);
sma.StateTimers = sma.StateTimers(StateOrder);

% Add >exit and >back state codes to transition matrices
exitState = nStates+1; % nStates+1 is the state machine's op code for the exit state
backState = 256; % IF >back is used in the SM, 255 (256 here due to indexing) is the state machine's 
                 % op code for returning to the previous state
sma.InputMatrix(sma.InputMatrix == 65537) = exitState; % 65537 is the assembler's op code for the >exit op
sma.StateTimerMatrix(sma.StateTimerMatrix == 65537) = exitState;
sma.GlobalTimerStartMatrix(sma.GlobalTimerStartMatrix == 65537) = exitState;
sma.GlobalTimerEndMatrix(sma.GlobalTimerEndMatrix == 65537) = exitState;
sma.GlobalCounterMatrix(sma.GlobalCounterMatrix == 65537) = exitState;
sma.ConditionMatrix(sma.ConditionMatrix == 65537) = exitState;
sma.InputMatrix(sma.InputMatrix == 65538) = backState; % 65538 is the assembler's op code for the >back op
sma.StateTimerMatrix(sma.StateTimerMatrix == 65538) = backState;
sma.GlobalTimerStartMatrix(sma.GlobalTimerStartMatrix == 65538) = backState;
sma.GlobalTimerEndMatrix(sma.GlobalTimerEndMatrix == 65538) = backState;
sma.GlobalCounterMatrix(sma.GlobalCounterMatrix == 65538) = backState;
sma.ConditionMatrix(sma.ConditionMatrix == 65538) = backState;

% Determine number of global timers, global counters and conditions used
nGlobalTimersUsed = find(sma.GlobalTimers.IsSet, 1, 'last');
nGlobalCountersUsed = find(sma.GlobalCounterSet, 1, 'last');
nConditionsUsed = find(sma.ConditionSet, 1, 'last');
if isempty(nGlobalTimersUsed); nGlobalTimersUsed = 0; end
if isempty(nGlobalCountersUsed); nGlobalCountersUsed = 0; end
if isempty(nConditionsUsed); nConditionsUsed = 0; end

% Next, format input, output, timer, counter and condition matrices into linear
% byte vectors for transfer. This employs a compression scheme where only
% differences from the default matrix are sent.

% First, set up default matrices with 'same state' for every event
defaultInputMatrix = repmat((1:nStates)', 1, sma.meta.InputMatrixSize);
defaultExtensionMatrix_GT = defaultInputMatrix(1:nStates, 1:nGlobalTimersUsed);
defaultExtensionMatrix_GC = defaultInputMatrix(1:nStates, 1:nGlobalCountersUsed);
defaultExtensionMatrix_C = defaultInputMatrix(1:nStates, 1:nConditionsUsed);

% Compute compressed input matrix
differenceMatrix = (sma.InputMatrix ~= defaultInputMatrix)';
nDifferences = sum(differenceMatrix);
msgLength = sum(nDifferences>0)*2 + nStates;
inputMatrix = zeros(1,msgLength); pos = 1;
for i = 1:nStates
    inputMatrix(pos) = nDifferences(i); pos = pos + 1;
    if nDifferences(i) > 0
        thisState = differenceMatrix(:,i)';
        positions = find(thisState)-1;
        values = sma.InputMatrix(i,thisState)-1;
        posVal = [positions; values];
        posVal = posVal(1:end);
        inputMatrix(pos:pos+(nDifferences(i)*2)-1) = posVal;
        pos = pos + nDifferences(i)*2;
    end
end
inputMatrix = uint8(inputMatrix);

% Compute compressed output matrix
outputMatrixRaw = sma.OutputMatrix(:, 1:BpodSystem.HW.Pos.GlobalTimerTrig-1); % All physical channels. 
                                                                              % Virtual outputs are handled separately
differenceMatrix = (outputMatrixRaw ~= 0)';
nDifferences = sum(differenceMatrix, 1);
msgLength = sum(nDifferences>0)*2 + nStates;
outputMatrix = zeros(1,msgLength); pos = 1;
for i = 1:nStates
    outputMatrix(pos) = nDifferences(i); pos = pos + 1;
    if nDifferences(i) > 0
        thisState = differenceMatrix(:,i)';
        positions = find(thisState)-1;
        values = outputMatrixRaw(i,thisState);
        posVal = [positions; values];
        posVal = posVal(1:end);
        outputMatrix(pos:pos+(nDifferences(i)*2)-1) = posVal;
        pos = pos + nDifferences(i)*2;
    end
end
if BpodSystem.MachineType == 4
    outputMatrix = typecast(uint16(outputMatrix), 'uint8');
else
    outputMatrix = uint8(outputMatrix);
end

% Compute compressed global timer start matrix
differenceMatrix = (sma.GlobalTimerStartMatrix(:,1:nGlobalTimersUsed) ~= defaultExtensionMatrix_GT)';
nDifferences = sum(differenceMatrix, 1);
msgLength = sum(nDifferences>0)*2 + nStates;
globalTimerStartMatrix = zeros(1,msgLength); pos = 1;
for i = 1:nStates
    globalTimerStartMatrix(pos) = nDifferences(i); pos = pos + 1;
    if nDifferences(i) > 0
        thisState = differenceMatrix(:,i)';
        positions = find(thisState)-1;
        values = sma.GlobalTimerStartMatrix(i,thisState)-1;
        posVal = [positions; values];
        posVal = posVal(1:end);
        globalTimerStartMatrix(pos:pos+(nDifferences(i)*2)-1) = posVal;
        pos = pos + nDifferences(i)*2;
    end
end
globalTimerStartMatrix = uint8(globalTimerStartMatrix);

% Compute compressed global timer end matrix
differenceMatrix = (sma.GlobalTimerEndMatrix(:,1:nGlobalTimersUsed) ~= defaultExtensionMatrix_GT)';
nDifferences = sum(differenceMatrix, 1);
msgLength = sum(nDifferences>0)*2 + nStates;
globalTimerEndMatrix = zeros(1,msgLength); pos = 1;
for i = 1:nStates
    globalTimerEndMatrix(pos) = nDifferences(i); pos = pos + 1;
    if nDifferences(i) > 0
        thisState = differenceMatrix(:,i)';
        positions = find(thisState)-1;
        values = sma.GlobalTimerEndMatrix(i,thisState)-1;
        posVal = [positions; values];
        posVal = posVal(1:end);
        globalTimerEndMatrix(pos:pos+(nDifferences(i)*2)-1) = posVal;
        pos = pos + nDifferences(i)*2;
    end
end
globalTimerEndMatrix = uint8(globalTimerEndMatrix);

% Compute compressed global counter matrix
differenceMatrix = (sma.GlobalCounterMatrix(:,1:nGlobalCountersUsed) ~= defaultExtensionMatrix_GC)';
nDifferences = sum(differenceMatrix, 1);
msgLength = sum(nDifferences>0)*2 + nStates;
globalCounterMatrix = zeros(1,msgLength); pos = 1;
for i = 1:nStates
    globalCounterMatrix(pos) = nDifferences(i); pos = pos + 1;
    if nDifferences(i) > 0
        thisState = differenceMatrix(:,i)';
        positions = find(thisState)-1;
        values = sma.GlobalCounterMatrix(i,thisState)-1;
        posVal = [positions; values];
        posVal = posVal(1:end);
        globalCounterMatrix(pos:pos+(nDifferences(i)*2)-1) = posVal;
        pos = pos + nDifferences(i)*2;
    end
end
globalCounterMatrix = uint8(globalCounterMatrix);

% Compute compressed condition matrix
differenceMatrix = (sma.ConditionMatrix(:,1:nConditionsUsed) ~= defaultExtensionMatrix_C)';
nDifferences = sum(differenceMatrix,1);
msgLength = sum(nDifferences>0)*2 + nStates;
conditionMatrix = zeros(1,msgLength); pos = 1;
for i = 1:nStates
    conditionMatrix(pos) = nDifferences(i); pos = pos + 1;
    if nDifferences(i) > 0
        thisState = differenceMatrix(:,i)';
        positions = find(thisState)-1;
        values = sma.ConditionMatrix(i,thisState)-1;
        posVal = [positions; values];
        posVal = posVal(1:end);
        conditionMatrix(pos:pos+(nDifferences(i)*2)-1) = posVal;
        pos = pos + nDifferences(i)*2;
    end
end
conditionMatrix = uint8(conditionMatrix);

% Format state timer matrix
stateTimerMatrix = uint8(sma.StateTimerMatrix-1);

% Format global timer, counter and condition properties
conditionChannels = uint8(sma.ConditionChannels(1:nConditionsUsed)-1);
conditionValues = uint8(sma.ConditionValues(1:nConditionsUsed));
globalTimerChannels = uint8(sma.GlobalTimers.OutputChannel(1:nGlobalTimersUsed)-1);
uartChannels = globalTimerChannels < BpodSystem.HW.Pos.Input_USB-1;
globalTimerOnMessages = sma.GlobalTimers.OnMessage(1:nGlobalTimersUsed);
globalTimerOnMessages(globalTimerOnMessages==0 & uartChannels) = 255;
globalTimerOffMessages = sma.GlobalTimers.OffMessage(1:nGlobalTimersUsed);
globalTimerOffMessages(globalTimerOffMessages==0 & uartChannels) = 255;
globalTimerLoopMode = uint8(sma.GlobalTimers.LoopMode(1:nGlobalTimersUsed));
sendGlobalTimerEvents = uint8(sma.GlobalTimers.SendEvents(1:nGlobalTimersUsed));
globalCounterAttachedEvents = uint8(sma.GlobalCounterEvents(1:nGlobalCountersUsed)-1);
globalCounterThresholds = uint32(sma.GlobalCounterThresholds(1:nGlobalCountersUsed));
if BpodSystem.MachineType == 4 % Global timer on/off messages are 16-bit on state machine 2+
    globalTimerOnMessages = typecast(uint16(globalTimerOnMessages), 'uint8');
    globalTimerOffMessages = typecast(uint16(globalTimerOffMessages), 'uint8');
else
    globalTimerOnMessages = uint8(globalTimerOnMessages);
    globalTimerOffMessages = uint8(globalTimerOffMessages);
end

% Extract and format virtual outputs (global timer trig + cancel, global counter reset)
maxGlobalTimers = BpodSystem.HW.n.GlobalTimers;
if maxGlobalTimers > 16
    globalTimerOnset_Trigger = uint32(sma.GlobalTimers.TimerOn_Trigger(1:nGlobalTimersUsed));
    globalTimerTrigs = uint32(sma.OutputMatrix(:,BpodSystem.HW.Pos.GlobalTimerTrig))';
    globalTimerCancels = uint32(sma.OutputMatrix(:,BpodSystem.HW.Pos.GlobalTimerCancel))';
elseif maxGlobalTimers > 8
    globalTimerOnset_Trigger = uint16(sma.GlobalTimers.TimerOn_Trigger(1:nGlobalTimersUsed));
    globalTimerTrigs = uint16(sma.OutputMatrix(:,BpodSystem.HW.Pos.GlobalTimerTrig))';
    globalTimerCancels = uint16(sma.OutputMatrix(:,BpodSystem.HW.Pos.GlobalTimerCancel))';
else
    globalTimerOnset_Trigger = uint8(sma.GlobalTimers.TimerOn_Trigger(1:nGlobalTimersUsed));
    globalTimerTrigs = uint8(sma.OutputMatrix(:,BpodSystem.HW.Pos.GlobalTimerTrig))';
    globalTimerCancels = uint8(sma.OutputMatrix(:,BpodSystem.HW.Pos.GlobalTimerCancel))';
end
if BpodSystem.FirmwareVersion < 23
    globalCounterResets = uint8(sma.OutputMatrix(:,BpodSystem.HW.Pos.GlobalCounterReset))';
else
    gcResets = uint8(sma.OutputMatrix(:,BpodSystem.HW.Pos.GlobalCounterReset))';
    gcOverrides = find(gcResets ~= 0);
    nOverrides = length(gcOverrides);
    outMatrix = [];
    if nOverrides > 0 
        outMatrix = [gcOverrides-1; gcResets(gcOverrides)];
    end
    if nOverrides == 1
        globalCounterResets = [nOverrides outMatrix'];
    else 
        globalCounterResets = [nOverrides outMatrix(1:end)];
    end
end

% Extract and format Flex I/O analog input event matrix and threshold configuration
analogThreshEnable = [];
analogThreshDisable = [];
if BpodSystem.MachineType == 4
    atEnable = uint8(sma.OutputMatrix(:,BpodSystem.HW.Pos.AnalogThreshEnable))'; 
               % Bits indicate thresholds to enable (zeros are not disabled)
    atOverrides = find(atEnable ~= 0);
    nOverrides = length(atOverrides);
    outMatrix = [];
    if nOverrides > 0 
        outMatrix = [atOverrides-1; atEnable(atOverrides)];
    end
    if length(outMatrix) == 2
        outMatrix = outMatrix';
    end
    analogThreshEnable = [nOverrides outMatrix(1:end)]; 
    
    atDisable = uint8(sma.OutputMatrix(:,BpodSystem.HW.Pos.AnalogThreshDisable))'; 
                % Bits indicate thresholds to disable (zeros are not enabled)
    atOverrides = find(atDisable ~= 0);
    nOverrides = length(atOverrides);
    outMatrix = [];
    if nOverrides > 0 
        outMatrix = [atOverrides-1; atDisable(atOverrides)];
    end
    if length(outMatrix) == 2
        outMatrix = outMatrix';
    end
    analogThreshDisable = [nOverrides outMatrix(1:end)];
end

% Format timers (initially double type, unit=seconds) into 32 bit int, unit = multiple of the state machine cycle period
stateTimers = uint32(sma.StateTimers*BpodSystem.HW.CycleFrequency);
globalTimers = uint32(sma.GlobalTimers.Duration(1:nGlobalTimersUsed)*BpodSystem.HW.CycleFrequency);
globalTimerDelays = uint32(sma.GlobalTimers.OnsetDelay(1:nGlobalTimersUsed)*BpodSystem.HW.CycleFrequency);
globalTimerLoopIntervals = uint32(sma.GlobalTimers.LoopInterval(1:nGlobalTimersUsed)*BpodSystem.HW.CycleFrequency);

% Assemble vectors of 8-bit, 16-bit and 32-bit data
eightBitMatrix = [nStates nGlobalTimersUsed nGlobalCountersUsed nConditionsUsed...
    stateTimerMatrix inputMatrix outputMatrix globalTimerStartMatrix globalTimerEndMatrix...
    globalCounterMatrix conditionMatrix globalTimerChannels globalTimerOnMessages...
    globalTimerOffMessages globalTimerLoopMode sendGlobalTimerEvents...
    globalCounterAttachedEvents conditionChannels conditionValues globalCounterResets analogThreshEnable analogThreshDisable];
globalTimerMatrix = [globalTimerTrigs globalTimerCancels globalTimerOnset_Trigger];
thirtyTwoBitMatrix = [stateTimers globalTimers globalTimerDelays globalTimerLoopIntervals globalCounterThresholds];

% Set additional ops packaged with state machine description (e.g. programming serial message library)
containsAdditionalOps = [];
finalAdditionalOps = [];
if BpodSystem.FirmwareVersion > 22 
    containsAdditionalOps = uint8(1);
    finalAdditionalOps = uint8(0);
end

% This section can be optimized for speed (currently should take ~0.5ms per module for most tasks)
% Create serial message vector (if using implicit serial messages)
serialMessageVector = []; nModulesLoaded = 0;
if sma.SerialMessageMode == 1
    for i = 1:BpodSystem.HW.n.UartSerialChannels
        if sma.nSerialMessages(i) > 0
            serialMessageVector = [serialMessageVector containsAdditionalOps 'L' i-1 sma.nSerialMessages(i)];
            for j = 1:sma.nSerialMessages(i)
                thisMessage = sma.SerialMessages{i,j};
                serialMessageVector = [serialMessageVector j length(thisMessage) thisMessage];
            end
            nModulesLoaded = nModulesLoaded + 1;
        end
    end
    serialMessageVector = uint8(serialMessageVector);
end

% Send state machine description to Bpod State Machine device
if BpodSystem.EmulatorMode == 0
    if BpodSystem.FirmwareVersion > 22 % Package ops with byte string
        byteString = [eightBitMatrix typecast(globalTimerMatrix, 'uint8') typecast(thirtyTwoBitMatrix, 'uint8')... 
                      serialMessageVector finalAdditionalOps];
    else
        byteString = [eightBitMatrix typecast(globalTimerMatrix, 'uint8') typecast(thirtyTwoBitMatrix, 'uint8')];
    end
    nBytes = uint16(length(byteString));
    if BpodSystem.Status.InStateMatrix == 1 % If loading during a trial
        if sma.SerialMessageMode == 0 || BpodSystem.FirmwareVersion > 22
            switch BpodSystem.MachineType
                case 1
                    error(['Error: Bpod 0.5 cannot send a state machine while a trial is in progress. '...
                           'If you need this functionality, consider switching to Bpod 0.7+'])
                case 2
                    BpodSystem.SerialPort.write(['C' runASAP use255BackSignal], 'uint8', nBytes, 'uint16');
                    for i = 1:length(byteString)
                        BpodSystem.SerialPort.write(byteString(i), 'uint8'); % send byte-wise, to avoid HW timer overrun
                    end
                case 3
                    BpodSystem.SerialPort.write(['C' runASAP use255BackSignal typecast(nBytes, 'uint8') byteString], 'uint8');
                case 4
                    BpodSystem.SerialPort.write(['C' runASAP use255BackSignal typecast(nBytes, 'uint8') byteString], 'uint8');
            end
        else
            error(['Error: On state machine firmware v22 and older, TrialManager does not support state machine descriptions that' ...
                   char(10) 'use implicit serial messages (e.g. {''MyModule1'', [''A'' 1 2]}.' char(10)...
                   'Use LoadSerialMessages() to program them explicitly, or upgrade to firmware v23+.'])
        end
    else
        BpodSystem.SerialPort.write(['C' runASAP use255BackSignal typecast(nBytes, 'uint8') byteString], 'uint8');
        if BpodSystem.FirmwareVersion < 23
            if sma.SerialMessageMode == 1 % If SerialMessage Library was updated due to implicit programming
                % in state machine syntax, current firmware returns an acknowledgement byte which must be read here
                % to avoid conflicts with subsequent commands. A future firmware update will read this byte after
                % the next trial starts, to avoid the speed penalty of a read during dead-time (see comment below)
                BpodSystem.SerialPort.write(serialMessageVector, 'uint8');
                ack = BpodSystem.SerialPort.read(nModulesLoaded, 'uint8');
            end
        end
    end
    
    
    BpodSystem.Status.NewStateMachineSent = 1; % On next run, a byte is returned confirming that the state machine was received.
    BpodSystem.Status.SM2runASAP = runASAP;
    % Note: depricated confirmation. To reduce dead time when SerialMessageMode = 0, 
    %       transmission is confirmed on next call to RunStateMachine()
    confirmed = 1;
else % In emulator mode, the state machine is not actually sent to a device.
    confirmed = 1;
end

BpodSystem.StateMatrixSent = sma;