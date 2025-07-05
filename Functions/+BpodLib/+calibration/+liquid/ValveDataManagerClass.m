% ValveDataManagerClass - Handle class for storing and managing multiple valve calibration data
%
% This class can store multiple valve calibration data
% This is the OOP version of the LiquidCal struct from <1.8.1

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

classdef ValveDataManagerClass < handle
properties
    ValveDatas  % struct of BpodLib.calibration.liquid.ValveData objects, indexed by valve name
    metadata  % struct of metadata of valve
end

methods
    function obj = ValveDataManagerClass(varargin)
        % Container class for managing multiple multiple valves
        % obj = ValvedataManagerClass(_)
        %
        % Keyword Arguments
        % -----------------
        % filepath : char
        %     Path to file to auto load from

        p = inputParser();
        p.addParameter('filepath', '', @ischar);
        p.parse(varargin{:});

        obj.ValveDatas = struct();
        obj.metadata = struct();

        if ~isempty(p.Results.filepath)
            obj.loadData(p.Results.filepath);
        else
            obj.ValveDatas = struct();
        end
    end

    function valveData = getValve(obj, valveName)
        % Return valve object
        % valveData = getValve(valveName)
        %
        % Arguments
        % ---------
        % valveName : char or double
        %     Identity of vlve to retrieve
        %
        % Returns
        % -------
        % valveData : BpodLib.calibration.liquid.ValveDataClass
        %     Single valve data object

        if isa(valveName, 'double')
            valveName = sprintf('Valve%d', valveName);
        end

        try
            valveData = obj.ValveDatas.(valveName);
        catch ME
            if strcmp(ME.identifier, 'MATLAB:Containers:Map:NoKey')
                error('BpodLib:ValveDataManagerClass:ValveNotFound', 'Valve %s not found in data. Use createValve to make new valve data.', valveName);
            else
                rethrow(ME);
            end
        end
    end

    function valveData = createValve(obj, valveName)
        % Create a new valve within the manager
        % valveData = createValve(valveName)
        %
        % Arguments
        % ---------
        % valveName : char
        %     Name of the new valve
        %
        % Returns
        % -------
        % valveData : BpodLib.calibration.liquid.ValveDataClass
        %     The new ValveData object

        valveData = BpodLib.calibration.liquid.ValveDataClass();
        valveData.ValveName = valveName;
        if isfield(obj.ValveDatas, valveName)
            error('BpodLib:ValveDataManagerClass:ValveExists', 'Valve %s already exists in data.', valveName);
        end
        obj.ValveDatas.(valveName) = valveData;
        % ! this doesn't allow for funky naming schemes, which we should probably try to allow
    end

    function valveNames = getValveNames(obj)
        % Get the names of all valves
        % 
        % Returns
        % -------
        % valveNames : cell array of strings
        %     Names of all valves

        valveNames = fieldnames(obj.ValveDatas);
    end

    function n_Valves = nValves(obj)
        % Get number of valves stored in file
        % Returns
        % -------
        % n_Valves : double
        %     Number of valves in the manager

        n_Valves = numel(obj.getValveNames);
    end

    function savedata = createSaveData(obj)
        % Create a file save-ready format of the manager
        % Returns
        % -------
        % savedata : struct
        %     Structure formatted for json encoding

        % -- Create save data struct
        % Initialize struct array (jsonencode will write as array of objects)
        valveDatas = cell(1, obj.nValves);
        valveNames = obj.getValveNames();
        i = 0;
        for valveName = valveNames'
            i = i + 1;
            valveDatas{i} = struct(obj.getValve(valveName{1}));
        end

        savedata = struct;
        savedata.metadata = obj.metadata;
        savedata.metadata.modification_datetime = BpodLib.utils.isotime();
        savedata.ValveDatas = valveDatas;
    end

    function saveData(obj, filepath)
        % Convenience function to save data, BpodLib.calibration.liquid.io.save is preferred
        % 
        % Arguments
        % ---------
        % filepath : char
        %     The path to the file to save to
        %
        % JSON save format
        % metadata: object
        %     modification_datetime: string
        % ValveDatas: array of objects
        %     ValveName: string
        %     LastDateModified: string
        %     Coeffs: array of numbers
        %     Durations: array of numbers
        %     Amounts: array of numbers
        %
        % ValveName is 'ValveX' where X is the valve number
        % LastDateModified is the date and time the data was last modified in ISO format
        % Coeffs is a 1x3 array of polynomial coefficients (2nd order polynomial)
        % Durations and Amounts are arrays of the same length

        BpodLib.calibration.liquid.io.save(obj.createSaveData(), 'filepath', filepath, 'verbose', false)
    end

    function loadData(obj, filepath, varargin)
        % Load data from file
        % loadData(filepath, _)
        %
        % Arguments
        % ---------
        % filepath : char
        %     JSON file to load from
        %
        % Keyword Arguments
        % -----------------
        % overwrite : logical (default=true)
        %     Overwrite existing valve data

        p = inputParser;
        p.addOptional('overwrite', true, @islogical);
        p.parse(varargin{:});

        if p.Results.overwrite
            obj.ValveDatas = struct();
        end
        [~, ~, ext] = fileparts(filepath);

        if ~strcmp(ext, '.json')
            error('Expected .json file but received %s file.', ext)
            % ? we could implement a .mat file loader, but this is not the format we want to use
        end

        loaddata = fileread(filepath);
        rawstruct = jsondecode(loaddata);
        obj.metadata = rawstruct.metadata;
        valveDatas = rawstruct.ValveDatas;
        
        % Load data into ValveData objects
        for i = 1:numel(valveDatas)
            valveData = BpodLib.calibration.liquid.ValveDataClass();
            valveData.load(valveDatas(i));
            obj.ValveDatas.(valveData.ValveName) = valveData;
        end
    end
end

end