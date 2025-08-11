function isDefault = checkDefaultData(LiquidCal)
% Check if the data is unchanged from the placeholder data shipped with Bpod
% isDefault = checkDefaultData(LiquidCal)
%
% This tests against the data in Bpod_Gen2/Examples/Examples Calibration Files/LiquidCalibration.json
% 
% Arguments
% ---------
% LiquidCal : BpodLib.calibration.liquid.ValveDataManagerClass or struct
%
% Returns
% -------
% isDefault : char
%      'true' (is default), 'false' (user modified), or 'unknown'

% Dummy data was created in 2016-11-17

isDefault = 'true';
if isa(LiquidCal, 'struct')
    if LiquidCal(1).LastDateModified > 736651.67253095
        isDefault = 'false';
    end
elseif isa(LiquidCal, 'BpodLib.calibration.liquid.ValveDataManagerClass')
    if isfield(LiquidCal.metadata, 'modification_datetime') && ~strcmp(LiquidCal.metadata.modification_datetime, "2000-01-01 00:00:00")
        isDefault = 'false';
    end
elseif isempty(LiquidCal)
    isDefault = 'unknown';
else
    warning('Could not determine if LiquidCal data has been user modified or not.')
end
end