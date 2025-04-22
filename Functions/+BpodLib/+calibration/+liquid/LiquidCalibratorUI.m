% UI for liquid calibration

%{
GUIHandles
----------
- MainFig: figure
- ValveSelector: listbox
- MeasurementSelector: listbox
- AddMeasurementButton: pushbutton
- RemoveMeasurementButton: pushbutton
- CalibrationCurveAxes: axes
- nPulsesEdit: edit
- SuggestPointsButton: pushbutton

%}

classdef LiquidCalibratorUI < handle
properties
    BpodSystem % for .GUIHandles and for running the RunRewardCal
    GUIHandles
    ValveDataManager
    savepath

    PendingMeasurements  % struct: the measurements to add to the data, indexed by valve name
    Measurement2add
    CalibrationTargetRange
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
        p.addParameter('savepath', [])
        p.parse(varargin{:});

        % If BpodSystem is specified insert self into GUIHandles (for closing on EndBpod)
        if ~isempty(p.Results.BpodSystem)
            obj.BpodSystem = p.Results.BpodSystem;
            obj.BpodSystem.GUIHandles.LiquidCalibrator = obj;
        else
            obj.BpodSystem = [];
        end

        obj.ValveDataManager = p.Results.ValveDataManager;
        obj.savepath = p.Results.savepath;
        
        obj.CalibrationTargetRange = [2, 10]; % uL of liquid to calibrate
        ValveListboxString = obj.ValveDataManager.getValveNames();
        obj.PendingMeasurements = struct();
        for i = 1:length(ValveListboxString)
            obj.PendingMeasurements.(ValveListboxString{i}) = [];
        end

        % Create the user interface
        obj.GUIHandles = struct();
        obj.GUIHandles.MainFig =  figure('Position',[150 180 830 370],'name','Bpod liquid calibrator','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off', 'CloseRequestFcn', @(src,event) obj.close());
        ha = axes('units','normalized', 'position',[0 0 1 1]);
        uistack(ha,'bottom');
        BG = imread('RewardCalMain.bmp');
        image(BG); axis off;
        obj.GUIHandles.ValveSelector = uicontrol('Style', 'listbox',...
            'String', ValveListboxString, 'Position', [20 55 100 210], 'FontWeight', 'bold',...
            'FontUnits', 'Pixels', 'FontSize', 20, 'Callback', @(src,event) obj.DisplayValve(src, event));
        obj.GUIHandles.MeasurementSelector = uicontrol('Style', 'listbox',...
            'String', {'No measurements found'}, 'Position', [140 55 300 210], 'FontWeight', 'bold',...
            'FontUnits', 'Pixels', 'FontSize', 16);
        obj.GUIHandles.AddMeasurementButton = uicontrol('Style', 'pushbutton',...
            'Position', [445 230 30 30], 'Callback', @(src,event) obj.AddPendingMeasurement(src, event));
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
        obj.GUIHandles.SuggestPointsButton = uicontrol('Style', 'pushbutton',...
            'Position', [20 300 250 50], 'Callback', @(src,event) obj.SuggestPoints(src,event));
        set(obj.GUIHandles.SuggestPointsButton, 'CData', imread('SuggestPoints.bmp'));
        obj.GUIHandles.MeasurePendingButton = uicontrol('Style', 'pushbutton',...
            'Position', [290 300 250 50], 'Callback', @(src,event) obj.RunPendingMeasurements(src,event));
        set(obj.GUIHandles.MeasurePendingButton, 'CData', imread('MeasurePending.bmp'));
        obj.GUIHandles.TestCurveButton = uicontrol('Style', 'pushbutton',...
            'Position', [560 300 250 50], 'Callback', @(src,event) obj.TestSpecificAmount(src,event));
        set(obj.GUIHandles.TestCurveButton, 'CData', imread('TestCurve.bmp'));
        obj.DisplayValve()
    end

    function close(obj)
        % Close the UI
        try
            delete(obj.GUIHandles.MainFig);
        catch
        end
    end

    function delete(obj)
        obj.close()
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
        if nMeasurements == 0
            if isempty(obj.PendingMeasurements.(ValveToShowName))
                ThisValveCalEntries{1} = 'No measurements found';
                set(obj.GUIHandles.MeasurementSelector, 'Value', 1)
            else
                for x = 1:length(obj.PendingMeasurements.(ValveToShowName))
                    ThisValveCalEntries{x} = ['<html><FONT COLOR="#ff0000">*PENDING MEASUREMENT: '  num2str(obj.PendingMeasurements.(ValveToShowName)(x)) 'ms</FONT></html>'];
                end
            end
        else
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
            if ~isempty(obj.PendingMeasurements.(ValveToShowName))
                for x = 1:length(obj.PendingMeasurements.(ValveToShowName))
                    ThisValveCalEntries{nMeasurements+x} = ['<html><FONT COLOR="#ff0000">*PENDING MEASUREMENT: '  num2str(obj.PendingMeasurements.(ValveToShowName)(x)) 'ms</FONT></html>'];
                end
            end
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
        if ~isempty(ValveData.Coeffs)
            Vector = polyval(ValveData.Coeffs,0:.1:150);
            % Plot the calibration curve
            plot(obj.GUIHandles.CalibrationCurveAxes,Vector, 0:.1:150, 'k-', 'LineWidth', 1.5);
            hold(obj.GUIHandles.CalibrationCurveAxes, 'on');
            % Plot the real calibration points
            scatter(obj.GUIHandles.CalibrationCurveAxes, ValveData.Durations, ValveData.Amounts, 'LineWidth', 2);
            set(obj.GUIHandles.CalibrationCurveAxes, 'tickdir', 'out', 'box', 'off');
            Ymax = max(ValveData.Amounts)+.1*max(ValveData.Amounts);
            % Add pending measurement datapoints
            PendingMeasurements = obj.PendingMeasurements.(ValveToShowName);
            if ~isempty(PendingMeasurements)
                nPendingMeasurements = length(PendingMeasurements);
                for y = 1:nPendingMeasurements
                    line([PendingMeasurements(y) PendingMeasurements(y)],[0 Ymax], 'Color', 'r', 'LineStyle', ':','Parent',obj.GUIHandles.CalibrationCurveAxes);
                end
            end
            if Ymax > 0
                set(obj.GUIHandles.CalibrationCurveAxes, 'YLim', [0 Ymax]);
            else
                set(obj.GUIHandles.CalibrationCurveAxes, 'YLim', [0 1]);
            end
            MaxPlot = max(ValveData.Durations) + min(ValveData.Durations);
            MaxPending = max(PendingMeasurements) + min(ValveData.Durations);
            MaxPlotX = max([MaxPlot MaxPending]);
            set(obj.GUIHandles.CalibrationCurveAxes, 'XLim', [0 MaxPlotX]);
            set(get(obj.GUIHandles.CalibrationCurveAxes, 'Ylabel'), 'String', 'Liquid (ul)', 'fontsize', 14, 'color', [1 1 1]);
            set(get(obj.GUIHandles.CalibrationCurveAxes, 'Xlabel'), 'String', 'Valve duration (ms)', 'fontsize', 14, 'color', [1 1 1]);
            hold(obj.GUIHandles.CalibrationCurveAxes, 'off');
        else
            % If there are no measured values make plot empty
            plot(obj.GUIHandles.CalibrationCurveAxes, 0, 0);
            set(obj.GUIHandles.CalibrationCurveAxes, 'xtick', [], 'ytick', []);
        end
        set(obj.GUIHandles.CalibrationCurveAxes, 'tickdir', 'out', 'box', 'off', 'fontsize', 12, 'fontname', 'arial', 'XColor', [1 1 1], 'YColor', [1 1 1]);
        % ? shouldn't these be pointing at the axes?
        xlabel('Valve time (ms)', 'fontsize', 14, 'color', [1 1 1]);
        ylabel('Liquid (ul)', 'fontsize', 14, 'color', [1 1 1]);
    end

    function AddPendingMeasurement(obj, src, event)
        % Add a pending measurement to the selected valve

        ThisValveCalEntries = get(obj.GUIHandles.MeasurementSelector,'String');
        selectedValveIndex = get(obj.GUIHandles.ValveSelector,'Value');
        nValvesSelected = length(selectedValveIndex);
        assert(nValvesSelected, 'This should not be possible.')
        if ~iscell(ThisValveCalEntries)
            nEntries = 0;
            TempEntry = ThisValveCalEntries;
            ThisValveCalEntries = cell(1,1);
            ThisValveCalEntries{1} = TempEntry;
        elseif strcmp(ThisValveCalEntries{1}, 'No measurements found')
            nEntries = 0;
        else
            nEntries = length(ThisValveCalEntries);
        end

        % -- Request user for measurement value
        obj.GUIHandles.ValueEntryFig = figure('Position', [540 400 400 200],'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off' );
        ha = axes('units','normalized', 'position',[0 0 1 1]);
        uistack(ha,'bottom');
        BG = imread('RewardCalEnterValue.bmp');
        image(BG); axis off;
        obj.GUIHandles.AmountEntry = uicontrol('Style', 'edit', 'String', '0', 'Position', [75 15 115 50], 'FontWeight', 'bold', 'FontSize', 20);
        CalOkButtonGFX = imread('CalOkButton.bmp');
        OkButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [250 15 80 50], 'Callback', @(src, event) obj.GetPendingMeasurementFromUser(), 'CData', CalOkButtonGFX, 'TooltipString', 'Confirm entry');
        uiwait(gcf); % ? should this be obj.GUIHandles.ValueEntryFig?

        % -- Add the measurement to the pending list
        Value2measure = obj.Measurement2add;
        if ~isnan(Value2measure)
            Exists = 0;
            for x = 1:nValvesSelected
                % Check to make sure value doesn't already exist in pending measurements
                valveName = obj.GUIHandles.ValveSelector.String{selectedValveIndex};
%                 valveName = CurrentValve{x}; ? this assumes more than one
%                 valve can be selected
                Pending = obj.PendingMeasurements.(valveName);
                if ~isempty(Pending)
                    if sum(Pending == Value2measure) > 0
                        Exists = 1;
                    end
                end
                % Check to make sure value doesn't already exist in table
                ValveData = obj.ValveDataManager.getValve(valveName);
                if ~isempty(ValveData)
                    ValuesPresent = ValveData.Durations;
                    if sum(Value2measure == ValuesPresent) > 0
                        Exists = 1;
                    end
                end
            end
            if Exists == 0
                for x = 1:nValvesSelected
                    obj.PendingMeasurements.(valveName) = [obj.PendingMeasurements.(valveName) Value2measure];
                end
                ThisValveCalEntries{nEntries+1} = ['<html><FONT COLOR="#ff0000">*PENDING MEASUREMENT: ' num2str(Value2measure) 'ms</FONT></html>'];
                obj.DisplayValve;
            else
                warndlg(['A measurement for ' num2str(Value2measure) 'ms exists. Please delete it first.'], 'Error', 'modal');
            end
        end
        set(obj.GUIHandles.MeasurementSelector,'String',ThisValveCalEntries);
    end

    function GetPendingMeasurementFromUser(obj, src, event)
        % Get a value for liquid amount from the user
        ValueEntered = get(obj.GUIHandles.AmountEntry, 'String');
        ValidEntry = 1;
        CandidateValue = str2double(ValueEntered);
        if isnan(CandidateValue)
            ValidEntry = 0;
        elseif CandidateValue < 1
            ValidEntry = 0;
        elseif CandidateValue > 5000
            ValidEntry = 0;
        end
        if ValidEntry == 1
            obj.Measurement2add = CandidateValue;
        else
            obj.Measurement2add = NaN;
        end
        close(obj.GUIHandles.ValueEntryFig);
    end

    function RemoveMeasurement(obj, varargin)
        ThisValveCalEntries = get(obj.GUIHandles.MeasurementSelector,'String');
        currentValveIndex = get(obj.GUIHandles.ValveSelector,'Value');
        valveName = obj.GUIHandles.ValveSelector.String{currentValveIndex};
        if ~iscell(ThisValveCalEntries)
            TempEntry = ThisValveCalEntries;
            ThisValveCalEntries = cell(1,1);
            ThisValveCalEntries{1} = TempEntry;
        end
        SelectedEntry = get(obj.GUIHandles.MeasurementSelector,'Value');
        SelectedEntryText = ThisValveCalEntries{SelectedEntry};

        isPendingMeasurement = 0;
        if SelectedEntryText(1) == '<'
            isPendingMeasurement = 1;
            % remove pending measurement and skip subsequent script to remove table
            % values
            valveObject = obj.ValveDataManager.getValve(valveName);
            nActualMeasurements= numel(valveObject.Durations);
            PendingEntryIndex = SelectedEntry - nActualMeasurements;
            CurrentValvePendingMeasurements = obj.PendingMeasurements.(valveName);
            nPendingEntries = length(CurrentValvePendingMeasurements);
            if nPendingEntries > 1
                if PendingEntryIndex > 1
                    Entries_pre = CurrentValvePendingMeasurements(1:(PendingEntryIndex-1));
                else
                    Entries_pre = [];
                end
                if PendingEntryIndex < nPendingEntries
                    Entries_post = CurrentValvePendingMeasurements(PendingEntryIndex+1:nPendingEntries);
                else
                    Entries_post = [];
                end
                obj.PendingMeasurements.(valveName) = [Entries_pre Entries_post];
            else
                obj.PendingMeasurements.(valveName) = [];
            end
        end
        ThisValveCalEntries = ThisValveCalEntries(~ismember(ThisValveCalEntries,SelectedEntryText));
        [nEntries,Trash] = size(ThisValveCalEntries);
        if SelectedEntry > nEntries
            set(obj.GUIHandles.MeasurementSelector, 'Value', SelectedEntry-1);
        end
        if isempty(ThisValveCalEntries)
            ThisValveCalEntries{1} = 'No measurements found.';
            set(obj.GUIHandles.MeasurementSelector, 'Value', 1);
        end
        set(obj.GUIHandles.MeasurementSelector,'String',ThisValveCalEntries);

        if isPendingMeasurement == 0
            % Remove entry from calibration table copy in handles struct
            valveObject = obj.ValveDataManager.getValve(valveName);
            nMeasurements = numel(valveObject.Durations);
            if nMeasurements > 1
                valveObject.removeMeasurement(SelectedEntry);
                valveObject.updateCoeffs()
                
                % Move selected value in listbox if that value no longer exists
                if SelectedEntry > nMeasurements
                    set(obj.GUIHandles.MeasurementSelector, 'Value', nMeasurements);
                elseif SelectedEntry == nMeasurements
                    set(obj.GUIHandles.MeasurementSelector, 'Value', nMeasurements-1);
                end
            else
                valveObject.removeMeasurement(1)
                valveObject.updateCoeffs()
            end
            obj.saveFile()
        end
        obj.DisplayValve();
    end


    function RunPendingMeasurements(obj, varargin)
        % Create a vector of measurements to test
        ValveIDs = [];
        PulseDurations = [];
        PendingMeasurements = obj.PendingMeasurements;
        allValveNames = fields(PendingMeasurements);
        valveNames = {};
        for x = 1:numel(allValveNames)
            valveName = allValveNames{x};
            if ~isempty(PendingMeasurements.(valveName))
                ValveIDs = [ValveIDs x];
                valveNames = [valveNames, valveName];
                PulseDurations = [PulseDurations (PendingMeasurements.(valveName)(1))/1000];
            end
        end
        nValidMeasurements = length(ValveIDs);
        if ~isempty(ValveIDs)
            % Deliver liquid
            k = msgbox('Please refill liquid reservoirs and click Ok to begin.', 'modal');
            waitfor(k);
            Completed = BpodLib.calibration.liquid.RunRewardCalibration(obj.BpodSystem, str2double(get(obj.GUIHandles.nPulsesEdit, 'string')), valveNames, PulseDurations, 'PulseInterval', .2);
            if Completed
                % Enter measurements:
                
                % Set up window
                % todo: make compatible with port array and other numbers
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
                
                % Prompt for each valid measurement in order, un-hiding the GUI box and
                % displaying a cursor triangle on the correct row
                for y = 1:8
                    if isempty(find(y == ValveIDs))
                        eval(['set(obj.GUIHandles.CB' num2str(y) 'b, ''Enable'', ''off'')'])
                    else
                        eval(['set(obj.GUIHandles.CB' num2str(y) 'b, ''Enable'', ''on'', ''BackgroundColor'', [.6 .9 .6])'])
                    end
                end
                drawnow;
            end
        end
    end

    function saveFile(obj, varargin)
        % Save file
        saveFolder = fileparts(obj.savePath);
        if exist(saveFolder) ~= 7
            mkdir(saveFolder);
        end
        % BpodLib.calibration.liquid.io.save(obj.ValveDataManager.createSaveData(), 'BpodSystem', obj.BpodSystem, 'filepath', obj.savePath, 'verbose', true)
        warning('LiquidCalibratorUI.saveFile() not completing save while in dev mode.')
        % todo: make save work before final release
    end

    function AddCalMeasurements(obj, varargin)
        figure(obj.GUIHandles.RunMeasurementsFig);
        PendingMeasurements = obj.PendingMeasurements;
        allValveNames = fields(PendingMeasurements);
        nValves = length(fields(PendingMeasurements));
        % Create a vector of measurements to test
        ValveIDs = [];
        valveNames = {};
        PulseDurations = [];
        for x = 1:nValves
            valveName = allValveNames{x};
            if ~isempty(PendingMeasurements.(valveName))
                ValveIDs = [ValveIDs x];
                valveNames = [valveNames allValveNames(x)];
                PulseDurations = [PulseDurations PendingMeasurements.(valveName)(1)];
            end
        end
        nValidMeasurements = length(ValveIDs);
        CurrentAmounts = nan(1,nValidMeasurements);
        % Extract measured amounts from textboxes. Error if invalid.
        AllValid = 1;
        for x = 1:nValidMeasurements
            CurrentAmounts(x) = str2double(obj.GUIHandles.(sprintf('CB%ib', ValveIDs(x))).String);
            % eval(['CurrentAmounts(' num2str(x) ') = str2double(get(obj.GUIHandles.CB' num2str(ValveIDs(x)) 'b, ''String''));'])
            if isnan(CurrentAmounts(x))
                AllValid = 0;
                errordlg(['Invalid measurement entered for valve ' num2str(ValveIDs(x))])
                break
            elseif CurrentAmounts(x) < 0
                AllValid = 0;
                errordlg(['Invalid measurement entered for valve ' num2str(ValveIDs(x))])
                break
            end
        end
        
        % Convert g*nPulses to microliters
        CurrentAmounts = CurrentAmounts*1000/str2double(get(obj.GUIHandles.nPulsesEdit, 'string'));
        
        if AllValid == 1
            % Update cal table on HD and in GUI handles
            for x = 1:nValidMeasurements
                valveName = valveNames{x}; % ! I reckon this could go wrong at some point
                valveObject = obj.ValveDataManager.getValve(valveName);
                % Add or append to table
                valveObject.addMeasurement(PulseDurations(x), CurrentAmounts(x))
                valveObject.updateCoeffs()

            end
            % Remove pending measurements (preserving any more that were set for future rounds)
            PendingMeasurements = obj.PendingMeasurements;
            for x = 1:nValidMeasurements
                valveName = valveNames{x};
                if length(PendingMeasurements.(valveName)) > 1
                    Measurements = PendingMeasurements.(valveName);
                    Measurements = Measurements(2:length(Measurements));
                    PendingMeasurements.(valveName) = Measurements;
                else
                    PendingMeasurements.(valveName) = [];
                end
            end
            obj.PendingMeasurements = PendingMeasurements;
            
            % Call the Listbox 1 call back in
            % LiquidCalibrationManager to reflect the new pending measurements vector
            
            % Save file
            obj.saveFile()
            % todo: modify insert valve insertion into BpodSystem
%             BpodSystem.CalibrationTables.LiquidCal = LiquidCal;
            msgbox('Calibration files updated.', 'modal')
            close(obj.GUIHandles.RunMeasurementsFig);
            obj.DisplayValve();
        end
    end
    
    function SuggestPoints(obj, varargin)
        if isfield(obj.GUIHandles, 'RecommendedMeasureFig')
            if isvalid(obj.GUIHandles.RecommendedMeasureFig)
                figure(obj.GUIHandles.RecommendedMeasureFig);
                return
            end
        end
        CalData = obj.ValveDataManager;
        obj.GUIHandles.RecommendedMeasureFig = figure('Position', [540 400 400 200],'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off' );
        ha = axes('units','normalized', 'position',[0 0 1 1]);
        uistack(ha,'bottom');
        BG = imread('RewardCalAddRecommends.bmp');
        image(BG); axis off;
        obj.GUIHandles.CB1 = uicontrol('Style', 'checkbox', 'Position', [13 140 15 15]);
        obj.GUIHandles.CB2 = uicontrol('Style', 'checkbox', 'Position', [64 140 15 15]);
        obj.GUIHandles.CB3 = uicontrol('Style', 'checkbox', 'Position', [116 140 15 15]);
        obj.GUIHandles.CB4 = uicontrol('Style', 'checkbox', 'Position', [168 140 15 15]);
        obj.GUIHandles.CB5 = uicontrol('Style', 'checkbox', 'Position', [220 140 15 15]);
        obj.GUIHandles.CB6 = uicontrol('Style', 'checkbox', 'Position', [271 140 15 15]);
        obj.GUIHandles.CB7 = uicontrol('Style', 'checkbox', 'Position', [324 140 15 15]);
        obj.GUIHandles.CB8 = uicontrol('Style', 'checkbox', 'Position', [375 140 15 15]);

        for valveIndex = 1:8
            if ~isempty(CalData.getValve(valveIndex).Durations)
                obj.GUIHandles.(sprintf('CB%i', valveIndex)).Value = 1;
            end
        end

        obj.GUIHandles.LowRangeEdit = uicontrol('Style', 'edit', 'String', '2', 'Position', [248 71 35 30], 'FontWeight', 'bold', 'FontSize', 12, 'TooltipString', 'Enter a non-zero value for range minimum');
        obj.GUIHandles.HighRangeEdit = uicontrol('Style', 'edit', 'String', '10', 'Position', [329 71 35 30], 'FontWeight', 'bold', 'FontSize', 12, 'TooltipString', 'Enter a non-zero value for range maximum');
        set(obj.GUIHandles.LowRangeEdit, 'String', num2str(obj.CalibrationTargetRange(1)));
        set(obj.GUIHandles.HighRangeEdit, 'String', num2str(obj.CalibrationTargetRange(2)));
        obj.GUIHandles.SuggestButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [150 10 120 50], 'Callback', @(src, event) obj.AddSuggestedPoints(), 'CData', imread('SuggestButton.bmp'), 'TooltipString', 'Confirm');
    end

    function AddSuggestedPoints(obj, varargin)
        figure(obj.GUIHandles.RecommendedMeasureFig);
        CalTable = obj.ValveDataManager;
        % Figure out which valves were to be targeted
        ValveLogic = zeros(1,8);
        for valveIndex = 1:8
            ValveLogic(valveIndex) = get(obj.GUIHandles.(sprintf('CB%i', valveIndex)), 'Value');
        end

    
        TargetValves = find(ValveLogic);
        CalPending = obj.PendingMeasurements;
        RangeLow = str2double(get(obj.GUIHandles.LowRangeEdit, 'String'));
        RangeHigh = str2double(get(obj.GUIHandles.HighRangeEdit, 'String'));
        SelectedValve = get(obj.GUIHandles.ValveSelector,'Value');
        CurrentEntryString = get(obj.GUIHandles.MeasurementSelector,'String');
    
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
    
        if InvalidParams == 0
            for valveIndex = TargetValves
                ThisValve = CalTable.getValve(valveIndex);
                if ~isempty(ThisValve.Durations)
                    MeasuredAmounts = ThisValve.Amounts';
                    ValveDurations = ThisValve.Durations';
                    nMeasurements = length(MeasuredAmounts);
                else
                    MeasuredAmounts = [];
                    nMeasurements = 0;
                end
                if nMeasurements > 1 % Use trinomial curve fit to predict next measurement
                    DistanceVector = MeasuredAmounts;
                    if isempty(find(MeasuredAmounts == RangeLow))
                        DistanceVector = [DistanceVector RangeLow];
                    end
                    if isempty(find(MeasuredAmounts == RangeHigh))
                        DistanceVector = [DistanceVector RangeHigh];
                    end
                    DistanceVector = sort(DistanceVector);
                    Startpoint = find(DistanceVector == RangeLow);
                    Endpoint = find(DistanceVector == RangeHigh);
                    DistanceVector = DistanceVector(Startpoint:Endpoint);
                    Distances = zeros(1,length(DistanceVector));
                    for y = 2:length(DistanceVector)
                        Distances(y) = abs(DistanceVector(y) - DistanceVector(y-1));
                    end
                    [MaxDistance, MaxDistancePos] = max(Distances);
                    SuggestedAmount = DistanceVector(MaxDistancePos-1) + (DistanceVector(MaxDistancePos)-DistanceVector(MaxDistancePos-1))/2;
                    if nMeasurements > 3
                        SuggestedValveDuration = round(polyval(CalTable.getValve(valveIndex).Coeffs,SuggestedAmount));
                    elseif nMeasurements == 3
                        Coeffs = polyfit(MeasuredAmounts, ValveDurations, 2);
                        SuggestedValveDuration = round(polyval(Coeffs, SuggestedAmount));
                    elseif nMeasurements == 2
                        Coeffs = polyfit(MeasuredAmounts, ValveDurations, 1);
                        SuggestedValveDuration = round(polyval(Coeffs, SuggestedAmount));
                    end
                else
                    if nMeasurements == 1
                        % Use a linear estimate
                        ulPerMs = MeasuredAmounts/ValveDurations;
                        if (MeasuredAmounts < RangeLow) || (MeasuredAmounts > RangeHigh)
                            TargetAmount = (RangeHigh - RangeLow)/2;
                        else
                            BottomPart = MeasuredAmounts - RangeLow;
                            TopPart = RangeHigh - MeasuredAmounts;
                            if BottomPart > TopPart
                                TargetAmount = RangeLow+(BottomPart/2);
                            else
                                TargetAmount = RangeHigh-(TopPart/2);
                            end
                            
                        end
                        SuggestedValveDuration = round(TargetAmount/ulPerMs);
                    else
                        % Use an estimate of the middle of the range based on range and our experience with
                        % the CSHL configuration (nResearch pinch valves, silastic
                        % tubing, specs in Bpod literature)
                        SuggestedValveDuration = mean([RangeHigh RangeLow])*4;
                    end
                end
                valveNames = fields(CalPending);
                valveName = valveNames{valveIndex};
                ThisValvePending = CalPending.(valveName);
                NonDuplicate = 0;
                if isempty(ThisValvePending)
                    ThisValvePending(1) = SuggestedValveDuration;
                    NonDuplicate = 1;
                else
                    if isempty(find(ThisValvePending == SuggestedValveDuration))
                        ThisValvePending(length(ThisValvePending)+1) = SuggestedValveDuration;
                        NonDuplicate = 1;
                    end
                end
                
                if NonDuplicate == 1 % If this measurement hasn't already been added to pending
                    CalPending.(valveName) = ThisValvePending;
                    if valveIndex == SelectedValve
                        CurrentEntryString{nMeasurements+1} = ['<html><FONT COLOR="#ff0000">*PENDING MEASUREMENT: '  num2str(SuggestedValveDuration) 'ms</FONT></html>'];
                        set(obj.GUIHandles.MeasurementSelector, 'String', CurrentEntryString);
                    end
                    CalPending.(valveName) = ThisValvePending;
                end
            end
            obj.PendingMeasurements = CalPending;
            obj.CalibrationTargetRange = [RangeLow RangeHigh];
            close(obj.GUIHandles.RecommendedMeasureFig);
            obj.DisplayValve();
        else
            if (RangeHigh == 0) || (RangeLow == 0)
                warndlg('Range minimum and maximum must be non-zero.', 'Error', 'modal');
            else
                warndlg('Invalid range entered.', 'Error', 'modal');
            end
        end
    
    end

    function TestSpecificAmount(obj, varargin)
        if isfield(obj.GUIHandles, 'TestSpecificAmtFig') && ~verLessThan('MATLAB', '8.4')
            if isgraphics(obj.GUIHandles.TestSpecificAmtFig)
                figure(obj.GUIHandles.TestSpecificAmtFig);
                return
            end
        end
        obj.GUIHandles.TestSpecificAmtFig = figure('Position', [100 100 400 600],'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off', 'Name', 'Test specific amount');
        ha = axes('units','normalized', 'position',[0 0 1 1]);
        uistack(ha,'bottom');
        BG = imread('SpecificAmountEntry.bmp');
        image(BG); axis off;
        obj.GUIHandles.CB1b = uicontrol('Style', 'checkbox', 'Position', [13 535 15 15], 'TooltipString', 'Test valve 1');
        obj.GUIHandles.CB2b = uicontrol('Style', 'checkbox', 'Position', [64 535 15 15], 'TooltipString', 'Test valve 2');
        obj.GUIHandles.CB3b = uicontrol('Style', 'checkbox', 'Position', [116 535 15 15], 'TooltipString', 'Test valve 3');
        obj.GUIHandles.CB4b = uicontrol('Style', 'checkbox', 'Position', [168 535 15 15], 'TooltipString', 'Test valve 4');
        obj.GUIHandles.CB5b = uicontrol('Style', 'checkbox', 'Position', [220 535 15 15], 'TooltipString', 'Test valve 5');
        obj.GUIHandles.CB6b = uicontrol('Style', 'checkbox', 'Position', [271 535 15 15], 'TooltipString', 'Test valve 6');
        obj.GUIHandles.CB7b = uicontrol('Style', 'checkbox', 'Position', [324 535 15 15], 'TooltipString', 'Test valve 7');
        obj.GUIHandles.CB8b = uicontrol('Style', 'checkbox', 'Position', [375 535 15 15], 'TooltipString', 'Test valve 8');

        for valveIndex = 1:8
            if ~isempty(obj.ValveDataManager.getValve(valveIndex).Durations)
                obj.GUIHandles.(sprintf('CB%ib', valveIndex)).Value = 1;
            end
        end

        obj.GUIHandles.SpecificAmtEdit = uicontrol('Style', 'edit', 'String', '10', 'Position', [256 478 40 25], 'FontWeight', 'bold', 'FontUnits', 'Pixels', 'FontSize', 16, 'BackgroundColor', [.9 .9 .9]);
        obj.GUIHandles.nPulsesDropmenu = uicontrol('Style', 'popupmenu', 'String', {'100' '200' '300' '400' '500'}, 'Position', [289 447 50 25], 'FontWeight', 'bold', 'FontUnits', 'Pixels', 'FontSize', 16, 'BackgroundColor', [.9 .9 .9], 'TooltipString', 'Use more pulses with small water volumes for improved accuracy');
        obj.GUIHandles.ToleranceDropmenu = uicontrol('Style', 'popupmenu', 'String', {'5' '10'}, 'Position', [289 416 50 25], 'FontWeight', 'bold', 'FontUnits', 'Pixels', 'FontSize', 16, 'BackgroundColor', [.9 .9 .9], 'TooltipString', 'Percent of intended amount by which measured amount can differ');
        obj.GUIHandles.ResultsListbox = uicontrol('Style', 'listbox', 'String', {''}, 'Position', [25 28 355 130], 'FontWeight', 'bold', 'FontUnits', 'Pixels', 'FontSize', 15, 'BackgroundColor', [.85 .85 .85], 'SelectionHighlight', 'off');
    
        jScrollPane = findjobj(obj.GUIHandles.ResultsListbox); % get the scroll-pane object
        jListbox = jScrollPane.getViewport.getComponent(0);
        jListbox.setBackground(javax.swing.plaf.ColorUIResource(.85,.85,.85));
    
        DeliverButtonGFX = imread('TestDeliverButton.bmp');
        obj.GUIHandles.DeliverButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [40 300 325 50], 'Callback', @(src, event) obj.RunSpecificAmount(), 'TooltipString', 'Start liquid delivery', 'CData', DeliverButtonGFX);
        obj.GUIHandles.MeasuredAmtEdit = uicontrol('Style', 'edit', 'String', '---', 'Position', [202 238 55 30], 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.88 .88 .88], 'Enable', 'off');
        obj.GUIHandles.MeasuredValveText = uicontrol('Style', 'edit', 'String', '1', 'Position', [123 238 55 30], 'FontWeight', 'bold', 'FontSize', 14, 'enable', 'off', 'BackgroundColor', [.85 .85 .85]);
        MeasurementButtonGFX = imread('NextMeasurement.bmp');
        obj.GUIHandles.EnterMeasurementButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [295 233 60 40], 'Callback', @(src, event) obj.EnterTestCal(), 'TooltipString', 'Enter measurement', 'CData', MeasurementButtonGFX);
    end

    function RunSpecificAmount(obj, varargin)
        figure(obj.GUIHandles.TestSpecificAmtFig);
        % In case the GUI has already been used, reset values.
        set(obj.GUIHandles.EnterMeasurementButton, 'Enable', 'on');
        set(obj.GUIHandles.ResultsListbox, 'String', cell(1,1), 'Value', 1)
        set(obj.GUIHandles.MeasuredValveText, 'String', '1')
        InvalidParams = 0; % if invalid params are found, this is set to "1" and delivery is skipped
    
        % Figure out which valves to test
        ValveLogic = zeros(1,8);
        for index = 1:8
            ValveLogic(index) = obj.GUIHandles.(sprintf('CB%ib', index)).Value;
        end
        TargetValveIndices = find(ValveLogic);
        TargetValveNames = cell(sum(ValveLogic), 1);
        allValveNames = obj.ValveDataManager.getValveNames();
        for index = TargetValveIndices
            valveName = allValveNames{index};
            TargetValveNames{index} = valveName;
        end
        % Sanity-check target valves
        if isempty(TargetValveIndices)
            InvalidParams = 1;
        end
        % Figure out amount to test
        LiquidAmount = get(obj.GUIHandles.SpecificAmtEdit, 'String');
        % Sanity-check liquid amount
        if isnan(str2double(LiquidAmount))
            InvalidParams = 1;
        end
        LiquidAmount = round(str2double(LiquidAmount));
        if (LiquidAmount < 0) || (LiquidAmount > 1000)
            InvalidParams = 1;
        end
    
        if InvalidParams == 0
            % Convert liquid amount to pulse duration using current table
            PulseDurations = GetValveTimes(LiquidAmount, TargetValveIndices, 'ValveDataManager', obj.ValveDataManager);
            % Figure out how many pulses to deliver
            nPulses = get(obj.GUIHandles.nPulsesDropmenu, 'Value')*100;
            % Set valve request window
            set(obj.GUIHandles.MeasuredValveText, 'String', num2str(TargetValveIndices(1)));
            drawnow;
            % Call calibration script
            Completed = BpodLib.calibration.liquid.RunRewardCalibration(obj.BpodSystem, nPulses, TargetValveNames, PulseDurations, 'PulseInterval', .2);
        else
            warndlg('Invalid settings detected. Check setup.', 'Error', 'modal');
        end
        if Completed
            % Get measurements
            set(obj.GUIHandles.MeasuredAmtEdit, 'String', '', 'Enable', 'on');
            uicontrol(obj.GUIHandles.MeasuredAmtEdit);
        end
    end

    function EnterTestCal(obj, varargin)
        figure(obj.GUIHandles.TestSpecificAmtFig);
    
        ToleranceLevelStrings = get(obj.GUIHandles.ToleranceDropmenu, 'String');
        ToleranceLevel = str2double(ToleranceLevelStrings{get(obj.GUIHandles.ToleranceDropmenu, 'Value')})/100; % Fraction of intended amount by which measured amount is allowed to differ from intended amount
    
        % Figure out which valves were tested
        ValveLogic = zeros(1,8);
        for index = 1:8
            ValveLogic(index) = obj.GUIHandles.(sprintf('CB%ib', index)).Value;
        end
        TargetValves = find(ValveLogic);
    
        InvalidParams = 0;
        MeasuredLiquidAmount = get(obj.GUIHandles.MeasuredAmtEdit, 'String');
        % Sanity-check liquid amount
        if isnan(str2double(MeasuredLiquidAmount))
            InvalidParams = 1;
        end
        nPulses = get(obj.GUIHandles.nPulsesDropmenu, 'Value')*100;
        MeasuredLiquidAmount = str2double(MeasuredLiquidAmount);
        if (MeasuredLiquidAmount < 0) || (MeasuredLiquidAmount > 1000)
            InvalidParams = 1;
        end
        IntendedLiquidAmount = get(obj.GUIHandles.SpecificAmtEdit, 'String');
        IntendedLiquidAmount = str2double(IntendedLiquidAmount);
        if InvalidParams == 0
            ValveID = str2double(get(obj.GUIHandles.MeasuredValveText, 'String'));
            ListboxMeasurements = get(obj.GUIHandles.ResultsListbox, 'String');
            if isempty(ListboxMeasurements{1})
                nEntries = 0;
            else
                nEntries = length(ListboxMeasurements);
            end
            CurrentEntry = nEntries+1;
            MeasuredLiquidAmount = MeasuredLiquidAmount/nPulses; % Amount per pulse in ml
            MeasuredLiquidAmount = MeasuredLiquidAmount*1000; % Amount per pulse in ul
            ToleranceIntervalLowBound = IntendedLiquidAmount - (IntendedLiquidAmount*ToleranceLevel);
            ToleranceIntervalHighBound = IntendedLiquidAmount + (IntendedLiquidAmount*ToleranceLevel);
            WithinTolerance = ((MeasuredLiquidAmount >= ToleranceIntervalLowBound) && (MeasuredLiquidAmount <= ToleranceIntervalHighBound));
            if WithinTolerance == 1
                ListboxMeasurements{CurrentEntry} = ['<html><FONT COLOR="#009900">Valve ' num2str(ValveID) ': ' num2str(IntendedLiquidAmount) 'ul indended. ' num2str(MeasuredLiquidAmount) 'ul measured. PASS</FONT></html>'];
            else
                ListboxMeasurements{CurrentEntry} = ['<html><FONT COLOR="#ff0000">Valve ' num2str(ValveID) ': ' num2str(IntendedLiquidAmount) 'ul indended. ' num2str(MeasuredLiquidAmount) 'ul measured. FAIL</FONT></html>'];
            end
            set(obj.GUIHandles.ResultsListbox, 'String', ListboxMeasurements)
            ValveIDPos = find(TargetValves == ValveID);
            if ValveIDPos < length(TargetValves)
                NextValve = TargetValves(ValveIDPos+1);
                set(obj.GUIHandles.MeasuredValveText, 'String', num2str(NextValve));
            else
                set(obj.GUIHandles.EnterMeasurementButton, 'Enable', 'off');
            end
        else
            warndlg('Invalid liquid amount.', 'Error', 'modal');
        end
        set(obj.GUIHandles.MeasuredAmtEdit, 'String', '');
    
    end

end

end