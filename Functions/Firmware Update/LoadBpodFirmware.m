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

% LoadBpodFirmware is a GUI-driven class to select and load firmware for
% Bpod state machines and modules.
%
% Example usage:
% LoadBpodFirmware;

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
                    'Please follow instructions <a href="matlab:web(''https://sanworks.github.io/Bpod_Wiki/install-and-update/'...
                    'firmware-update/#manual'',''-browser'')">here</a> to update with the Arduino application.'],computer)
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
            firmwarePath = fileparts(mfilename('fullpath'));
            
            % Define path for tycmd executable
            switch computer
                case 'PCWIN64'
                    obj.tycmd = fullfile(firmwarePath,'tycmd');
                case 'MAXI64'
                    obj.tycmd = fullfile(firmwarePath,'tycmd_osx');
                case 'GLNXA64'
                    obj.tycmd = fullfile(firmwarePath,'tycmd_linux64');
            end
            
            % Check for udev rules on linux
            if ~ismac && isunix && ~exist('/etc/udev/rules.d/00-teensy.rules','file')
                error(['Error: Cannot find teensy udev rules.' char(10) ...
                'Please follow instructions <a href="matlab:web(''https://www.pjrc.com/teensy/' ...
                'td_download.html'',''-browser'')">here</a> to install them.'])
            end
            
            % Parse firmware filenames to populate menus
            allFiles = dir(firmwarePath);
            nFirmwareFound = 0;
            firmwareNames = cell(0,1);
            obj.FirmwareVersions = cell(0,1);
            obj.LoaderApps = cell(0,1);
            for i = 3:length(allFiles)
                fileExt = allFiles(i).name(end-2:end);
                if strcmp(fileExt, 'bin') || strcmp(fileExt, 'hex')
                    fileName = allFiles(i).name(1:end-4);
                    divPos = strfind(fileName, '_'); divPos = divPos(end);
                    thisFirmwareName = fileName(1:divPos-1);
                    thisFirmwareVersion = fileName(divPos+2:end);
                    if sum(strcmp(thisFirmwareName,firmwareNames)) > 0
                        obj.FirmwareVersions{nFirmwareFound} = [obj.FirmwareVersions{nFirmwareFound} {thisFirmwareVersion}];
                        [~, Inds] = sort(str2double(obj.FirmwareVersions{nFirmwareFound}),'descend');
                        obj.FirmwareVersions{nFirmwareFound} = obj.FirmwareVersions{nFirmwareFound}(Inds);
                    else
                        nFirmwareFound = nFirmwareFound + 1;
                        firmwareNames{nFirmwareFound} = thisFirmwareName;
                        obj.FirmwareVersions{nFirmwareFound} = thisFirmwareVersion;
                        switch(fileExt)
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
                usbSerialPorts = sort(serialportlist('available'));
            elseif exist('seriallist','file')
                usbSerialPorts = sort(seriallist('available'));
            else % MATLAB pre r2017a. Fall back to system call
                if ispc
                    usbSerialPorts = cell(0,1);
                    [Status,RawString] = system('powershell.exe -inputformat none "[System.IO.Ports.SerialPort]::getportnames()"');
                    nPortsAdded = 0;
                    if ~isempty(RawString)
                        portLocations = strsplit(RawString,char(10));
                        portLocations = portLocations(1:end-1);
                        nPorts = length(portLocations);
                        for p = 1:nPorts
                            candidatePort = portLocations{p};
                            novelPort = 1;
                            if sum(strcmp(candidatePort, usbSerialPorts)) > 0
                                novelPort = 0;
                            end
                            if novelPort == 1
                                nPortsAdded = nPortsAdded + 1;
                                usbSerialPorts{nPortsAdded} = candidatePort;
                            end
                        end
                    end
                elseif ismac % Contributed by Thiago Gouvea JUN_9_2016
                    [trash, RawSerialPortList] = system('ls /dev/cu.usbmodem*');
                    string = strtrim(RawSerialPortList);
                    portStringPositions = strfind(string, '/dev/cu.usbmodem');
                    stringEnds = find(string == 9);
                    nPorts = length(portStringPositions);
                    candidatePorts = cell(1,nPorts);
                    nGoodPorts = 0;
                    for x = 1:nPorts
                        if x < nPorts && nPorts > 1
                            candidatePort = string(portStringPositions(x):stringEnds(x)-1);
                        elseif x == nPorts
                            candidatePort = string(portStringPositions(x):end);
                        end
                        nGoodPorts = nGoodPorts + 1;
                        candidatePorts{nGoodPorts} = candidatePort;
                    end
                    usbSerialPorts = candidatePorts(1:nGoodPorts);
                else
                    [trash, RawSerialPortList] = system('ls /dev/ttyACM*');
                    string = strtrim(RawSerialPortList);
                    portStringPositions = strfind(string, '/dev/ttyACM');
                    nPorts = length(portStringPositions);
                    candidatePorts = cell(1,nPorts);
                    nGoodPorts = 0;
                    for x = 1:nPorts
                        if portStringPositions(x)+11 <= length(string)
                            candidatePort = strtrim(string(portStringPositions(x):portStringPositions(x)+11));
                            nGoodPorts = nGoodPorts + 1;
                            candidatePorts{nGoodPorts} = candidatePort;
                        end
                    end
                    usbSerialPorts = candidatePorts(1:nGoodPorts);
                end
            end
            obj.PortType(1:length(usbSerialPorts)) = 1;
            
            % Identify state machine accessory ports (to exclude from list)
            global BpodSystem % Import the global BpodSystem object
            excludedPorts = {};
            if isempty(BpodSystem) || ~isvalid(BpodSystem)
                clear global BpodSystem
            else
                analogPort = [];
                fsmPort = [];
                if ~isempty(BpodSystem.AnalogSerialPort)
                    analogPort = BpodSystem.AnalogSerialPort.PortName;
                end
                if excludeFSM
                    fsmPort = BpodSystem.SerialPort.PortName;
                end
                excludedPorts = [{'COM1','COM2'} analogPort ...
                    fsmPort BpodSystem.HW.AppSerialPortName];
            end
            usbSerialPorts = setdiff(usbSerialPorts, excludedPorts);
            
            % Get Teensy RawHID boards
            [~, Tstring] = system(['"' obj.tycmd '" list']);
            allRawHIDs = cell(0);
            if ~isempty(Tstring)
                hardReturns = find(Tstring == 10);
                pos = 1;
                found = 0;
                if ~isempty(hardReturns)
                    for i = 1:length(hardReturns)-1
                        segment = Tstring(pos:hardReturns(i));
                        if ~isempty(strfind(segment, 'Teensyduino RawHID')) || ~isempty(strfind(segment, 'HalfKay'))
                            found = found + 1;
                            allRawHIDs{found} = ['SER#' segment(strfind(segment, 'add ') + 4:strfind(segment, '-Teensy')-1)];
                        end
                        pos = pos + length(segment);
                    end
                    segment = Tstring(pos:end);
                    if ~isempty(strfind(segment, 'Teensyduino RawHID')) || ~isempty(strfind(segment, 'HalfKay'))
                        found = found + 1;
                        allRawHIDs{found} = ['SER#' segment(strfind(segment, 'add ') + 4:strfind(segment, '-Teensy')-1)];
                    end
                end
            end
            obj.PortType = [obj.PortType ones(1,length(allRawHIDs))*2];
            
            % Combine lists of USB serial ports & RawHID devices
            allPorts = [usbSerialPorts allRawHIDs];
            if isempty(allPorts)
                error('Error: No USB serial devices were detected.');
            end
            labelOffset = 0;
            dropMenuFontSize = 10;
            labelFontSize = 16;
            if ispc
                labelOffset = -2;
                dropMenuFontSize = 12;
                labelFontSize = 18;
            end
            % Set up GUI
            bpodPath = which('Bpod');
            bgPath = fullfile(bpodPath(1:end-6), 'Assets', 'Bitmap', 'FirmwareBG.bmp');
            bg = imread(bgPath);
            obj.gui.Fig  = figure('name','Bpod Firmware Loading Tool', 'position',[100,100,855,200],...
                'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off',...
                'Color',[0.1 0.1 0.1],'CloseRequestFcn',@(h,e)obj.clear_obj());
            bgAxes = axes('units','normalized', 'position',[0 0 1 1]);
            uistack(bgAxes,'bottom');
            image(bg); axis off;
            uicontrol('Style', 'text', 'Position', [18+labelOffset 150 120 30], 'String', 'Firmware', 'FontSize', labelFontSize,...
                'FontWeight', 'bold', 'BackgroundColor', [0.05 0.1 0.05], 'ForegroundColor', [0.1 1 0.1]);
            obj.gui.Devices = uicontrol('Style', 'popup', 'Position', [25 80 320 30], 'String', firmwareNames, 'FontSize', dropMenuFontSize,...
                'FontWeight', 'bold','Callback', @(h,e)obj.update_versions(), 'BackgroundColor', [0.05 0.1 0.05],... 
                'ForegroundColor', [0.1 1 0.1]);
            uicontrol('Style', 'text', 'Position', [375+labelOffset 150 105 30], 'String', 'Version', 'FontSize', labelFontSize,...
                'FontWeight', 'bold', 'BackgroundColor', [0.05 0.1 0.05], 'ForegroundColor', [0.1 1 0.1]);
            obj.gui.Versions = uicontrol('Style', 'popup', 'Position', [385 80 80 30], 'String', obj.FirmwareVersions{1},... 
                'FontSize', dropMenuFontSize,'FontWeight', 'bold', 'BackgroundColor', [0.05 0.1 0.05], 'ForegroundColor', [0.1 1 0.1]);
            uicontrol('Style', 'text', 'Position', [490 150 65 30], 'String', 'Port', 'FontSize', labelFontSize,...
                'FontWeight', 'bold', 'BackgroundColor', [0.05 0.1 0.05], 'ForegroundColor', [0.1 1 0.1]);
            obj.gui.Ports = uicontrol('Style', 'popup', 'Position', [500 80 180 30], 'String', allPorts, 'FontSize', dropMenuFontSize,...
                'FontWeight', 'bold', 'BackgroundColor', [0.05 0.1 0.05], 'ForegroundColor', [0.1 1 0.1]);
            obj.gui.smButton = uicontrol('Style', 'pushbutton', 'Position', [730 75 100 50], 'String', 'Load', 'FontSize', 14,...
                'FontWeight', 'bold', 'Enable', 'on','Callback', @(h,e)obj.update_firmware(), 'BackgroundColor', [0.05 0.1 0.05],... 
                'ForegroundColor', [0.1 1 0.1]);
            % Filter list if a filter arg was provided
            if ~isempty(set2Device)
                if strcmp(set2Device, 'PA') % Special handling of port array module for backwards compatability
                    set2Device = 'PortArray';
                end

                % If a hardware version was provided, extract firmware name and HW version
                deviceName = set2Device;
                hwVersionPos = find(set2Device == '&');
                if ~isempty(hwVersionPos)
                    deviceName = set2Device(1:hwVersionPos-1);
                    hwVersion = set2Device(hwVersionPos+1:end);
                    posHW = strfind(firmwareNames,hwVersion);
                    posHW = find(~cellfun(@isempty,posHW));
                end
                pos = strfind(firmwareNames,deviceName);
                pos = find(~cellfun(@isempty,pos));
                if ~isempty(hwVersionPos)
                    pos = intersect(pos, posHW);
                end
                posExact = find(strcmp(firmwareNames, deviceName));

                % Make the exact match rank first
                if ~isempty(posExact)
                    pos = [posExact pos(pos ~= posExact)];
                end
                if ~isempty(pos)
                    set(obj.gui.Devices, 'Value', 1);
                    set(obj.gui.Devices, 'String', firmwareNames(pos));
                    obj.LoaderApps = obj.LoaderApps(pos);
                    obj.FirmwareVersions = obj.FirmwareVersions(pos);
                    obj.update_versions();
                end
            end
            % Set the port if a port arg was provided
            if ~isempty(set2Port)
                posExact = find(strcmp(allPorts, set2Port));
                if ~isempty(posExact)
                    set(obj.gui.Ports, 'Value', posExact);
                end
            end
        end
        
        function update_versions(obj, varargin)
            firmwareIndex = get(obj.gui.Devices, 'Value');
            set(obj.gui.Versions, 'Value', 1);
            set(obj.gui.Versions, 'String', obj.FirmwareVersions{firmwareIndex});
        end
        
        function update_firmware(obj, varargin)
            moduleNamePos = get(obj.gui.Devices, 'Value');
            moduleNameList = get(obj.gui.Devices, 'String');
            moduleName = moduleNameList{moduleNamePos};
            versionPos = get(obj.gui.Versions, 'Value');
            versionList = get(obj.gui.Versions, 'String');
            if ~iscell(versionList)
                versionList = {versionList};
            end
            version = versionList{versionPos};
            portNamePos = get(obj.gui.Ports, 'Value');
            portNameString = get(obj.gui.Ports, 'String');
            if ~iscell(portNameString)
                portNameString = {portNameString};
            end
            portName = portNameString{portNamePos};
            fileName = [moduleName '_v' version];
            progressbar(0.02); pause(.1);
            progressbar(0.6);
            if strcmp(moduleName, 'StateMachine_Bpod1') || strcmp(moduleName, 'StateMachine_Bpod05')
                disp('*Note* Firmware upload may take up to 3 minutes and the program may appear to be non-responsive.')
            end
            [OK,msg] = obj.upload_firmware(portName, fileName, obj.LoaderApps{moduleNamePos}, obj.PortType(portNamePos));
            pause(1);
            progressbar(0.9);
            pause(1); % Time for HiFi module to finish booting
            progressbar(1);
            fontSize = 14;
            if isunix
                fontSize = 12;
            end
            if OK
                bgColor = [0.1 0.9 0.1];
                msg1 = '*GREAT SUCCESS*';
                msg2 = 'Firmware update complete';
                global BpodSystem;
                if isempty(BpodSystem)
                    clear global BpodSystem
                else
                    BpodSystem.LoadModules;
                end
            else
                bgColor = [1 0.4 0.4];
                msg1 = '*FAILED*';
                msg2 = 'See command window';
                disp('Console output:')
                disp(msg)
            end
            obj.gui.ConfirmModal  = figure('name','Firmware Update', 'position',[335,120,280,200],...
                'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off',...
                'Color',bgColor);
            
            obj.gui.Msg1 = uicontrol('Style', 'text', 'Position', [25 140 220 30], 'String', msg1, 'FontSize', fontSize,...
                'FontWeight', 'bold', 'BackgroundColor', bgColor);
            obj.gui.Msg2 = uicontrol('Style', 'text', 'Position', [15 90 250 30], 'String', msg2, 'FontSize', fontSize,...
                'FontWeight', 'bold', 'BackgroundColor', bgColor);
            uicontrol('Style', 'pushbutton', 'Position', [90 20 100 40], 'String', 'Ok', 'FontSize', 14,...
                'FontWeight', 'bold', 'BackgroundColor', [0.05 0.1 0.05], 'ForegroundColor', [0.1 1 0.1], 'Callback',... 
                @(h,e)obj.close_modal());
            if OK
                bgColor(2) = 0.1;
                try
                    for i = 1:100
                        bgColor(2) = bgColor(2) + (0.8/100);
                        set(obj.gui.ConfirmModal, 'Color', bgColor);
                        set(obj.gui.Msg1, 'BackgroundColor', bgColor);
                        set(obj.gui.Msg2, 'BackgroundColor', bgColor);
                        pause(.005);
                        drawnow;
                    end
                    bgColor = [0.1 0.9 0.1];
                    set(obj.gui.ConfirmModal, 'Color', bgColor);
                    set(obj.gui.Msg1, 'BackgroundColor', bgColor);
                    set(obj.gui.Msg2, 'BackgroundColor', bgColor);
                catch
                end

            end
            
        end
        
        function close_modal(obj)
            delete(obj.gui.ConfirmModal);
            delete(obj.gui.Fig);
            evalin('base', 'clear ans');
        end

        function [ok,msg] = upload_firmware(obj, targetPort, filename, loaderApp, portType)
            % Warn if non-FSM firmware is about to get loaded to an FSM
            if portType == 1
                isFSMFirmware = ~isempty(strfind(filename, 'StateMachine'));
                if ~isFSMFirmware
                    tempPort = ArCOMObject_Bpod(targetPort);
                    pause(.3);
                    portIsKnownFSM = 0;
                    if tempPort.bytesAvailable > 0
                        msg = tempPort.read(1, 'uint8');
                        if msg == 222
                            portIsKnownFSM = 1;
                        end
                    end
                    clear tempPort
                    if portIsKnownFSM
                        disp('****** WARNING ******')
                        disp(['State Machine detected on Port ' targetPort '.' char(10) filename ' is not state machine firmware!'])
                        reply = input('Enter ''y'' to load anyway, or any other key to exit >', 's');
                        disp(' ');
                        if reply ~= 'y'
                            ok = 0;
                            msg = ['Firmware upload canceled by the user.' char(10) ... 
                                'Please select state machine firmware and try again.'];
                            return
                        end
                    end
                end
            end
            % Warn if a paired module is about to get loaded with non-matching firmware
            try
                bpodPath = fileparts(which('Bpod'));
                parentDir = fileparts(bpodPath);
                settingsDir = fullfile(parentDir, 'Bpod Local', 'Settings');
                data = load(fullfile(settingsDir, 'ModuleUSBConfig.mat'));
                moduleUSBConfig = data.ModuleUSBConfig(1);
                for i = 1:length(moduleUSBConfig.ModuleNames)
                    thisModuleName = moduleUSBConfig.ModuleNames{i};
                    if ~isempty(thisModuleName)
                        thisModuleName = thisModuleName(1:end-1);
                        if strcmp(thisModuleName, 'PA')
                            thisModuleName = 'PortArray';
                        end
                        thisPortName = moduleUSBConfig.USBPorts{i};
                        if strcmp(thisPortName, targetPort)
                            if isempty(strfind(filename,thisModuleName))
                                disp('****** WARNING ******')
                                disp(['The ' thisModuleName ' module is paired with ' targetPort ' in the Bpod console.' ... 
                                    char(10) filename ' is not a version of ' thisModuleName '!'])
                                reply = input('Enter ''y'' to load anyway, or any other key to exit >', 's');
                                disp(' ');
                                if reply ~= 'y'
                                    ok = 0;
                                    msg = ['Firmware upload canceled by the user.' char(10) ... 
                                        'Please select a different firmware file and try again.'];
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
                    firmwarePath = fullfile(thisFolder, [filename '.bin']);
                    if ispc
                        system(['@mode ' targetPort ':1200,N,8,1']);
                        system('PING -n 3 127.0.0.1>NUL');
                        bossacPath = fullfile(thisFolder, 'bossac.exe');
                        programPath = ['"' bossacPath '"' ' -i -d -U true -e -w -v -b "' firmwarePath '" -R'];
                    elseif isunix
                        if system('command -v bossac &> /dev/null')
                            error('Cannot find bossac. Please install bossa-cli using your system''s package management system.')
                        end
                        programPath = ['bossac -i -d -U=true -e -w -v -b "' firmwarePath '" -R'];
                    end
                case 'tycmd'
                    if ~ispc && ~ismac
                        try % Try to give the uploader execute permissions
                            [ok, msg] = system(['chmod a+x "' fullfile(thisFolder, 'tycmd_linux64') '"']);
                            if ~isempty(msg)
                                warning(msg)
                            end
                        catch
                        end
                    end
                    firmwarePath = fullfile(thisFolder, [filename '.hex']);
                    if ispc
                        [x, y] = system('taskkill /F /IM teensy.exe');
                    elseif isunix
                        [x, y] = system('killall teensy');
                    end
                    pause(.1);
                    switch portType
                        case 1
                            programPath = ['"' obj.tycmd '" upload "' firmwarePath '" --board "@' targetPort '"'];
                        case 2
                            programPath = ['"' obj.tycmd '" upload "' firmwarePath '" --board "' targetPort(5:end) '"'];
                    end
            end
            disp('------Uploading new firmware------')
            disp([filename ' ==> ' targetPort])
            [~, msg] = system(programPath);
            ok = 0;
            if ~isempty(strfind(msg, 'Sending reset command')) || ~isempty(strfind(msg, 'Verify successful'))
                ok = 1;
            end
            if ok
                disp('----------UPDATE COMPLETE---------')
            else
                disp('----------FAILED TO LOAD----------')
            end
            disp(' ');
        end

        function clear_obj(obj)
            delete(obj.gui.Fig);
            evalin('base', 'clear ans');
        end
    end
end