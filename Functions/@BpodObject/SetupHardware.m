%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2022 Sanworks LLC, Rochester, New York, USA

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
function obj = SetupHardware(obj)
    if obj.EmulatorMode == 1 % Set up as Bpod 0.7
        obj.StateMachineInfo.MaxStates = 256;
        obj.HW.n.MaxSerialEvents = 60;
        obj.HW.CyclePeriod = 100;
        obj.HW.CycleFrequency = 10000;
        obj.HW.ValveType = 'SPI';
        obj.HW.n.GlobalTimers = 5;
        obj.HW.n.GlobalCounters  = 5;
        obj.HW.n.Conditions  = 5;
        obj.HW.n.Inputs = 16;
        obj.HW.Inputs = 'UUUXBBWWPPPPPPPP';
        obj.HW.n.Outputs = 25;
        obj.HW.Outputs = 'UUUXBBWWWPPPPPPPPVVVVVVVVGGG';
        close(obj.GUIHandles.LaunchEmuFig);
        disp('Connection aborted. Bpod started in Emulator mode: State Machine v1.0')
        obj.FirmwareVersion = obj.CurrentFirmware.StateMachine;
        obj.MachineType = 2;
        nModules = sum(obj.HW.Outputs=='U');
        obj.Modules.Connected = zeros(1,nModules);
        obj.Modules.Name = cell(1,nModules);
        obj.Modules.nSerialEvents = ones(1,nModules)*(obj.HW.n.MaxSerialEvents/(nModules+1));
        obj.Modules.EventNames = cell(1,nModules);
        obj.Modules.RelayActive = zeros(1,nModules);
        obj.Modules.USBport = cell(1,nModules);
        AppSerialPortName = [];
    else
        % Get firmware version
        obj.SerialPort.write('F', 'uint8');
        obj.FirmwareVersion = obj.SerialPort.read(1, 'uint16');
        obj.MachineType = obj.SerialPort.read(1, 'uint16');
        switch obj.MachineType
            case 1
               SMName = 'r0.5';
               FirmwareName = 'StateMachine_Bpod05';
            case 2
               SMName = 'r0.7-1.0';
               FirmwareName = 'StateMachine_Bpod1';
            case 3
               SMName = 'r2';
               FirmwareName = 'StateMachine_Bpod2';
                if obj.FirmwareVersion > 22
                    obj.SerialPort.write('v', 'uint8');
                    SM_Revision = obj.SerialPort.read(1, 'uint8');
                    if SM_Revision > 4
                        SMName = 'r2.5';
                        FirmwareName = 'StateMachine_Bpod2_5';
                    end
                end
            case 4
               SMName = 'r2_Plus';
               FirmwareName = 'StateMachine_Bpod2Plus';
               if obj.SerialPort.Interface == 0 % For Teensy 4.1, restart serial port with correct baud rate --> buffer sizes
                   FSMportName = obj.SerialPort.PortName;
                   obj.SerialPort = [];
                   pause(.2);
                   obj.SerialPort = ArCOMObject_Bpod(FSMportName, 480000000, [], [], 1000000, 1000000);
               end
        end
        disp(['Bpod State Machine ' SMName ' connected on port ' obj.SerialPort.PortName])
        if obj.FirmwareVersion ~= obj.CurrentFirmware.StateMachine 
            if obj.FirmwareVersion < obj.CurrentFirmware.StateMachine
                disp(' ');
                disp('***************************************************************');
                disp([char(13) 'NOTICE: Old state machine firmware detected: v' num2str(obj.FirmwareVersion) '. ' char(13)...
                    'You may optionally update the state machine firmware to v' num2str(obj.CurrentFirmware.StateMachine) '.' char(13)...
                    'Click <a href="matlab:EndBpod; LoadBpodFirmware(''' FirmwareName ''', 0, ''' obj.SerialPort.PortName ''');">here</a> to start the update tool, or run LoadBpodFirmware().' char(13)...
                    'If necessary, manual firmware update instructions are <a href="matlab:web(''https://sites.google.com/site/bpoddocumentation/firmware-update'',''-browser'')">here</a>.' char(13)]);
                disp('***************************************************************');
                BpodErrorSound;
                if obj.FirmwareVersion > 21
                    warndlg(['NOTICE: Old state machine firmware detected.' char(10) 'Please read note in the MATLAB command window.']);
                else
                    errordlg(['NOTICE: Old state machine firmware detected.' char(10) 'See instructions in the MATLAB command window.']);
                    error('Error: Old state machine firmware must be upgraded to proceed.');
                end
            else
                obj.SerialPort.write('Z');
                obj.SerialPort = []; % Trigger the ArCOM port's destructor function (closes and releases port)
                obj.GUIData.OldFirmwareFlag = 1; % Signal to the Bpod.m launch code that old firmware was detected
                error('The firmware on the Bpod state machine is newer than your Bpod software for MATLAB. Please update your MATLAB software from the Bpod repository and try again.')
            end
        end
        AvailableUSBPorts = obj.FindUSBSerialPorts;
        % On state machine r2+ or newer, with firmware v23 or newer, find the analog serial port
        if obj.MachineType > 3 && obj.FirmwareVersion > 22
            
            Ports = AvailableUSBPorts(~strcmp(AvailableUSBPorts, obj.SerialPort.PortName)); % Eliminate state machine port
            nPorts = length(Ports);
            iPort = 0; Found = 0;
            while (Found == 0) && (iPort < nPorts)
                iPort = iPort + 1;
                ThisPort = Ports{iPort};
                try
                    TestPort = ArCOMObject_Bpod(ThisPort, 115200);
                    obj.SerialPort.write(['}' 1], 'uint8'); % the '}' op sends an ID byte on the analog serial port
                    pause(.1);
                    if TestPort.bytesAvailable > 0
                        Msg = TestPort.read(1, 'uint8');
                        if Msg == 223
                            Found = 1;
                        end
                    end
                catch
                end
            end
            if Found == 0
                error('Error: Failed to identify the analog serial port');
            end
            TestPort.delete;
            obj.AnalogSerialPort = ArCOMObject_Bpod(Ports{iPort}, 115200);
        end
        AppSerialPortName = [];
        % On state machine r2 or newer, with firmware v23 or newer, find the external app serial port
        if obj.MachineType > 2 && obj.FirmwareVersion > 22
            Ports = AvailableUSBPorts(~strcmp(AvailableUSBPorts, obj.SerialPort.PortName)); % Eliminate state machine port
            if ~isempty(obj.AnalogSerialPort)
                Ports = Ports(~strcmp(Ports, obj.AnalogSerialPort.PortName)); % Eliminate analog serial port
            end
            nPorts = length(Ports);
            iPort = 0; Found = 0;
            while (Found == 0) && (iPort < nPorts)
                iPort = iPort + 1;
                ThisPort = Ports{iPort};
                try
                    TestPort = ArCOMObject_Bpod(ThisPort, 115200);
                    obj.SerialPort.write(['{' 1], 'uint8'); % the '{' op sends an ID byte on the accessory serial port
                    pause(.1);
                    if TestPort.bytesAvailable > 0
                        Msg = TestPort.read(1, 'uint8');
                        if Msg == 222
                            Found = 1;
                        end
                    end
                catch
                end
            end
            if Found == 0
                error('Error: Failed to identify the external app serial port. If another app is connected to it, please close the app and restart Bpod');
            end
            TestPort.delete;
            AppSerialPortName = Ports{iPort};
        end
        
        % Request hardware description
        obj.SerialPort.write('H', 'uint8');
        obj.HW.n = struct; % Stores total numbers of different types of channels (e.g. 5 BNC input channels)
        obj.StateMachineInfo.MaxStates = obj.SerialPort.read(1, 'uint16');
        obj.HW.CyclePeriod = double(obj.SerialPort.read(1, 'uint16'));
        obj.HW.CycleFrequency = 1000000/double(obj.HW.CyclePeriod);
        obj.HW.ValveType = 'SPI';
        obj.HW.n.MaxSerialEvents = double(obj.SerialPort.read(1, 'uint8'));
        if obj.FirmwareVersion > 22
            obj.HW.n.MaxBytesPerSerialMsg = double(obj.SerialPort.read(1, 'uint8'));
        else
            obj.HW.n.MaxBytesPerSerialMsg = 3;
        end
        obj.HW.n.GlobalTimers = double(obj.SerialPort.read(1, 'uint8'));
        obj.HW.n.GlobalCounters  = double(obj.SerialPort.read(1, 'uint8'));
        obj.HW.n.Conditions  = double(obj.SerialPort.read(1, 'uint8'));
        obj.HW.n.Inputs = double(obj.SerialPort.read(1, 'uint8'));
        obj.HW.Inputs = char(obj.SerialPort.read(obj.HW.n.Inputs, 'uint8'));
        obj.HW.n.Outputs = double(obj.SerialPort.read(1, 'uint8'));
        obj.HW.Outputs = [char(obj.SerialPort.read(obj.HW.n.Outputs, 'uint8')) 'GGG']; % G = Global timer / counter
        % Enable ports
        if length(obj.InputsEnabled) ~= obj.HW.n.Inputs
            obj.InputsEnabled = zeros(1,obj.HW.n.Inputs);
            PortPos = find(obj.HW.Inputs == 'P');
            if ~isempty(PortPos)
                obj.InputsEnabled(PortPos(1:3)) = 1;
            end
            obj.InputsEnabled(obj.HW.Inputs == 'B') = 1;
            if obj.MachineType > 1 % v0.7+ uses optoisolators on wire channels; OK to enable by default
                obj.InputsEnabled(obj.HW.Inputs == 'W') = 1;
            end
            if obj.MachineType == 4
                obj.InputsEnabled(obj.HW.Inputs == 'F') = 1; % Enable all flex inputs (for testing)
            end
        end
        obj.SerialPort.write(['E' obj.InputsEnabled], 'uint8');
        Confirmed = obj.SerialPort.read(1, 'uint8');
        if Confirmed ~= 1
            error('Could not enable ports');
        end
        % Sanity check sync config
        if obj.SyncConfig.Channel < 255
            syncIsValid = 1;
            if obj.SyncConfig.Channel+1 > obj.HW.n.Outputs
                syncIsValid = 0;
            else
                SyncChannelType = obj.HW.Outputs(obj.SyncConfig.Channel+1);
                if ~(SyncChannelType == 'B' || SyncChannelType == 'W' || SyncChannelType == 'P')
                    syncIsValid = 0;
                end
            end
            if ~syncIsValid
                warning('Sync is configured for an invalid channel type. Resetting to ''None''')
                obj.SyncConfig.Channel = 255;
                obj.SyncConfig.SignalType = 0;
                copyfile(fullfile(obj.Path.BpodRoot, 'Examples', 'Example Settings Files', 'SyncConfig.mat'), obj.Path.SyncConfig);
            end
        end
        % Set up Sync config
        obj.SerialPort.write(['K' obj.SyncConfig.Channel obj.SyncConfig.SignalType], 'uint8');
        Confirmed = obj.SerialPort.read(1, 'uint8');
        if Confirmed ~= 1
            error('Could not set sync configuration');
        end
        % Read state machine's timestamp return scheme (0 = after each trial, 1 = on each event)
        obj.SerialPort.write('G', 'uint8');
        obj.LiveTimestamps = obj.SerialPort.read(1, 'uint8');
        if ~(obj.LiveTimestamps == 0 || obj.LiveTimestamps == 1)
            error('Error: invalid timestamp scheme returned from state machine.');
        end
    end
    obj.HW.ChannelKey = 'D = digital B/W = BNC/Wire (digital), P = Port (digital in, PWM out), U = UART, X = USB(SoftCode), Z = USB2(External) V = Valve, F = FlexI/O';
    obj.HW.n.BNCOutputs = sum(obj.HW.Outputs == 'B');
    obj.HW.n.BNCInputs = sum(obj.HW.Inputs == 'B');
    obj.HW.n.WireOutputs = sum(obj.HW.Outputs == 'W');
    obj.HW.n.WireInputs = sum(obj.HW.Inputs == 'W');
    obj.HW.n.Ports = sum(obj.HW.Outputs == 'P');
    obj.HW.n.FlexIO = sum(obj.HW.Outputs == 'F');
    obj.HW.FlexIO_ChannelTypes = ones(1, obj.HW.n.FlexIO);
    nIOvalves = sum(obj.HW.Outputs == 'V');
    if nIOvalves > 0
        obj.HW.ValveType = 'IO';
        obj.HW.n.Valves = nIOvalves;
    else
        obj.HW.ValveType = 'SPI';
        obj.HW.n.Valves = obj.HW.n.Ports;
    end
    obj.HW.n.DigitalInputs = obj.HW.n.BNCInputs + obj.HW.n.WireInputs + obj.HW.n.Ports;
    obj.HW.n.UartSerialChannels = sum(obj.HW.Outputs == 'U');
    obj.HW.n.USBChannels = sum(obj.HW.Outputs == 'X');
    obj.HW.n.USBChannels_External = sum(obj.HW.Outputs == 'Z');
    obj.HW.n.SerialChannels = obj.HW.n.USBChannels + obj.HW.n.USBChannels_External + obj.HW.n.UartSerialChannels;
    obj.HW.n.SoftCodes = 15;
    obj.HW.EventTypes = [repmat('S', 1, obj.HW.n.MaxSerialEvents) repmat('F', 1, obj.HW.n.FlexIO*2) repmat('I', 1, obj.HW.n.DigitalInputs*2) repmat('T', 1, obj.HW.n.GlobalTimers*2 ) repmat('+', 1, obj.HW.n.GlobalCounters)  repmat('C', 1, obj.HW.n.Conditions) 'U'];
    obj.HW.EventKey = 'S = serial, F = Flex I/O I = Digital I/O, T = global timer, + = global counter, C = condition, U = state timer';
    obj.HW.FlexIOEventStartposition = find(obj.HW.EventTypes == 'F', 1);
    obj.HW.IOEventStartposition = find(obj.HW.EventTypes == 'I', 1);
    obj.HW.GlobalTimerStartposition = find(obj.HW.EventTypes == 'T', 1);
    obj.HW.GlobalCounterStartposition = find(obj.HW.EventTypes == '+', 1);
    obj.HW.ConditionStartposition = find(obj.HW.EventTypes == 'C', 1);
    obj.HW.StateTimerPosition = find(obj.HW.EventTypes == 'U');
    obj.HW.CircuitRevision = struct;
    obj.HW.CircuitRevision.StateMachine = NaN;
    
    % In firmware v23 or newer, determine circuit board revision and minor firmware version
    if obj.FirmwareVersion > 22 
        if obj.EmulatorMode == 1
            obj.HW.CircuitRevision.StateMachine = 0;
             obj.HW.minorFirmwareVersion = obj.CurrentFirmware.StateMachine_Minor;
        else
            obj.SerialPort.write('v', 'uint8');
            SM_Revision = obj.SerialPort.read(1, 'uint8');
            obj.HW.CircuitRevision.StateMachine = SM_Revision;
            obj.SerialPort.write('f', 'uint8');
            obj.HW.minorFirmwareVersion = obj.SerialPort.read(1, 'uint16');
        end
        if obj.FirmwareVersion == obj.CurrentFirmware.StateMachine
            if obj.HW.minorFirmwareVersion ~= obj.CurrentFirmware.StateMachine_Minor
                disp(' ')
                disp(['**********************ALERT*************************' char(10)...
                      'State machine firmware mismatch detected (minor version).' char(10)... 
                      'The state machine reported version ' num2str(obj.FirmwareVersion) '.' num2str(obj.HW.minorFirmwareVersion) char(10)...
                      'The MATLAB software expects version ' num2str(obj.FirmwareVersion) '.' num2str(obj.CurrentFirmware.StateMachine_Minor) char(10)...
                      'This can happen when using the ''develop'' branch of Bpod_Gen2 or Bpod_StateMachine_Firmware.' char(10)...
                      'Please note that LoadBpodFirmware will not work for minor releases - the firmware update must be loaded with Arduino.' char(10)...
                      '****************************************************'])
                disp(' ');
            end
        end
    end
    obj.HW.AppSerialPortName = AppSerialPortName;
    obj.HW.Pos = struct; % Positions of different channel types in hardware description vectors
    obj.HardwareState.Key = 'F = FlexI/O, D = digital B/W = BNC/Wire (digital), P = Port (digital in, PWM out), S = SPI (Valve array), U = UART, X = USB, Z = USB_EXT V = Valve';
    obj.HardwareState.InputState = zeros(1,obj.HW.n.Inputs);
    obj.HardwareState.InputType = obj.HW.Inputs;
    obj.HardwareState.OutputState = zeros(1,obj.HW.n.Outputs+3);
    obj.HardwareState.OutputType = obj.HW.Outputs;
    obj.HardwareState.OutputOverride = zeros(1,obj.HW.n.Outputs+3);
    obj.LastHardwareState = obj.HardwareState;
    % Find positions of input channel groups
    obj.HW.Pos.Input_FlexIO = find(obj.HW.Inputs == 'F', 1);
    obj.HW.Pos.Input_BNC = find(obj.HW.Inputs == 'B', 1);
    obj.HW.Pos.Input_Wire = find(obj.HW.Inputs == 'W', 1);
    obj.HW.Pos.Input_Port = find(obj.HW.Inputs == 'P', 1);
    obj.HW.Pos.Input_USB = find(obj.HW.Inputs == 'X', 1);
    obj.LoadModules;
    obj.SetupStateMachine;
    obj.BpodSplashScreen(3);
    
    % Set flexIO config
    if obj.MachineType == 4
        nFlexIOChannels = sum(obj.HW.Outputs == 'F');
        if exist(obj.Path.FlexConfig)
            load(obj.Path.FlexConfig)  
        else
            % Load defaults
            FlexIOConfig = struct;
            FlexIOConfig.about = struct;
            FlexIOConfig.channelTypes = ones(1,nFlexIOChannels)*4; % ChannelTypes: 0 = DI, 1 = DO, 2 = ADC, 3 = DAC, 4 = Disabled (Tri-State / High Z)
            FlexIOConfig.analogSamplingRate = 1000; % Hz
            FlexIOConfig.nReadsPerSample = 3; % ADC measurements per sample (averaged)
            FlexIOConfig.threshold1 = ones(1,nFlexIOChannels)*5;
            FlexIOConfig.threshold2 = ones(1,nFlexIOChannels)*5;
            FlexIOConfig.polarity1 = zeros(1,nFlexIOChannels);
            FlexIOConfig.polarity2 = zeros(1,nFlexIOChannels);
            FlexIOConfig.thresholdMode = zeros(1,nFlexIOChannels);
            % Add human-readable info about units, etc
            FlexIOConfig.about.channelTypes = 'Values: 0 = DI, 1 = DO, 2 = ADC, 3 = DAC 4 = OFF (Tri-State / High Z)';
            FlexIOConfig.about.analogSamplingRate = 'Sampling rate for channels configured as ADC. Units = Hz';
            FlexIOConfig.about.nReadsPerSample = 'Number of ADC reads per sample.';
            FlexIOConfig.about.threshold = 'Event thresholds for channels configured as ADC. Two thresholds exist per channel. Units = Volts';
            FlexIOConfig.about.polarity = 'Threshold polarity for channels configured as ADC. 0 = rising (low -> high, 1 = falling (high -> low)';
            FlexIOConfig.about.thresholdMode = '0 = thresholds manually re-enabled, 1 = thresholds re-enable each other';
        end
        obj.FlexIOConfig = FlexIOConfig;
    end
    obj.BpodSplashScreen(4);
    if isfield(obj.SystemSettings, 'BonsaiAutoConnect')
        if obj.SystemSettings.BonsaiAutoConnect == 1
            try
                disp('Attempting to connect to Bonsai. Timeout in 10 seconds...')
                obj.BonsaiSocket = TCPCom(11235);
                disp('Connected to Bonsai on port: 11235')
            catch
                BpodErrorSound;
                disp('Warning: Auto-connect to Bonsai failed. Please connect manually.')
            end
        end
    end
    obj.BpodSplashScreen(5);
    close(obj.GUIHandles.SplashFig);
end