function save(ValveDataManagerStruct, filepath, varargin)
% Save liquid calibration data to disk
% :param ValveDataManagerStruct: The output of ValveDataManager.createSaveData()
% :type ValveDataManagerStruct: struct


p = inputParser();
p.addParameter('BpodSystem', [])
p.addParameter('type', [])
p.addParameter('verbose', false)
p.parse(varargin{:})
BpodSystem = BpodLib.utils.getBpodSystem(p);

% We want data to be a struct from the get-go because we might want to insert additional data later on...
assert(isa(ValveDataManagerStruct, 'struct'),'BpodLib:LiquidCalibrationSave:WrongFormat',...
    'Save data should be a structure.')
savedata = ValveDataManagerStruct;
% todo: should it be?

% Insert COM port metadata
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
    % todo: is this warning useful?
end
savedata.metadata.COM = currentCOM;


% Write to JSON file
writedata = jsonencode(savedata, 'PrettyPrint', true);
fid = fopen(filepath, 'w');
fwrite(fid, writedata, 'char');
fclose(fid);

end