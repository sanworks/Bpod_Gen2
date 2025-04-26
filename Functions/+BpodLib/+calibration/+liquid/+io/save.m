function save(ValveDataManagerStruct, varargin)
% Save liquid calibration data to disk
% :param ValveDataManagerStruct: The output of ValveDataManager.createSaveData()
% :type ValveDataManagerStruct: struct

p = inputParser();
p.addParameter('BpodSystem', [])
p.addParameter('filepath', [])
p.addParameter('type', [])
p.addParameter('verbose', false)
p.parse(varargin{:})
BpodSystem = p.Results.BpodSystem;

% We want data to be a struct from the get-go because we might want to insert additional data later on...
assert(isa(ValveDataManagerStruct, 'struct'),'BpodLib:LiquidCalibrationSave:WrongFormat',...
    'Save data should be a structure.')
savedata = ValveDataManagerStruct;

% Determine the save location of the calibration file
if isempty(p.Results.filepath)
    assert(~isempty(p.Results.type), "Either 'filepath' or 'type' must be specified")
    calibrationFolderpath = BpodLib.path.getPath(BpodSystem, 'liquidcalibration');
    switch lower(p.Results.type)
        case 'statemachine'
            filename = 'LiquidCalibration.json';
        case 'portarray'
            filename = 'LiquidCalibration-PortArrays.json';
        otherwise
            error('BpodLib:LiquidCalibration:UnrecognisedType', "Load type '%s' not recognised, should be 'statemachine' or 'portarray'", p.Results.type)
    end
    filepath = fullfile(calibrationFolderpath, filename);
else
    assert(isempty(p.Results.type), 'Only provide filepath or automate save location with type')
    filepath = p.Results.filepath;
end

% Insert COM port metadata
if ~isempty(BpodSystem)
    if isfield(savedata.metadata, 'COM')
        savedCOM = savedata.metadata.COM;
    else
        savedCOM = 'none';
    end
    currentCOM = BpodLib.utils.getCurrentCOM(BpodSystem);
    
    % check COM against saved value
    if p.Results.verbose && ~strcmp(currentCOM, savedCOM)
        warning('COM port has changed.')
        fprintf('Previous COM: %s\nNew COM: %s\n', savedCOM, currentCOM)
    end
    savedata.metadata.COM = currentCOM;
end


% Write to JSON file
writedata = jsonencode(savedata, 'PrettyPrint', true);
fid = fopen(filepath, 'w');
fwrite(fid, writedata, 'char');
fclose(fid);

end