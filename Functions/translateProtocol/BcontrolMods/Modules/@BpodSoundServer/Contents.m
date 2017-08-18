% This directory contains the definitins of the RTLSoundMachine object.
%
% The current definition is intended to exactly replicate the
% capabilities of the TDT RPBoxes in use in August 2005. Future
% RTLSoundMachine definitions will expand and modify this.
%
%
% Methods:
%
% sm = RTLSoundMachine('host', port, soundcard_number) 
%                Construct a new RTLSoundMachine handle.
%                The host and port that the sound server is listening on
%                Defaults to 'localhost', 3334.  
%
%                The soundcard_number indicates which of the soundcards on the 
%                soundmachine is the intended soundcard to use.  Otherwise an 
%                8th parameter to LoadSound is required to override this.  
%                This parameter is for soundmachines that have more than 1 
%                soundcard.
%
%                A newly constructed RTLSoundMachine has the
%                following default properties:
%
%                Sample Rate:  200000
%
% [ncards] = GetNumCards(sm)
%                Query the sound machine to find out how many soundcards it 
%                has installed.
%
% card = GetCard(sm)    
%                Get the active soundcard that we are connected to
%                (affect where sounds play when triggered from state
%                machine, etc).  See also: SetCard.m and GetNumCards.m
%
% sm = SetCard(sm, card)    
%                Set the active soundcard that we are connected to
%                (affect where sounds play when triggered from state
%                machine, etc).  See also: GetCard.m and GetNumCards.m
%
% sm = Initialize(sm)   
%                This is equivalent to a reboot of the
%                Sound Server. It clears all variables, including
%                the sound files, and initializes the system. 
%
%                It is not necessary to call this unless you want to clear 
%                things and start with a clean slate.
%
%                Note that multiple sm objects could potentially point to the
%                same real sound server so be careful when re-initializing 
%                the sound server, as all sounds will be reset for
%                all instances that point to the same host/port combination!
% 
%
% sm = SetSampleRate(sm, srate)
%                Set the sample rate for future calls to LoadSound()
%                Note that changing the sampling rate only has an effect
%                on future soundfiles loaded via LoadSound().  Sound files
%                that were already loaded will *not* be updated to use
%                the new rate!  The default rate on a newly constructed object 
%                is 44000 (44 kHz).
%
% sm = GetSampleRate(sm)
%                Get the sample rate that will be used for future calls to 
%                LoadSound().  
%
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
%
% sm = PlaySound(sm, trigger)   
%                Forces the soundmachine to play a particular sound previously 
%                loaded with LoadSound().  
%
%                Note this triggering happens in non-realtime and
%                is thus useful for testing the sound file, but not
%                useful for realtime control experiments.
%
% sm = StopSound(sm) 
%                Forces the soundmachine to stop any sounds it may 
%                (or may not) be currently playing.
%
% [] = Close(sm) Begone! Begone!
%
% double_scalar_time = GetTime(sm)    
%                Gets the time, in seconds, that has elapsed since
%                the last call to Initialize().
%
% Calin Culianu last updated me on 8-Feb-06


