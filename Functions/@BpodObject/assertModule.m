%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2022 Sanworks LLC, Rochester, New York, USA

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

% Returns an error if any modules in ModuleNames are not registered with
% the state machine. Note: the 'Refresh' button on the console GUI
% registers newly connected modules.
% Optional argument 'USBParied' will return an error if all modules in
% ModuleNames are not paired with their respective USB serial ports (see 'USB' button on the console GUI)
%
% Example Usage: 
% BpodSystem.AssertModule('ValveDriver'); % Does not have to be USB paired
% BpodSystem.AssertModule({'HiFi', RotaryEncoder}, 'USBPaired');

function obj = assertModule(obj, ModuleNames, varargin)
    USBParied = 0;
    if nargin > 2
        optArg = varargin{1};
        if ischar(optArg)
            if strcmp(lower(optArg), 'usbpaired')
                USBParied = 1;
            end
        end
    end
    if ischar(ModuleNames)
        ModuleNames = {ModuleNames};
    end
    nModules = length(ModuleNames);
    for i = 1:nModules
        ThisModule = [ModuleNames{i} '1'];
        if sum(strcmp(obj.Modules.Name, ThisModule)) == 0
            error(['Bpod ' ModuleNames{i} ' module not found.' char(10) 'Connect the module to a state machine ''Module'' port and click the ''refresh'' icon on the Bpod console.'])
        end
        if USBParied
            if ~isfield(obj.ModuleUSB, ThisModule)
                error(['Error: To run this protocol, you must first pair the ' ModuleNames{i} ' module with its USB port.' char(10) 'Click the USB config button on the Bpod console.'])
            end
        end
    end
end