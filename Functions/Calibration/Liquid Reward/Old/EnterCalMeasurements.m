function EnterCalMeasurements
global BpodSystem
handles=guidata(LiquidCalibrationManager);
figure(handles.RunMeasurementsFig);


% Create a vector of measurements to test
ValveIDs = [];
PulseDurations = [];
for x = 1:8
    if ~isempty(handles.PendingMeasurements{x})
        ValveIDs = [ValveIDs x];
        PulseDurations = [PulseDurations handles.PendingMeasurements{x}(1)];
    end
end
nValidMeasurements = length(ValveIDs);
CurrentAmounts = nan(1,nValidMeasurements);
% Extract measured amounts from textboxes. Error if invalid.
AllValid = 1;
for x = 1:nValidMeasurements
    eval(['CurrentAmounts(' num2str(x) ') = str2double(get(handles.CB' num2str(ValveIDs(x)) 'b, ''String''));'])
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
%CurrentAmounts = CurrentAmounts*10; % FIND ACTUAL CONV
CurrentAmounts = CurrentAmounts*1000/str2double(handles.nPulses_edit.String); % FIND ACTUAL CONV


if AllValid == 1
    % Update cal table on HD and in GUI handles
    for x = 1:nValidMeasurements
        % Add or append to table
        CurrentTable = handles.LiquidCal(ValveIDs(x)).Table;
        if isempty(CurrentTable)
            CurrentTable = [PulseDurations(x) CurrentAmounts(x)];
        else
            m = [PulseDurations(x) CurrentAmounts(x)];
            CurrentTable = [CurrentTable; m];
        end
        handles.LiquidCal(ValveIDs(x)).Table = CurrentTable;
        % Calculate coeffs
        MeasuredAmounts = CurrentTable(:,2)';
        ValveDurations = CurrentTable(:,1)';
        nMeasurements = length(MeasuredAmounts);
        if nMeasurements > 2
            handles.LiquidCal(ValveIDs(x)).TrinomialCoeffs = polyfit(MeasuredAmounts, ValveDurations, 3);
        elseif nMeasurements > 1
            handles.LiquidCal(ValveIDs(x)).TrinomialCoeffs = polyfit(MeasuredAmounts, ValveDurations, 2);
        else
            handles.LiquidCal(ValveIDs(x)).TrinomialCoeffs = [];
        end
%         if (nMeasurements) > 2
%             handles.LiquidCal(ValveIDs(x)).TrinomialCoeffs = polyfit(handles.LiquidCal(ValveIDs(x)).Table(:,2),handles.LiquidCal(ValveIDs(x)).Table(:,1),3);
%         else
%             handles.LiquidCal(ValveIDs(x)).TrinomialCoeffs = [];
%         end
    end
    k =  5;
    % Remove pending measurements (preserving any more that were set for future
    % rounds)
    PendingMeasurements = handles.PendingMeasurements;
    for x = 1:nValidMeasurements
        if length(PendingMeasurements{ValveIDs(x)}) > 1
            Measurements = PendingMeasurements{ValveIDs(x)};
            Measurements = Measurements(2:length(Measurements));
            PendingMeasurements{ValveIDs(x)} = Measurements;
        else
            PendingMeasurements{ValveIDs(x)} = [];
        end
    end
    handles.PendingMeasurements = PendingMeasurements;
    guidata(LiquidCalibrationManager, handles);
    % Call the Listbox 1 call back in
    % LiquidCalibrationManager to reflect the new pending measurements vector
    LiquidCalibrationManager('listbox1_Callback', LiquidCalibrationManager,[], handles)
    % Save file
    TestSavePath = fullfile(BpodSystem.Path.BpodRoot, 'Calibration Files');
    if exist(TestSavePath) ~= 7
        mkdir(TestSavePath);
    end
    SavePath = fullfile(BpodPath, 'Calibration Files', 'LiquidCalibration.mat');
    LiquidCal = handles.LiquidCal;
    LiquidCal(1).LastDateModified = now;
    save(SavePath, 'LiquidCal');
    BpodSystem.CalibrationTables.LiquidCal = LiquidCal;
    msgbox('Calibration files updated.', 'modal')
    close(handles.RunMeasurementsFig);
end