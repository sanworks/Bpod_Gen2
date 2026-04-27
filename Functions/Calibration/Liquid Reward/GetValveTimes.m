function ValveTimes_s = GetValveTimes(LiquidAmount_uL, TargetValves, varargin)
% Get time required for target valves to release requested amount of liquid
% 
% times_s = GetValveTimes(LiquidAmount_uL, TargetValves);
% times_s_portarray = GetValveTimes(10, [1, 3], 'PortArray', 1);
% 
% :param LiquidAmount: Required amount of liquid
% :type LiquidAmount: double
% :param TargetValves: List of valves to retrieve times for
% :type TargetValves: int or array
% :param PortArray: PortArrayModule's indentity, integer
% :type PortArray: double
%
% Examples:
% vt = GetValveTimes(5, [1 3]); % Return valve times for 5ul of liquid for behavior ports 1 and 3 on the state machine
% vt = GetValveTimes(7, 2, 'PortArray', 1); % Return the valve time for 7ul from behavior port 2 on port array #1

p = inputParser();
p.addParameter('BpodSystem', [])
p.addParameter('PortArray', [])
p.parse(varargin{:})

persistent deprecationWarningIssued

BpodSystem = BpodLib.utils.getBpodSystem(p);
if isempty(p.Results.PortArray)
    LiquidCal = BpodSystem.CalibrationTables.LiquidCal;
    assert(~isempty(LiquidCal), 'Liquid calibration table not found.')

    if isa(LiquidCal, 'struct') % The legacy system
        if isempty(deprecationWarningIssued) && false
            warning('GetValveTimes:Deprecation', ...
            'The LiquidCalibration.mat file should have been converted into a .json file. This warning means this has not happened, and the file will have to be modified. Please contact the forums for assistance.');
        deprecationWarningIssued = true; % Mark as warned
        end
        ValveTimes_s = LegacyGetValveTimes(LiquidAmount_uL, TargetValves, 'BpodSystem', BpodSystem);
        return
    else
        ValveDataManager = LiquidCal;
        portnameFunc = @(index) sprintf('Valve%i', index);
    end
else
    assert(isa(BpodSystem.CalibrationTables.PortArrays, 'BpodLib.calibration.liquid.ValveDataManagerClass'), 'PortArray calibration data not loaded and therefore cannot find value.')
    % This error probably means .PortArrays = []
    % User should use BpodLib.calibration.liquid.portarray.launchCalibrator(BpodSystem)
    ValveDataManager = BpodSystem.CalibrationTables.PortArrays;
    portname = sprintf('PA%i', p.Results.PortArray);
    portnameFunc = @(index) sprintf('%s_%i', portname, index);
end


nValves = length(TargetValves);
ValveTimes_ms = nan(1,nValves);

for x = 1:nValves
    valveNumber = TargetValves(x);
    valveName = portnameFunc(valveNumber);
    valveTime_ms = ValveDataManager.getValve(valveName).getValveTime(LiquidAmount_uL);
    ValveTimes_ms(x) = valveTime_ms;
end

ValveTimes_s = ValveTimes_ms / 1000;
end