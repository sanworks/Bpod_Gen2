function stopProtocol(BpodSystem)
% End the current protocol session.
% stopProtocol(BpodSystem)

if ~isempty(BpodSystem.Status.CurrentProtocolName) & BpodSystem.Status.Verbose
    disp(' ')
    fprintf('%s Stopping protocol: %s\n', BpodLib.utils.isotime('time'), BpodSystem.Status.CurrentProtocolName)
end
warning off % Suppress warning, in case protocol folder has already been removed
% This folder is added in launchProtocol.m
rmpath(fileparts(BpodSystem.Path.CurrentProtocol));
warning on
BpodSystem.Status.BeingUsed = 0;
BpodSystem.Status.CurrentProtocolName = '';
BpodSystem.Path.Settings = '';
BpodSystem.Status.Live = 0;
if BpodSystem.EmulatorMode == 0
    if BpodSystem.MachineType > 3
        stop(BpodSystem.Timers.AnalogTimer);
        try
        fclose(BpodSystem.AnalogDataFile);
        catch
        end
    end
    BpodSystem.SerialPort.write('X', 'uint8');
    pause(.1);
    BpodSystem.SerialPort.flush;
    if BpodSystem.MachineType > 3
        BpodSystem.AnalogSerialPort.flush;
    end
    if isfield(BpodSystem.PluginSerialPorts, 'TeensySoundServer')
        TeensySoundServer('end');
    end   
end
BpodSystem.Status.RecordAnalog = 1;
BpodSystem.Status.InStateMatrix = 0;

% Close protocol and plugin figures
try
    Figs = fields(BpodSystem.ProtocolFigures);
    nFigs = length(Figs);
    for x = 1:nFigs
        try
            close(eval(['BpodSystem.ProtocolFigures.' Figs{x}]));
        catch
            
        end
    end
    try
        close(BpodNotebook)
    catch
    end
    try
        BpodSystem.analogViewer('end', []);
    catch
    end
catch
end
if ~isempty(BpodSystem.GUIHandles)
    set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.GoButton,... 
        'TooltipString', 'Launch behavior session');
end
if BpodSystem.Status.Pause == 1
    BpodSystem.Status.Pause = 0;
end
% ---- end Shut down Plugins
end