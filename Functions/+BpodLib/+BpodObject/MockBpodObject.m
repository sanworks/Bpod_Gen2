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

        p = inputParser();
        p.addRequired('comport')
        p.addParameter('verbose', false, @islogical);
        p.parse(varargin{:});
        isEmulator = strcmp(p.Results.comport, 'EMU');

        % Constructor to initialize the mock Bpod object
        if isEmulator
            obj.SerialPort = [];
        else
            obj.SerialPort.PortName = p.Results.comport;
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