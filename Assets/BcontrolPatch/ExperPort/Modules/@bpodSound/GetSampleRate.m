% [srate] = GetSampleRate(sm)
%

function [srate] = GetSampleRate(sm)
   
   mydata = get(sm.myfig, 'UserData');
   srate = mydata.samplerate;
   
   