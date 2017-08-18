function MyProtocol % On each trial, at random, either port 1 or 3 will blink.

global BpodSystem % Allows access to Bpod device from this function
TrialTypes = ceil(rand(1,5000)*2); % Make 5000 future trial types

BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

for currentTrial = 1:5000
    disp(['Trial# ' num2str(currentTrial) ' TrialType: ' num2str(TrialTypes(currentTrial))])
    
    if TrialTypes(currentTrial) == 1 % Determine which LED to set to max brightness (255)
        LEDcode = {'PWM1', 255}; MyStateChangeConditions = {'Port1In', 'LightOff'};
    else
        LEDcode = {'PWM3', 255}; MyStateChangeConditions = {'Port3In', 'LightOff'};
    end
    
    sma = NewStateMatrix(); % Assemble state matrix
    
    sma = AddState(sma, 'Name', 'LightOn', ...
        'Timer', 0,...
        'StateChangeConditions', MyStateChangeConditions,...
        'OutputActions', LEDcode);
    
    sma = AddState(sma, 'Name', 'LightOff', ...
        'Timer', 0.5,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {});
    
    SendStateMatrix(sma); RawEvents = RunStateMatrix; % Send and run state matrix
    
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the current trial type to data
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.BeingUsed == 0
        return
    end
end