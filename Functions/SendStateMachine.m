%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2019 Sanworks LLC, Stony Brook, New York, USA

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
function Confirmed = SendStateMachine(sma, varargin)
global BpodSystem
runASAP = 0; % Byte (set to 0 or 1) indicating whether to auto-run the state matrix as soon as the current one finishes
if nargin > 1
    runImmediately = varargin{1};
    if strcmp(runImmediately, 'RunASAP')
        runASAP = 1;
    else
        error(['Error: ' runImmediately ' is not a valid argument for SendStateMachine.'])
    end
end
use255BackSignal = sma.meta.use255BackSignal;
if sum(BpodSystem.Modules.RelayActive) > 0
    BpodSystem.StopModuleRelay();
end
nStates = length(sma.StateNames);
%% Check to make sure the Placeholder state was replaced
if strcmp(sma.StateNames{1},'Placeholder')
    error('Error: could not send an empty matrix. You must define at least one state first.')
end

%% Check to make sure the State Machine doesn't have undefined states
if sum(sma.StatesDefined == 0) > 0
    disp('Error: The state machine contains references to the following undefined states: ');
    UndefinedStates = find(sma.StatesDefined == 0);
    nUndefinedStates = length(UndefinedStates);
    undefinedStateNames = cell(1,nUndefinedStates);
    for x = 1:nUndefinedStates
        undefinedStateNames{x} = [sma.StateNames{UndefinedStates(x)} ' '];
    end
    error(['Please define the following states using the AddState function before sending the state machine: ' cell2mat(undefinedStateNames)])
end

%% Check to make sure the state matrix does not exceed the maximum number of states
MaxStates = BpodSystem.StateMachineInfo.MaxStates;
if sma.meta.use255BackSignal
    MaxStates = MaxStates - 1;
end
if nStates > MaxStates
    error(['Error: the current state matrix can have a maximum of ' num2str(MaxStates) ' states.'])
end

%% Check to make sure sync line is not used
if BpodSystem.SyncConfig.Channel ~= 255
    SyncChanOutputStates = sma.OutputMatrix(:,BpodSystem.SyncConfig.Channel+1) > 0;
    if (sum(SyncChanOutputStates) > 0) > 0
        ProblemStateNames = sma.StateNames(SyncChanOutputStates);
        nProblemStates = length(ProblemStateNames);
        ErrorMessage = ('Error: The sync channel cannot simultaneously be used as a state machine output.');
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
%% Rearrange states to reflect order they were added (not referenced)
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

%% Add >exit and >back state codes to transition matrices
ExitState = nStates+1; % nStates+1 is the state machine's op code for the exit state
BackState = 256; % IF >back is used in the SM, 255 (as 256 here) is the state machine's op code for returning to the previous state
sma.InputMatrix(sma.InputMatrix == 65537) = ExitState; % 65537 is the assembler's op code for the >exit op
sma.StateTimerMatrix(sma.StateTimerMatrix == 65537) = ExitState;
sma.GlobalTimerStartMatrix(sma.GlobalTimerStartMatrix == 65537) = ExitState;
sma.GlobalTimerEndMatrix(sma.GlobalTimerEndMatrix == 65537) = ExitState;
sma.GlobalCounterMatrix(sma.GlobalCounterMatrix == 65537) = ExitState;
sma.ConditionMatrix(sma.ConditionMatrix == 65537) = ExitState;
sma.InputMatrix(sma.InputMatrix == 65538) = BackState; % 65538 is the assembler's op code for the >back op
sma.StateTimerMatrix(sma.StateTimerMatrix == 65538) = BackState;
sma.GlobalTimerStartMatrix(sma.GlobalTimerStartMatrix == 65538) = BackState;
sma.GlobalTimerEndMatrix(sma.GlobalTimerEndMatrix == 65538) = BackState;
sma.GlobalCounterMatrix(sma.GlobalCounterMatrix == 65538) = BackState;
sma.ConditionMatrix(sma.ConditionMatrix == 65538) = BackState;

%% Determine number of global timers, global counters and conditions used
nGlobalTimersUsed = find(sma.GlobalTimers.IsSet, 1, 'last');
nGlobalCountersUsed = find(sma.GlobalCounterSet, 1, 'last');
nConditionsUsed = find(sma.ConditionSet, 1, 'last');
if isempty(nGlobalTimersUsed); nGlobalTimersUsed = 0; end
if isempty(nGlobalCountersUsed); nGlobalCountersUsed = 0; end
if isempty(nConditionsUsed); nConditionsUsed = 0; end

%% Format input, output and wave matrices into linear byte vectors for transfer
DefaultInputMatrix = repmat((1:nStates)', 1, sma.meta.InputMatrixSize);
DefaultExtensionMatrix_GT = DefaultInputMatrix(1:nStates, 1:nGlobalTimersUsed);
DefaultExtensionMatrix_GC = DefaultInputMatrix(1:nStates, 1:nGlobalCountersUsed);
DefaultExtensionMatrix_C = DefaultInputMatrix(1:nStates, 1:nConditionsUsed);

DifferenceMatrix = (sma.InputMatrix ~= DefaultInputMatrix)';
nDifferences = sum(DifferenceMatrix);
msgLength = sum(nDifferences>0)*2 + nStates;
InputMatrix = zeros(1,msgLength); Pos = 1;
for i = 1:nStates
    InputMatrix(Pos) = nDifferences(i); Pos = Pos + 1;
    if nDifferences(i) > 0
        ThisState = DifferenceMatrix(:,i)';
        Positions = find(ThisState)-1;
        Values = sma.InputMatrix(i,ThisState)-1;
        PosVal = [Positions; Values];
        PosVal = PosVal(1:end);
        InputMatrix(Pos:Pos+(nDifferences(i)*2)-1) = PosVal;
        Pos = Pos + nDifferences(i)*2;
    end
end
InputMatrix = uint8(InputMatrix);

OutputMatrixRaw = sma.OutputMatrix(:, 1:BpodSystem.HW.Pos.GlobalTimerTrig-1); % All except for virtual triggers

DifferenceMatrix = (OutputMatrixRaw ~= 0)';
nDifferences = sum(DifferenceMatrix, 1);
msgLength = sum(nDifferences>0)*2 + nStates;
OutputMatrix = zeros(1,msgLength); Pos = 1;
for i = 1:nStates    
    OutputMatrix(Pos) = nDifferences(i); Pos = Pos + 1;
    if nDifferences(i) > 0
        ThisState = DifferenceMatrix(:,i)';
        Positions = find(ThisState)-1;
        Values = OutputMatrixRaw(i,ThisState);
        PosVal = [Positions; Values];
        PosVal = PosVal(1:end);
        OutputMatrix(Pos:Pos+(nDifferences(i)*2)-1) = PosVal;
        Pos = Pos + nDifferences(i)*2;
    end
end
OutputMatrix = uint8(OutputMatrix);

DifferenceMatrix = (sma.GlobalTimerStartMatrix(:,1:nGlobalTimersUsed) ~= DefaultExtensionMatrix_GT)';
nDifferences = sum(DifferenceMatrix, 1);
msgLength = sum(nDifferences>0)*2 + nStates;
GlobalTimerStartMatrix = zeros(1,msgLength); Pos = 1;
for i = 1:nStates
    GlobalTimerStartMatrix(Pos) = nDifferences(i); Pos = Pos + 1;
    if nDifferences(i) > 0
        ThisState = DifferenceMatrix(:,i)';
        Positions = find(ThisState)-1;
        Values = sma.GlobalTimerStartMatrix(i,ThisState)-1;
        PosVal = [Positions; Values];
        PosVal = PosVal(1:end);
        GlobalTimerStartMatrix(Pos:Pos+(nDifferences(i)*2)-1) = PosVal;
        Pos = Pos + nDifferences(i)*2;
    end
end
GlobalTimerStartMatrix = uint8(GlobalTimerStartMatrix);

DifferenceMatrix = (sma.GlobalTimerEndMatrix(:,1:nGlobalTimersUsed) ~= DefaultExtensionMatrix_GT)';
nDifferences = sum(DifferenceMatrix, 1);
msgLength = sum(nDifferences>0)*2 + nStates;
GlobalTimerEndMatrix = zeros(1,msgLength); Pos = 1;
for i = 1:nStates
    GlobalTimerEndMatrix(Pos) = nDifferences(i); Pos = Pos + 1;
    if nDifferences(i) > 0
        ThisState = DifferenceMatrix(:,i)';
        Positions = find(ThisState)-1;
        Values = sma.GlobalTimerEndMatrix(i,ThisState)-1;
        PosVal = [Positions; Values];
        PosVal = PosVal(1:end);
        GlobalTimerEndMatrix(Pos:Pos+(nDifferences(i)*2)-1) = PosVal;
        Pos = Pos + nDifferences(i)*2;
    end
end
GlobalTimerEndMatrix = uint8(GlobalTimerEndMatrix);

DifferenceMatrix = (sma.GlobalCounterMatrix(:,1:nGlobalCountersUsed) ~= DefaultExtensionMatrix_GC)';
nDifferences = sum(DifferenceMatrix, 1);
msgLength = sum(nDifferences>0)*2 + nStates;
GlobalCounterMatrix = zeros(1,msgLength); Pos = 1;
for i = 1:nStates
    GlobalCounterMatrix(Pos) = nDifferences(i); Pos = Pos + 1;
    if nDifferences(i) > 0
        ThisState = DifferenceMatrix(:,i)';
        Positions = find(ThisState)-1;
        Values = sma.GlobalCounterMatrix(i,ThisState)-1;
        PosVal = [Positions; Values];
        PosVal = PosVal(1:end);
        GlobalCounterMatrix(Pos:Pos+(nDifferences(i)*2)-1) = PosVal;
        Pos = Pos + nDifferences(i)*2;
    end
end
GlobalCounterMatrix = uint8(GlobalCounterMatrix);

DifferenceMatrix = (sma.ConditionMatrix(:,1:nConditionsUsed) ~= DefaultExtensionMatrix_C)';
nDifferences = sum(DifferenceMatrix,1);
msgLength = sum(nDifferences>0)*2 + nStates;
ConditionMatrix = zeros(1,msgLength); Pos = 1;
for i = 1:nStates
    ConditionMatrix(Pos) = nDifferences(i); Pos = Pos + 1;
    if nDifferences(i) > 0
        ThisState = DifferenceMatrix(:,i)';
        Positions = find(ThisState)-1;
        Values = sma.ConditionMatrix(i,ThisState)-1;
        PosVal = [Positions; Values];
        PosVal = PosVal(1:end);
        ConditionMatrix(Pos:Pos+(nDifferences(i)*2)-1) = PosVal;
        Pos = Pos + nDifferences(i)*2;
    end
end
ConditionMatrix = uint8(ConditionMatrix);
StateTimerMatrix = uint8(sma.StateTimerMatrix-1);
ConditionChannels = uint8(sma.ConditionChannels(1:nConditionsUsed)-1);
ConditionValues = uint8(sma.ConditionValues(1:nConditionsUsed));
GlobalTimerChannels = uint8(sma.GlobalTimers.OutputChannel(1:nGlobalTimersUsed)-1);
GlobalTimerOnMessages = sma.GlobalTimers.OnMessage(1:nGlobalTimersUsed);
GlobalTimerOnMessages(GlobalTimerOnMessages==0) = 255;
GlobalTimerOnMessages = uint8(GlobalTimerOnMessages);
GlobalTimerOffMessages = sma.GlobalTimers.OffMessage(1:nGlobalTimersUsed);
GlobalTimerOffMessages(GlobalTimerOffMessages==0) = 255;
GlobalTimerOffMessages = uint8(GlobalTimerOffMessages);
GlobalTimerLoopMode = uint8(sma.GlobalTimers.LoopMode(1:nGlobalTimersUsed));
SendGlobalTimerEvents = uint8(sma.GlobalTimers.SendEvents(1:nGlobalTimersUsed));
GlobalCounterAttachedEvents = uint8(sma.GlobalCounterEvents(1:nGlobalCountersUsed)-1);
GlobalCounterThresholds = uint32(sma.GlobalCounterThresholds(1:nGlobalCountersUsed));

%% Extract and format virtual outputs (global timer trig + cancel, global counter reset)
maxGlobalTimers = BpodSystem.HW.n.GlobalTimers;
if maxGlobalTimers > 16
    GlobalTimerOnset_Trigger = uint32(sma.GlobalTimers.TimerOn_Trigger(1:nGlobalTimersUsed));
    GlobalTimerTrigs = uint32(sma.OutputMatrix(:,BpodSystem.HW.Pos.GlobalTimerTrig))';
    GlobalTimerCancels = uint32(sma.OutputMatrix(:,BpodSystem.HW.Pos.GlobalTimerCancel))';
    GTbytes = 4;
elseif maxGlobalTimers > 8
    GlobalTimerOnset_Trigger = uint16(sma.GlobalTimers.TimerOn_Trigger(1:nGlobalTimersUsed));
    GlobalTimerTrigs = uint16(sma.OutputMatrix(:,BpodSystem.HW.Pos.GlobalTimerTrig))';
    GlobalTimerCancels = uint16(sma.OutputMatrix(:,BpodSystem.HW.Pos.GlobalTimerCancel))';
    GTbytes = 2;
else
    GlobalTimerOnset_Trigger = uint8(sma.GlobalTimers.TimerOn_Trigger(1:nGlobalTimersUsed));
    GlobalTimerTrigs = uint8(sma.OutputMatrix(:,BpodSystem.HW.Pos.GlobalTimerTrig))';
    GlobalTimerCancels = uint8(sma.OutputMatrix(:,BpodSystem.HW.Pos.GlobalTimerCancel))';
    GTbytes = 1;
end

GlobalCounterResets = uint8(sma.OutputMatrix(:,BpodSystem.HW.Pos.GlobalCounterReset))';

%% Format timers (doubles in seconds) into 32 bit int vectors
StateTimers = uint32(sma.StateTimers*BpodSystem.HW.CycleFrequency);
GlobalTimers = uint32(sma.GlobalTimers.Duration(1:nGlobalTimersUsed)*BpodSystem.HW.CycleFrequency);
GlobalTimerDelays = uint32(sma.GlobalTimers.OnsetDelay(1:nGlobalTimersUsed)*BpodSystem.HW.CycleFrequency);
GlobalTimerLoopIntervals = uint32(sma.GlobalTimers.LoopInterval(1:nGlobalTimersUsed)*BpodSystem.HW.CycleFrequency);
%% Add input channel configuration
%InputChannelConfig = [BpodSystem.InputsEnabled.PortsEnabled];

%% Create vectors of 8-bit, 16-bit and 32-bit data

EightBitMatrix = [nStates nGlobalTimersUsed nGlobalCountersUsed nConditionsUsed...
    StateTimerMatrix InputMatrix OutputMatrix GlobalTimerStartMatrix GlobalTimerEndMatrix...
    GlobalCounterMatrix ConditionMatrix GlobalTimerChannels GlobalTimerOnMessages...
    GlobalTimerOffMessages GlobalTimerLoopMode SendGlobalTimerEvents...
    GlobalCounterAttachedEvents ConditionChannels ConditionValues GlobalCounterResets];
GlobalTimerMatrix = [GlobalTimerTrigs GlobalTimerCancels GlobalTimerOnset_Trigger];
ThirtyTwoBitMatrix = [StateTimers GlobalTimers GlobalTimerDelays GlobalTimerLoopIntervals GlobalCounterThresholds];
nBytes = uint16(length(EightBitMatrix) + GTbytes*length(GlobalTimerMatrix) + 4*length(ThirtyTwoBitMatrix)); % Number of bytes in state matrix (excluding nStates byte)

%% Create serial message vector (if using implicit serial messages)
SerialMessageVector = []; nModulesLoaded = 0;
if sma.SerialMessageMode == 1
    for i = 1:BpodSystem.HW.n.UartSerialChannels
        if sma.nSerialMessages(i) > 0
            SerialMessageVector = [SerialMessageVector 'L' i-1 sma.nSerialMessages(i)];
            for j = 1:sma.nSerialMessages(i)
                ThisMessage = sma.SerialMessages{i,j};
                SerialMessageVector = [SerialMessageVector j length(ThisMessage) ThisMessage];
            end
            nModulesLoaded = nModulesLoaded + 1;
        end
    end
    SerialMessageVector = uint8(SerialMessageVector);
end

if BpodSystem.EmulatorMode == 0
    %% Send state matrix to Bpod device
    ByteString = [EightBitMatrix typecast(GlobalTimerMatrix, 'uint8') typecast(ThirtyTwoBitMatrix, 'uint8')];
    if BpodSystem.Status.InStateMatrix == 1 % If loading during a trial
        if sma.SerialMessageMode == 0
            switch BpodSystem.MachineType
                case 1
                    error('Error: Bpod 0.5 cannot send a state machine while a trial is in progress. If you need this functionality, consider switching to Bpod 0.7+')
                case 2
                    BpodSystem.SerialPort.write(['C' runASAP use255BackSignal], 'uint8', nBytes, 'uint16');
                    for i = 1:length(ByteString)
                        BpodSystem.SerialPort.write(ByteString(i), 'uint8'); % send byte-wise, to avoid HW timer overrun
                    end
                case 3
                    BpodSystem.SerialPort.write(['C' runASAP use255BackSignal typecast(nBytes, 'uint8') ByteString], 'uint8');
                case 4
                    BpodSystem.SerialPort.write(['C' runASAP use255BackSignal typecast(nBytes, 'uint8') ByteString], 'uint8');
            end
        else
            error(['Error: TrialManager does not support state machine descriptions that' char(10)...
                'use implicit serial messages (e.g. {''MyModule1'', [''A'' 1 2]}.' char(10)...
                'Use LoadSerialMessages() to program them explicitly, or rewrite your protocol without using TrialManager.'])
        end
    else
        BpodSystem.SerialPort.write(['C' runASAP use255BackSignal typecast(nBytes, 'uint8') ByteString], 'uint8');
        if sma.SerialMessageMode == 1 % If SerialMessage Library was updated due to implicit programming
            % in state machine syntax, current firmware returns an acknowledgement byte which must be read here
            % to avoid conflicts with subsequent commands. A future firmware update will read this byte after 
            % the next trial starts, to avoid the speed penalty of a read during dead-time (see comment below)
            BpodSystem.SerialPort.write(SerialMessageVector, 'uint8');
            Ack = BpodSystem.SerialPort.read(nModulesLoaded, 'uint8');
        end
    end
    
    %% Confirm send. Note: To reduce dead time when SerialMessageMode = 0, transmission is confirmed from 
    %  state machine after next call to RunStateMachine()
    BpodSystem.Status.NewStateMachineSent = 1; % On next run, a byte is returned confirming that the state machine was received.
    BpodSystem.Status.SM2runASAP = runASAP;
    Confirmed = 1;
else
    Confirmed = 1;
end
%% Update State Machine Object
BpodSystem.StateMatrixSent = sma;