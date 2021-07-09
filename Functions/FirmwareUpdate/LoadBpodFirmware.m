classdef LoadBpodFirmware < handle
    properties
        
    end
    properties (Access = private)
        Port
        gui
    end
    methods
        function obj = LoadBpodFirmware(varargin)
            BpodPath = fileparts(which('Bpod'));
            addpath(genpath(fullfile(BpodPath, 'Functions')));
            AllDevices = {'StateMachine_Bpod2_Standard', 'StateMachine_Bpod0_789', 'BpodWavePlayer_4ch',...
                'BpodWavePlayer_8ch','AnalogInputModule_8ch', 'RotaryEncoderModule', 'DDSModule',...
                'AmbientModule','BpodAudioPlayerLive_4ch', 'BpodHiFiModule_SD', 'BpodHiFiModule_HD', 'StateMachine_Bpod0_5'};
            SerialPortKeywords = {'COM'};
            nKeywords = length(SerialPortKeywords);
            for k = 1:nKeywords
                USBSerialPorts.(SerialPortKeywords{k}) = cell(1,100);
            end
            for k = 1:nKeywords
                [Status RawString] = system(['wmic path Win32_SerialPort Where "Caption LIKE ''%' SerialPortKeywords{k} '%''" Get DeviceID']);
                PortLocations = strfind(RawString, 'COM');
                nPorts = length(PortLocations);
                nPortsAdded = 0;
                for p = 1:nPorts
                    Clip = RawString(PortLocations(p):PortLocations(p)+6);
                    CandidatePort = Clip(1:find(Clip == 32,1, 'first')-1);
                    if ~strcmp(CandidatePort, 'COM1')
                        novelPort = 1;
                        for i = 1:nKeywords
                            if sum(strcmp(CandidatePort, USBSerialPorts.(SerialPortKeywords{i}))) > 0
                                novelPort = 0;
                            end
                        end
                        if novelPort == 1
                            nPortsAdded = nPortsAdded + 1;
                            USBSerialPorts.(SerialPortKeywords{k}){nPortsAdded} = CandidatePort;
                        end
                    end
                end
                USBSerialPorts.(SerialPortKeywords{k}) = USBSerialPorts.(SerialPortKeywords{k})(1:nPortsAdded);
            end
            AllPorts = USBSerialPorts.COM;
            if isempty(AllPorts)
                error('Error: No USB serial devices were detected.');
            end
            obj.gui.Fig  = figure('name','Bpod Firmware Loading Tool', 'position',[100,100,600,200],...
                'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off',...
                'Color',[0.1 0.1 0.1]);
            uicontrol('Style', 'text', 'Position', [25 150 80 30], 'String', 'Device', 'FontSize', 18,...
                'FontWeight', 'bold', 'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', [0.1 1 0.1]); 
            obj.gui.Devices = uicontrol('Style', 'popup', 'Position', [25 80 280 30], 'String', AllDevices, 'FontSize', 12,...
                'FontWeight', 'bold', 'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', [0.1 1 0.1]); 
            uicontrol('Style', 'text', 'Position', [310 150 80 30], 'String', 'Port', 'FontSize', 18,...
                'FontWeight', 'bold', 'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', [0.1 1 0.1]); 
            obj.gui.Ports = uicontrol('Style', 'popup', 'Position', [330 80 100 30], 'String', AllPorts, 'FontSize', 12,...
                'FontWeight', 'bold', 'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', [0.1 1 0.1]); 
            obj.gui.smButton = uicontrol('Style', 'pushbutton', 'Position', [470 80 100 50], 'String', 'Load', 'FontSize', 14,...
                'FontWeight', 'bold', 'Enable', 'on','Callback', @(h,e)obj.updateFirmware(), 'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', [0.1 1 0.1]); 
            
        end
        function updateFirmware(obj, varargin)
            ModuleNamePos = get(obj.gui.Devices, 'Value');
            ModuleNameList = get(obj.gui.Devices, 'String');
            ModuleName = ModuleNameList{ModuleNamePos};
            PortNamePos = get(obj.gui.Ports, 'Value');
            PortNameString = get(obj.gui.Ports, 'String');
            PortName = PortNameString{PortNamePos};
            switch ModuleName
                    case 'BpodWavePlayer_4ch'
                        suffix = '.hex';
                        boardType = 'Teensy3_x';
                        PauseFor = .1;
                    case 'BpodWavePlayer_8ch'
                        suffix = '.hex';
                        boardType = 'Teensy3_x';
                        PauseFor = .1;
                    case 'BpodAudioPlayerLive_4ch'
                        suffix = '.hex';
                        boardType = 'Teensy3_x';
                        PauseFor = .1;
                    case 'AnalogInputModule_8ch'
                        suffix = '.hex';
                        boardType = 'Teensy3_x';
                        PauseFor = .1;
                    case 'RotaryEncoderModule'
                        suffix = '.hex';
                        boardType = 'Teensy3_x';
                        PauseFor = .1;
                    case 'DDSModule'
                        suffix = '.hex';
                        boardType = 'Teensy3_x';
                        PauseFor = .1;
                    case 'AmbientModule'
                        suffix = '.bin';
                        boardType = 'TrinketM0';
                        PauseFor = 1;
                    case 'StateMachine_Bpod0_5'
                        suffix = '.bin';
                        boardType = 'ArduinoDue';
                        PauseFor = 1;
                    case 'StateMachine_Bpod0_789'
                        suffix = '.bin';
                        boardType = 'ArduinoDue';
                        PauseFor = 1;
                    case 'StateMachine_Bpod2_Standard'
                        suffix = '.hex';
                        boardType = 'Teensy3_x';
                        PauseFor = 1;
                    case 'BpodHiFiModule_SD'
                        suffix = '.hex';
                        boardType = 'Teensy4_x';
                        PauseFor = 1;
                    case 'BpodHiFiModule_HD'
                        suffix = '.hex';
                        boardType = 'Teensy4_x';
                        PauseFor = 1;
            end
            FirmwareFilename = [ModuleName suffix];
            progressbar(0.02); pause(.1);
            progressbar(0.6);
            obj.uploadFirmware(PortName, FirmwareFilename, boardType);
            pause(PauseFor);
            progressbar(0.9);            
            progressbar(1);
            BGColor = [0.4 1 0.4];
            obj.gui.ConfirmModal  = figure('name','Firmware Update', 'position',[335,120,280,200],...
                'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off',...
                'Color',BGColor);
                
                uicontrol('Style', 'text', 'Position', [25 140 220 30], 'String', '*GREAT SUCCESS*', 'FontSize', 14,...
                                    'FontWeight', 'bold', 'BackgroundColor', BGColor);
                uicontrol('Style', 'text', 'Position', [15 90 250 30], 'String', ['Firmware update complete'], 'FontSize', 14,...
                                    'FontWeight', 'bold', 'BackgroundColor', BGColor);
                uicontrol('Style', 'pushbutton', 'Position', [90 20 100 40], 'String', 'Ok', 'FontSize', 14,...
                                    'FontWeight', 'bold', 'BackgroundColor', [0.8 0.8 0.8], 'Callback', @(h,e)obj.closeModal());
        end
        function closeModal(obj)
                delete(obj.gui.ConfirmModal);
        end
        function uploadFirmware(obj, TargetPort, Filename, boardType)
            thisFolder = fileparts(which('UpdateBpodFirmware'));
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
                case 'Teensy4_x'
                    [status, msg] = system('taskkill /F /IM teensy.exe');
                    pause(.1);
                    programPath = fullfile(thisFolder, ['tycmd upload ' firmwarePath ' --board "@' TargetPort '"']);
            end
            disp('------Uploading new firmware------')
            system(programPath);
        end
    end
end