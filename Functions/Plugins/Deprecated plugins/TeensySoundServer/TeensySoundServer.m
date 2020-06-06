%{
----------------------------------------------------------------------------

This file is part of the Bpod Project
Copyright (C) 2014 Joshua I. Sanders, Cold Spring Harbor Laboratory, NY, USA

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
function TeensySoundServer(op, varargin)
global BpodSystem
if isempty(BpodSystem)
    error('Error: You must run Bpod() before you can use TeensySoundServer');
end
Message = lower(op);
switch Message
    case 'init'
        % Syntax: TeensySoundServer('init', SerialPort); % example SerialPort = 'COM3' 
        SerialPort = varargin{1};
        BpodSystem.PluginSerialPorts.TeensySoundServer = serial(SerialPort, 'BaudRate', 115200, 'Timeout', 10, 'DataTerminalReady', 'on', 'OutputBufferSize', 50000000);
        fopen(BpodSystem.PluginSerialPorts.TeensySoundServer);
        disp(['TeensySoundServer found on port ' SerialPort '.' char(10) 'Please remember to run TeensySoundServer(''end'') before closing Bpod.']);
    case 'loadwaveform'
        % Syntax: TeensySoundServer('loadwaveform', index, data);
        Index = varargin{1};
        WaveData = varargin{2};
        TempDir = fullfile(BpodSystem.Path.LocalDir, 'Temp');
        mkdir(TempDir); % Fails silently if it exists
        FilePath = fullfile(BpodSystem.Path.LocalDir, 'Temp', 'temp.wav');
        audiowrite(FilePath, WaveData', 44100,'BitsPerSample', 16);
        F = fopen(FilePath);
        FileData = fread(F);
        fclose(F);
        fwrite(BpodSystem.PluginSerialPorts.TeensySoundServer, 'F');
        fwrite(BpodSystem.PluginSerialPorts.TeensySoundServer, Index, 'uint8');
        fwrite(BpodSystem.PluginSerialPorts.TeensySoundServer, length(FileData), 'uint32');
        fwrite(BpodSystem.PluginSerialPorts.TeensySoundServer, FileData, 'uint8');
    case 'loadfile'
        % Syntax: TeensySoundServer('loadfile', index, filepath);
        Index = varargin{2};
        FilePath = varargin{3};
        F = fopen(FilePath);
        FileData = fread(F);
        fclose(F);
        fwrite(BpodSystem.PluginSerialPorts.TeensySoundServer, 'F');
        fwrite(BpodSystem.PluginSerialPorts.TeensySoundServer, Index, 'uint8');
        fwrite(BpodSystem.PluginSerialPorts.TeensySoundServer, length(FileData), 'uint32');
        fwrite(BpodSystem.PluginSerialPorts.TeensySoundServer, FileData, 'uint8');
    case 'play'
        % Syntax: TeensySoundServer('play', index);
        Index = varargin{1};
        fwrite(BpodSystem.PluginSerialPorts.TeensySoundServer, ['S' Index]);
    case 'end'
        % Syntax: TeensySoundServer('end');
        fclose(BpodSystem.PluginSerialPorts.TeensySoundServer);
        delete(BpodSystem.PluginSerialPorts.TeensySoundServer);
        BpodSystem.PluginSerialPorts = rmfield(BpodSystem.PluginSerialPorts, 'TeensySoundServer');
    otherwise
        error('Error: Invalid op. Valid ops are: init, loadwaveform, loadfile, play, end');
end