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

% PsychToolboxAudio is a class to play sounds using the PC sound card.
% Channels 1+2 are used for audio. Ch3 plays a 1ms voltage pulse to
% synchronize sound onset with a compatible logic or analog acquisition device.
%
% Requirements:
% 1. PsychToolbox must be installed for this plugin to work.
% 2. A compatible sound card is required:
%    -ASUS Xonar DX
%    -ASUS Xonar AE
%    -HTOmega Fenix (strongly preferred)
% 
% Example usage:
% P = PsychToolboxAudio;
% P.load(2, mySound); % Load audio waveform mySound to sound library position 2
% P.play(2);          % Play the sound at library position 2 (non-blocking)
% P.stopAll;          % Stop playback
% clear P             % Clear the object and release the sound hardware

classdef PsychToolboxAudio < handle
    properties
        
    end
    properties (SetAccess = private)
        SamplingRate = 192000;
        MaxSounds = 32;
    end
    properties (Access = private)
        SoundCard
        MasterOutput
        SlaveOutput
        nOutputChannels = 4;
        EmulatorMode = 0;
        isFenix = 0;
    end
    
    methods
        function obj = PsychToolboxAudio(EmulatorModeOverride)
            global BpodSystem % Import the global BpodSystem object
            
            if isprop(BpodSystem, 'EmulatorMode')
                obj.EmulatorMode = BpodSystem.EmulatorMode;
            else
                obj.EmulatorMode = 0;
            end

            if nargin == 1
                obj.EmulatorMode = EmulatorModeOverride;
            end

            if obj.EmulatorMode == 0
                try
                    PsychPortAudio('Verbosity', 0);
                catch
                    error('Error: You must install PsychToolbox on your system to use the PsychToolboxAudio plugin')
                end
                InitializePsychSound(1);
                PsychPortAudio('Close');
                devices = PsychPortAudio('GetDevices');
                DeviceID = -1;
                isXonarDX = 0;
                isWASAPIWinXonar = 0;
                if ispc
                    ASIODevices = ismember({devices(:).HostAudioAPIName}, 'ASIO');
                    WASAPIDevices = ismember({devices(:).HostAudioAPIName}, 'Windows WASAPI');
                    if sum(ASIODevices | WASAPIDevices) == 0
                        error(['Error: Compatible sound card not found. ' char(10) ...
                            'PsychToolboxAudio requires an ASIO-compatible sound card if used with PsychToolbox r3.0.14 or earlier (using ASIO drivers + the old ASIO-compatible DLL).' char(10) ...
                            'With PsychToolbox r3.0.15 or newer, you must use a WASAPI-compatible sound card.'])
                    end
                    asioList = find(ASIODevices);
                    wasapiList = find(WASAPIDevices);
                    CandidateDevices = [asioList wasapiList];
                    deviceType = [zeros(1,length(asioList)) ones(1,length(wasapiList))];
                    CardFound = 0; i = 0; 
                    while (CardFound == 0) && (i < length(CandidateDevices))
                        i = i + 1;
                        if devices(CandidateDevices(i)).NrOutputChannels > 3
                            if isempty(strfind(devices(CandidateDevices(i)).DeviceName, 'SPDIF'))
                                CardFound = 1;
                                DeviceID = devices(CandidateDevices(i)).DeviceIndex;
                                if deviceType(i) == 1
                                    if ~isempty(strfind(devices(CandidateDevices(i)).DeviceName, 'XONAR'))
                                        isWASAPIWinXonar = 1;
                                    end
                                    if ~isempty(strfind(devices(CandidateDevices(i)).DeviceName, 'FENIX'))
                                        obj.isFenix = 1;
                                    end
                                end
                            end
                        else
                            if deviceType(i) == 1 
                                if (~isempty(strfind(lower(devices(CandidateDevices(i)).DeviceName), 'xonar dx')) || (~isempty(strfind(lower(devices(CandidateDevices(i)).DeviceName), 'xonar dsx'))))
                                    isXonarDX = 1;
                                end
                            end
                        end
                    end
                elseif ismac
                    error('Error: the PsychToolboxAudio plugin is not supported on OS X.')
                else
                    CardFound = 0;
                    nDevices = length(devices);
                    for i = 1:nDevices
                        if CardFound == 0
                            DeviceName = devices(i).DeviceName;
                            if sum(strcmpi(DeviceName(1:4), {'XONA', 'ASUS'})) > 0 % Assumes ASUS Xonar series
                                if devices(i).NrOutputChannels > 3
                                    CardFound = 1;
                                    DeviceID = devices(i).DeviceIndex;
                                end
                            end
                        end
                    end
                end
                if DeviceID == -1
                    if isXonarDX == 1 && ispc
                        error(['Error: ASUS Xonar DX and DSX are not supported with the latest version of PsychToolbox.' char(10) 'There are two ways to fix this: ' char(10) '1. Switch to the HTOmega FENIX sound card OR' char(10) '2. Downgrade PsychToolbox to v3.0.14 and contact support@sanworks.io for a software patch.']);
                        
                    else
                        error('Error: A compatible sound card was not found.')
                        
                    end
                end
                if isWASAPIWinXonar
                    bufferSize = obj.SamplingRate/100; % A larger buffer is used with Xonar AE and SE to prevent underruns on some systems (tested on Lenovo M920T Win10 Corei5 8GB RAM)
                else
                    bufferSize = 32;
                end
                obj.MasterOutput = PsychPortAudio('Open', DeviceID, 9, 4, obj.SamplingRate, obj.nOutputChannels , bufferSize);
                PsychPortAudio('Start', obj.MasterOutput, 0, 0, 1);
                for i = 1:obj.MaxSounds
                    obj.SlaveOutput(i) = PsychPortAudio('OpenSlave', obj.MasterOutput);
                end
                Data = zeros(obj.nOutputChannels,obj.SamplingRate/1000);
                PsychPortAudio('FillBuffer', obj.SlaveOutput(1), Data);
                PsychPortAudio('Start', obj.SlaveOutput(1));
            else
                % Set up sound server in emulator mode
                BpodSystem.PluginObjects.SoundServer = struct;
                BpodSystem.PluginObjects.SoundServer.Sounds = cell(1,32);
                BpodSystem.PluginObjects.SoundServer.Enabled = 1;
                try
                    sound(zeros(1,10), 48000);
                catch
                    BpodSystem.PluginObjects.SoundServer.Enabled = 0;
                    error('Error starting the emulator sound server. Some platforms do not support sound in MATLAB. See "doc sound" for more details.')
                end
            end
        end
        function load(obj, soundIndex, waveform)
            global BpodSystem
            Siz = size(waveform);
            if Siz(1) > 2
                error('Sound data must be a row vector');
            end
            if soundIndex > obj.MaxSounds
                error(['The PsychToolboxAudio plugin currently supports only ' num2str(obj.MaxSounds) ' sounds.'])
            end
            if obj.EmulatorMode == 0
                if obj.isFenix
                    waveform = waveform*.75; % To avoid saturation
                end
                if Siz(1) == 1 % If mono, send the same signal on both channels
                    waveform(2,:) = waveform;
                end
                % Add a 1ms sync pulse on ch3+4 (center L and center R)
                waveform(3:obj.nOutputChannels,:) = zeros(obj.nOutputChannels-2,Siz(2));
                waveform(3:obj.nOutputChannels,1:(obj.SamplingRate/1000)) = ones(obj.nOutputChannels-2,(obj.SamplingRate/1000));
                PsychPortAudio('FillBuffer', obj.SlaveOutput(soundIndex), waveform);
            else
                if Siz(1) == 1 % If mono, send the same signal on both channels
                    R = rem(length(waveform), 4); % Trim for down-sampling
                    if R > 0
                        waveform = waveform(1:length(waveform)-R);
                    end
                    waveform = mean(reshape(waveform, 4, length(waveform)/4)); % Down-sample 192kHz to 48kHz (only once for mono)
                    waveform(2,:) = waveform;
                else
                    R = rem(length(waveform(1,:)), 4); % Trim for down-sampling
                    if R > 0
                        Data1 = waveform(1,1:length(waveform(1,:))-R);
                    else
                        Data1 = waveform(1,:);
                    end
                    R = rem(length(waveform(2,:)), 4); % Trim for down-sampling
                    if R > 0
                        Data2 = waveform(2,1:length(waveform(2,:))-R);
                    else
                        Data2 = waveform(2,:);
                    end
                    waveform = zeros(1,length(Data1)/4);
                    waveform(1,:) = mean(reshape(Data1, 4, length(Data1)/4)); % Down-sample 192kHz to 48kHz
                    waveform(2,:) = mean(reshape(Data2, 4, length(Data2)/4)); % Down-sample 192kHz to 48kHz
                end
                BpodSystem.PluginObjects.SoundServer.Sounds{soundIndex} = waveform;
            end
        end

        function play(obj, soundIndex)
            global BpodSystem
            if soundIndex <= obj.MaxSounds
                if obj.EmulatorMode == 0
                    PsychPortAudio('Start', obj.SlaveOutput(soundIndex));
                else
                    sound(BpodSystem.PluginObjects.SoundServer.Sounds{soundIndex}, 48000);
                end
            else
                error(['The PsychToolboxAudio plugin currently supports only ' num2str(obj.MaxSounds) ' sounds.'])
            end
        end

        function stop(obj, soundIndex)
            if obj.EmulatorMode == 0
                PsychPortAudio('Stop', obj.SlaveOutput(soundIndex));
            else
                clear playsnd
            end
        end

        function stopAll(obj)
            if obj.EmulatorMode == 0
                for i = 1:obj.MaxSounds
                    PsychPortAudio('Stop', obj.SlaveOutput(i));
                end
            else
                clear playsnd
            end
        end

        function delete(obj)
            global BpodSystem
            obj.stopAll();
            PsychPortAudio('Close');
            if obj.EmulatorMode == 1
                BpodSystem.PluginObjects = rmfield(BpodSystem.PluginObjects, 'SoundServer');
            end
        end
        
    end
end