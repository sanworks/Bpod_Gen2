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

% FlexIOConfigGUI() launches a GUI to configure state machine onboard FlexIO
% channels as digital in, digital out, analog in or analog out.

function FlexIOConfigGUI

global BpodSystem % Import the global BpodSystem object

if isfield(BpodSystem.GUIHandles, 'FlexConfigFig') && ~verLessThan('MATLAB', '8.4') 
    if isgraphics(BpodSystem.GUIHandles.FlexConfigFig)
        figure(BpodSystem.GUIHandles.FlexConfigFig);
        return;
    end
end
if BpodSystem.MachineType < 4 
    error('Error: Flex I/O configuration requires State Machine r2+ or newer.');
end
BpodSystem.GUIHandles.FlexConfigFig = figure('Position',[600 400 500 200],'name','Flex I/O Config.',...
    'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
fontName = 'Courier New';
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
bg = imread('InputChannelConfig2.bmp');
image(bg); axis off;
channelTypeStrings = {'Digital In', 'Digital Out', 'Analog In', 'Analog Out', 'Disabled'};
BpodSystem.GUIHandles.FlexConfig1 = uicontrol('Style', 'popupmenu', 'String', channelTypeStrings, 'Position', [35 120 100 15],... 
    'Callback', @UpdateFlexConfig,'TooltipString', 'Select Channel Type', 'BackgroundColor', [0.5 0.5 0.5], 'FontSize', 12,... 
    'Value', BpodSystem.HW.FlexIO_ChannelTypes(1)+1);
BpodSystem.GUIHandles.FlexConfig2 = uicontrol('Style', 'popupmenu', 'String', channelTypeStrings, 'Position', [145 120 100 15],... 
    'Callback', @UpdateFlexConfig,'TooltipString', 'Select Channel Type', 'BackgroundColor', [0.5 0.5 0.5], 'FontSize', 12,... 
    'Value', BpodSystem.HW.FlexIO_ChannelTypes(2)+1);
BpodSystem.GUIHandles.FlexConfig3 = uicontrol('Style', 'popupmenu', 'String', channelTypeStrings, 'Position', [255 120 100 15],... 
    'Callback', @UpdateFlexConfig,'TooltipString', 'Select Channel Type', 'BackgroundColor', [0.5 0.5 0.5], 'FontSize', 12,... 
    'Value', BpodSystem.HW.FlexIO_ChannelTypes(3)+1);
BpodSystem.GUIHandles.FlexConfig4 = uicontrol('Style', 'popupmenu', 'String', channelTypeStrings, 'Position', [365 120 100 15],... 
    'Callback', @UpdateFlexConfig,'TooltipString', 'Select Channel Type', 'BackgroundColor', [0.5 0.5 0.5], 'FontSize', 12,... 
    'Value', BpodSystem.HW.FlexIO_ChannelTypes(4)+1);
text(130, 25, 'Flex I/O Config', 'FontName', fontName, 'FontSize', 16, 'Color', [0.8 0.8 0.8]);

function UpdateFlexConfig(~,~)
global BpodSystem % Import the global BpodSystem object
BpodFlexConfig = zeros(1,4);
BpodFlexConfig(1) = get(BpodSystem.GUIHandles.FlexConfig1, 'Value')-1;
BpodFlexConfig(2) = get(BpodSystem.GUIHandles.FlexConfig2, 'Value')-1;
BpodFlexConfig(3) = get(BpodSystem.GUIHandles.FlexConfig3, 'Value')-1;
BpodFlexConfig(4) = get(BpodSystem.GUIHandles.FlexConfig4, 'Value')-1;
BpodSystem.FlexIOConfig.channelTypes = BpodFlexConfig;
FlexIOConfig = BpodSystem.FlexIOConfig;
save(BpodSystem.Path.FlexConfig, 'FlexIOConfig');