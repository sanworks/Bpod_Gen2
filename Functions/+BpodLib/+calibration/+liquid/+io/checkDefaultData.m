function isDifferent = checkDefaultData(LiquidCal)
% isDifferent = checkDefaultData(LiquidCal)
% Check if the data is unchanged from the placeholder data shipped with Bpod

dummyManager = BpodLib.calibration.liquid.compatibility.createDummyData();
isDifferent = 'false';
if isa(LiquidCal, 'struct')
    if LiquidCal(1).LastDateModified > 7.3665e+05
        isDifferent = 'true';
    end
elseif isa(LiquidCal, 'BpodLib.calibration.liquid.ValveDataManagerClass')
    if isfield(LiquidCal.metadata, 'LastDateModified') && ~strcmp(LiquidCal.metadata.LastDateModified, "2016-11-17 16:08:26")
        isDifferent = 'true';
    end
elseif isempty(LiquidCal)
    isDifferent = 'unknown';
else
    warning('Could not determine if LiquidCal data has been user modified or not.')
end

end