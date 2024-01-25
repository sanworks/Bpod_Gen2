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

% BpodObject.assertModule() returns an error if any modules in ModuleNames are not registered with
% the state machine. Note: the 'Refresh' button on the console GUI
% registers newly connected modules.
%
% Arguments:
% ModuleNames (cell array) a list of module names to assert. Module names are given in BpodObject.Modules.Name
%
% USBParied (optional) is an array of 1s and 0s indicating which module(s) must be paired with their respective
% USB serial ports (see 'USB' button on the console GUI)
%
% Example Usage:
% BpodSystem.AssertModule('ValveDriver'); % Does not have to be USB paired
% BpodSystem.AssertModule({'HiFi', 'ValveDriver'}, [1 0]); % HiFi must be USB paired, but ValveDriver does not

function obj = assertModule(obj, moduleNames, varargin)

% If a single module name is passed as a string, package to cell array
if ischar(moduleNames)
    moduleNames = {moduleNames};
end

% Ensure not running Bpod in emulator mode
if obj.EmulatorMode == 1
    error([moduleNames{1} ' module not found.' char(10)...
        'Only the state machine''s onboard channels are currently supported by the emulator.']) %#ok newline requires r2016b but Bpod supports back to r2013a
end

% Generate list of modules that must be USB-paired
nModules = length(moduleNames);
usbParied = zeros(1,nModules);
if nargin > 2
    optArg = varargin{1};
    if length(optArg) ~= nModules
        error('Error using assertModule: if a USB pairing vector is supplied, there must be one value per module')
    end
    usbParied = optArg;
end

% Assert modules
for i = 1:nModules
    thisModule = [moduleNames{i} '1'];
    if sum(strcmp(obj.Modules.Name, thisModule)) == 0
        error(['Bpod ' moduleNames{i} ' module not found.' char(10)...
            'Connect the module to a state machine ''Module'' port and click the ''refresh'' icon on the Bpod console.'])
    end
    if usbParied(i)
        if ~isfield(obj.ModuleUSB, thisModule)
            error(['Error: To run this protocol, you must first pair the ' moduleNames{i}...
                ' module with its USB port.' char(10) 'Click the USB config button on the Bpod console.'])
        end
    end
end
end