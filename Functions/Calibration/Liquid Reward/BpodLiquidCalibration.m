function varargout = BpodLiquidCalibration(operation, varargin)
%BpodLiquidCalibration(operation, _)

global BpodSystem

if strcmpi(operation, 'calibrate')
    if nargin == 1
        BpodLib.calibration.liquid.launchLiquidCalibrationUI(BpodSystem);
        return;
    else
        assert(strcmpi(varargin{2}, 'portarray'), "Expected 'portarray' as second argument when calling 'calibrate' operation.");
        try
            BpodLib.calibration.liquid.portarray.launchCalibrator(BpodSystem);
        catch ME
            if strcmp(ME.identifier, 'BpodLib:portarraylaunchCalibrator:NoData')
                BpodLib.calibration.liquid.portarray.initialise(BpodSystem);
                fprintf('%s Created new port array calibration file.\n', BpodLib.utils.isotime('time'))
                BpodLib.calibration.liquid.portarray.launchCalibrator(BpodSystem);
            else
                rethrow(ME);
            end
        end
    end
elseif strcmpi(operation, 'getvalvetimes')
    % Would anyone use this code?
    assert(nargin==3, "Operation 'getvalvetimes' requires liquidamount_ul, targetvalves")
    LiquidAmount_uL = varargin{1};
    TargetValves = varargin{2};
    if ~isnumeric(LiquidAmount_uL);LiquidAmount_uL = str2double(LiquidAmount_uL);end
    if ~isnumeric(TargetValves);TargetValves = str2double(TargetValves);end
    ValveTimes_s = GetValveTimes(LiquidAmount_uL, TargetValves);
    varargout{1} = ValveTimes_s;
    return;
else
    error("Operation '%s' not recognised.", operation)
end

end