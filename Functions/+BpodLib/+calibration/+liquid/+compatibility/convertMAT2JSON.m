function convertMAT2JSON(BpodSystem, sourcepath, savepath)
% Convert a LiquidCalibration.mat file to a LiquidCalibration.json file
% :param sourcepath: the path to the LiquidCalibration.mat file
% :type sourcepath: char
% :param savepath: the path to save the .json file
% :type savepath: char

%{
Prior to version 1.X.X, liquid calibration data was stored in a .mat file.
This function converts the .mat file to a .json file for compatibility with the new format.
%}

[~, ~, ext] = fileparts(sourcepath);

assert(strcmp(ext, '.mat'), 'File must be a .mat file');
LiquidCal = load(sourcepath, 'LiquidCal').LiquidCal;

nValves = numel(LiquidCal);
if nValves ~= 8
    warning('BpodLib:ValveDataManagerClass:Unexpected valve number', '8 valves expected but %i found. User-modified liquid calibration data likely.', nValves);
end

valveManager = BpodLib.calibration.liquid.compatibility.convertFormat(LiquidCal);

valveManager.saveData(savepath);
valveDatas = valveManager.createSaveData();
currentCOM = BpodLib.utils.getCurrentCOM(BpodSystem);
valveDatas.metadata.COM = currentCOM;
BpodLib.calibration.liquid.io.save(valveDatas, savepath, 'BpodSystem', BpodSystem);
end