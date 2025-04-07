function LiquidCal = convertToOldFormat(ValveDataManager)
% Save ValveDataManager as the old format

LiquidCal = struct('Table', [], 'Coeffs', [], 'LastDateModified', []);

valveNames = ValveDataManager.getValveNames();
assert(numel(valveNames) == 8)

savetimes = nan(1, 8);

for x = 1:8
    Valve = ValveDataManager.getValve(x);
    Table = [Valve.Durations, Valve.Amounts];
    [~, nCols] = size(Table);
    if ~ismember(nCols, [0, 2])
        error('Table is not working as expected.')
    end
    LiquidCal(x).Table = Table;
    LiquidCal(x).Coeffs = Valve.Coeffs;
    ldm = Valve.LastDateModified;
    if ~isempty(ldm)
        savetimes(x) = datenum(ldm);
    end
end

LiquidCal(1).LastDateModified = max(savetimes);


end