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
function ok = sendSM2Bpod(sma, varargin)
global BpodSystem
RunASAP = 0;
if nargin > 1
    if strcmp(varargin{1}, 'RunASAP')
        RunASAP = 1;
    end
end
AudioPlayerOutputCh = find(strcmp(BpodSystem.Modules.Name, 'AudioPlayer1'));
if isempty(AudioPlayerOutputCh)
    AudioPlayerOutputCh = find(strcmp(BpodSystem.Modules.Name, 'HiFi1'));
end
WavePlayerOutputCh = find(strcmp(BpodSystem.Modules.Name, 'WavePlayer1'));
HasAudioPlayer = 0;
if ~isempty(AudioPlayerOutputCh)
    HasAudioPlayer = 1;
end
HasAnalogPlayer = 0;
if ~isempty(WavePlayerOutputCh)
    HasAnalogPlayer = 1;
end

% Identify positions of columns in state matrix
ColLabels = get_col_labels(sma);
ColLabelNames = ColLabels(:,1)';
TupPos = find(strcmp('Tup', ColLabelNames));
TimerPos = find(strcmp('Timer', ColLabelNames));
DoutPos = find(strcmp('DOut', ColLabelNames));
SndoutPos = find(strcmp('SoundOut', ColLabelNames));
GlobalTimerPos = find(strcmp('SchedWaveTrig', ColLabelNames));

% In pre-happenings matrices, extra columns (following ports) are scheduled
% waves. Identify the first and last scheduled wave column.
nColumns = length(ColLabelNames);
WaveStartPos = 0; WaveEndPos = 0; HasNonHappeningWaves = 0;
for i = 1:nColumns
    ThisColLabel = ColLabelNames{i};
    if sum(ThisColLabel(end-2:end) == '_In') == 3
        if WaveStartPos == 0
            WaveStartPos = i;
            HasNonHappeningWaves = 1;
        end
    end
    if length(ThisColLabel) > 3
        if sum(ThisColLabel(end-3:end) == '_Out') == 4
            if i > WaveEndPos
                WaveEndPos = i;
                HasNonHappeningWaves = 1;
            end
        end
    end
end

if HasNonHappeningWaves
    PortEndPos = WaveStartPos - 1;
else
    PortEndPos = TupPos-1;
end

StateMatrix = get_states(sma); StateMatrix = StateMatrix(40:end, :);
[nStates, nCols] = size(StateMatrix);

% Parse labels
Labels = get_labels(sma);
LabelStrings = Labels(:,1)';
nLabels = length(LabelStrings);

LabelStates = cell2mat(Labels(:,2))';
UserStateIndexes = LabelStates > 38;
UserStates = LabelStates(UserStateIndexes);
UserStrings = LabelStrings(UserStateIndexes);
% For states that have no label, auto-generate a label
States = 1:39+nStates;
StateNames = cell(1,length(States));
StateNames(UserStates) = UserStrings;
States2Rename = ~ismember(States, UserStates);
% for i = 39:length(States)
%     if States2Rename(i)
%         StateNames{i} = BpodSystem.PluginObjects.DefaultStateNames{i};
%     end
% end
StateNames(States2Rename) = BpodSystem.PluginObjects.DefaultStateNames(States2Rename);
StateNames = StateNames(39:end);

% Select actual user-defined states and parse columns for mapping
StateMatrix(strcmp('check_next_trial_ready', StateMatrix)) = {nStates+39}; % Set exit states
%StateMatrix(strcmp('final_state', StateMatrix)) = {nStates+40}; % Set exit states
% Replace state names with state numbers
for i = 1:nStates
    if ~strcmp(StateNames{i}, 'check_next_trial_ready')
        StateMatrix(strcmpi(StateNames{i}, StateMatrix)) = {i+38};
    end
    ThisRow = StateMatrix(i,:);
    isString = cellfun(@ischar,ThisRow);
    for j = 1:length(ThisRow)
        if isString(j)
            ThisElement = ThisRow{j};
            [len,wid] = size(ThisElement);
            if wid == 1 && len > 1
                ThisElement = ThisElement';
            end
            ThisElementLength = length(ThisElement);
            if ThisElementLength > 13
                if sum(ThisElement(1:13) == 'current_state') == 13
                    op = ThisElement(14);
                    nStates2Move = str2double(ThisElement(15:end));
                    switch op
                        case '+'
                            destState = i+38+nStates2Move;
                        case '-'
                            destState = i+38-nStates2Move;
                        otherwise
                            error('Error converting B-control state matrix to Bpod: Unsupported current_state motif detected')
                    end
                    StateMatrix(i,j) = {destState};
                end
            elseif ThisElementLength == 13
                if sum(ThisElement == 'current_state') == 13
                    StateMatrix(i,j) = {i+38};
                end
            end
        end
    end
end
if ~isUsingHappenings(sma)
    PortInputMatrix = cell2mat(StateMatrix(:,1:PortEndPos))-38;
end
StateTimerMatrix = cell2mat(StateMatrix(:,TupPos))-38;
Timers = cell2mat(StateMatrix(:,TimerPos));
Dout = cell2mat(StateMatrix(:,DoutPos));
SoundOut = cell2mat(StateMatrix(:,SndoutPos));
StateNames{1} = 'State_0';
% Map B-control Dout to Bpod output matrix columns
DoutBinary = dec2bin(Dout) == '1';
DoutBinary = DoutBinary(:, end:-1:1);
DoutValve = DoutBinary(:, 1:2:end);
DoutLED = DoutBinary(:, 2:2:end);
[nRowsV, nCols] = size(DoutValve);
[nRowsL, nColsL] = size(DoutLED);
ValveMask = 2.^(0:nCols-1);
ValveState = DoutValve * ValveMask';

% Initialize blank Bpod state matrix with correct number of states
bsma = NewStateMachine();

% Future-proof (but *very* slow) way to initialize blank state machine
% for i = 1:nStates
%     bsma = AddState(bsma, 'Name', StateNames{i}, ...
%         'Timer', Timers(i),...
%         'StateChangeConditions', {},...
%         'OutputActions', {});
% end

% Faster way to initialize blank state machine, must be updated as SM structure changes
bsma.nStates = nStates;
bsma.nStatesInManifest = nStates;
bsma.Manifest(1:nStates) = StateNames(1:nStates);
bsma.StateNames = StateNames(1:nStates);
bsma.InputMatrix = repmat((1:nStates)', 1, length(bsma.InputMatrix));
bsma.OutputMatrix = zeros(nStates, length(bsma.OutputMatrix));
bsma.GlobalTimerStartMatrix = repmat((1:nStates)', 1, length(bsma.GlobalTimerStartMatrix));
bsma.GlobalTimerEndMatrix = repmat((1:nStates)', 1, length(bsma.GlobalTimerEndMatrix));
bsma.GlobalCounterMatrix = repmat((1:nStates)', 1, length(bsma.GlobalCounterMatrix));
bsma.ConditionMatrix = repmat((1:nStates)', 1, length(bsma.ConditionMatrix));
bsma.StateTimers = Timers(1:nStates)';
bsma.StatesDefined = ones(1,nStates);
% End faster way to initialize blank state machine
bsma.StateTimers(1) = 0; % Set state 1 timer to 0 (equiv to B-control state 0)

% Copy B-control input matrix (only if not using happenings)
if ~isUsingHappenings(sma)
    bsma.InputMatrix(:,BpodSystem.HW.Pos.Event_Port:BpodSystem.HW.Pos.Event_Port+PortEndPos-1) = PortInputMatrix;
end
bsma.InputMatrix(1,:) = 1; % Clear state 1 events
% Copy B-control state timer matrix
bsma.StateTimerMatrix = StateTimerMatrix';
bsma.StateTimerMatrix(1) = 2; % Set state 1 to move to state 2 on timeup
% Copy valve states (extracted from B-control Dout above)
if sum(BpodSystem.HW.Outputs == 'S') > 0
    bsma.OutputMatrix(:, find(BpodSystem.HW.Outputs == 'S')) = ValveState;
else
    ValvePos = find(BpodSystem.HW.Outputs == 'V',1);
    bsma.OutputMatrix(:, ValvePos:ValvePos+nCols-1) = DoutValve;
end
% Copy port LED states set to maximum intensity (extracted from B-control Dout above)
bsma.OutputMatrix(:, BpodSystem.HW.Pos.Output_PWM:BpodSystem.HW.Pos.Output_PWM+nColsL-1) = DoutLED*255;
% Copy & convert sound triggers
if HasAudioPlayer == 0
    if sum(SoundOut) ~= 0
        error('Error: A Bpod AudioPlayer module is required to run this state matrix, but none is connected.')
    end
else
    if BpodSystem.PluginObjects.SoundServerType == 1
        BpodOutputMatrixCol_Snd = find(strcmp(BpodSystem.StateMachineInfo.OutputChannelNames, 'AudioPlayer1'));
    elseif BpodSystem.PluginObjects.SoundServerType == 2
        BpodOutputMatrixCol_Snd = find(strcmp(BpodSystem.StateMachineInfo.OutputChannelNames, 'HiFi1'));
    end
    nSoundsSupported = BpodSystem.PluginObjects.SoundServer.Info.maxSounds;
    SoundOut(SoundOut < 0) = (SoundOut(SoundOut < 0)*-1)+double(nSoundsSupported); % 1 more than the max number of sounds begins sound-off codes.
    SoundOut(1) = uint8('*'); % State 1 (equiv to state 0) sends a "push" signal to the sound server, to set newly
                              % loaded sounds to the front (playback) buffer
    bsma.OutputMatrix(:,BpodOutputMatrixCol_Snd) = SoundOut;
end

% Initialize event code map in buffer
BpodSystem.PluginObjects.BcontrolEventCodeMapBuffer = zeros(1,BpodSystem.HW.StateTimerPosition); % Happening code for each Bpod event
BpodSystem.PluginObjects.BcontrolEventCodeMapBuffer(BpodSystem.HW.StateTimerPosition) = -1; %B-control code for Tup
if isUsingHappenings(sma)
    hSpec = get_happening_spec(sma);
    hNames = {hSpec(:).name};
    nHappenings = length(hSpec);
end
% Convert scheduled waves -> global timers
BpodOutputMatrixCol_SwTrig = find(strcmp(BpodSystem.StateMachineInfo.OutputChannelNames, 'GlobalTimerTrig'));
BpodOutputMatrixCol_SwCancel = find(strcmp(BpodSystem.StateMachineInfo.OutputChannelNames, 'GlobalTimerCancel'));
SW = get_scheduled_waves(sma);
nWavesDeclared = length(SW);
if nWavesDeclared > BpodSystem.HW.n.GlobalTimers
    error(['Error: A state machine was defined with ' num2str(nWavesDeclared) ' scheduled waves, but your Bpod state machine supports only ' num2str(BpodSystem.HW.n.GlobalTimers) '.'])
end

waveNames = cell(1,nWavesDeclared);
GTStartEventPos = BpodSystem.HW.GlobalTimerStartposition;
GTEndEventPos = GTStartEventPos + BpodSystem.HW.n.GlobalTimers;

for i = 1:nWavesDeclared
    bsma.GlobalTimers.OnsetDelay(i) = SW(i).preamble;
    bsma.GlobalTimers.Duration(i) = SW(i).sustain;
    bsma.GlobalTimers.IsSet(i) = 1;
    waveNames{i} = SW(i).name;
    bsma.GlobalTimers.Names{i} = waveNames{i};
    if SW(i).sound_trig ~= 0
        if HasAudioPlayer
            MaxSounds = BpodSystem.PluginObjects.SoundServer.Info.maxSounds;
            bsma.GlobalTimers.OutputChannel(i) = AudioPlayerOutputCh;
            if SW(i).sound_trig > 0
                bsma.GlobalTimers.OnMessage(i) = SW(i).sound_trig;
                bsma.GlobalTimers.OffMessage(i) = SW(i).sound_trig+MaxSounds; % JS: If sounds are shut off when scheduled waves end.. is this true?
            else
                bsma.GlobalTimers.OnMessage(i) = (SW(i).sound_trig*-1)+MaxSounds;
            end
        else
            error('Error: A Bpod AudioPlayer module is required to run this state matrix, but none is connected.')
        end
    end
    if ~isnan(SW(i).dio_line)
        if SW(i).dio_line ~= -1
            % Map dio CHANNELS to Bpod (no bits)
            bsma.GlobalTimers.OutputChannel(i) = BpodSystem.PluginObjects.Bcontrol2Bpod_DO_Map(SW(i).dio_line+1);
            % Set on and off events for FSM onboard channel type 
            %(Analog and Sound module channels are set separately per module below)
            switch BpodSystem.HW.Outputs(bsma.GlobalTimers.OutputChannel(i))
                case 'P'
                    bsma.GlobalTimers.OnMessage(i) = 255;
                    bsma.GlobalTimers.OffMessage(i) = 0;
                case 'B'
                    bsma.GlobalTimers.OnMessage(i) = 1;
                    bsma.GlobalTimers.OffMessage(i) = 0;
                case 'W'
                    bsma.GlobalTimers.OnMessage(i) = 1;
                    bsma.GlobalTimers.OffMessage(i) = 0;
                case 'V'
                    bsma.GlobalTimers.OnMessage(i) = 1;
                    bsma.GlobalTimers.OffMessage(i) = 0;
            end
        end
    end
    if ~isempty(SW(i).analog_waveform)
        if HasAnalogPlayer
            outputCh = SW(i).ao_line;
            thisWaveform = SW(i).analog_waveform;
            switch BpodSystem.PluginObjects.WavePlayer.OutputRange
                case '0V:5V'
                    thisWaveform = ((thisWaveform+1)/2)*5;
                case '0V:10V'
                    thisWaveform = ((thisWaveform+1)/2)*10;
                case '0V:12V'
                    thisWaveform = ((thisWaveform+1)/2)*12;
                case '-5V:5V'
                    thisWaveform = thisWaveform*5;
                case '-10V:10V'
                    thisWaveform = thisWaveform*10;
                case '-12V:12V'
                    thisWaveform = thisWaveform*12;
            end
            nSamples = length(thisWaveform);
            lastWaveform = BpodSystem.PluginObjects.WavePlayer.Waveforms{outputCh};
            SendWave = 0;
            if isempty(lastWaveform)
                SendWave = 1;
            elseif nSamples ~= length(lastWaveform)
                SendWave = 1;
            else
                if sum(thisWaveform == lastWaveform) ~= nSamples
                    SendWave = 1;
                end
            end
            if SendWave
                nChannels = length(BpodSystem.PluginObjects.WavePlayer.BpodEvents);
               if outputCh <= nChannels
                    BpodSystem.PluginObjects.WavePlayer.loadWaveform(outputCh, thisWaveform);  
               else
                   error(['Error: an analog scheduled wave was set for channel ' num2str(outputCh) ' but only ' num2str(nChannels) ' analog channels are available.'])
               end
            end
            bsma.GlobalTimers.OutputChannel(i) = WavePlayerOutputCh;
            bsma.GlobalTimers.OnMessage(i) = outputCh;
            bsma.GlobalTimers.OffMessage(i) = 'X';
            bsma.GlobalTimers.Duration(i) = nSamples/BpodSystem.PluginObjects.WavePlayer.SamplingRate;
            bsma.GlobalTimers.OnsetDelay(i) = 0; % Override preamble (defaults to 1 second). Comment this line to re-enable preamble for analog waves
        else
            error('Error: A Bpod WavePlayer module is required to run analog scheduled waves in this state matrix, but none is connected.')
        end
    end
    if SW(i).loop ~= 0
            bsma.GlobalTimers.LoopMode(i) = 1;
            bsma.GlobalTimers.LoopInterval(i) = bsma.GlobalTimers.OnsetDelay(i);
        if SW(i).loop > 1
            if SW(i).loop < 256
                bsma.GlobalTimers.LoopMode(i) = SW(i).loop;
            else
                error(['Error: ' num2str(SW(i).loop) ' scheduled wave loops requested. Bpod supports one-shot, infinite, or a fixed number up to 255.'])
            end
        elseif SW(i).loop == 1
            bsma.GlobalTimers.LoopMode(i) = 0;
        end
    end
    if SW(i).trigger_on_up > 0
        bsma.GlobalTimers.TimerOn_Trigger(i) = SW(i).trigger_on_up;
    end
    if SW(i).untrigger_on_down ~= 0
        error('Error: scheduled wave untrigger_on_down is not supported with Bpod.')
    end
    if SW(i).refraction ~= 0
        error('Error: scheduled wave refraction is not supported on Bpod.')
    end
    if isUsingHappenings(sma)
        inHapp = find(strcmp([waveNames{i} '_In'], hNames));
        outHapp = find(strcmp([waveNames{i} '_Out'], hNames));
        if ~isempty(inHapp)
            BpodSystem.PluginObjects.BcontrolEventCodeMapBuffer(i+GTStartEventPos-1) = inHapp;
        end
        if ~isempty(outHapp)
            BpodSystem.PluginObjects.BcontrolEventCodeMapBuffer(i+GTEndEventPos-1) = outHapp;
        end
    end
end
if ~isempty(GlobalTimerPos)
    SchWavTrig = StateMatrix(:,GlobalTimerPos);
    for i = 1:nStates
        [bsma.OutputMatrix(i,BpodOutputMatrixCol_SwTrig), bsma.OutputMatrix(i,BpodOutputMatrixCol_SwCancel)] = parseSchWavTrigger(SchWavTrig{i}, waveNames);
    end
end

% If not using happenings, copy global timer portion of state matrix to global timer start and end matrices
if ~isUsingHappenings(sma)
    if nWavesDeclared > 0
        bsma.GlobalTimerStartMatrix(:, 1:nWavesDeclared) = cell2mat(StateMatrix(:,WaveStartPos:2:WaveEndPos))-38;
        bsma.GlobalTimerEndMatrix(:, 1:nWavesDeclared) = cell2mat(StateMatrix(:,WaveStartPos+1:2:WaveEndPos))-38;
    end
end

% Load Happenings
if isUsingHappenings(sma)
    hFuncNames = {hSpec(:).detectorFunctionName};
    hInputChannels = {hSpec(:).inputNumber};
    hList = get_happening_list(sma);
    hStates = find(~cellfun(@isempty, hList));
    nHappStates = length(hStates);
    nTotalStates = length(hList)-39;
    standardEventsFromSM = ColLabelNames(1:TupPos-1); % Could be used to sanity check procedural standard events (below)
    nLogicInputChannels = length(BpodSystem.PluginObjects.Bcontrol2Bpod_DI_Map);
    standardEvents = cell(1,nLogicInputChannels);
    standardEventPos = 0;
    for i = 1:nLogicInputChannels
        standardEventPos = standardEventPos + 1;
        switch BpodSystem.PluginObjects.Bcontrol2Bpod_DI_Map{i}
            case 'C'
                standardEvents{standardEventPos} = 'Cin';
                standardEventPos = standardEventPos + 1;
                standardEvents{standardEventPos} = 'Cout';
            case 'L'
                standardEvents{standardEventPos} = 'Lin';
                standardEventPos = standardEventPos + 1;
                standardEvents{standardEventPos} = 'Lout';
            case 'R'
                standardEvents{standardEventPos} = 'Rin';
                standardEventPos = standardEventPos + 1;
                standardEvents{standardEventPos} = 'Rout';
        end
    end
    
    nConditionsSet = 0;
    portOffset = BpodSystem.HW.Pos.Event_Port-1;
    % Create happening map and load conditions
    for happ = 1:length(hSpec)
        thisEventColumn = find(strcmp(hNames{happ}, standardEvents));
        if ~isempty(thisEventColumn)
            BpodSystem.PluginObjects.BcontrolEventCodeMapBuffer(thisEventColumn+portOffset) = happ;
        end
    end
    % Set up i/o input matrix + global timer and counter input matrices
    for i = 1:nHappStates
        ThisStateIndex = hStates(i);
        ThisHappening = hList{ThisStateIndex};
        ThisStateNumber = ThisStateIndex - 1;
        nHappeningCells = length(ThisHappening);
        for j = 1:2:nHappeningCells
            ThisEvent = ThisHappening{j};
            ThisHappeningNumber = find(strcmp(ThisEvent, hNames));
            if length(ThisHappeningNumber) > 1
                disp('Warning! Duplicate happening spec detected in Bcontrol -> Bpod SM conversion! Using most recently added happening spec.');
                ThisHappeningNumber = ThisHappeningNumber(end);
            end
            DestinationState = ThisHappening{j+1};
            if DestinationState == 35
                DestinationState = 39+nTotalStates;
            end
            thisEventColumn = find(strcmp(ThisEvent, standardEvents));
            thisConditionNum = find(strcmp(ThisEvent, bsma.ConditionNames));
            if ~isempty(thisEventColumn) % If this happening is a standard event
                bsma.InputMatrix(ThisStateNumber-38, thisEventColumn+portOffset) = DestinationState-38; 
            elseif ~isempty(thisConditionNum)
                bsma.ConditionMatrix(ThisStateNumber-38,thisConditionNum) = DestinationState-38;
                BpodSystem.PluginObjects.BcontrolEventCodeMapBuffer(thisConditionNum+BpodSystem.HW.ConditionStartposition-1) = ThisHappeningNumber;
            else
                switch hFuncNames{ThisHappeningNumber}
                    case 'line_high'
                        bsma = Add_Condition_From_Happening(bsma, ThisStateNumber, DestinationState, ThisHappeningNumber, ThisEvent, 1, hInputChannels, waveNames, 'IO');
                    case 'line_low'
                        bsma = Add_Condition_From_Happening(bsma, ThisStateNumber, DestinationState, ThisHappeningNumber, ThisEvent, 0, hInputChannels, waveNames, 'IO');
                    case 'wave_in'
                        thisWaveName = ThisEvent(1:end-3);
                        waveNum = find(strcmp(thisWaveName, waveNames));
                        if ~isempty(waveNum)
                            bsma.GlobalTimerStartMatrix(ThisStateNumber-38, waveNum) = DestinationState-38;
                        else
                            keyboard
                        end
                    case 'wave_out'
                        thisWaveName = ThisEvent(1:end-4);
                        waveNum = find(strcmp(thisWaveName, waveNames));
                        if ~isempty(waveNum)
                            bsma.GlobalTimerEndMatrix(ThisStateNumber-38, waveNum) = DestinationState-38;
                        else
                            keyboard
                        end
                    case 'wave_high'
                        bsma = Add_Condition_From_Happening(bsma, ThisStateNumber, DestinationState, ThisHappeningNumber, ThisEvent, 1, hInputChannels, waveNames, 'Wave');
                    case 'wave_low'
                        bsma = Add_Condition_From_Happening(bsma, ThisStateNumber, DestinationState, ThisHappeningNumber, ThisEvent, 0, hInputChannels, waveNames, 'Wave');
                end
            end
        end
    end
end

% If not using happenings, set up event code map buffer
if ~isUsingHappenings(sma)
    GTstart = BpodSystem.HW.GlobalTimerStartposition;
    lastDeclaredGT = GTstart+nWavesDeclared-1;
    GTend = BpodSystem.HW.GlobalTimerStartposition + BpodSystem.HW.n.GlobalTimers;
    % Map port events
    BpodSystem.PluginObjects.BcontrolEventCodeMapBuffer(BpodSystem.HW.Pos.Event_Port:GTstart-1) = 1:BpodSystem.HW.n.Ports*2;
    % Map global timer events
    BpodSystem.PluginObjects.BcontrolEventCodeMapBuffer(GTstart:lastDeclaredGT) = WaveStartPos:2:WaveEndPos;
    BpodSystem.PluginObjects.BcontrolEventCodeMapBuffer(GTend:GTend+nWavesDeclared-1) = WaveStartPos+1:2:WaveEndPos;
end
if RunASAP
    ok = SendStateMachine(bsma, 'RunASAP');
    BpodSystem.Status.InStateMatrix = 1;
else
    ok = SendStateMachine(bsma);
end

BpodSystem.StateMatrixSent = bsma;

function [TrigByte, CancelByte] = parseSchWavTrigger(TrigString, waveNames)
TrigByte = 0; CancelByte = 0;
[l,w] = size(TrigString);
if l > w
    TrigString = TrigString';
end
if ischar(TrigString)
    if isempty(TrigString)
        TrigByte = 0; CancelByte = 0;
    else
        Sign = 1;
        NoSpaceIndexes = TrigString ~= ' ';
        TrigString = TrigString(NoSpaceIndexes);
        if TrigString(2) == '('
            if TrigString(end) == ')'
                if TrigString(1) == '-'
                    Sign = -1;
                end
                TrigString = TrigString(3:end-1);
            else
                error(['Error: the Bpod state matrix translator was unable to parse scheduled wave trigger string: ' TrigString])
            end
        end
        Op = TrigString(1);
        if Op ~= '+' && Op ~= '-'
            TrigString = ['+' TrigString];
            Op = '+';
        end
        if Op == '+'
            Ops = (TrigString == '+');
        else
            Ops = (TrigString == '-');
        end
        nOps = sum(Ops);
        opPos = find(Ops);
        for i = 1:nOps
            if nOps > i               
                ThisWave = TrigString(opPos(i)+1:opPos(i+1)-1);
            else
                ThisWave = TrigString(opPos(i)+1:end);
            end
            if ~strcmp(ThisWave, 'null')
                WavePos = find(strcmp(ThisWave, waveNames));
                switch Op
                    case '+'
                        if Sign == 1
                            TrigByte = TrigByte + 2^(WavePos-1);
                        else
                            CancelByte = CancelByte + 2^(WavePos-1);
                        end
                    case '-'
                        if Sign == 1
                            CancelByte = CancelByte + 2^(WavePos-1);
                        else
                            TrigByte = TrigByte + 2^(WavePos-1);
                        end
                end
            end
        end
    end
else
    if TrigString == 0
        TrigByte = 0; CancelByte = 0;
    end
end

function bsma = Add_Condition_From_Happening(bsma, CurrentState, DestinationState, HappNum, HappName, HappValue, hInputChannels, waveNames, condType)
global BpodSystem
switch condType
    case 'IO'
        CondChannelOffset = BpodSystem.HW.Pos.Input_Port;
        thisInputChannel = hInputChannels{HappNum};
    case 'Wave'
        CondChannelOffset = length(BpodSystem.HW.Inputs)+1;
        thisWaveName = HappName(1:end-3);
        thisInputChannel = find(strcmp(thisWaveName, waveNames));
    otherwise
        error('Error: Invalid condition type specified. Valid condition types are: IO, Wave');
end
maxConditions = length(bsma.ConditionSet);
nConditionsSet = sum(bsma.ConditionSet);
if nConditionsSet < maxConditions
    nConditionsSet = nConditionsSet + 1;
    bsma.ConditionChannels(nConditionsSet) = CondChannelOffset + thisInputChannel - 1;
    bsma.ConditionValues(nConditionsSet) = HappValue;
    bsma.ConditionNames{nConditionsSet} = HappName;
    bsma.ConditionSet(nConditionsSet) = 1;
    bsma.ConditionMatrix(CurrentState-38,nConditionsSet) = DestinationState-38;
    BpodSystem.PluginObjects.BcontrolEventCodeMapBuffer(nConditionsSet+BpodSystem.HW.ConditionStartposition-1) = HappNum;
else
    error(['Error: Too many conditions required to convert happenings of this protocol. The connected Bpod state machine connected only supports ' num2str(maxConditions) ' conditions.'])
end