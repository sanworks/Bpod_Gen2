function isDefault = checkDefaultData(LiquidCal)
% isDefault = checkDefaultData(LiquidCal)
% Check if the data is unchanged from the placeholder data shipped with Bpod
% Returns char 'true', 'false', or 'unknown'
% todo: do better checks on this
dummyManager = BpodLib.calibration.liquid.compatibility.createDummyData();
isDefault = 'true';
if isa(LiquidCal, 'struct')
    if LiquidCal(1).LastDateModified > 736651.67253095
        isDefault = 'false';
    end
elseif isa(LiquidCal, 'BpodLib.calibration.liquid.ValveDataManagerClass')
    if isfield(LiquidCal.metadata, 'modification_datetime') && ~strcmp(LiquidCal.metadata.modification_datetime, "2016-11-17 16:08:26")
        isDefault = 'false';
    end
elseif isempty(LiquidCal)
    isDefault = 'unknown';
else
    warning('Could not determine if LiquidCal data has been user modified or not.')
end

end