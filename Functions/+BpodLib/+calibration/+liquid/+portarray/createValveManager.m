function ValveManager = createValveManager(BpodSystem)
% Create an empty ValveDataManager for PortArrays

ValveManager = BpodLib.compatibility.liquid.ValveDataManagerClass();
switch BpodSystem.MachineType
    % todo: add values for other machine types
    case 2; nModuleChannels = 4;
    case 3; nModuleChannels = 4;
    case 4; nModuleChannels = 3;
    otherwise; error('BpodLib:portarray.createValveManager:MachineTypeUnrecognised', 'Machine type unrecognised.')
end

for portarraynumber = 1:nModuleChannels
    for valveIndex = 1:4
        ValveManager.addValve(sprintf('PA%i-%i', portarraynumber, valveIndex))
    end
end

end