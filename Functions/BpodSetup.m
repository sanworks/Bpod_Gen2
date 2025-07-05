function BpodSetup(operation, varargin)
% Interact with Bpod setup and configuration.
% BpodSetup(operation, _)
% 
% Examples
% --------
% BpodSetup updatesettings > Updates the Bpod configuration settings.
% BpodSetup multisetup > Creates a multi-setup configuration.

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

global BpodSystem

if nargin == 0
    BpodSetup('help')
    return
end

switch lower(operation)
    case 'help'
        help('BpodSetup')
    case 'updatesettings'
        % Settings folder to Config folder
        fprintf('This will convert\nBpod Local/\n├─ Data/\n├─ Protocols/\n├─ Calibration Files/\n│  ├─ LiquidCalibration.json\n│  ├─ SoundCalibration.mat\n├─ Settings/\n│  ├─ BpodSettings.mat\n│  ├─ InputConfig.mat\n│  ├─ ModuleUSBConfig.mat\n│  ├─ SyncConfig.mat\n')
        fprintf('    to \nBpod Local/\n├─ Data/\n├─ Protocols/\n├─ Config/\n│  ├─ LiquidCalibration.json\n│  ├─ SoundCalibration.mat\n│  ├─ BpodSettings.mat\n│  ├─ InputConfig.mat\n│  ├─ ModuleUSBConfig.mat\n│  ├─ SyncConfig.mat\n')
        answer = input('Do you want to update the Bpod configuration? (yes/no): ', 's');
        if strcmpi(answer, 'yes')
            % Update the Bpod configuration
            BpodLib.BpodObject.setup.compatibility.convertSettingsFolder(BpodSystem, 'verbose', true);
        else
            disp('Bpod configuration update cancelled.');
        end
    case 'multisetup'
        % Create a multi-setup configuration
        BpodLib.multi.createMultiSetup(BpodSystem);
    otherwise
        error('BpodLib:Utils:UpdateBpodConfig:InvalidOperation', ...
            'Operation "%s" is not recognized. Use "updatesettings" to update the Bpod configuration.', operation);
end

end

