function report(LiquidCal)
if ~BpodLib.calibration.liquid.io.checkDefaultData(LiquidCal)
    warning('BpodLib:liquidcalibration:UnmodifiedData', 'Liquid calibration data is detected as unmodified. Remember to calibrate your valve before performing experiments!')
end

if isa(LiquidCal, 'BpodLib.calibration.liquid.ValveDataManagerClass')
    valveNames = LiquidCal.getValveNames();
    for idx = 1:numel(valveNames)
        valveName = valveNames{idx};
        Valve = LiquidCal.getValve(valveName);
        if ~isempty(Valve.LastDateModified)
            ldm = datetime(Valve.LastDateModified);
            delta = datetime('now') - ldm;
            fprintf('%s last modified %s (%.1f days ago)\n', valveName, ldm, round(days(delta), 1))
        end
    end
elseif isa(LiquidCal, 'struct')
    ldm = datetime(LiquidCal(1).LastDateModified, 'ConvertFrom', 'datenum');
    delta = datetime('now') - ldm;
    fprintf('Liquid calibration data last modified %s (%.1f days ago)\n', ldm, round(days(delta), 1))
elseif isempty(LiquidCal)
    % fail silently?
end

end