% sm = GetSampleRate(sm)
%                Get the sample rate that will be used for future calls to 
%                LoadSound().  
function r = GetSampleRate(sm)
     r = sm.sample_rate;

