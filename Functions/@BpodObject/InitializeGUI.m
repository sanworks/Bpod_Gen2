%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2019 Sanworks LLC, Stony Brook, New York, USA

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
function obj = InitializeGUI(obj)
    TitleFontName = 'Courier New';
    FontName = 'Courier New';
    % Add labels
    LabelFontColor = [0.8 0.8 0.8];
    if 1 %obj.EmulatorMode == 0
        Title = 'Bpod Console';
        TitleColor = LabelFontColor;
    else
        Title = 'Bpod Emulator';
        TitleColor = [0.9 0 0];
    end
    if ispc
        Vvsm = 12; Vsm = 11; Sm = 12; Med = 13; Lg = 20;
    elseif ismac
        Vvsm = 12; Vsm = 14; Sm = 16; Med = 17; Lg = 22;
        FontName = 'Arial';
    else
        Vvsm = 10; Vsm = 10; Sm = 12; Med = 13; Lg = 20;
        FontName = 'DejaVu Sans Mono';
    end

    % add bpod name to window title
    FigTitle = 'Bpod Console';
    if ~strcmp(obj.Name, '')
        FigTitle = [FigTitle ': ' obj.Name];
    end
    obj.GUIHandles.MainFig = figure('Position',[80 100 825 400],'name',FigTitle,'numbertitle','off',...
        'MenuBar', 'none', 'Resize', 'off', 'CloseRequestFcn', 'EndBpod');
    obj.GUIHandles.Console = axes('units','normalized', 'position',[0 0 1 1]);
    uistack(obj.GUIHandles.Console,'bottom');
    BG = imread('ConsoleBG3.bmp');
    image(BG); axis off;

    obj.GUIData.GoButton = imread('PlayButton.bmp');
    obj.GUIData.PauseButton = imread('PauseButton.bmp');
    obj.GUIData.PauseRequestedButton = imread('PauseRequestedButton.bmp');
    obj.GUIData.StopButton = imread('StopButton.bmp');
    obj.GUIHandles.RunButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [742 100 60 60], 'Callback', 'RunProtocol(''StartPause'')', 'CData', obj.GUIData.GoButton, 'TooltipString', 'Launch behavior session');
    
    % check if protocol is running, set run button to pause
    if obj.Status.BeingUsed
        set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton, 'TooltipString', 'Press to pause session');
    end
    
    obj.GUIHandles.EndButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [742 20 60 60], 'Callback', 'RunProtocol(''Stop'')', 'CData', obj.GUIData.StopButton, 'TooltipString', 'End session');

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
    obj.GUIHandles.SettingsButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [778 275 29 29], 'Callback', 'BpodSettingsMenu', 'CData', obj.GUIData.SettingsButton, 'TooltipString', 'Settings and calibration');
    obj.GUIHandles.RefreshButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [733 275 29 29], 'Callback', @(h,e)obj.LoadModules(), 'CData', obj.GUIData.RefreshButton, 'TooltipString', 'Refresh modules');
    obj.GUIHandles.SystemInfoButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [778 227 29 29], 'Callback', 'BpodSystemInfo', 'CData', obj.GUIData.SystemInfoButton, 'TooltipString', 'View system info');
    obj.GUIHandles.USBButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [733 227 29 29], 'Callback', 'ConfigureModuleUSB', 'CData', obj.GUIData.USBButton, 'TooltipString', 'Configure module USB ports');
    obj.GUIHandles.DocButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [796 371 29 29], 'Callback', @(h,e)obj.Wiki(), 'CData', obj.GUIData.DocButton, 'TooltipString', 'Documentation wiki');
    if ispc
        CfgXpos = 740; Movpos = 345; Sesspos = 735;
    elseif ismac
        CfgXpos = 745; Movpos = 360; Sesspos = 741;
    else
        CfgXpos = 735; Movpos = 345; Sesspos = 731;
    end
    text(CfgXpos, 65,'Config', 'FontName', FontName, 'FontSize', Med, 'Color', LabelFontColor);
    line([730 815], [79 79], 'Color', LabelFontColor, 'LineWidth', 2);
    text(Movpos, 65,'Manual Override', 'FontName', FontName, 'FontSize', Med, 'Color', LabelFontColor);
    line([145 718], [79 79], 'Color', LabelFontColor, 'LineWidth', 2);
    text(Sesspos, 205,'Session', 'FontName', FontName, 'FontSize', Med, 'Color', LabelFontColor);
    line([730 815], [220 220], 'Color', LabelFontColor, 'LineWidth', 2);

    PluginPanelWidth = 575;
    PluginPanelOffset = 145;
    TabWidth = (PluginPanelWidth)/obj.HW.n.SerialChannels;
    obj.GUIHandles.PanelButton = zeros(1,obj.HW.n.SerialChannels);
    ModuleNames = {'<html>&nbsp;State<br>Machine', 'Serial 1', 'Serial 2', 'Serial 3', 'Serial 4', 'Serial 5'};
    FormattedModuleNames = ModuleNames;
    TabPos = PluginPanelOffset;
    obj.GUIData.DefaultPanel = ones(1,obj.HW.n.SerialChannels);
    
    ButtonFont = 'Courier New';
    if ~ispc && ~ismac 
        ButtonFont = 'DejaVu Sans Mono';
    end
    
    for i = 1:obj.HW.n.SerialChannels
        % Set module names
        if i > 1
            if obj.Modules.Connected(i-1)
                ThisModuleName = obj.Modules.Name{i-1};
                UCase = (ThisModuleName > 64 & ThisModuleName < 91);
                LCase = (ThisModuleName > 96 & ThisModuleName < 123);
                if sum(UCase) == 2 && length(UCase) > 5 && sum(LCase) > 0
                    CapPos = find(UCase);
                    NamePart1 = ThisModuleName(1:CapPos(2)-1);
                    NamePart2 = ThisModuleName(CapPos(2):end);
                    BufferLength = 5-length(NamePart2);
                    if BufferLength < 1
                        BufferLength = 0;
                    end
                    Buffer = ['<html>' repmat('&nbsp;', 1, BufferLength)];
                    NamePart2 = [Buffer NamePart2(1:end-1) ' ' NamePart2(end)];
                    FormattedModuleNames{i} = ['<html>&nbsp;' NamePart1 '<br>' NamePart2];
                else
                    ThisModuleName = [ThisModuleName(1:end-1) ' ' ThisModuleName(end)];
                    FormattedModuleNames{i} = ThisModuleName;
                end
            else
                ThisModuleName = 'None';
            end
        end
        % Draw tab
        obj.GUIHandles.PanelButton(i) = uicontrol('Style', 'pushbutton', 'String', FormattedModuleNames{i}, 'Callback', @(h,e)obj.SwitchPanels(i), 'BackgroundColor', [0.37 0.37 0.37], 'Position', [TabPos 272 TabWidth-1 49], 'ForegroundColor', [0.9 0.9 0.9], 'FontSize', Vvsm, 'FontName', ButtonFont);
        TabPos = TabPos + TabWidth;
        if isempty(strfind(obj.HostOS, 'Linux')) && ~verLessThan('matlab', '8.0.0') && verLessThan('matlab', '9.5.0')
            jButton = findjobj(obj.GUIHandles.PanelButton(i));
            jButton.setBorderPainted(false);
        end
        % Draw panel
        obj.GUIHandles.OverridePanel(i) = uipanel(obj.GUIHandles.MainFig, 'Units', 'Pixels', 'Position',[PluginPanelOffset,16,PluginPanelWidth,256],...
            'FontSize',12, 'BackgroundColor',[.38 .38 .38],...
            'HighlightColor', [0.4 0.4 0.4]);

        % Draw Axes
        obj.GUIHandles.OverridePanelAxes(i) = axes('Parent', obj.GUIHandles.OverridePanel(i), 'Position',[0 0 1 1], 'Color',[.37,.37,.37], 'Xlim', [0 PluginPanelWidth], 'Ylim', [0 250], 'UserData', 'PrimaryPanelAxes'); axis off;
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
            if ~strcmp(ThisModuleName, 'None')
                ModuleTypeString = ThisModuleName(1:end-1);
                ModuleFileName = [ModuleTypeString '_Panel.m'];
                if exist(ModuleFileName, 'file')
                    ModuleFunctionName = [ModuleTypeString '_Panel'];
                    eval([ModuleFunctionName '(obj.GUIHandles.OverridePanel(' num2str(i) '), ''' ThisModuleName ''');']);
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
        TabPos = PluginPanelOffset;
        for i = 1:obj.HW.n.SerialChannels-1
            TabPos = TabPos + TabWidth;
            line([TabPos-1 TabPos-1], [82 130], 'Color', [0.45 0.45 0.45], 'LineWidth', 5);
        end
        if isempty(strfind(obj.HostOS, 'Linux')) && ~verLessThan('matlab', '8.0.0') && verLessThan('matlab', '9.5.0')
            for i = 1:obj.HW.n.SerialChannels
                jButton = findjobj(obj.GUIHandles.PanelButton(i));
                jButton.setBorderPainted(false);
            end
        end
    end
    if ispc
        InfoDispFontSize = 9; InfoDispBoxHeight = 20; PortDispBoxHeight = 20; InfoDispBoxWidth = 115; Ypos = 268;
    elseif ismac
        InfoDispFontSize = 12; InfoDispBoxHeight = 22; PortDispBoxHeight = 28; InfoDispBoxWidth = 115; Ypos = 264;
    else
        InfoDispFontSize = 9; InfoDispBoxHeight = 23; PortDispBoxHeight = 23; InfoDispBoxWidth = 120; Ypos = 268;
    end
    
    if obj.EmulatorMode == 1
        PortString = 'EMULATOR';
    else
        PortString = obj.SerialPort.PortName;
    end

    obj.GUIHandles.CurrentStateDisplay = uicontrol('Style', 'text', 'String', 'None', 'Position', [12 Ypos InfoDispBoxWidth InfoDispBoxHeight], 'FontWeight', 'bold', 'FontSize', InfoDispFontSize); Ypos = Ypos - 51;
    obj.GUIHandles.PreviousStateDisplay = uicontrol('Style', 'text', 'String', 'None', 'Position', [12 Ypos InfoDispBoxWidth InfoDispBoxHeight], 'FontWeight', 'bold', 'FontSize', InfoDispFontSize); Ypos = Ypos - 51;
    obj.GUIHandles.LastEventDisplay = uicontrol('Style', 'text', 'String', 'None', 'Position', [12 Ypos InfoDispBoxWidth InfoDispBoxHeight], 'FontWeight', 'bold', 'FontSize', InfoDispFontSize); Ypos = Ypos - 51;
    obj.GUIHandles.TimeDisplay = uicontrol('Style', 'text', 'String', '0', 'Position', [12 Ypos InfoDispBoxWidth InfoDispBoxHeight], 'FontWeight', 'bold', 'FontSize', InfoDispFontSize); Ypos = Ypos - 51;
    obj.GUIHandles.USBPortDisplay = uicontrol('Style', 'text', 'String', PortString, 'Position', [12 Ypos InfoDispBoxWidth PortDispBoxHeight], 'FontWeight', 'bold', 'FontSize', InfoDispFontSize);
    obj.FixPushbuttons;
    text(15, 30, Title, 'FontName', TitleFontName, 'FontSize', Lg, 'Color', TitleColor);
    line([220 780], [30 30], 'Color', LabelFontColor, 'LineWidth', 4);

    text(10, 102,'Current State', 'FontName', FontName, 'FontSize', Vsm, 'Color', LabelFontColor);
    text(10, 153,'Previous State', 'FontName', FontName, 'FontSize', Vsm, 'Color', LabelFontColor);
    text(10, 204,'Last Event', 'FontName', FontName, 'FontSize', Vsm, 'Color', LabelFontColor);
    text(10, 255,'Trial-Start', 'FontName', FontName, 'FontSize', Vsm, 'Color', LabelFontColor);
    text(10, 306,'Port', 'FontName', FontName, 'FontSize', Vsm, 'Color', LabelFontColor);
    text(23, 65,'Live Info', 'FontName', FontName, 'FontSize', Med, 'Color', LabelFontColor);
    line([10 130], [79 79], 'Color', LabelFontColor, 'LineWidth', 2);
    Ver = BpodSoftwareVersion;
    text(10, 376,['Console v' sprintf('%3.2f', Ver)], 'FontName', FontName, 'FontSize', Vsm, 'Color', [0.8 0.8 0.8]);
    drawnow;
    if obj.IsOnline == 1
        if isfield(obj.SystemSettings, 'PhoneHome')
            if obj.SystemSettings.PhoneHome == 1 % Note: You are opted out by default
                %obj.BpodPhoneHome(0); % Disabled until server migration. -JS July 2018 % Sends installation metadata to the Sanworks secure server on load (see comments in BpodPhoneHome fcn below)
            end
        else
            obj.PhoneHomeOpt_In_Out();
        end
    end
    set(obj.GUIHandles.MainFig, 'HandleVisibility', 'callback');
end