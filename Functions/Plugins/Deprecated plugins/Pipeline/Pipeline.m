function varargout = Pipeline(op, varargin)
global BpodSystem
global PipelineSystem
switch op
    case 'init'
        % Expects the following argument/value pairs:
        % 'SessionEndCriteriaType', 'type' ('type = 'time', 'nTrials')
        % 'SessionEndCriteria', value (value units = seconds if SessionEndCriteriaType = time, trials if trials)
        % Optional argument: 
        % 'BreakDuration', duration (Duration in seconds, for break between sessions in 2-box configuration)
        % 'Animals', (a cell array of strings listing animals in the
        % pipeline. Animal 1 gets loaded into the behavior chamber. Animal
        % 2 gets loaded so he will be trained next (box to the left of the
        % behavior chamber). Animal 3 gets loaded in the remaining box.
        SerialPort = varargin{1};
        PipelineSystem.Settings = struct;
        PipelineSystem.Settings.SessionEndCriteriaType = varargin{3}; % 'nTrials' or 'time' 
        PipelineSystem.Settings.SessionEndCriteria = varargin{5}; %(units are seconds if EndCriteria = 'time' or trials if EndCriteria = 'nTrials')
        if nargin > 8
            PipelineSystem.Settings.BreakDuration = varargin{9}; % Break duration in seconds (for two-box task only)
        end
        if isfield(PipelineSystem,'SerialPort')
            PipelineDoor('end');
        end
        PipelineDoor('init', SerialPort);
        PipelineSystem.Animals = varargin{7};
        PipelineSystem.nAnimals = length(PipelineSystem.Animals);
        PipelineSystem.currentAnimal = PipelineSystem.nAnimals; % This will cause it to cycle to 1 for the first session
        PipelineSystem.Vars = struct;
        PipelineSystem.sessionIndex = 0; % Increments with each session
        PipelineSystem.currentTime = 0; % Measures time at beginning of each trial
        PipelineSystem.sessionStartTime = 0; % Measures time at beginning of each session
        PipelineSystem.run = 1; % set to 1 to continue running sessions, 0 to finish training
        PipelineSystem.currentTrial = 0;
    case 'newSession'
        PipelineSystem.runSession = 1; % internally set to 1 to continue running the current session, 0 to end it
        PipelineSystem.sessionIndex = PipelineSystem.sessionIndex + 1;
        if (PipelineSystem.currentAnimal < PipelineSystem.nAnimals)
            PipelineSystem.currentAnimal = PipelineSystem.currentAnimal + 1;
        else
            PipelineSystem.currentAnimal = 1;
        end
        currentAnimalName = PipelineSystem.Animals{PipelineSystem.currentAnimal};
        disp(['Begin session ' num2str(PipelineSystem.sessionIndex) '. Running animal: ' currentAnimalName])
        PipelineSystem.currentTrial = 0; % Current trial within session
        % Close all protocol figures
        try
            Figs = fields(BpodSystem.ProtocolFigures);
            nFigs = length(Figs);
            for x = 1:nFigs
                try
                    close(eval(['BpodSystem.ProtocolFigures.' Figs{x}]));
                catch
                    
                end
            end
            try
                close(BpodNotebook)
            catch
            end
        catch
        end
        FormattedDate = [datestr(now, 3) datestr(now, 7) '_' datestr(now, 10)];
        DataFolder = fullfile(BpodSystem.BpodPath,'Data',currentAnimalName,BpodSystem.CurrentProtocolName, 'Session Data');
        Candidates = dir(DataFolder);
        nSessionsToday = 0;
        for x = 1:length(Candidates)
            if x > 2
                if strfind(Candidates(x).name, FormattedDate)
                    nSessionsToday = nSessionsToday + 1;
                end
            end
        end
        DataPath = fullfile(BpodSystem.BpodPath,'Data',currentAnimalName,BpodSystem.CurrentProtocolName,'Session Data',[BpodSystem.GUIData.SubjectName '_' BpodSystem.CurrentProtocolName '_' FormattedDate '_Session' num2str(nSessionsToday+1) '.mat']);
        BpodSystem.DataPath = DataPath;
        BpodSystem.Data = struct;
        BpodSystem.Data.TrialTypes = [];
        BpodSystem.ProtocolStartTime = now;
        PipelineSystem.sessionStartTime = BpodTime;
        PipelineSystem.runSession = 1;
        if BpodSystem.BeingUsed == 0
            PipelineSystem.run = 0;
        end
    case 'checkSessionFinished'
        switch PipelineSystem.Settings.SessionEndCriteriaType
            case 'time'
                if (BpodTime - PipelineSystem.sessionStartTime) > PipelineSystem.Settings.SessionEndCriteria
                    PipelineSystem.runSession = 0;
                end
            case 'nTrials'
                if (PipelineSystem.currentTrial+1) > PipelineSystem.Settings.SessionEndCriteria
                    PipelineSystem.runSession = 0;
                end
        end
        if BpodSystem.BeingUsed == 0
            PipelineSystem.run = 0;
        end
    case 'cycleAnimals'
        ManualOverride(2, 1); ManualOverride(2, 2); ManualOverride(2, 3);
        Ok = PipelineDoor('cycle', 1);
        ManualOverride(2, 1); ManualOverride(2, 2); ManualOverride(2, 3);
        disp(['End session# ' num2str(PipelineSystem.sessionIndex) '. ' num2str(PipelineSystem.currentTrial) ' trials completed.']);
        PipelineDoor('open', 4);
        sma = NewStateMatrix();
        sma = AddState(sma, 'Name', 'WaitForPoke', ...
            'Timer', 0,...
            'StateChangeConditions', {'Port1In', 'exit','Port2In', 'exit','Port3In', 'exit'},...
            'OutputActions', {});
        SendStateMatrix(sma); RunStateMatrix;
        Ok = PipelineDoor('close', 4);
        Ok = PipelineDoor('cycle', 3);
        pause(10);
        Ok = PipelineDoor('cycle', 2);

    case 'interSessionPause' % Waits for BreakDuration seconds until the next session (2-chamber configuration only)
        disp(['Waiting ' num2str(PipelineSystem.Settings.BreakDuration/60) ' minutes.']);
        pause(PipelineSystem.Settings.BreakDuration);
    case 'interSessionEnd' % Opens door, waits until mouse has poked in a port to close it (2-chamber configuration only)
        PipelineDoor('open');
        sma = NewStateMatrix();
        sma = AddState(sma, 'Name', 'WaitForPoke', ...
            'Timer', 0,...
            'StateChangeConditions', {'Port1In', 'exit','Port2In', 'exit','Port3In', 'exit'},...
            'OutputActions', {});
        SendStateMatrix(sma); RunStateMatrix;
        Ok = PipelineDoor('close');
        if ~Ok
            error('Door close failure detected');
        end
    case 'end'
        PipelineDoor('end');
end

function Result = WaitForDoorClose
global PipelineSystem
while PipelineSystem.SerialPort.BytesAvailable == 0
end
Result = fread(PipelineSystem.SerialPort, PipelineSystem.SerialPort.BytesAvailable);