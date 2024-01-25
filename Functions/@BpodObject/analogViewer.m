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

% BpodObject.analogViewer() is an oscilloscope style GUI tool for viewing live analog data from
% the state machine's FlexIO channels (if equipped)
%
% Arguments:
% op (char array) must be one of:
%                                'init' to initialize the GUI
%                                'update', to update the viewer with new analog data
%                                'stepVoltsPerDiv' to change volts per division
%                                'stepTimePerDiv to change time per division
%                                'logStartStop to start or stop logging the analog data
%                                'setDC' to toggle DC offset subtraction
%                                'end' to close the GUI
% newData (uint16), new analog data processed by the 'update' op

function obj = analogViewer(obj, op, newData)

% Setup button characters
if verLessThan('MATLAB', '8.4') % Earlier versions of MATLAB did not support unicode on buttons
    upButtonChar = '<HTML>&#9650;';
    downButtonChar = '<HTML>&#9660;';
    recButtonChar = '<HTML>&bull;';
    zeroButtonChar = '<HTML>&#8767;';
    restoreDCChar = '=';
    stopButtonChar = '<HTML>&#9632;';
else
    upButtonChar = char(9650);
    downButtonChar = char(9660);
    recButtonChar = char(9210);
    zeroButtonChar = char(8767);
    restoreDCChar = char(9107);
    stopButtonChar = char(9632);
end

switch op
    case 'init' % Initialize the GUI
        % Ensure that FlexIO analog input channels exist
        if sum(obj.HW.FlexIO_ChannelTypes == 2) == 0 % If no FlexIO channels are configured as analog input
            BpodErrorDlg(['No FlexI/O channels are' char(10)...
                'configured as analog inputs.']); %#ok newline requires r2016b but Bpod supports back to r2013a
        end

        % Check for GUI already open
        if isfield(obj.GUIHandles, 'OscopeFig_Builtin')
            if ~isempty(obj.GUIHandles.OscopeFig_Builtin)
                figure(obj.GUIHandles.OscopeFig_Builtin);
                obj.GUIHandles.OSC.SweepPos = 1;
                obj.GUIHandles.OSC.nUpdates = 0;
                for ch = 1:obj.HW.n.FlexIO
                    set(obj.GUIHandles.OSC.OscopeDataLine(ch), 'Ydata', nan(1,obj.GUIHandles.OSC.nDisplaySamples*2));
                end
                return
            end
        end

        % Setup GUI vars
        oscBGColor = [0.55 0.55 0.55];
        lineColors = {[1 1 0], [0 1 1], [1 0.5 0], [0 1 0]};
        obj.GUIHandles.OSC = struct;
        obj.GUIHandles.OSC.nXDivisions = 12;
        obj.GUIHandles.OSC.nYDivisions = 8;
        obj.GUIHandles.OSC.VoltDivPos = 7;
        obj.GUIHandles.OSC.TimeDivPos = 3;
        obj.GUIHandles.OSC.VoltDivValues = [0.02 0.05 0.1 0.2 0.5 1 2 5];
        obj.GUIHandles.OSC.TimeDivValues = [0.05 0.1 0.2 0.5 1];
        obj.GUIHandles.OSC.nDisplaySamples = obj.FlexIOConfig.analogSamplingRate *...
            obj.GUIHandles.OSC.TimeDivValues(obj.GUIHandles.OSC.TimeDivPos) * obj.GUIHandles.OSC.nXDivisions;
        obj.GUIHandles.OSC.SweepPos = 1;
        obj.GUIHandles.OSC.DCmode = 0;
        obj.GUIHandles.OSC.DCOffset = zeros(1,obj.HW.n.FlexIO);
        obj.GUIHandles.OSC.sampleSum = zeros(1,obj.HW.n.FlexIO);
        obj.GUIHandles.OSC.nSamplesSummed = zeros(1,obj.HW.n.FlexIO);
        if isunix && ~ismac
            titleFontSize = 16;
            scaleFontSize = 14;
            subTitleFontSize = 12;
            lineEdge = 0.25;
            figHeight = 470;
            dropFontSize = 8;
        else
            titleFontSize = 18;
            scaleFontSize = 18;
            subTitleFontSize = 16;
            lineEdge = 0;
            figHeight = 500;
            dropFontSize = 10;
        end

        % Setup GUI elements
        obj.GUIHandles.OscopeFig_Builtin = figure('Name','Flex I/O Analog Viewer',...
            'NumberTitle','off',...
            'MenuBar','none',...
            'Color',oscBGColor,...
            'Position',[700,310,720,figHeight],...
            'CloseRequestFcn',@(h,e)obj.analogViewer('end', []));
        obj.GUIHandles.Plot = axes('units','pixels', 'position',[10 10 640 480], ...
            'box', 'off', 'tickdir', 'out', 'Color', [0.1 0.1 0.1]);
        set(gca, 'xlim', [0 obj.GUIHandles.OSC.nXDivisions], 'ylim', [-0.4 obj.GUIHandles.OSC.nYDivisions], 'ytick', [], 'xtick', []);

        obj.GUIHandles.VoltScaleUpButton = uicontrol('Style', 'pushbutton', 'String', upButtonChar, 'Position', [661 69 50 50],...
            'Callback',@(h,e)obj.analogViewer('stepVoltsPerDiv', 1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', titleFontSize,...
            'FontWeight', 'bold', 'TooltipString', 'Increase Volts/div');
        obj.GUIHandles.VoltScaleDnButton = uicontrol('Style', 'pushbutton', 'String', downButtonChar, 'Position', [661 9 50 50],...
            'Callback',@(h,e)obj.analogViewer('stepVoltsPerDiv', -1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', titleFontSize,...
            'FontWeight', 'bold', 'TooltipString', 'Decrease Volts/div');
        annotation('textbox',[.91 .1 .1 .2],'String','V/Div','EdgeColor','none', 'FontSize', 14, 'FontWeight', 'Bold');

        obj.GUIHandles.TimeScaleUpButton = uicontrol('Style', 'pushbutton', 'String', upButtonChar, 'Position', [661 224 50 50],...
            'Callback',@(h,e)obj.analogViewer('stepTimePerDiv', 1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', titleFontSize,...
            'FontWeight', 'bold', 'TooltipString', 'Increase time/div');
        obj.GUIHandles.TimeScaleDnButton = uicontrol('Style', 'pushbutton', 'String', downButtonChar, 'Position', [661 164 50 50],...
            'Callback',@(h,e)obj.analogViewer('stepTimePerDiv', -1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', titleFontSize,...
            'FontWeight', 'bold', 'TooltipString', 'Decrease time/div');
        annotation('textbox',[.91 .41 .1 .2],'String','s/Div','EdgeColor','none', 'FontSize', 14, 'FontWeight', 'Bold');

        obj.GUIHandles.RecordButton = uicontrol('Style', 'pushbutton', 'String', recButtonChar, 'Position', [661 415 50 50],...
            'Callback',@(h,e)obj.analogViewer('logStartStop', 0), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', titleFontSize,...
            'FontWeight', 'bold', 'ForegroundColor', [.7 0 0], 'TooltipString', 'Record to data file');
        annotation('textbox',[.915 .79 .1 .2],'String','Rec','EdgeColor','none', 'FontSize', 14, 'FontWeight', 'Bold');

        obj.GUIHandles.ZeroButton = uicontrol('Style', 'pushbutton', 'String', zeroButtonChar, 'Position', [661 322 50 50],...
            'Callback',@(h,e)obj.analogViewer('setDC', 0), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', 30,...
            'FontWeight', 'bold', 'ForegroundColor', [0 0 0], 'TooltipString', 'Subtract DC (in viewer only)');
        annotation('textbox',[.922 .6 .1 .2],'String','DC','EdgeColor','none', 'FontSize', 14, 'FontWeight', 'Bold');

        % Setup data containers
        interval = obj.GUIHandles.OSC.nXDivisions/obj.GUIHandles.OSC.nDisplaySamples;
        obj.GUIHandles.OSCData = struct;
        obj.GUIHandles.OSCData.Xdata = 0:interval:obj.GUIHandles.OSC.nXDivisions-interval;
        obj.GUIHandles.OSCData.Ydata = nan(obj.HW.n.FlexIO,obj.GUIHandles.OSC.nDisplaySamples);

        % Create oscilloscope grid lines
        for i = 1:obj.GUIHandles.OSC.nYDivisions-1
            obj.GUIHandles.OSC.GridXLines(i) = line([0,obj.GUIHandles.OSC.nXDivisions],[i,i], 'Color', [.3 .3 .3], 'LineStyle',':');
            if i == floor(obj.GUIHandles.OSC.nYDivisions/2)
                set(obj.GUIHandles.OSC.GridXLines(i), 'Color', [.6 .6 .6]);
            end
        end
        for i = 1:obj.GUIHandles.OSC.nXDivisions-1
            obj.GUIHandles.OSC.GridYLines(i) = line([i,i],[0,obj.GUIHandles.OSC.nYDivisions], 'Color', [.3 .3 .3], 'LineStyle',':');
            if i == floor(obj.GUIHandles.OSC.nXDivisions/2)
                set(obj.GUIHandles.OSC.GridYLines(i), 'Color', [.6 .6 .6]);
            end
        end
        for i = 1:obj.HW.n.FlexIO
            obj.GUIHandles.OSC.OscopeDataLine(i) = line([obj.GUIHandles.OSCData.Xdata,obj.GUIHandles.OSCData.Xdata],...
                [obj.GUIHandles.OSCData.Ydata(i,:),obj.GUIHandles.OSCData.Ydata(i,:)], 'Color', lineColors{i});
        end
        obj.GUIHandles.OSC.MaskLine = line([lineEdge,obj.GUIHandles.OSC.nXDivisions-lineEdge],[-0.2,-0.2], 'Color', [.2 .2 .2], 'LineWidth', 20);

        % Create GUI Text
        obj.GUIHandles.OSC.VDivText = text(0.2,-0.2, 'V/div: 2.0', 'Color', 'yellow', 'FontName', 'Courier New', 'FontSize', 12);
        obj.GUIHandles.OSC.TimeText = text(9.5,-0.2, 'Time 200.0ms', 'Color', 'yellow', 'FontName', 'Courier New', 'FontSize', 12);
        obj.GUIHandles.OSC.StatText = text(0.2,7.7, 'Stopped', 'Color', 'red', 'FontName', 'Courier New', 'FontSize', 12);
        obj.GUIHandles.OSC.RecStatText = text(10.2,7.7, '', 'Color', 'red', 'FontName', 'Courier New', 'FontSize', 12);

        % Configure GUI elements
        if obj.Status.BeingUsed
            set(obj.GUIHandles.RecordButton, 'Enable', 'off')
        end
        obj.GUIHandles.OSC.nUpdates = 0;
        if obj.Status.RecordAnalog
            set(obj.GUIHandles.OSC.RecStatText, 'String', 'Recording');
            set(obj.GUIHandles.RecordButton, 'String', stopButtonChar, 'ForegroundColor', [0 0 0]);
        end

        % Final tasks
        obj.Status.AnalogViewer = 1;
        drawnow;
        set(obj.GUIHandles.OscopeFig_Builtin, 'HandleVisibility', 'callback');

    case 'update' % Update is called by ProcessAnalogSamples() which is called periodically by timer object obj.Timers.AnalogTimer
        dataCh = 0;
        if obj.GUIHandles.OSC.nUpdates == 0
            set(obj.GUIHandles.OSC.StatText, 'String', 'Running', 'Color', 'green');
        end
        obj.GUIHandles.OSC.nUpdates = obj.GUIHandles.OSC.nUpdates + 1;
        currentVoltDivValue = obj.GUIHandles.OSC.VoltDivValues(obj.GUIHandles.OSC.VoltDivPos);
        maxVolts = currentVoltDivValue*(obj.GUIHandles.OSC.nYDivisions);
        halfMax = maxVolts/2;
        resetFlag = 0;
        for ch = 1:obj.HW.n.FlexIO
            if obj.HW.FlexIO_ChannelTypes(ch) == 2
                dataCh = dataCh + 1;
                nsThisCh = newData(dataCh,:);
                nNewSamples = length(nsThisCh);
                NSThisChVolts = ((double(nsThisCh)/4095)*5);
                obj.GUIHandles.OSC.sampleSum(ch) = obj.GUIHandles.OSC.sampleSum(ch) + sum(NSThisChVolts);
                obj.GUIHandles.OSC.nSamplesSummed(ch) = obj.GUIHandles.OSC.nSamplesSummed(ch) + length(NSThisChVolts);
                if obj.GUIHandles.OSC.DCmode
                    NSThisChVolts = NSThisChVolts - obj.GUIHandles.OSC.DCOffset(ch);
                else
                    NSThisChVolts(NSThisChVolts>maxVolts) = NaN;
                end
                nsThisChSamples = ((NSThisChVolts+halfMax)/maxVolts)*obj.GUIHandles.OSC.nYDivisions;
                if obj.GUIHandles.OSC.SweepPos == 1
                    obj.GUIHandles.OSCData.Ydata(ch,:) = NaN;
                    obj.GUIHandles.OSCData.Ydata(ch,1:nNewSamples) = nsThisChSamples;
                elseif obj.GUIHandles.OSC.SweepPos + nNewSamples > obj.GUIHandles.OSC.nDisplaySamples
                    obj.GUIHandles.OSCData.Ydata(ch,obj.GUIHandles.OSC.SweepPos:obj.GUIHandles.OSC.nDisplaySamples-1) =...
                        nsThisChSamples(1:(obj.GUIHandles.OSC.nDisplaySamples-obj.GUIHandles.OSC.SweepPos));
                    if obj.GUIHandles.OSC.DCmode
                        obj.GUIHandles.OSC.DCOffset(ch) = obj.GUIHandles.OSC.sampleSum(ch)/obj.GUIHandles.OSC.nSamplesSummed(ch);
                        obj.GUIHandles.OSC.sampleSum(ch)= 0;
                        obj.GUIHandles.OSC.nSamplesSummed(ch) = 0;
                    end
                    obj.GUIHandles.OSC.SweepPos = 1;
                    resetFlag = 1;
                else
                    obj.GUIHandles.OSCData.Ydata(ch,obj.GUIHandles.OSC.SweepPos:obj.GUIHandles.OSC.SweepPos+nNewSamples-1) = nsThisChSamples;
                end
                set(obj.GUIHandles.OSC.OscopeDataLine(ch), 'Ydata', [obj.GUIHandles.OSCData.Ydata(ch,:),obj.GUIHandles.OSCData.Ydata(ch,:)]);
            end
        end
        if ~resetFlag
            obj.GUIHandles.OSC.SweepPos = obj.GUIHandles.OSC.SweepPos + nNewSamples;
        end

    case 'stepVoltsPerDiv' % Set new volts per division
        newPos = obj.GUIHandles.OSC.VoltDivPos + newData;
        if (newPos > 0) && (newPos <= length(obj.GUIHandles.OSC.VoltDivValues))
            obj.GUIHandles.OSC.VoltDivPos = obj.GUIHandles.OSC.VoltDivPos + newData;
            obj.GUIHandles.OSC.SweepPos = 1;
            obj.GUIHandles.OSCData.Ydata = nan(obj.HW.n.FlexIO,obj.GUIHandles.OSC.nDisplaySamples);
            newVoltsDiv = obj.GUIHandles.OSC.VoltDivValues(newPos);
            if newVoltsDiv >= 1
                voltString = ['V/div: ' num2str(newVoltsDiv) '.0'];
            else
                voltString = ['mV/div: ' num2str(newVoltsDiv*1000) '.0'];
            end
            set(obj.GUIHandles.OSC.VDivText, 'String', voltString);
        end

    case 'stepTimePerDiv' % Set new time per division
        newPos = obj.GUIHandles.OSC.TimeDivPos + newData;
        if (newPos > 0) && (newPos <= length(obj.GUIHandles.OSC.TimeDivValues))
            obj.GUIHandles.OSC.TimeDivPos = obj.GUIHandles.OSC.TimeDivPos + newData;
            newTimeDivValue = obj.GUIHandles.OSC.TimeDivValues(obj.GUIHandles.OSC.TimeDivPos);
            nSamplesPerSweep = obj.FlexIOConfig.analogSamplingRate*newTimeDivValue*obj.GUIHandles.OSC.nXDivisions;
            interval = obj.GUIHandles.OSC.nXDivisions/(nSamplesPerSweep-1);
            obj.GUIHandles.OSCData.Xdata = 0:interval:obj.GUIHandles.OSC.nXDivisions;
            obj.GUIHandles.OSC.SweepPos = 1;
            obj.GUIHandles.OSCData.Ydata = nan(obj.HW.n.FlexIO,nSamplesPerSweep);
            for i = 1:obj.HW.n.FlexIO
                set(obj.GUIHandles.OSC.OscopeDataLine(i), 'XData', [obj.GUIHandles.OSCData.Xdata,obj.GUIHandles.OSCData.Xdata],...
                    'YData', [obj.GUIHandles.OSCData.Ydata(i,:),obj.GUIHandles.OSCData.Ydata(i,:)]);
            end
            obj.GUIHandles.OSC.nDisplaySamples = nSamplesPerSweep;

            newTimeDiv = obj.GUIHandles.OSC.TimeDivValues(newPos);
            if newTimeDivValue >= 1
                timeString = ['Time: ' num2str(newTimeDiv) '.00s'];
            else
                timeString = ['Time: ' num2str(newTimeDiv*1000) '.0ms'];
            end
            set(obj.GUIHandles.OSC.TimeText, 'String', timeString);
        end

    case 'logStartStop' % Toggle logging the analog data to the current analog data file
        switch obj.Status.RecordAnalog
            case 0
                obj.Status.RecordAnalog = 1;
                set(obj.GUIHandles.OSC.RecStatText, 'String', 'Recording');
                set(obj.GUIHandles.RecordButton, 'String', stopButtonChar, 'ForegroundColor', [0 0 0]);
            case 1
                obj.Status.RecordAnalog = 0;
                set(obj.GUIHandles.OSC.RecStatText, 'String', '');
                set(obj.GUIHandles.RecordButton, 'String', recButtonChar, 'ForegroundColor', [.7 0 0]);
        end

    case 'setDC' % Toggle the DC offset
        obj.GUIHandles.OSC.DCmode = 1-obj.GUIHandles.OSC.DCmode;
        if obj.GUIHandles.OSC.DCmode
            for ch = 1:obj.HW.n.FlexIO
                obj.GUIHandles.OSC.DCOffset(ch) = obj.GUIHandles.OSC.sampleSum(ch)/obj.GUIHandles.OSC.nSamplesSummed(ch);
                obj.GUIHandles.OSC.sampleSum(ch) = 0;
                obj.GUIHandles.OSC.nSamplesSummed(ch) = 0;
            end
            set(obj.GUIHandles.ZeroButton, 'String', restoreDCChar, 'TooltipString', 'Restore DC (in viewer only)');
        else
            set(obj.GUIHandles.ZeroButton, 'String', zeroButtonChar, 'TooltipString', 'Subtract DC (in viewer only)');
        end
        obj.GUIHandles.OSC.SweepPos = 1;

    case 'end' % Close the GUI
        obj.Status.AnalogViewer = 0;
        delete(obj.GUIHandles.OscopeFig_Builtin);
        obj.GUIHandles.OscopeFig_Builtin = [];
        if isfield(obj.GUIHandles, 'OSC')
            obj.GUIHandles = rmfield(obj.GUIHandles, 'OSC');
        end
end

end