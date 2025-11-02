function VerifyCOMGUI(BpodSystem)
% Ask the user what to do with mismatching COM port
% obj = VerifyCOMGUI(BpodSystem)
%
% Parameters
% ----------
% BpodSystem : Bpod object
%     The Bpod system object

assert(strcmp(BpodLib.calibration.liquid.utils.checkCOM(BpodSystem), 'no'))
LiquidCal = BpodSystem.CalibrationTables.LiquidCal;  % the handle is extracted for convenience

if BpodLib.multi.isMultiSetup(BpodSystem)
    availableMachines = BpodLib.multi.listMultiSetups(BpodLib.path.getPath('config', BpodSystem, 'setuptype', 'single'));  % we need to look in Config/ for multi setups

    % Multi setup - ask user which machine this is
    prompt = {
        sprintf('The Bpod COM port (%s) does not match the', BpodLib.utils.getCurrentCOM(BpodSystem));
        sprintf('liquid calibration file''s COM port (%s).', LiquidCal.metadata.COM);
        'Please select which machine this Bpod is from the';
        'list below:'
    };
    ignoreOption = 'I will remember to recalibrate. (ignore)';
    options = [{ignoreOption}, availableMachines'];

    [selectionIdx, ok] = listdlg('PromptString', prompt, ...
        'SelectionMode', 'single', ...
        'ListString', options, ...
        'ListSize', [300, 300],...
        'CancelString', 'Ignore');
    if ~ok
        return
    end

    selectedMachine = options{selectionIdx};
    if strcmp(selectedMachine, ignoreOption)
        return
    end

    % Update the calibration file's COM to match the selected machine
    % BpodSytem cannot be fed to save as it will override the COM port.
    LiquidCal.metadata.COM = extractAfter(selectedMachine, 'Machine-');
    filepath = fullfile(BpodLib.path.getPath('calibration', BpodSystem), 'LiquidCalibration.json');
    BpodLib.calibration.liquid.io.save(LiquidCal.createSaveData(), 'filepath', filepath);
else
    % Single setup - ask user what to do
    choice = questdlg(sprintf(['The Bpod COM port (%s) does not match the liquid calibration file''s COM port (%s).\n\n', ...
        'Would you like to re-calibrate or does the calibration file COM need to be updated?'], BpodLib.utils.getCurrentCOM(BpodSystem), LiquidCal.metadata.COM), ...
        'Liquid calibration COM Port Mismatched', ...
        'Update liquid calibration file''s COM to match Bpod', 'I will remember to re-calibrate', ...
        'I will remember to re-calibrate');
    
    % If user closed dialog, treat as cancel
    if isempty(choice)
        return
    end
    if strcmp(choice, 'Update liquid calibration file''s COM to match Bpod')
        LiquidCal.metadata.COM = BpodLib.utils.getCurrentCOM(BpodSystem);
        BpodLib.calibration.liquid.io.save(LiquidCal.createSaveData(), 'BpodSystem', BpodSystem, 'type', 'statemachine');
    end
end
end