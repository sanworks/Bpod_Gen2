function ValveManager = createValveManager(BpodSystem)
% Create an empty ValveDataManager for PortArrays

ValveManager = BpodLib.calibration.liquid.ValveDataManagerClass();
nModuleChannels = numel(BpodSystem.Modules.Connected);

for portarraynumber = 1:nModuleChannels
    for valveIndex = 1:4
        ValveManager.createValve(sprintf('PA%i_%i', portarraynumber, valveIndex))
    end
end

end