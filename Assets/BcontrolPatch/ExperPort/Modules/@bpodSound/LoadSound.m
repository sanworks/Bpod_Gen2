function [sm] = LoadSound(sm, trignum, sound, side, tau_ms, predelay_s, loop_fg)
   global BpodSystem
   if ~isfield(BpodSystem.PluginObjects, 'SoundServerType')
       error('LoadSound() requires a sound server. The current setup did not detect one.')
   end
   if BpodSystem.PluginObjects.SoundServerType == 1
       if BpodSystem.Status.InStateMatrix == 0 % If pre-session, load in fast mode
           if strcmp(BpodSystem.PluginObjects.SoundServer.LoadMode, 'Safe')
               BpodSystem.PluginObjects.SoundServer.LoadMode = 'Fast';
           end
           % disp('Loading sounds in FAST mode!');
       else % If running a session, load in safe mode
           if strcmp(BpodSystem.PluginObjects.SoundServer.LoadMode, 'Fast')
               BpodSystem.PluginObjects.SoundServer.LoadMode = 'Safe';
           end
           % disp('Loading sounds in SAFE mode!');
       end
   end
   if nargin<7, loop_fg    = 0; end;
   if nargin<6, predelay_s = 0; end;
   
   % note: we ignore tau_ms -- it is only provided for
   % compatibility with RTLSoundMachine
   if nargin<5, tau_ms = 0; end;
   
   if (tau_ms ~= 0), 
     warning(['Your tau_ms value of %g (the on-ramp envelope time)' ... 
              ' is ignored in bpodSound::LoadSound(),' ...
              ' it is only provided for compatibility with' ...
              ' the RTLSoundMachine!'], tau_ms); 
   end;
   if loop_fg ~= 0,
     warning(['Your loop_fg value of %g' ... 
              ' is ignored in bpodSound::LoadSound(),' ...
              ' it is only provided for compatibility with' ...
              ' the RTLSoundMachine!'], loop_fg); 
   end;
   
   
   if nargin<4, side = 'both'; end;
   mydata = get(sm.myfig, 'UserData');

   if (size(sound,1) > 2 | size(sound,1) < 1),
       error('Sound file must be 1xN or 2xN for stereo!!');
   end;
   
   % pad the predelay_s with zeroes...
   nsamps = predelay_s * mydata.samplerate;
   sound = horzcat(zeros(size(sound,1), nsamps), sound);

   %Code to allow users to set a volume scaling factor unique to each rig to
  %help make sounds uniform between rigs when differences are greater than
  %what the amplifiers can manage
  volume_scale = bSettings('get','SOUND','volume_scaling');
  if isempty(volume_scale) || isnan(volume_scale); volume_scale = 1; end
  sound = sound * volume_scale;
  sound(sound > 1) = 1;
  sound(sound < -1) = -1; 
  
   if (trignum < 0), trignum = -trignum; end;
   
   if ~ismember(trignum, mydata.allowed_trigs),
      error(['trignum must be one of ' sprintf('%d ',mydata.allowed_trigs)]);
   end;

   if strcmp(side, 'both'),
     mydata.(['sound' num2str(trignum)]) = sound;
     set(sm.myfig, 'UserData', mydata);
     if BpodSystem.PluginObjects.SoundServerType == 1
        BpodSystem.PluginObjects.SoundServer.loadSound(trignum, sound, loop_fg);
     elseif BpodSystem.PluginObjects.SoundServerType == 2
        BpodSystem.PluginObjects.SoundServer.load(trignum, sound, 'LoopMode', loop_fg);
     end
     return
   end;
   
   olddata = mydata.(['sound' num2str(trignum)]);
   olddata = rowize(olddata); sound = rowize(sound);
   if size(sound,1) > 1, 
      error('Can''t load single side sound with a stereo sound');
   end;

   switch side,
    case 'left',
     if size(olddata,1) < 2, % didn't have stereo previously
        nd = [sound; zeros(size(sound))]; 
     else
        if length(sound) ~= length(olddata), nd=[sound ; zeros(size(sound))];
        else                                 nd=[sound ; olddata(2,:)];
        end;
     end;
        
    case 'right',
     if size(olddata,1) < 2, % didn't have stereo previously
        nd = [zeros(size(sound)) ; sound]; 
     else
        if length(sound) ~= length(olddata), nd=[zeros(size(sound)) ; sound];
        else                                 nd=[olddata(1,:)       ; sound];
        end;
     end;
       
    otherwise, error(['Don''t know hot to do this side ' side]);
   end;
    
   mydata.(['sound' num2str(trignum)]) = nd;      
   set(sm.myfig, 'UserData', mydata);
   if BpodSystem.PluginObjects.SoundServerType == 1
       BpodSystem.PluginObjects.SoundServer.loadSound(trignum, sound, loop_fg);
   elseif BpodSystem.PluginObjects.SoundServerType == 2
       BpodSystem.PluginObjects.SoundServer.load(trignum, sound, 'LoopMode', loop_fg);
   end
   return;
   
   
   
   
% -----------------                   
                   
function [s] = rowize(s)
                   
   if size(s,1) > size(s,2), s = s'; end;
   