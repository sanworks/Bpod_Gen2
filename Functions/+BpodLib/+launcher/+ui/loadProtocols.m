function loadProtocols(BpodSystem)
% Update the list of available protocols in the GUI

ProtocolNames = BpodLib.launcher.findProtocols(BpodSystem);
set(BpodSystem.GUIHandles.ProtocolSelector, 'String', ProtocolNames);
end