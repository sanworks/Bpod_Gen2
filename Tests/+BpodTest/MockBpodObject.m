% Mock BpodObject for use in unit testing

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

classdef MockBpodObject < handle
properties
    SerialPort
    Modules
    Status
    Path
    Data
    GUIHandles
    EmulatorMode

    % Settings loaded at startup
    CalibrationTables
    InputsEnabled
    SyncConfig
    SystemSettings
end
methods
    function obj = MockBpodObject(varargin)
        % obj = MockBpodObject(_)
        p = inputParser();
        p.addRequired('comport')
        p.addParameter('verbose', false, @islogical);
        p.parse(varargin{:});
        isEmulator = strcmp(p.Results.comport, 'EMU');

        % Constructor to initialize the mock Bpod object
        if isEmulator
            obj.SerialPort = [];
        else
            obj.SerialPort.PortName = BpodTest.nativePort(p.Results.comport, 'idformat', false);
        end
        obj.Modules = struct();
        obj.Status = struct();
        obj.Status.Verbose = p.Results.verbose;
        obj.Path = struct();
        obj.Data = struct();
        obj.GUIHandles = struct();
        obj.EmulatorMode = isEmulator;
    end

    function setupSettings(obj, varargin)
        p = inputParser();
        BpodLib.BpodObject.setup.updatePathAndSettings(obj, 'verbose', p.Results.verbose);
    end
end
end