classdef PendingMeasurementManager < handle
properties
    ValveManager
    data
end

methods
    function obj = PendingMeasurementManager(ValveManager)
        obj.ValveManager = ValveManager;

        % Initialize the data structure with empty arrays for each valve
        valveNames = ValveManager.getValveNames();
        obj.data = struct();
        for idx = 1:numel(valveNames)
            valvename = valveNames{idx};
            obj.data.(valvename) = [];
        end
    end

    function addPending(obj, valvename, duration_ms)
        % Add a pending measurement for a valve
        assert(ismember(valvename, fieldnames(obj.data)), 'Unknown valve requested')
        assert(~ismember(duration_ms, obj.data.(valvename)), 'BpodLib:LiquidCalibration:ExistingDuration', 'Duration already exists in pending')
        assert(~ismember(duration_ms, obj.ValveManager.getValve(valvename).Durations), 'BpodLib:LiquidCalibration:ExistingDuration', 'Duration already exists in completed data')
        obj.data.(valvename) = [obj.data.(valvename), duration_ms];
    end

    function removePending(obj, valvename, duration_ms)
        assert(ismember(valvename, fieldnames(obj.data)), 'Unknown valve requested')
        assert(ismember(duration_ms, obj.data.(valvename)), 'Duration for valve should exist')
        obj.data.(valvename) = setdiff(obj.data.(valvename), duration_ms);
    end

    function completeMeasurement(obj, valvename, duration_ms, amount)
        % Complete a measurement for a valve
        assert(ismember(valvename, fieldnames(obj.data)), 'Unknown valve requested')
        assert(ismember(duration_ms, obj.data.(valvename)), 'Duration for completed measurement should have been pending')

        % Remove the completed measurement from pending
        obj.data.(valvename) = setdiff(obj.data.(valvename), duration_ms);

        % Add the completed measurement to the completed list
        obj.ValveManager.getValve(valvename).addMeasurement(duration_ms, amount);
    end

    function [valveNames, Durations_ms] = getPending(obj)
        % Get the pending measurements for all valves
        % Used to generate GUI data and to create calibration runscript
        valveNames = {};
        Durations_ms = [];

        allValveNames = fieldnames(obj.data);
        for idx = 1:numel(allValveNames)
            valvename = allValveNames{idx};
            pending_durations = obj.data.(valvename);
            if ~isempty(pending_durations)
                first_duration_s = pending_durations(1);
                valveNames{end+1} = valvename;
                Durations_ms = [Durations_ms; first_duration_s];
            end
        end
    end
end
end