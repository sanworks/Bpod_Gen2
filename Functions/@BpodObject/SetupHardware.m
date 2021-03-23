%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2019 Sanworks LLC, Stony Brook, New York, USA

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
        disp('Connection aborted. Bpod started in Emulator mode: State Machine v0.7.')
        obj.FirmwareVersion = obj.CurrentFirmware.StateMachine;
        obj.MachineType = 2;
        nModules = sum(obj.HW.Outputs=='U');
        obj.Modules.Connected = zeros(1,nModules);
        obj.Modules.Name = cell(1,nModules);
        obj.Modules.nSerialEvents = ones(1,nModules)*(obj.HW.n.MaxSerialEvents/(nModules+1));
        obj.Modules.EventNames = cell(1,nModules);
        obj.Modules.RelayActive = zeros(1,nModules);
        obj.Modules.USBport = cell(1,nModules);
    else
        % Get firmware version
        obj.SerialPort.write('F', 'uint8');
        obj.FirmwareVersion = obj.SerialPort.read(1, 'uint16');
        obj.MachineType = obj.SerialPort.read(1, 'uint16');
        switch obj.MachineType
            case 1
               SMName = 'r0.5';
            case 2
               SMName = 'r0.7-1.0';
            case 3
               SMName = 'r2.0';
            case 4
               SMName = 'r2_Plus';
        end
        disp(['Bpod State Machine ' SMName ' connected on port ' obj.SerialPort.PortName])
        if obj.FirmwareVersion ~= obj.CurrentFirmware.StateMachine 
            if obj.FirmwareVersion < obj.CurrentFirmware.StateMachine
                disp([char(13) 'ERROR: Old state machine firmware detected, v' num2str(obj.FirmwareVersion) '. ' char(13)...
                    'Please update the state machine firmware to v' num2str(obj.CurrentFirmware.StateMachine) ', and try again.' char(13)...
                    'Click <a href="matlab:UpdateBpodFirmware(''' obj.SerialPort.PortName ''');">here</a> to start the update tool, or run UpdateBpodFirmware().' char(13)...
                    'If necessary, manual firmware update instructions are <a href="matlab:web(''https://sites.google.com/site/bpoddocumentation/firmware-update'',''-browser'')">here</a>.' char(13)]);
                BpodErrorSound;
                obj.SerialPort.write('Z');
                obj.SerialPort = []; % Trigger the ArCOM port's destructor function (closes and releases port)
                obj.GUIData.OldFirmwareFlag = 1; % Signal to the Bpod.m launch code that old firmware was detected
                errordlg(['ERROR: Old state machine firmware detected.' char(10) 'See instructions in the MATLAB command window.']);
                %error('Old firmware detected. See instructions above.');
            else
                error('The firmware on the Bpod state machine is newer than your Bpod software for MATLAB. Please update your MATLAB software from the Bpod repository and try again.')
            end
        end
        % Request hardware description
        obj.SerialPort.write('H', 'uint8');
        obj.HW.n = struct; % Stores total numbers of different types of channels (e.g. 5 BNC input channels)
        obj.StateMachineInfo.MaxStates = obj.SerialPort.read(1, 'uint16');
        obj.HW.CyclePeriod = double(obj.SerialPort.read(1, 'uint16'));
        obj.HW.CycleFrequency = 1000000/double(obj.HW.CyclePeriod);
        obj.HW.ValveType = 'SPI';
        obj.HW.n.MaxSerialEvents = double(obj.SerialPort.read(1, 'uint8'));
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
        end
        obj.SerialPort.write(['E' obj.InputsEnabled], 'uint8');
        Confirmed = obj.SerialPort.read(1, 'uint8');
        if Confirmed ~= 1
            error('Could not enable ports');
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
    obj.HW.ChannelKey = 'D = digital B/W = BNC/Wire (digital), P = Port (digital in, PWM out), U = UART, X = USB, V = Valve';
    obj.HW.n.BNCOutputs = sum(obj.HW.Outputs == 'B');
    obj.HW.n.BNCInputs = sum(obj.HW.Inputs == 'B');
    obj.HW.n.WireOutputs = sum(obj.HW.Outputs == 'W');
    obj.HW.n.WireInputs = sum(obj.HW.Inputs == 'W');
    obj.HW.n.Ports = sum(obj.HW.Outputs == 'P');
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
    obj.HW.n.SerialChannels = obj.HW.n.USBChannels + obj.HW.n.UartSerialChannels;
    obj.HW.n.SoftCodes = 10;
    obj.HW.EventTypes = [repmat('S', 1, obj.HW.n.MaxSerialEvents) repmat('I', 1, obj.HW.n.DigitalInputs*2) repmat('T', 1, obj.HW.n.GlobalTimers*2 ) repmat('+', 1, obj.HW.n.GlobalCounters)  repmat('C', 1, obj.HW.n.Conditions) 'U'];
    obj.HW.EventKey = 'S = serial, I = i/o, T = global timer, + = global counter, C = condition, U = state timer';
    obj.HW.IOEventStartposition = find(obj.HW.EventTypes == 'I', 1);
    obj.HW.GlobalTimerStartposition = find(obj.HW.EventTypes == 'T', 1);
    obj.HW.GlobalCounterStartposition = find(obj.HW.EventTypes == '+', 1);
    obj.HW.ConditionStartposition = find(obj.HW.EventTypes == 'C', 1);
    obj.HW.StateTimerPosition = find(obj.HW.EventTypes == 'U');
    obj.HW.Pos = struct; % Positions of different channel types in hardware description vectors
    obj.HardwareState.Key = 'D = digital B/W = BNC/Wire (digital), P = Port (digital in, PWM out), S = SPI (Valve array), U = UART, X = USB, V = Valve';
    obj.HardwareState.InputState = zeros(1,obj.HW.n.Inputs);
    obj.HardwareState.InputType = obj.HW.Inputs;
    obj.HardwareState.OutputState = zeros(1,obj.HW.n.Outputs+3);
    obj.HardwareState.OutputType = obj.HW.Outputs;
    obj.HardwareState.OutputOverride = zeros(1,obj.HW.n.Outputs+3);
    obj.LastHardwareState = obj.HardwareState;
    % Find positions of input channel groups
    obj.HW.Pos.Input_BNC = find(obj.HW.Inputs == 'B', 1);
    obj.HW.Pos.Input_Wire = find(obj.HW.Inputs == 'W', 1);
    obj.HW.Pos.Input_Port = find(obj.HW.Inputs == 'P', 1);
    obj.HW.Pos.Input_USB = find(obj.HW.Inputs == 'X', 1);
    obj.LoadModules;
    obj.SetupStateMachine;
    obj.BpodSplashScreen(3);
    obj.BpodSplashScreen(4);
    if isfield(obj.SystemSettings, 'BonsaiAutoConnect')
        if obj.SystemSettings.BonsaiAutoConnect == 1
            try
                disp('Attempting to connect to Bonsai. Timeout in 10 seconds...')
                BpodSocketServer('connect', 11235);
                obj.BonsaiSocket.Connected = 1;
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