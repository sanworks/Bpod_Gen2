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
function obj = LoadModules(obj)
    defaultBaudRate = 1312500;
    if obj.EmulatorMode == 0 && obj.Status.BeingUsed == 0
        nModules = sum(obj.HW.Outputs=='U');
        if isfield(obj.Modules, 'USBport')
            USBPairing = obj.Modules.USBport;
        else
            USBPairing = cell(1,nModules);
        end
        % Get info from modules
        obj.Modules.nModules = nModules;
        obj.Modules.RelayActive = zeros(1,nModules);
        obj.StopModuleRelay();
        obj.Modules.Connected = zeros(1,nModules);
        obj.Modules.Name = cell(1,nModules);
        obj.Modules.Module2SM_BaudRate = ones(1,nModules)*defaultBaudRate;
        obj.Modules.FirmwareVersion = zeros(1,nModules);
        obj.Modules.nSerialEvents = ones(1,nModules)*(floor(obj.HW.n.MaxSerialEvents/obj.HW.n.SerialChannels));
        obj.Modules.EventNames = cell(1,nModules);
        obj.Modules.USBport = USBPairing;
        obj.SerialPort.write('M', 'uint8');
        if obj.SerialPort.Interface == 3 || obj.SerialPort.Interface == 4
            pause(1);
        else
            pause(0.3);
        end
        messageLength = obj.SerialPort.bytesAvailable;
        moduleEventsRequested = zeros(1,obj.HW.n.UartSerialChannels);
        if messageLength > 1
            for i = 1:nModules
                obj.Modules.Connected(i) = obj.SerialPort.read(1, 'uint8');
                if obj.Modules.Connected(i) == 1
                    obj.Modules.FirmwareVersion(i) = obj.SerialPort.read(1, 'uint32');
                    nBytes = obj.SerialPort.read(1, 'uint8');
                    NameString = obj.SerialPort.read(nBytes, 'char');
                    SameModuleCount = 0;
                    for j = 1:nModules
                        if strcmp(obj.Modules.Name{j}(1:end-1), NameString)
                            SameModuleCount = SameModuleCount + 1;
                        end
                    end
                    obj.Modules.Name{i} = [NameString num2str(SameModuleCount+1)];
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
                            end
                            moreInfoFollows = obj.SerialPort.read(1, 'uint8');
                        end
                    end
                end
            end
            nEventsRequested = sum(moduleEventsRequested)+obj.HW.n.SoftCodes;
            if nEventsRequested > obj.HW.n.MaxSerialEvents
                error(['Error: modules requested more serial events ' num2str(nEventsRequested) ' than the current state machine can support ' num2str(obj.HW.n.MaxSerialEvents) '. Please reconfigure modules.'])
            end
            for i = 1:nModules
                if obj.Modules.Connected(i) == 1
                    if moduleEventsRequested(i) > obj.Modules.nSerialEvents(i)
                        nToReassign = moduleEventsRequested(i) - obj.Modules.nSerialEvents(i);
                        obj.Modules.nSerialEvents(i) = moduleEventsRequested(i); % Assign events
                    else
                        nToReassign = 0;
                    end
                    Pos = nModules;
                    while nToReassign > 0
                        if obj.Modules.nSerialEvents(Pos) > 0 && obj.Modules.Connected(Pos) == 0
                            if obj.Modules.nSerialEvents(Pos) >= nToReassign
                                obj.Modules.nSerialEvents(Pos) = obj.Modules.nSerialEvents(Pos) - nToReassign;
                                nToReassign = 0;
                            else
                                nToReassign = nToReassign - obj.Modules.nSerialEvents(Pos);
                                obj.Modules.nSerialEvents(Pos) = 0;
                            end
                        end
                        Pos = Pos - 1;
                        if Pos == 0
                            error(['Error: modules requested more serial events ' num2str(nEventsRequested) ' than the current state machine can support ' num2str(obj.HW.n.MaxSerialEvents) '. Please reconfigure modules.'])
                        end
                    end
                end
            end
            obj.HW.n.SoftCodes = obj.HW.n.MaxSerialEvents-sum(obj.Modules.nSerialEvents);
            obj.SerialPort.write(['%' obj.Modules.nSerialEvents obj.HW.n.SoftCodes], 'uint8');
            Confirmed = obj.SerialPort.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error: State machine did not confirm module event reallocation');
            end

            % Load module USB port configuration
            USBPorts = obj.FindUSBSerialPorts;
            USBPorts = [USBPorts.Arduino USBPorts.Teensy USBPorts.Sparkfun USBPorts.COM];
            USBPorts = USBPorts(logical(1-strcmp(USBPorts, obj.SerialPort.PortName)));

            for i = 1:length(obj.Modules.Name)
                USBPorts = USBPorts(logical(1-strcmp(USBPorts, obj.Modules.USBport{i})));
            end
            load(obj.Path.ModuleUSBConfig);
            for i = 1:obj.Modules.nModules
                ThisModuleName = obj.Modules.Name{i};
                ThisPortName = ModuleUSBConfig.USBPorts{i};
                ExpectedModuleName = ModuleUSBConfig.ModuleNames{i};
                if ~isempty(ThisModuleName) && ~isempty(ThisPortName) % If an entry exists
                    if sum(strcmp(ThisPortName, USBPorts)) > 0 % If the USB port is detected
                        if isempty(obj.Modules.USBport{i}) % If the module is unpaired
                            if strcmp(ThisModuleName, ExpectedModuleName)
                                obj.Modules.USBport{i} = ThisPortName;
                                obj.ModuleUSB.(ThisModuleName) = ThisPortName;
                            end
                        end
                    end
                end
            end
        else
            error('Error requesting module information: state machine did not return enough data.')
        end
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
        for i = 1:nModules % Check for incompatible module firmware
            thisModuleName = obj.Modules.Name{i}(1:end-1);
            thisModuleFirmware = obj.Modules.FirmwareVersion(i);
            if ~isempty(thisModuleName)
                if isfield(obj.CurrentFirmware, thisModuleName)
                    expectedFirmwareVersion = obj.CurrentFirmware.(thisModuleName);
                    if thisModuleFirmware < expectedFirmwareVersion
                        disp([char(13) 'WARNING: ' thisModuleName ' module with old firmware detected, v' num2str(thisModuleFirmware) '. ' char(13)...
                            'Please update its firmware to v' num2str(expectedFirmwareVersion) ', restart Bpod and try again.' char(13)...
                            'While Bpod is still open, click <a href="matlab:UpdateBpodFirmware;">here</a> to start the update tool, UpdateBpodFirmware().' char(13)...
                            'If necessary, manual firmware update instructions are <a href="matlab:web(''https://sites.google.com/site/bpoddocumentation/firmware-update'',''-browser'')">here</a>.' char(13)]);
                        oldFirmwareFound = 1;
                    elseif thisModuleFirmware > expectedFirmwareVersion
                        Errormsg = ['WARNING: The firmware on the ' thisModuleName ' module on port ' num2str(i) ' is newer than your Bpod software for MATLAB. ' char(13) 'Please update your MATLAB software from the Bpod repository and try again.'];
                        warndlg(Errormsg)
                        disp(Errormsg);
                    end
                end
            end
        end
        if oldFirmwareFound == 1
            BpodErrorSound;
            warndlg('WARNING: Old module firmware detected. See instructions in the MATLAB command window.');
        end
    elseif obj.Status.BeingUsed == 1
         BpodErrorDlg(['Cannot refresh modules.' char(10) 'Stop the session first.'], 0);
    end
end