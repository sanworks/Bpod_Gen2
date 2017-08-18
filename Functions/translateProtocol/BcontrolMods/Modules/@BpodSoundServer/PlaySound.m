% sm = PlaySound(sm, trigger)   
%                Forces the soundmachine to play a particular sound previously 
%                loaded with LoadSound().  
%
%                Note this triggering happens in non-realtime and
%                is thus useful for testing the sound file, but not
%                useful for realtime control experiments.
function [sm] = PlaySound(sm, d)

     ChkConn(sm);
     DoSimpleCmd(sm, sprintf('TRIGGER %d\n', d));
     sm = sm;
