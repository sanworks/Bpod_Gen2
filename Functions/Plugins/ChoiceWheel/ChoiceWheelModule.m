%{
----------------------------------------------------------------------------

This file is part of the Sanworks Pulse Pal repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

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

% ChoiceWheel is a system to measure lateral paw sweeps in mice.
%
% Installation:
% 1. Install PsychToolbox from: http://psychtoolbox.org/download/
% 2. Install ArCOM from https://github.com/sanworks/ArCOM
% 3. Connect ChoiceWheel to a free serial port on Bpod with a CAT6 cable
% 4. Connect ChoiceWheel to the computer with a USB micro cable.
%
% - Create a ChoiceWheel object with W = ChoiceWheel('COMx') where COMx is your serial port string
% - Directly manipulate its fields to change trial parameters on the device.
% - Run W.stream to see streaming output (for testing purposes)
% - Run P = W.currentPosition to return the current wheel position (for testing purposes).
% - Run W.runTrial to start an experimental trial.
% - Check W.runningTrial to find out if the trial is still running (0 = idle, 1 = running)
% - Run data = W.getLastTrialData once the trial is over, to return the trial outcome and wheel position record
% - Trigger a new trial start from Bpod by sending byte 'T' over the hardware serial connection
% - Serial events during the trial will be sent to Bpod: 1 = left choice, 2 = right choice,
%                                                        3 = timeout, 4 = idle period end, 5 = trial start

classdef ChoiceWheelModule < handle
    properties
        Port % ArCOM Serial port
        idleTime2Start = 1; % Time with no ball motion needed to start a trial (s)
        idleTimeMotionGrace = 10; % Distance allowed during idle time (degrees)
        leftThreshold = 140; % Threshold for left choice (in degrees from animal's prespective, trials start at 180)
        rightThreshold = 220; % Threshold for right choice (in degrees)
        timeout = 5; % Time for choice response
        lastTrialData % Struct containing the last trial's data. The struct is empty until the trial is complete.
        runningTrial = 0; % 0 if idle, 1 if running a trial
        autoSync = 1; % If 1, update params on device when parameter fields change. If 0, don't.
    end
    properties (Access = private)
        acquiring = 0; % 0 if idle, 1 if acquiring data
        gui = struct; % Handles for GUI elements
        positionBytemask = logical(repmat([1 1 0 0 0 0], 1, 10000)); % For parsing data coming back from wheel
        timeBytemask = logical(repmat([0 0 1 1 1 1], 1, 10000));
        eventNames = {'Left', 'Right', 'Timeout'};
        nDisplaySamples = 1000; % When streaming to plot, show up to 1,000 samples
        maxDisplayTime = 10; % When streaming to plot, show up to last 10 seconds
    end
    methods
        function obj = ChoiceWheelModule(portString)
            obj.Port = ArCOMObject_Bpod(portString, 115200);
            obj.Port.write('C', 'uint8');
            response = obj.Port.read(1, 'uint8');
            if response ~= 217
                error('Could not connect =( ')
            end
            obj.syncParams();
        end
        function pos = currentPosition(obj)
            obj.Port.write('Q', 'uint8');
            pos = obj.Port.read(1, 'uint16');
        end
        function set.idleTime2Start(obj, initTime)
            if obj.autoSync
                obj.Port.write('PI', 'uint8', initTime*1000, 'uint32');
            end
            obj.idleTime2Start = initTime;
        end
        function set.idleTimeMotionGrace(obj, graceDistance)
            if obj.autoSync
                obj.Port.write('PG', 'uint8', obj.degrees2pos(graceDistance), 'uint16');
            end
            obj.idleTimeMotionGrace = graceDistance;
        end
        function set.leftThreshold(obj, thresh)
            if obj.autoSync
                obj.Port.write('PL', 'uint8', obj.degrees2pos(thresh), 'uint16');
            end
            obj.leftThreshold = thresh;
        end
        function set.rightThreshold(obj, thresh)
            if obj.autoSync
                obj.Port.write('PR', 'uint8', obj.degrees2pos(thresh), 'uint16');
            end
            obj.rightThreshold = thresh;
        end
        function set.timeout(obj, timeout)
            if obj.autoSync
                obj.Port.write('PT', 'uint8', timeout*1000, 'uint32');
            end
            obj.timeout = timeout;
        end
        function syncParams(obj) % For use when autoSync is off
            SixteenBitMessage = [obj.degrees2pos(obj.idleTimeMotionGrace) obj.degrees2pos(obj.leftThreshold) ...
                 obj.degrees2pos(obj.rightThreshold)];
            ThirtyTwoBitMessage = [obj.idleTime2Start*1000 obj.timeout*1000];
            obj.Port.write('A', 'uint8', SixteenBitMessage, 'uint16', ThirtyTwoBitMessage, 'uint32');
            Confirm = obj.Port.read(1, 'uint8');
            if Confirm ~= 1
                error('Error while synchronizing parameters. ChoiceWheel did not return a confirmation bit.')
            end
        end
        function runTrial(obj, varargin)
            remoteTrigger = 0;
            if nargin > 1
                if strcmp(varargin{1}, 'SerialStart') % If triggering trial start from the serial port (not MATLAB)
                    remoteTrigger = 1;
                end
            end
            if ~remoteTrigger
                obj.Port.write('T', 'uint8');
            end
            obj.runningTrial = 1;
            obj.lastTrialData = struct;
        end
        function Data = getLastTrialData(obj)
            nBytes = obj.Port.bytesAvailable;
            if nBytes > 0
                Data = struct();
                Data.nPositions = double(obj.Port.read(1, 'uint16'));
                [TerminatingEventCode, PreTrialDuration, PosData, TimeData] = obj.Port.read(...
                    1, 'uint8', 1, 'uint32', Data.nPositions, 'uint16', Data.nPositions, 'uint32');
                Data.PreTrialDuration = double(PreTrialDuration)/1000;
                Data.TerminatingEventCode = TerminatingEventCode;
                Data.PosData = obj.pos2degrees(PosData);
                Data.TimeData = double(TimeData)/1000;
                Data.TerminatingEventName = obj.eventNames{Data.TerminatingEventCode};
                Data.TerminatingEventTime = Data.TimeData(end);
                obj.runningTrial = 0;
            else
                error('Could not get trial data - no data was available.')
            end
        end
        function stream(obj)
            obj.acquiring = 1;
            DisplayPositions = nan(1,obj.nDisplaySamples);
            DisplayTimes = nan(1,obj.nDisplaySamples);
            obj.gui.Fig  = figure('name','Position Stream','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off', 'CloseRequestFcn', @(h,e)obj.endAcq());
            obj.gui.Plot = axes('units','normalized', 'position',[.2 .2 .65 .65]); ylabel('Position (deg)', 'FontSize', 18); xlabel('Time (s)', 'FontSize', 18);
            set(gca, 'xlim', [0 obj.maxDisplayTime], 'ylim', [0 360], 'ytick', [0 180 360]);
            Xdata = nan(1,obj.nDisplaySamples); Ydata = nan(1,obj.nDisplaySamples);
            obj.gui.StartLine = line([0,obj.maxDisplayTime],[180,180], 'Color', [.5 .5 .5]);
            obj.gui.OscopeDataLine = line([Xdata,Xdata],[Ydata,Ydata]);
            DisplayPos = 1;
            drawnow;
            obj.Port.write('S', 'uint8');
            SweepStartTime = 0;
            while obj.acquiring
                BytesAvailable = obj.Port.bytesAvailable;
                if BytesAvailable > 5
                    nBytesToRead = floor(BytesAvailable/6)*6;
                    Message = obj.Port.read(nBytesToRead, 'uint8');
                    nPositions = length(Message)/6;
                    Positions = typecast(Message(obj.positionBytemask(1:6*nPositions)), 'uint16');
                    Times = double(typecast(Message(obj.timeBytemask(1:6*nPositions)), 'uint32'))/1000;
                    DisplayTime = (Times(end)-SweepStartTime);
                    DisplayPos = DisplayPos + nPositions;
                    if DisplayTime >= obj.maxDisplayTime
                        DisplayPositions(1:DisplayPos) = NaN;
                        DisplayTimes(1:DisplayPos) = NaN;
                        DisplayPos = 1;
                        SweepStartTime = Times(end);
                    else
                        SweepTimes = Times-SweepStartTime;
                        DisplayPositions(DisplayPos-nPositions+1:DisplayPos) = obj.pos2degrees(Positions);
                        DisplayTimes(DisplayPos-nPositions+1:DisplayPos) = SweepTimes;
                    end
                    set(obj.gui.OscopeDataLine,'xdata',[DisplayTimes, DisplayTimes], 'ydata', [DisplayPositions, DisplayPositions]); drawnow;
                end
                pause(.0001);
            end
        end
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
    methods (Access = private)
        function endAcq(obj)
            obj.Port.write('X', 'uint8');
            obj.acquiring = 0;
            delete(obj.gui.Fig);
            if obj.Port.bytesAvailable > 0
                obj.Port.read(obj.Port.bytesAvailable, 'uint8');
            end
        end
        function degrees = pos2degrees(obj, pos)
            degrees = (double(pos)/1024)*360;
        end
        function pos = degrees2pos(obj, degrees)
            pos = uint16((degrees/360)*1024);
        end
    end
end