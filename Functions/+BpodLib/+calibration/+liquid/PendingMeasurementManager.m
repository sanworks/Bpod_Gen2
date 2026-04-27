% Manager for pending data

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

classdef PendingMeasurementManager < handle
properties
    LiquidCal
    Pending
end

methods
    function obj = PendingMeasurementManager(LiquidCal)
        % obj = PendingMeasurementManager(LiquidCal)
        obj.LiquidCal = LiquidCal;

        % Initialize the Pending structure with empty arrays for each valve
        valveNames = LiquidCal.getValveNames();
        obj.Pending = struct();
        for idx = 1:numel(valveNames)
            valvename = valveNames{idx};
            obj.Pending.(valvename) = [];
        end
    end

    function addPending(obj, valvename, duration_ms)
        % Add a pending measurement for a valve
        assert(ismember(valvename, fieldnames(obj.Pending)), 'Unknown valve requested')
        assert(~ismember(duration_ms, obj.Pending.(valvename)), 'BpodLib:LiquidCalibration:ExistingDuration', 'Duration already exists in pending')
        assert(~ismember(duration_ms, obj.LiquidCal.getValve(valvename).Durations), 'BpodLib:LiquidCalibration:ExistingDuration', 'Duration already exists in completed data')
        obj.Pending.(valvename) = [obj.Pending.(valvename), duration_ms];
    end

    function removePending(obj, valvename, duration_ms)
        assert(ismember(valvename, fieldnames(obj.Pending)), 'Unknown valve requested')
        assert(ismember(duration_ms, obj.Pending.(valvename)), 'Duration for valve should exist')
        obj.Pending.(valvename) = setdiff(obj.Pending.(valvename), duration_ms);
    end

    function completeMeasurement(obj, valvename, duration_ms, amount)
        % Complete a measurement for a valve
        assert(ismember(valvename, fieldnames(obj.Pending)), 'Unknown valve requested')
        assert(ismember(duration_ms, obj.Pending.(valvename)), 'Duration for completed measurement should have been pending')

        % Remove the completed measurement from pending
        obj.Pending.(valvename) = setdiff(obj.Pending.(valvename), duration_ms);

        % Add the completed measurement to the completed list
        obj.LiquidCal.getValve(valvename).addMeasurement(duration_ms, amount);
    end

    function Durations_ms = getValvePending(obj, valveName)
        Durations_ms = obj.Pending.(valveName);
    end

    function valveNames = getValveNames(obj)
        valveNames = fields(obj.Pending);
    end

    function [valveNames, Durations_ms] = getPending(obj)
        % Get the pending measurements for all valves
        % Used to generate GUI Pending and to create calibration runscript
        valveNames = {};
        Durations_ms = [];

        allValveNames = fieldnames(obj.Pending);
        for idx = 1:numel(allValveNames)
            valvename = allValveNames{idx};
            pending_durations = obj.Pending.(valvename);
            if ~isempty(pending_durations)
                first_duration_s = pending_durations(1);
                valveNames{end+1} = valvename;
                Durations_ms = [Durations_ms; first_duration_s];
            end
        end
    end
end
end