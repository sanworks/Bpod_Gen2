function SoftCodeHandler_LatencyLoop(softCode)
% This is the soft code handler function used by SoftCodeLatencyLoop.m
if softCode == 1
    SendBpodSoftCode(1);
end