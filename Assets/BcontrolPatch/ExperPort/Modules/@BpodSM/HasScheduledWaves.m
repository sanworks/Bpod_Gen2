function [ truefalse ] = HasScheduledWaves( sm )
%UNTITLED1 Summary of this function goes here
%   Detailed explanation goes here
    truefalse = ~isempty(sm.sched_waves);
    return;
    