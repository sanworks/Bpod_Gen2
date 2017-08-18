% sm = SetSampleRate(sm, srate)
%                Set the sample rate for future calls to LoadSound()
%                Note that changing the sampling rate only has an effect
%                on future soundfiles loaded via LoadSound().  Sound files
%                that were already loaded will *not* be updated to use
%                the new rate!  The default rate on a newly constructed object 
%                is 44000 (44 kHz).
function [ret] = SetSampleRate(sm, rate)
  sm.sample_rate = rate;
  ret = sm;
