% sm = LoadSound(sm, unsigned triggernum, Vector_of_doubles soundVector, String side, tau_ms, predelay_s, loop_flg)
%
%                This function defines a particular sound to play for
%                a particular trigger number.
%         
%                The soundVector is either a 1xNUM_SAMPLES (mono)
%                or 2xNUM_SAMPLES (stereo) in the range [-1,1].
%
%                side is either 'left', 'right' or 'both', and
%                controls which speaker side the sound will play from.
%
%                tau_ms is the number of milliseconds to do a cosine2
%                stop-ramp function when triggering the sound to 'stop'.
%                Default is 0, meaning don't ramp-down the volume.
%                If nonzero, the volume will be ramped-down for a 'gradual
%                stop' over time tau_ms on trigger-stop events.
%                NB: On natural, untriggered stops, no ramping is
%                ever applied, since it is assumed that the
%                soundfile itself ramps whatever it contains down
%                to 0 volume naturally.
%
%                predelay_s is the amount of time in seconds to pre-delay the
%                playing of the sound when triggering.  This
%                functionally prepends predelay_s seconds worth of
%                zeroes to the sound matrix so as to cause sounds
%                to play with a predefined delay from the time they
%                are triggered to the time that real sounds
%                actually begin emanating from the speakers.
%                (As strange as this may seem, delaying sound
%                output from the time of the trigger to when the
%                sound really plays is useful to some protocols).
%
%                If loop_flg is true, the sound should loop indefinitely
%                whenever it is triggered, otherwise it will play
%                only once for each triggering.
%
%                Calling this function with a stereo soundVector and
%                any side parameter other than 'both' is supported
%                and is a good way to suppress the output of one side.
%
%                Sampling rate note: Each file that is loaded to the 
%                RTLSoundMachine takes the sampling rate currently 
%                set via the SetSampleRate() method.  In other words, it is 
%                necessary to call SetSampleRate() before calling LoadSound() 
%                for each file you load via LoadSound() if all your sound 
%                files' sampling rates differ!  Likewise, you need to reload
%                sound files if you want new sampling rates set via
%                SetSamplingRate() to take effect.
function [sm] = LoadSound(sm, trig, sound, side, stop_ramp_tau_ms, ...
                          predelay_s, loop_flg)

  if (nargin < 3 || nargin > 8),  error('Wrong number of arguments!'); end;
  if (nargin < 4), side = 'both'; end;
  if (nargin < 5), stop_ramp_tau_ms = 0; end;
  if (nargin < 6), predelay_s = 0; end;
  if (nargin < 7), loop_flg = 0; end;
  if (stop_ramp_tau_ms < 0) stop_ramp_tau_ms = 0; end;
  
  [m,n] = size(sound);
  if (m < 1 || m > 2), error('Sound vector must have one row for mono or two rows for stereo!'); end;

  % Force stereo even for mono sounds due to implementation
  % limitations
  if (m == 1), sound(2,1:n) = sound(1,1:n); m = 2; end;
  
  % add predelay_s samples at the beginning to realize the predelay
  % TODO: change this and do the predelay inside rtlinux to save
  % memory.. prepending zeros is wasteful, after all.   -Calin
  nsamps = predelay_s * sm.sample_rate;
  sound = horzcat(zeros(m,nsamps), sound);
  [m,n] = size(sound);
  
  if (~isnumeric(sound)), error('Need to pass a vector/matrix of numbers!'); end;
  if (~isa(sound, 'int32')) 
     % force the sound to be int32 format.. convert from double -1,1 to signed PCM32
%    if (isa(sound, 'double')) % ok, if it isn''t int32, scale it to int32
%       for i = 1:m
%         for j = 1:n
%           sound(i,j) = int32(sound(i,j) * intmax('int32'));
%         end;
%       end;
%    end;
%
%    sound = int32(sound); % now that it''s scaled, actually convert the datatype
%   The above was slow.. trying to do this natively in mex for speed - Calin
     
    %JPL - cant find SoundTrigClient...
    %sound = SoundTrigClient('toInt32', sound);
    sound = int32(sound);
    
  end;

  chans = m;
  
  % Suppress a side if they said they want 'left' or 'right'
  switch(side)
     case 'left'
         % for mono files, duplicate the channel on both sides
         if (m == 1), sound(2,1:n) = sound(1,1:n);  m = 2; chans = 2; end;
        sound(2,1:n) = zeros(1,n); % silence out right channel in 'left' mode
     case 'right'
         % for mono files, duplicate the channel on both sides
        if (m == 1), sound(2,1:n) = sound(1,1:n); m = 2; chans = 2; end;
        sound(1,1:n) = zeros(1,n); % silence out left channel in 'right' mode
  end;

  %sound = SoundTrigClient('interleaveMatrix', sound); 

  %ChkConn(sm);
%   [res] = SoundTrigClient('sendstring', sm.handle, sprintf('SET SOUND %d %d %d %d %d %d\n', floor(trig), floor(n*m*4), floor(chans), 32, floor(sm.sample_rate), floor(stop_ramp_tau_ms)));
  if (sm.sample_rate ~= 200000),
    warning(['For now, RTLSoundMachine is limited to a sample rate' ...
             ' of 200kHz only!  Please fix your code!']);
  end;
  %[res] = SoundTrigClient('sendstring', ...
  %                        sm.handle, ...
  %                        sprintf(['SET SOUND %d %d %d %d %d %d %d\n'], ...
  %                                floor(trig), floor(n*m*4), floor(chans), ...
  %                                32, 200000, floor(stop_ramp_tau_ms), ...
  %                                loop_flg));
  %ReceiveREADY(sm, 'SET SOUND');
  %[res] = SoundTrigClient('sendint32matrix', sm.handle, sound);
  %ReceiveOK(sm, 'SET SOUND');
  % just to clean up the connection
  %fsmclient('disconnect');
  return;
