% hilo = GetInputChannelStates(@RTLSM2::sm)   Returns a vector with the current state of input channels 
%
% Use this function to find what the input channels are currently doing-- 
% for example, to ask whether the Center poke is interrupted (High) or not 
% (Low). Runs asynchronously, so there is no guarantee that by the time the
% function returns the input channels remain in the same state as reported.
%
% Returns a vector that is the same length as the number of input channels
% that the sm is operating with. In this vector, 1 represents "High", 0
% represents "Low".
%

function hilo = GetInputChannelStates(sm)

if ~min_server(sm, 220090628, mfilename),
    hilo = [];
    return;
end;

hilo = DoQueryMatrixCmd(sm, 'GET INPUT CHANNEL STATES');
return;
    
    