%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Sound Beach, New York, USA

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
RunMessage = []; % If 'RunImmediately' argument is provided, 'R' gets appended to the state machine serial message
if nargin > 1
    runImmediately = varargin{1};
    if strcmp(runImmediately, 'RunImmediately')
        RunMessage = 'R';
    end
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
if nStates > BpodSystem.StateMachineInfo.MaxStates
    error(['Error: the state matrix can have a maximum of ' num2str(BpodSystem.StateMachineInfo.MaxStates) ' states.'])
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
    sma.InputMatrix(OriginalInputMatrix==StateOrder(i)) = i;
    sma.StateTimerMatrix(OriginalStateTimerMatrix==StateOrder(i)) = i;
    sma.GlobalTimerStartMatrix(OriginalTimerStartMatrix==StateOrder(i)) = i;
    sma.GlobalTimerEndMatrix(OriginalTimerEndMatrix==StateOrder(i)) = i;
    sma.GlobalCounterMatrix(OriginalCounterMatrix==StateOrder(i)) = i;
    sma.ConditionMatrix(OriginalConditionMatrix==StateOrder(i)) = i;
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

%% Add exit state codes to transition matrices
ExitState = nStates+1;
sma.InputMatrix(isnan(sma.InputMatrix)) = ExitState;
sma.StateTimerMatrix(isnan(sma.StateTimerMatrix)) = ExitState;
sma.GlobalTimerStartMatrix(isnan(sma.GlobalTimerStartMatrix)) = ExitState;
sma.GlobalTimerEndMatrix(isnan(sma.GlobalTimerEndMatrix)) = ExitState;
sma.GlobalCounterMatrix(isnan(sma.GlobalCounterMatrix)) = ExitState;
sma.ConditionMatrix(isnan(sma.ConditionMatrix)) = ExitState;

%% Format input, output and wave matrices into linear byte vectors for transfer
DefaultInputMatrix = repmat((1:nStates)', 1, sma.meta.InputMatrixSize);
DefaultExtensionMatrix = DefaultInputMatrix(1:nStates, 1:5);

DifferenceMatrix = (sma.InputMatrix ~= DefaultInputMatrix)';
nDifferences = sum(DifferenceMatrix);
msgLength = sum(nDifferences>0)*2 + nStates;
InputMatrix = zeros(1,msgLength); Pos = 1;
for i = 1:nStates
    ThisState = DifferenceMatrix(:,i)';
    InputMatrix(Pos) = nDifferences(i); Pos = Pos + 1;
    if nDifferences(i) > 0
        Positions = find(ThisState)-1;
        Values = sma.InputMatrix(i,ThisState)-1;
        PosVal = [Positions; Values];
        PosVal = PosVal(1:end);
        InputMatrix(Pos:Pos+(nDifferences(i)*2)-1) = PosVal;
        Pos = Pos + nDifferences(i)*2;
    end
end
InputMatrix = uint8(InputMatrix);

DifferenceMatrix = (sma.OutputMatrix ~= 0)';
nDifferences = sum(DifferenceMatrix);
msgLength = sum(nDifferences>0)*2 + nStates;
OutputMatrix = zeros(1,msgLength); Pos = 1;
for i = 1:nStates
    ThisState = DifferenceMatrix(:,i)';
    OutputMatrix(Pos) = nDifferences(i); Pos = Pos + 1;
    if nDifferences(i) > 0
        Positions = find(ThisState)-1;
        Values = sma.OutputMatrix(i,ThisState);
        PosVal = [Positions; Values];
        PosVal = PosVal(1:end);
        OutputMatrix(Pos:Pos+(nDifferences(i)*2)-1) = PosVal;
        Pos = Pos + nDifferences(i)*2;
    end
end
OutputMatrix = uint8(OutputMatrix);

DifferenceMatrix = (sma.GlobalTimerStartMatrix ~= DefaultExtensionMatrix)';
nDifferences = sum(DifferenceMatrix);
msgLength = sum(nDifferences>0)*2 + nStates;
GlobalTimerStartMatrix = zeros(1,msgLength); Pos = 1;
for i = 1:nStates
    ThisState = DifferenceMatrix(:,i)';
    GlobalTimerStartMatrix(Pos) = nDifferences(i); Pos = Pos + 1;
    if nDifferences(i) > 0
        Positions = find(ThisState)-1;
        Values = sma.GlobalTimerStartMatrix(i,ThisState)-1;
        PosVal = [Positions; Values];
        PosVal = PosVal(1:end);
        GlobalTimerStartMatrix(Pos:Pos+(nDifferences(i)*2)-1) = PosVal;
        Pos = Pos + nDifferences(i)*2;
    end
end
GlobalTimerStartMatrix = uint8(GlobalTimerStartMatrix);

DifferenceMatrix = (sma.GlobalTimerEndMatrix ~= DefaultExtensionMatrix)';
nDifferences = sum(DifferenceMatrix);
msgLength = sum(nDifferences>0)*2 + nStates;
GlobalTimerEndMatrix = zeros(1,msgLength); Pos = 1;
for i = 1:nStates
    ThisState = DifferenceMatrix(:,i)';
    GlobalTimerEndMatrix(Pos) = nDifferences(i); Pos = Pos + 1;
    if nDifferences(i) > 0
        Positions = find(ThisState)-1;
        Values = sma.GlobalTimerEndMatrix(i,ThisState)-1;
        PosVal = [Positions; Values];
        PosVal = PosVal(1:end);
        GlobalTimerEndMatrix(Pos:Pos+(nDifferences(i)*2)-1) = PosVal;
        Pos = Pos + nDifferences(i)*2;
    end
end
GlobalTimerEndMatrix = uint8(GlobalTimerEndMatrix);

DifferenceMatrix = (sma.GlobalCounterMatrix ~= DefaultExtensionMatrix)';
nDifferences = sum(DifferenceMatrix);
msgLength = sum(nDifferences>0)*2 + nStates;
GlobalCounterMatrix = zeros(1,msgLength); Pos = 1;
for i = 1:nStates
    ThisState = DifferenceMatrix(:,i)';
    GlobalCounterMatrix(Pos) = nDifferences(i); Pos = Pos + 1;
    if nDifferences(i) > 0
        Positions = find(ThisState)-1;
        Values = sma.GlobalCounterMatrix(i,ThisState)-1;
        PosVal = [Positions; Values];
        PosVal = PosVal(1:end);
        GlobalCounterMatrix(Pos:Pos+(nDifferences(i)*2)-1) = PosVal;
        Pos = Pos + nDifferences(i)*2;
    end
end
GlobalCounterMatrix = uint8(GlobalCounterMatrix);

DifferenceMatrix = (sma.ConditionMatrix ~= DefaultExtensionMatrix)';
nDifferences = sum(DifferenceMatrix);
msgLength = sum(nDifferences>0)*2 + nStates;
ConditionMatrix = zeros(1,msgLength); Pos = 1;
for i = 1:nStates
    ThisState = DifferenceMatrix(:,i)';
    ConditionMatrix(Pos) = nDifferences(i); Pos = Pos + 1;
    if nDifferences(i) > 0
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
ConditionChannels = uint8(sma.ConditionChannels-1);
ConditionValues = uint8(sma.ConditionValues);
GlobalTimerChannels = uint8(sma.GlobalTimers.OutputChannel-1);
GlobalTimerOnMessages = sma.GlobalTimers.OnMessage;
GlobalTimerOnMessages(GlobalTimerOnMessages==0) = 255;
GlobalTimerOnMessages = uint8(GlobalTimerOnMessages);
GlobalTimerOffMessages = sma.GlobalTimers.OffMessage;
GlobalTimerOffMessages(GlobalTimerOffMessages==0) = 255;
GlobalTimerOffMessages = uint8(GlobalTimerOffMessages);
GlobalCounterAttachedEvents = uint8(sma.GlobalCounterEvents-1);
GlobalCounterThresholds = uint32(sma.GlobalCounterThresholds);

%% Format timers (doubles in seconds) into 32 bit int vectors
StateTimers = uint32(sma.StateTimers*BpodSystem.HW.CycleFrequency);
GlobalTimers = uint32(sma.GlobalTimers.Duration*BpodSystem.HW.CycleFrequency);
GlobalTimerDelays = uint32(sma.GlobalTimers.OnsetDelay*BpodSystem.HW.CycleFrequency);
%% Add input channel configuration
%InputChannelConfig = [BpodSystem.InputsEnabled.PortsEnabled];

%% Create vectors of 8-bit and 32-bit data

EightBitMatrix = ['C' nStates StateTimerMatrix InputMatrix OutputMatrix GlobalTimerStartMatrix GlobalTimerEndMatrix GlobalCounterMatrix ConditionMatrix GlobalTimerChannels GlobalTimerOnMessages GlobalTimerOffMessages GlobalCounterAttachedEvents ConditionChannels ConditionValues];
ThirtyTwoBitMatrix = [StateTimers GlobalTimers GlobalTimerDelays GlobalCounterThresholds];

if BpodSystem.EmulatorMode == 0
    %% Send state matrix to Bpod device
    ByteString = [EightBitMatrix typecast(ThirtyTwoBitMatrix, 'uint8') RunMessage];
    BpodSystem.SerialPort.write(ByteString, 'uint8');
    
%% Confirm send. Note: To reduce dead time, transmission is confirmed from state machine after next call to RunStateMachine()
    BpodSystem.Status.NewStateMachineSent = 1; % On next run, a byte is returned confirming that the state machine was received.
    Confirmed = 1;
else
    Confirmed = 1;
end
%% Update State Machine Object
BpodSystem.StateMatrix = sma;