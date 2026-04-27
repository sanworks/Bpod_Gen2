function save(saveData, varargin)
% Save liquid calibration data to disk
% save(saveData, _)
%
% Arguments
% ---------
% saveData : struct
%     The output of ValveDataManager.createSaveData().
%
% Keyword Arguments
% -----------------
% BpodSystem : BpodObject
%     BpodSystem used to identify the COM
% type : char
%     What kind of liquid calibration data it is. 'statemachine' or 'portarray'
% filepath : char
%     Filepath to save to. Must be specified if 'type' is not.
% verbose : logical (default=true)
%     Whether to display messages in Command Window.

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

p = inputParser();
p.addParameter('BpodSystem', [])
p.addParameter('filepath', [])
p.addParameter('type', [])
p.addParameter('verbose', false)
p.parse(varargin{:})
BpodSystem = p.Results.BpodSystem;

% LiquidCal should be converted into a a struct with .createSaveData()
% first, as this allows arbitrary metadata to be saved prior to this final
% process.
assert(isa(saveData, 'struct'),'BpodLib:LiquidCalibrationSave:WrongFormat',...
    'Save data should be a structure.')

% Determine the save location of the calibration file
if isempty(p.Results.filepath)
    assert(~isempty(p.Results.type), "Either 'filepath' or 'type' must be specified")
    calibrationFolderpath = BpodLib.path.getPath('calibration', BpodSystem);
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
    if isfield(saveData.metadata, 'COM')
        savedCOM = saveData.metadata.COM;
    else
        savedCOM = 'none';
    end
    currentCOM = BpodLib.utils.getCurrentCOM(BpodSystem);
    
    % check COM against saved value
    if p.Results.verbose && ~strcmp(currentCOM, savedCOM)
        warning('COM port has changed.')
        fprintf('Previous COM: %s\nNew COM: %s\n', savedCOM, currentCOM)
    end
    saveData.metadata.COM = currentCOM;
end


% Write to JSON file

if verLessThan('matlab', '9.10') % R2021a is 9.10
    writedata = jsonencode(saveData);
else
    writedata = jsonencode(saveData, 'PrettyPrint', true);
end
fid = fopen(filepath, 'w');
fwrite(fid, writedata, 'char');
fclose(fid);

end