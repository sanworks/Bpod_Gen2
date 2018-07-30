classdef UpdateBpodFirmware < handle
    properties
        
    end
    properties (Access = private)
        CurrentFirmware
        StateMachinePort
        gui
        HW
        MachineType
        LatestModuleFirmware
        ModuleNames
        ModuleUSBPorts
    end
    methods
        function obj = UpdateBpodFirmware(varargin)
            global BpodSystem
            if ~ispc
                error(['Error: The Bpod firmware updater is not yet available on OSX or Linux.' char(10)...
                    'Please follow instructions <a href="matlab:web(''https://sites.google.com/site/bpoddocumentation/firmware-update'',''-browser'')">here</a> to update with the Arduino application.'])
            end
            disp(' ');
            disp('----Bpod Firmware Updater Beta----')
            disp('*IMPORTANT* The Bpod firmware update tool is a BETA release.')
            disp('If it does not work, you may need to update your firmware')
            disp('manually. To do so, follow the instructions <a href="matlab:web(''https://sites.google.com/site/bpoddocumentation/firmware-update'',''-browser'')">here</a>.')
            disp(' ');
            reply = input('Do you want to launch the update tool? (y/n) ', 's');
            if lower(reply) ~= 'y'
                error('Firmware updater aborted by user.')
            end
            BpodPath = fileparts(which('Bpod'));
            addpath(genpath(fullfile(BpodPath, 'Functions')));
            obj.CurrentFirmware = CurrentFirmwareList;
            if ~isempty(BpodSystem) && isvalid(BpodSystem)
                StateMachinePort = BpodSystem.SerialPort.PortName;
                SMFirmwareVersion = BpodSystem.FirmwareVersion;
                ModuleFirmwareVersions = BpodSystem.Modules.FirmwareVersion;
                obj.ModuleNames = BpodSystem.Modules.Name;
                obj.MachineType = BpodSystem.MachineType;
                obj.ModuleUSBPorts = BpodSystem.Modules.USBport;
                USBWarning = 0;
                nModules = length(obj.ModuleNames);
                hasUSBPairing = zeros(1,nModules);
                for i = 1:nModules
                    ThisModuleName = obj.ModuleNames{i};
                    if ~strcmp(ThisModuleName(1:end-1), 'Serial')
                        if isempty(obj.ModuleUSBPorts{i})
                            USBWarning = 1;
                        else
                            hasUSBPairing(i) = 1;
                        end
                    end
                end
                if USBWarning == 1
                    BpodErrorSound;
                    warndlg(['Important: To update a module, it must first be' char(10)...
                           'paired with its corresponding USB serial port.' char(10)...
                           'Use USB icon on the Bpod console,' char(10)...
                           'then restart the updater: UpdateBpodFirmware()']);
                end
            else
                if nargin > 0
                    StateMachinePort = varargin{1};
                else
                    error('Error: Please call UpdateBpodFirmware with a port argument for the state machine, e.g. UpdateBpodFirmware(''COM3'')');
                end
                Port = ArCOMObject_Bpod(StateMachinePort, 115200);
                obj.SMhandshake(Port); % Make sure it's a state machine
                [SMFirmwareVersion, MachineType] = obj.GetFirmwareVer(Port);
                obj.MachineType = MachineType;
                pause(.1);
                % Request hardware description
                Port.write('H', 'uint8');
                obj.HW.n = struct; % Stores total numbers of different types of channels (e.g. 5 BNC input channels)
                MaxStates = Port.read(1, 'uint16');
                obj.HW.CyclePeriod = double(Port.read(1, 'uint16'));
                obj.HW.CycleFrequency = 1000000/double(obj.HW.CyclePeriod);
                obj.HW.ValveType = 'SPI';
                obj.HW.n.MaxSerialEvents = double(Port.read(1, 'uint8'));
                obj.HW.n.GlobalTimers = double(Port.read(1, 'uint8'));
                obj.HW.n.GlobalCounters  = double(Port.read(1, 'uint8'));
                obj.HW.n.Conditions  = double(Port.read(1, 'uint8'));
                obj.HW.n.Inputs = double(Port.read(1, 'uint8'));
                obj.HW.Inputs = char(Port.read(obj.HW.n.Inputs, 'uint8'));
                obj.HW.n.Outputs = double(Port.read(1, 'uint8'));
                obj.HW.Outputs = [char(Port.read(obj.HW.n.Outputs, 'uint8')) 'GGG']; % G = Global timer / counter
                pause(.1);
                Port.write('Z', 'uint8');
                clear Port
                ModuleFirmwareVersions = [];
            end
            BGColor = [0.8 0.8 0.8];
            Height = 260;
            obj.gui.Fig  = figure('name','Bpod Firmware Update Tool', 'position',[100,100,740,Height],...
                'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off',...
                'Color',[0.8 0.8 0.8]);
            Ypos = Height-40;
            if isempty(ModuleFirmwareVersions)
                nModules = 0;
            else
                nModules = length(ModuleFirmwareVersions);
            end
            % Device
            uicontrol('Style', 'text', 'Position', [20 Ypos 170 30], 'String', 'Device', 'FontSize', 18,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor); Ypos = Ypos - 45;
            uicontrol('Style', 'edit', 'Position', [20 Ypos 170 30], 'String', 'State Machine', 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor); Ypos = Ypos - 30;
            for i = 1:nModules
                ModuleName = obj.ModuleNames{i};
                if strcmp(ModuleName(1:6), 'Serial')
                    SerNum = ModuleName(end);
                    ModuleName = ['Module' num2str(SerNum)];
                end
                uicontrol('Style', 'edit', 'Position', [20 Ypos 170 30], 'String', ModuleName, 'FontSize', 14,...
                    'FontWeight', 'bold', 'Enable', 'inactive', 'BackgroundColor', BGColor); Ypos = Ypos - 30;
            end
            Ypos = Height-40;
            % Firmware Ver
            uicontrol('Style', 'text', 'Position', [195 Ypos 170 30], 'String', 'Firmware ver.', 'FontSize', 18,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor); Ypos = Ypos - 45;
            obj.gui.StateMachineFV = uicontrol('Style', 'edit', 'Position', [195 Ypos 170 30], 'String', num2str(SMFirmwareVersion), 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor); Ypos = Ypos - 30;
            for i = 1:nModules
                thisModuleFirmware = ModuleFirmwareVersions(i);
                if ModuleFirmwareVersions(i) == 0
                    FV = '---';
                else
                    FV = num2str(thisModuleFirmware);
                end
                obj.gui.ModuleFV(i) = uicontrol('Style', 'edit', 'Position', [195 Ypos 170 30], 'String', FV, 'FontSize', 14,...
                    'FontWeight', 'bold', 'Enable', 'inactive', 'BackgroundColor', BGColor); Ypos = Ypos - 30;
            end
            % Latest firmware
            Ypos = Height-40;
            uicontrol('Style', 'text', 'Position', [370 Ypos 170 30], 'String', 'Latest ver.', 'FontSize', 18,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor); Ypos = Ypos - 45;
            obj.gui.FV = uicontrol('Style', 'edit', 'Position', [370 Ypos 170 30], 'String', num2str(obj.CurrentFirmware.StateMachine), 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor); Ypos = Ypos - 30;
            obj.LatestModuleFirmware = zeros(1,nModules);
            for i = 1:nModules
                ModuleName = obj.ModuleNames{i};
                if strcmp(ModuleName(1:6), 'Serial')
                    obj.LatestModuleFirmware(i) = ModuleFirmwareVersions(i);
                else
                    obj.LatestModuleFirmware(i) = obj.CurrentFirmware.(ModuleName(1:end-1));
                end
                thisModuleFirmware = obj.LatestModuleFirmware(i);
                if ModuleFirmwareVersions(i) == 0
                    FV = '---';
                else
                    FV = num2str(thisModuleFirmware);
                end
                uicontrol('Style', 'edit', 'Position', [370 Ypos 170 30], 'String', FV, 'FontSize', 14,...
                    'FontWeight', 'bold', 'Enable', 'inactive', 'BackgroundColor', BGColor); Ypos = Ypos - 30;
            end
            % Update Buttons
            Ypos = Height-40;
            uicontrol('Style', 'text', 'Position', [545 Ypos 170 30], 'String', 'Update', 'FontSize', 18,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor); Ypos = Ypos - 45;
            Enable = 'on';
            if (obj.CurrentFirmware.StateMachine == SMFirmwareVersion)
                Enable = 'off';
            end
            obj.gui.smButton = uicontrol('Style', 'pushbutton', 'Position', [545 Ypos 170 30], 'String', 'Update', 'FontSize', 14,...
                'FontWeight', 'bold', 'Enable', Enable,'Callback', @(h,e)obj.updateFirmware()); Ypos = Ypos - 30;
            for i = 1:nModules
                thisModuleFirmware = ModuleFirmwareVersions(i);
                Enable = 'on';
                thisModuleName = obj.ModuleNames{i};
                if thisModuleFirmware == 0
                        Enable = 'off';
                elseif thisModuleFirmware == obj.CurrentFirmware.(thisModuleName(1:end-1))
                        Enable = 'off';
                end
                if hasUSBPairing(i) == 0
                    Enable = 'off';
                end
                obj.gui.moduleButton(i) = uicontrol('Style', 'pushbutton', 'Position', [545 Ypos 170 30], 'String', 'Update', 'FontSize', 14,...
                    'FontWeight', 'bold', 'Enable', 'inactive', 'Enable', Enable,'Callback', @(h,e)obj.updateFirmware(i)); Ypos = Ypos - 30;
            end
            if nModules == 0
                uicontrol('Style', 'text', 'Position', [30 Height-180 710 30], 'String', 'Note: Run Bpod() first to view connected modules', 'FontSize', 18,...
                    'BackgroundColor', BGColor); Ypos = Ypos - 45;
            end
            obj.StateMachinePort = StateMachinePort;
        end
        function updateFirmware(obj, varargin)
            global BpodSystem
            ModuleNum = 0;
            if nargin > 1
                ModuleNum = varargin{1};
                ModuleName = obj.ModuleNames{ModuleNum};
            end
            progressbar(0); pause(.2);
            obj.CurrentFirmware = CurrentFirmwareList;
            if ModuleNum == 0
                if obj.MachineType == 3
                    boardType = 'Teensy3_x';
                    if obj.HW.n.GlobalTimers == 20
                        FirmwareFilename = 'StateMachine_Bpod2_BControl.hex';
                    else
                        FirmwareFilename = 'StateMachine_Bpod2_Standard.hex';
                    end
                    PauseFor = .1;
                elseif obj.MachineType == 2
                    boardType = 'ArduinoDue';
                    FirmwareFilename = 'StateMachine_Bpod1.bin';
                    PauseFor = 1;
                elseif obj.MachineType == 1
                    boardType = 'ArduinoDue';
                    FirmwareFilename = 'StateMachine_Bpod0_5.bin';
                    PauseFor = 1;
                end
                Port = obj.StateMachinePort;
            else
                Port = obj.ModuleUSBPorts{ModuleNum};
                switch ModuleName(1:end-1)
                    case 'WavePlayer'
                        boardType = 'Teensy3_x';
                        PauseFor = .1;
                        W = BpodWavePlayer(Port, 'NoWarnings');
                        nChannels = length(W.LoopDuration);
                        clear W
                        if nChannels == 4
                            FirmwareFilename = 'BpodWavePlayer_4ch.hex';
                        elseif nChannels == 8
                            FirmwareFilename = 'BpodWavePlayer_8ch.hex';
                        end
                    case 'AudioPlayer'
                        boardType = 'Teensy3_x';
                        PauseFor = .1;
                        A = BpodAudioPlayer(Port, 'NoWarnings');
                        if strcmp(A.Info.playerType, 'AudioPlayer Live')
                            FirmwareFilename = 'BpodAudioPlayerLive_4ch.hex';
                        else
                            FirmwareFilename = 'BpodAudioPlayer_4ch.hex';
                        end
                        clear A
                    case 'AnalogIn'
                        boardType = 'Teensy3_x';
                        FirmwareFilename = 'AnalogInputModule_8ch.hex';
                        PauseFor = .1;
                    case 'RotaryEncoder'
                        boardType = 'Teensy3_x';
                        FirmwareFilename = 'RotaryEncoderModule.hex';
                        PauseFor = .1;
                    case 'DDSModule'
                        boardType = 'Teensy3_x';
                        FirmwareFilename = 'DDSModule.hex';
                        PauseFor = .1;
                    case 'AmbientModule'
                        boardType = 'TrinketM0';
                        FirmwareFilename = 'AmbientModule.bin';
                        PauseFor = 1;
                        A = AmbientModule(Port);
                        pause(.1);
                        AmbientCal = A.getCalibration;
                        pause(.1);
                        clear A
                    otherwise
                        BpodErrorDlg(['This tool cannot yet update' char(10) ModuleName(1:end-1) ' modules '])
                end
            end
            progressbar(0.02); pause(.1);
            obj.uploadFirmware(Port, FirmwareFilename, boardType);
            progressbar(0.6);
            pause(PauseFor);
            progressbar(0.9);
            if ModuleNum == 0
                Port = ArCOMObject_Bpod(obj.StateMachinePort, 115200);
                obj.SMhandshake(Port); % Make sure it's a state machine
                [FirmwareVersion, MachineType] = obj.GetFirmwareVer(Port);
                CurrentFirmwareVersion = obj.CurrentFirmware.StateMachine;
                pause(.1);
                Port.write('Z', 'uint8');
                clear Port
            else
                ThisModuleType = ModuleName(1:end-1);
                CurrentFirmwareVersion = obj.CurrentFirmware.(ThisModuleType);
                pause(.1);
                BpodSystem.StartModuleRelay(ModuleName);
                ModuleWrite(ModuleName, 255, 'uint8'); % Request self-description (incl. firmware version)
                pause(.1);
                Reply = ModuleRead(ModuleName, BpodSystem.SerialPort.bytesAvailable, 'uint8');
                % Request again - sometimes first request immediately after a firmware
                % flash contains a spurious byte
                ModuleWrite(ModuleName, 255, 'uint8'); % Request self-description (incl. firmware version)
                pause(.1);
                Reply = ModuleRead(ModuleName, BpodSystem.SerialPort.bytesAvailable, 'uint8');
                FirmwareVersion = typecast(Reply(2:5), 'uint32');
                BpodSystem.StopModuleRelay;
                if strcmp(ModuleName(1:end-1), 'AmbientModule')
                    % Re-flash calibration values
                    A = AmbientModule(Port);
                    pause(.1);
                    A.setCalibration(AmbientCal.Temperature_C, AmbientCal.AirPressure_mb, AmbientCal.RelativeHumidity);
                    pause(.1);
                    clear A
                end
            end
            
            progressbar(1);
            Success = 0;
            if FirmwareVersion == CurrentFirmwareVersion
                Success = 1;
            else
                error(['Error: Update NOT successful. State machine still has firmware v' num2str(FirmwareVersion)])
            end
            if Success == 1 
                BGColor = [0.4 1 0.4];
            else
                BGColor = [1 0.4 0.4];
            end
            obj.gui.ConfirmModal  = figure('name','Firmware Update', 'position',[335,120,280,200],...
                'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off',...
                'Color',BGColor);
            if Success == 1 
                if ModuleNum == 0
                    set(obj.gui.smButton, 'Enable', 'off');
                    set(obj.gui.StateMachineFV, 'String', num2str(FirmwareVersion));
                else
                    set(obj.gui.moduleButton(ModuleNum), 'Enable', 'off');
                    set(obj.gui.ModuleFV(ModuleNum), 'String', num2str(FirmwareVersion));
                    BpodSystem.Modules.FirmwareVersion(ModuleNum) = FirmwareVersion;
                end
                
                uicontrol('Style', 'text', 'Position', [60 140 150 30], 'String', 'Success!', 'FontSize', 14,...
                                    'FontWeight', 'bold', 'BackgroundColor', BGColor);
                uicontrol('Style', 'text', 'Position', [15 90 250 30], 'String', ['Firmware is now v' num2str(FirmwareVersion)], 'FontSize', 14,...
                                    'FontWeight', 'bold', 'BackgroundColor', BGColor);
                uicontrol('Style', 'pushbutton', 'Position', [90 20 100 40], 'String', 'Ok', 'FontSize', 14,...
                                    'FontWeight', 'bold', 'BackgroundColor', [0.8 0.8 0.8], 'Callback', @(h,e)obj.closeModal());
                disp('------Firmware update complete------')
            else
                uicontrol('Style', 'text', 'Position', [60 140 150 30], 'String', 'Failure', 'FontSize', 14,...
                                    'FontWeight', 'bold', 'BackgroundColor', BGColor);
                uicontrol('Style', 'text', 'Position', [15 90 250 30], 'String', ['Firmware is still v' num2str(obj.CurrentFirmware.StateMachine)], 'FontSize', 14,...
                                    'FontWeight', 'bold', 'BackgroundColor', BGColor);
                uicontrol('Style', 'pushbutton', 'Position', [90 20 100 40], 'String', 'Ok', 'FontSize', 14,...
                                    'FontWeight', 'bold', 'BackgroundColor', [0.8 0.8 0.8], 'Callback', @(h,e)obj.closeModal());
            end
        end
        function closeModal(obj)
                delete(obj.gui.ConfirmModal);
        end
        function uploadFirmware(obj, TargetPort, Filename, boardType)
            thisFolder = fileparts(which(mfilename));
            firmwarePath = fullfile(thisFolder, Filename);
            switch boardType
                case 'ArduinoDue'
                    system(['@mode ' TargetPort ':1200,N,8,1']);
                    system('PING -n 3 127.0.0.1>NUL');
                    programPath = fullfile(thisFolder, ['bossac -i -d -U true -e -w -v -b ' firmwarePath ' -R']);
                case 'TrinketM0'
                    system(['@mode ' TargetPort ':1200,N,8,1']);
                    system('PING -n 3 127.0.0.1>NUL');
                    programPath = fullfile(thisFolder, ['bossac -i -d -U true -e -w -v -b ' firmwarePath ' -R']);
                case 'Teensy3_x'
                    [status, msg] = system('taskkill /F /IM teensy.exe');
                    pause(.1);
                    programPath = fullfile(thisFolder, ['tycmd upload ' firmwarePath ' --board "@' TargetPort '"']);
            end
            disp('------Uploading new firmware------')
            system(programPath);
        end
        function SMhandshake(obj, Port)
            Port.read(Port.bytesAvailable, 'uint8');
            Port.write('6', 'uint8');
            pause(.2);
            Reply = Port.read(1, 'uint8');
            if (Reply == 222)
                while Reply == 222
                    pause(.1);
                    Reply = Port.read(1, 'uint8');
                end
            end
            if (Reply ~= '5') % If the Bpod state machine replied correctly
                error(['Error: could not find a state machine on port ' StateMachinePort]);
            end
        end
        function [SMFirmwareVersion, MachineType] = GetFirmwareVer(obj, Port)
            Port.write('F', 'uint8');
            SMFirmwareVersion = Port.read(1, 'uint16');
            MachineType = Port.read(1, 'uint16');
        end
    end
end