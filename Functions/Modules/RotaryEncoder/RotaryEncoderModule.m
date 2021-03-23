%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2018 Sanworks LLC, Stony Brook, New York, USA

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

% The Rotary Encoder Module interfaces a quadrature rotary encoder with
% MATLAB via USB. It also enables rapid communication of threshold
% crossings to the Bpod State Machine (v0.7+), and streaming of position data
% to other Bpod modules.
%
% Installation:
% 1. Install PsychToolbox from: http://psychtoolbox.org/download/
% 2. Install Bpod Gen2 from https://github.com/sanworks/Bpod_Gen2, and add
%    the repository root folder to the MATLAB path
% 3. Connect the rotary encoder module to a free serial port on Bpod with a CAT6 cable
% 4. Connect the rotary encoder module to the computer with a USB micro cable.
%
% - Create a RotaryEncoderModule object with R = RotaryEncoderModule('COMx') where COMx is your serial port string
% - Directly manipulate its fields to change trial parameters on the device.
% - Run R.streamUI to see streaming output (for testing purposes)
% - Run P = R.currentPosition to return the current encoder position (for testing purposes).
% - Other methods can be viewed with methods(R), and documentation is on the Bpod wiki at: 
% https://sites.google.com/site/bpoddocumentation/bpod-user-guide/function-reference-beta/rotaryencodermodule

classdef RotaryEncoderModule < handle
    properties
        Port % ArCOM Serial port
        thresholds = [-40 40]; % Encoder position thresholds, in degrees, used to generate behavior events
        wrapPoint = 180; % Point at which position wraps around, in degrees. Set to 0 to inactivate wrapping.
        wrapMode = 'bipolar'; % 'bipolar' (position wraps to negative value) or 'unipolar' (wraps to 0) 
        sendThresholdEvents = 'off'; % Set to 'on' to send threshold crossing events to the Bpod state machine
        moduleOutputStream = 'off'; % Set to 'on' to stream position data directly to another Bpod module
        moduleStreamPrefix = 'M'; % The byte that precedes each position in the module output stream
    end
    properties (Access = private)
        Timer % MATLAB timer (for updating the UI)
        acquiring = 0; % 0 if idle, 1 if streaming data to serial buffer
        uiStreaming = 0; % 1 if streaming data to UI
        gui = struct; % Handles for GUI elements
        positionBytemask = logical(repmat([1 1 0 0 0 0], 1, 10000)); % For parsing data coming back from encoder
        timeBytemask = logical(repmat([0 0 1 1 1 1], 1, 10000));
        nDisplaySamples = 1000; % When streaming to plot, show up to 1,000 samples
        maxDisplayTime = 10; % When streaming to plot, show up to last 10 seconds
        displayPos = 1; % Current position on UI plot
        sweepStartTime = 0; % Time current UI sweep started
        displayPositions % UI y data
        displayTimes % UI x data
        UIResetScheduled = 0; % 1 if a sweep should start the next time data arrives due to manual reset, 0 if not
        autoSync = 1; % If 1, update params on device when parameter fields change. If 0, don't.
        validWrapModes = {'bipolar', 'unipolar'};
        wrapModeByte = 1; % current wrap mode position in validWrapModes
        NewDataTemplate = struct; % Template struct for new data (copied when streaming data is read to save time)
        isLogging = 0; % True if logging to microSD card, false if not
        maxThresholds = 8; % Maximum number of currently supported thresholds
        usbCaptureEnabled = 0; % If 1, a timer object checks the serial port for new data every 0.1s and appends it to usbCapturedData
        usbCapturedData = []; % Stores streaming data if usbCaptureEnabled = 1
        rollOverSum = 0; % If 32-bit micros() clock has rolled over since stream or log reset, this gets incremented by 2^32
        LastTimeRead = 0; % Last timestamp read from the device
    end
            
    methods
        function obj = RotaryEncoderModule(portString)
            % Destroy any orphaned timers from previous instances
            T = timerfindall;
            for i = 1:length(T)
                thisTimer = T(i);
                thisTimerTag = get(thisTimer, 'tag');
                if strcmp(thisTimerTag, ['RE_' portString])
                    warning('off');
                    delete(thisTimer);
                    warning('on');
                end
            end
            % Create ArCOM wrapper for USB communication with Teensy
            obj.Port = ArCOMObject_Bpod(portString, 115200);
            obj.Port.write('CX', 'uint8'); % C = handshake, X = reset data streams
            response = obj.Port.read(1, 'uint8');
            if response ~= 217
                error('Could not connect =( ')
            end
            obj.resetParams();
            obj.displayPositions = nan(1,obj.nDisplaySamples); % UI y data
            obj.displayTimes = nan(1,obj.nDisplaySamples); % UI x data
            % Set up template struct for new streaming data
            obj.NewDataTemplate.nPositions = 0;
            obj.NewDataTemplate.Positions = zeros(1,1000);
            obj.NewDataTemplate.Times = zeros(1,1000);
            obj.NewDataTemplate.nEvents = 0;
            obj.NewDataTemplate.EventTypes = uint8(zeros(1,1000));
            obj.NewDataTemplate.EventCodes = uint8(zeros(1,1000));
            obj.NewDataTemplate.EventTimestamps = zeros(1,1000);
        end
        
        function pos = currentPosition(obj)
            obj.assertNotUSBStreaming;
            obj.Port.write('Q', 'uint8');
            pos = obj.pos2degrees(obj.Port.read(1, 'int16'));
        end
        function set.thresholds(obj, newThresholds)
            obj.assertNotUSBStreaming;
            if sum(abs(newThresholds) > obj.wrapPoint) > 0
                error(['Error: thresholds cannot exceed the rotary encoder''s current wrap point: ' num2str(obj.wrapPoint) ' degrees.'])
            end
            if length(newThresholds) > obj.maxThresholds
                error(['Error: the current software supports only ' num2str(obj.maxThresholds) ' thresholds.']);
            end
            ThresholdsInTics = obj.degrees2pos(newThresholds);
            obj.Port.write(['T' length(ThresholdsInTics)], 'uint8', ThresholdsInTics, 'int16');
            obj.ConfirmUSBTransmission('Thresholds');
            obj.thresholds = newThresholds;
        end
        function set.moduleOutputStream(obj, stateString)
            obj.assertNotUSBStreaming;
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
            obj.assertNotUSBStreaming;
            if (length(Prefix) > 1) || (~ischar(Prefix))
                error('Error setting output stream prefix; Prefix must be a single character.')
            end
            obj.Port.write(['I' Prefix], 'uint8');
            obj.ConfirmUSBTransmission('Module Output Stream Prefix');
        end
        function set.wrapPoint(obj, newWrapPoint)
            obj.assertNotUSBStreaming;
            newWrapPointTics = obj.degrees2pos(newWrapPoint);
            obj.Port.write('W', 'uint8', newWrapPointTics, 'int16');
            obj.ConfirmUSBTransmission('Module Wrap Point');
            obj.wrapPoint = newWrapPoint;
        end
        function set.wrapMode(obj, newWrapMode)
            obj.assertNotUSBStreaming;
            newWrapModeValue = find(strcmpi(newWrapMode, obj.validWrapModes));
            if isempty(newWrapModeValue)
                ErrMsg = ['Error: Invalid wrap mode: ' newWrapMode '. Valid wrap modes are: ''unipolar'', ''bipolar'''];
                error(ErrMsg)
            end
            
            obj.Port.write(['M' newWrapModeValue-1], 'uint8');
            obj.ConfirmUSBTransmission('Wrap Mode');
            obj.wrapModeByte = newWrapModeValue;
            obj.wrapMode = newWrapMode;
        end
        function set.sendThresholdEvents(obj, stateString)
            obj.assertNotUSBStreaming;
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
        function startLogging(obj)
            obj.Port.write('L', 'uint8');
            obj.isLogging = 1;
        end
        function stopLogging(obj)
                obj.Port.write('F', 'uint8');
                obj.isLogging = 0;
        end
        function Data = getLoggedData(obj)
            if obj.uiStreaming == 1
                stop(obj.Timer);
                obj.stopUSBStream;
            end
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
                Data.Times = double(TimeData)/1000000;
                RolloverPoints = find(diff(Data.Times) < 0)+1;
                nRolloverPoints = length(RolloverPoints);
                rolloverVal = 0;
                for i = 1:nRolloverPoints
                    rolloverVal = rolloverVal + 4294967296;
                    if i < nRolloverPoints
                        Data.Times(RolloverPoints(i):RolloverPoints(i+1)-1) = Data.Times(RolloverPoints(i):RolloverPoints(i+1)-1) + rolloverVal;
                    else
                        Data.Times(RolloverPoints(i):end) = Data.Times(RolloverPoints(i):end) + rolloverVal;
                    end
                end
            else
                Data.nPositions = 0;
                Data.Positions = [];
                Data.Times = [];
            end
            if obj.uiStreaming == 1
                obj.startUSBStream;
                start(obj.Timer);
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
            obj.ConfirmUSBTransmission('Rotary Encoder Position');
        end
        function enableThresholds(obj, ThresholdsEnabled)
            ThresholdEnabledBits = sum(ThresholdsEnabled.*2.^((0:length(ThresholdsEnabled)-1)));
            obj.Port.write([';' ThresholdEnabledBits], 'uint8');
        end
        function startUSBStream(obj, varargin)
            if obj.acquiring == 0
                if obj.isLogging == 0
                    obj.acquiring = 1;
                    obj.Port.write(['S' 1], 'uint8');
                    obj.LastTimeRead = 0;
                    obj.rollOverSum = 0;
                    if nargin > 1
                        op = varargin{1};
                        switch lower(op)
                            case 'usetimer'
                                obj.usbCaptureEnabled = 1;
                                obj.Timer = timer('TimerFcn',@(h,e)obj.captureUSBStream(), 'ExecutionMode', 'fixedRate', 'Period', 0.1, 'Tag', ['RE_' obj.Port.PortName]);
                                start(obj.Timer);
                            otherwise
                                error(['Error starting rotary encoder USB stream: Invalid argument ' op '. Valid arguments are: ''UseTimer'''])
                        end
                                
                    end
                else
                    error('Error: The Rotary Encoder Module is logging to microSD. Turn off logging with stopLogging() to enable USB streaming.')
                end
            end
        end
        function NewData = readUSBStream(obj)
            NewData = obj.getUSBStream;
            if obj.usbCaptureEnabled == 1
                obj.usbCapturedData = obj.appendStreamData(obj.usbCapturedData, NewData);
                NewData = obj.usbCapturedData;
                obj.usbCapturedData = [];
            end
        end
        function OutData = appendStreamData(obj, StreamData, NewData)
            if isfield(StreamData, 'nPositions')
                StreamData.nPositions = StreamData.nPositions + NewData.nPositions;
                StreamData.nEvents = StreamData.nEvents + NewData.nEvents;
                StreamData.Positions = [StreamData.Positions NewData.Positions];
                StreamData.Times = [StreamData.Times NewData.Times];
                StreamData.EventTypes = [StreamData.EventTypes NewData.EventTypes];
                StreamData.EventCodes = [StreamData.EventCodes NewData.EventCodes];
                StreamData.EventTimestamps = [StreamData.EventTimestamps NewData.EventTimestamps];
                OutData = StreamData;
            else
                OutData = NewData;
            end
        end
        function stopUSBStream(obj)
            if obj.usbCaptureEnabled == 1
                obj.usbCaptureEnabled = 0;
                obj.usbCapturedData = [];
                stop(obj.Timer);
                delete(obj.Timer);
                obj.Timer = [];
            end
            if obj.acquiring
                obj.Port.write(['S' 0], 'uint8');
                pause(.05);
                if obj.Port.bytesAvailable > 0
                    obj.Port.read(obj.Port.bytesAvailable, 'uint8');
                end
                obj.acquiring = 0;
            end
        end
        function streamUI(obj)
            if obj.isLogging == 1
                error('Error: The Rotary Encoder Module is logging to microSD. Turn off logging with stopLogging() to enable USB streaming.')
            end
            if obj.uiStreaming == 0
                obj.uiStreaming = 1;
                BGColor = [0.8 0.8 0.8];
                thresholdColors = {[0 0 1], [1 0 0], [0 1 0], [1 1 0], [0 1 1],...
                    [1 0 1], [0.5 0 0], [0 0.5 0]}; 
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
                    if obj.wrapModeByte == 1
                      set(gca, 'ytick', [-obj.wrapPoint 0 obj.wrapPoint], 'ylim', [-obj.wrapPoint obj.wrapPoint]);
                    elseif obj.wrapModeByte == 2
                      set(gca, 'ytick', [0 obj.wrapPoint], 'ylim', [0 obj.wrapPoint]);  
                    end
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
                uicontrol('Style', 'text', 'Position', [600 Ypos 170 30], 'String', 'Threshold Events', 'FontSize', 14,...
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
            else
                error('Error: A rotary encoder streamUI window is already open. Please close it and try again.');
            end
        end
        function showThresholds(obj, State)
            if State == 1
                obj.updateThresh(1);
            else
                obj.updateThresh(0);
            end
        end
        function clearUI(obj) % Clears data shown on UI (does not reset current sweep)
            obj.displayPositions(1:obj.displayPos) = NaN;
            obj.displayTimes(1:obj.displayPos) = NaN;
            set(obj.gui.OscopeDataLine,'xdata',[obj.displayTimes, obj.displayTimes], 'ydata', [obj.displayPositions, obj.displayPositions]); drawnow;
            obj.UIResetScheduled = 1;
        end
        function delete(obj)
            obj.stopUSBStream;
            obj.stopLogging;
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
        function captureUSBStream(obj)
            newData = obj.readUSBStream;
            if (newData.nEvents > 0) || (newData.nPositions > 0)
                obj.usbCapturedData = obj.appendStreamData(obj.usbCapturedData, newData);
            end
        end
        function updatePlot(obj)
            newData = obj.getUSBStream;
            if ~isempty(newData.Positions)
                DisplayTime = (newData.Times(end)-obj.sweepStartTime);
                obj.displayPos = obj.displayPos + newData.nPositions;
                if (DisplayTime >= obj.maxDisplayTime) || (obj.UIResetScheduled == 1)
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
                obj.UIResetScheduled = 0;
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
            obj.acquiring = 0;
            nThresholds = length(obj.thresholds);
            newThreshold1 = str2double(get(obj.gui.Threshold1Edit, 'String'));
            obj.thresholds(1) = newThreshold1; 
            if nThresholds > 1
                newThreshold2 = str2double(get(obj.gui.Threshold2Edit, 'String'));
                obj.thresholds(2) = newThreshold2; 
            end
            useEvents = get(obj.gui.UseEventsCheckbox, 'Value');
            if useEvents
                obj.updateThresh(1);
            else
                obj.updateThresh(0);
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
            obj.acquiring = 1;
            start(obj.Timer);
        end
        function updateThresh(obj,State)
            nThresholds = length(obj.thresholds);
            if State == 1
                 set(obj.gui.Threshold1Edit, 'enable', 'on');
                 set(obj.gui.ThreshLine{1}, 'Ydata', [obj.thresholds(1),obj.thresholds(1)]);
                if nThresholds > 1
                    set(obj.gui.Threshold2Edit, 'enable', 'on');
                    set(obj.gui.ThreshLine{2}, 'Ydata', [obj.thresholds(2),obj.thresholds(2)]);
                end
                if nThresholds > 2
                    for i = 3:nThresholds
                        set(obj.gui.ThreshLine{i}, 'Ydata', [obj.thresholds(i),obj.thresholds(i)]);
                    end
                end
            else
                set(obj.gui.Threshold1Edit, 'enable', 'off');
                set(obj.gui.ThreshLine{1}, 'Ydata', [NaN NaN]);
                if nThresholds > 1
                    set(obj.gui.Threshold2Edit, 'enable', 'off');
                    set(obj.gui.ThreshLine{2}, 'Ydata', [NaN NaN]);
                end
                if nThresholds > 2
                    for i = 3:nThresholds
                        set(obj.gui.ThreshLine{i}, 'Ydata', [NaN NaN]);
                    end
                end
            end
        end
        function NewData = getUSBStream(obj)
            if ~obj.acquiring
                error('Error: the USB stream must be started with startUSBStream() before you can read stream data from the buffer.')
            end
            NewData = obj.NewDataTemplate;
            nNewDataPoints = 0;
            nNewEvents = 0;
            nBytesAvailable = obj.Port.bytesAvailable;
            if (nBytesAvailable > 6)
                
                msgSize = 7*floor(nBytesAvailable/7); % Only read complete messages
                Msg = obj.Port.read(msgSize, 'uint8');
                MsgInd = 1;
                while MsgInd < length(Msg)
                    thisOp = Msg(MsgInd);
                    switch thisOp
                        case 'P' % Position  
                            MsgInd = MsgInd + 1;
                            Positions = Msg(MsgInd:MsgInd+5);
                            MsgInd = MsgInd + 6;
                            NewData.nPositions = NewData.nPositions + 1;
                            nNewDataPoints = nNewDataPoints + 1;
                            NewData.Positions(nNewDataPoints) = obj.pos2degrees(typecast(Positions(obj.positionBytemask(1:6)), 'int16'));
                            NewTime = double(typecast(Positions(obj.timeBytemask(1:6)), 'uint32'))/1000000;
                            if obj.LastTimeRead > NewTime;
                                obj.rollOverSum = obj.rollOverSum + 4294.967296;
                            end
                            obj.LastTimeRead = NewTime;
                            NewData.Times(nNewDataPoints) = NewTime + obj.rollOverSum;
                        case 'E' % Event
                            MsgInd = MsgInd + 1;
                            EventData = Msg(MsgInd:MsgInd+5);
                            nNewEvents = nNewEvents + 1;
                            MsgInd = MsgInd + 6;
                            NewData.nEvents = NewData.nEvents + 1;
                            NewData.EventTypes(nNewEvents) = EventData(1);
                            NewData.EventCodes(nNewEvents) = EventData(2);
                            NewTime = double(typecast(EventData(3:end), 'uint32'))/1000000;
                            if obj.LastTimeRead > NewTime;
                                obj.rollOverSum = obj.rollOverSum + 4294.967296;
                            end
                            obj.LastTimeRead = NewTime;
                            NewData.EventTimestamps(nNewEvents) = NewTime + obj.rollOverSum;
                    end
                end
                if nNewDataPoints > 0
                    NewData.Positions = NewData.Positions(1:nNewDataPoints);
                    NewData.Times = NewData.Times(1:nNewDataPoints);
                else
                    NewData.Positions = [];
                    NewData.Times = [];
                end
                if nNewEvents > 0
                    NewData.EventTypes = NewData.EventTypes(1:nNewEvents);
                    NewData.EventCodes = NewData.EventCodes(1:nNewEvents);
                    NewData.EventTimestamps = NewData.EventTimestamps(1:nNewEvents);
                else
                    NewData.EventTypes = [];
                    NewData.EventCodes = [];
                    NewData.EventTimestamps = [];
                end
            else
                NewData.Positions = [];
                NewData.Times = [];
                NewData.EventTypes = [];
                NewData.EventCodes = [];
                NewData.EventTimestamps = [];
            end
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
        function assertNotUSBStreaming(obj)
            if obj.acquiring == 1
                error('Error: Cannot access rotary encoder module while USB streaming is active. Stop the stream first with stopUSBStream().')
            end
        end
        function resetParams(obj)
            obj.thresholds = [-40 40];
            obj.wrapPoint = 180;
            obj.wrapMode = 'bipolar';
            obj.sendThresholdEvents = 'off';
            obj.moduleOutputStream = 'off';
            obj.moduleStreamPrefix = 'M';
        end
    end
end