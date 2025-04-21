function ValveTimes_s = GetValveTimes(LiquidAmount_uL, TargetValves, varargin)
% Get time required for target valves to release requested amount of liquid
% 
% :param LiquidAmount: Required amount of liquid
% :type LiquidAmount: double
% :param TargetValves: Valves to retrieve times for
% :type TargetValves: int or array

p = inputParser();
p.addParameter('BpodSystem', [])
p.addParameter('ValveDataManager', [])
p.parse(varargin{:})

persistent deprecationWarningIssued

BpodSystem = BpodLib.utils.getBpodSystem(p);
if isfield(BpodSystem.CalibrationTables, 'LiquidCal')
    LiquidCal = BpodSystem.CalibrationTables.LiquidCal;

    if isa(LiquidCal, 'struct')
        if isempty(deprecationWarningIssued)
            warning('GetValveTimes:Deprecation', ...
            'The LiquidCalibration.mat file should have been converted into a .json file. This warning means this has not happened, and the file will have to be modified. Please contact the forums for assistance.');
        deprecationWarningIssued = true; % Mark as warned
        end
        ValveTimes_s = LegacyGetValveTimes(LiquidAmount_uL, TargetValves, 'BpodSystem', BpodSystem);
        return
    else
        ValveDataManager = LiquidCal;
    end
end


nValves = length(TargetValves);
ValveTimes_ms = nan(1,nValves);

for x = 1:nValves
    valveNumber = TargetValves(x);
    valveName = sprintf('Valve%i', valveNumber);
    valveTime_ms = ValveDataManager.getValve(valveName).getValveTime(LiquidAmount_uL);

    ValveTimes_ms(x) = valveTime_ms;
end

ValveTimes_s = ValveTimes_ms / 1000;
end