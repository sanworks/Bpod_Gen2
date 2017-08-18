function ConfigureBonsaiSocket
global BpodSystem
BpodSystem.GUIHandles.ConfigureBonsaiFig = figure('Position', [350 380 300 300],'name','Bonsai socket configuration','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('BonsaiSettingsBG.bmp');
image(BG); axis off; drawnow;
BpodSystem.GUIHandles.BonsaiConnectButtonGFX = imread('BonsaiConnectButton.bmp');
BpodSystem.GUIHandles.BonsaiDisconnectButtonGFX = imread('BonsaiDisconnectButton.bmp');
BpodSystem.GUIHandles.BonsaiConnectButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [75 65 150 40], 'Callback', @ConnectToBonsai, 'CData', BpodSystem.GUIHandles.BonsaiConnectButtonGFX, 'TooltipString', 'Connect to Bonsai');
BpodSystem.GUIHandles.BonsaiConnectStatus = uicontrol('Style', 'text', 'String', 'Disconnected', 'Position', [75 228 150 30], 'FontSize', 14, 'FontWeight', 'bold', 'ForegroundColor', 'r', 'BackgroundColor', [.6 .6 .6]);
BpodSystem.GUIHandles.BonsaiIPEdit = uicontrol('Style', 'edit', 'String', 'localhost', 'Position', [75 155 150 30], 'FontSize', 14, 'FontWeight', 'bold', 'ForegroundColor', 'k', 'BackgroundColor', [.9 .9 .9]);
BpodSystem.GUIHandles.BonsaiPortEdit = uicontrol('Style', 'edit', 'String', '11235', 'Position', [75 115 150 30], 'FontSize', 14, 'FontWeight', 'bold', 'ForegroundColor', 'k', 'BackgroundColor', [.9 .9 .9]);
BpodSystem.GUIHandles.BonsaiAutoConnectSelector = uicontrol('Style', 'checkbox', 'String', '', 'Position', [255 28 15 15], 'BackgroundColor', [.9 .9 .9], 'Callback', @SetBonsaiAutoConnect);
if isfield(BpodSystem.SystemSettings, 'BonsaiAutoConnect')
    set(BpodSystem.GUIHandles.BonsaiAutoConnectSelector, 'value', BpodSystem.SystemSettings.BonsaiAutoConnect);
end
if BpodSystem.BonsaiSocket.Connected == 1 % Replace with actual detection of remote connection
    set(BpodSystem.GUIHandles.BonsaiConnectStatus, 'String', 'Connected', 'ForegroundColor', 'g');
    set(BpodSystem.GUIHandles.BonsaiConnectButton, 'CData', BpodSystem.GUIHandles.BonsaiDisconnectButtonGFX);
end

function SetBonsaiAutoConnect(junk, otherjunk)
global BpodSystem
BonsaiAutoConnectStatus = get(BpodSystem.GUIHandles.BonsaiAutoConnectSelector, 'value');
BpodSystem.SystemSettings.BonsaiAutoConnect = BonsaiAutoConnectStatus;

function ConnectToBonsai(junk, otherjunk)
global BpodSystem
if BpodSystem.BonsaiSocket.Connected == 0
    IPstring = get(BpodSystem.GUIHandles.BonsaiIPEdit, 'string');
    Port = str2double(get(BpodSystem.GUIHandles.BonsaiPortEdit, 'string'));
    %Instrument control toolbox way
    %BpodSystem.BonsaiSocket = tcpip(IPstring, Port, 'NetworkRole', 'server', 'BytesAvailableFcn', 'BonsaiOverride', 'BytesAvailableFcnCount', 3);
    
    % Java way, using BpodSocketServer plugin
    try
        BpodSocketServer('connect', Port);
        BpodSystem.BonsaiSocket.Connected = 1;
        set(BpodSystem.GUIHandles.BonsaiConnectStatus, 'String', 'Connected', 'ForegroundColor', 'g');
        set(BpodSystem.GUIHandles.BonsaiConnectButton, 'CData', BpodSystem.GUIHandles.BonsaiDisconnectButtonGFX);
    catch
        
    end
else
    BpodSocketServer('close');
    set(BpodSystem.GUIHandles.BonsaiConnectStatus, 'String', 'Disconnected', 'ForegroundColor', 'r');
    set(BpodSystem.GUIHandles.BonsaiConnectButton, 'CData', BpodSystem.GUIHandles.BonsaiConnectButtonGFX);
    BpodSystem.BonsaiSocket.Connected = 0;
end