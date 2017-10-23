function [sm] = SetSampleRate(sm, srate)
   
   mydata = get(sm.myfig, 'UserData');
   mydata.samplerate = srate;
   set(sm.myfig, 'UserData', mydata);
   
   