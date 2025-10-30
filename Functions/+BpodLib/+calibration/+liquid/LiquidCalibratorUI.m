% UI for liquid calibration
%
% GUIHandles
% ----------
% - MainFig: figure
% - ValveSelector: listbox
% - MeasurementSelector: listbox
% - AddMeasurementButton: pushbutton
% - RemoveMeasurementButton: pushbutton
% - CalibrationCurveAxes: axes
% - nPulsesEdit: edit
% - SuggestPointsButton: pushbutton

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

classdef LiquidCalibratorUI < handle
properties
    BpodSystem % for .GUIHandles and for running the RunRewardCal
    GUIHandles % struct with handles of all GUI objects
    ValveDataManager % handle object that manages valve data
    savePath % char: path to save liquid calibration data
    source % char : 'statemachine' | 'portarray'

    PendingMeasurements  % struct: the measurements to add to the data, indexed by valve name
    PendingRun
    Measurement2add
    CalibrationTargetRange
end

properties (Access = private)
    supportsHTMLTags % bool. MATLAB stopped supporting HTML in UI strings in r2025a
    nValvesToDisplay % int: The number of valves to display (matches target device(s).
end

methods
    function obj = LiquidCalibratorUI(varargin)
        % Create the LiquidCalibratorUI
        % 
        % :param ValveDataManager: the ValveDataManager object to use
        % :type ValveDataManager: BpodLib.calibration.liquid.ValveDataManagerClass
        % :param BpodSystem: the BpodSystem object to use
        % :type BpodSystem: BpodObject
        % :param savepath: Filepath to save liquid calibration to
        % :type savepath: char

        p = inputParser();
        p.addRequired('ValveDataManager'); % BpodSystem.CalibrationTables.LiquidCal
        p.addParameter('BpodSystem', []);
        p.addParameter('savepath', []);
        p.addParameter('source', 'unknown');
        p.addParameter('target', []);
        p.parse(varargin{:});

        % Configure support for HTML tags
        obj.supportsHTMLTags = true;
        if ~verLessThan('matlab', '25.1')
            obj.supportsHTMLTags = false;
        end

        % If BpodSystem is specified insert self into GUIHandles (for closing on EndBpod)
        if ~isempty(p.Results.BpodSystem)
            obj.BpodSystem = p.Results.BpodSystem;
            obj.BpodSystem.GUIHandles.LiquidCalibrator = obj;
        else
            obj.BpodSystem = [];
        end

        obj.ValveDataManager = p.Results.ValveDataManager;
        obj.savePath = p.Results.savepath;
        obj.PendingMeasurements = BpodLib.calibration.liquid.PendingMeasurementManager(obj.ValveDataManager);
        obj.source = p.Results.source;
        
        obj.CalibrationTargetRange = [2, 10]; % uL of liquid to calibrate
        switch p.Results.target
            case 'FSM_Onboard'
                nValves = obj.BpodSystem.HW.n.Ports;
            case 'PortArray'
                nValves = 0;
                for i = 1:obj.BpodSystem.Modules.nModules
                    if ~isempty(strfind(obj.BpodSystem.Modules.Name{i}, 'PA'))
                        nValves = nValves + obj.BpodSystem.Modules.nSerialEvents(i)/2;
                    end
                end
        end
        obj.nValvesToDisplay = nValves;
        ValveListboxString = obj.ValveDataManager.getValveNames();
        ValveListboxString = ValveListboxString(1:nValves);

        % Create the user interface
        obj.GUIHandles = struct();
        obj.GUIHandles.MainFig = figure('Position',[150 180 830 370],'name','Bpod liquid calibrator',...
            'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off', 'CloseRequestFcn', @(src,event) obj.close(), ...
            'Tag', 'BpodLiquidCal-Main');
        ha = axes('units','normalized', 'position',[0 0 1 1]);
        uistack(ha,'bottom');
        bgcolor = [0.2627 0.2627 0.2627];
        set(obj.GUIHandles.MainFig, 'Color', bgcolor);
        % BG = imread('RewardCalMain.bmp');
        % image(BG); 
        axis off;
        obj.GUIHandles.ValveSelector = uicontrol('Style', 'listbox',...
            'String', ValveListboxString, 'Position', [20 55 100 210], 'FontWeight', 'bold',...
            'FontUnits', 'Pixels', 'FontSize', 20, 'Callback', @(src,event) obj.DisplayValve(src, event));
        obj.GUIHandles.MeasurementSelector = uicontrol('Style', 'listbox',...
            'String', {'No measurements found'}, 'Position', [140 55 300 210], 'FontWeight', 'bold',...
            'FontUnits', 'Pixels', 'FontSize', 16);
        obj.GUIHandles.AddMeasurementButton = uicontrol('Style', 'pushbutton',...
            'Position', [445 230 30 30], 'Callback', @(src,event) obj.RequestPendingMeasurement(src, event));
        obj.GUIHandles.RemoveMeasurementButton = uicontrol('Style', 'pushbutton',...
            'Position', [445 185 30 30], 'Callback', @(src,event) obj.RemoveMeasurement(src,event));
        set(obj.GUIHandles.AddMeasurementButton, 'CData', imread('PlusButton.bmp'));
        set(obj.GUIHandles.RemoveMeasurementButton, 'CData', imread('MinusButton.bmp'));
        obj.GUIHandles.CalibrationCurveAxes = axes('Units', 'pixels', 'Position', [550 65 250 200]);
        set(gca, 'tickdir', 'out', 'box', 'off', 'fontsize', 12, 'fontname', 'arial', 'XColor', [1 1 1], 'YColor', [1 1 1]);
        xlabel('Valve time (ms)', 'fontsize', 14, 'color', [1 1 1]); ylabel('Liquid (ul)', 'fontsize', 14, 'color', [1 1 1]);
        obj.GUIHandles.nPulsesEdit = uicontrol('Style', 'edit',...
            'String', '100', 'Position', [360 15 80 30], 'FontSize', 14,...
            'TooltipString', 'Number of pulses per weight measurement (100-500)');
        obj.GUIHandles.nPulsesLabel = uicontrol('Style', 'text',...
            'String', '#Pulses to measure', 'Position', [65 15 300 30], 'FontSize', 18,...
            'BackgroundColor', 'none', 'ForegroundColor', 'white', 'FontName', 'FixedWidth');
        % -- Top bar
        styleargs = {'BackgroundColor', 'none', 'ForegroundColor', 'white',... 
            'FontName', 'FixedWidth', 'FontWeight', 'bold', 'FontSize', 17};
        obj.GUIHandles.SuggestPointsButton = uicontrol('Style', 'pushbutton',...
            'String', 'Suggest Points', styleargs{:},...
            'Position', [20 300 200 50], 'Callback', @(src,event) obj.SuggestPoints(src,event));
        % set(obj.GUIHandles.SuggestPointsButton, 'CData', imread('SuggestPoints.bmp'));
        obj.GUIHandles.MeasurePendingButton = uicontrol('Style', 'pushbutton',...
            'String', 'Measure Pending', styleargs{:},...
            'Position', [235 300 215 50], 'Callback', @(src,event) obj.PreRunPendingCheck(src,event));
        obj.GUIHandles.TestCurveButton = uicontrol('Style', 'pushbutton',...
            'String', 'Test Curve', styleargs{:},...
            'Position', [460 300 150 50], 'Callback', @(src,event) obj.TestSpecificAmount(src,event));
        
        % Is PortArray connected?
        arrayConnected = false;
        if ~isempty(obj.BpodSystem)
            moduleNames = obj.BpodSystem.Modules.Name;
            for x = 1:numel(moduleNames)
                if startsWith(moduleNames{x}, 'PA')
                    arrayConnected = true;
                    break
                end
            end
        end

        if arrayConnected || strcmp(obj.source, 'portarray')
            sourceList = {'State Machine', 'Port Array'};
        else
            sourceList = {'State Machine'};
        end

        % Determine what the current source is and set button to it
        if strcmp(obj.source, 'statemachine')
            buttonIndex = 1;
        elseif strcmp(obj.source, 'portarray')
            buttonIndex = 2;
        else
            error('BpodLib:LiquidCalibratorUI:InvalidSource', 'Source must be either ''statemachine'' or ''portarray''');
        end
        styleargs{end} = 12; % replace font size from styleargs with 12
        obj.GUIHandles.SourceSelection = uicontrol(obj.GUIHandles.MainFig, 'Style', 'popupmenu',...
            'String', sourceList,...
            'Position', [630 300 165 25], 'Callback', @(src,event) obj.SwapSource,...
            styleargs{:});
        obj.GUIHandles.SourceSelection.Value = buttonIndex;

        uicontrol('Style', 'text', 'String', 'Source:', 'Position', [630 325 160 25], styleargs{:});

        obj.DisplayValve()
    end

    function close(obj)
        % Close the UI
        try
            obj.CloseChildWindows();
            delete(obj.GUIHandles.MainFig);
        catch
        end
    end

    function delete(obj)
        obj.close()
    end

    function valveName = selectedValve(obj)
        % Get the name of the selected valve
        selectedValveIndex = get(obj.GUIHandles.ValveSelector, 'Value');
        allValveNames = obj.ValveDataManager.getValveNames();
        valveName = allValveNames{selectedValveIndex};
        % check against guihandle string
        if ~strcmp(valveName, obj.GUIHandles.ValveSelector.String{selectedValveIndex})
            error('Valve name mismatch')
        end
    end

    function saveFile(obj, varargin)
        % Save file
        saveFolder = fileparts(obj.savePath);
        if exist(saveFolder) ~= 7
            mkdir(saveFolder);
        end
        BpodLib.calibration.liquid.io.save(obj.ValveDataManager.createSaveData(), 'BpodSystem', obj.BpodSystem, 'filepath', obj.savePath, 'verbose', false)
    end

    function DisplayValve(obj, ~, ~)
        % Update the GUI to show a valve
        selectedValveIndex = get(obj.GUIHandles.ValveSelector, 'Value');
        allValveNames = obj.ValveDataManager.getValveNames();
        ValveToShowName = allValveNames{selectedValveIndex};
        % ValveToShowName = sprintf('Valve%i', selectedValveIndex);
        ValveData = obj.ValveDataManager.getValve(ValveToShowName);
        nMeasurements = length(ValveData.Durations);

        % -- Update measurement list
        ThisValveCalEntries = cell(1, 1);
        % Add existing calibration data to list
        if ~isempty(ValveData.Durations)
            for x = 1:nMeasurements
                Pad = '';
                if ValveData.Durations(x) < 100
                    Pad = [Pad '  '];
                end
                if ValveData.Durations(x) < 10
                    Pad = [Pad '  '];
                end
                ThisValveCalEntries{x} = [num2str(ValveData.Durations(x)) 'ms pulse ' Pad '=  ' num2str(ValveData.Amounts(x)) 'ul liquid'];
            end
        end

        % Add pending measurements to list
        PendingDurations = obj.PendingMeasurements.getValvePending(ValveToShowName);
        if ~isempty(PendingDurations)
            nPendingMeasurements = length(PendingDurations);
            prefix = '';
            suffix = '';
            if obj.supportsHTMLTags
                prefix = '<html><FONT COLOR="#ff0000">';
                suffix = '</FONT></html>';
            end
            for x = 1:nPendingMeasurements
                ThisValveCalEntries{end+1} = [prefix '*PENDING MEASUREMENT: '  num2str(PendingDurations(x)) 'ms' suffix];
            end
        end

        % If no measurements exist, add a message to the list
        if isempty(ThisValveCalEntries{1})
            ThisValveCalEntries{1} = 'No measurements found';
            set(obj.GUIHandles.MeasurementSelector, 'Value', 1)
        end

        % If selected entry index exceeds total entries, set current highlighted
        % entry to equal the last entry available
        SelectedEntry = get(obj.GUIHandles.MeasurementSelector,'Value');
        if SelectedEntry == 0 || nMeasurements == 0
            set(obj.GUIHandles.MeasurementSelector,'Value', 1)
        elseif SelectedEntry > nMeasurements
            set(obj.GUIHandles.MeasurementSelector,'Value', nMeasurements)
        end
        set(obj.GUIHandles.MeasurementSelector,'String',ThisValveCalEntries);

        % -- Update plot of calibration values and curve
        ValveData = obj.ValveDataManager.getValve(ValveToShowName);
        AxCalib = obj.GUIHandles.CalibrationCurveAxes;
        LineColor = [0 0 0];
        PointColor = [0 0 1];
        if IsMATLAB_DarkMode
            LineColor = [.5 .8 1];
            PointColor = [.4 .5 1];
        end
        if ~isempty(ValveData.Coeffs)
            Vector = polyval(ValveData.Coeffs,0:.1:150);
            % Plot the calibration curve
            plot(AxCalib,Vector, 0:.1:150, 'Color', LineColor, 'LineWidth', 1.5);
            hold(AxCalib, 'on');
            % Plot the real calibration points
            scatter(AxCalib, ValveData.Durations, ValveData.Amounts,... 
                    'LineWidth', 2, 'MarkerEdgeColor', PointColor);
            set(AxCalib, 'tickdir', 'out', 'box', 'off');
            Ymax = max(ValveData.Amounts)+.1*max(ValveData.Amounts);
            % Add pending measurement datapoints
            PendingDurations = obj.PendingMeasurements.getValvePending(ValveToShowName);
            if ~isempty(PendingDurations)
                nPendingMeasurements = length(PendingDurations);
                for y = 1:nPendingMeasurements
                    line([PendingDurations(y) PendingDurations(y)],[0 Ymax], 'Color', 'r',... 
                        'LineStyle', ':','Parent',obj.GUIHandles.CalibrationCurveAxes);
                end
            end
            if Ymax > 0
                set(AxCalib, 'YLim', [0 Ymax]);
            else
                set(AxCalib, 'YLim', [0 1]);
            end
            MaxPlot = max(ValveData.Durations) + min(ValveData.Durations);
            MaxPending = max(PendingDurations) + min(ValveData.Durations);
            MaxPlotX = max([MaxPlot MaxPending]);
            set(AxCalib, 'XLim', [0 MaxPlotX]);
            set(get(AxCalib, 'Ylabel'), 'String', 'Liquid (ul)', 'fontsize', 14, 'color', [1 1 1]);
            set(get(AxCalib, 'Xlabel'), 'String', 'Valve duration (ms)', 'fontsize', 14, 'color', [1 1 1]);
            hold(AxCalib, 'off');
        else
            % If there are no measured values make plot empty
            plot(AxCalib, 0, 0);
            set(AxCalib, 'xtick', [], 'ytick', []);
        end
        set(AxCalib, 'tickdir', 'out', 'box', 'off', 'fontsize', 12, 'fontname', 'arial', 'XColor', [1 1 1], 'YColor', [1 1 1]);
        xlabel(AxCalib, 'Valve time (ms)', 'fontsize', 14, 'color', [1 1 1]);
        ylabel(AxCalib, 'Liquid (ul)', 'fontsize', 14, 'color', [1 1 1]);
    end

    function RequestPendingMeasurement(obj, src, event)
        % Create a GUI for entering a pending measurement
        obj.GUIHandles.ValueEntryFig = figure('Position', [540 400 400 200],'numbertitle','off', 'MenuBar', 'none',... 
            'Resize', 'off', 'Tag', 'BpodLiquidCal-EnterPending');
        ha = axes('units','normalized', 'position',[0 0 1 1]);
        uistack(ha,'bottom');
        BG = imread('RewardCalEnterValue.bmp');
        image(BG); axis off;
        obj.GUIHandles.AmountEntry = uicontrol('Style', 'edit', 'String', '0', 'Position', [75 15 115 50], 'FontWeight', 'bold', 'FontSize', 20);
        CalOkButtonGFX = imread('CalOkButton.bmp');
        obj.GUIHandles.OkButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [250 15 80 50], 'Callback', @(src, event) obj.GetPendingMeasurementFromUser(), 'CData', CalOkButtonGFX, 'TooltipString', 'Confirm entry');
    end

    function GetPendingMeasurementFromUser(obj, ~, ~)
        % Get the value for liquid amount from the GUI window

        % -- Validate entered value
        ValueEntered_ms = get(obj.GUIHandles.AmountEntry, 'String');
        ValidEntry = 1;
        CandidateValue = str2double(ValueEntered_ms);
        if isnan(CandidateValue)
            ValidEntry = 0;
        elseif CandidateValue < 1
            ValidEntry = 0;
        elseif CandidateValue > 5000
            ValidEntry = 0;
        end
        if ValidEntry == 1
            Value2measure_ms = CandidateValue;
        else
            Value2measure_ms = NaN;
        end
        % todo: add error for invalid entry? currently it fails silently

        % -- Add user input into pending measurements
        valveName = obj.selectedValve();
        if ValidEntry
            try
                obj.PendingMeasurements.addPending(valveName, Value2measure_ms);
            catch ME
                if strcmp(ME.identifier, 'BpodLib:LiquidCalibration:ExistingDuration')
                    warndlg(['A measurement for ' num2str(str2double(get(obj.GUIHandles.AmountEntry, 'String'))) 'ms exists. Please delete it first.'], 'Error', 'modal');
                else
                    rethrow(ME);
                end
            end
        end
        obj.DisplayValve()

        close(obj.GUIHandles.ValueEntryFig);
    end

    function RemoveMeasurement(obj, varargin)
        valveName = obj.selectedValve();
        ThisValveCalEntries = get(obj.GUIHandles.MeasurementSelector,'String');
        if ~iscell(ThisValveCalEntries)
            TempEntry = ThisValveCalEntries;
            ThisValveCalEntries = cell(1,1);
            ThisValveCalEntries{1} = TempEntry;
        end
        SelectedEntry = get(obj.GUIHandles.MeasurementSelector,'Value');
        SelectedEntryText = ThisValveCalEntries{SelectedEntry};
        isPendingMeasurement = (SelectedEntryText(1) == '<' || SelectedEntryText(1) == '*');

        if isPendingMeasurement
            valuetext = strsplit(SelectedEntryText, 'ms');
            valuetext = strsplit(valuetext{1}, ' ');
            SelectedDuration = str2double(valuetext{end});
            assert(~isnan(SelectedDuration), 'BpodLib:LiquidCalibration:InvalidPendingMeasurement', 'Pending measurement not valid')
            obj.PendingMeasurements.removePending(valveName, SelectedDuration);
        else
            valuetext = strsplit(SelectedEntryText, 'ms');
            SelectedDuration = str2double(valuetext{1});
            assert(~isnan(SelectedDuration), 'BpodLib:LiquidCalibration:InvalidMeasurement', 'Measurement not valid')
            obj.ValveDataManager.getValve(valveName).removeMeasurement(SelectedDuration, 'duration', true);
            obj.saveFile()
        end

        obj.DisplayValve();
    end

    function PreRunPendingCheck(obj, varargin)
        % % Create a vector of measurements to test
        % todo: remove RunPending from properties
        
        % todo: use PendingMeasurements.getPending to build more informative message box

        % Check for pending measurements
        [valveNames, pulseDurations_ms] = obj.PendingMeasurements.getPending();
        if numel(valveNames) == 0 
            errordlg(['No pending measurements found.' char(10) 'Please add pending measurements and try again.'], 'Error')
            error('No pending measurements found. Please add pending measurements and try again.')
        end

        mb = msgbox('Please refill liquid reservoirs and click Ok to begin.', 'non-modal');
        okbutton = mb.findobj('Tag', 'OKButton');
        okbutton.Callback = @(~, ~) mbfunc(mb);
        obj.GUIHandles.OkButton = okbutton; % used in unit test user input simulation

        function mbfunc(mbox)
            close(mbox)
            obj.RunPendingMeasurements
        end

    end

    function RunPendingMeasurements(obj, varargin)
        % Deliver liquid
        [valveNames, pulseDurations_ms] = obj.PendingMeasurements.getPending();
        assert(numel(valveNames) > 0, 'There must be pending values to calibrate')
        Completed = BpodLib.calibration.liquid.RunRewardCalibration(obj.BpodSystem, str2double(get(obj.GUIHandles.nPulsesEdit, 'string')), valveNames, pulseDurations_ms / 1000, 'PulseInterval', .2);
        if Completed
            % -- Create GUI for entering measurements
            allValveNames = obj.PendingMeasurements.getValveNames();
            allValveNames = allValveNames(1:obj.nValvesToDisplay);
            EntryGUI = BpodLib.calibration.liquid.ui.ValueEntryGUI(allValveNames, @obj.AddCalMeasurements);
            EntryGUI.setPending(valveNames)
            obj.GUIHandles.ValueEntryGUI = EntryGUI;
            obj.GUIHandles.RunMeasurementsFig = EntryGUI.GUIHandles.RunMeasurementsFig;
        end
    end

    function AddCalMeasurements(obj, varargin)
        % todo: refactor this into ValueEntryGUI
        figure(obj.GUIHandles.RunMeasurementsFig);
        [pendingValves, pendingDurations_ms] = obj.PendingMeasurements.getPending();

        % -- Verify that all of the entries into the GUI are valid
        for x = 1:length(pendingValves)
            valveName = pendingValves{x};
            value = str2double(obj.GUIHandles.ValueEntryGUI.GUIHandles.(valveName).String);
            if isnan(value) || value < 0
                errordlg(['Invalid measurement entered for valve ' num2str(valveName)])
                return  % This exits out of the function, allowing user to modify the entered value before clicking okay again
            end
        end

        % -- Update the the new values
        for x = 1:length(pendingValves)
            valveName = pendingValves{x};
            pendingduration = pendingDurations_ms(x);
            recordedWeight = str2double(obj.GUIHandles.ValueEntryGUI.GUIHandles.(valveName).String);
            pulseWeight_ml = recordedWeight * 1000 / str2double(get(obj.GUIHandles.nPulsesEdit, 'string'));

            obj.PendingMeasurements.completeMeasurement(valveName, pendingduration, pulseWeight_ml);
            set(obj.GUIHandles.ValueEntryGUI.GUIHandles.(valveName), 'Enable', 'off', 'BackgroundColor', [.9 .9 .9]); % disable box now that value has been entered (protects against unexpected errors and multiple inputs)
        end

        obj.saveFile()
        obj.GUIHandles.msgbox = msgbox('Calibration files updated.', 'non-modal');
        close(obj.GUIHandles.RunMeasurementsFig);
        obj.DisplayValve();
    end
    
    function SuggestPoints(obj, varargin)
        if isfield(obj.GUIHandles, 'RecommendedMeasureFig')
            % todo: a bit of a weird pattern, should figure what to make the standard
            if obj.GUIHandles.RecommendedMeasureFig.focus()
                return
            end
        end
        obj.GUIHandles.RecommendedMeasureFig = BpodLib.calibration.liquid.ui.SuggestPointsGUI(obj.ValveDataManager,... 
            obj.BpodSystem, obj.nValvesToDisplay, @obj.AddSuggestedPoints);
        obj.GUIHandles.RecommendedMeasureFig.setRange(obj.CalibrationTargetRange(1), obj.CalibrationTargetRange(2));

        valveNamesSet = obj.ValveDataManager.getValveNames();
        for iValve = 1:numel(valveNamesSet)
            valveName = valveNamesSet{iValve};
            if ~isempty(obj.ValveDataManager.getValve(valveName).Durations)
                obj.GUIHandles.RecommendedMeasureFig.GUIHandles.(valveName).Value = 1;
            end
        end
    end

    function AddSuggestedPoints(obj, varargin)
        LiquidCal = obj.ValveDataManager;
        CalPending = obj.PendingMeasurements;
        targetValveNameSet = obj.GUIHandles.RecommendedMeasureFig.getRequestedValves();

        [RangeLow, RangeHigh] = obj.GUIHandles.RecommendedMeasureFig.getRange();

        % Sanity check RangeLow and RangeHigh
        InvalidParams = 0;
        if isnan(RangeLow)
            InvalidParams = 1;
        else
            if (RangeLow < 1) || (RangeLow > 1000)
                InvalidParams = 1;
            end
        end
        if isnan(RangeHigh)
            InvalidParams = 1;
        else
            if (RangeHigh < 1) || (RangeHigh > 1000) || (RangeHigh < RangeLow)
                InvalidParams = 1;
            end
        end
        if InvalidParams == 1
            if (RangeHigh == 0) || (RangeLow == 0)
                warndlg('Range minimum and maximum must be non-zero.', 'Error', 'modal');
            else
                warndlg('Invalid range entered.', 'Error', 'modal');
            end
            return
        end

        % Add suggested points to pending measurements
        for valveIndex = 1:numel(targetValveNameSet)
            valveName = targetValveNameSet{valveIndex};
            SuggestedValveDuration = BpodLib.calibration.liquid.utils.suggestDuration(LiquidCal.getValve(valveName), RangeLow, RangeHigh);
            SuggestedValveDuration = round(SuggestedValveDuration); % required b/c durations are assumed integers in ui code
            try
                CalPending.addPending(valveName, SuggestedValveDuration)
            catch ME
                % If the duration already exists, skip it
                if ~strcmp(ME.identifier, 'BpodLib:LiquidCalibration:ExistingDuration')
                    rethrow(ME);
                end
            end

        end
        obj.CalibrationTargetRange = [RangeLow RangeHigh]; % Update cal range to what was in GUI
        close(obj.GUIHandles.RecommendedMeasureFig);
        obj.DisplayValve();
    
    end

    function TestSpecificAmount(obj, varargin)
        if isfield(obj.GUIHandles, 'TestSpecificAmtFig')
            if obj.GUIHandles.TestSpecificAmtFig.focus()
                return
            end
        end
        obj.GUIHandles.TestSpecificAmtFig = BpodLib.calibration.liquid.ui.TestSpecificAmountGUI(obj.BpodSystem, obj.ValveDataManager, obj.nValvesToDisplay);
    end

    function SwapSource(obj)
        % Swap between state machine and port array calibrations
        selectedSource = obj.GUIHandles.SourceSelection.String{obj.GUIHandles.SourceSelection.Value}; % retrieve the selected source before closing the current GUI
        originalPosition = obj.GUIHandles.MainFig.Position; % save current position to restore later
        % Close any GUI windows configured for previous source
        obj.close()
        % Determine what source was selected
        if strcmp(selectedSource, 'State Machine')
            BpodLib.calibration.liquid.launchLiquidCalibrationUI(obj.BpodSystem);
        elseif strcmp(selectedSource, 'Port Array')
            if isempty(obj.BpodSystem.CalibrationTables.PortArrays)
                BpodLib.calibration.liquid.portarray.initialize(obj.BpodSystem);
                BpodLib.calibration.liquid.portarray.launchCalibrator(obj.BpodSystem)
            else
                BpodLib.calibration.liquid.portarray.launchCalibrator(obj.BpodSystem)
            end
        else
            error('BpodLib:LiquidCalibration:UnknownSource', 'Unknown source selected: %s', selectedSource);
        end

        BpodLib.ui.alignWindow(obj.BpodSystem.GUIHandles.LiquidCalibrator.GUIHandles.MainFig, originalPosition)
    end

    function CloseChildWindows(obj)
        if isfield(obj.GUIHandles, 'TestSpecificAmtFig')
            try
                obj.GUIHandles.TestSpecificAmtFig.close();
            catch
            end
        end
        if isfield(obj.GUIHandles, 'RecommendedMeasureFig')
            try
                obj.GUIHandles.RecommendedMeasureFig.close();
            catch
            end
        end
        if isfield(obj.GUIHandles, 'RunMeasurementsFig')
            try
                close(obj.GUIHandles.RunMeasurementsFig);
            catch
            end
        end
    end

end

end