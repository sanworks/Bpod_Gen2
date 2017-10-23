%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

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
% - Run R.runTrial to manually start an experimental trial (sets position to 0, enables thresholds).
% - Run data = R.getLastTrialData once the trial is over, to return the trial outcome and wheel position record
% - Run a trial from the Bpod state machine by sending byte 'T' over the hardware serial connection
% - Serial event bytes during the trial will be sent to Bpod: 1 = left choice, 2 = right choice

classdef RotaryEncoderModule < handle
    properties
        Port % ArCOM Serial port
        Timer % MATLAB timer (for updating the UI)
        thresholds = [-40 40]; % Encoder position thresholds, in degrees, used to generate behavior events
        wrapPoint = 180; % Point at which position wraps around, in degrees. Set to 0 to deactivate wrapping.
        sendThresholdEvents = 'off';
        moduleOutputStream = 'off';
        moduleStreamPrefix = 'M';
    end
    properties (Access = private)
        acquiring = 0; % 0 if idle, 1 if streaming data to serial buffer
        uiStreaming = 0; % 1 if streaming data to UI
        gui = struct; % Handles for GUI elements
        positionBytemask = logical(repmat([1 1 0 0 0 0], 1, 10000)); % For parsing data coming back from wheel
        timeBytemask = logical(repmat([0 0 1 1 1 1], 1, 10000));
        nDisplaySamples = 1000; % When streaming to plot, show up to 1,000 samples
        maxDisplayTime = 10; % When streaming to plot, show up to last 10 seconds
        displayPos = 1; % Current position on UI plot
        sweepStartTime = 0; % Time current UI sweep started
        displayPositions % UI y data
        displayTimes % UI x data
        autoSync = 1; % If 1, update params on device when parameter fields change. If 0, don't.
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
        function set.thresholds(obj, newThresholds)
            if sum(abs(newThresholds) > obj.wrapPoint) > 0
                error(['Error: thresholds cannot exceed the rotary encoder''s current wrap point: ' num2str(obj.wrapPoint) ' degrees.'])
            end
            ThresholdsInTics = obj.degrees2pos(newThresholds);
            obj.Port.write(['T' length(ThresholdsInTics)], 'uint8', ThresholdsInTics, 'int16');
            obj.ConfirmUSBTransmission('Thresholds');
            obj.thresholds = newThresholds;
        end
        function set.moduleOutputStream(obj, stateString)
            stateString = lower(stateString);
            if obj.autoSync
                switch stateString
                    case 'off'
                        obj.Port.write(['O' 0], 'uint8');
                    case 'on'
                        obj.Port.write(['O' 1], 'uint8');
                    otherwise
                        error('Error setting moduleOutputStream; value must be ''on'' or ''off''');
                end
            end
            obj.ConfirmUSBTransmission('Module Output Stream Enable/Disable');
            obj.moduleOutputStream = stateString;
        end
        function set.moduleStreamPrefix(obj, Prefix)
            if (length(Prefix) > 1) || (~ischar(Prefix))
                error('Error setting output stream prefix; Prefix must be a single character.')
            end
            obj.Port.write(['F' Prefix], 'uint8');
            obj.ConfirmUSBTransmission('Module Output Stream Prefix');
        end
        function set.wrapPoint(obj, newWrapPoint)
            newWrapPointTics = obj.degrees2pos(newWrapPoint);
            obj.Port.write('W', 'uint8', newWrapPointTics, 'int16');
            obj.ConfirmUSBTransmission('Module Wrap Point');
            obj.wrapPoint = newWrapPoint;
        end
        function set.sendThresholdEvents(obj, stateString)
            stateString = lower(stateString);
            if obj.autoSync
                switch stateString
                    case 'off'
                        obj.Port.write(['V' 0], 'uint8');
                    case 'on'
                        obj.Port.write(['V' 1], 'uint8');
                    otherwise
                        error('Error setting sendThresholdEvents; value must be ''on'' or ''off''');
                end
            end
            obj.ConfirmUSBTransmission('State Machine Threshold Events (Enable/Disable)');
            obj.sendThresholdEvents = stateString;
        end
        function syncParams(obj) % For use when autoSync is off
            ModuleOutputStreamValue = double(strcmp(obj.moduleOutputStream, 'on'));
            obj.Port.write(['O' ModuleOutputStreamValue], 'uint8');
            obj.ConfirmUSBTransmission('Output Module Stream');
            StateMachineEventsValue = double(strcmp(obj.sendThresholdEvents, 'on'));
            obj.Port.write(['V' StateMachineEventsValue], 'uint8');
            obj.ConfirmUSBTransmission('State Machine Events');
            ThresholdsInTics = obj.degrees2pos(obj.thresholds);
            obj.Port.write(['T' length(ThresholdsInTics)], 'uint8', ThresholdsInTics, 'int16');
            obj.ConfirmUSBTransmission('Thresholds');
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
            Data = struct();
            
            if nPositions > 0
                Data = struct();
                Data.nPositions = double(nPositions);
                RawData = obj.Port.read(Data.nPositions*2, 'int32');
                PosData = RawData(1:2:end);
                TimeData = RawData(2:2:end);
                Data.Positions = obj.pos2degrees(PosData);
                Data.Times = double(TimeData)/1000;
            else
                Data.nPositions = 0;
                Data.Positions = [];
                Data.Times = [];
            end
        end
        function zeroPosition(obj)
            obj.Port.write('Z', 'uint8');
            if obj.uiStreaming
                obj.displayPositions(obj.displayPos) = NaN;
                obj.displayTimes(obj.displayPos) = NaN;
            end
        end
        function setPosition(obj, Pos)
            PositionTics = obj.degrees2pos(Pos);
            obj.Port.write('P', 'uint8', PositionTics, 'int16');
        end
        function enableThresholds(obj, ThresholdsEnabled)
            ThresholdEnabledBits = sum(ThresholdsEnabled.*2.^((0:length(ThresholdsEnabled)-1)));
            obj.Port.write([';' ThresholdEnabledBits], 'uint8');
        end
        function startUSBStream(obj)
            obj.acquiring = 1;
            obj.Port.write(['S' 1], 'uint8');
        end
        function NewData = readUSBStream(obj)
            if ~obj.acquiring
                error('Error: the USB stream must be started with startUSBStream() before you can read stream data from the buffer.')
            end
            BytesAvailable = obj.Port.bytesAvailable;
            NewData = struct;
            NewData.nPositions = 0;
            NewData.Positions = [];
            NewData.Times = [];
            if BytesAvailable > 5
                nBytesToRead = floor(BytesAvailable/6)*6;
                Message = obj.Port.read(nBytesToRead, 'uint8');
                NewData.nPositions = length(Message)/6;
                NewData.Positions = obj.pos2degrees(typecast(Message(obj.positionBytemask(1:6*NewData.nPositions)), 'int16'));
                NewData.Times = double(typecast(Message(obj.timeBytemask(1:6*NewData.nPositions)), 'uint32'))/1000;
            end
        end
        function stopUSBStream(obj)
            if obj.acquiring
                obj.Port.write(['S' 0], 'uint8');
                pause(.1);
                if obj.Port.bytesAvailable > 0
                    obj.Port.read(obj.Port.bytesAvailable, 'uint8');
                end
                obj.acquiring = 0;
            end
        end
        function streamUI(obj)
            obj.acquiring = 1;
            obj.uiStreaming = 1;
            BGColor = [0.8 0.8 0.8];
            thresholdColors = {[0 0 1], [1 0 0], [0 1 0], [1 1 0], [0 1 1], [1 0 1]}; 
            obj.displayPositions = nan(1,obj.nDisplaySamples);
            obj.displayTimes = nan(1,obj.nDisplaySamples);
            obj.gui.Fig  = figure('name','Position Stream', 'position',[100,100,800,500],...
                'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off',...
                'Color',BGColor, 'CloseRequestFcn', @(h,e)obj.endAcq());
            obj.gui.Plot = axes('units','pixels', 'position',[90,70,500,400]); 
            ylabel('Position (deg)', 'FontSize', 18); 
            xlabel('Time (s)', 'FontSize', 18);
            set(gca, 'xlim', [0 obj.maxDisplayTime], 'tickdir', 'out', 'FontSize', 12);
            if obj.wrapPoint > 0
                set(gca, 'ytick', [-obj.wrapPoint 0 obj.wrapPoint], 'ylim', [-obj.wrapPoint obj.wrapPoint]);
            else
                set(gca, 'ytick', [-180 0 180], 'ylim', [-180 180]);
            end
            Xdata = nan(1,obj.nDisplaySamples); Ydata = nan(1,obj.nDisplaySamples);
            obj.gui.StartLine = line([0,obj.maxDisplayTime],[0,0], 'Color', [.5 .5 .5]);
            nThresholds = length(obj.thresholds);
            obj.gui.ThreshLine = cell(1,nThresholds);
            for i = 1:nThresholds
                obj.gui.ThreshLine{i} = line([0,obj.maxDisplayTime],[NaN NaN], 'Color', thresholdColors{i}, 'LineStyle', ':');
            end
            obj.gui.OscopeDataLine = line([Xdata,Xdata],[Ydata,Ydata]);
            Ypos = 445;
            uicontrol('Style', 'text', 'Position', [600 Ypos 170 30], 'String', 'Behavior Events', 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor); Ypos = Ypos - 30;
            obj.gui.UseEventsCheckbox = uicontrol('Style', 'checkbox', 'Position', [610 Ypos 30 30], 'FontSize', 12,...
                'BackgroundColor', BGColor, 'Callback',@(h,e)obj.UIsetParams());
            uicontrol('Style', 'text', 'Position', [630 Ypos-5 60 30], 'String', 'Enable', 'FontSize', 12,...
                'BackgroundColor', BGColor); Ypos = Ypos - 45;
            Ypos = 370;
            uicontrol('Style', 'text', 'Position', [600 Ypos 180 30], 'String', 'Event Thresh (deg)', 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor); Ypos = Ypos - 45;
            
            uicontrol('Style', 'text', 'Position', [600 Ypos 30 30], 'String', '1:', 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor, 'ForegroundColor', thresholdColors{1});
            obj.gui.Threshold1Edit = uicontrol('Style', 'edit', 'Position', [630 Ypos+2 60 30], 'String', num2str(obj.thresholds(1)), 'FontSize', 14,...
                'FontWeight', 'bold', 'Enable', 'off', 'Callback',@(h,e)obj.UIsetParams());
            if nThresholds > 1
                uicontrol('Style', 'text', 'Position', [695 Ypos 30 30], 'String', '2:', 'FontSize', 14,...
                    'FontWeight', 'bold', 'BackgroundColor', BGColor, 'ForegroundColor', thresholdColors{2});
                obj.gui.Threshold2Edit = uicontrol('Style', 'edit', 'Position', [725 Ypos+2 60 30], 'String', num2str(obj.thresholds(2)), 'FontSize', 14,...
                    'FontWeight', 'bold', 'Enable', 'off', 'Callback',@(h,e)obj.UIsetParams());
            end
            Ypos = 225;
            obj.gui.ThresholdResetButton = uicontrol('Style', 'pushbutton', 'Position', [610 Ypos 175 30], 'String', 'Reset Thresholds', 'FontSize', 14,...
                    'FontWeight', 'bold','Callback',@(h,e)obj.enableThresholds(ones(1,nThresholds))); Ypos = Ypos + 50;
            obj.gui.ThresholdResetButton = uicontrol('Style', 'pushbutton', 'Position', [610 Ypos 175 30], 'String', 'Reset Position', 'FontSize', 14,...
                    'FontWeight', 'bold','Callback',@(h,e)obj.zeroPosition());
            Ypos = 175;
            uicontrol('Style', 'text', 'Position', [600 Ypos 150 30], 'String', 'Output Stream', 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor); Ypos = Ypos - 30;
            obj.gui.OutputStreamCheckbox = uicontrol('Style', 'checkbox', 'Position', [610 Ypos 30 30], 'FontSize', 12,...
                'BackgroundColor', BGColor, 'Callback',@(h,e)obj.UIsetParams(), 'Value', strcmp(obj.moduleOutputStream, 'on'));
            uicontrol('Style', 'text', 'Position', [630 Ypos-5 60 30], 'String', 'Enable', 'FontSize', 12,...
                'BackgroundColor', BGColor); Ypos = Ypos - 45;
            obj.displayPos = 1;
            obj.sweepStartTime = 0;
            drawnow;
            obj.Timer = timer('TimerFcn',@(h,e)obj.updatePlot(), 'ExecutionMode', 'fixedRate', 'Period', 0.05);
            obj.startUSBStream();
            start(obj.Timer);
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
            obj.stopUSBStream();
            obj.acquiring = 0;
            obj.uiStreaming = 0;
            delete(obj.gui.Fig);
        end
        function updatePlot(obj)
            newData = obj.readUSBStream;
            if ~isempty(newData.Positions)
                DisplayTime = (newData.Times(end)-obj.sweepStartTime);
                obj.displayPos = obj.displayPos + newData.nPositions;
                if DisplayTime >= obj.maxDisplayTime
                    obj.displayPositions(1:obj.displayPos) = NaN;
                    obj.displayTimes(1:obj.displayPos) = NaN;
                    obj.displayPos = 1;
                    obj.sweepStartTime = newData.Times(end);
                else
                    SweepTimes = newData.Times-obj.sweepStartTime;
                    newData.Positions(newData.Positions == obj.wrapPoint) = NaN;
                    obj.displayPositions(obj.displayPos-newData.nPositions+1:obj.displayPos) = newData.Positions;
                    obj.displayTimes(obj.displayPos-newData.nPositions+1:obj.displayPos) = SweepTimes;
                end
                set(obj.gui.OscopeDataLine,'xdata',[obj.displayTimes, obj.displayTimes], 'ydata', [obj.displayPositions, obj.displayPositions]); drawnow;
            end
        end
        function UIsetParams(obj)
            obj.Port.write('X', 'uint8');
            stop(obj.Timer);
            pause(.1);
            nBytesAvailable = obj.Port.bytesAvailable;
            if (nBytesAvailable > 0)
                obj.Port.read(nBytesAvailable, 'uint8');
            end
            nThresholds = length(obj.thresholds);
            newThreshold1 = str2double(get(obj.gui.Threshold1Edit, 'String'));
            obj.thresholds(1) = newThreshold1; 
            if nThresholds > 1
                newThreshold2 = str2double(get(obj.gui.Threshold2Edit, 'String'));
                obj.thresholds(2) = newThreshold2; 
            end
            useEvents = get(obj.gui.UseEventsCheckbox, 'Value');
            if useEvents
                set(obj.gui.Threshold1Edit, 'enable', 'on');           
                set(obj.gui.ThreshLine{1}, 'Ydata', [obj.thresholds(1),obj.thresholds(1)]);
                if nThresholds > 1
                    set(obj.gui.Threshold2Edit, 'enable', 'on');
                    set(obj.gui.ThreshLine{2}, 'Ydata', [obj.thresholds(2),obj.thresholds(2)]);
                end
            else
                set(obj.gui.Threshold1Edit, 'enable', 'off');
                set(obj.gui.ThreshLine{1}, 'Ydata', [NaN NaN]);
                if nThresholds > 1
                    set(obj.gui.Threshold2Edit, 'enable', 'off');
                    set(obj.gui.ThreshLine{2}, 'Ydata', [NaN NaN]);
                end
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
                    obj.sendThresholdEvents = 'off';
                    obj.enableThresholds(zeros(1,length(obj.thresholds)));
                case 1
                    obj.sendThresholdEvents = 'on';
                    obj.enableThresholds(ones(1,length(obj.thresholds)));
            end
            switch useOutputStream
                case 0
                    obj.moduleOutputStream = 'off';
                case 1
                    obj.moduleOutputStream = 'on';
            end
            obj.Port.write(['S' 1], 'uint8');
            start(obj.Timer);
        end
        function degrees = pos2degrees(obj, pos)
            degrees = round(((double(pos)/512)*180)*10)/10;
        end
        function pos = degrees2pos(obj, degrees)
            pos = int16((degrees./180).*512);
        end
        function ConfirmUSBTransmission(obj,ParamName)
            Confirm = obj.Port.read(1, 'uint8');
            if Confirm ~= 1
                error(['Error while updating ' ParamName '. RotaryEncoderModule did not return a confirmation byte.'])
            end
        end
    end
end