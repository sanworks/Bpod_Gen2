function sm = bpodSound(a)
global BpodSystem
if nargin==0,
    
    myfig = figure('Visible', 'off');
    
    sr=bSettings('get','SOUND','sound_sample_rate');
    if isnan(sr)
        sr=8000;
    end
    mydata = struct( ...
        'samplerate',    sr,   ...
        'allowed_trigs', [1:32]  ...
        );
    
    
    for i=1:32,
        mydata = setfield(mydata, ['sound' num2str(i)], []);
    end;
    
    set(myfig, 'UserData', mydata);
    
    sm = struct('myfig', myfig);
    sm = class(sm, 'bpodSound');
    AudioPlayerFound = 0;
    if ~isfield(BpodSystem.PluginObjects, 'SoundServer')
        if isfield(BpodSystem.ModuleUSB, 'AudioPlayer1')
            AssertAudioPlayerAvailable(BpodSystem.ModuleUSB.AudioPlayer1, 229); % 229 is the handshake request byte
            BpodSystem.PluginObjects.SoundServer = BpodAudioPlayer(BpodSystem.ModuleUSB.AudioPlayer1);
            BpodSystem.PluginObjects.SoundServerType = 1; % Type 1 = Analog output module with AudioPlayer_Live firmware
            AudioPlayerFound = 1;
        elseif isfield(BpodSystem.ModuleUSB, 'HiFi1')
            AssertAudioPlayerAvailable(BpodSystem.ModuleUSB.HiFi1, 243); % 243 is the handshake request byte
            BpodSystem.PluginObjects.SoundServer = BpodHiFi(BpodSystem.ModuleUSB.HiFi1);
            BpodSystem.PluginObjects.SoundServerType = 2; % Type 2 = HiFi module
            AudioPlayerFound = 1;
        elseif sum(strcmp('AudioPlayer1', BpodSystem.Modules.Name)) > 0 || sum(strcmp('HiFi1', BpodSystem.Modules.Name)) > 0
            error('Error setting up Bpod sound server for B-control: the sound server''s USB port must be paired with its Bpod serial port. Use the USB menu on the Bpod console.')
        else
            % Check to see whether the audio player's usual serial port is present
            %%% NOTE %%% This fallback handler does not yet work for the HiFi module
            USBSerialPorts = BpodSystem.FindUSBSerialPorts;
            CandidateAudioPlayers = USBSerialPorts;
            CandidateHiFiPlayers = USBSerialPorts;
            load(BpodSystem.Path.ModuleUSBConfig)
            LastPairedAudioPlayerPort = ModuleUSBConfig.USBPorts(strcmp(ModuleUSBConfig.ModuleNames, 'AudioPlayer1'));
            LastPairedHiFiPort = ModuleUSBConfig.USBPorts(strcmp(ModuleUSBConfig.ModuleNames, 'HiFi1'));
            if ~isempty(LastPairedHiFiPort)
                LastPairedHiFiPort = LastPairedHiFiPort{1};
            else
                LastPairedHiFiPort{1} = '';
            end
            if ~isempty(LastPairedAudioPlayerPort)
                LastPairedAudioPlayerPort = LastPairedAudioPlayerPort{1};
            else
                LastPairedAudioPlayerPort{1} = '';
            end

            if sum(strcmp(CandidateAudioPlayers, LastPairedAudioPlayerPort)) > 0
                AssertAudioPlayerAvailable(LastPairedAudioPlayerPort, 229);
                BpodSystem.LoadModules();
                if isfield(BpodSystem.ModuleUSB, 'AudioPlayer1')
                    BpodSystem.PluginObjects.SoundServer = BpodAudioPlayer(BpodSystem.ModuleUSB.AudioPlayer1);
                    AudioPlayerFound = 1;
                else
                    disp('#########################################');
                    disp(['ALERT! No Audio module detected!' char(10) 'Protocols will error out if sound is used.'])
                    disp('#########################################');
                end
            elseif sum(strcmp(CandidateHiFiPlayers, LastPairedHiFiPort)) > 0
                AssertAudioPlayerAvailable(LastPairedHiFiPort, 243);
                BpodSystem.LoadModules();
                if isfield(BpodSystem.ModuleUSB, 'HiFi1')
                    BpodSystem.PluginObjects.SoundServer =  BpodHiFi(BpodSystem.ModuleUSB.HiFi1);
                    AudioPlayerFound = 1;
                else
                    disp('#########################################');
                    disp(['ALERT! No Audio module detected!' char(10) 'Protocols will error out if sound is used.'])
                    disp('#########################################');
                end
            else
                disp('#########################################');
                disp(['ALERT! No Audio module detected!' char(10) 'Protocols will error out if sound is used.'])
                disp('#########################################');
            end
        end
        if AudioPlayerFound == 1
            if BpodSystem.PluginObjects.SoundServerType == 1
                if sr > 44100
                    error('Error: In your custom_settings.conf file, a sampling rate over 44.1kHz is specified - but the current BpodAudio firmware can only support up to 44.1kHz.')
                end
            end
            if BpodSystem.PluginObjects.SoundServerType == 2
                if sum(intersect(sr, [44100 48000 96000 192000])) == 0
                    error('Error: In your custom_settings.conf file, an invalid sampling rate is specified. Valid sampling rates are: 44100, 48000, 96000, 192000')
                end
            end
            nSoundsSupported = BpodSystem.PluginObjects.SoundServer.Info.maxSounds;
            BpodSystem.PluginObjects.SoundServer.SamplingRate = sr;
            % Configure a 1ms linear AM onset and offset ramp by default
            BpodSystem.PluginObjects.SoundServer.AMenvelope = 1000/sr:1000/sr:1;
            if BpodSystem.PluginObjects.SoundServerType == 1 % These are immutable defaults for the HiFi module
                % Set load mode to 'fast', since session has not started yet
                BpodSystem.PluginObjects.SoundServer.LoadMode = 'Fast';
                % Set trigger mode to 'master' so that new sounds automatically cancel old ones
                BpodSystem.PluginObjects.SoundServer.TriggerMode = 'Master';
            end
            % Setup trigger messages from state machine
            TriggerMessages = cell(1,nSoundsSupported*2);
            for i = 1:nSoundsSupported
                TriggerMessages{i} = ['P' i-1];
            end
            for i = nSoundsSupported+1:nSoundsSupported*2
                TriggerMessages{i} = ['x' i-nSoundsSupported-1];
            end
            if BpodSystem.PluginObjects.SoundServerType == 1
                LoadSerialMessages('AudioPlayer1', TriggerMessages);
            else
                LoadSerialMessages('HiFi1', TriggerMessages);
            end
        end
    end
    Initialize(sm);
    return;
    
elseif isa(ssm, 'softsm'),
    ssm = a;
    return;
    
else
    error(['Don''t understand this argument for creation of a ' ...
        'bpodSound']);
end;

function AssertAudioPlayerAvailable(CandidatePort, HandshakeByte)
% Spam the candidate port with handshake bytes until it replies.
TestPort = ArCOMObject_Bpod(CandidatePort, 115200);
TestPort.write(HandshakeByte, 'uint8');
pause(.1);
replied = TestPort.bytesAvailable;
if replied == 0
    disp('---------------------------------------')
    disp('Bpod audio player did not reply.')
    disp([CandidatePort ' may be the wrong port, OR'])
    disp('the player may be stuck waiting for data.')
    disp('Attempting to reset audio player. Please wait...')
    disp('---------------------------------------')
    nTries = 20; i = 0;
    while (replied == 0 && i < nTries)
        TestPort.write(ones(1,200000)*HandshakeByte, 'uint8');
        pause(.01);
        replied = TestPort.bytesAvailable;
        i = i + 1;
    end
    if replied == 0
        error(['Error: Bpod Audio Player non-responsive on port ' CandidatePort])
    end
    while TestPort.bytesAvailable > 0
        TestPort.read(TestPort.bytesAvailable, 'uint8');
    end
    disp('Audio player reset successfully!')
else
    TestPort.read(TestPort.bytesAvailable, 'uint8');
end
clear TestPort
pause(.1);