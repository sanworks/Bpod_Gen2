classdef ValueEntryGUI < handle
properties
    GUIHandles
end
methods
    function obj = ValueEntryGUI(valveNames, okcallback)
        %ValueEntryGUI(valveNames, okcallback)
        % Create a GUI for entering pending measurements for liquid valves
        spacing = 43;
        figheight = 151 + spacing * numel(valveNames) + 20;
        figwidth = 317;
        startY = figheight - 151;

        obj.GUIHandles.RunMeasurementsFig = figure('Position', [540 100 figwidth figheight],'numbertitle','off',... 
            'MenuBar', 'none', 'Resize', 'off', 'Name', 'Enter pending measurements', 'Tag', 'BpodLiquidCal-EnterValue');
        ha = axes('units','normalized', 'position',[0 0 1 1]);
        hold(ha, 'on')
        set(obj.GUIHandles.RunMeasurementsFig, 'Color', [0.2627 0.2627 0.2627]);
        axis(ha, 'off')
        uistack(ha,'bottom');
        obj.GUIHandles.axes = ha;

        
        % Draw the input outline
        yupper = figheight - 60;
        ylower = 59;
        plot(ha, [5, figwidth - 5, figwidth - 5, 5, 5], [yupper, yupper, ylower, ylower, yupper], 'Color', 'w', 'linewidth', 1.5)
        

        textargs = {'FontSize', 14, 'FontWeight', 'bold', 'Color', 'w', 'Interpreter', 'none', 'FontName', 'FixedWidth'};
        text(ha, 50, figheight - 30, 'Enter measurements:', textargs{:})
        text(ha, 30, figheight - 80, 'Valve', textargs{:})
        text(ha, 120, figheight - 80, 'Liquid weight', textargs{:})
        MeasurementButtonGFX2 = imread('MeasurementEntryOkButtonBG.bmp');
        obj.GUIHandles.EnterMeasurementButton2 = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [120 7 80 50], 'Callback', @(src, event) okcallback(), 'TooltipString', 'Enter measurement', 'CData', MeasurementButtonGFX2);
        bgColor = [.9 .9 .9];
        fgColor = [0 0 0];
        if IsMATLAB_DarkMode
            bgColor = [.2 .2 .2];
            fgColor = [1 1 1];
        end

        for idx = 1:numel(valveNames)
            valveName = valveNames{idx};
            yposition = startY - (idx-1) * spacing;
            obj.GUIHandles.(valveName) = uicontrol('Style', 'edit', 'Position', [155 yposition 80 35], ...
                'TooltipString', sprintf('Enter liquid weight for %s', valveName), 'FontWeight', 'bold', ...
                'FontSize', 12,'ForegroundColor', fgColor, 'BackgroundColor', bgColor);
            obj.GUIHandles.(valveName).Enable = 'off';
            
            % Add text for each valve
            text(ha, 30, yposition + 17, valveName, 'HorizontalAlignment', 'left', textargs{:});
            text(ha, 240, yposition + 17, 'g', textargs{:});
        end
        ha.XLim = [0 figwidth];
        ha.YLim = [0 figheight];
    end

    function close(obj)
        % Close the GUI
        if ishandle(obj.GUIHandles.RunMeasurementsFig)
            close(obj.GUIHandles.RunMeasurementsFig);
        end
    end

    function setPending(obj, pendingNames)
        % Set the active valves that require value entry
        enabledColor = [.6 .9 .6];
        if IsMATLAB_DarkMode
            enabledColor = [.3 .6 .3];
        end
        for idx = 1:numel(pendingNames)
            valvename = pendingNames{idx};
            set(obj.GUIHandles.(valvename), 'BackgroundColor', enabledColor, 'Enable', 'on');
        end
    end
end
end