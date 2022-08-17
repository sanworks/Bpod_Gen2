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
classdef LoadBpodFirmware < handle
    properties
        
    end
    properties (Access = private)
        Port
        gui
        PortType
        FirmwareVersions
        LoaderApps
    end
    methods
        function obj = LoadBpodFirmware(varargin)
            % Optional args:
            % set2Device: A string containing a filter for the firmware list
            % excludeFSM: 0 to include FSM serial port, 1 to hide it. This only works if the Bpod console is open.
            if ~ispc
                error(['Error: The Bpod firmware updater is not yet available on OSX or Linux.' char(10)...
                    'Please follow instructions <a href="matlab:web(''https://sites.google.com/site/bpoddocumentation/firmware-update'',''-browser'')">here</a> to update with the Arduino application.'])
            end
            set2Device = [];
            excludeFSM = 0;
            if nargin > 0
                set2Device = varargin{1};
            end
            if nargin > 1
                excludeFSM = varargin{2};
            end
            % Set up path
            BpodPath = fileparts(which('Bpod'));
            addpath(genpath(fullfile(BpodPath, 'Functions')));
            FirmwarePath = fullfile(BpodPath, 'Functions', 'FirmwareUpdate');
            % Parse firmware filenames to populate menus
            AllFiles = dir(FirmwarePath);
            nFirmwareFound = 0;
            FirmwareNames = cell(0,1);
            obj.FirmwareVersions = cell(0,1);
            obj.LoaderApps = cell(0,1);
            for i = 3:length(AllFiles)
                FileExt = AllFiles(i).name(end-2:end);
                if strcmp(FileExt, 'bin') || strcmp(FileExt, 'hex')
                    FileName = AllFiles(i).name(1:end-4);
                    DivPos = strfind(FileName, '_'); DivPos = DivPos(end);
                    ThisFirmwareName = FileName(1:DivPos-1);
                    ThisFirmwareVersion = FileName(DivPos+2:end);
                    if sum(strcmp(ThisFirmwareName,FirmwareNames)) > 0
                         obj.FirmwareVersions{nFirmwareFound} = [obj.FirmwareVersions(nFirmwareFound) {ThisFirmwareVersion}];
                         [~, Inds] = sort(str2double(obj.FirmwareVersions{nFirmwareFound}),'descend');
                         obj.FirmwareVersions{nFirmwareFound} = obj.FirmwareVersions{nFirmwareFound}(Inds);
                    else
                        nFirmwareFound = nFirmwareFound + 1;
                        FirmwareNames{nFirmwareFound} = ThisFirmwareName;
                        obj.FirmwareVersions{nFirmwareFound} = ThisFirmwareVersion;
                        switch(FileExt)
                            case 'bin'
                                obj.LoaderApps{nFirmwareFound} = 'bossac';
                            case 'hex'
                                obj.LoaderApps{nFirmwareFound} = 'tycmd';
                        end                     
                    end
                end
            end

            % Get list of USB serial ports
            
            % Identify state machine accessory ports (to exclude from list)
            global BpodSystem
            ExcludedPorts = [];
            if isempty(BpodSystem)
                clear global BpodSystem
            else
                AnalogPort = [];
                FSMPort = [];
                if ~isempty(BpodSystem.AnalogSerialPort)
                    AnalogPort = BpodSystem.AnalogSerialPort.PortName;
                end
                if excludeFSM
                    FSMPort = BpodSystem.SerialPort.PortName;
                end
                ExcludedPorts = [{'COM1','COM2'} AnalogPort FSMPort BpodSystem.HW.AppSerialPortName];
            end

            % Load USB serial ports
            USBSerialPorts = cell(0,1);
            [Status,RawString] = system('powershell.exe "[System.IO.Ports.SerialPort]::getportnames()"');
            nPortsAdded = 0;
            if ~isempty(RawString)
                PortLocations = strsplit(RawString,char(10));
                PortLocations = PortLocations(1:end-1);
                nPorts = length(PortLocations);
                for p = 1:nPorts
                    CandidatePort = PortLocations{p};
                    if sum(strcmp(ExcludedPorts, CandidatePort)) == 0
                        novelPort = 1;
                        if sum(strcmp(CandidatePort, USBSerialPorts)) > 0
                            novelPort = 0;
                        end
                        if novelPort == 1
                            nPortsAdded = nPortsAdded + 1;
                            USBSerialPorts{nPortsAdded} = CandidatePort;
                        end
                    end
                end
            end
            obj.PortType(1:length(USBSerialPorts)) = 1;

            % Load Teensy RawHID boards
            RawHIDs = cell(0);
            programPath = fullfile(fileparts(which('UpdateBpodFirmware')), ['tycmd list']);
            [~, Tstring] = system(programPath);
            if ~isempty(Tstring)
                HardReturns = find(Tstring == 10);
                Pos = 1;
                Found = 0;
                if ~isempty(HardReturns)
                    for i = 1:length(HardReturns)-1
                        Segment = Tstring(Pos:HardReturns(i));
                        if strfind(Segment, 'Teensyduino RawHID')
                            Found = Found + 1;
                            RawHIDs{Found} = Segment(strfind(Segment, 'add ') + 4:strfind(Segment, '-Teensy')-1);
                        end
                        Pos = Pos + length(Segment);
                    end
                    Segment = Tstring(Pos:end);
                    if strfind(Segment, 'Teensyduino RawHID')
                        Found = Found + 1;
                        RawHIDs{Found} = ['SER#' Segment(strfind(Segment, 'add ') + 4:strfind(Segment, '-Teensy')-1)];
                    end
                end
            end
            if ~isempty(RawHIDs)
                obj.PortType = [obj.PortType ones(1,length(RawHIDs))*2];
            end
            if isempty(USBSerialPorts) && isempty(RawHIDs)
                error('Error: No USB serial devices were detected.');
            end
            AllPorts = [USBSerialPorts RawHIDs];

            % Set up GUI
            obj.gui.Fig  = figure('name','Bpod Firmware Loading Tool', 'position',[100,100,755,200],...
                'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off',...
                'Color',[0.1 0.1 0.1]);
            uicontrol('Style', 'text', 'Position', [20 150 120 30], 'String', 'Firmware', 'FontSize', 18,...
                'FontWeight', 'bold', 'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', [0.1 1 0.1]);
            obj.gui.Devices = uicontrol('Style', 'popup', 'Position', [25 80 280 30], 'String', FirmwareNames, 'FontSize', 12,...
                'FontWeight', 'bold','Callback', @(h,e)obj.updateVersions(), 'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', [0.1 1 0.1]);
            uicontrol('Style', 'text', 'Position', [340 150 100 30], 'String', 'Version', 'FontSize', 18,...
                'FontWeight', 'bold', 'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', [0.1 1 0.1]);
            obj.gui.Versions = uicontrol('Style', 'popup', 'Position', [345 80 100 30], 'String', obj.FirmwareVersions{1}, 'FontSize', 12,...
                'FontWeight', 'bold', 'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', [0.1 1 0.1]);
            uicontrol('Style', 'text', 'Position', [465 150 80 30], 'String', 'Port', 'FontSize', 18,...
                'FontWeight', 'bold', 'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', [0.1 1 0.1]);
            obj.gui.Ports = uicontrol('Style', 'popup', 'Position', [480 80 100 30], 'String', AllPorts, 'FontSize', 12,...
                'FontWeight', 'bold', 'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', [0.1 1 0.1]);
            obj.gui.smButton = uicontrol('Style', 'pushbutton', 'Position', [630 75 100 50], 'String', 'Load', 'FontSize', 14,...
                'FontWeight', 'bold', 'Enable', 'on','Callback', @(h,e)obj.updateFirmware(), 'BackgroundColor', [0.1 0.1 0.1], 'ForegroundColor', [0.1 1 0.1]);
            % Filter list if a filter arg was provided
            if ~isempty(set2Device)
                Pos = strfind(FirmwareNames,set2Device);
                Pos = find(~cellfun(@isempty,Pos));
                PosExact = find(strcmp(FirmwareNames, set2Device));
                % Make the exact match rank first
                if ~isempty(PosExact)
                    Pos = [PosExact Pos(Pos ~= PosExact)];
                end
                if ~isempty(Pos)
                    set(obj.gui.Devices, 'Value', 1);
                    set(obj.gui.Devices, 'String', FirmwareNames(Pos));
                    obj.LoaderApps = obj.LoaderApps(Pos);
                    obj.FirmwareVersions = obj.FirmwareVersions(Pos);
                    obj.updateVersions();
                end
            end
            
        end
        function updateVersions(obj, varargin)
            firmwareIndex = get(obj.gui.Devices, 'Value');
            set(obj.gui.Versions, 'Value', 1);
            set(obj.gui.Versions, 'String', obj.FirmwareVersions{firmwareIndex});
        end

        function updateFirmware(obj, varargin)
            ModuleNamePos = get(obj.gui.Devices, 'Value');
            ModuleNameList = get(obj.gui.Devices, 'String');
            ModuleName = ModuleNameList{ModuleNamePos};
            VersionPos = get(obj.gui.Versions, 'Value');
            VersionList = get(obj.gui.Versions, 'String');
            if ~iscell(VersionList)
                VersionList = {VersionList};
            end
            Version = VersionList{VersionPos};
            PortNamePos = get(obj.gui.Ports, 'Value');
            PortNameString = get(obj.gui.Ports, 'String');
            if ~iscell(PortNameString)
                PortNameString = {PortNameString};
            end
            PortName = PortNameString{PortNamePos};
            FileName = [ModuleName '_v' Version];
            progressbar(0.02); pause(.1);
            progressbar(0.6);
            if strcmp(ModuleName, 'StateMachine_Bpod1') || strcmp(ModuleName, 'StateMachine_Bpod05')
                disp('*Note* Firmware upload may take up to 3 minutes and the program may appear to be non-responsive.')
            end
            [OK,msg] = obj.uploadFirmware(PortName, FileName, obj.LoaderApps{ModuleNamePos}, obj.PortType(PortNamePos));
            pause(1);
            progressbar(0.9);
            progressbar(1);
            if OK
                BGColor = [0.4 1 0.4];
                Msg1 = '*GREAT SUCCESS*';
                Msg2 = 'Firmware update complete';
                global BpodSystem;
                if isempty(BpodSystem)
                   clear global BpodSystem
                else
                    BpodSystem.LoadModules;
                end
            else
                BGColor = [1 0.4 0.4];
                Msg1 = '*FAILED*';
                Msg2 = 'See command window';
                disp('Console output:')
                disp(msg)
            end
            obj.gui.ConfirmModal  = figure('name','Firmware Update', 'position',[335,120,280,200],...
                'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off',...
                'Color',BGColor);
            
            uicontrol('Style', 'text', 'Position', [25 140 220 30], 'String', Msg1, 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor);
            uicontrol('Style', 'text', 'Position', [15 90 250 30], 'String', Msg2, 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor);
            uicontrol('Style', 'pushbutton', 'Position', [90 20 100 40], 'String', 'Ok', 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', [0.8 0.8 0.8], 'Callback', @(h,e)obj.closeModal());
           
        end
        function closeModal(obj)
            delete(obj.gui.ConfirmModal);
            delete(obj.gui.Fig);
        end
        function [OK,msg] = uploadFirmware(obj, TargetPort, Filename, loaderApp, portType)
            thisFolder = fileparts(which('LoadBpodFirmware'));
            switch loaderApp
                case 'bossac'
                    firmwarePath = fullfile(thisFolder, [Filename '.bin']);
                    system(['@mode ' TargetPort ':1200,N,8,1']);
                    system('PING -n 3 127.0.0.1>NUL');
                    programPath = fullfile(thisFolder, ['bossac -i -d -U true -e -w -v -b ' firmwarePath ' -R']);
                case 'tycmd'
                    firmwarePath = fullfile(thisFolder, [Filename '.hex']);
                    [status, msg] = system('taskkill /F /IM teensy.exe');
                    pause(.1);
                    switch portType
                        case 1
                            programPath = fullfile(thisFolder, ['tycmd upload ' firmwarePath ' --board "@' TargetPort '"']);
                        case 2
                            programPath = fullfile(thisFolder, ['tycmd upload ' firmwarePath ' --board "' TargetPort(5:end) '"']);
                    end
            end
            disp('------Uploading new firmware------')
            disp([Filename ' ==> ' TargetPort])
            [status, msg] = system(programPath);
            OK = 0;
            if ~isempty(strfind(msg, 'Sending reset command')) || ~isempty(strfind(msg, 'Verify successful'))
                OK = 1;
            end
            if OK
                disp('----------UPDATE COMPLETE---------')
            else
                disp('----------FAILED TO LOAD----------')
            end
            disp(' ');
        end
    end
end