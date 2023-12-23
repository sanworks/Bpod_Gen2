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
% Example usage:
% H = HARPSoundCard
% H.loadSound(Index, Waveform, SamplingRate)
% H.play(Index)
%
% Index range: [2 32]
% Waveform: Audio vector with samples in range [-1, 1]
% SamplingRate: Either 96000 or 192000
%
% clear H % Clear object

classdef HARPSoundCard < handle
    properties
        
    end
    properties (Access = private)
        CMDPort
        DataPort
        Path
        Amp24Bits
        UsePsychToolbox
        forceJava
        ServerProcessName = 'server_v1.0.exe'; % Hard-coded fallback, overwritten by code below
    end
    methods
        function obj = HARPSoundCard(portString, varargin)
            if ~ispc
                error('Error: The HARP Sound Card Interface currently requires Windows 7-10.');
            end
            % Try to find the server in its default location
            [Status, DocumentsPath] = system('powershell -Command "[Environment]::GetFolderPath(''MyDocuments'')');
            DocumentsPath = DocumentsPath(1:end-1); % Trim off hard return
            ServerPath = fullfile(DocumentsPath, 'HarpSoundCard', 'Interface TCP');
            Contents = dir(ServerPath);
            ExeName = [];
            for i = 1:length(Contents)
                if ~isempty(strfind(Contents(i).name, '.exe'))
                    ExeName = Contents(i).name;
                end
            end
            if ~isempty(ExeName)
                ServerPath = fullfile(ServerPath, ExeName);
                obj.ServerProcessName = ExeName;
            end
        % Make sure TCP server is running
        [status,result] = system(['tasklist /FI "imagename eq ' obj.ServerProcessName '" /fo table /nh']);
        if isempty(strfind(result, obj.ServerProcessName))
            try
                if ~isempty(ExeName)
                    [Ack, Msg] = system(['start "" "' ServerPath '"']);
                    pause(.3);
                end
            catch
                error('Error: You must open the HARP Sound Card TCP Server before creating a HARP Sound Card object.')
            end
        end
        obj.forceJava = 0;
        if nargin > 1
            useJava = varargin{1};
            if strcmp(useJava, 'forcejava')
                obj.CMDPort = ArCOMObject_Bpod(portString, 1000000, 'Java');
                obj.forceJava = 1;
            else
                obj.CMDPort = ArCOMObject_Bpod(portString, 1000000);
            end
        else
            obj.CMDPort = ArCOMObject_Bpod(portString, 1000000);
        end
        obj.UsePsychToolbox = 0;
        if obj.forceJava == 0
            try
                PsychtoolboxVersion;
                obj.UsePsychToolbox = 1;
            catch
                if ~license('test','instr_control_toolbox')
                    error('Error: You must have either PsychToolbox or MATLAB Instrument Control Toolbox installed to access the HARP Sound Card');
                end
            end
        end
        if obj.UsePsychToolbox == 0
            obj.DataPort = tcpip('127.0.0.1', 9999, 'InputBufferSize', 1000000, 'OutputBufferSize', 100000000, 'Timeout', 3);
            fopen(obj.DataPort); pause(.1); fclose(obj.DataPort); % Check to make sure the port can be opened
        else
            obj.DataPort = pnet('tcpconnect','127.0.0.1',9999);
            pause(.1);
            pnet(obj.DataPort,'close');
        end
        
        obj.Amp24Bits = pow2(31) - 1;
    end
    function loadSound(obj, Index, Waveform, SamplingRate)
    if Index < 2 || Index > 32
        error('Error: Sound index must be in range [2, 32]')
    end
    Index = round(Index);
    if max(Waveform(:)) > 1 || min(Waveform(:)) < -1
        error('Error: Waveform samples must be in range [-1, 1]')
    end
    if ~(SamplingRate == 96000 || SamplingRate == 192000)
        error('Error: Sampling rate must be either 96000 or 192000')
    end
    [L, W] = size(Waveform);
    if ~((L == 1) || (L == 2))
        error('Error: Waveform must be a 1xn or 2xn vector of samples');
    end
    if L == 1
        Waveform = [Waveform; Waveform];
    end
    Waveform = int32(Waveform*obj.Amp24Bits);
    AudioData = typecast(Waveform(1:end), 'uint8');
    nAudioDataBytes = length(AudioData);
    if nAudioDataBytes > 8000000
        disp('***************');
        disp(['Warning: Max audio data size exceeded for sound index ' num2str(Index) '. Max size for a single sound is 8MB (10.922s at 96kHz, 5.461s at 192kHz).' char(10)...
            'Data for sound# ' num2str(Index) ' will overwrite sound data at the subsequent index(es). However you can safely use alternating indexes if you need long sounds.']);
        disp('***************');
    end
    nCompletePackets = floor(nAudioDataBytes/32768); % Note: length(waveform) assumes stereo is already interleaved
    nDataBytesInFinalPacket = length(AudioData) - (nCompletePackets*32768);
    OutData = zeros(1,22+(32780*(nCompletePackets+1)), 'int8'); % Initialize output vector
    InitialCmd = [[2 20 130 255 1] typecast(uint32([Index, W*2, SamplingRate, 0]), 'uint8')];
    Checksum = rem(sum(InitialCmd), 256);
    HeaderMessage = typecast(uint8([InitialCmd Checksum]), 'int8');
    OutData(1:22) = HeaderMessage;
    OutDataPos = 23;
    DataCmd = zeros(1, 32780);
    DataCmd(1:7) = [2 255 4 128 132 255 132];
    PacketNumber = 0;
    DataPos = 1;
    
    for p = 1:nCompletePackets+1
        if p == nCompletePackets+1
            nDataBytesInPacket = nDataBytesInFinalPacket;
            DataCmd(12:end) = 0;
        else
            nDataBytesInPacket = 32768;
        end
        DataCmd(8:11) = typecast(uint32(PacketNumber), 'uint8');
        DataCmd(12:12+nDataBytesInPacket-1) = AudioData(DataPos:DataPos+nDataBytesInPacket-1);
        DataPos = DataPos + nDataBytesInPacket;
        Checksum = rem(sum(DataCmd(1:end-1)), 256);
        DataCmd(end) = Checksum;
        OutData(OutDataPos:OutDataPos+32780-1) = typecast(uint8(DataCmd), 'int8');
        OutDataPos = OutDataPos + 32780;
        PacketNumber = PacketNumber + 1;
    end
    if obj.UsePsychToolbox == 0
        fopen(obj.DataPort);
        fwrite(obj.DataPort, OutData, 'int8');
        Reply = fread(obj.DataPort, 12*(nCompletePackets+2), 'uint8');
        fclose(obj.DataPort);
    else
        obj.DataPort = pnet('tcpconnect','127.0.0.1',9999);
        pnet(obj.DataPort,'write',OutData);
        Reply = pnet(obj.DataPort,'read', 12*(nCompletePackets+2));
        pnet(obj.DataPort,'close');
    end
    if sum(Reply(1:12:end) == 2) ~= nCompletePackets+2
        error('Error: Sound data not acknowledged by HARP Sound Card');
    end
    end
    
    function play(obj, soundIndex)
    if isempty(obj.CMDPort)
        error('Error: To trigger sounds, you must initialize the HarpSoundCard object with a serial port argument');
    end
    Msg = [2 6 32 255 2 soundIndex 0];
    checksum = rem(sum(Msg), 256);
    obj.CMDPort.write([Msg checksum], 'uint8');
    end
    function stop(obj)
    Msg = [2 5 33 255 1 1];
    checksum = rem(sum(Msg), 256);
    obj.CMDPort.write([Msg checksum], 'uint8');
    end
    function delete(obj)
    obj.CMDPort = []; % Trigger the ArCOM port's destructor function (closes and releases port)
    if obj.UsePsychToolbox == 0
        fclose(obj.DataPort);
        delete(obj.DataPort);
        obj.DataPort = [];
    end
    try
        [Status, Msg] = system(['taskkill /F /IM ' obj.ServerProcessName]);
    catch
        % User manually closed the server
    end
    end
end
methods (Access = private)
    
end
end