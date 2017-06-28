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
% 3. Connect the rotary encoder module to a free serial port on Bpod with a CAT6 cable
% 4. Connect the rotary encoder module to the computer with a USB micro cable.
%
% - Create a RotaryEncoderModule object with R = RotaryEncoderModule('COMx') where COMx is your serial port string
% - Directly manipulate its fields to change trial parameters on the device.
% - Run R.stream to see streaming output (for testing purposes)
% - Run P = R.currentPosition to return the current wheel position (for testing purposes).
% - Run R.runTrial to manually start an experimental trial.
% - Check R.runningTrial to find out if the trial is still running (0 = idle, 1 = running)
% - Run data = R.getLastTrialData once the trial is over, to return the trial outcome and wheel position record
% - Run a trial from the Bpod state machine by sending byte 'T' over the hardware serial connection
% - Serial event bytes during the trial will be sent to Bpod: 1 = left choice, 2 = right choice

classdef RotaryEncoderModule < handle
    properties
        Port % ArCOM Serial port
        Timer % MATLAB timer (for updating the UI)
        threshold1 = -40; % Threshold for left choice (in degrees, trials start at 180)
        threshold2 = 40; % Threshold for right choice (in degrees)
        runningTrial = 0; % 0 if idle, 1 if running a trial
        outputStream = 'off';
        sendEvents = 'off';
        autoSync = 1; % If 1, update params on device when parameter fields change. If 0, don't.
    end
    properties (Access = private)
        acquiring = 0; % 0 if idle, 1 if acquiring data
        gui = struct; % Handles for GUI elements
        positionBytemask = logical(repmat([1 1 0 0 0 0], 1, 10000)); % For parsing data coming back from wheel
        timeBytemask = logical(repmat([0 0 1 1 1 1], 1, 10000));
        nDisplaySamples = 1000; % When streaming to plot, show up to 1,000 samples
        maxDisplayTime = 10; % When streaming to plot, show up to last 10 seconds
        displayPos = 1; % Current position on UI plot
        sweepStartTime = 0; % Time current UI sweep started
        displayPositions % UI y data
        displayTimes % UI x data
    end
    methods
        function obj = RotaryEncoderModule(portString)
            obj.Port = ArCOMObject_Bpod(portString, 115200);
            obj.Port.write('C', 'uint8');
            response = obj.Port.read(1, 'uint8');
            if response ~= 217
                error('Could not connect =( ')
            end
            obj.syncParams();
            obj.displayPositions = nan(1,obj.nDisplaySamples); % UI y data
            obj.displayTimes = nan(1,obj.nDisplaySamples); % UI x data
        end
        function pos = currentPosition(obj)
            obj.Port.write('Q', 'uint8');
            pos = obj.pos2degrees(obj.Port.read(1, 'int16'));
        end
        function set.threshold1(obj, thresh)
            if obj.autoSync
                obj.Port.write(['H' 1], 'uint8', obj.degrees2pos(thresh), 'int16');
            end
            Confirm = obj.Port.read(1, 'uint8');
            if Confirm ~= 1
                error('Error setting threshold. The rotary encoder module did not return a confirmation bit.')
            end
            obj.threshold1 = thresh;
        end
        function set.threshold2(obj, thresh)
            if obj.autoSync
                obj.Port.write(['H' 2], 'uint8', obj.degrees2pos(thresh), 'int16');
            end
            Confirm = obj.Port.read(1, 'uint8');
            if Confirm ~= 1
                error('Error setting threshold. The rotary encoder module did not return a confirmation bit.')
            end
            obj.threshold2 = thresh;
        end
        function set.outputStream(obj, stateString)
            stateString = lower(stateString);
            if obj.autoSync
                switch stateString
                    case 'off'
                        obj.Port.write(['O' 0], 'uint8');
                    case 'on'
                        obj.Port.write(['O' 1], 'uint8');
                    otherwise
                        error('Error setting outputStream; value must be ''on'' or ''off''');
                end
            end
            Confirm = obj.Port.read(1, 'uint8');
            if Confirm ~= 1
                error('Error setting output stream state. ChoiceWheel did not return a confirmation bit.')
            end
            obj.outputStream = stateString;
        end
        function set.sendEvents(obj, stateString)
            stateString = lower(stateString);
            if obj.autoSync
                switch stateString
                    case 'off'
                        obj.Port.write(['V' 0], 'uint8');
                    case 'on'
                        obj.Port.write(['V' 1], 'uint8');
                    otherwise
                        error('Error setting sendEvents; value must be ''on'' or ''off''');
                end
            end
            Confirm = obj.Port.read(1, 'uint8');
            if Confirm ~= 1
                error('Error setting event output state. ChoiceWheel did not return a confirmation bit.')
            end
            obj.sendEvents = stateString;
        end
        function syncParams(obj) % For use when autoSync is off
            EightBitMessage = double([strcmp(obj.outputStream, 'on') strcmp(obj.sendEvents, 'on')]); 
            SixteenBitMessage = [obj.degrees2pos(obj.threshold1) obj.degrees2pos(obj.threshold2)];
            obj.Port.write(['A' EightBitMessage], 'uint8', SixteenBitMessage, 'int16');
            Confirm = obj.Port.read(1, 'uint8');
            if Confirm ~= 1
                error('Error while synchronizing parameters. ChoiceWheel did not return a confirmation bit.')
            end
        end
        function runTrial(obj, varargin) % Resets thresholds, starts logging
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
        end
        function startLogging(obj)
            obj.Port.write('L', 'uint8');
        end
        function stopLogging(obj)
            obj.Port.write('F', 'uint8');
        end
        function Data = getLoggedData(obj)
            obj.Port.write('R', 'uint8');
            nPositions = obj.Port.read(1, 'uint32');
            if nPositions > 0
                Data = struct();
                Data.nPositions = double(nPositions);
                RawData = obj.Port.read(Data.nPositions*2, 'int32');
                PosData = RawData(1:2:end);
                TimeData = RawData(2:2:end);
                Data.PosData = obj.pos2degrees(PosData);
                Data.TimeData = double(TimeData)/1000;
                obj.runningTrial = 0;
            else
                error('Could not get trial data - no data was available.')
            end
        end
        function zeroPosition(obj)
            obj.Port.write('Z', 'uint8');
        end
        function enableThresholds(obj)
            obj.Port.write([';' 1], 'uint8');
        end
        function disableThresholds(obj)
            obj.Port.write([';' 0], 'uint8');
        end
        function stream(obj)
            obj.acquiring = 1;
            BGColor = [0.8 0.8 0.8];
            LeftColor = [0 0 1];
            RightColor = [1 0 0];
            obj.displayPositions = nan(1,obj.nDisplaySamples);
            obj.displayTimes = nan(1,obj.nDisplaySamples);
            obj.gui.Fig  = figure('name','Position Stream', 'position',[100,100,800,500],...
                'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off',...
                'Color',BGColor, 'CloseRequestFcn', @(h,e)obj.endAcq());
            obj.gui.Plot = axes('units','pixels', 'position',[90,70,500,400]); 
            ylabel('Position (deg)', 'FontSize', 18); 
            xlabel('Time (s)', 'FontSize', 18);
            set(gca, 'xlim', [0 obj.maxDisplayTime], 'ylim', [-180 180], 'ytick', [-180 0 180], 'tickdir', 'out', 'FontSize', 12);
            Xdata = nan(1,obj.nDisplaySamples); Ydata = nan(1,obj.nDisplaySamples);
            obj.gui.StartLine = line([0,obj.maxDisplayTime],[0,0], 'Color', [.5 .5 .5]);
            obj.gui.Thresh1Line = line([0,obj.maxDisplayTime],[NaN NaN], 'Color', LeftColor, 'LineStyle', ':');
            obj.gui.Thresh2Line = line([0,obj.maxDisplayTime],[NaN NaN], 'Color', RightColor, 'LineStyle', ':');
            obj.gui.OscopeDataLine = line([Xdata,Xdata],[Ydata,Ydata]);
            Ypos = 445;
            uicontrol('Style', 'text', 'Position', [600 Ypos 170 30], 'String', 'Behavior Events', 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor); Ypos = Ypos - 30;
            obj.gui.UseEventsCheckbox = uicontrol('Style', 'checkbox', 'Position', [610 Ypos 30 30], 'FontSize', 12,...
                'BackgroundColor', BGColor, 'Callback',@(h,e)obj.UIsetParams());
            uicontrol('Style', 'text', 'Position', [630 Ypos-5 50 30], 'String', 'Enable', 'FontSize', 12,...
                'BackgroundColor', BGColor); Ypos = Ypos - 45;
            Ypos = 370;
            uicontrol('Style', 'text', 'Position', [600 Ypos 180 30], 'String', 'Event Thresh (deg)', 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor); Ypos = Ypos - 45;
            uicontrol('Style', 'text', 'Position', [600 Ypos 30 30], 'String', '1:', 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor, 'ForegroundColor', LeftColor);
            obj.gui.Threshold1Edit = uicontrol('Style', 'edit', 'Position', [630 Ypos+2 60 30], 'String', num2str(obj.threshold1), 'FontSize', 14,...
                'FontWeight', 'bold', 'Enable', 'off');
            uicontrol('Style', 'text', 'Position', [695 Ypos 30 30], 'String', '2:', 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor, 'ForegroundColor', RightColor);
            obj.gui.Threshold2Edit = uicontrol('Style', 'edit', 'Position', [725 Ypos+2 60 30], 'String', num2str(obj.threshold2), 'FontSize', 14,...
                'FontWeight', 'bold', 'Enable', 'off');
            Ypos = 275;
            uicontrol('Style', 'text', 'Position', [600 Ypos 150 30], 'String', 'Output Stream', 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor); Ypos = Ypos - 30;
            obj.gui.OutputStreamCheckbox = uicontrol('Style', 'checkbox', 'Position', [610 Ypos 30 30], 'FontSize', 12,...
                'BackgroundColor', BGColor, 'Callback',@(h,e)obj.UIsetParams(), 'Value', strcmp(obj.outputStream, 'on'));
            uicontrol('Style', 'text', 'Position', [630 Ypos-5 50 30], 'String', 'Enable', 'FontSize', 12,...
                'BackgroundColor', BGColor); Ypos = Ypos - 45;
            obj.displayPos = 1;
            obj.sweepStartTime = 0;
            drawnow;
            obj.Timer = timer('TimerFcn',@(h,e)obj.updatePlot(), 'ExecutionMode', 'fixedRate', 'Period', 0.05);
            obj.Port.write('S', 'uint8');
            start(obj.Timer);
        end
        function UIsetParams(obj)
            obj.Port.write('X', 'uint8');
            stop(obj.Timer);
            pause(.1);
            nBytesAvailable = obj.Port.bytesAvailable;
            if (nBytesAvailable > 0)
                obj.Port.read(nBytesAvailable, 'uint8');
            end
            useEvents = get(obj.gui.UseEventsCheckbox, 'Value');
            if useEvents
                set(obj.gui.Threshold1Edit, 'enable', 'on');
                set(obj.gui.Threshold2Edit, 'enable', 'on');
                set(obj.gui.Thresh1Line, 'Ydata', [obj.threshold1,obj.threshold1]);
                set(obj.gui.Thresh2Line, 'Ydata', [obj.threshold2,obj.threshold2]);
            else
                set(obj.gui.Threshold1Edit, 'enable', 'off');
                set(obj.gui.Threshold2Edit, 'enable', 'off');
                set(obj.gui.Thresh1Line, 'Ydata', [NaN NaN]);
                set(obj.gui.Thresh2Line, 'Ydata', [NaN NaN]);
            end
            useOutputStream = get(obj.gui.OutputStreamCheckbox, 'Value');
            
            Nans = nan(1,length(obj.displayPositions));
            obj.displayPositions = Nans;
            obj.displayTimes = Nans;
            set(obj.gui.OscopeDataLine, 'Ydata', [Nans Nans], 'Xdata', [Nans Nans]);
            obj.sweepStartTime = 0;
            obj.displayPos = 1;
            switch useEvents
                case 0
                    obj.sendEvents = 'off';
                    obj.disableThresholds;
                case 1
                    obj.sendEvents = 'on';
                    obj.enableThresholds;
            end
            switch useOutputStream
                case 0
                    obj.outputStream = 'off';
                case 1
                    obj.outputStream = 'on';
            end
            obj.threshold1 = str2double(get(obj.gui.Threshold1Edit, 'String'));
            obj.threshold2 = str2double(get(obj.gui.Threshold2Edit, 'String'));
            obj.Port.write('S', 'uint8');
            start(obj.Timer);
        end
        function updatePlot(obj)
            BytesAvailable = obj.Port.bytesAvailable;
            if BytesAvailable > 5
                nBytesToRead = floor(BytesAvailable/6)*6;
                Message = obj.Port.read(nBytesToRead, 'uint8');
                nPositions = length(Message)/6;
                Positions = typecast(Message(obj.positionBytemask(1:6*nPositions)), 'int16');
                Times = double(typecast(Message(obj.timeBytemask(1:6*nPositions)), 'uint32'))/1000;
                DisplayTime = (Times(end)-obj.sweepStartTime);
                obj.displayPos = obj.displayPos + nPositions;
                if DisplayTime >= obj.maxDisplayTime
                    obj.displayPositions(1:obj.displayPos) = NaN;
                    obj.displayTimes(1:obj.displayPos) = NaN;
                    obj.displayPos = 1;
                    obj.sweepStartTime = Times(end);
                else
                    SweepTimes = Times-obj.sweepStartTime;
                    Pos = obj.pos2degrees(Positions);
                    Pos(Pos == 180) = NaN;
                    obj.displayPositions(obj.displayPos-nPositions+1:obj.displayPos) = Pos;
                    obj.displayTimes(obj.displayPos-nPositions+1:obj.displayPos) = SweepTimes;
                end
                set(obj.gui.OscopeDataLine,'xdata',[obj.displayTimes, obj.displayTimes], 'ydata', [obj.displayPositions, obj.displayPositions]); drawnow;
            end
        end
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
    methods (Access = private)
        function endAcq(obj)
            stop(obj.Timer);
            delete(obj.Timer);
            obj.Timer = [];
            obj.Port.write('X', 'uint8');
            obj.acquiring = 0;
            delete(obj.gui.Fig);
            pause(.1);
            if obj.Port.bytesAvailable > 0
                obj.Port.read(obj.Port.bytesAvailable, 'uint8');
            end
        end
        function degrees = pos2degrees(obj, pos)
            degrees = round(((double(pos)/512)*180)*10)/10;
        end
        function pos = degrees2pos(obj, degrees)
            pos = int16((degrees/180)*512);
        end
    end
end