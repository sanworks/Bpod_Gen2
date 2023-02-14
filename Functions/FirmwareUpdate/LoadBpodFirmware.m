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
        tycmd
    end
    methods
        function obj = LoadBpodFirmware(varargin)
            % Optional args:
            % set2Device: A string containing a filter for the firmware list
            % excludeFSM: 0 to include FSM serial port, 1 to hide it. This only works if the Bpod console is open.
            if ~ismember(computer,{'PCWIN64', 'GLNXA64'})
                error(['Error: The Bpod firmware updater is not yet available on %s.' char(10)...
                    'Please follow instructions <a href="matlab:web(''https://sites.google.com/site/bpoddocumentation/firmware-update'',''-browser'')">here</a> to update with the Arduino application.'],computer)
            end
            set2Device = [];
            set2Port = [];
            excludeFSM = 0;
            if nargin > 0
                set2Device = varargin{1};
            end
            if nargin > 1
                excludeFSM = varargin{2};
            end
            if nargin > 2
                set2Port = varargin{3};
            end
            
            % Location of firmware binaries
            FirmwarePath = fileparts(mfilename('fullpath'));
            
            % Define path for tycmd executable
            switch computer
                case 'PCWIN64'
                    obj.tycmd = fullfile(FirmwarePath,'tycmd');
                case 'MAXI64'
                    obj.tycmd = fullfile(FirmwarePath,'tycmd_osx');
                case 'GLNXA64'
                    obj.tycmd = fullfile(FirmwarePath,'tycmd_linux64');
            end
            
            % Check for udev rules on linux
            if ~ismac && isunix && ~exist('/etc/udev/rules.d/00-teensy.rules','file')
                error(['Error: Cannot find teensy udev rules.' char(10) ...
                    'Please follow instructions <a href="matlab:web(''https://www.pjrc.com/teensy/td_download.html'',''-browser'')">here</a> to install them.'])
            end
            
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
                        obj.FirmwareVersions{nFirmwareFound} = [obj.FirmwareVersions{nFirmwareFound} {ThisFirmwareVersion}];
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
            if exist('serialportlist','file')
                USBSerialPorts = sort(serialportlist('available'));
            elseif exist('seriallist','file')
                USBSerialPorts = sort(seriallist('available'));
            else % MATLAB pre r2017a. Fall back to system call
                if ispc
                    USBSerialPorts = cell(0,1);
                    [Status,RawString] = system('powershell.exe -inputformat none "[System.IO.Ports.SerialPort]::getportnames()"');
                    nPortsAdded = 0;
                    if ~isempty(RawString)
                        PortLocations = strsplit(RawString,char(10));
                        PortLocations = PortLocations(1:end-1);
                        nPorts = length(PortLocations);
                        for p = 1:nPorts
                            CandidatePort = PortLocations{p};
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
                elseif ismac % Contributed by Thiago Gouvea JUN_9_2016
                    [trash, RawSerialPortList] = system('ls /dev/cu.usbmodem*');
                    string = strtrim(RawSerialPortList);
                    PortStringPositions = strfind(string, '/dev/cu.usbmodem');
                    StringEnds = find(string == 9);
                    nPorts = length(PortStringPositions);
                    CandidatePorts = cell(1,nPorts);
                    nGoodPorts = 0;
                    for x = 1:nPorts
                        if x < nPorts && nPorts > 1
                            CandidatePort = string(PortStringPositions(x):StringEnds(x)-1);
                        elseif x == nPorts
                            CandidatePort = string(PortStringPositions(x):end);
                        end
                        nGoodPorts = nGoodPorts + 1;
                        CandidatePorts{nGoodPorts} = CandidatePort;
                    end
                    USBSerialPorts = CandidatePorts(1:nGoodPorts);
                else
                    [trash, RawSerialPortList] = system('ls /dev/ttyACM*');
                    string = strtrim(RawSerialPortList);
                    PortStringPositions = strfind(string, '/dev/ttyACM');
                    nPorts = length(PortStringPositions);
                    CandidatePorts = cell(1,nPorts);
                    nGoodPorts = 0;
                    for x = 1:nPorts
                        if PortStringPositions(x)+11 <= length(string)
                            CandidatePort = strtrim(string(PortStringPositions(x):PortStringPositions(x)+11));
                            nGoodPorts = nGoodPorts + 1;
                            CandidatePorts{nGoodPorts} = CandidatePort;
                        end
                    end
                    USBSerialPorts = CandidatePorts(1:nGoodPorts);
                end
            end
            obj.PortType(1:length(USBSerialPorts)) = 1;
            
            % Identify state machine accessory ports (to exclude from list)
            global BpodSystem
            ExcludedPorts = {};
            if isempty(BpodSystem) || ~isvalid(BpodSystem)
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
                ExcludedPorts = [{'COM1','COM2'} AnalogPort ...
                    FSMPort BpodSystem.HW.AppSerialPortName];
            end
            USBSerialPorts = setdiff(USBSerialPorts, ExcludedPorts);
            
            % Get Teensy RawHID boards
            [~, Tstring] = system(['"' obj.tycmd '" list']);
            AllRawHIDs = cell(0);
            if ~isempty(Tstring)
                HardReturns = find(Tstring == 10);
                Pos = 1;
                Found = 0;
                if ~isempty(HardReturns)
                    for i = 1:length(HardReturns)-1
                        Segment = Tstring(Pos:HardReturns(i));
                        if ~isempty(strfind(Segment, 'Teensyduino RawHID')) || ~isempty(strfind(Segment, 'HalfKay'))
                            Found = Found + 1;
                            AllRawHIDs{Found} = ['SER#' Segment(strfind(Segment, 'add ') + 4:strfind(Segment, '-Teensy')-1)];
                        end
                        Pos = Pos + length(Segment);
                    end
                    Segment = Tstring(Pos:end);
                    if ~isempty(strfind(Segment, 'Teensyduino RawHID')) || ~isempty(strfind(Segment, 'HalfKay'))
                        Found = Found + 1;
                        AllRawHIDs{Found} = ['SER#' Segment(strfind(Segment, 'add ') + 4:strfind(Segment, '-Teensy')-1)];
                    end
                end
            end
            obj.PortType = [obj.PortType ones(1,length(AllRawHIDs))*2];
            
            % Combine lists of USB serial ports & RawHID devices
            AllPorts = [USBSerialPorts AllRawHIDs];
            if isempty(AllPorts)
                error('Error: No USB serial devices were detected.');
            end
            labelOffset = 0;
            if ispc
                labelOffset = -10;
            end
            % Set up GUI
            BpodPath = which('Bpod');
            BGPath = fullfile(BpodPath(1:end-6), 'Assets', 'Bitmap', 'FirmwareBG.bmp');
            BG = imread(BGPath);
            obj.gui.Fig  = figure('name','Bpod Firmware Loading Tool', 'position',[100,100,855,200],...
                'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off',...
                'Color',[0.1 0.1 0.1],'CloseRequestFcn',@(h,e)obj.clearObject());
            BGAxes = axes('units','normalized', 'position',[0 0 1 1]);
            uistack(BGAxes,'bottom');
            image(BG); axis off;
            uicontrol('Style', 'text', 'Position', [18+labelOffset 150 140 30], 'String', 'Firmware', 'FontSize', 18,...
                'FontWeight', 'bold', 'BackgroundColor', [0.05 0.1 0.05], 'ForegroundColor', [0.1 1 0.1]);
            obj.gui.Devices = uicontrol('Style', 'popup', 'Position', [25 80 280 30], 'String', FirmwareNames, 'FontSize', 12,...
                'FontWeight', 'bold','Callback', @(h,e)obj.updateVersions(), 'BackgroundColor', [0.05 0.1 0.05], 'ForegroundColor', [0.1 1 0.1]);
            uicontrol('Style', 'text', 'Position', [335+labelOffset 150 120 30], 'String', 'Version', 'FontSize', 18,...
                'FontWeight', 'bold', 'BackgroundColor', [0.05 0.1 0.05], 'ForegroundColor', [0.1 1 0.1]);
            obj.gui.Versions = uicontrol('Style', 'popup', 'Position', [345 80 100 30], 'String', obj.FirmwareVersions{1}, 'FontSize', 12,...
                'FontWeight', 'bold', 'BackgroundColor', [0.05 0.1 0.05], 'ForegroundColor', [0.1 1 0.1]);
            uicontrol('Style', 'text', 'Position', [465 150 80 30], 'String', 'Port', 'FontSize', 18,...
                'FontWeight', 'bold', 'BackgroundColor', [0.05 0.1 0.05], 'ForegroundColor', [0.1 1 0.1]);
            obj.gui.Ports = uicontrol('Style', 'popup', 'Position', [480 80 200 30], 'String', AllPorts, 'FontSize', 12,...
                'FontWeight', 'bold', 'BackgroundColor', [0.05 0.1 0.05], 'ForegroundColor', [0.1 1 0.1]);
            obj.gui.smButton = uicontrol('Style', 'pushbutton', 'Position', [730 75 100 50], 'String', 'Load', 'FontSize', 14,...
                'FontWeight', 'bold', 'Enable', 'on','Callback', @(h,e)obj.updateFirmware(), 'BackgroundColor', [0.05 0.1 0.05], 'ForegroundColor', [0.1 1 0.1]);
            % Filter list if a filter arg was provided
            if ~isempty(set2Device)
                if strcmp(set2Device, 'PA') % Special handling of port array module for backwards compatability
                    set2Device = 'PortArray';
                end
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
            % Set the port if a port arg was provided
            if ~isempty(set2Port)
                PosExact = find(strcmp(AllPorts, set2Port));
                if ~isempty(PosExact)
                    set(obj.gui.Ports, 'Value', PosExact);
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
            pause(1); % Time for HiFi module to finish booting
            progressbar(1);
            FontSize = 14;
            if isunix
                FontSize = 12;
            end
            if OK
                BGColor = [0.1 0.9 0.1];
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
            
            obj.gui.Msg1 = uicontrol('Style', 'text', 'Position', [25 140 220 30], 'String', Msg1, 'FontSize', FontSize,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor);
            obj.gui.Msg2 = uicontrol('Style', 'text', 'Position', [15 90 250 30], 'String', Msg2, 'FontSize', FontSize,...
                'FontWeight', 'bold', 'BackgroundColor', BGColor);
            uicontrol('Style', 'pushbutton', 'Position', [90 20 100 40], 'String', 'Ok', 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', [0.05 0.1 0.05], 'ForegroundColor', [0.1 1 0.1], 'Callback', @(h,e)obj.closeModal());
            if OK
                BGColor(2) = 0.1;
                try
                    for i = 1:100
                        BGColor(2) = BGColor(2) + (0.8/100);
                        set(obj.gui.ConfirmModal, 'Color', BGColor);
                        set(obj.gui.Msg1, 'BackgroundColor', BGColor);
                        set(obj.gui.Msg2, 'BackgroundColor', BGColor);
                        pause(.005);
                        drawnow;
                    end
                    BGColor = [0.1 0.9 0.1];
                    set(obj.gui.ConfirmModal, 'Color', BGColor);
                    set(obj.gui.Msg1, 'BackgroundColor', BGColor);
                    set(obj.gui.Msg2, 'BackgroundColor', BGColor);
                catch
                end

            end
            
        end
        function closeModal(obj)
            delete(obj.gui.ConfirmModal);
            delete(obj.gui.Fig);
            evalin('base', 'clear ans');
        end
        function [OK,msg] = uploadFirmware(obj, TargetPort, Filename, loaderApp, portType)
            % Warn if non-FSM firmware is about to get loaded to an FSM
            if portType == 1
                isFSMFirmware = ~isempty(strfind(Filename, 'StateMachine'));
                if ~isFSMFirmware
                    tempPort = ArCOMObject_Bpod(TargetPort);
                    pause(.3);
                    portIsKnownFSM = 0;
                    if tempPort.bytesAvailable > 0
                        Msg = tempPort.read(1, 'uint8');
                        if Msg == 222
                            portIsKnownFSM = 1;
                        end
                    end
                    clear tempPort
                    if portIsKnownFSM
                        disp('****** WARNING ******')
                        disp(['State Machine detected on Port ' TargetPort '.' char(10) Filename ' is not state machine firmware!'])
                        Reply = input('Enter ''y'' to load anyway, or any other key to exit >', 's');
                        disp(' ');
                        if Reply ~= 'y'
                            OK = 0;
                            msg = ['Firmware upload canceled by the user.' char(10) 'Please select state machine firmware and try again.'];
                            return
                        end
                    end
                end
            end
            % Warn if a paired module is about to get loaded with non-matching firmware
            try
                BpodPath = fileparts(which('Bpod'));
                ParentDir = fileparts(BpodPath);
                SettingsDir = fullfile(ParentDir, 'Bpod Local', 'Settings');
                Data = load(fullfile(SettingsDir, 'ModuleUSBConfig.mat'));
                ModuleUSBConfig = Data.ModuleUSBConfig(1);
                for i = 1:length(ModuleUSBConfig.ModuleNames)
                    thisModuleName = ModuleUSBConfig.ModuleNames{i};
                    if ~isempty(thisModuleName)
                        thisModuleName = thisModuleName(1:end-1);
                        if strcmp(thisModuleName, 'PA')
                            thisModuleName = 'PortArray';
                        end
                        thisPortName = ModuleUSBConfig.USBPorts{i};
                        if strcmp(thisPortName, TargetPort)
                            if isempty(strfind(Filename,thisModuleName))
                                disp('****** WARNING ******')
                                disp(['The ' thisModuleName ' module is paired with ' TargetPort ' in the Bpod console.' char(10) Filename ' is not a version of ' thisModuleName '!'])
                                Reply = input('Enter ''y'' to load anyway, or any other key to exit >', 's');
                                disp(' ');
                                if Reply ~= 'y'
                                    OK = 0;
                                    msg = ['Firmware upload canceled by the user.' char(10) 'Please select a different firmware file and try again.'];
                                    return
                                end
                            end
                        end
                    end
                end
            catch
            end

            thisFolder = fileparts(which('LoadBpodFirmware'));
            switch loaderApp
                case 'bossac'
                    firmwarePath = fullfile(thisFolder, [Filename '.bin']);
                    if ispc
                        system(['@mode ' TargetPort ':1200,N,8,1']);
                        system('PING -n 3 127.0.0.1>NUL');
                        programPath = fullfile(thisFolder, ['bossac -i -d -U true -e -w -v -b "' firmwarePath '" -R']);
                    elseif isunix
                        if system('command -v bossac &> /dev/null')
                            error('Cannot find bossac. Please install bossa-cli using your system''s package management system.')
                        end
                        programPath = ['bossac -i -d -U=true -e -w -v -b "' firmwarePath '" -R'];
                    end
                case 'tycmd'
                    if ~ispc && ~ismac
                        try % Try to give the uploader execute permissions
                            [OK, Msg] = system(['chmod a+x "' fullfile(thisFolder, 'tycmd_linux64') '"']);
                            if ~isempty(Msg)
                                warning(Msg)
                            end
                        catch
                        end
                    end
                    firmwarePath = fullfile(thisFolder, [Filename '.hex']);
                    if ispc
                        [x, y] = system('taskkill /F /IM teensy.exe');
                    elseif isunix
                        [x, y] = system('killall teensy');
                    end
                    pause(.1);
                    switch portType
                        case 1
                            programPath = ['"' obj.tycmd '" upload "' firmwarePath '" --board "@' TargetPort '"'];
                        case 2
                            programPath = ['"' obj.tycmd '" upload "' firmwarePath '" --board "' TargetPort(5:end) '"'];
                    end
            end
            disp('------Uploading new firmware------')
            disp([Filename ' ==> ' TargetPort])
            [~, msg] = system(programPath);
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
        function clearObject(obj)
            delete(obj.gui.Fig);
            evalin('base', 'clear ans');
        end
    end
end