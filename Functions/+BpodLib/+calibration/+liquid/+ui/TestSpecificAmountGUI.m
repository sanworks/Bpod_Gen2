% Window for users to test whether their liquid calibration is accurate.

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

classdef TestSpecificAmountGUI < handle
properties
    BpodSystem
    GUIHandles
    LiquidCal
    valveNamesSet

    hasRun
    testDuration
end

methods
    function obj = TestSpecificAmountGUI(BpodSystem, LiquidCal)
        % obj = TestSpecificAmountGUI(BpodSystem, LiquidCal)

        obj.BpodSystem = BpodSystem;
        obj.LiquidCal = LiquidCal;
        obj.GUIHandles = struct();
        valveNamesSet = LiquidCal.getValveNames();
        obj.valveNamesSet = valveNamesSet;
        obj.hasRun = false;

        %% -- Create GUI
        buttonSpacing = 30;
        figheight = 137 + numel(valveNamesSet) * buttonSpacing + 190;
        figwidth = 400;
        fig = figure('Position', [500, 400, figwidth, figheight], 'Resize', 'off', 'MenuBar', 'none',... 
            'numbertitle', 'off', 'Tag', 'BpodLiquidCal-TestAmount');
        obj.GUIHandles.Figure = fig;

        ax = axes('units','normalized', 'position',[0 0 1 1]); % axes fill figures at end of initialisation with full size
        bgcolor = [0.2627 0.2627 0.2627];
        set(obj.GUIHandles.Figure, 'Color', bgcolor);
        textargs = {'FontSize', 14, 'FontWeight', 'bold', 'Color', 'w', 'Interpreter', 'none', 'FontName', 'FixedWidth'};
        obj.GUIHandles.ax = ax;
        uistack(ax,'bottom');
        axis off;

        % -- Parameter box
        bgColor = [.9 .9 .9];
        if IsMATLAB_DarkMode
            bgColor = [.2 .2 .2];
        end
        ypos = figheight;
        textstep = 29;
        boxpad = 3;
        xpos = 300;

        ypos = ypos - 20;
        text(ax, 200, ypos, 'Parameters', textargs{:}, 'HorizontalAlignment', 'center')

        ypos = ypos - textstep - 10;
        text(ax, xpos, ypos, 'Amount to test (uL):', textargs{:}, 'HorizontalAlignment', 'right',... 
            'VerticalAlignment', 'bottom')
        obj.GUIHandles.SpecificAmtEdit = uicontrol('Style', 'edit', 'String', '10',... 
            'Position', [xpos+boxpad ypos 65 25], 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', bgColor);

        ypos = ypos - textstep;
        text(ax, xpos, ypos, 'Number of pulses:', textargs{:}, 'HorizontalAlignment', 'right',... 
            'VerticalAlignment', 'bottom')
        obj.GUIHandles.nPulsesDropmenu = uicontrol('Style', 'popupmenu', 'String', {'100' '200' '300' '400' '500'},... 
            'Position', [xpos+boxpad ypos 65 25], 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', bgColor,... 
            'TooltipString', 'Use more pulses with small water volumes for improved accuracy');

        ypos = ypos - textstep;
        text(ax, xpos, ypos, 'Measure tolerance (%):', textargs{:}, 'HorizontalAlignment', 'right',...
            'VerticalAlignment', 'bottom')
        obj.GUIHandles.ToleranceDropmenu = uicontrol('Style', 'popupmenu', 'String', {'5' '10'},... 
            'Position', [xpos+boxpad ypos 65 25], 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', bgColor, 'TooltipString', 'Percent of intended amount by which measured amount can differ');
        
        ypos = ypos - 20;
        parameter_lower = ypos;
        rectangle(ax, 'Position', [10 ypos figwidth - 20 figheight - 10 - ypos], 'linewidth', 1.5,... 
            'EdgeColor', 'w', 'Curvature', 0.1)
        % disp(figheight - parameter_lower) % = 137 (this is the height of the parameter box)
        
        % -- Check box
        ypos = parameter_lower - 25;
        checkhead = ypos;
        text(ax, 200, ypos, 'Check', textargs{:}, 'HorizontalAlignment', 'center')

        ypos = figheight - 180; % refer to figheight - parameter_lower to find good spacing
        tipargs = {'FontSize', 8, 'FontName', 'FixedWidth', 'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold'};
        text(ax, 110 + 20 + 15/2, ypos, 'Active', tipargs{:})
        text(ax, 130 + 20 + 40 + 30, ypos, 'Measured (g)', tipargs{:})
        text(ax, 130 + 20 + 40 + 30 + 90, ypos, 'Result', tipargs{:})
        for idx = 1:numel(valveNamesSet)
            ypos = ypos - buttonSpacing;
            valveName = valveNamesSet{idx};
            xpos = 110;
            obj.GUIHandles.(valveName).name = text(ax, xpos, ypos, valveName, 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right', textargs{:});
            xpos = xpos + 20;
            obj.GUIHandles.(valveName).checkbox = uicontrol('Style', 'checkbox', 'Position', [xpos ypos+5 15 15], 'Tooltip', 'Tick to deliver test pulses to this valve');
            xpos = xpos + 50;
            obj.GUIHandles.(valveName).entrybox = uicontrol('Style', 'edit', 'Position', [xpos, ypos, 80, 25], 'Tooltip', 'Enter weighed value', 'FontWeight', 'bold', 'FontSize', 12);
            xpos = xpos + 90;
            obj.GUIHandles.(valveName).resultbox = text(ax, xpos, ypos, '', 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left', textargs{:}, 'Tag', valveName);

            % Set uicontrol active levels based on whether there are enough measurements to estimate the valve time
            valveobject = LiquidCal.getValve(valveName);
            if isempty(valveobject.Durations)
                obj.GUIHandles.(valveName).checkbox.Enable = 'off';
                obj.GUIHandles.(valveName).entrybox.Enable = 'off';
                obj.GUIHandles.(valveName).resultbox.String = 'No data';
                obj.GUIHandles.(valveName).resultbox.Color = [0.5 0.5 0.5];
                obj.GUIHandles.(valveName).name.Color = [0.5 0.5 0.5];
            else
                obj.GUIHandles.(valveName).checkbox.Enable = 'on';
                obj.GUIHandles.(valveName).entrybox.Enable = 'off';
                obj.GUIHandles.(valveName).resultbox.String = 'Unknown';
            end

        end

        % Create buttons
        ypos = ypos - 60;
        buttonwidth = 250;
        obj.GUIHandles.RunButton = uicontrol('Style', 'pushbutton', 'String', 'Deliver test pulses', 'Position', [75 ypos buttonwidth 50], 'Callback', @(~,~) obj.runTests, 'TooltipString', 'Use state machine to deliver pulses to active valves', 'BackgroundColor', bgcolor, 'ForegroundColor', 'white', 'FontName', 'FixedWidth', 'FontWeight', 'bold', 'FontSize', 12);

        ypos = ypos - 70;
        obj.GUIHandles.CheckButton = uicontrol('Style', 'pushbutton', 'String', 'Calculate result', 'Position', [75 ypos buttonwidth 50], 'Callback', @(~, ~) obj.checkResults, 'TooltipString', 'Test whether measured amounts meet criteria and print to Command Window', 'BackgroundColor', bgcolor, 'ForegroundColor', 'white', 'FontName', 'FixedWidth', 'FontWeight', 'bold', 'FontSize', 12);

        rectangle(ax, 'Position', [10 10 figwidth-20 checkhead], 'linewidth', 1.5, 'EdgeColor', 'w', 'Curvature', 0.05)

        % -- Finalise axis limits to make align with pixels of figure
        ax.XLim = [0 figwidth];
        ax.YLim = [0 figheight];
    end

    function runTests(obj)
        nPulses =  str2double(obj.GUIHandles.nPulsesDropmenu.String{obj.GUIHandles.nPulsesDropmenu.Value});
        amount_uL = str2double(get(obj.GUIHandles.SpecificAmtEdit, 'String'));
        targetValveNamesSet =  obj.getTargetValves();

        if isempty(targetValveNamesSet)
            errordlg('No valves selected for testing. Please select at least one valve.')
            error('BpodLib:LiquidCalibration:NoValvesSelected', 'No valves selected for testing. Please select at least one valve.');
        end

        pulseDurations_s = nan(numel(targetValveNamesSet), 1);
        for iValve = 1:numel(targetValveNamesSet)
            valveName = targetValveNamesSet{iValve};
            duration_ms = obj.LiquidCal.getValve(valveName).getValveTime(amount_uL);
            pulseDurations_s(iValve) = duration_ms / 1000; % Convert ms to seconds
            obj.GUIHandles.(valveName).entrybox.Enable = 'on';
        end

        % Run the pulse delivery
        tic
        obj.hasRun = BpodLib.calibration.liquid.RunRewardCalibration(obj.BpodSystem, nPulses, targetValveNamesSet, pulseDurations_s);
        obj.testDuration = toc;

        % Update GUI
        nValves = numel(obj.valveNamesSet);
        for iValve = 1:nValves
            valveName = obj.valveNamesSet{iValve};
            isValid = ~isempty(obj.LiquidCal.getValve(valveName).Durations);
            isActive = obj.GUIHandles.(valveName).checkbox.Value;
            if obj.hasRun
                if isActive % pulses were given for these
                    obj.GUIHandles.(valveName).entrybox.Enable = 'on';
                    obj.GUIHandles.(valveName).resultbox.String = 'Pending';
                    obj.GUIHandles.(valveName).resultbox.Color = 'y';
                    obj.GUIHandles.(valveName).name.Color = 'w';
                elseif isValid && ~isActive % could have been given pulses but were not selected
                    obj.GUIHandles.(valveName).entrybox.Enable = 'off';
                    obj.GUIHandles.(valveName).resultbox.String = 'Unknown';
                    obj.GUIHandles.(valveName).resultbox.Color = [.7 .7 .7];
                    obj.GUIHandles.(valveName).name.Color = [.7 .7 .7];
                else %  no data available to calculate durations
                    obj.GUIHandles.(valveName).entrybox.Enable = 'off';
                    obj.GUIHandles.(valveName).resultbox.String = 'No data';
                    obj.GUIHandles.(valveName).resultbox.Color = [0.5 0.5 0.5];
                    obj.GUIHandles.(valveName).name.Color = [0.5 0.5 0.5];
                end
            end
        end
    end

    function checkResults(obj)
        % Check if results meet criteria, update GUI, and print results
        if ~obj.hasRun
            errordlg('Please run the test pulses first before checking results.', 'Error')
            error('BpodLib:LiquidCalibration:NoTestRun', 'Please run the test pulses first before checking results.');
        end

        % Print results into command window
        fprintf('Bpod liquid calibration (%s) %s\n', BpodLib.utils.getCurrentCOM(obj.BpodSystem), BpodLib.utils.isotime())
        fprintf('    Expected amount to dispense per pulse: %.3f uL\n', str2double(obj.GUIHandles.SpecificAmtEdit.String));
        fprintf('    Acceptable tolerance: %.2f%%\n', str2double(obj.GUIHandles.ToleranceDropmenu.String{obj.GUIHandles.ToleranceDropmenu.Value}));
        fprintf('    %d pulses delivered over %.2f seconds\n', str2double(obj.GUIHandles.nPulsesDropmenu.String{obj.GUIHandles.nPulsesDropmenu.Value}), obj.testDuration);

        % Check the results of the test pulses
        expectedAmount_uL = str2double(obj.GUIHandles.SpecificAmtEdit.String);
        expectedAmount_g = expectedAmount_uL * 0.001; % Convert uL to g (assuming density of water is 1 g/mL)
        nPulses = str2double(obj.GUIHandles.nPulsesDropmenu.String{obj.GUIHandles.nPulsesDropmenu.Value});
        toleranceFraction = str2double(obj.GUIHandles.ToleranceDropmenu.String{obj.GUIHandles.ToleranceDropmenu.Value}) / 100; % Convert percentage to fraction

        targetValveNamesSet = obj.getTargetValves();
        for iValve = 1:numel(targetValveNamesSet)
            valveName = targetValveNamesSet{iValve};
            measuredWeight_g = str2double(obj.GUIHandles.(valveName).entrybox.String);
            if isnan(measuredWeight_g)
                warning('No valid weight entered for valve %s. Skipping.', valveName);
                continue
            end

            measuredWeight_g_avg = measuredWeight_g / nPulses; % Average weight per pulse
            passed = abs(expectedAmount_g - measuredWeight_g_avg) <= toleranceFraction * expectedAmount_g;

            if passed
                obj.GUIHandles.(valveName).resultbox.String = 'PASS';
                obj.GUIHandles.(valveName).resultbox.Color = 'g';
            else
                obj.GUIHandles.(valveName).resultbox.String = 'FAIL';
                obj.GUIHandles.(valveName).resultbox.Color = 'r';
            end
            fprintf("Valve '%s' : Result = %s, Measured = %.3f uL\n", ...
                valveName, obj.GUIHandles.(valveName).resultbox.String, measuredWeight_g_avg * 1000); % Convert g to uL
        end
    end

    function targetValveNamesSet = getTargetValves(obj)
        % Get the target valves from the GUI
        valveNamesSet = obj.valveNamesSet;
        valveLogic = false(numel(valveNamesSet), 1);
        for idx = 1:numel(valveNamesSet)
            valveName = valveNamesSet{idx};
            valveLogic(idx) = obj.GUIHandles.(valveName).checkbox.Value;
        end
        targetValveNamesSet = valveNamesSet(valveLogic);
    end

    function result = focus(obj)
        result = BpodLib.ui.raise(obj);
    end
end
end