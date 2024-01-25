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

% TotalRewardDisplay is a class to display the total liquid reward delivered.
% TotalRewardDisplay('init') - initializes a window that displays total reward
% TotalRewardDisplay('add', Amount) - updates the total reward display with
% a new reward, adding to the total amount (units = microliters).

function TotalRewardDisplay(varargin)

global BpodSystem % Import the global BpodSystem object

op = varargin{1};
if nargin > 1
    amountToAdd = varargin{2};
end
op = lower(op);
switch op
    case 'init'
        BpodSystem.PluginObjects.TotalRewardDelivered = 0;
        BpodSystem.ProtocolFigures.TotalRewardDisplay = figure('Position', [900 550 150 150],'name','Total Reward',...
            'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off', 'Color', [.6 .6 1]);
        BpodSystem.GUIHandles.TotalRewardDisplay = struct;
        BpodSystem.GUIHandles.TotalRewardDisplay.Label = uicontrol('Style', 'text', 'String', 'Total reward',... 
            'units', 'normalized', 'Position', [.15 .7 .7 .15], 'FontWeight', 'bold', 'FontSize', 16,...
            'FontName', 'Arial', 'BackgroundColor', [.7 .7 1]);
        BpodSystem.GUIHandles.TotalRewardDisplay.Amount = uicontrol('Style', 'text', 'String', ['0 ' char(181) 'l'],... 
            'units', 'normalized', 'Position', [.1 .25 .8 .25], 'FontSize', 24, 'FontName', 'Arial',...
            'BackgroundColor', [.7 .7 1]);
        
    case 'add'
        BpodSystem.PluginObjects.TotalRewardDelivered = BpodSystem.PluginObjects.TotalRewardDelivered + amountToAdd;
        if BpodSystem.PluginObjects.TotalRewardDelivered > 1000
            displayAmount = BpodSystem.PluginObjects.TotalRewardDelivered/1000;
            displayUnits = ' ml';
        else
            displayAmount = BpodSystem.PluginObjects.TotalRewardDelivered;
            displayUnits = [' ' char(181) 'l'];
        end
        set(BpodSystem.GUIHandles.TotalRewardDisplay.Amount, 'String', [num2str(displayAmount) displayUnits]);
end