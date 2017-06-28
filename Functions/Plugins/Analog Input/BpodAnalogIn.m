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

classdef BpodAnalogIn < handle
   
    properties
        About = struct; % Contains a text string describing each field
        Port % ArCOM Serial port
        Timer % MATLAB timer object
        Status % Struct containing status of ongoing ops (logging, streaming, etc)
        nActiveChannels % Number of channels to sample (consecutive, beginning with channel 1)
        SamplingRate % 1Hz-50kHz, affects all channels
        InputRange % A cell array of strings indicating voltage range for 12-bit conversion. Valid ranges are in ValidRanges (below)
        Thresholds % Threshold (V) for each channel. Analog signal crossing the threshold generates an event.
        ResetVoltages % Voltage must cross ResetValue (V) before another threshold event can occur
        SMeventsEnabled % Logical vector indicating channels that generate events
        Stream2Module % Logical vector indicating channels to stream to output module (raw data)
        nSamplesToLog = Inf; % Number of samples to log on trigger, 0 = infinite
    end
    
    properties(Constant)
        ValidRanges = {'-10V:10V', '-5V:5V', '-2.5V:2.5V','0V:10V'};
        ValidSamplingRates = [1 100000]; % Range of valid sampling rates
    end
    
    properties (Access = private)
        CurrentFirmwareVersion = 1;
        UIhandles % A struct with UI handles
        UIdata % A struct with internal user interface data
        opMenuByte = 213; % Byte code to access op menu
        RangeMultipliers = [20 10 5 10];
        RangeOffsets = [10 5 2.5 0];
        InputRangeLimits = [-10 10; -5 5; -2.5 2.5; 0 10];
        RangeIndex = ones(1,8); % Integer code for voltage range (position in ValidRanges vector above)
        nPhysicalChannels = 8; % Number of physical channels
        RootPath = fileparts(which('AnalogInObject'));
        FirmwareVersion = 0;
        Stream2USB % Logical vector indicating channels to stream to USB (raw data)
        Initialized = 0; % Set to 1 after object constructor is done running
        Streaming = 0; % Set to 1 if the oscope display is streaming
        chBits = (2^13); % Bit width of ADC
    end
    
    methods
        
        function obj = BpodAnalogIn(portString)
            try
                obj.Port = ArCOMObject_Ain(portString, 115200);
            catch
                error('Was not able to find BpodAnalogIn module. Try disconnect and connect again.')
            end
            obj.Port.write([obj.opMenuByte 'O'], 'uint8');
            pause(.1);
            HandShakeOkByte = obj.Port.read(1, 'uint8');
            if HandShakeOkByte == 161 % Correct handshake response
                obj.FirmwareVersion = obj.Port.read(1, 'uint32');
                disp(['AnalogIn module V' num2str(obj.FirmwareVersion) ' found.']);
            else
                error(['Error: The serial port (' portString ') returned an unexpected handshake signature.'])
            end
            % Set defaults (also set in parallel on device)
            obj.InputRange  = repmat(obj.ValidRanges(1), 1, obj.nPhysicalChannels);
            obj.SamplingRate = 1000;
            obj.Status = struct;
            obj.Status.Logging = 0;
            obj.Status.EventReporting = 0;
            obj.Status.USBStreamEnabled = 0;
            obj.Status.ModuleStreamEnabled = 0;
            obj.nActiveChannels = obj.nPhysicalChannels;            
            obj.Thresholds = ones(1,obj.nPhysicalChannels)*10; % Initialized to max voltage of default range
            obj.ResetVoltages = ones(1,obj.nPhysicalChannels)*-10;
            obj.SMeventsEnabled = zeros(1,obj.nPhysicalChannels);
            obj.Stream2USB = zeros(1,obj.nPhysicalChannels);
            obj.Stream2Module = zeros(1,obj.nPhysicalChannels);
            
            obj.About.Port = 'ArCOM USB serial port object, to simplify data transactions with Arduino. See https://github.com/sanworks/ArCOM';
            obj.About.GUIhandles = 'A struct containing handles of the UI';
            obj.About.Status = 'A struct containing process status: logging, streaming to output module, returning threshold events to state machine';
            obj.About.SamplingRate = 'Sampling rate for all channels (in Hz)';
            obj.About.InputRange = 'Voltage range mapped to 12 bits of each channel. Valid ranges are in .ValidRanges';
            obj.About.nActiveChannels = 'Number of channels to read, beginning with channel 1. Fewer channels -> faster sampling.';
            obj.About.Thresholds = 'Threshold, in volts, generates an event when crossed. The event will be sent to the state machine if SendBpodEvents was called earlier.';
            obj.About.ResetVoltages = 'Threshold reset voltages for each channel. Voltage must go below this value to enable the next event.';
            obj.About.SMeventsEnabled = 'Logical vector indicating channels that generate threshold crossing events';
            obj.About.Stream2USB = 'Logical vector indicating which channels stream raw data to USB.';
            obj.About.Stream2Module = 'Logical vector indicating which channels stream raw data to output module.';
            obj.About.nSamplesToLog = 'Number of samples to log following a call to StartSDlogging() or serial log command from the state machine. 0 = Infinite.';
            obj.About.METHODS = 'type methods(myObject) at the command line to see a list of valid methods.';
            obj.Initialized = 1;
        end
       
        function set.nSamplesToLog(obj, nSamples)
            if obj.Initialized
                nSamples2Send = nSamples;
                if nSamples == Inf
                    nSamples2Send = 0;
                end
                % Used to acquire a fixed number of samples
                obj.Port.write([obj.opMenuByte 'W'], 'uint8', nSamples2Send, 'uint32');
                obj.confirmTransmission('nSamplesToLog');
                if nSamples == 0
                   nSamples = Inf;
                end
            end
            obj.nSamplesToLog = nSamples;
        end
               
        function set.SamplingRate(obj, sf)
            if obj.Initialized
                if sf < obj.ValidSamplingRates(1) || sf > obj.ValidSamplingRates(2)
                    error(['Error setting sampling rate: valid rates are in range: [' num2str(obj.ValidSamplingRates) '] Hz'])
                end
                obj.Port.write([obj.opMenuByte 'F'], 'uint8', sf,'uint32');
                obj.confirmTransmission('sampling rate');
            end
            obj.SamplingRate = sf;
        end
        
        function set.nActiveChannels(obj, nChannels)
            if obj.Initialized
                if nChannels < 1 || nChannels > obj.nPhysicalChannels
                    error(['Error setting active channel count: nChannels must be in the range 1:' num2str(obj.nPhysicalChannels)]);
                end
                obj.Port.write([obj.opMenuByte 'A' nChannels], 'uint8');
                obj.confirmTransmission('active channels');
            end
            obj.nActiveChannels = nChannels;
        end
        
        function set.InputRange(obj, value)          
            %1: '-10V - 10V' 2: '-5V - 5V' 3: '-2.5V - 2.5V' 4: '0V - 10V' 
            if obj.Initialized
                InputRangeIndex = ones(1,obj.nPhysicalChannels);
                for i = 1:obj.nPhysicalChannels
                    RangeString = value{i};
                    RangeIndex = find(strcmp(RangeString, obj.ValidRanges),1);
                    if isempty(RangeIndex)
                        error(['Invalid range specified: ' RangeString '. Valid ranges are: ' obj.ValidRanges]);
                    end
                    InputRangeIndex(i) = RangeIndex;
                end
                obj.Port.write([obj.opMenuByte 'R' InputRangeIndex-1], 'uint8');
                obj.confirmTransmission('voltage range');
                oldRangeIndex = obj.RangeIndex;
                obj.RangeIndex = InputRangeIndex;
                % Set thresholds and reset values (expressed in voltages) to values in new range. 
                % Thresholds that are out of range are set to maximum range.
                NewThresholds = obj.Thresholds;
                NewResets = obj.ResetVoltages;
                for i = 1:obj.nPhysicalChannels
                    ThisRangeMin = obj.InputRangeLimits(obj.RangeIndex(i),1);
                    ThisRangeMax = obj.InputRangeLimits(obj.RangeIndex(i),2);
                    if NewThresholds(i) < ThisRangeMin
                        NewThresholds(i) = ThisRangeMin;
                    elseif NewThresholds(i) > ThisRangeMax
                        NewThresholds(i) = ThisRangeMax;
                    end
                    if NewResets(i) < ThisRangeMin
                        NewResets(i) = ThisRangeMin;
                    elseif NewResets(i) > ThisRangeMax
                        NewResets(i) = ThisRangeMax;
                    end
                    if obj.Thresholds(i) == obj.InputRangeLimits(oldRangeIndex(i), 2)
                        NewThresholds(i) = ThisRangeMax;
                    end
                    if obj.ResetVoltages(i) == obj.InputRangeLimits(oldRangeIndex(i), 1)
                        NewResets(i) = ThisRangeMin;
                    end
                end
                 obj.InputRange = value;
                 % Reset and threshold must be set simultanesously, since they
                 % were changed simultaneously. Instead of calling
                 % set.Thresholds, and set.ResetVoltages, the next 4 lines do both at once.
                 ResetValueBits = obj.Volts2Bits(NewResets, obj.RangeIndex);
                 ThresholdBits = obj.Volts2Bits(NewThresholds, obj.RangeIndex);
                 obj.Port.write([obj.opMenuByte 'T'], 'uint8', [ThresholdBits ResetValueBits], 'uint16');
                 obj.confirmTransmission('thresholds');
                 obj.Initialized = 0; % Disable updating to change the object
                 obj.Thresholds = NewThresholds;
                 obj.ResetVoltages = NewResets;
                 obj.Initialized = 1;
            else
                obj.InputRange = value;
            end
            
        end
        
        function set.Thresholds(obj, value)
            if obj.Initialized
                for i = 1:obj.nPhysicalChannels
                    if value(i) < obj.InputRangeLimits(obj.RangeIndex(i),1) || value(i) > obj.InputRangeLimits(obj.RangeIndex(i),2)
                        error(['Error setting threshold: the threshold for channel ' num2str(i) ' is not within the channel''s voltage range: ' obj.InputRange{i}])
                    end
                end
                %Rescale thresholds according to voltage range.
                ResetValueBits = obj.Volts2Bits(obj.ResetVoltages, obj.RangeIndex);
                ThresholdBits = obj.Volts2Bits(value, obj.RangeIndex);
                obj.Port.write([obj.opMenuByte 'T'], 'uint8', [ThresholdBits ResetValueBits], 'uint16');
                obj.confirmTransmission('thresholds');
            end
            obj.Thresholds = value;
        end

        function set.ResetVoltages(obj, value)
            if obj.Initialized
                for i = 1:obj.nPhysicalChannels
                    if value(i) < obj.InputRangeLimits(obj.RangeIndex(i),1) || value(i) > obj.InputRangeLimits(obj.RangeIndex(i),2)
                        error(['Error setting threshold reset voltage: the value for channel ' num2str(i) ' is not within the channel''s voltage range: ' obj.InputRange{i}])
                    end
                end
                %Rescale thresholds according to voltage range.
                ResetValueBits = obj.Volts2Bits(value, obj.RangeIndex);
                ThresholdBits = obj.Volts2Bits(obj.Thresholds, obj.RangeIndex);
                obj.Port.write([obj.opMenuByte 'T'], 'uint8', [ThresholdBits ResetValueBits], 'uint16');
                obj.confirmTransmission('reset values');
            end
            obj.ResetVoltages = value;
        end
        
        function set.SMeventsEnabled(obj, value)
            if obj.Initialized
                if ~(length(value) == obj.nPhysicalChannels && sum((value == 0) | (value == 1)) == obj.nPhysicalChannels)
                    error('Error setting events enabled: enabled state must be 0 or 1')
                end
                obj.Port.write([obj.opMenuByte 'K' value], 'uint8');
                obj.confirmTransmission('events enabled');
            end
            obj.SMeventsEnabled = value;
        end
        
        function startModuleStream(obj)
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'S' 1 1], 'uint8');
                obj.confirmTransmission('Module stream');
            end
            obj.Status.ModuleStreamEnabled = 1;
        end
        
        function stopModuleStream(obj)
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'S' 1 0], 'uint8');
                obj.confirmTransmission('Module stream');
            end
            obj.Status.ModuleStreamEnabled = 0;
        end
        
        function startUSBStream(obj)
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'S' 0 1], 'uint8');
                %obj.confirmTransmission('USB stream');
            end
            obj.Status.USBStreamEnabled = 1;
        end
        
        function stopUSBStream(obj)
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'S' 0 0], 'uint8');
                % Do not confirm; data bytes in buffer may be expected by
                % another application
            end
            obj.Status.USBStreamEnabled = 0;
        end
        
        function startReportingEvents(obj)
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'E' 1 1], 'uint8');
                obj.confirmTransmission('event reporting');
            end
            obj.Status.EventReporting = 1;
        end
        
        function stopReportingEvents(obj)
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'E' 1 0], 'uint8');
                obj.confirmTransmission('event reporting');
            end
            obj.Status.EventReporting = 0;
        end
        
        function startLogging(obj)
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'L' 1], 'uint8');
                obj.confirmTransmission('start logging');
                obj.Status.Logging = 1;
            end
        end
        
        function stopLogging(obj)
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'L' 0], 'uint8');
                obj.confirmTransmission('stop logging');
                obj.Status.Logging = 0;
            end
        end
        
        function set.Stream2USB(obj, value)
            if obj.Initialized
                if ~(length(value) == obj.nPhysicalChannels && sum((value == 0) | (value == 1)) == obj.nPhysicalChannels)
                    error('Error setting Stream2USB channels: value for each channel must be 0 or 1')
                end
                obj.Port.write([obj.opMenuByte 'C' value obj.Stream2Module], 'uint8');
                obj.confirmTransmission('stream to USB');
            end
            obj.Stream2USB = value;
        end
        
        function set.Stream2Module(obj, value)
            if obj.Initialized
                if ~(length(value) == obj.nPhysicalChannels && sum((value == 0) | (value == 1)) == obj.nPhysicalChannels)
                    error('Error setting Stream2USB channels: value for each channel must be 0 or 1')
                end
                obj.Port.write([obj.opMenuByte 'C' obj.Stream2USB value], 'uint8');
                obj.confirmTransmission('stream to USB');
            end
            obj.Stream2Module = value;
        end
        
        function data = getData(obj)   
            if obj.Port.bytesAvailable > 0
                obj.Port.read(obj.Port.bytesAvailable); % Clear buffer
            end
            % Send 'Retrieve' command to the AM
            obj.Port.write([obj.opMenuByte 'D'], 'uint8');
            nSamples = obj.Port.read(1, 'uint32');
            nValues = obj.nActiveChannels*nSamples;
            RawData = obj.Port.read(nValues, 'uint16');
            data = struct;
            data.y = zeros(obj.nActiveChannels, nSamples);
            ReshapedRawData = reshape(RawData, obj.nActiveChannels, nSamples);
            for i = 1:obj.nActiveChannels
                thisMultiplier = obj.RangeMultipliers(obj.RangeIndex(i));
                thisOffset = obj.RangeOffsets(obj.RangeIndex(i));
                data.y(i,:) = ((double(ReshapedRawData(i,:))/8192)*thisMultiplier)-thisOffset;
            end
            Period = 1/obj.SamplingRate;
            data.x = 0:Period:(Period*double(nSamples)-Period);
        end
        
        function Scope(obj)
            obj.scope;
        end
        
        function scope(obj)
            obj.UIhandles.nXDivisions = 12;
            obj.UIhandles.nYDivisions = 8;
            obj.UIdata.VoltDivPos = 9;
            obj.UIdata.TimeDivPos = 5;
            obj.UIdata.VoltDivValues = [0.01 0.02 0.05 0.1 0.2 0.5 1 2 5];
            obj.UIdata.TimeDivValues = [0.01 0.02 0.05 0.1 0.2 0.5 1 2];
            obj.UIdata.nDisplaySamples = obj.SamplingRate*obj.UIdata.TimeDivValues(obj.UIdata.TimeDivPos)*obj.UIhandles.nXDivisions;
            obj.UIdata.SweepPos = 1;
            obj.UIdata.SweepPos = 1;
            if IsLinux
                TitleFontSize = 16;
                ScaleFontSize = 14;
                SubTitleFontSize = 12;
                lineEdge = 0.25; 
                figHeight = 470;
                dropFontSize = 8;
            else
                TitleFontSize = 18;
                ScaleFontSize = 18;
                SubTitleFontSize = 16;
                lineEdge = 0;
                figHeight = 500;
                dropFontSize = 10;
            end
            OscBGColor = [0.55 0.55 0.55];
            LineColors = {[1 1 0], [0 1 1], [1 0.5 0], [0 1 0], [1 .3 .3], [.6 .2 1], [.3 .3 1], [1 0 1]};
            ResetLineColors = cell(1,obj.nPhysicalChannels);
            for i = 1:obj.nPhysicalChannels
                ResetLineColors{i} = LineColors{i}*0.5;
            end
            obj.UIhandles.OscopeFig = figure('Name','Scope',...
                                                 'NumberTitle','off',...
                                                 'MenuBar','none',...
                                                 'Color',OscBGColor,...
                                                 'Position',[100,100,1024,figHeight],...
                                                 'CloseRequestFcn',@(h,e)obj.endAcq());
            obj.UIhandles.Plot = axes('units','pixels', 'position',[10 10 640 480], ...
                                 'box', 'off', 'tickdir', 'out', 'Color', [0.1 0.1 0.1]);
            set(gca, 'xlim', [0 obj.UIhandles.nXDivisions], 'ylim', [-0.4 obj.UIhandles.nYDivisions], 'ytick', [], 'xtick', []);
            Interval = obj.UIhandles.nXDivisions/obj.UIdata.nDisplaySamples;
            obj.UIdata.Xdata = 0:Interval:obj.UIhandles.nXDivisions-Interval; 
            obj.UIdata.Ydata = nan(obj.nPhysicalChannels,obj.UIdata.nDisplaySamples);
            for i = 1:obj.UIhandles.nYDivisions-1
                obj.UIhandles.GridXLines(i) = line([0,obj.UIhandles.nXDivisions],[i,i], 'Color', [.3 .3 .3], 'LineStyle',':');
                if i == floor(obj.UIhandles.nYDivisions/2)
                    set(obj.UIhandles.GridXLines(i), 'Color', [.6 .6 .6]);
                end
            end
            for i = 1:obj.UIhandles.nXDivisions-1
                obj.UIhandles.GridYLines(i) = line([i,i],[0,obj.UIhandles.nYDivisions], 'Color', [.3 .3 .3], 'LineStyle',':');
                if i == floor(obj.UIhandles.nXDivisions/2)
                    set(obj.UIhandles.GridYLines(i), 'Color', [.6 .6 .6]);
                end
            end
            for i = 1:obj.nPhysicalChannels
                obj.UIhandles.OscopeDataLine(i) = line([obj.UIdata.Xdata,obj.UIdata.Xdata],[obj.UIdata.Ydata(i,:),obj.UIdata.Ydata(i,:)], 'Color', LineColors{i});
            end
            currentVoltDivValue = obj.UIdata.VoltDivValues(obj.UIdata.VoltDivPos);
            MaxVolts = currentVoltDivValue*(obj.UIhandles.nYDivisions); HalfMax = MaxVolts/2; 
            VisibilityVec = {'Off', 'On'};
            for i = 1:obj.nPhysicalChannels
                ThreshY = ((obj.Thresholds(i)+HalfMax)/MaxVolts)*obj.UIhandles.nYDivisions;
                obj.UIhandles.ThresholdLine(i) = line([0 obj.UIhandles.nXDivisions],[ThreshY,ThreshY],...
                'Color', LineColors{i}, 'LineStyle', ':', 'Visible', VisibilityVec{obj.SMeventsEnabled(i)+1});
                ResetY = ((obj.ResetVoltages(i)+HalfMax)/MaxVolts)*obj.UIhandles.nYDivisions;
                obj.UIhandles.ResetLine(i) = line([0 obj.UIhandles.nXDivisions],[ResetY,ResetY],...
                'Color', ResetLineColors{i}, 'LineStyle', ':', 'Visible', VisibilityVec{obj.SMeventsEnabled(i)+1});
            end
            
            
            obj.UIhandles.MaskLine = line([lineEdge,obj.UIhandles.nXDivisions-lineEdge],[-0.2,-0.2], 'Color', [.2 .2 .2], 'LineWidth', 20);
            obj.UIhandles.VDivText = text(0.2,-0.2, 'V/div: 5.0', 'Color', 'yellow', 'FontName', 'Courier New', 'FontSize', 12);
            obj.UIhandles.TimeText = text(9.5,-0.2, 'Time 200.0ms', 'Color', 'yellow', 'FontName', 'Courier New', 'FontSize', 12);
            obj.UIhandles.StatText = text(0.2,7.7, 'Stopped', 'Color', 'red', 'FontName', 'Courier New', 'FontSize', 12);
            obj.UIhandles.RunButton = uicontrol('Style', 'pushbutton', 'String', 'RUN', 'Position', [895 390 120 95],...
                'Callback',@(h,e)obj.StartStopStreaming(), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', TitleFontSize,...
                'FontWeight', 'bold', 'TooltipString', 'Stream data to display');
            obj.UIhandles.TimeScaleUpButton = uicontrol('Style', 'pushbutton', 'String', '>', 'Position', [970 10 50 50],...
                'Callback',@(h,e)obj.stepTimescale(1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', TitleFontSize,...
                'FontWeight', 'bold', 'TooltipString', 'Increase time/div');
            obj.UIhandles.TimeScaleDnButton = uicontrol('Style', 'pushbutton', 'String', '<', 'Position', [845 10 50 50],...
                'Callback',@(h,e)obj.stepTimescale(-1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', TitleFontSize,...
                'FontWeight', 'bold', 'TooltipString', 'Decrease time/div');
            uicontrol('Style', 'text', 'Position', [895 37 70 30], 'String', 'Time', 'FontSize', ScaleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [895 10 70 30], 'String', '/ div', 'FontSize', ScaleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            obj.UIhandles.VoltScaleUpButton = uicontrol('Style', 'pushbutton', 'String', '^', 'Position', [780 10 50 50],...
                'Callback',@(h,e)obj.stepVoltscale(1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', TitleFontSize,...
                'FontWeight', 'bold', 'TooltipString', 'Increase volts/div');
            obj.UIhandles.VoltScaleDnButton = uicontrol('Style', 'pushbutton', 'String', 'v', 'Position', [660 10 50 50],...
                'Callback',@(h,e)obj.stepVoltscale(-1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', TitleFontSize,...
                'FontWeight', 'bold', 'TooltipString', 'Decrease volts/div');
            uicontrol('Style', 'text', 'Position', [710 37 70 30], 'String', 'Volts', 'FontSize', ScaleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [710 10 70 30], 'String', '/ div', 'FontSize', ScaleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [655 310 70 30], 'String', 'View', 'FontSize', SubTitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [720 310 90 30], 'String', 'Range', 'FontSize', SubTitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [800 310 90 30], 'String', 'Events', 'FontSize', SubTitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [887 310 60 30], 'String', 'Thrsh', 'FontSize', SubTitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [955 310 60 30], 'String', 'Reset', 'FontSize', SubTitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [655 460 130 30], 'String', 'Sampling', 'FontSize', TitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [667 420 65 30], 'String', '#Chan', 'FontSize', SubTitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [740 420 140 30], 'String', 'Freq (Hz)', 'FontSize', SubTitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [655 350 230 30], 'String', 'Channel Settings', 'FontSize', TitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            obj.UIhandles.SFEdit = uicontrol('Style', 'edit', 'Position', [760 390 100 30], 'String', num2str(obj.SamplingRate), 'FontSize', 12,...
                'BackgroundColor', [0.8 0.8 0.8], 'FontWeight', 'bold', 'Callback',@(h,e)obj.UIsetSamplingRate());
            obj.UIhandles.nChanSelect = uicontrol('Style', 'popupmenu', 'Position', [670 390 65 30], 'String', {'1','2','3','4','5','6','7','8'}, 'FontSize', 12,...
                'BackgroundColor', [0.8 0.8 0.8], 'FontWeight', 'bold', 'Value', obj.nActiveChannels, 'Callback',@(h,e)obj.UIsetNactiveChannels());
            YPos = 285;
            EnableStrings = {'off', 'on'};
            for i = 1:obj.nPhysicalChannels
                uicontrol('Style', 'text', 'Position', [655 YPos 35 20], 'String', ['Ch' num2str(i)], 'FontSize', 12,...
                    'BackgroundColor', OscBGColor, 'FontWeight', 'bold', 'ForegroundColor', LineColors{i});
                obj.UIhandles.chanEnable(i) = uicontrol('Style', 'checkbox', 'Position', [700 YPos 20 20], 'FontSize', 12,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold', 'Value', obj.Stream2USB(i), 'Callback',@(h,e)obj.UIenableChannel(i));
                obj.UIhandles.rangeSelect(i) = uicontrol('Style', 'popupmenu', 'Position', [730 YPos 85 20], 'FontSize', dropFontSize,...
                'BackgroundColor', [0.8 0.8 0.8], 'FontWeight', 'bold', 'Value', obj.RangeIndex(i), 'Callback',@(h,e)obj.UIsetRange(i),...
                'String',obj.ValidRanges, 'enable', EnableStrings{(i<= obj.nActiveChannels)+1});
                obj.UIhandles.SMeventEnable(i) = uicontrol('Style', 'checkbox', 'Position', [840 YPos 20 20], 'FontSize', 12,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold', 'Value', obj.SMeventsEnabled(i), 'Callback',@(h,e)obj.UIenableSMEvents(i),...
                'TooltipString', ['Send threshold crossing events from channel ' num2str(i) ' to state machine']);
                obj.UIhandles.thresholdSet(i) = uicontrol('Style', 'edit', 'Position', [890 YPos 55 20], 'FontSize', 10,...
                'BackgroundColor', [0.8 0.8 0.8], 'FontWeight', 'bold', 'Callback',@(h,e)obj.UIsetThreshold(i),...
                'String',num2str(obj.Thresholds(i)), 'enable', EnableStrings{obj.SMeventsEnabled(i)+1});
                obj.UIhandles.resetSet(i) = uicontrol('Style', 'edit', 'Position', [960 YPos 55 20], 'FontSize', 10,...
                'BackgroundColor', [0.8 0.8 0.8], 'FontWeight', 'bold', 'Callback',@(h,e)obj.UIsetReset(i),...
                'String',num2str(obj.ResetVoltages(i)), 'enable', EnableStrings{obj.SMeventsEnabled(i)+1});
                YPos= YPos - 30;
            end
            set(obj.UIhandles.chanEnable(1), 'Value', 1);
            obj.Stream2USB(1) = 1;
            drawnow;  
        end
      
        function endAcq(obj)
            obj.stopUIStream;
            delete(obj.UIhandles.OscopeFig);
        end
        
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
        
    end
    
    methods (Access = private) 
        function confirmTransmission(obj,paramName)
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed == 0
                error(['Error setting ' paramName ': the module denied your request.'])
            elseif Confirmed ~= 1
                error(['Error setting ' paramName ': module did not acknowledge new value.']);
            end
        end
        function stopUIStream(obj)
            if obj.Streaming
                obj.stopUSBStream;
                stop(obj.Timer);
                pause(.1);
                if obj.Port.bytesAvailable > 0
                    obj.Port.read(obj.Port.bytesAvailable, 'uint8');
                end
            end
        end
        function updateThresholdLine(obj, chan)
            currentVoltDivValue = obj.UIdata.VoltDivValues(obj.UIdata.VoltDivPos);
            MaxVolts = currentVoltDivValue*(obj.UIhandles.nYDivisions); HalfMax = MaxVolts/2;  
            ThreshY = ((obj.Thresholds(chan)+HalfMax)/MaxVolts)*obj.UIhandles.nYDivisions;
            set(obj.UIhandles.ThresholdLine(chan), 'YData', [ThreshY,ThreshY]);
            ResetY = ((obj.ResetVoltages(chan)+HalfMax)/MaxVolts)*obj.UIhandles.nYDivisions;
            set(obj.UIhandles.ResetLine(chan), 'YData', [ResetY,ResetY]);
        end
        function bits = Volts2Bits(obj, VoltVector, RangeIndexes)
            VoltVector = double(VoltVector);
            nElements = length(VoltVector);
            bits = zeros(1,nElements);
            for i = 1:nElements
                thisMultiplier = obj.RangeMultipliers(RangeIndexes(i));
                thisOffset = obj.RangeOffsets(RangeIndexes(i));
                bits(i) = ((VoltVector(i) + thisOffset)/thisMultiplier)*obj.chBits;
            end
        end
        function ValueOut = ScaleValue(obj,Action,ValueIn,RangeString)
            
            %validate input: nrows in ValueIn == n values in Range
            
            ValueOut = nan(size(ValueIn));
            
            for i=1:size(ValueIn,1)
                
                switch obj.RangeIndex(i)
                    case 4 %'0V - 10V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 10/2^13 - 0.0;
                            case 'toBits'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+0.0)*2^13/10);
                        end
                    case 3 %'-2.5V - 2.5V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 5/2^13 - 2.5;
                            case 'toBits'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+2.5)*2^13/5);
                        end
                    case 2 %'5V - 5V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 10/2^13 - 5.0;
                            case 'toBits'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+5.0)*2^13/10);
                        end
                    case 1 %'-10V - 10V'
                        switch Action
                            case 'toVolts'
                                ValueOut(i,:) = double(ValueIn(i,:)) * 0.002455851742364 -10.091771492112841;
                                %ValueOut(i,:) = ValueIn(i,:);
                            case 'toBits'
                                ValueOut(i,:) = uint32((ValueIn(i,:)+10.0)*2^13/20);
                        end
                    otherwise
                end
            end
        end
        function StartStopStreaming(obj)
            if obj.Streaming == 0
                obj.Streaming = 1;
                set(obj.UIhandles.StatText, 'String', 'Running', 'Color', 'green');
                set(obj.UIhandles.RunButton, 'String', 'Stop');
                obj.startUSBStream;
                obj.Timer = timer('TimerFcn',@(h,e)obj.updatePlot(), 'ExecutionMode', 'fixedRate', 'Period', 0.05);
                start(obj.Timer);
            else
                stop(obj.Timer);
                obj.stopUSBStream;
                set(obj.UIhandles.StatText, 'String', 'Stopped', 'Color', 'red');
                set(obj.UIhandles.RunButton, 'String', 'Run');
                obj.Streaming = 0;
                delete(obj.Timer);
                pause(.1);
                BA = obj.Port.bytesAvailable;
                if BA > 0
                    obj.Port.read(obj.Port.bytesAvailable, 'uint8');
                end
            end
            drawnow;
        end
        function stepTimescale(obj, Step)
            NewPos = obj.UIdata.TimeDivPos + Step;
            if (NewPos > 0) && (NewPos <= length(obj.UIdata.TimeDivValues))
                obj.UIdata.TimeDivPos = obj.UIdata.TimeDivPos + Step;
                newTimeDivValue = obj.UIdata.TimeDivValues(obj.UIdata.TimeDivPos);
                nSamplesPerSweep = obj.SamplingRate*newTimeDivValue*obj.UIhandles.nXDivisions;
                Interval = obj.UIhandles.nXDivisions/(nSamplesPerSweep-1);
                obj.UIdata.Xdata = 0:Interval:obj.UIhandles.nXDivisions;
                obj.UIdata.Ydata = nan(obj.nPhysicalChannels,nSamplesPerSweep);
                obj.UIdata.SweepPos = 1;
                for i = 1:obj.nPhysicalChannels
                    set(obj.UIhandles.OscopeDataLine(i), 'XData', [obj.UIdata.Xdata,obj.UIdata.Xdata], 'YData', [obj.UIdata.Ydata(i,:),obj.UIdata.Ydata(i,:)]);
                end
                obj.UIdata.nDisplaySamples = nSamplesPerSweep;
                if newTimeDivValue >= 1
                    timeString = ['Time: ' num2str(newTimeDivValue) '.00s'];
                else
                    timeString = ['Time: ' num2str(newTimeDivValue*1000) '.0ms'];
                end
                set(obj.UIhandles.TimeText, 'String', timeString);
            end
        end
        function stepVoltscale(obj, Step)
            NewPos = obj.UIdata.VoltDivPos + Step;
            if (NewPos > 0) && (NewPos <= length(obj.UIdata.VoltDivValues))
                obj.UIdata.VoltDivPos = obj.UIdata.VoltDivPos + Step;
                obj.UIdata.SweepPos = 1;
                obj.UIdata.Ydata = nan(obj.nPhysicalChannels,obj.UIdata.nDisplaySamples);
                NewVoltsDiv = obj.UIdata.VoltDivValues(NewPos);
                if NewVoltsDiv >= 1
                    voltString = ['V/div: ' num2str(NewVoltsDiv) '.0'];
                else
                    voltString = ['mV/div: ' num2str(NewVoltsDiv*1000) '.0'];
                end
                set(obj.UIhandles.VDivText, 'String', voltString);
                for i = 1:obj.nPhysicalChannels
                    if obj.SMeventsEnabled(i)
                        obj.updateThresholdLine(i);
                    end
                end
            end
        end
        function UIsetSamplingRate(obj)
            obj.stopUIStream;
            ValidSF = 0;
            SFstring = get(obj.UIhandles.SFEdit, 'String');
            SF = str2double(SFstring);
            if ~isnan(SF)
                SF = round(SF);
                if (SF > 0) && (SF < obj.ValidSamplingRates(2))
                    ValidSF = 1;
                end
            end
            if ValidSF == 1
                obj.SamplingRate = SF;
                obj.stepTimescale(0); % Adjusts display time scale to same window setting at new SF
            else
                set(obj.UIhandles.SFEdit, 'String', num2str(obj.SamplingRate));
            end
            if obj.Streaming
                obj.startUSBStream;
                start(obj.Timer);
            end
        end
        function UIsetNactiveChannels(obj)
            nActiveChan = get(obj.UIhandles.nChanSelect, 'Value');
            obj.stopUIStream;
            if nActiveChan <= obj.nPhysicalChannels % Clear plot not in use
                for i = 1:nActiveChan
                    set(obj.UIhandles.chanEnable(i), 'enable', 'on');
                    set(obj.UIhandles.rangeSelect(i), 'enable', 'on');
                end
                for i = nActiveChan+1:obj.nPhysicalChannels
                    obj.UIdata.Ydata(i,:) = NaN;
                    set(obj.UIhandles.OscopeDataLine(i), 'Ydata', [obj.UIdata.Ydata(i,:),obj.UIdata.Ydata(i,:)]);
                    set(obj.UIhandles.chanEnable(i), 'value', 0);
                    set(obj.UIhandles.chanEnable(i), 'enable', 'off');
                    set(obj.UIhandles.rangeSelect(i), 'enable', 'off');
                end
            end
            obj.nActiveChannels = nActiveChan;
            if obj.Streaming
                obj.startUSBStream;
                start(obj.Timer);
            end
        end
        function UIenableChannel(obj, chan)
            obj.stopUIStream;
            value = get(obj.UIhandles.chanEnable(chan), 'Value');
            obj.Stream2USB(chan) = value;
            obj.UIdata.Ydata(chan,:) = NaN;
            set(obj.UIhandles.OscopeDataLine(chan), 'Ydata', [obj.UIdata.Ydata(chan,:),obj.UIdata.Ydata(chan,:)]);
            if obj.Streaming
                obj.startUSBStream;
                start(obj.Timer);
            end
        end
        function UIenableSMEvents(obj, chan)
            obj.stopUIStream;
            value = get(obj.UIhandles.SMeventEnable(chan), 'Value');
            obj.SMeventsEnabled(chan) = value;
            if value == 0
                set(obj.UIhandles.ThresholdLine(chan), 'Visible', 'Off');
                set(obj.UIhandles.ResetLine(chan), 'Visible', 'Off');
            else
                set(obj.UIhandles.ThresholdLine(chan), 'Visible', 'On');
                set(obj.UIhandles.ResetLine(chan), 'Visible', 'On');
                obj.updateThresholdLine(chan);
            end
            if sum(obj.SMeventsEnabled) > 0
                obj.startReportingEvents;
            else
                obj.stopReportingEvents;
            end
            EnableStrings = {'off', 'on'};
            set(obj.UIhandles.thresholdSet(chan), 'enable', EnableStrings{value+1});
            set(obj.UIhandles.resetSet(chan), 'enable', EnableStrings{value+1});
            if obj.Streaming
                obj.startUSBStream;
                start(obj.Timer);
            end
        end
        function UIsetRange(obj, chan)
            obj.stopUIStream;
            value = get(obj.UIhandles.rangeSelect(chan), 'Value');
            obj.InputRange{chan} = obj.ValidRanges{value};
            set(obj.UIhandles.thresholdSet(chan), 'String', num2str(obj.Thresholds(chan)));
            set(obj.UIhandles.resetSet(chan), 'String', num2str(obj.ResetVoltages(chan)));
            if obj.Streaming
                obj.startUSBStream;
                start(obj.Timer);
            end
        end
        function UIsetThreshold(obj, chan)
            obj.stopUIStream;
            newThresholdstr = get(obj.UIhandles.thresholdSet(chan), 'String');
            newThreshold = str2double(newThresholdstr);
            thisChannelRange = obj.RangeIndex(chan);
            thisChannelMin = obj.InputRangeLimits(thisChannelRange, 1);
            thisChannelMax = obj.InputRangeLimits(thisChannelRange, 2);
            ValidThreshold = 0;
            if ~isnan(newThreshold)
                if (newThreshold >= thisChannelMin) && (newThreshold <= thisChannelMax) && isreal(newThreshold)
                    obj.Thresholds(chan) = newThreshold;
                    ValidThreshold = 1;
                    obj.updateThresholdLine(chan);
                end
            end
            if ~ValidThreshold
               set(obj.UIhandles.thresholdSet(chan), 'String', num2str(obj.Thresholds(chan))); 
            end
            if obj.Streaming
                obj.startUSBStream;
                start(obj.Timer);
            end
        end
        function UIsetReset(obj, chan)
            obj.stopUIStream;
            newThresholdstr = get(obj.UIhandles.resetSet(chan), 'String');
            newThreshold = str2double(newThresholdstr);
            thisChannelRange = obj.RangeIndex(chan);
            thisChannelMin = obj.InputRangeLimits(thisChannelRange, 1);
            thisChannelMax = obj.InputRangeLimits(thisChannelRange, 2);
            ValidThreshold = 0;
            if ~isnan(newThreshold)
                if (newThreshold >= thisChannelMin) && (newThreshold <= thisChannelMax) && isreal(newThreshold)
                    obj.ResetVoltages(chan) = newThreshold;
                    ValidThreshold = 1;
                    obj.updateThresholdLine(chan);
                end
            end
            if ~ValidThreshold
               set(obj.UIhandles.resetSet(chan), 'String', num2str(obj.ResetVoltages(chan))); 
            end
            if obj.Streaming
                obj.startUSBStream;
                start(obj.Timer);
            end
        end
        function updatePlot(obj)
            nBytesAvailable = obj.Port.bytesAvailable;
            channelsStreaming = obj.Stream2USB(1:obj.nActiveChannels);
            nChannelsStreaming = sum(channelsStreaming);
            updateChannels = find(channelsStreaming);
            nBytesPerFrame = (nChannelsStreaming*2)+1;
            if nChannelsStreaming > 0
                if nBytesAvailable > nBytesPerFrame % If at least 1 sample is available for each channel
                    nBytesToRead = floor(nBytesAvailable/nBytesPerFrame)*nBytesPerFrame;
                    NewData = obj.Port.read(nBytesToRead, 'uint8');
                    currentVoltDivValue = obj.UIdata.VoltDivValues(obj.UIdata.VoltDivPos);
                    if NewData(1) == 'R'
                        NewData(1:nBytesPerFrame:end) = [];
                        NewSamples = typecast(NewData(1:end), 'uint16');
                        nNewSamples = length(NewSamples)/nChannelsStreaming;
                        SweepPos = obj.UIdata.SweepPos;
                        for ch = 1:nChannelsStreaming
                            thisChIndex = updateChannels(ch);
                            NSThisCh = NewSamples(ch:nChannelsStreaming:end);
                            M = obj.RangeMultipliers(obj.RangeIndex(thisChIndex));
                            O = obj.RangeOffsets(obj.RangeIndex(thisChIndex));
                            NSThisChVolts = ((double(NSThisCh)/obj.chBits)*M)-O;
                            MaxVolts = currentVoltDivValue*(obj.UIhandles.nYDivisions);
                            HalfMax = MaxVolts/2;
                            NSThisChVolts(NSThisChVolts<MaxVolts*-1 & NSThisChVolts>MaxVolts) = NaN;
                            NSThisChSamples = ((NSThisChVolts+HalfMax)/MaxVolts)*obj.UIhandles.nYDivisions;
                            if SweepPos == 1
                                obj.UIdata.Ydata(thisChIndex,:) = NaN;
                                obj.UIdata.Ydata(thisChIndex,1:nNewSamples) = NSThisChSamples;
                                obj.UIdata.SweepPos = SweepPos + nNewSamples;
                            elseif SweepPos + nNewSamples > obj.UIdata.nDisplaySamples
                                obj.UIdata.Ydata(thisChIndex,SweepPos:obj.UIdata.nDisplaySamples-1) = NSThisChSamples(1:(obj.UIdata.nDisplaySamples-SweepPos));
                                obj.UIdata.SweepPos = 1;
                            else
                                obj.UIdata.Ydata(thisChIndex,SweepPos:SweepPos+nNewSamples-1) = NSThisChSamples;
                                obj.UIdata.SweepPos = SweepPos + nNewSamples;
                            end
                            set(obj.UIhandles.OscopeDataLine(thisChIndex), 'Ydata', [obj.UIdata.Ydata(thisChIndex,:),obj.UIdata.Ydata(thisChIndex,:)]);
                        end
                    else
                        stop(obj.Timer);
                        delete(obj.Timer);
                        error('Error: invalid frame returned.')
                    end
                end
            end
        end
    end
end    