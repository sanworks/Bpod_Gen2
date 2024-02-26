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

% RotaryEncoderModule is a class to interface with the Bpod Rotary Encoder Module
% via its USB connection to the PC.
%
% User-configurable device parameters are exposed as class properties. Setting
% the value of a property will trigger its 'set' method to update the device.

% Docs:
% https://sanworks.github.io/Bpod_Wiki/module-documentation/rotary-encoder-module/
% Additional documentation of properties and methods is given in-line below.

% Usage Notes:
% - Create a RotaryEncoderModule object with R = RotaryEncoderModule('COMx') where COMx is your serial port string
% - Directly manipulate its fields to change trial parameters on the device.
% - Run R.streamUI to see streaming output (for testing purposes)
% - Run P = R.currentPosition to return the current encoder position (for testing purposes).
% - Other methods can be viewed with methods(R), and documentation is on the Bpod wiki at: 
%   https://sanworks.github.io/Bpod_Wiki/module-documentation/rotary-encoder-module/

classdef RotaryEncoderModule < handle
    properties
        Port % ArCOM Serial port
        thresholds = [-40 40]; % Encoder position thresholds, in degrees, used to generate behavior events
        wrapPoint = 180; % Point at which position wraps around, in degrees. Set to 0 to inactivate wrapping.
        wrapMode = 'bipolar'; % 'bipolar' (position wraps to negative value) or 'unipolar' (wraps to 0) 
        sendThresholdEvents = 'off'; % Set to 'on' to send threshold crossing events to the Bpod state machine
        moduleOutputStream = 'off'; % Set to 'on' to stream position data directly to another Bpod module (HW version 1 only)
        moduleStreamPrefix = 'M'; % The byte that precedes each position in the module output stream (HW version 1 only)
        userCallbackFcn = ''; % The name of a user-created callback function run when new data is available. The most recent encoder position is the input arg. 
                              % Can be used to map wheel position to a stimulus (albeit with a ~100Hz refresh rate, and NOT with the FSM's timing precision)
        useAdvancedThresholds = 'off'; % If on (HW version 2 or newer) advanced thresholds are used, and thresholds property is ignored.
                                       % Advanced thresholds are configured with setAdvancedThresholds() and
                                       % made current with push() from MATLAB or the '*' command from the state machine
    end
    properties (Access = private)
        Timer % MATLAB timer (for reading data from the serial buffer during USB streaming)
        timerInterval = 0.1; % Interval between serial buffer reads. This also determines the frequency of the user callback (used to control a stimulus).
        userCallbackFcnSet = 0; % 1 if obj.userCallbackFcn is set, 0 if not
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
        uiResetScheduled = 0; % 1 if a sweep should start the next time data arrives due to manual reset, 0 if not
        autoSync = 1; % If 1, update params on device when parameter fields change. If 0, don't.
        validWrapModes = {'bipolar', 'unipolar'};
        wrapModeByte = 1; % current wrap mode position in validWrapModes
        newDataTemplate = struct; % Template struct for new data (copied when streaming data is read to save time)
        isLogging = 0; % True if logging to microSD card, false if not
        maxThresholds = 8; % Maximum number of currently supported thresholds
        usbCaptureEnabled = 0; % If 1, a timer object checks the serial port for new data every 0.1s and appends it to usbCapturedData
        usbCapturedData = []; % Stores streaming data if usbCaptureEnabled = 1
        rollOverSum = 0; % If 32-bit micros() clock has rolled over since stream or log reset, this gets incremented by 2^32
        lastTimeRead = 0; % Last timestamp read from the device
        hardwareVersion = 0; % Major version of the connected hardware
        halfPoint = 512; % Half of total positions per revolution (depends both on encoder and encoding method)
        thresholdType = 0; % 0 = standard (legacy, default), 1 = advanced, see comment of useAdvancedThresholds property above
        hardwareTimerInterval = 0.0001; % seconds, currently fixed in firmware
    end
            
    methods
        function obj = RotaryEncoderModule(portString)
            % Constructor

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

            % Create ArCOM wrapper for USB communication
            obj.Port = ArCOMObject_Bpod(portString, 12000000);
            obj.Port.write('CX', 'uint8'); % C = handshake, X = reset data streams
            response = obj.Port.read(1, 'uint8');
            if response ~= 217
                error('Rotary encoder module returned an incorrect handshake byte.')
            end

            % Check for hardware version 2
            obj.Port.write('IM', 'uint8');
            reply = obj.Port.read(1, 'uint8');
            obj.hardwareVersion = 1;
            if reply == 0
                obj.hardwareVersion = 2;
                obj.halfPoint = 2048;
                % If HW version 2, restart serial port with Teensy 4's correct baud rate --> buffer sizes
                obj.Port = [];
                pause(.2);
                obj.Port = ArCOMObject_Bpod(portString, 480000000);
            end

            % Reset parameters
            obj.resetParams();
            obj.displayPositions = nan(1,obj.nDisplaySamples); % UI y data
            obj.displayTimes = nan(1,obj.nDisplaySamples); % UI x data

            % Set up template struct for new streaming data
            obj.newDataTemplate.nPositions = 0;
            obj.newDataTemplate.Positions = zeros(1,1000);
            obj.newDataTemplate.Times = zeros(1,1000);
            obj.newDataTemplate.nEvents = 0;
            obj.newDataTemplate.EventTypes = uint8(zeros(1,1000));
            obj.newDataTemplate.EventCodes = uint16(zeros(1,1000));
            obj.newDataTemplate.EventTimestamps = zeros(1,1000);
        end
        
        function pos = currentPosition(obj)
            % Return the current position
            % Arguments: None
            % Returns: pos, the shaft position in degrees

            if obj.acquiring == 1
                stop(obj.Timer);
                obj.captureUSBStream; % Push latest data to buffer
                pos = obj.usbCapturedData.Positions(end);
                start(obj.Timer);
            else
                obj.Port.write('Q', 'uint8');
                pos = obj.pos2degrees(obj.Port.read(1, 'int16'));
            end
        end

        function set.userCallbackFcn(obj, newFcn)
            % Set a user function to call each time new data is returned during USB streaming.
            % Arguments:
            % newFcn (char array) the name of the function to call. 
            % Note: The user function will be called with a single input argument, the most recent position captured.

            if obj.acquiring == 1
                error('The Rotary Encoder Module''s user callback function cannot be set while streaming is active.')
            end
            if ~ischar(newFcn)
                error('The Rotary Encoder Module''s user callback function must be a character array.')
            end
            if isempty(which(newFcn))
                error(['Error setting Rotary Encoder Module user callback function: ' newFcn ' is not a function in the MATLAB path.'])
            end
            if isempty(newFcn)
                obj.userCallbackFcnSet = 0;
                obj.timerInterval = 0.1;
            else
                obj.userCallbackFcnSet = 1;
                obj.timerInterval = 0.01; % Callback can run at up to 100Hz. Exact timing depends on other processing, and is not guaranteed
                obj.usbCaptureEnabled = 1;        
            end
            obj.userCallbackFcn = newFcn;
        end

        function set.thresholds(obj, newThresholds)
            % Set the position thresholds for generating behavioral events
            % Arguments: newThresholds, a 1xnThresholds array of positions (units = degrees)

            if obj.thresholdType == 0
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
            else
                if ~ischar(newThresholds)
                    error('Thresholds must be set using the setAdvancedThresholds() method if useAdvancedThresholds is set to ''on''')
                end
            end
            obj.thresholds = newThresholds;
        end

        function set.moduleOutputStream(obj, stateString)
            % Enable / Disable sending position data directly to another Bpod module 
            % via the 'Output Stream' jack
            % Parameters: stateString (char array): 'on' or 'off'

            if obj.hardwareVersion == 1
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
        end

        function set.useAdvancedThresholds(obj, stateString)
                % Enable / Disable advanced threshold mode. 
                % In the default mode, thresholds are positions that take effect immediately when updated. 
                % Advanced thresholds include more configuration options,and the next trial's thresholds can 
                % be sent to the device without taking effect until the next trial starts.
                % Parameters: stateString (char array): 'on' or 'off'

                obj.assertNotUSBStreaming;
                stateString = lower(stateString);
                if obj.autoSync
                    switch stateString
                        case 'off'
                            obj.thresholdType = 0;
                            obj.thresholds = [-40 40];
                        case 'on'
                            if obj.hardwareVersion == 1
                                error('Error: Advanced thresholds require rotary encoder module v2 or newer');
                            end
                            obj.thresholdType = 1;
                            obj.thresholds = '<Advanced Thresholds>';
                        otherwise
                            error('Error setting useAdvancedThresholds; value must be ''on'' or ''off''');
                    end
                end
                obj.useAdvancedThresholds = stateString;
        end

        function set.moduleStreamPrefix(obj, prefix)
            % Set the module-to-module output data stream prefix, a command byte
            % sent immediately prior to each sample
            % Arguments: prefix, the command byte.

            if obj.hardwareVersion == 1
                obj.assertNotUSBStreaming;
                if (length(prefix) > 1) || (~ischar(prefix))
                    error('Error setting output stream prefix; Prefix must be a single character.')
                end
                obj.Port.write(['I' prefix], 'uint8');
                obj.ConfirmUSBTransmission('Module Output Stream Prefix');
            end
        end

        function set.wrapPoint(obj, newWrapPoint)
            % Set the position at which the position value wraps around.
            % This can be used to set thresholds at positions larger than 1 revolution.
            % Arguments: newWrapPoint (degrees)

            obj.assertNotUSBStreaming;
            newWrapPointTics = obj.degrees2pos(newWrapPoint);
            obj.Port.write('W', 'uint8', newWrapPointTics, 'int16');
            obj.ConfirmUSBTransmission('Module Wrap Point');
            obj.wrapPoint = newWrapPoint;
        end

        function set.wrapMode(obj, newWrapMode)
            % Set unipolar or bipolar wrap mode.
            % Unipolar: positive positions only, wrapping returns to 0
            % Bipolar: positive and negative positions, starting at 0 wrapping from positive goes to negative.
            % Arguments: newWrapMode (char array) - 'unipolar' or 'bipolar'

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
            % Enable/Disable sending threshold-crossing events to the Bpod State Machine
            % Arguments: stateString (char array) 'on' or 'off'

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

        function setAdvancedThresholds(obj, thresholds, varargin)
            % Syntax: setAdvancedThresholds(thresholds, [thresholdTypes], [thresholdTimes]) where [] is an optional argument.
            %         thresholds = a value in degrees for each threshold, up to 8 thresholds maximum
            %         thresholdTypes = 0 (Threshold reached when position crossed), 1 (After enable, threshold reached after Time spent within +/- position)
            %         thresholdTimes = a value in seconds for computing threshold type 1. Ignored if thresholdTypes == 0
            %         If thresholdType = 1, a non-zero thresholdTime must be specified.
            %         Thresholds programmed with setAdvancedThresholds() are not current on the module until the next push command ('*' from the state machine)

            if obj.thresholdType == 0
                error('useAdvancedThresholds must be set to ''on'' to set advanced thresholds');
            end
            nThresholds = length(thresholds);
            thresholdTypes = zeros(1,nThresholds);
            thresholdTimes = zeros(1,nThresholds);
            if nargin > 2
                thresholdTypes = varargin{1};
                if length(thresholdTypes) ~= nThresholds
                    error('Incorrect number of threshold types. Exactly one threshold type for each rotary encoder threshold must be specified.');
                end
                if sum(thresholdTypes>1) > 0 || sum(thresholdTypes<0) > 0
                    error('Error: threshold types must be 0 or 1')
                end
            end
            if nargin > 3
                thresholdTimes = varargin{2};
                if length(thresholdTimes) ~= nThresholds
                    error('Incorrect number of threshold times. Exactly one threshold time for each rotary encoder threshold must be specified.');
                end
                if sum(thresholdTimes <= 0 & thresholdTypes == 1) > 0
                    error('Rotary encoder threshold times must be positive durations, specified in seconds');
                end
                thresholdTimes = thresholdTimes/obj.hardwareTimerInterval;
            end
            thresholdsInTics = obj.degrees2pos(thresholds);
            obj.Port.write(['t' nThresholds thresholdTypes], 'uint8', thresholdsInTics, 'int16', thresholdTimes, 'uint32');
        end

        function push(obj) 
            % In advanced threshold mode, push() makes newly loaded thresholds current

            obj.Port.write('*', 'uint8');
        end

        function startLogging(obj)
            % Start logging position to the microSD card (hardware v1 only)

            if obj.hardwareVersion == 2
                error('Error: microSD logging is not available on Rotary Encoder Module v2');
            end
            obj.Port.write('L', 'uint8');
            obj.isLogging = 1;
        end

        function stopLogging(obj)
            % Stop logging position to the microSD card (hardware v1 only)

            if obj.hardwareVersion == 2
                error('Error: microSD logging is not available on Rotary Encoder Module v2');
            end
            obj.Port.write('F', 'uint8');
            obj.isLogging = 0;
        end

        function data = getLoggedData(obj)
            % Return position data logged to microSD between calls to startLogging() and
            % stopLogging(). Hardware v1 only.
            % Arguments: None
            % Returns: data, a struct with fields:
            %          nPositions, the number of positions acquired
            %          Positions, the positions captured
            %          Times, a timestamp for each position, measured by the Rotary Encoder Module clock

            if obj.hardwareVersion == 2
                error('Error: microSD logging is not available on Rotary Encoder Module v2');
            end
            if obj.uiStreaming == 1
                stop(obj.Timer);
                obj.stopUSBStream;
            end
            obj.Port.write('R', 'uint8');
            nPositions = obj.Port.read(1, 'uint32');
            data = struct();
            if nPositions > 0
                data = struct();
                data.nPositions = double(nPositions);
                rawData = obj.Port.read(data.nPositions*2, 'int32');
                posData = rawData(1:2:end);
                timeData = rawData(2:2:end);
                data.Positions = obj.pos2degrees(posData);
                data.Times = double(timeData)/1000000;
                rolloverPoints = find(diff(data.Times) < 0)+1;
                nRolloverPoints = length(rolloverPoints);
                rolloverVal = 0;
                for i = 1:nRolloverPoints
                    rolloverVal = rolloverVal + 4294967296;
                    if i < nRolloverPoints
                        data.Times(rolloverPoints(i):rolloverPoints(i+1)-1) = data.Times(rolloverPoints(i):rolloverPoints(i+1)-1) + rolloverVal;
                    else
                        data.Times(rolloverPoints(i):end) = data.Times(rolloverPoints(i):end) + rolloverVal;
                    end
                end
            else
                data.nPositions = 0;
                data.Positions = [];
                data.Times = [];
            end
            if obj.uiStreaming == 1
                obj.startUSBStream;
                start(obj.Timer);
            end
        end

        function zeroPosition(obj)
            % Set the current position to 0

            obj.Port.write('Z', 'uint8');
            if obj.uiStreaming
                obj.displayPositions(obj.displayPos) = NaN;
                obj.displayTimes(obj.displayPos) = NaN;
            end
        end

        function setPosition(obj, pos)
            % Set the current position to a given value
            % Arguments: pos (degrees)

            positionTics = obj.degrees2pos(pos);
            obj.Port.write('P', 'uint8', positionTics, 'int16');
            obj.ConfirmUSBTransmission('Rotary Encoder Position');
        end

        function enableThresholds(obj, thresholdsEnabled)
            % Enable thresholds. Thresholds are automatically disabled when crossed.
            % Arguments: thresholdsEnabled, a 1xnThresholds array indicating which thresholds to enable

            thresholdEnabledBits = sum(thresholdsEnabled.*2.^((0:length(thresholdsEnabled)-1)));
            obj.Port.write([';' thresholdEnabledBits], 'uint8');
        end

        function startUSBStream(obj, varargin)
            % Start streaming position data via USB. You can then read streaming positions with readUSBStream().
            % To support legacy user code, this function can read (and ignore) an input argument.
            if obj.acquiring == 0
                if obj.isLogging == 0
                    obj.acquiring = 1;
                    obj.Port.write(['S' 1], 'uint8');
                    obj.lastTimeRead = 0;
                    obj.rollOverSum = 0;
                    if nargin > 1
                        op = varargin{1};
                        switch lower(op)
                            case 'usetimer'
                                
                            otherwise
                                error(['Error starting rotary encoder USB stream: Invalid argument ' op '. Valid arguments are: ''UseTimer'''])
                        end     
                    end
                    obj.usbCaptureEnabled = 1;
                    obj.Timer = timer('TimerFcn',@(h,e)obj.captureUSBStream(), 'ExecutionMode', 'fixedRate', 'Period', obj.timerInterval, 'Tag', ['RE_' obj.Port.PortName]);
                    start(obj.Timer);
                else
                    error('Error: The Rotary Encoder Module is logging to microSD. Turn off logging with stopLogging() to enable USB streaming.')
                end
            end
        end

        function newData = readUSBStream(obj, varargin)
            % Reads streaming position data, started with startUSBStream()
            % readUSBStream() returns all new data up to the current moment. readUSBStream(eventCode) reads all new data prior to an event code received by the REM.
            % To send an event code to the REM from the state machine, use {'RotaryEncoder1', ['#' eventCode]} in output actions.
            eventCode = [];
            if nargin > 1
                eventCode = varargin{1};
            end
            newData = obj.getUSBStream;
            obj.usbCapturedData = obj.appendStreamData(obj.usbCapturedData, newData);
            if isempty(eventCode)
                newData = obj.usbCapturedData;
                obj.usbCapturedData = [];
            else
                [newData, obj.usbCapturedData] = obj.splitData(obj.usbCapturedData,eventCode);
            end
        end

        function [newData, usbCapturedData] = splitData(obj, streamData, eventCode)
            % Splits streaming data into parts before and after an event code
            % Arguments:
            % streamData: The position data to split
            % eventCode: The event indicating the time to split the data
            %
            % Returns:
            % newData: Positions and timestamps before the event
            % usbCapturedData: Positions and timestamps after the event
            if sum(streamData.EventCodes == eventCode) > 0
                splitEventIndex = find(streamData.EventCodes == eventCode, 1);
                splitEventTime = streamData.EventTimestamps(splitEventIndex);
                firstHalfPositionIndexes = streamData.Times <= splitEventTime;
                secondHalfPositionIndexes = logical(1-firstHalfPositionIndexes);
                firstHalfEventIndexes = streamData.EventTimestamps <= splitEventTime;
                secondHalfEventIndexes = logical(1-firstHalfEventIndexes);
                newData = struct;
                newData.nPositions = sum(firstHalfPositionIndexes);
                newData.nEvents = sum(firstHalfEventIndexes);
                newData.Positions = streamData.Positions(firstHalfPositionIndexes);
                newData.Times = streamData.Times(firstHalfPositionIndexes);
                newData.EventTypes = streamData.EventTypes(firstHalfEventIndexes);
                newData.EventCodes = streamData.EventCodes(firstHalfEventIndexes);
                newData.EventTimestamps = streamData.EventTimestamps(firstHalfEventIndexes);
                usbCapturedData = struct;
                usbCapturedData.nPositions = sum(secondHalfPositionIndexes);
                usbCapturedData.nEvents = sum(secondHalfEventIndexes);
                usbCapturedData.Positions = streamData.Positions(secondHalfPositionIndexes);
                usbCapturedData.Times = streamData.Times(secondHalfPositionIndexes);
                usbCapturedData.EventTypes = streamData.EventTypes(secondHalfEventIndexes);
                usbCapturedData.EventCodes = streamData.EventCodes(secondHalfEventIndexes);
                usbCapturedData.EventTimestamps = streamData.EventTimestamps(secondHalfEventIndexes);
            else
                newData = streamData;
                usbCapturedData = [];
            end
        end

        function outData = appendStreamData(obj, streamData, newData)
            % Combine two position data structures
            if isfield(streamData, 'nPositions')
                streamData.nPositions = streamData.nPositions + newData.nPositions;
                streamData.nEvents = streamData.nEvents + newData.nEvents;
                streamData.Positions = [streamData.Positions newData.Positions];
                streamData.Times = [streamData.Times newData.Times];
                streamData.EventTypes = [streamData.EventTypes newData.EventTypes];
                streamData.EventCodes = [streamData.EventCodes newData.EventCodes];
                streamData.EventTimestamps = [streamData.EventTimestamps newData.EventTimestamps];
                outData = streamData;
            else
                outData = newData;
            end
        end

        function stopUSBStream(obj)
            % Stop the USB position data stream
            if obj.usbCaptureEnabled == 1
                if ~isempty(obj.Timer)
                    stop(obj.Timer);
                end
                delete(obj.Timer);
                obj.Timer = [];
                obj.usbCaptureEnabled = 0;
                obj.usbCapturedData = [];
            end
            if obj.acquiring
                obj.Port.write(['S' 0], 'uint8');
                pause(.05);
                if obj.Port.bytesAvailable > 0
                    obj.Port.flush;
                end
                obj.acquiring = 0;
            end
        end

        function streamUI(obj)
            % Launch a user interface to view a live plot of the encoder
            % position. The UI also has elements for setting and resetting
            % two event thresholds.
            if obj.isLogging == 1
                error('Error: The Rotary Encoder Module is logging to microSD. Turn off logging with stopLogging() to enable USB streaming.')
            end
            if obj.uiStreaming == 0
                obj.uiStreaming = 1;
                bgColor = [0.8 0.8 0.8];
                thresholdColors = {[0 0 1], [1 0 0], [0 1 0], [1 1 0], [0 1 1],...
                    [1 0 1], [0.5 0 0], [0 0.5 0]}; 
                obj.displayPositions = nan(1,obj.nDisplaySamples);
                obj.displayTimes = nan(1,obj.nDisplaySamples);
                obj.gui.Fig  = figure('name','Position Stream', 'position',[100,100,800,500],...
                    'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off',...
                    'Color',bgColor, 'CloseRequestFcn', @(h,e)obj.endAcq());
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
                xData = nan(1,obj.nDisplaySamples); yData = nan(1,obj.nDisplaySamples);
                obj.gui.StartLine = line([0,obj.maxDisplayTime],[0,0], 'Color', [.5 .5 .5]);
                nThresholds = length(obj.thresholds);
                obj.gui.ThreshLine = cell(1,nThresholds);
                for i = 1:nThresholds
                    obj.gui.ThreshLine{i} = line([0,obj.maxDisplayTime],[NaN NaN], 'Color', thresholdColors{i}, 'LineStyle', ':');
                end
                obj.gui.OscopeDataLine = line([xData,xData],[yData,yData]);
                yPos = 445;
                uicontrol('Style', 'text', 'Position', [600 yPos 170 30], 'String', 'Threshold Events', 'FontSize', 14,...
                    'FontWeight', 'bold', 'BackgroundColor', bgColor); yPos = yPos - 30;
                obj.gui.UseEventsCheckbox = uicontrol('Style', 'checkbox', 'Position', [610 yPos 30 30], 'FontSize', 12,...
                    'BackgroundColor', bgColor, 'Callback',@(h,e)obj.UIsetParams());
                uicontrol('Style', 'text', 'Position', [630 yPos-5 60 30], 'String', 'Enable', 'FontSize', 12,...
                    'BackgroundColor', bgColor); yPos = yPos - 45;
                yPos = 370;
                uicontrol('Style', 'text', 'Position', [600 yPos 180 30], 'String', 'Event Thresh (deg)', 'FontSize', 14,...
                    'FontWeight', 'bold', 'BackgroundColor', bgColor); yPos = yPos - 45;

                uicontrol('Style', 'text', 'Position', [600 yPos 30 30], 'String', '1:', 'FontSize', 14,...
                    'FontWeight', 'bold', 'BackgroundColor', bgColor, 'ForegroundColor', thresholdColors{1});
                obj.gui.Threshold1Edit = uicontrol('Style', 'edit', 'Position', [630 yPos+2 60 30], 'String', num2str(obj.thresholds(1)), 'FontSize', 14,...
                    'FontWeight', 'bold', 'Enable', 'off', 'Callback',@(h,e)obj.UIsetParams());
                if nThresholds > 1
                    uicontrol('Style', 'text', 'Position', [695 yPos 30 30], 'String', '2:', 'FontSize', 14,...
                        'FontWeight', 'bold', 'BackgroundColor', bgColor, 'ForegroundColor', thresholdColors{2});
                    obj.gui.Threshold2Edit = uicontrol('Style', 'edit', 'Position', [725 yPos+2 60 30], 'String', num2str(obj.thresholds(2)), 'FontSize', 14,...
                        'FontWeight', 'bold', 'Enable', 'off', 'Callback',@(h,e)obj.UIsetParams());
                end
                yPos = 225;
                obj.gui.ThresholdResetButton = uicontrol('Style', 'pushbutton', 'Position', [610 yPos 175 30], 'String', 'Reset Thresholds', 'FontSize', 14,...
                        'FontWeight', 'bold','Callback',@(h,e)obj.enableThresholds(ones(1,nThresholds))); yPos = yPos + 50;
                obj.gui.ThresholdResetButton = uicontrol('Style', 'pushbutton', 'Position', [610 yPos 175 30], 'String', 'Reset Position', 'FontSize', 14,...
                        'FontWeight', 'bold','Callback',@(h,e)obj.zeroPosition());
                yPos = 175;
                uicontrol('Style', 'text', 'Position', [600 yPos 150 30], 'String', 'Output Stream', 'FontSize', 14,...
                    'FontWeight', 'bold', 'BackgroundColor', bgColor); yPos = yPos - 30;
                obj.gui.OutputStreamCheckbox = uicontrol('Style', 'checkbox', 'Position', [610 yPos 30 30], 'FontSize', 12,...
                    'BackgroundColor', bgColor, 'Callback',@(h,e)obj.UIsetParams(), 'Value', strcmp(obj.moduleOutputStream, 'on'));
                if obj.hardwareVersion == 2
                    set(obj.gui.OutputStreamCheckbox, 'enable', 'off');
                end
                uicontrol('Style', 'text', 'Position', [630 yPos-5 60 30], 'String', 'Enable', 'FontSize', 12,...
                    'BackgroundColor', bgColor); yPos = yPos - 45;
                obj.displayPos = 1;
                obj.sweepStartTime = 0;
                drawnow;
                obj.Timer = timer('TimerFcn',@(h,e)obj.updatePlot(), 'ExecutionMode', 'fixedRate', 'Period', 0.05);
                obj.acquiring = 1;
                obj.Port.write(['S' 1], 'uint8');
                obj.lastTimeRead = 0;
                obj.rollOverSum = 0;
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
            obj.uiResetScheduled = 1;
        end

        function delete(obj)
            % Destructor
            obj.stopUSBStream;
            if obj.hardwareVersion == 1
                obj.stopLogging;
            end
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
    methods (Access = private)
        function endAcq(obj)
            if ~isempty(obj.Timer)
                stop(obj.Timer);
            end
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
                if (DisplayTime >= obj.maxDisplayTime) || (obj.uiResetScheduled == 1)
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
                obj.uiResetScheduled = 0;
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
            
            nans = nan(1,length(obj.displayPositions));
            obj.displayPositions = nans;
            obj.displayTimes = nans;
            set(obj.gui.OscopeDataLine, 'Ydata', [nans nans], 'Xdata', [nans nans]);
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

        function updateThresh(obj,state)
            nThresholds = length(obj.thresholds);
            if state == 1
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

        function newData = getUSBStream(obj)
            if ~obj.acquiring
                error('Error: the USB stream must be started with startUSBStream() before you can read stream data from the buffer.')
            end
            newData = obj.newDataTemplate;
            nNewDataPoints = 0;
            nNewEvents = 0;
            nBytesAvailable = obj.Port.bytesAvailable;
            if (nBytesAvailable > 6)
                msgSize = 7*floor(nBytesAvailable/7); % Only read complete messages
                msg = obj.Port.read(msgSize, 'uint8');
                msgInd = 1;
                while msgInd < length(msg)
                    thisOp = msg(msgInd);
                    switch thisOp
                        case 'P' % Position  
                            msgInd = msgInd + 1;
                            positions = msg(msgInd:msgInd+5);
                            msgInd = msgInd + 6;
                            newData.nPositions = newData.nPositions + 1;
                            nNewDataPoints = nNewDataPoints + 1;
                            newData.Positions(nNewDataPoints) = obj.pos2degrees(typecast(positions(obj.positionBytemask(1:6)), 'int16'));
                            newTime = double(typecast(positions(obj.timeBytemask(1:6)), 'uint32'))/1000000;
                            if obj.lastTimeRead > newTime
                                obj.rollOverSum = obj.rollOverSum + 4294.967296;
                            end
                            obj.lastTimeRead = newTime;
                            newData.Times(nNewDataPoints) = newTime + obj.rollOverSum;
                        case 'E' % Event
                            msgInd = msgInd + 1;
                            eventData = msg(msgInd:msgInd+5);
                            nNewEvents = nNewEvents + 1;
                            msgInd = msgInd + 6;
                            newData.nEvents = newData.nEvents + 1;
                            newData.EventTypes(nNewEvents) = eventData(1);
                            newData.EventCodes(nNewEvents) = eventData(2);
                            newTime = double(typecast(eventData(3:end), 'uint32'))/1000000;
                            if obj.lastTimeRead > newTime
                                obj.rollOverSum = obj.rollOverSum + 4294.967296;
                            end
                            obj.lastTimeRead = newTime;
                            newData.EventTimestamps(nNewEvents) = newTime + obj.rollOverSum;
                    end
                end
                if nNewDataPoints > 0
                    newData.Positions = newData.Positions(1:nNewDataPoints);
                    newData.Times = newData.Times(1:nNewDataPoints);
                else
                    newData.Positions = [];
                    newData.Times = [];
                end
                if nNewEvents > 0
                    newData.EventTypes = newData.EventTypes(1:nNewEvents);
                    newData.EventCodes = newData.EventCodes(1:nNewEvents);
                    newData.EventTimestamps = newData.EventTimestamps(1:nNewEvents);
                else
                    newData.EventTypes = [];
                    newData.EventCodes = [];
                    newData.EventTimestamps = [];
                end
                if obj.userCallbackFcnSet
                    latestPosition = newData.Positions(end);
                    eval([obj.userCallbackFcn '(latestPosition)'])
                    newData.EventTypes(end+1) = 255;
                    newData.EventCodes(end+1) = latestPosition;
                    newData.EventTimestamps(end+1) = newData.Times(end);
                end
            else
                newData.Positions = [];
                newData.Times = [];
                newData.EventTypes = [];
                newData.EventCodes = [];
                newData.EventTimestamps = [];
            end
        end

        function degrees = pos2degrees(obj, pos)
            degrees = round(((double(pos)/obj.halfPoint)*180)*10)/10;
        end

        function pos = degrees2pos(obj, degrees)
            pos = int16((degrees./180).*obj.halfPoint);
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