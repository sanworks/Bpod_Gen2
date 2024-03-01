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

% BpodObject.LoadModules() requests updated information from the state machine about any
% connected Bpod modules. The UI tabs and valid event + channel info is updated accordingly.

function obj = LoadModules(obj)

% Determine baud rate of state machine <---> module connection
defaultBaudRate = 1312500;
if obj.MachineType < 2
    defaultBaudRate = 115200;
end

% Ensure that no session is running
if obj.Status.BeingUsed == 1
    BpodErrorDlg(['Cannot refresh modules.' char(10) 'Stop the session first.'], 0); %#ok
end

% If emulator mode, return (no hardware is connected)
if obj.EmulatorMode == 1
    return
end

% Store the USB Pairing info
nModules = sum(obj.HW.Outputs=='U');
if isfield(obj.Modules, 'USBport')
    usbPairing = obj.Modules.USBport;
else
    usbPairing = cell(1,nModules);
end

% Set module info to defaults
obj.Modules.nModules = nModules;
obj.Modules.RelayActive = zeros(1,nModules);
obj.StopModuleRelay();
obj.Modules.Connected = zeros(1,nModules);
obj.Modules.Name = cell(1,nModules);
obj.Modules.Module2SM_BaudRate = ones(1,nModules)*defaultBaudRate;
obj.Modules.FirmwareVersion = zeros(1,nModules);
obj.Modules.nSerialEvents = ones(1,nModules)*(floor(obj.HW.n.MaxSerialEvents/obj.HW.n.SerialChannels));
obj.Modules.EventNames = cell(1,nModules);
obj.Modules.USBport = usbPairing;
obj.Modules.HWVersion_Major = nan(1,nModules);
obj.Modules.HWVersion_Minor = nan(1,nModules);

% Send the 'M' command to request module information
obj.SerialPort.write('M', 'uint8');

% Wait for the state machine to poll the modules for info
if obj.SerialPort.Interface == 3 || obj.SerialPort.Interface == 4
    pause(1);
else
    pause(0.3);
end

% Read and parse the module description message
messageLength = obj.SerialPort.bytesAvailable;
moduleEventsRequested = zeros(1,obj.HW.n.UartSerialChannels);
if messageLength > 1
    for i = 1:nModules % For each module, read and parse module info
        obj.Modules.Connected(i) = obj.SerialPort.read(1, 'uint8');
        if obj.Modules.Connected(i) == 1
            obj.Modules.FirmwareVersion(i) = obj.SerialPort.read(1, 'uint32');
            nBytes = obj.SerialPort.read(1, 'uint8');
            nameString = obj.SerialPort.read(nBytes, 'char');
            sameModuleCount = 0;
            for j = 1:nModules
                if strcmp(obj.Modules.Name{j}(1:end-1), nameString)
                    sameModuleCount = sameModuleCount + 1;
                end
            end
            obj.Modules.Name{i} = [nameString num2str(sameModuleCount+1)];
            moreInfoFollows = obj.SerialPort.read(1, 'uint8');
            if moreInfoFollows
                while moreInfoFollows
                    paramType = obj.SerialPort.read(1, 'uint8');
                    switch paramType
                        case '#' % Number of events requested by module
                            moduleEventsRequested(i) = obj.SerialPort.read(1, 'uint8');
                        case 'E' % Strings to replace default event names (e.g. ModuleName1_1)
                            nStrings = obj.SerialPort.read(1, 'uint8');
                            obj.Modules.EventNames{i} = cell(1,nStrings);
                            for j = 1:nStrings
                                nCharInThisString = obj.SerialPort.read(1, 'uint8');
                                obj.Modules.EventNames{i}{j} = obj.SerialPort.read(nCharInThisString, 'char');
                            end
                        case 'V' % Major hardware version
                            obj.Modules.HWVersion_Major(i) = obj.SerialPort.read(1, 'uint8');
                        case 'v' % Minor hardware version (circuit revision)
                            obj.Modules.HWVersion_Minor(i) = obj.SerialPort.read(1, 'uint8');
                    end
                    moreInfoFollows = obj.SerialPort.read(1, 'uint8');
                end
            end
        end
    end

    % Compute and validate the number of behavior events requested by the module
    nEventsRequested = sum(moduleEventsRequested)+obj.HW.n.SoftCodes;
    if nEventsRequested > obj.HW.n.MaxSerialEvents
        error(['Error: modules requested more serial events ' num2str(nEventsRequested)...
            ' than the current state machine can support ' num2str(obj.HW.n.MaxSerialEvents)...
            '. Please reconfigure modules.'])
    end

    % Reassign module events to accomodate all requests
    for i = 1:nModules
        if obj.Modules.Connected(i) == 1
            if moduleEventsRequested(i) > obj.Modules.nSerialEvents(i)
                nToReassign = moduleEventsRequested(i) - obj.Modules.nSerialEvents(i);
                obj.Modules.nSerialEvents(i) = moduleEventsRequested(i); % Assign events
            else
                nToReassign = 0;
            end
            pos = nModules;
            while nToReassign > 0
                if obj.Modules.nSerialEvents(pos) > 0 && obj.Modules.Connected(pos) == 0
                    if obj.Modules.nSerialEvents(pos) >= nToReassign
                        obj.Modules.nSerialEvents(pos) = obj.Modules.nSerialEvents(pos) - nToReassign;
                        nToReassign = 0;
                    else
                        nToReassign = nToReassign - obj.Modules.nSerialEvents(pos);
                        obj.Modules.nSerialEvents(pos) = 0;
                    end
                end
                pos = pos - 1;
                if pos == 0
                    error(['Error: modules requested more serial events ' num2str(nEventsRequested)...
                        ' than the current state machine can support ' num2str(obj.HW.n.MaxSerialEvents)...
                        '. Please reconfigure modules.'])
                end
            end
        end
    end

    % Determine number of Bpod soft codes and App soft codes
    obj.HW.n.SoftCodes = obj.HW.n.MaxSerialEvents-sum(obj.Modules.nSerialEvents);
    nSoftCodes = obj.HW.n.SoftCodes/(obj.HW.n.USBChannels+obj.HW.n.USBChannels_External);
    nAppSoftCodes = obj.HW.n.USBChannels_External*nSoftCodes;
    if nAppSoftCodes == 0
        nAppSoftCodes = [];
    end

    % Update the state machine with new event allocation
    obj.SerialPort.write(['%' obj.Modules.nSerialEvents nSoftCodes nAppSoftCodes], 'uint8');
    confirmed = obj.SerialPort.read(1, 'uint8');
    if confirmed ~= 1
        error('Error: State machine did not confirm module event reallocation');
    end

    % Load module USB port pairing configuration
    usbPorts = obj.FindUSBSerialPorts;
    usbPorts = usbPorts(logical(1-strcmp(usbPorts, obj.SerialPort.PortName)));
    for i = 1:length(obj.Modules.Name)
        usbPorts = usbPorts(logical(1-strcmp(usbPorts, obj.Modules.USBport{i})));
    end
    load(obj.Path.ModuleUSBConfig);
    for i = 1:obj.Modules.nModules
        thisModuleName = obj.Modules.Name{i};
        thisPortName = ModuleUSBConfig.USBPorts{i};
        expectedModuleName = ModuleUSBConfig.ModuleNames{i};
        if ~isempty(thisModuleName) && ~isempty(thisPortName) % If an entry exists
            if sum(strcmp(thisPortName, usbPorts)) > 0 % If the USB port is detected
                if isempty(obj.Modules.USBport{i}) % If the module is unpaired
                    if strcmp(thisModuleName, expectedModuleName)
                        obj.Modules.USBport{i} = thisPortName;
                        obj.ModuleUSB.(thisModuleName) = thisPortName;
                    end
                end
            end
        end
    end
else
    error('Error requesting module information: state machine did not return enough data.')
end

% Update Bpod console UI tabs
if isfield(obj.GUIHandles, 'MainFig') % GUI was already loaded. Update tabs and panels.
    obj.SetupStateMachine;
    obj.refreshGUIPanels;
    obj.FixPushbuttons;
    if isfield(obj.GUIHandles, 'SystemInfoFig')
        if ishandle(obj.GUIHandles.SystemInfoFig) % If info figure is open
            close(obj.GUIHandles.SystemInfoFig);
            BpodSystemInfo;
            figure(obj.GUIHandles.MainFig);
        end
    end
end
oldFirmwareFound = 0;

% Check for old module firmware
for i = 1:nModules
    thisModuleName = obj.Modules.Name{i}(1:end-1);
    thisModuleFirmware = obj.Modules.FirmwareVersion(i);
    if ~isempty(thisModuleName)
        if isfield(obj.CurrentFirmware, thisModuleName)
            expectedFirmwareVersion = obj.CurrentFirmware.(thisModuleName);
            if thisModuleFirmware < expectedFirmwareVersion
                autoUpdatable = 1;
                if strcmp(thisModuleName, 'ValveModule')
                    thisModuleName = 'ValveDriverModule';
                    if isnan(obj.Modules.HWVersion_Major(i))
                        obj.Modules.HWVersion_Major(i) = 1;
                        autoUpdatable = 0;
                    end
                end
                if strcmp(thisModuleName, 'I2C')
                    autoUpdatable = 0;
                end
                moduleNameMotif = thisModuleName;
                if obj.Modules.HWVersion_Major(i) > 1
                    moduleNameMotif = [moduleNameMotif '&HW' num2str(obj.Modules.HWVersion_Major(i))];
                end
                if strcmp(thisModuleName, 'HiFi')
                    try % Try to determine if HD or SD model
                        A = ArCOMObject_Bpod(obj.Modules.USBport{i});
                        A.write('I', 'uint8');
                        isHD = A.read(1, 'uint8');
                        A.flush;
                        pause(.001);
                        clear A
                        versionName = 'SD';
                        if isHD
                            versionName = 'HD';
                        end
                        moduleNameMotif = [moduleNameMotif '&' versionName];
                    end
                end
                usbPreSelection = [];
                if ~isempty(obj.Modules.USBport{i})
                    usbPreSelection = [',' ' ' '''' obj.Modules.USBport{i} ''''];
                end
                disp([char(13) 'WARNING: ' thisModuleName ' module with old firmware detected, v'...
                    num2str(thisModuleFirmware) '. ' char(13)...
                    'Please update its firmware to v' num2str(expectedFirmwareVersion) ', restart Bpod and try again.']);
                if autoUpdatable
                    disp(['1. From the Bpod console, pair the ' thisModuleName ' module with its USB port.' char(13)...
                        '2. While Bpod is still open, click <a href="matlab:LoadBpodFirmware(''' moduleNameMotif, ...
                        ''', 1' usbPreSelection ');">here</a> to start the update tool, LoadBpodFirmware().' char(13)...
                        '3. Select the correct firmware and USB port.' char(13)...
                        '   NOTE: If updating the analog output module, use the correct version (4ch or 8ch).' char(13) ...
                        'If necessary, manual firmware update instructions are '...
                        '<a href="matlab:web(''https://sanworks.github.io/Bpod_Wiki/install-and-update/firmware-update/#manual'',''-browser'')">here</a>.'...
                        char(13)]);
                else
                    disp(['Firmware update instructions are' ...
                        '<a href="matlab:web(''https://sanworks.github.io/Bpod_Wiki/install-and-update/firmware-update/#manual'',''-browser'')">here</a>.'...
                        char(13)]);
                    disp(['IMPORTANT NOTE: Modules based on the red SAMD21 Mini board' char(13)...
                        '(Original Valve Driver, I2C and SNES)' char(13) 'should NOT be updated with the LoadBpodFirmware tool.'])
                end
                oldFirmwareFound = 1;
            elseif thisModuleFirmware > expectedFirmwareVersion
                errormsg = ['WARNING: The firmware on the ' thisModuleName ' module on port ' num2str(i)...
                    ' is newer than your Bpod software for MATLAB. ' char(13)...
                    'Please update your MATLAB software from the Bpod repository and try again.'];
                warndlg(errormsg)
                disp(errormsg);
            end
        end
    end
end

% Issue firmware warning if old firwmare found
if oldFirmwareFound == 1
    BpodErrorSound;
    warndlg('WARNING: Old module firmware detected. See instructions in the MATLAB command window.');
end

% Update HW revision information
smRevision = obj.HW.CircuitRevision.StateMachine;
obj.HW.CircuitRevision = struct;
obj.HW.CircuitRevision.StateMachine = smRevision;
for i = 1:nModules
    if obj.Modules.Connected(i)
        thisModuleName = obj.Modules.Name{i};
        obj.HW.CircuitRevision.(thisModuleName) = obj.Modules.HWVersion_Minor(i);
    end
end

end