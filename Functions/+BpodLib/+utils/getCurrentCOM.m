function comport = getCurrentCOM(BpodSystem)
% Return the name of the current COM
% Will return 'EMU' if emulator mode, otherwise 'COMX'

if isempty(BpodSystem.SerialPort)
    comport = 'EMU';
else
    comport = BpodSystem.SerialPort.Port;
end

end