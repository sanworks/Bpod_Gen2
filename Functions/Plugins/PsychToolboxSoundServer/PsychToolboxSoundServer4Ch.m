%{
----------------------------------------------------------------------------

This file is part of the Bpod Project
Copyright (C) 2016 Joshua I. Sanders, Sanworks LLC

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

% This version of PsychToolboxSoundServer is modified to accept up to 4
% channels of sound data (a 4xN array), to control 4 separate speakers. 
function PsychToolboxSoundServer4Ch(Function, varargin)
global BpodSystem
SF = 192000; % Sound card sampling rate
nSlaves = 32;
Function = lower(Function);
switch Function
    case 'init'
        if BpodSystem.EmulatorMode == 0
            if ~isfield(BpodSystem.SystemSettings, 'SoundDeviceID')
                BpodSystem.SystemSettings.SoundDeviceID = [];
            end
            PsychPortAudio('Verbosity', 0);
            if isfield(BpodSystem.PluginObjects, 'SoundServer')
                try
                    PsychPortAudio('Close', BpodSystem.PluginObjects.SoundServer);
                catch
                end
            else
                InitializePsychSound(1);
            end
            PsychPortAudio('Close');
            AudioDevices = PsychPortAudio('GetDevices');
            nDevices = length(AudioDevices);
            CandidateDevices = []; nCandidates = 0;
            if ispc
                for x = 1:nDevices
                    if strcmp(AudioDevices(x).HostAudioAPIName, 'ASIO')
                        if AudioDevices(x).NrOutputChannels == 8
                            nCandidates = nCandidates + 1;
                            CandidateDevices(nCandidates) = AudioDevices(x).DeviceIndex;
                        end
                    end
                end
            elseif ismac
            else
                for x = 1:nDevices
                    DeviceName = AudioDevices(x).DeviceName;
                    if ~isempty(strfind(DeviceName, 'Xonar DX: Multichannel')) || ~isempty(strfind(DeviceName, 'Xonar U7: USB Audio')) % Assumes ASUS Xonar DX or U7 Soundcard
                        if AudioDevices(x).NrOutputChannels == 8
                            nCandidates = nCandidates + 1;
                            CandidateDevices(nCandidates) = AudioDevices(x).DeviceIndex;
                        end
                    end
                end
            end
            
            if nCandidates > 0
                for x = 1:nCandidates
                    disp(['Candidate device found! Trying candidate ' num2str(x) ' of ' num2str(nCandidates)])
                    try
                        CandidateDevice = PsychPortAudio('Open', CandidateDevices(x), 9, 4, SF, 6 , 32);
                        BpodSystem.SystemSettings.SoundDeviceID = CandidateDevices(x);
                        SaveBpodSystemSettings;
                        PsychPortAudio('Close', CandidateDevice);
                        disp('Success! A compatible sound card was detected and stored in Bpod settings.')
                    catch
                        
                    end
                end
            else
                disp('Error: no compatible sound subsystem detected. On Windows, ensure ASIO drivers are installed.')
            end
            BpodSystem.PluginObjects.SoundServer.MasterOutput = PsychPortAudio('Open', BpodSystem.SystemSettings.SoundDeviceID, 9, 4, SF, 6 , 32);
            PsychPortAudio('Start', BpodSystem.PluginObjects.SoundServer.MasterOutput, 0, 0, 1);
            for x = 1:nSlaves
                BpodSystem.PluginObjects.SoundServer.SlaveOutput(x) = PsychPortAudio('OpenSlave', BpodSystem.PluginObjects.SoundServer.MasterOutput);
            end
            Data = zeros(6,192);
            PsychPortAudio('FillBuffer', BpodSystem.PluginObjects.SoundServer.SlaveOutput(1), Data);
            PsychPortAudio('Start', BpodSystem.PluginObjects.SoundServer.SlaveOutput(1));
            disp('PsychToolbox sound server successfully initialized.')
        else
            if isfield(BpodSystem.PluginObjects, 'SoundServer')
                try
                    PsychPortAudio('Close', BpodSystem.PluginObjects.SoundServer);
                catch
                end
            end
            % Set up sound server in emulator mode
            BpodSystem.PluginObjects.SoundServer = struct;
            BpodSystem.PluginObjects.SoundServer.Sounds = cell(1,32);
            BpodSystem.PluginObjects.SoundServer.Enabled = 1;
            try
                sound(zeros(1,10), 48000);
                disp('Emulator sound server successfully initialized.')
            catch
                BpodSystem.PluginObjects.SoundServer.Enabled = 0;
                disp('Error starting the emulator sound server. Some platforms do not support sound in MATLAB. See "doc sound" for more details.')
            end
        end
    case 'close'
        if BpodSystem.EmulatorMode == 0
            PsychPortAudio('Close');
            disp('PsychToolbox sound server successfully closed.')
        else
            BpodSystem.PluginObjects = rmfield(BpodSystem.PluginObjects, 'SoundServer');
            disp('Emulator sound server successfully closed.')
        end
    case 'load'
        SlaveID = varargin{1};
        Data = varargin{2};
        Siz = size(Data);
        if Siz(1) > 2
            error('Sound data must be a row vector');
        end
        if BpodSystem.EmulatorMode == 0
            switch Siz(1)
                case 1 % If mono, send the same signal on all 4 channels
                    Data(2:4,:) = Data;
                case 2 % If stereo, duplicate the first 2 channels on Ch3-4
                    Data(3:4,:) = Data;
            end
            Data(5:6,:) = zeros(2,Siz(2));
            Data(5:6,1:(SF/1000)) = ones(2,(SF/1000));
            PsychPortAudio('FillBuffer', BpodSystem.PluginObjects.SoundServer.SlaveOutput(SlaveID), Data);
        else
            % Note: This code will fail in emulator mode because MATLAB's sound function does not
            % support more than 2 channels.
            if Siz(1) == 1 % If mono, send the same signal on both channels
                R = rem(length(Data), 4); % Trim for down-sampling
                if R > 0
                    Data = Data(1:length(Data)-R);
                end
                Data = mean(reshape(Data, 4, length(Data)/4)); % Down-sample 192kHz to 48kHz (only once for mono)
                Data(2,:) = Data;
            else
                R = rem(length(Data(1,:)), 4); % Trim for down-sampling
                if R > 0
                    Data1 = Data(1,1:length(Data(1,:))-R);
                else
                    Data1 = Data(1,:);
                end
                R = rem(length(Data(2,:)), 4); % Trim for down-sampling
                if R > 0
                    Data2 = Data(2,1:length(Data(2,:))-R);
                else
                    Data2 = Data(2,:);
                end
                Data = zeros(1,length(Data1)/4);
                Data(1,:) = mean(reshape(Data1, 4, length(Data1)/4)); % Down-sample 192kHz to 48kHz
                Data(2,:) = mean(reshape(Data2, 4, length(Data2)/4)); % Down-sample 192kHz to 48kHz
            end
            BpodSystem.PluginObjects.SoundServer.Sounds{SlaveID} = Data;
        end
    case 'play'
        SlaveID = varargin{1};
        if SlaveID < nSlaves+1
            if BpodSystem.EmulatorMode == 0
                PsychPortAudio('Start', BpodSystem.PluginObjects.SoundServer.SlaveOutput(SlaveID));
            else
                sound(BpodSystem.PluginObjects.SoundServer.Sounds{SlaveID}, 48000);
            end
        else
            error(['The psychtoolbox sound server currently supports only ' num2str(nSlaves) ' sounds.'])
        end
    case 'stop'
        if BpodSystem.EmulatorMode == 0
            SlaveID = varargin{1};
            PsychPortAudio('Stop', BpodSystem.PluginObjects.SoundServer.SlaveOutput(SlaveID));
        else
            clear playsnd
        end
    case 'stopall'
        for x = 1:nSlaves
            if BpodSystem.EmulatorMode == 0
                PsychPortAudio('Stop', BpodSystem.PluginObjects.SoundServer.SlaveOutput(x));
            else
                clear playsnd;
            end
        end
    otherwise
        error([Function ' is an invalid op code for PsychToolboxSoundServer.'])
end