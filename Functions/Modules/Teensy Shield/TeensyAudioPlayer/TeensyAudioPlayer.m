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

% This class is a minimally revised version of the original 
% Teensy audio player for Bpod 0.5, for backwards compatability
% with labs that still use it. JS 2017

classdef TeensyAudioPlayer < handle
    properties
        Port % ArCOM Serial port
        Info % Struct with info about player
    end

    properties (SetAccess = protected)
        FirmwareVersion = 0;
    end

    properties (Access = private)
        LocalFolder
        TempFile
    end

    methods
        function obj = TeensyAudioPlayer(portString)
            obj.Port = ArCOMObject_Bpod(portString, 115200);
            obj.LocalFolder = fileparts(which('TeensyAudioPlayer'));
            obj.TempFile = fullfile(obj.LocalFolder, 'temp.wav');
            obj.Info = struct;
            obj.Info.ExpectedSamplingRate = 44100;
        end

        function load(obj, Index, WaveData)
            audiowrite(obj.TempFile, WaveData, 44100,'BitsPerSample', 16);
            f = fopen(obj.TempFile);
            fileData = fread(f);
            fclose(f);
            obj.Port.write(['F' Index], 'uint8', length(fileData), 'uint32', fileData, 'uint8');
        end

        function play(obj, index)
            obj.Port.write(['S' index], 'uint8');
        end

        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
end