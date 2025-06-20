% Class for managing ValveData objects
% This class is used to store ValveData objects for multiple valves, and provides methods for getting and saving data.
% The valve datas are stored in a cell array, with each cell containing a ValveData object (a handle) for a single valve.

classdef ValveDataManagerClass < handle
properties
    ValveDatas  % struct of BpodLib.calibration.liquid.ValveData objects, indexed by valve name
    metadata  % struct of metadata of valve
end

methods
    function obj = ValveDataManagerClass(varargin)
        % Create the ValveDataManager
        % :param filepath: the path to a file to load data from, optional
        % :type filepath: char
        
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
        % Get the ValveData object for a valve
        % :param valveName: the name of the valve to get data for, or the valve number X ('ValveX')
        % :type valveName: char or int
        % :return valveData: the ValveData object for the valve (a handle)
        % :rtype valveData: BpodLib.calibration.liquid.ValveDataClass

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
        % Create a new ValveData object for a valve
        % :param valveName: the name of the valve to create data for
        % :type valveName: char or string
        % :return valveData: the new ValveData object
        % :rtype valveData: BpodLib.calibration.liquid.ValveDataClass
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
        % :return valveNames: the names of all valves
        % :rtype valveNames: cell array of strings

        valveNames = fieldnames(obj.ValveDatas);
    end

    function n_Valves = nValves(obj)
        % Get number of valves stored in file
        % :return n_Valves: number of valve
        % :rtype n_Valves: int

        n_Valves = numel(obj.getValveNames);
    end

    function savedata = createSaveData(obj)
        % Create a save-ready format of the manager
        % :return savedata: Structure formatted for json encoding

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
        % :param filepath: the path to the file to save
        % :type filepath: char
        %
        % Save data JSON format
        % ---------------------
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
        % Load data from a file
        % :param filepath: the path to the file to load
        % :type filepath: char
        % :param overwrite: whether to overwrite existing data (default: true), or append
        % :type overwrite: logical

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