% Window for users to select valves to create duration suggestions for

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

classdef SuggestPointsGUI < handle

    properties
        GUIHandles
        valveNames
        callbackfunc
    end

    methods
        function obj = SuggestPointsGUI(LiquidCal, BpodSystem, nValvesToDisplay, okcallback)
            % obj = SuggestPointsGUI(LiquidCal, okcallback)

            valveNames = LiquidCal.getValveNames();
            valveNames = valveNames(1:nValvesToDisplay);
            obj.valveNames = valveNames;

            obj.GUIHandles = struct();
            buttonSpacing = 30;
            figheight = 70 + numel(valveNames) * buttonSpacing + 85;
            figwidth = 213;
            fig = figure('Position', [500, 400, figwidth, figheight], 'Resize', 'off', 'MenuBar', 'none',...
                'numbertitle', 'off', 'Tag', 'BpodLiquidCal-SuggestPoints');
            obj.GUIHandles.Figure = fig;

            ax = axes('units','normalized', 'position',[0 0 1 1]); % axes fill figures at end of initialisation with full size
            bgcolor = [0.2627 0.2627 0.2627];
            set(obj.GUIHandles.Figure, 'Color', bgcolor);
            textargs = {'FontSize', 14, 'FontWeight', 'bold', 'Color', 'w', 'Interpreter', 'none', 'FontName', 'FixedWidth'};
            obj.GUIHandles.ax = ax;
            uistack(ax,'bottom');
            axis off;

            % -- Create heading text
            text(ax, 5, figheight - 15, 'Calibration range:', textargs{:})
            ypos = figheight - 60;
            obj.GUIHandles.LowRangeEdit = uicontrol('Style', 'edit', 'String', '2', 'Position', [21 ypos 35 30], 'FontWeight', 'bold', 'FontSize', 12, 'TooltipString', 'Enter a non-zero value for range minimum');
            obj.GUIHandles.HighRangeEdit = uicontrol('Style', 'edit', 'String', '10', 'Position', [121 ypos 35 30], 'FontWeight', 'bold', 'FontSize', 12, 'TooltipString', 'Enter a non-zero value for range maximum');
            text(ax, 61, ypos + 10, 'ul -', 'VerticalAlignment', 'baseline',textargs{:})
            text(ax, 161, ypos + 10, 'ul', 'VerticalAlignment', 'baseline',textargs{:})

            % -- Create the valve entry buttons
            for idx = 1:numel(valveNames)
                ypos = figheight - idx * buttonSpacing - 70;
                valveName = valveNames{idx};
                obj.GUIHandles.(valveName) = uicontrol('Style', 'checkbox', 'Position', [55 ypos 15 15]);
                text(ax, 90, ypos, valveName, 'VerticalAlignment', 'baseline', textargs{:})
            end

            % -- Okay button
            ypos = ypos - buttonSpacing - 35;
            obj.callbackfunc = okcallback;
            obj.GUIHandles.SuggestButton = uicontrol('Style', 'pushbutton', 'String', 'Okay', 'Position', [48 ypos 120 50], 'Callback', okcallback, 'TooltipString', 'Confirm', 'BackgroundColor', bgcolor, 'ForegroundColor', 'white', 'FontName', 'FixedWidth', 'FontWeight', 'bold', 'FontSize', 12);
            rectangle(ax, 'Position', [10 10 figwidth-20 figheight-80], 'linewidth', 1.5, 'EdgeColor', 'w', 'Curvature', 0.3)
            % -- Finalise axis limits to make align with pixels
            ax.XLim = [0 figwidth];
            ax.YLim = [0 figheight];
        end

        function callback(obj)
            obj.callbackfunc()
        end

        function result = focus(obj)
            result = BpodLib.ui.raise(obj);
        end

        function close(obj)
            close(obj.GUIHandles.Figure);
        end

        function setRange(obj, low, high)
            % Set the range values in the GUI
            set(obj.GUIHandles.LowRangeEdit, 'String', num2str(low));
            set(obj.GUIHandles.HighRangeEdit, 'String', num2str(high));
        end

        function [rangeLow, rangeHigh] = getRange(obj)
            rangeLow = str2double(get(obj.GUIHandles.LowRangeEdit, 'String'));
            rangeHigh = str2double(get(obj.GUIHandles.HighRangeEdit, 'String'));
        end

        function requestedValves = getRequestedValves(obj)
            % Get the valves selected in the GUI
            valveLogic = false(numel(obj.valveNames), 1);
            for idx = 1:numel(obj.valveNames)
                valveName = obj.valveNames{idx};
                valveLogic(idx) = get(obj.GUIHandles.(valveName), 'Value');
            end
            requestedValves = obj.valveNames(valveLogic);
        end

    end
end

