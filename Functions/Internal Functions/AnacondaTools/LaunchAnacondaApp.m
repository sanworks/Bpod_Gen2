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

% LaunchAnacondaApp() detects the system's default Anaconda installation, and
% launches a specific .py file in a specific environment.
%
% Arguments:
% env: The name of the anaconda environment to use. Use 'base' for the
% default environment. If a full path is not given, the environment must
% reside in .../Anaconda3/envs/
%
% folderPath: The complete path to the target folder where your .py file is, 
% including the filename and extension
%
% commands: A cell array with commands to add to the system call


function LaunchAnacondaApp(env, folderPath, commands)
condaPath = FindAnaconda();
if strcmpi(env, 'base')
    EnvStr = [];
else
    EnvStr = fullfile(condaPath, 'envs', env);
end
launchCommand = ['chcp 1252 & call ' fullfile(condaPath, 'Scripts', 'activate') ' '...
                EnvStr ' & cd "' folderPath '" & python'];
nCommands = length(commands);
for i = 1:nCommands
    launchCommand = [launchCommand ' & ' commands{i}];
end
system(launchCommand);