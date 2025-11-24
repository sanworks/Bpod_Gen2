function VerifyCOMGUI(BpodSystem)
% Ask the user what to do with mismatching COM port
% obj = VerifyCOMGUI(BpodSystem)
%
% Parameters
% ----------
% BpodSystem : Bpod object
%     The Bpod system object

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

LiquidCal = BpodSystem.CalibrationTables.LiquidCal;  % the handle is extracted for convenience

if BpodLib.multi.isMultiSetup(BpodSystem)
    availableMachines = BpodLib.multi.listMultiSetups(BpodLib.path.getPath('config', BpodSystem, 'setuptype', 'single'));  % we need to look in Config/ for multi setups

    % Multi setup - ask user which machine to import from.
    prompt = {
        sprintf('The Bpod COM port (%s) does not match the', BpodLib.utils.getCurrentCOM(BpodSystem));
        sprintf('liquid calibration file''s COM port (%s).', LiquidCal.metadata.COM);
        'Please select which COM to copy in the liquid';
        'calibration file from:'
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

    % Load calibration from selected machine
    configDir = BpodLib.path.getPath('config', BpodSystem, 'setuptype', 'single');
    filepath = fullfile(configDir, selectedMachine, 'LiquidCalibration.json');
    NewLiquidCal = BpodLib.calibration.liquid.ValveDataManagerClass('filepath', filepath);

    % Update COM port and save to current machine
    NewLiquidCal.metadata.COM = BpodLib.utils.getCurrentCOM(BpodSystem);
    BpodSystem.CalibrationTables.LiquidCal = NewLiquidCal;
    BpodLib.calibration.liquid.io.save(NewLiquidCal.createSaveData(), 'BpodSystem', BpodSystem, 'type', 'statemachine');
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