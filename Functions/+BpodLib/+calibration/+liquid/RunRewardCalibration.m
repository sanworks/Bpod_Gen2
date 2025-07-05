function completed = RunRewardCalibration(BpodSystem, nPulses, TargetValves, PulseDurations, varargin)
% Run a series of reward calibration pulses for specified valves.
% completed = RunRewardCalibration(BpodSystem, nPulses, Targetvalves, PulseDurations, _)
%
% Parameters
% ----------
% BpodSystem : struct
%     The Bpod system object
% nPulses : int
%     Number of pulse repetitions to deliver
% TargetValves : cell array of char
%     Valves to pulse ('Valve1' for state machine port, 'PA1-2' for port array)
% PulseDurations : array of double
%     Duration of each pulse in seconds
%
% Keyword Arguments
% -----------------
% PulseInterval : double (default=0.2)
%     Interval between pulses of each valve (seconds)
% PulseSetPause : double (default=0.5)
%     Pause between each set of pulses (seconds)
% verbose : logical (default=true)
%     Whether to display progress messages
%
% Returns
% -------
% completed : int
%     1 if calibration completed successfully, 0 otherwise

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

completed = 0;

p = inputParser();
p.addParameter('PulseInterval', 0.2, @isnumeric);
p.addParameter('PulseSetPause', 0.5, @isnumeric);
p.addParameter('verbose', true)
p.parse(varargin{:})

PulseInterval = p.Results.PulseInterval;

for x = 1:length(PulseDurations)
    if isnan(PulseDurations(x))
        PulseDurations(x) = 0;
    end
end

%% Build valve testing information
if p.Results.verbose
    fprintf('Running reward calibration pulses with:\n')
end

data = struct('name', [], 'outputaction', [], 'type', []);
ValvePhysicalAddress = 2.^(0:7);
nValves = length(TargetValves);
for idx = 1:nValves
    valveName = TargetValves{idx};
    if p.Results.verbose
        fprintf('\t%s for %.1f ms\n', valveName, PulseDurations(idx) * 1000)
    end
    if strncmp(valveName, 'Valve', 5)
        data(idx).name = valveName;
        valveID = str2double(valveName(6));
        data(idx).outputaction = {'ValveState', ValvePhysicalAddress(valveID)};
        data(idx).type = 'wire';
    elseif strncmp(valveName, 'PA', 2)
        data(idx).name = valveName;
        portnumber = str2double(valveName(5)) - 1;  % PortArray is 0-indexed
        data(idx).outputaction = {valveName(1:3), ['V', portnumber]};
        data(idx).type = 'serial';
    else
        error('BpodLib:LiquidCalibration:UnrecognisedValveName', 'Valve %s does not meet expected format requirement.', valveName)
    end
end

%% Create pulse delivery state matrix
sma = NewStateMatrix();
for y = 1:nValves
    valveData = data(y);
    
    if strcmp(valveData.type, 'wire')
        % Valve is open only while the state is active
        openValveAction = valveData.outputaction;
        nextStatePulseEnd = ['Delay' valveData.name];
    else
        % Port arrays must be explicitly closed
        % output actions are ['V' portnumber state]
        openValveAction = valveData.outputaction;
        openValveAction{2} = [openValveAction{2} 1];
        nextStatePulseEnd = ['PulseClosed', valveData.name]; % use additional state to send close message

        closeValveAction = valveData.outputaction;
        closeValveAction{2} = [closeValveAction{2} 0];
    end

    sma = AddState(sma, 'Name', ['Pulse' valveData.name], ...
                        'Timer', PulseDurations(y),...
                        'StateChangeConditions', ...
                        {'Tup', nextStatePulseEnd},...
                        'OutputActions', openValveAction);

    if strcmp(valveData.type, 'serial')
        sma = AddState(sma, 'Name', ['PulseClose' valveData.name], ...
                            'Timer', 0,...
                            'StateChangeConditions', ...
                            {'Tup', ['Delay' valveData.name]},...
                            'OutputActions', closeValveAction);
    end

    if y < nValves
        sma = AddState(sma, 'Name', ['Delay' valveData.name], ...
                            'Timer', PulseInterval,...
                            'StateChangeConditions', ...
                            {'Tup', ['Pulse' data(y+1).name]},...
                            'OutputActions', {});
    else
        sma = AddState(sma, 'Name', ['Delay' valveData.name], ...
                            'Timer', PulseInterval,...
                            'StateChangeConditions', ...
                            {'Tup', 'exit'},...
                            'OutputActions', {});
    end
end

%% Execute pulses
SendStateMatrix(sma);

for x = 1:nPulses
    progressbar(x/nPulses)

    if BpodSystem.EmulatorMode == 0
        RunStateMatrix;
        pause(p.Results.PulseSetPause);
    else
        if x == 1 && p.Results.verbose
            disp('Emulator mode detected, reward calibration will not run but values can be entered.');
        end
        completed = 1;
        progressbar(1)
    end
    if BpodSystem.Status.BeingUsed == 0
        progressbar(1);
        return
    end
end
completed = 1;
BpodSystem.Status.BeingUsed = 0;
end