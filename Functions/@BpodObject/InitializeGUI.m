%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) Sanworks LLC, Rochester, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}

% BpodObject.InitializeGUI() initializes the Bpod Console GUI.
% InitializeGUI() is called on startup in Bpod.m

function obj = InitializeGUI(obj)

% Setup figure label
labelFontColor = [0.8 0.8 0.8];
title = 'Bpod Console';
titleColor = labelFontColor;

% Setup fonts
titleFontName = 'Courier New';
fontName = 'Courier New';

% Setup font sizes
if ispc
    vvsm = 12; vsm = 11; sm = 12; med = 13; lg = 20;
elseif ismac
    vvsm = 12; vsm = 14; sm = 16; med = 17; lg = 22;
    fontName = 'Arial';
else
    vvsm = 10; vsm = 9; sm = 12; med = 13; lg = 20;
    fontName = 'DejaVu Sans Mono';
end

% Create GUI figure + background image
obj.GUIHandles.MainFig = figure('Position',[80 100 825 400],'name','Bpod Console','numbertitle','off',...
    'MenuBar', 'none', 'Resize', 'off', 'CloseRequestFcn', 'EndBpod');
obj.GUIHandles.Console = axes('units','normalized', 'position',[0 0 1 1]);
uistack(obj.GUIHandles.Console,'bottom');
bg = imread('ConsoleBG3.bmp');
image(bg); axis off;

% Create buttons
obj.GUIData.GoButton = imread('PlayButton.bmp');
obj.GUIData.PauseButton = imread('PauseButton.bmp');
obj.GUIData.PauseRequestedButton = imread('PauseRequestedButton.bmp');
obj.GUIData.StopButton = imread('StopButton.bmp');
obj.GUIHandles.RunButton = uicontrol('Style', 'pushbutton',...
    'String', '', ...
    'Position', [742 100 60 60],...
    'Callback', 'RunProtocol(''StartPause'')',...
    'CData', obj.GUIData.GoButton,...
    'TooltipString', 'Launch behavior session');
obj.GUIHandles.EndButton = uicontrol('Style', 'pushbutton',...
    'String', '',...
    'Position', [742 20 60 60],...
    'Callback', 'RunProtocol(''Stop'')',...
    'CData', obj.GUIData.StopButton,...
    'TooltipString', 'End session');

obj.GUIData.OffButton = imread('ButtonOff.bmp');
obj.GUIData.OffButtonDark = imread('ButtonOff_dark.bmp');
obj.GUIData.OnButton = imread('ButtonOn.bmp');
obj.GUIData.OnButtonDark = imread('ButtonOn_dark.bmp');
obj.GUIData.SettingsButton = imread('SettingsButton.bmp');
obj.GUIData.RefreshButton = imread('RefreshButton.bmp');
obj.GUIData.USBButton = imread('USBButton.bmp');
obj.GUIData.SystemInfoButton = imread('SystemInfoButton.bmp');
obj.GUIData.DocButton = imread('DocButton.bmp');
obj.GUIData.AddProtocolButton = imread('AddProtocolIcon.bmp');
obj.GUIData.AnalogViewerButton = imread('AlgViewer.bmp');
obj.GUIHandles.SettingsButton = uicontrol('Style', 'pushbutton',...
    'String', '',...
    'Position', [778 275 29 29],...
    'Callback', 'BpodSettingsMenu',...
    'CData', obj.GUIData.SettingsButton,...
    'TooltipString', 'Settings and calibration');
obj.GUIHandles.RefreshButton = uicontrol('Style', 'pushbutton',...
    'String', '',...
    'Position', [733 275 29 29],...
    'Callback', @(h,e)obj.LoadModules(),...
    'CData', obj.GUIData.RefreshButton,...
    'TooltipString', 'Refresh modules');
obj.GUIHandles.SystemInfoButton = uicontrol('Style', 'pushbutton',...
    'String', '',...
    'Position', [778 227 29 29],...
    'Callback', 'BpodSystemInfo',...
    'CData', obj.GUIData.SystemInfoButton,...
    'TooltipString', 'View system info');
obj.GUIHandles.USBButton = uicontrol('Style', 'pushbutton',...
    'String', '',...
    'Position', [733 227 29 29],...
    'Callback', 'ConfigureModuleUSB',...
    'CData', obj.GUIData.USBButton,...
    'TooltipString', 'Configure module USB ports');
obj.GUIHandles.DocButton = uicontrol('Style', 'pushbutton',...
    'String', '',...
    'Position', [796 371 29 29],...
    'Callback', @(h,e)obj.Wiki(),...
    'CData', obj.GUIData.DocButton,...
    'TooltipString', 'Documentation wiki');
% Create text labels
if ispc
    cfgXpos = 740; movPos = 345; sessPos = 735;
elseif ismac
    cfgXpos = 745; movPos = 360; sessPos = 741;
else
    cfgXpos = 735; movPos = 345; sessPos = 731;
end
text(cfgXpos, 65,'Config', 'FontName', fontName, 'FontSize', med, 'Color', labelFontColor);
line([730 815], [79 79], 'Color', labelFontColor, 'LineWidth', 2);
text(movPos, 65,'Manual Override', 'FontName', fontName, 'FontSize', med, 'Color', labelFontColor);
line([145 718], [79 79], 'Color', labelFontColor, 'LineWidth', 2);
text(sessPos, 205,'Session', 'FontName', fontName, 'FontSize', med, 'Color', labelFontColor);
line([730 815], [220 220], 'Color', labelFontColor, 'LineWidth', 2);

% Create tabs.
% Tabs are implemented with buttons and panels instead of uitab to retain compatability with MATLAB r2013a - 2014a
pluginPanelWidth = 575;
pluginPanelOffset = 145;
nTabs = obj.HW.n.UartSerialChannels+1;
tabWidth = (pluginPanelWidth)/nTabs;
obj.GUIHandles.PanelButton = zeros(1,nTabs);
moduleNames = {'<html>&nbsp;State<br>Machine', 'Serial 1', 'Serial 2', 'Serial 3', 'Serial 4', 'Serial 5'};
formattedModuleNames = moduleNames;
tabPos = pluginPanelOffset;
obj.GUIData.DefaultPanel = ones(1,nTabs);
buttonFont = 'Courier New';
if ~ispc && ~ismac
    buttonFont = 'DejaVu Sans Mono';
end
for i = 1:nTabs
    % Set module names
    if i > 1
        if obj.Modules.Connected(i-1)
            thisModuleName = obj.Modules.Name{i-1};
            uCase = (thisModuleName > 64 & thisModuleName < 91);
            lCase = (thisModuleName > 96 & thisModuleName < 123);
            if sum(uCase) == 2 && length(uCase) > 5 && sum(lCase) > 0
                capPos = find(uCase);
                namePart1 = thisModuleName(1:capPos(2)-1);
                namePart2 = thisModuleName(capPos(2):end);
                bufferLength = 5-length(namePart2);
                if bufferLength < 1
                    bufferLength = 0;
                end
                buffer = ['<html>' repmat('&nbsp;', 1, bufferLength)];
                namePart2 = [buffer namePart2(1:end-1) ' ' namePart2(end)];
                formattedModuleNames{i} = ['<html>&nbsp;' namePart1 '<br>' namePart2];
            else
                thisModuleName = [thisModuleName(1:end-1) ' ' thisModuleName(end)];
                formattedModuleNames{i} = thisModuleName;
            end
        else
            thisModuleName = 'None';
        end
    end
    % Draw tab
    obj.GUIHandles.PanelButton(i) = uicontrol('Style', 'pushbutton',...
        'String', formattedModuleNames{i},...
        'Callback', @(h,e)obj.SwitchPanels(i),...
        'BackgroundColor', [0.37 0.37 0.37],...
        'Position', [tabPos 272 tabWidth-1 49],...
        'ForegroundColor', [0.9 0.9 0.9], ...
        'FontSize', vvsm,...
        'FontName', buttonFont);
    tabPos = tabPos + tabWidth;
    if isempty(strfind(obj.HostOS, 'Linux')) && ~verLessThan('matlab', '8.0.0') && verLessThan('matlab', '9.5.0')
        jButton = findjobj(obj.GUIHandles.PanelButton(i));
        jButton.setBorderPainted(false);
    end
    % Draw panel
    obj.GUIHandles.OverridePanel(i) = uipanel(obj.GUIHandles.MainFig, 'Units', 'Pixels',...
        'Position',[pluginPanelOffset,16,pluginPanelWidth,256],...
        'FontSize',12,...
        'BackgroundColor',[.38 .38 .38],...
        'HighlightColor', [0.4 0.4 0.4]);

    % Draw Axes
    obj.GUIHandles.OverridePanelAxes(i) = axes('Parent', obj.GUIHandles.OverridePanel(i),...
        'Position',[0 0 1 1],...
        'Color',[.37,.37,.37],...
        'Xlim', [0 pluginPanelWidth],...
        'Ylim', [0 250],...
        'UserData', 'PrimaryPanelAxes');
    axis off;
    uistack(obj.GUIHandles.OverridePanel(1),'top');
    if i == 1 % State machine panel
        switch obj.MachineType
            case 1
                StateMachinePanel_0_5; % This is a file in /Bpod/Functions/OverridePanels/
            case 2
                StateMachinePanel_0_7;
            case 3
                StateMachinePanel_2_0_0;
            case 4
                StateMachinePanel_2Plus;
        end
    else % Module panel
        % Find module panel function and draw panel, otherwise draw default panel
        if ~strcmp(thisModuleName, 'None')
            moduleTypeString = thisModuleName(1:end-1);
            moduleFileName = [moduleTypeString '_Panel.m'];
            if exist(moduleFileName, 'file')
                moduleFunctionName = [moduleTypeString '_Panel'];
                eval([moduleFunctionName '(obj.GUIHandles.OverridePanel(' num2str(i) '), ''' thisModuleName ''');']);
                obj.GUIData.DefaultPanel(i) = 0;
            else % No override panel function exists for module
                DefaultBpodModule_Panel(obj.GUIHandles.OverridePanel(i), obj.Modules.Name{i-1});
            end

        else % Module did not respond
            DefaultBpodModule_Panel(obj.GUIHandles.OverridePanel(i), obj.Modules.Name{i-1});
        end
    end
    drawnow;
    set(obj.GUIHandles.OverridePanel(i), 'Visible', 'off');
end
set (obj.GUIHandles.PanelButton(1), 'BackgroundColor', [0.45 0.45 0.45]); % Set first button active
set(obj.GUIHandles.OverridePanel(1), 'Visible', 'on');
obj.GUIData.CurrentPanel = 1;
axes(obj.GUIHandles.Console);
uistack(obj.GUIHandles.Console,'bottom');
if isempty(strfind(obj.HostOS, 'Linux'))
    % Draw lines between tabs
    tabPos = pluginPanelOffset;
    for i = 1:obj.HW.n.UartSerialChannels
        tabPos = tabPos + tabWidth;
        line([tabPos-1 tabPos-1], [82 130], 'Color', [0.45 0.45 0.45], 'LineWidth', 5);
    end
    if isempty(strfind(obj.HostOS, 'Linux')) && ~verLessThan('matlab', '8.0.0') && verLessThan('matlab', '9.5.0')
        for i = 1:obj.HW.n.UartSerialChannels+1
            jButton = findjobj(obj.GUIHandles.PanelButton(i));
            jButton.setBorderPainted(false);
        end
    end
end

% Setup state and event info display elements
if ispc
    infoDispFontSize = 9; infoDispBoxHeight = 20; portDispBoxHeight = 20; infoDispBoxWidth = 122; yPos = 268; xPos = 12;
elseif ismac
    infoDispFontSize = 12; infoDispBoxHeight = 22; portDispBoxHeight = 28; infoDispBoxWidth = 115; yPos = 264; xPos = 12;
else
    infoDispFontSize = 9; infoDispBoxHeight = 23; portDispBoxHeight = 23; infoDispBoxWidth = 128; yPos = 268; xPos = 10;
end

if obj.EmulatorMode == 1
    portString = 'EMULATOR';
else
    portString = obj.SerialPort.PortName;
end

obj.GUIHandles.CurrentStateDisplay = uicontrol('Style', 'text',...
    'String', '---',...
    'Position', [xPos yPos infoDispBoxWidth infoDispBoxHeight],...
    'FontWeight', 'bold',...
    'FontSize', infoDispFontSize);
yPos = yPos - 51;
obj.GUIHandles.PreviousStateDisplay = uicontrol('Style', 'text',...
    'String', '---',...
    'Position', [xPos yPos infoDispBoxWidth infoDispBoxHeight],...
    'FontWeight', 'bold',...
    'FontSize', infoDispFontSize);
yPos = yPos - 51;
obj.GUIHandles.LastEventDisplay = uicontrol('Style', 'text',...
    'String', '---',...
    'Position', [xPos yPos infoDispBoxWidth infoDispBoxHeight],...
    'FontWeight', 'bold',...
    'FontSize', infoDispFontSize);
yPos = yPos - 51;
obj.GUIHandles.TimeDisplay = uicontrol('Style', 'text',...
    'String', '0:00:00',...
    'Position', [xPos yPos infoDispBoxWidth infoDispBoxHeight],...
    'FontWeight', 'bold',...
    'FontSize', infoDispFontSize,...
    'TooltipString', 'Time in session, updated on each trial start');
yPos = yPos - 51;
obj.GUIHandles.USBPortDisplay = uicontrol('Style', 'text',...
    'String', portString,...
    'Position', [xPos yPos infoDispBoxWidth portDispBoxHeight],...
    'FontWeight', 'bold',...
    'FontSize', infoDispFontSize,...
    'TooltipString', 'The Bpod State Machine''s primary USB serial port');
obj.FixPushbuttons; % Removes button borders
text(15, 30, title, 'FontName', titleFontName, 'FontSize', lg, 'Color', titleColor);
line([220 780], [30 30], 'Color', labelFontColor, 'LineWidth', 4);
text(10, 102,'Current State', 'FontName', fontName, 'FontSize', vsm, 'Color', labelFontColor);
text(10, 153,'Previous State', 'FontName', fontName, 'FontSize', vsm, 'Color', labelFontColor);
text(10, 204,'Last Event', 'FontName', fontName, 'FontSize', vsm, 'Color', labelFontColor);
text(10, 255,'Session Time', 'FontName', fontName, 'FontSize', vsm, 'Color', labelFontColor);
text(10, 306,'Port', 'FontName', fontName, 'FontSize', vsm, 'Color', labelFontColor);
text(23, 65,'Live Info', 'FontName', fontName, 'FontSize', med, 'Color', labelFontColor);
line([10 130], [79 79], 'Color', labelFontColor, 'LineWidth', 2);

% Finish up
ver = BpodSoftwareVersion_Semantic;
text(10, 376,['Console v' ver], 'FontName', fontName, 'FontSize', vsm, 'Color', [0.8 0.8 0.8]);
drawnow;
if obj.IsOnline == 1
    if isfield(obj.SystemSettings, 'PhoneHome')
        if obj.SystemSettings.PhoneHome == 1 % Note: You are opted out by default
            %obj.BpodPhoneHome(0);
            % Sends installation metadata to the Sanworks secure server on load (see comments in BpodPhoneHome fcn below)
            % Disabled until server migration. -JS July 2018
        end
    else
        obj.PhoneHomeOpt_In_Out();
    end
end
set(obj.GUIHandles.MainFig, 'HandleVisibility', 'callback');
end