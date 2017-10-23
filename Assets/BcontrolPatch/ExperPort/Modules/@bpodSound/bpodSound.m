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
      
      if ~isfield(BpodSystem.PluginObjects, 'SoundServer')
          if isfield(BpodSystem.ModuleUSB, 'AudioPlayer1')
            BpodSystem.PluginObjects.SoundServer = BpodAudioPlayer(BpodSystem.ModuleUSB.AudioPlayer1);
            if sr > 100000
                error('Error: In your custom_settings.conf file, a sampling rate over 100kHz is specified - but the current BpodAudio firmware can only support up to 100kHz.')
            end
            nSoundsSupported = BpodSystem.PluginObjects.SoundServer.Info.maxSounds;
            BpodSystem.PluginObjects.SoundServer.SamplingRate = sr;
            % Configure a 1ms linear AM onset and offset ramp by default
            BpodSystem.PluginObjects.SoundServer.AMenvelope = 1000/sr:1000/sr:1;
            % Set load mode to 'fast', since session has not started yet
            BpodSystem.PluginObjects.SoundServer.LoadMode = 'Fast';
            % Set trigger mode to 'master' so that new sounds automatically cancel old ones
            BpodSystem.PluginObjects.SoundServer.TriggerMode = 'Master';
            % Setup trigger messages from state machine
            TriggerMessages = cell(1,nSoundsSupported+1);
            for i = 1:nSoundsSupported
                TriggerMessages{i} = ['P' i-1];
            end
            TriggerMessages{nSoundsSupported+1} = 'X';
            LoadSerialMessages('AudioPlayer1', TriggerMessages);
          elseif sum(strcmp('AudioPlayer1', BpodSystem.Modules.Name)) > 0
            error('Error setting up Bpod sound server for B-control: the sound server''s USB port must be paired with its Bpod serial port. Use the USB menu on the Bpod console.')
          else
              disp('#########################################');
              disp(['ALERT! No AudioPlayer module detected!' char(10) 'Protocols will error out if sound is used.'])
              disp('#########################################');
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
   
          