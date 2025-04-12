function save(ValveDataManagerStruct, filepath, varargin)
% Save liquid calibration data to disk
% :param ValveDataManagerStruct: The output of ValveDataManager.createSaveData()
% :type ValveDataManagerStruct: struct


p = inputParser();
p.addParameter('BpodSystem', [])
p.parse(varargin{:})

assert(isa(ValveDataManagerStruct, 'struct'),'BpodLib:LiquidCalibrationSave:WrongFormat',...
    'Save data should be a structure!')
savedata = ValveDataManagerStruct;
% todo: should it be?

% Insert COM port metadata
if isfield(savedata.metadata, 'COM')
    savedCOM = savedata.metadata.COM;
else
    savedCOM = [];
end
if ~isempty(p.Results.BpodSystem)
    SerialPort = p.Results.BpodSystem.SerialPort;
    if isempty(SerialPort)
        currentCOM = 'EMU';
    else
        currentCOM = SerialPort.Port;
    end

    % check COM against saved value
    if ~strcmp(currentCOM, savedCOM)
        warning('COM port has changed.')
        fprintf('Previous COM: %s\New COM: %s\n', savedCOM, currentCOM)
    end
    savedata.metadata.COM = currentCOM;
end
% savedata.metadata.COMPort = BpodSystem.

% Write to JSON file
writedata = jsonencode(savedata, 'PrettyPrint', true);
fid = fopen(filepath, 'w');
fwrite(fid, writedata, 'char');
fclose(fid);

end