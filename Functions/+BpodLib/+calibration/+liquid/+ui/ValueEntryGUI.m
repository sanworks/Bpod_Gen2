%{
The code we're trying to replicate
valveNames could be {'PA1_1', 'PA1_2', 'PA1_3', 'PA1_4', 'PA2_1', 'PA2_2', 'PA2_3', 'PA2_4'}

obj.GUIHandles.RunMeasurementsFig = figure('Position', [540 100 317 530],'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off', 'Name', 'Enter pending measurements');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('CuedMeasurementEntry.bmp');
image(BG); axis off;
obj.GUIHandles.CB1b = uicontrol('Style', 'edit', 'Position', [155 379 80 35], 'TooltipString', 'Enter liquid weight for valve 1', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
obj.GUIHandles.CB2b = uicontrol('Style', 'edit', 'Position', [155 336 80 35], 'TooltipString', 'Enter liquid weight for valve 2', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
obj.GUIHandles.CB3b = uicontrol('Style', 'edit', 'Position', [155 293 80 35], 'TooltipString', 'Enter liquid weight for valve 3', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
obj.GUIHandles.CB4b = uicontrol('Style', 'edit', 'Position', [155 250 80 35], 'TooltipString', 'Enter liquid weight for valve 4', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
obj.GUIHandles.CB5b = uicontrol('Style', 'edit', 'Position', [155 207 80 35], 'TooltipString', 'Enter liquid weight for valve 5', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
obj.GUIHandles.CB6b = uicontrol('Style', 'edit', 'Position', [155 164 80 35], 'TooltipString', 'Enter liquid weight for valve 6', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
obj.GUIHandles.CB7b = uicontrol('Style', 'edit', 'Position', [155 121 80 35], 'TooltipString', 'Enter liquid weight for valve 7', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
obj.GUIHandles.CB8b = uicontrol('Style', 'edit', 'Position', [155 78 80 35], 'TooltipString', 'Enter liquid weight for valve 8', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
MeasurementButtonGFX2 = imread('MeasurementEntryOkButtonBG.bmp');
obj.GUIHandles.EnterMeasurementButton2 = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [120 7 80 50], 'Callback', @(src, event) obj.AddCalMeasurements(), 'TooltipString', 'Enter measurement', 'CData', MeasurementButtonGFX2);
%}

classdef ValueEntryGUI < handle
properties
    GUIHandles
end
methods
    function obj = ValueEntryGUI(valveNames, okcallback)
        spacing = 43;
        figheight = 530;
        figheight = 151 + spacing * numel(valveNames) + 20;
        figwidth = 317;
        startY = figheight - 151;

        obj.GUIHandles.RunMeasurementsFig = figure('Position', [540 100 figwidth figheight],'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off', 'Name', 'Enter pending measurements');
        ha = axes('units','normalized', 'position',[0 0 1 1]);
        hold(ha, 'on')
        % set axes background color
%         ha.Color = [0.2627 0.2627 0.2627];
        % set figure background color
        set(obj.GUIHandles.RunMeasurementsFig, 'Color', [0.2627 0.2627 0.2627]);
        axis(ha, 'off')
        uistack(ha,'bottom');
        obj.GUIHandles.axes = ha;

%         BG = imread('CuedMeasurementEntry.bmp');
        
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
        

        for idx = 1:numel(valveNames)
            valveName = valveNames{idx};
            yposition = startY - (idx-1) * spacing;
            obj.GUIHandles.(valveName) = uicontrol('Style', 'edit', 'Position', [155 yposition 80 35], ...
                'TooltipString', sprintf('Enter liquid weight for %s', valveName), 'FontWeight', 'bold', ...
                'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
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
        for idx = 1:numel(pendingNames)
            valvename = pendingNames{idx};
            set(obj.GUIHandles.(valvename), 'BackgroundColor', [.6 .9 .6], 'Enable', 'on');
        end
    end
end
end