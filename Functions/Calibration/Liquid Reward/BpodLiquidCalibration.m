function varargout = BpodLiquidCalibration(op, varargin)
global BpodSystem
if isempty(isprop(BpodSystem, 'BpodPath'))
    error('You must run Bpod before using this function.');
end
ValveListboxString = {'Valve1', 'Valve2', 'Valve3', 'Valve4', 'Valve5', 'Valve6', 'Valve7', 'Valve8'};
switch lower(op)
    case 'calibrate' % Launch the GUI
        BpodSystem.GUIHandles.LiquidCalibrator = struct;
        BpodSystem.GUIHandles.LiquidCalibrator.MainFig =  figure('Position',[150 180 830 370],'name','Bpod liquid calibrator','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off', 'CloseRequestFcn', @EndCal);
        ha = axes('units','normalized', 'position',[0 0 1 1]);
        uistack(ha,'bottom');
        BG = imread('RewardCalMain.bmp');
        image(BG); axis off;
        BpodSystem.GUIHandles.LiquidCalibrator.ValveSelector = uicontrol('Style', 'listbox',...
            'String', ValveListboxString, 'Position', [20 55 100 210], 'FontWeight', 'bold',...
            'FontUnits', 'Pixels', 'FontSize', 20, 'Callback', @DisplayValve);
        BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector = uicontrol('Style', 'listbox',...
            'String', {'No measurements found'}, 'Position', [140 55 300 210], 'FontWeight', 'bold',...
            'FontUnits', 'Pixels', 'FontSize', 16);
        BpodSystem.GUIHandles.LiquidCalibrator.AddMeasurementButton = uicontrol('Style', 'pushbutton',...
            'Position', [445 230 30 30], 'Callback', @AddPendingMeasurement);
        BpodSystem.GUIHandles.LiquidCalibrator.RemoveMeasurementButton = uicontrol('Style', 'pushbutton',...
            'Position', [445 185 30 30], 'Callback', @RemoveMeasurement);
        set(BpodSystem.GUIHandles.LiquidCalibrator.AddMeasurementButton, 'CData', imread('PlusButton.bmp'));
        set(BpodSystem.GUIHandles.LiquidCalibrator.RemoveMeasurementButton, 'CData', imread('MinusButton.bmp'));
        BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes = axes('Units', 'pixels', 'Position', [550 65 250 200]);
        set(gca, 'tickdir', 'out', 'box', 'off', 'fontsize', 12, 'fontname', 'arial', 'XColor', [1 1 1], 'YColor', [1 1 1]);
        xlabel('Valve time (ms)', 'fontsize', 14, 'color', [1 1 1]); ylabel('Liquid (ul)', 'fontsize', 14, 'color', [1 1 1]);
        BpodSystem.GUIHandles.LiquidCalibrator.nPulsesEdit = uicontrol('Style', 'edit',...
            'String', '100', 'Position', [360 15 80 30], 'FontSize', 14,...
            'TooltipString', 'Number of pulses per weight measurement (100-500)');
        BpodSystem.GUIHandles.LiquidCalibrator.SuggestPointsButton = uicontrol('Style', 'pushbutton',...
            'Position', [20 300 250 50], 'Callback', @SuggestPoints);
        set(BpodSystem.GUIHandles.LiquidCalibrator.SuggestPointsButton, 'CData', imread('SuggestPoints.bmp'));
        BpodSystem.GUIHandles.LiquidCalibrator.MeasurePendingButton = uicontrol('Style', 'pushbutton',...
            'Position', [290 300 250 50], 'Callback', @RunPendingMeasurements);
        set(BpodSystem.GUIHandles.LiquidCalibrator.MeasurePendingButton, 'CData', imread('MeasurePending.bmp'));
        BpodSystem.GUIHandles.LiquidCalibrator.TestCurveButton = uicontrol('Style', 'pushbutton',...
            'Position', [560 300 250 50], 'Callback', @TestSpecificAmount);
        set(BpodSystem.GUIHandles.LiquidCalibrator.TestCurveButton, 'CData', imread('TestCurve.bmp'));
        
        % Setup calibration
        BpodSystem.PluginObjects.LiquidCal.PendingMeasurements = cell(1,8);
        CalibrationFilePath = fullfile(BpodSystem.Path.LocalDir, 'Calibration Files', 'LiquidCalibration.mat');
        load(CalibrationFilePath);
        BpodSystem.PluginObjects.LiquidCal.CalData = LiquidCal;
        BpodSystem.PluginObjects.LiquidCal.CalibrationTargetRange = [2 10];
        DisplayValve;
        
    case 'getvalvetimes'
        LiquidAmount = varargin{1};
        TargetValves = varargin{2};
        nValves = length(TargetValves);
        ValveTimes = nan(1,nValves);
        for x = 1:nValves
            ValidTable = 1;
            CurrentTable = BpodSystem.CalibrationTables.LiquidCal(TargetValves(x)).Table;
            if ~isempty(CurrentTable)
                ValveDurations = CurrentTable(:,1)';
                nMeasurements = length(ValveDurations);
                if nMeasurements < 2
                    ValidTable = 0;
                    error(['Not enough liquid calibration measurements exist for valve ' num2str(TargetValves(x)) '. Bpod needs at least 3 measurements.'])
                end
            else
                ValidTable = 0;
                error(['Not enough liquid calibration measurements exist for valve ' num2str(TargetValves(x)) '. Bpod needs at least 3 measurements.'])
            end
            if ValidTable == 1
                ValveTimes(x) = polyval(BpodSystem.CalibrationTables.LiquidCal(TargetValves(x)).Coeffs, LiquidAmount);
                if isnan(ValveTimes(x))
                    ValveTimes(x) = 0;
                end
                if any(ValveTimes<0)
                    error(['Wrong liquid calibration for valve ' num2str(TargetValves(x)) '. Negative open time.'])
                end
            end
        end
        ValveTimes = ValveTimes/1000;
        varargout{1} = ValveTimes;
    case 'end'
        
    otherwise
        error([op 'is not a valid argument for BpodLiquidCalibration.']);
end

function DisplayValve(varargin)
global BpodSystem
ValveToShow = get(BpodSystem.GUIHandles.LiquidCalibrator.ValveSelector,'Value');
ValveData = BpodSystem.PluginObjects.LiquidCal.CalData(ValveToShow).Table;
[nMeasurements trash] = size(ValveData);
if isempty(ValveData)
    ThisValveCalEntries = cell(1,1);
    nMeasurements = 1;
    if isempty(BpodSystem.PluginObjects.LiquidCal.PendingMeasurements{ValveToShow})
        ThisValveCalEntries{1} =  'No measurements found';
        set(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector,'Value', 1)
    else
        for x = 1:length(BpodSystem.PluginObjects.LiquidCal.PendingMeasurements{ValveToShow})
            ThisValveCalEntries{x} = ['<html><FONT COLOR="#ff0000">*PENDING MEASUREMENT: '  num2str(BpodSystem.PluginObjects.LiquidCal.PendingMeasurements{ValveToShow}(x)) 'ms</FONT></html>'];
        end
    end
else
    for x = 1:nMeasurements
        Pad = '';
        if ValveData(x,1) < 100
            Pad = [Pad '  '];
        end
        if ValveData(x,1) < 10
            Pad = [Pad '  '];
        end
        ThisValveCalEntries{x} = [num2str(ValveData(x,1)) 'ms pulse ' Pad '=  ' num2str(ValveData(x,2)) 'ul liquid'];
    end
    if ~isempty(BpodSystem.PluginObjects.LiquidCal.PendingMeasurements{ValveToShow})
        for x = 1:length(BpodSystem.PluginObjects.LiquidCal.PendingMeasurements{ValveToShow})
            ThisValveCalEntries{nMeasurements+x} = ['<html><FONT COLOR="#ff0000">*PENDING MEASUREMENT: '  num2str(BpodSystem.PluginObjects.LiquidCal.PendingMeasurements{ValveToShow}(x)) 'ms</FONT></html>'];
        end
    end
end
% If selected entry index exceeds total entries, set current highlighted
% entry to equal the last entry available
SelectedEntry = get(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector,'Value');
if SelectedEntry == 0
    set(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector,'Value', 1)
elseif SelectedEntry > nMeasurements
    set(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector,'Value', nMeasurements)
end
set(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector,'String',ThisValveCalEntries);
% Update plot
ValveData = BpodSystem.PluginObjects.LiquidCal.CalData;
p = ValveData(ValveToShow).Coeffs;
if ~isempty(p)
    Vector = polyval(p,0:.1:150);
    plot(BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes,Vector, 0:.1:150, 'k-', 'LineWidth', 1.5);
    hold(BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes, 'on');
    scatter(BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes, ValveData(ValveToShow).Table(:,1), ValveData(ValveToShow).Table(:,2), 'LineWidth', 2);
    hold(BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes, 'on');
    set(BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes, 'tickdir', 'out', 'box', 'off');
    Ymax = max(ValveData(ValveToShow).Table(:,2))+.1*max(ValveData(ValveToShow).Table(:,2));
    % Add pending measurement datapoints
    PendingMeasurements = BpodSystem.PluginObjects.LiquidCal.PendingMeasurements{ValveToShow};
    if ~isempty(PendingMeasurements)
        nPendingMeasurements = length(PendingMeasurements);
        for y = 1:nPendingMeasurements
            line([PendingMeasurements(y) PendingMeasurements(y)],[0 Ymax], 'Color', 'r', 'LineStyle', ':','Parent',BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes);
        end
    end
    if Ymax > 0
        set(BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes, 'YLim', [0 Ymax]);
    else
        set(BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes, 'YLim', [0 1]);
    end
    MaxPlot = max(ValveData(ValveToShow).Table(:,1)) + min(ValveData(ValveToShow).Table(:,1));
    MaxPending = max(PendingMeasurements) + min(ValveData(ValveToShow).Table(:,1));
    MaxPlotX = max([MaxPlot MaxPending]);
    set(BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes, 'XLim', [0 MaxPlotX]);
    set(get(BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes, 'Ylabel'), 'String', 'Liquid (ul)', 'fontsize', 14, 'color', [1 1 1]);
    set(get(BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes, 'Xlabel'), 'String', 'Valve duration (ms)', 'fontsize', 14, 'color', [1 1 1]);
    hold(BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes, 'off');
else
    plot(BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes, 0, 0);
    set(BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes, 'xtick', [], 'ytick', []);
end
set(BpodSystem.GUIHandles.LiquidCalibrator.CalibrationCurveAxes, 'tickdir', 'out', 'box', 'off', 'fontsize', 12, 'fontname', 'arial', 'XColor', [1 1 1], 'YColor', [1 1 1]);
xlabel('Valve time (ms)', 'fontsize', 14, 'color', [1 1 1]); ylabel('Liquid (ul)', 'fontsize', 14, 'color', [1 1 1]);

function AddPendingMeasurement(varargin)
global BpodSystem
ThisValveCalEntries = get(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector,'String');
CurrentValve = get(BpodSystem.GUIHandles.LiquidCalibrator.ValveSelector,'Value');
nValvesSelected = length(CurrentValve);
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
BpodSystem.GUIHandles.LiquidCalibrator.ValueEntryFig = figure('Position', [540 400 400 200],'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off' );
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('RewardCalEnterValue.bmp');
image(BG); axis off;
BpodSystem.GUIHandles.LiquidCalibrator.AmountEntry = uicontrol('Style', 'edit', 'String', '0', 'Position', [75 15 115 50], 'FontWeight', 'bold', 'FontSize', 20);
CalOkButtonGFX = imread('CalOkButton.bmp');
OkButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [250 15 80 50], 'Callback', @GetPendingMeasurementFromUser, 'CData', CalOkButtonGFX, 'TooltipString', 'Confirm entry');
uiwait(gcf);
Value2measure = BpodSystem.GUIHandles.LiquidCalibrator.Measurement2add;
if ~isnan(Value2measure)
    Exists = 0;
    for x = 1:nValvesSelected
        % Check to make sure value doesn't already exist in pending measurements
        Pending = BpodSystem.PluginObjects.LiquidCal.PendingMeasurements{CurrentValve(x)};
        if ~isempty(Pending)
            if sum(Pending == Value2measure) > 0
                Exists = 1;
            end
        end
        % Check to make sure value doesn't already exist in table
        ValveData = BpodSystem.PluginObjects.LiquidCal.CalData(CurrentValve(x)).Table;
        if ~isempty(ValveData)
            ValuesPresent = ValveData(1,:);
            if sum(Value2measure == ValuesPresent) > 0
                Exists = 1;
            end
        end
    end
    if Exists == 0
        for x = 1:nValvesSelected
            BpodSystem.PluginObjects.LiquidCal.PendingMeasurements{CurrentValve(x)} = [BpodSystem.PluginObjects.LiquidCal.PendingMeasurements{CurrentValve(x)} Value2measure];
        end
        ThisValveCalEntries{nEntries+1} = ['<html><FONT COLOR="#ff0000">*PENDING MEASUREMENT: ' num2str(Value2measure) 'ms</FONT></html>'];
        DisplayValve;
    else
        warndlg(['A measurement for ' num2str(Value2measure) 'ms exists. Please delete it first.'], 'Error', 'modal');
    end
end
set(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector,'String',ThisValveCalEntries);


function GetPendingMeasurementFromUser(varargin)
global BpodSystem
ValueEntered = get(BpodSystem.GUIHandles.LiquidCalibrator.AmountEntry, 'String');
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
    BpodSystem.GUIHandles.LiquidCalibrator.Measurement2add = CandidateValue;
else
    BpodSystem.GUIHandles.LiquidCalibrator.Measurement2add = NaN;
end
close(BpodSystem.GUIHandles.LiquidCalibrator.ValueEntryFig);

function RemoveMeasurement(varargin)
global BpodSystem
ThisValveCalEntries = get(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector,'String');
CurrentValve = get(BpodSystem.GUIHandles.LiquidCalibrator.ValveSelector,'Value');
if ~iscell(ThisValveCalEntries)
    TempEntry = ThisValveCalEntries;
    ThisValveCalEntries = cell(1,1);
    ThisValveCalEntries{1} = TempEntry;
end
SelectedEntry = get(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector,'Value');
SelectedEntryText = ThisValveCalEntries{SelectedEntry};
isPendingMeasurement = 0;
if SelectedEntryText(1) == '<'
    isPendingMeasurement = 1;
    % remove pending measurement and skip subsequent script to remove table
    % values
    ValveData = BpodSystem.PluginObjects.LiquidCal.CalData(CurrentValve).Table;
    [nActualMeasurements trash] = size(ValveData);
    PendingEntryIndex = SelectedEntry - nActualMeasurements;
    CurrentValvePendingMeasurements = BpodSystem.PluginObjects.LiquidCal.PendingMeasurements{CurrentValve};
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
        BpodSystem.PluginObjects.LiquidCal.PendingMeasurements{CurrentValve} = [Entries_pre Entries_post];
    else
        BpodSystem.PluginObjects.LiquidCal.PendingMeasurements{CurrentValve} = [];
    end
end
ThisValveCalEntries = ThisValveCalEntries(~ismember(ThisValveCalEntries,SelectedEntryText));
[nEntries,Trash] = size(ThisValveCalEntries);
if SelectedEntry > nEntries
    set(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector, 'Value', SelectedEntry-1);
end
if isempty(ThisValveCalEntries)
    ThisValveCalEntries{1} = 'No measurements found.';
    set(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector, 'Value', 1);
end
set(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector,'String',ThisValveCalEntries);
if isPendingMeasurement == 0
    % Remove entry from calibration table copy in handles struct
    ValveData = BpodSystem.PluginObjects.LiquidCal.CalData(CurrentValve).Table;
    Coeff = BpodSystem.PluginObjects.LiquidCal.CalData(CurrentValve).Coeffs;
    [nMeasurements trash] = size(ValveData);
    if nMeasurements > 1
        Vtemp_pre = ValveData(1:SelectedEntry-1,1:2);
        if SelectedEntry < nMeasurements
            Vtemp_post = ValveData(SelectedEntry+1:nMeasurements,1:2);
        else
            Vtemp_post = [];
        end
        ValveData = [Vtemp_pre; Vtemp_post];
        % Recalculate trinomial coeffs
        BpodSystem.PluginObjects.LiquidCal.CalData(CurrentValve).Table = ValveData;
        warning off % To suppress warnings about fits with 3 datapoints
        if nMeasurements > 1
            BpodSystem.PluginObjects.LiquidCal.CalData(CurrentValve).Coeffs = polyfit(BpodSystem.PluginObjects.LiquidCal.CalData(CurrentValve).Table(:,2),BpodSystem.PluginObjects.LiquidCal.CalData(CurrentValve).Table(:,1),2);
        else
            BpodSystem.PluginObjects.LiquidCal.CalData(CurrentValve).Coeffs = [];
        end
        warning on
        % Move selected value in listbox if that value no longer exists
        if SelectedEntry > nMeasurements
            set(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector, 'Value', nMeasurements);
        elseif SelectedEntry == nMeasurements
            set(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector, 'Value', nMeasurements-1);
        end
    else
        BpodSystem.PluginObjects.LiquidCal.CalData(CurrentValve).Table = [];
        BpodSystem.PluginObjects.LiquidCal.CalData(CurrentValve).Coeffs = [];
    end
    % Save file
    SavePath = fullfile(BpodSystem.Path.LocalDir, 'Calibration Files', 'LiquidCalibration.mat');
    LiquidCal = BpodSystem.PluginObjects.LiquidCal.CalData;
    LiquidCal(1).LastDateModified = now;
    save(SavePath, 'LiquidCal');
end
DisplayValve;

function SuggestPoints(varargin)
global BpodSystem
CalData = BpodSystem.PluginObjects.LiquidCal.CalData;
BpodSystem.PluginObjects.LiquidCal.RecommendedMeasureFig = figure('Position', [540 400 400 200],'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off' );
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('RewardCalAddRecommends.bmp');
image(BG); axis off;
BpodSystem.PluginObjects.LiquidCal.CB1 = uicontrol('Style', 'checkbox', 'Position', [13 140 15 15]);
BpodSystem.PluginObjects.LiquidCal.CB2 = uicontrol('Style', 'checkbox', 'Position', [64 140 15 15]);
BpodSystem.PluginObjects.LiquidCal.CB3 = uicontrol('Style', 'checkbox', 'Position', [116 140 15 15]);
BpodSystem.PluginObjects.LiquidCal.CB4 = uicontrol('Style', 'checkbox', 'Position', [168 140 15 15]);
BpodSystem.PluginObjects.LiquidCal.CB5 = uicontrol('Style', 'checkbox', 'Position', [220 140 15 15]);
BpodSystem.PluginObjects.LiquidCal.CB6 = uicontrol('Style', 'checkbox', 'Position', [271 140 15 15]);
BpodSystem.PluginObjects.LiquidCal.CB7 = uicontrol('Style', 'checkbox', 'Position', [324 140 15 15]);
BpodSystem.PluginObjects.LiquidCal.CB8 = uicontrol('Style', 'checkbox', 'Position', [375 140 15 15]);

if ~isempty(CalData(1).Table);
    set(BpodSystem.PluginObjects.LiquidCal.CB1, 'Value', 1);
end
if ~isempty(CalData(2).Table);
    set(BpodSystem.PluginObjects.LiquidCal.CB2, 'Value', 1);
end
if ~isempty(CalData(3).Table);
    set(BpodSystem.PluginObjects.LiquidCal.CB3, 'Value', 1);
end
if ~isempty(CalData(4).Table);
    set(BpodSystem.PluginObjects.LiquidCal.CB4, 'Value', 1);
end
if ~isempty(CalData(5).Table);
    set(BpodSystem.PluginObjects.LiquidCal.CB5, 'Value', 1);
end
if ~isempty(CalData(6).Table);
    set(BpodSystem.PluginObjects.LiquidCal.CB6, 'Value', 1);
end
if ~isempty(CalData(7).Table);
    set(BpodSystem.PluginObjects.LiquidCal.CB7, 'Value', 1);
end
if ~isempty(CalData(8).Table);
    set(BpodSystem.PluginObjects.LiquidCal.CB8, 'Value', 1);
end
BpodSystem.PluginObjects.LiquidCal.LowRangeEdit = uicontrol('Style', 'edit', 'String', '2', 'Position', [248 71 35 30], 'FontWeight', 'bold', 'FontSize', 12, 'TooltipString', 'Enter a non-zero value for range minimum');
BpodSystem.PluginObjects.LiquidCal.HighRangeEdit = uicontrol('Style', 'edit', 'String', '10', 'Position', [329 71 35 30], 'FontWeight', 'bold', 'FontSize', 12, 'TooltipString', 'Enter a non-zero value for range maximum');
set(BpodSystem.PluginObjects.LiquidCal.LowRangeEdit, 'String', num2str(BpodSystem.PluginObjects.LiquidCal.CalibrationTargetRange(1)));
set(BpodSystem.PluginObjects.LiquidCal.HighRangeEdit, 'String', num2str(BpodSystem.PluginObjects.LiquidCal.CalibrationTargetRange(2)));
BpodSystem.PluginObjects.LiquidCal.SuggestButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [150 10 120 50], 'Callback', @AddSuggestedPoints, 'CData', imread('SuggestButton.bmp'), 'TooltipString', 'Confirm');

function AddSuggestedPoints(varargin)
global BpodSystem
figure(BpodSystem.PluginObjects.LiquidCal.RecommendedMeasureFig);
CalTable = BpodSystem.PluginObjects.LiquidCal.CalData;
% Figure out which valves were to be targeted
ValveLogic = zeros(1,8);
ValveLogic(1) = get(BpodSystem.PluginObjects.LiquidCal.CB1, 'Value');
ValveLogic(2) = get(BpodSystem.PluginObjects.LiquidCal.CB2, 'Value');
ValveLogic(3) = get(BpodSystem.PluginObjects.LiquidCal.CB3, 'Value');
ValveLogic(4) = get(BpodSystem.PluginObjects.LiquidCal.CB4, 'Value');
ValveLogic(5) = get(BpodSystem.PluginObjects.LiquidCal.CB5, 'Value');
ValveLogic(6) = get(BpodSystem.PluginObjects.LiquidCal.CB6, 'Value');
ValveLogic(7) = get(BpodSystem.PluginObjects.LiquidCal.CB7, 'Value');
ValveLogic(8) = get(BpodSystem.PluginObjects.LiquidCal.CB8, 'Value');

TargetValves = find(ValveLogic);
CalPending = BpodSystem.PluginObjects.LiquidCal.PendingMeasurements;
RangeLow = str2double(get(BpodSystem.PluginObjects.LiquidCal.LowRangeEdit, 'String'));
RangeHigh = str2double(get(BpodSystem.PluginObjects.LiquidCal.HighRangeEdit, 'String'));
SelectedValve = get(BpodSystem.GUIHandles.LiquidCalibrator.ValveSelector,'Value');
CurrentEntryString = get(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector,'String');

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
    for x = TargetValves
        ThisValveTable = CalTable(x).Table;
        if ~isempty(ThisValveTable)
            MeasuredAmounts = ThisValveTable(:,2)';
            ValveDurations = ThisValveTable(:,1)';
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
                SuggestedValveDuration = round(polyval(CalTable(x).Coeffs,SuggestedAmount));
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
        ThisValvePending = CalPending{x};
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
            CalPending{x} = ThisValvePending;
            if x == SelectedValve
                CurrentEntryString{nMeasurements+1} = ['<html><FONT COLOR="#ff0000">*PENDING MEASUREMENT: '  num2str(SuggestedValveDuration) 'ms</FONT></html>'];
                set(BpodSystem.GUIHandles.LiquidCalibrator.MeasurementSelector, 'String', CurrentEntryString);
            end
            CalPending{x} = ThisValvePending;
        end
    end
    BpodSystem.PluginObjects.LiquidCal.PendingMeasurements = CalPending;
    BpodSystem.PluginObjects.LiquidCal.CalibrationTargetRange = [RangeLow RangeHigh];
    close(BpodSystem.PluginObjects.LiquidCal.RecommendedMeasureFig);
    DisplayValve;
else
    if (RangeHigh == 0) || (RangeLow == 0)
        warndlg('Range minimum and maximum must be non-zero.', 'Error', 'modal');
    else
        warndlg('Invalid range entered.', 'Error', 'modal');
    end
end

function RunPendingMeasurements(varargin)
global BpodSystem
% Create a vector of measurements to test
ValveIDs = [];
PulseDurations = [];
PendingMeasurements = BpodSystem.PluginObjects.LiquidCal.PendingMeasurements;
for x = 1:8
    if ~isempty(PendingMeasurements{x})
        ValveIDs = [ValveIDs x];
        PulseDurations = [PulseDurations (PendingMeasurements{x}(1))/1000];
    end
end
nValidMeasurements = length(ValveIDs);
if ~isempty(ValveIDs)
    % Deliver liquid
    k = msgbox('Please refill liquid reservoirs and click Ok to begin.', 'modal');
    waitfor(k);
    Completed = RunRewardCal(str2double(get(BpodSystem.GUIHandles.LiquidCalibrator.nPulsesEdit, 'string')), ValveIDs, PulseDurations, .2);
    if Completed
        % Enter measurements:
        
        % Set up window
        BpodSystem.GUIHandles.LiquidCalibrator.RunMeasurementsFig = figure('Position', [540 100 317 530],'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off', 'Name', 'Enter pending measurements');
        ha = axes('units','normalized', 'position',[0 0 1 1]);
        uistack(ha,'bottom');
        BG = imread('CuedMeasurementEntry.bmp');
        image(BG); axis off;
        BpodSystem.GUIHandles.LiquidCalibrator.CB1b = uicontrol('Style', 'edit', 'Position', [155 379 80 35], 'TooltipString', 'Enter liquid weight for valve 1', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
        BpodSystem.GUIHandles.LiquidCalibrator.CB2b = uicontrol('Style', 'edit', 'Position', [155 336 80 35], 'TooltipString', 'Enter liquid weight for valve 2', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
        BpodSystem.GUIHandles.LiquidCalibrator.CB3b = uicontrol('Style', 'edit', 'Position', [155 293 80 35], 'TooltipString', 'Enter liquid weight for valve 3', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
        BpodSystem.GUIHandles.LiquidCalibrator.CB4b = uicontrol('Style', 'edit', 'Position', [155 250 80 35], 'TooltipString', 'Enter liquid weight for valve 4', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
        BpodSystem.GUIHandles.LiquidCalibrator.CB5b = uicontrol('Style', 'edit', 'Position', [155 207 80 35], 'TooltipString', 'Enter liquid weight for valve 5', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
        BpodSystem.GUIHandles.LiquidCalibrator.CB6b = uicontrol('Style', 'edit', 'Position', [155 164 80 35], 'TooltipString', 'Enter liquid weight for valve 6', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
        BpodSystem.GUIHandles.LiquidCalibrator.CB7b = uicontrol('Style', 'edit', 'Position', [155 121 80 35], 'TooltipString', 'Enter liquid weight for valve 7', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
        BpodSystem.GUIHandles.LiquidCalibrator.CB8b = uicontrol('Style', 'edit', 'Position', [155 78 80 35], 'TooltipString', 'Enter liquid weight for valve 8', 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.9 .9 .9]);
        MeasurementButtonGFX2 = imread('MeasurementEntryOkButtonBG.bmp');
        BpodSystem.GUIHandles.LiquidCalibrator.EnterMeasurementButton2 = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [120 7 80 50], 'Callback', @AddCalMeasurements, 'TooltipString', 'Enter measurement', 'CData', MeasurementButtonGFX2);
        
        % Prompt for each valid measurement in order, un-hiding the GUI box and
        % displaying a cursor triangle on the correct row
        for y = 1:8
            if isempty(find(y == ValveIDs))
                eval(['set(BpodSystem.GUIHandles.LiquidCalibrator.CB' num2str(y) 'b, ''Enable'', ''off'')'])
            else
                eval(['set(BpodSystem.GUIHandles.LiquidCalibrator.CB' num2str(y) 'b, ''Enable'', ''on'', ''BackgroundColor'', [.6 .9 .6])'])
            end
        end
        drawnow;
    end
end

function Completed = RunRewardCal(nPulses, TargetValves, PulseDurations, PulseInterval)
% TargetValves = vector listing valves (in range 1-8) that are to be calibrated
% PulseDurations = for each valid valve, specify the time (in ms) for the valve to remain open.
% Pulse Interval = fixed delay between valve pulses
global BpodSystem
Completed = 0;
% Replace with settings
ValvePhysicalAddress = 2.^(0:7);
nValves = length(TargetValves);
PulseDurations(PulseDurations == 0) = NaN;
if sum(PulseDurations > 1) > 0
    error('Pulse durations should be specified in seconds.')
end
for x = 1:length(PulseDurations)
    if isnan(PulseDurations(x))
        PulseDurations(x) = 0;
    end
end

progressbar;
sma = NewStateMatrix();
for y = 1:nValves
    sma = AddState(sma, 'Name', ['PulseValve' num2str(TargetValves(y))], ...
        'Timer', PulseDurations(y),...
        'StateChangeConditions', ...
        {'Tup', ['Delay' num2str(y)]},...
        'OutputActions', {'ValveState', ValvePhysicalAddress(TargetValves(y))});
    if y < nValves
        sma = AddState(sma, 'Name', ['Delay' num2str(y)], ...
            'Timer', PulseInterval,...
            'StateChangeConditions', ...
            {'Tup', ['PulseValve' num2str(TargetValves(y+1))]},...
            'OutputActions', {});
    else
        sma = AddState(sma, 'Name', ['Delay' num2str(y)], ...
            'Timer', PulseInterval,...
            'StateChangeConditions', ...
            {'Tup', 'exit'},...
            'OutputActions', {});
    end
end
SendStateMatrix(sma);
for x = 1:nPulses
    progressbar(x/nPulses)
    if BpodSystem.EmulatorMode == 0
        RunStateMatrix;
        pause(.5);
    end
    if BpodSystem.Status.BeingUsed == 0
        progressbar(1);
        return
    end
end
Completed = 1;
BpodSystem.Status.BeingUsed = 0;

function AddCalMeasurements(varargin)
global BpodSystem
figure(BpodSystem.GUIHandles.LiquidCalibrator.RunMeasurementsFig);
PendingMeasurements = BpodSystem.PluginObjects.LiquidCal.PendingMeasurements;

% Create a vector of measurements to test
ValveIDs = [];
PulseDurations = [];
for x = 1:8
    if ~isempty(PendingMeasurements{x})
        ValveIDs = [ValveIDs x];
        PulseDurations = [PulseDurations PendingMeasurements{x}(1)];
    end
end
nValidMeasurements = length(ValveIDs);
CurrentAmounts = nan(1,nValidMeasurements);
% Extract measured amounts from textboxes. Error if invalid.
AllValid = 1;
for x = 1:nValidMeasurements
    eval(['CurrentAmounts(' num2str(x) ') = str2double(get(BpodSystem.GUIHandles.LiquidCalibrator.CB' num2str(ValveIDs(x)) 'b, ''String''));'])
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
CurrentAmounts = CurrentAmounts*1000/str2double(get(BpodSystem.GUIHandles.LiquidCalibrator.nPulsesEdit, 'string'));


if AllValid == 1
    % Update cal table on HD and in GUI handles
    for x = 1:nValidMeasurements
        % Add or append to table
        CurrentTable = BpodSystem.PluginObjects.LiquidCal.CalData(ValveIDs(x)).Table;
        if isempty(CurrentTable)
            CurrentTable = [PulseDurations(x) CurrentAmounts(x)];
        else
            m = [PulseDurations(x) CurrentAmounts(x)];
            CurrentTable = [CurrentTable; m];
        end
        BpodSystem.PluginObjects.LiquidCal.CalData(ValveIDs(x)).Table = CurrentTable;
        % Calculate coeffs
        MeasuredAmounts = CurrentTable(:,2)';
        ValveDurations = CurrentTable(:,1)';
        nMeasurements = length(MeasuredAmounts);
        if nMeasurements > 1
            BpodSystem.PluginObjects.LiquidCal.CalData(ValveIDs(x)).Coeffs = polyfit(MeasuredAmounts, ValveDurations, 2);
        else
            BpodSystem.PluginObjects.LiquidCal.CalData(ValveIDs(x)).Coeffs = [];
        end
    end
    % Remove pending measurements (preserving any more that were set for future rounds)
    PendingMeasurements = BpodSystem.PluginObjects.LiquidCal.PendingMeasurements;
    for x = 1:nValidMeasurements
        if length(PendingMeasurements{ValveIDs(x)}) > 1
            Measurements = PendingMeasurements{ValveIDs(x)};
            Measurements = Measurements(2:length(Measurements));
            PendingMeasurements{ValveIDs(x)} = Measurements;
        else
            PendingMeasurements{ValveIDs(x)} = [];
        end
    end
    BpodSystem.PluginObjects.LiquidCal.PendingMeasurements = PendingMeasurements;
    
    % Call the Listbox 1 call back in
    % LiquidCalibrationManager to reflect the new pending measurements vector
    
    % Save file
    TestSavePath = fullfile(BpodSystem.Path.BpodRoot, 'Calibration Files');
    if exist(TestSavePath) ~= 7
        mkdir(TestSavePath);
    end
    SavePath = fullfile(BpodSystem.Path.LocalDir, 'Calibration Files', 'LiquidCalibration.mat');
    LiquidCal = BpodSystem.PluginObjects.LiquidCal.CalData;
    LiquidCal(1).LastDateModified = now;
    save(SavePath, 'LiquidCal');
    BpodSystem.CalibrationTables.LiquidCal = LiquidCal;
    msgbox('Calibration files updated.', 'modal')
    close(BpodSystem.GUIHandles.LiquidCalibrator.RunMeasurementsFig);
    DisplayValve;
end

function TestSpecificAmount(varargin)
global BpodSystem
BpodSystem.GUIHandles.LiquidCalibrator.TestSpecificAmtFig = figure('Position', [100 100 400 600],'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off', 'Name', 'Test specific amount');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('SpecificAmountEntry.bmp');
image(BG); axis off;
BpodSystem.GUIHandles.LiquidCalibrator.CB1b = uicontrol('Style', 'checkbox', 'Position', [13 535 15 15], 'TooltipString', 'Test valve 1');
BpodSystem.GUIHandles.LiquidCalibrator.CB2b = uicontrol('Style', 'checkbox', 'Position', [64 535 15 15], 'TooltipString', 'Test valve 2');
BpodSystem.GUIHandles.LiquidCalibrator.CB3b = uicontrol('Style', 'checkbox', 'Position', [116 535 15 15], 'TooltipString', 'Test valve 3');
BpodSystem.GUIHandles.LiquidCalibrator.CB4b = uicontrol('Style', 'checkbox', 'Position', [168 535 15 15], 'TooltipString', 'Test valve 4');
BpodSystem.GUIHandles.LiquidCalibrator.CB5b = uicontrol('Style', 'checkbox', 'Position', [220 535 15 15], 'TooltipString', 'Test valve 5');
BpodSystem.GUIHandles.LiquidCalibrator.CB6b = uicontrol('Style', 'checkbox', 'Position', [271 535 15 15], 'TooltipString', 'Test valve 6');
BpodSystem.GUIHandles.LiquidCalibrator.CB7b = uicontrol('Style', 'checkbox', 'Position', [324 535 15 15], 'TooltipString', 'Test valve 7');
BpodSystem.GUIHandles.LiquidCalibrator.CB8b = uicontrol('Style', 'checkbox', 'Position', [375 535 15 15], 'TooltipString', 'Test valve 8');

if ~isempty(BpodSystem.PluginObjects.LiquidCal.CalData(1).Table);
    set(BpodSystem.GUIHandles.LiquidCalibrator.CB1b, 'Value', 1);
end
if ~isempty(BpodSystem.PluginObjects.LiquidCal.CalData(2).Table);
    set(BpodSystem.GUIHandles.LiquidCalibrator.CB2b, 'Value', 1);
end
if ~isempty(BpodSystem.PluginObjects.LiquidCal.CalData(3).Table);
    set(BpodSystem.GUIHandles.LiquidCalibrator.CB3b, 'Value', 1);
end
if ~isempty(BpodSystem.PluginObjects.LiquidCal.CalData(4).Table);
    set(BpodSystem.GUIHandles.LiquidCalibrator.CB4b, 'Value', 1);
end
if ~isempty(BpodSystem.PluginObjects.LiquidCal.CalData(5).Table);
    set(BpodSystem.GUIHandles.LiquidCalibrator.CB5b, 'Value', 1);
end
if ~isempty(BpodSystem.PluginObjects.LiquidCal.CalData(6).Table);
    set(BpodSystem.GUIHandles.LiquidCalibrator.CB6b, 'Value', 1);
end
if ~isempty(BpodSystem.PluginObjects.LiquidCal.CalData(7).Table);
    set(BpodSystem.GUIHandles.LiquidCalibrator.CB7b, 'Value', 1);
end
if ~isempty(BpodSystem.PluginObjects.LiquidCal.CalData(8).Table);
    set(BpodSystem.GUIHandles.LiquidCalibrator.CB8b, 'Value', 1);
end
BpodSystem.GUIHandles.LiquidCalibrator.SpecificAmtEdit = uicontrol('Style', 'edit', 'String', '10', 'Position', [256 478 40 25], 'FontWeight', 'bold', 'FontUnits', 'Pixels', 'FontSize', 16, 'BackgroundColor', [.9 .9 .9]);
BpodSystem.GUIHandles.LiquidCalibrator.nPulsesDropmenu = uicontrol('Style', 'popupmenu', 'String', {'100' '200' '300' '400' '500'}, 'Position', [289 447 50 25], 'FontWeight', 'bold', 'FontUnits', 'Pixels', 'FontSize', 16, 'BackgroundColor', [.9 .9 .9], 'TooltipString', 'Use more pulses with small water volumes for improved accuracy');
BpodSystem.GUIHandles.LiquidCalibrator.ToleranceDropmenu = uicontrol('Style', 'popupmenu', 'String', {'5' '10'}, 'Position', [289 416 50 25], 'FontWeight', 'bold', 'FontUnits', 'Pixels', 'FontSize', 16, 'BackgroundColor', [.9 .9 .9], 'TooltipString', 'Percent of intended amount by which measured amount can differ');
BpodSystem.GUIHandles.LiquidCalibrator.ResultsListbox = uicontrol('Style', 'listbox', 'String', {''}, 'Position', [25 28 355 130], 'FontWeight', 'bold', 'FontUnits', 'Pixels', 'FontSize', 15, 'BackgroundColor', [.85 .85 .85], 'SelectionHighlight', 'off');

jScrollPane = findjobj(BpodSystem.GUIHandles.LiquidCalibrator.ResultsListbox); % get the scroll-pane object
jListbox = jScrollPane.getViewport.getComponent(0);
jListbox.setBackground(javax.swing.plaf.ColorUIResource(.85,.85,.85));

DeliverButtonGFX = imread('TestDeliverButton.bmp');
BpodSystem.GUIHandles.LiquidCalibrator.DeliverButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [40 300 325 50], 'Callback', @RunSpecificAmount, 'TooltipString', 'Start liquid delivery', 'CData', DeliverButtonGFX);
BpodSystem.GUIHandles.LiquidCalibrator.MeasuredAmtEdit = uicontrol('Style', 'edit', 'String', '---', 'Position', [202 238 55 30], 'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', [.88 .88 .88], 'Enable', 'off');
BpodSystem.GUIHandles.LiquidCalibrator.MeasuredValveText = uicontrol('Style', 'edit', 'String', '1', 'Position', [123 238 55 30], 'FontWeight', 'bold', 'FontSize', 14, 'enable', 'off', 'BackgroundColor', [.85 .85 .85]);
MeasurementButtonGFX = imread('NextMeasurement.bmp');
BpodSystem.GUIHandles.LiquidCalibrator.EnterMeasurementButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [295 233 60 40], 'Callback', @EnterTestCal, 'TooltipString', 'Enter measurement', 'CData', MeasurementButtonGFX);

function RunSpecificAmount(varargin)
global BpodSystem
figure(BpodSystem.GUIHandles.LiquidCalibrator.TestSpecificAmtFig);
% In case the GUI has already been used, reset values.
set(BpodSystem.GUIHandles.LiquidCalibrator.EnterMeasurementButton, 'Enable', 'on');
set(BpodSystem.GUIHandles.LiquidCalibrator.ResultsListbox, 'String', cell(1,1), 'Value', 1)
set(BpodSystem.GUIHandles.LiquidCalibrator.MeasuredValveText, 'String', '1')
InvalidParams = 0; % if invalid params are found, this is set to "1" and delivery is skipped

% Figure out which valves to test
ValveLogic = zeros(1,8);
ValveLogic(1) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB1b, 'Value');
ValveLogic(2) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB2b, 'Value');
ValveLogic(3) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB3b, 'Value');
ValveLogic(4) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB4b, 'Value');
ValveLogic(5) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB5b, 'Value');
ValveLogic(6) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB6b, 'Value');
ValveLogic(7) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB7b, 'Value');
ValveLogic(8) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB8b, 'Value');
TargetValves = find(ValveLogic);
% Sanity-check target valves
if isempty(TargetValves)
    InvalidParams = 1;
end
% Figure out amount to test
LiquidAmount = get(BpodSystem.GUIHandles.LiquidCalibrator.SpecificAmtEdit, 'String');
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
    PulseDurations = BpodLiquidCalibration('GetValveTimes', LiquidAmount, TargetValves);
    % Figure out how many pulses to deliver
    nPulses = get(BpodSystem.GUIHandles.LiquidCalibrator.nPulsesDropmenu, 'Value')*100;
    % Set valve request window
    set(BpodSystem.GUIHandles.LiquidCalibrator.MeasuredValveText, 'String', num2str(TargetValves(1)));
    drawnow;
    % Call calibration script
    Completed = RunRewardCal(nPulses, TargetValves, PulseDurations, .2);
else
    warndlg('Invalid settings detected. Check setup.', 'Error', 'modal');
end
if Completed
    % Get measurements
    set(BpodSystem.GUIHandles.LiquidCalibrator.MeasuredAmtEdit, 'String', '', 'Enable', 'on');
    uicontrol(BpodSystem.GUIHandles.LiquidCalibrator.MeasuredAmtEdit);
end

function EnterTestCal(varargin)
global BpodSystem
figure(BpodSystem.GUIHandles.LiquidCalibrator.TestSpecificAmtFig);

ToleranceLevelStrings = get(BpodSystem.GUIHandles.LiquidCalibrator.ToleranceDropmenu, 'String');
ToleranceLevel = str2double(ToleranceLevelStrings{get(BpodSystem.GUIHandles.LiquidCalibrator.ToleranceDropmenu, 'Value')})/100; % Fraction of intended amount by which measured amount is allowed to differ from intended amount

% Figure out which valves were tested
ValveLogic = zeros(1,8);
ValveLogic(1) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB1b, 'Value');
ValveLogic(2) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB2b, 'Value');
ValveLogic(3) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB3b, 'Value');
ValveLogic(4) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB4b, 'Value');
ValveLogic(5) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB5b, 'Value');
ValveLogic(6) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB6b, 'Value');
ValveLogic(7) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB7b, 'Value');
ValveLogic(8) = get(BpodSystem.GUIHandles.LiquidCalibrator.CB8b, 'Value');
TargetValves = find(ValveLogic);

InvalidParams = 0;
MeasuredLiquidAmount = get(BpodSystem.GUIHandles.LiquidCalibrator.MeasuredAmtEdit, 'String');
% Sanity-check liquid amount
if isnan(str2double(MeasuredLiquidAmount))
    InvalidParams = 1;
end
nPulses = get(BpodSystem.GUIHandles.LiquidCalibrator.nPulsesDropmenu, 'Value')*100;
MeasuredLiquidAmount = str2double(MeasuredLiquidAmount);
if (MeasuredLiquidAmount < 0) || (MeasuredLiquidAmount > 1000)
    InvalidParams = 1;
end
IntendedLiquidAmount = get(BpodSystem.GUIHandles.LiquidCalibrator.SpecificAmtEdit, 'String');
IntendedLiquidAmount = str2double(IntendedLiquidAmount);
if InvalidParams == 0
    ValveID = str2double(get(BpodSystem.GUIHandles.LiquidCalibrator.MeasuredValveText, 'String'));
    ListboxMeasurements = get(BpodSystem.GUIHandles.LiquidCalibrator.ResultsListbox, 'String');
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
    set(BpodSystem.GUIHandles.LiquidCalibrator.ResultsListbox, 'String', ListboxMeasurements)
    ValveIDPos = find(TargetValves == ValveID);
    if ValveIDPos < length(TargetValves)
        NextValve = TargetValves(ValveIDPos+1);
        set(BpodSystem.GUIHandles.LiquidCalibrator.MeasuredValveText, 'String', num2str(NextValve));
    else
        set(BpodSystem.GUIHandles.LiquidCalibrator.EnterMeasurementButton, 'Enable', 'off');
    end
else
    warndlg('Invalid liquid amount.', 'Error', 'modal');
end

function EndCal(varargin)
global BpodSystem
if isfield(BpodSystem.GUIHandles, 'LiquidCalibrator')
    try
        delete(BpodSystem.GUIHandles.LiquidCalibrator.MainFig);
    catch
    end
    BpodSystem.GUIHandles = rmfield(BpodSystem.GUIHandles, 'LiquidCalibrator');
end
if isfield(BpodSystem.PluginObjects, 'LiquidCal')
    BpodSystem.PluginObjects = rmfield(BpodSystem.PluginObjects, 'LiquidCal');
end
