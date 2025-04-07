function Completed = RunRewardCalibration(BpodSystem, nPulses, TargetValves, PulseDurations, varargin)
% Make the specified valves pulse for the specified durations
% :param BpodSystem: the Bpod system object
% :type BpodSystem: struct
% :param nPulses: the number of pulses to deliver
% :type nPulses: int
% :param TargetValves: the valves to pulse
% :type TargetValves: array of int
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

% todo: allow TargetValves to be cell of valve names

Completed = 0;
% Replace with settings
PulseInterval = p.Results.PulseInterval;
ValvePhysicalAddress = 2.^(0:7);
nValves = length(TargetValves);
PulseDurations(PulseDurations == 0) = NaN;
% if sum(PulseDurations > 1) > 0
%     error('Pulse durations should be specified in seconds.')
% end
for x = 1:length(PulseDurations)
    if isnan(PulseDurations(x))
        PulseDurations(x) = 0;
    end
end

progressbar;
sma = NewStateMatrix();
for y = 1:nValves
    sma = AddState(sma, 'Name', ['PulseValve' num2str(TargetValves(y))], ...
        'Timer', PulseDurations(y),...
        'StateChangeConditions', ...
        {'Tup', ['Delay' num2str(y)]},...
        'OutputActions', {'ValveState', ValvePhysicalAddress(TargetValves(y))});
    if y < nValves
        sma = AddState(sma, 'Name', ['Delay' num2str(y)], ...
            'Timer', PulseInterval,...
            'StateChangeConditions', ...
            {'Tup', ['PulseValve' num2str(TargetValves(y+1))]},...
            'OutputActions', {});
    else
        sma = AddState(sma, 'Name', ['Delay' num2str(y)], ...
            'Timer', PulseInterval,...
            'StateChangeConditions', ...
            {'Tup', 'exit'},...
            'OutputActions', {});
    end
end
SendStateMatrix(sma);
for x = 1:nPulses
    progressbar(x/nPulses)
    if BpodSystem.EmulatorMode == 0
        RunStateMatrix;
        pause(p.Results.PulseSetPause);
    else
        disp('Emulator mode detected, reward calibration will not run but values can be entered.');
        % todo: dev mode to prevent users from doing this?
        Completed = 1;
        progressbar(1)
    end
    if BpodSystem.Status.BeingUsed == 0
        % ? does this need a warning message?
        progressbar(1);
        return
    end
end
Completed = 1;
BpodSystem.Status.BeingUsed = 0;
end