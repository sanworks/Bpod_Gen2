function Completed = RunRewardCalibration(BpodSystem, nPulses, TargetValves, PulseDurations, varargin)
% Make the specified valves pulse for the specified durations
% :param BpodSystem: the Bpod system object
% :type BpodSystem: struct
% :param nPulses: the number of pulses to deliver
% :type nPulses: int
% :param TargetValves: the valves to pulse, format as 'Valve1' (state machine's port) or 'PA1-2' (for port array module)
% :type TargetValves: cell array of char
% :param PulseDurations: the duration of each pulse (s)
% :type PulseDurations: array of double
% :param PulseInterval: the interval between pulses of each valve (s), optional
% :type PulseInterval: double
% :param PulseSetPause: the pause between each set of pulses (s), optional
% :type PulseSetPause: double
% :return: whether the calibration was completed
% :rtype: int


p = inputParser();
p.addParameter('PulseInterval', 0.2, @isnumeric);
p.addParameter('PulseSetPause', 0.5, @isnumeric);
p.parse(varargin{:})

Completed = 0;
PulseInterval = p.Results.PulseInterval;
PulseDurations(PulseDurations == 0) = NaN;
% if sum(PulseDurations > 1) > 0
    % error('Pulse durations should be specified in seconds.')
% end
for x = 1:length(PulseDurations)
    if isnan(PulseDurations(x))
        PulseDurations(x) = 0;
    end
end

% Build valve testing information
data = struct('name', [], 'outputaction', [], 'type', []);
ValvePhysicalAddress = 2.^(0:7);
nValves = length(TargetValves);
for idx = 1:nValves
    valveName = TargetValves{idx};
    if strcmp(valveName(1:5), 'Valve')
        data(idx).name = valveName;
        valveID = str2double(valveName(6));
        data(idx).outputaction = {'ValveState', ValvePhysicalAddress(valveID)};
        data(idx).type = 'wire';
    elseif strcmp(valveName(1:2), 'PA')
        data(idx).name = valveName;
        portnumber = str2double(valveName(5)) - 1;  % PortArray is 0-indexed
        data(idx).outputaction = {valveName(1:3), ['V', portnumber]};
        data(idx).type = 'serial';
    else
        error('BpodLib:LiquidCalibration:UnrecognisedValveName', 'Valve %s does not meet expected format requirement.', valveName)
    end
end

% Create the set of pulses to be tested out
sma = NewStateMatrix();
for y = 1:nValves
    valvedata = data(y);
    if strcmp(valvedata.type, 'wire')
        % Valve is open only while the state is active
        openvalveaction = valvedata.outputaction;
        nextstate_pulseend = ['Delay' valvedata.name];
    else
        % Valve is switched open and must have another message sent to close
        openvalveaction = valvedata.outputaction;
        openvalveaction{2} = [openvalveaction{2} 1];
        nextstate_pulseend = ['PulseClosed' valvedata.name]; % use additional state to send close message
        closevalveaction = valvedata.outputaction;
        closevalveaction{2} = [closevalveaction{2} 0];
    end

    sma = AddState(sma, 'Name', ['Pulse' valvedata.name], ...
                        'Timer', PulseDurations(y),...
                        'StateChangeConditions', ...
                        {'Tup', nextstate_pulseend},...
                        'OutputActions', openvalveaction);

    if strcmp(valvedata.type, 'serial')
        sma = AddState(sma, 'Name', ['PulseClose' valvedata.name], ...
                            'Timer', 0,...
                            'StateChangeConditions', ...
                            {'Tup', ['Delay' valvedata.name]},...
                            'OutputActions', closevalveaction);
    end

    if y < nValves
        sma = AddState(sma, 'Name', ['Delay' valvedata.name], ...
                            'Timer', PulseInterval,...
                            'StateChangeConditions', ...
                            {'Tup', ['Pulse' data(y+1).name]},...
                            'OutputActions', {});
    else
        sma = AddState(sma, 'Name', ['Delay' valvedata.name], ...
                            'Timer', PulseInterval,...
                            'StateChangeConditions', ...
                            {'Tup', 'exit'},...
                            'OutputActions', {});
    end
end
SendStateMatrix(sma);

% Do the pulses
progressbar;
for x = 1:nPulses
    progressbar(x/nPulses)
    if BpodSystem.EmulatorMode == 0
        RunStateMatrix;
        pause(p.Results.PulseSetPause);
    else
        disp('Emulator mode detected, reward calibration will not run but values can be entered.');
        Completed = 1;
        progressbar(1)
    end
    if BpodSystem.Status.BeingUsed == 0
        progressbar(1);
        return
    end
end
Completed = 1;
BpodSystem.Status.BeingUsed = 0;
end