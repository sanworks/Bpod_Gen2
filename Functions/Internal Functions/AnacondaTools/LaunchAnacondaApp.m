%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2021 Sanworks LLC, Rochester, New York, USA

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

% LaunchAnacondaApp detects the system's default Anaconda installation, and
% launches a specific .py file in a specific environment.
%
% Arguments:
%
% Path: The complete path to the target folder where your .py file is, 
% including the filename and extension
%
% Env: The name of the anaconda environment to use. Use 'base' for the
% default environment. If a full path is not given, the environment must
% reside in .../Anaconda3/envs/

function LaunchAnacondaApp(Env, FolderPath, Commands)
CondaPath = FindAnaconda();
if strcmpi(Env, 'base')
    EnvStr = [];
else
    EnvStr = fullfile(CondaPath, 'envs', Env);
end
LaunchCommand = ['chcp 1252 & call ' fullfile(CondaPath, 'Scripts', 'activate') ' '...
                EnvStr ' & cd "' FolderPath '" & python'];
nCommands = length(Commands);
for i = 1:nCommands
    LaunchCommand = [LaunchCommand ' & ' Commands{i}];
end
system(LaunchCommand);