%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) Sanworks LLC, Rochester, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}

% RunBpodEmulator() updates the emulator system with the next incoming event.

function [newMessage, opCodeBytes, virtualCurrentEvents] = RunBpodEmulator(op, manualOverrideEvent)

global BpodSystem % Import the global BpodSystem object

virtualCurrentEvents = zeros(1,10);
globalTimerStartOffset = BpodSystem.StateMatrix.meta.InputMatrixSize; % Not +1 to emulate zero index
globalTimerEndOffset = globalTimerStartOffset + BpodSystem.HW.n.GlobalTimers;
globalCounterOffset = globalTimerEndOffset+BpodSystem.HW.n.GlobalTimers;
conditionOffset = globalCounterOffset+BpodSystem.HW.n.GlobalCounters;
switch op
    case 'init'
        % Create default variables
        BpodSystem.Emulator.nEvents = 0;
        BpodSystem.Emulator.CurrentState = 1;
        BpodSystem.Emulator.GlobalTimerStart = zeros(1,BpodSystem.HW.n.GlobalTimers);
        BpodSystem.Emulator.GlobalTimerEnd = zeros(1,BpodSystem.HW.n.GlobalTimers);
        BpodSystem.Emulator.GlobalTimersTriggered = zeros(1,BpodSystem.HW.n.GlobalTimers);
        BpodSystem.Emulator.GlobalTimersActive = zeros(1,BpodSystem.HW.n.GlobalTimers);
        BpodSystem.Emulator.GlobalCounterCounts = zeros(1,BpodSystem.HW.n.GlobalCounters);
        BpodSystem.Emulator.GlobalCounterHandled = zeros(1,BpodSystem.HW.n.GlobalCounters);
        BpodSystem.Emulator.ConditionChannels = zeros(1,BpodSystem.HW.n.Conditions);
        BpodSystem.Emulator.ConditionValues = zeros(1,BpodSystem.HW.n.Conditions);
        BpodSystem.Emulator.Timestamps = zeros(1,10000);
        BpodSystem.Emulator.MeaningfulTimer = (BpodSystem.StateMatrix.StateTimerMatrix ~=... 
                                               1:length(BpodSystem.StateMatrix.StatesDefined));
        BpodSystem.Emulator.CurrentTime = now*100000;
        BpodSystem.Emulator.MatrixStartTime = BpodSystem.Emulator.CurrentTime;
        BpodSystem.Emulator.StateStartTime = BpodSystem.Emulator.CurrentTime;
        BpodSystem.Emulator.SoftCode = BpodSystem.StateMatrix.OutputMatrix(1,BpodSystem.HardwareState.OutputType == 'X');

        % Set global timer end-time (if triggered in first state)
        globalTimerTrigByte = BpodSystem.StateMatrix.OutputMatrix(BpodSystem.Emulator.CurrentState,BpodSystem.HW.Pos.GlobalTimerTrig);
        if globalTimerTrigByte ~= 0
            timersToTrigger = dec2bin(globalTimerTrigByte) == '1';
            allGlobalTimers = find(timersToTrigger(end:-1:1));
            for z = 1:length(allGlobalTimers)
                thisGlobalTimer = allGlobalTimers(z);
                if BpodSystem.StateMatrix.GlobalTimers.OnsetDelay(thisGlobalTimer) == 0
                    BpodSystem.Emulator.GlobalTimerEnd(thisGlobalTimer) = BpodSystem.Emulator.CurrentTime +... 
                        BpodSystem.StateMatrix.GlobalTimers.Duration(thisGlobalTimer);
                    BpodSystem.Emulator.GlobalTimersActive(thisGlobalTimer) = 1;
                    set_global_timer_channel(thisGlobalTimer, 1);
                else
                    BpodSystem.Emulator.GlobalTimerStart(thisGlobalTimer) = BpodSystem.Emulator.CurrentTime +... 
                        BpodSystem.StateMatrix.GlobalTimers.OnsetDelay(thisGlobalTimer);
                    BpodSystem.Emulator.GlobalTimerEnd(thisGlobalTimer) =... 
                        BpodSystem.Emulator.GlobalTimerStart(thisGlobalTimer) +... 
                        BpodSystem.StateMatrix.GlobalTimers.Duration(thisGlobalTimer);
                    BpodSystem.Emulator.GlobalTimersTriggered(thisGlobalTimer) = 1;
                end
            end
        end
    case 'loop'
        if BpodSystem.Emulator.SoftCode == 0
            BpodSystem.Emulator.CurrentTime = now*100000;
            BpodSystem.Emulator.nCurrentEvents = 0;

            % Add manual overrides to current events
            if ~isempty(manualOverrideEvent)
                BpodSystem.Emulator.nCurrentEvents = BpodSystem.Emulator.nCurrentEvents + 1;
                virtualCurrentEvents(BpodSystem.Emulator.nCurrentEvents) = manualOverrideEvent;
            end

            % Evaluate global timer transitions
            for i = 1:BpodSystem.HW.n.GlobalTimers
                if BpodSystem.Emulator.GlobalTimersActive(i) == 1
                    if BpodSystem.Emulator.CurrentTime > BpodSystem.Emulator.GlobalTimerEnd(i)
                        BpodSystem.Emulator.nCurrentEvents = BpodSystem.Emulator.nCurrentEvents + 1;
                        virtualCurrentEvents(BpodSystem.Emulator.nCurrentEvents) = globalTimerEndOffset+i;
                        BpodSystem.Emulator.GlobalTimersActive(i) = 0;
                    end
                else
                    if BpodSystem.Emulator.GlobalTimersTriggered(i)
                        if ~BpodSystem.Emulator.GlobalTimersActive(i)
                            if BpodSystem.Emulator.CurrentTime > BpodSystem.Emulator.GlobalTimerStart(i)
                                BpodSystem.Emulator.nCurrentEvents = BpodSystem.Emulator.nCurrentEvents + 1;
                                virtualCurrentEvents(BpodSystem.Emulator.nCurrentEvents) = globalTimerStartOffset+i;
                                BpodSystem.Emulator.GlobalTimersActive(i) = 1;
                                BpodSystem.Emulator.GlobalTimersTriggered(i) = 0;
                            end
                        end
                    end
                end
            end

            % Evaluate global counter transitions
            for i = 1:BpodSystem.HW.n.GlobalCounters
                if BpodSystem.StateMatrix.GlobalCounterEvents(i) ~= 255 && BpodSystem.Emulator.GlobalCounterHandled(i) == 0
                    if BpodSystem.Emulator.GlobalCounterCounts(i) == BpodSystem.StateMatrix.GlobalCounterThresholds(i)
                        BpodSystem.Emulator.nCurrentEvents = BpodSystem.Emulator.nCurrentEvents + 1;
                        virtualCurrentEvents(BpodSystem.Emulator.nCurrentEvents) = globalCounterOffset+i;
                        BpodSystem.Emulator.GlobalCounterHandled(i) = 1;
                    end
                    if virtualCurrentEvents(1) == BpodSystem.StateMatrix.GlobalCounterEvents(i)
                        BpodSystem.Emulator.GlobalCounterCounts(i) = BpodSystem.Emulator.GlobalCounterCounts(i) + 1;
                    end
                end
            end

            % Evaluate condition transitions
            for i = 1:BpodSystem.HW.n.Conditions
                if BpodSystem.StateMatrix.ConditionSet(i)
                    targetState = BpodSystem.StateMatrix.ConditionMatrix(BpodSystem.Emulator.CurrentState, i);
                    if targetState ~= BpodSystem.Emulator.CurrentState
                        thisChannel = BpodSystem.StateMatrix.ConditionChannels(i);
                        if thisChannel <= BpodSystem.HW.n.Inputs
                            hwState = BpodSystem.HardwareState.InputState(thisChannel);
                        else
                            hwState = BpodSystem.Emulator.GlobalTimersActive(thisChannel-BpodSystem.HW.n.Inputs);
                        end
                        if hwState == BpodSystem.StateMatrix.ConditionValues(i)
                            BpodSystem.Emulator.nCurrentEvents = BpodSystem.Emulator.nCurrentEvents + 1;
                            virtualCurrentEvents(BpodSystem.Emulator.nCurrentEvents) = conditionOffset+i;
                        end
                    end
                end
            end

            % Evaluate state timer transitions
            timeInState = BpodSystem.Emulator.CurrentTime - BpodSystem.Emulator.StateStartTime;
            stateTimer = BpodSystem.StateMatrix.StateTimers(BpodSystem.Emulator.CurrentState);
            if (timeInState > stateTimer) && (BpodSystem.Emulator.MeaningfulTimer(BpodSystem.Emulator.CurrentState) == 1)
                BpodSystem.Emulator.nCurrentEvents = BpodSystem.Emulator.nCurrentEvents + 1;
                virtualCurrentEvents(BpodSystem.Emulator.nCurrentEvents) = BpodSystem.HW.StateTimerPosition;
            end
            dominantEvent = virtualCurrentEvents(1);
            if dominantEvent > 0
                newMessage = 1;
                opCodeBytes = [1 BpodSystem.Emulator.nCurrentEvents];
                virtualCurrentEvents = virtualCurrentEvents - 1; % Set to c++ index by 0
                BpodSystem.Emulator.Timestamps(BpodSystem.Emulator.nEvents+1:BpodSystem.Emulator.nEvents+BpodSystem.Emulator.nCurrentEvents) =... 
                    BpodSystem.Emulator.CurrentTime - BpodSystem.Emulator.MatrixStartTime;
                BpodSystem.Emulator.nEvents = BpodSystem.Emulator.nEvents + BpodSystem.Emulator.nCurrentEvents;
            else
                newMessage = 0;
                opCodeBytes = [];
                virtualCurrentEvents = [];
            end
            drawnow;
        else
            newMessage = 1;
            opCodeBytes = [2 BpodSystem.Emulator.SoftCode];
            virtualCurrentEvents = [];
            BpodSystem.Emulator.SoftCode = 0;
        end    
end

function set_global_timer_channel(channel, op)
global BpodSystem
thisChannel = BpodSystem.StateMatrix.GlobalTimers.OutputChannel(channel);
if thisChannel < 255
    BpodSystem.HardwareState.OutputState(thisChannel) = op;
    switch op
        case 0
            BpodSystem.HardwareState.OutputOverride(thisChannel) = 0;
        case 1
            BpodSystem.HardwareState.OutputOverride(thisChannel) = 1;
    end

end
