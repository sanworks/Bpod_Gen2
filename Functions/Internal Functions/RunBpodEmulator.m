%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Sound Beach, New York, USA

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
function [NewMessage, OpCodeBytes, VirtualCurrentEvents] = RunBpodEmulator(Op, ManualOverrideEvent)
global BpodSystem
VirtualCurrentEvents = zeros(1,10);
GlobalTimerStartOffset = BpodSystem.StateMatrix.meta.InputMatrixSize; % Not +1 to emulate zero index
GlobalTimerEndOffset = GlobalTimerStartOffset + BpodSystem.HW.n.GlobalTimers;
GlobalCounterOffset = GlobalTimerEndOffset+BpodSystem.HW.n.GlobalTimers;
ConditionOffset = GlobalCounterOffset+BpodSystem.HW.n.GlobalCounters;
JumpOffset = ConditionOffset+BpodSystem.HW.n.Conditions;
switch Op
    case 'init'
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
        BpodSystem.Emulator.MeaningfulTimer = (BpodSystem.StateMatrix.StateTimerMatrix ~= 1:length(BpodSystem.StateMatrix.StatesDefined));
        BpodSystem.Emulator.CurrentTime = now*100000;
        BpodSystem.Emulator.MatrixStartTime = BpodSystem.Emulator.CurrentTime;
        BpodSystem.Emulator.StateStartTime = BpodSystem.Emulator.CurrentTime;
        BpodSystem.Emulator.SoftCode = BpodSystem.StateMatrix.OutputMatrix(1,BpodSystem.HardwareState.OutputType == 'X');
        
        % Continue updating HERE
        
        % Set global timer end-time (if triggered in first state)
        ThisGlobalTimer = BpodSystem.StateMatrix.OutputMatrix(BpodSystem.Emulator.CurrentState,BpodSystem.HW.Pos.GlobalTimerTrig);
        if ThisGlobalTimer ~= 0
            if BpodSystem.StateMatrix.GlobalTimers.OnsetDelay(ThisGlobalTimer) == 0
                BpodSystem.Emulator.GlobalTimerEnd(ThisGlobalTimer) = BpodSystem.Emulator.CurrentTime + BpodSystem.StateMatrix.GlobalTimers.Duration(ThisGlobalTimer);
                BpodSystem.Emulator.GlobalTimersActive(ThisGlobalTimer) = 1;
                setGlobalTimerChannel(ThisGlobalTimer, 1);
            else
                BpodSystem.Emulator.GlobalTimerStart(ThisGlobalTimer) = BpodSystem.Emulator.CurrentTime + BpodSystem.StateMatrix.GlobalTimers.OnsetDelay(ThisGlobalTimer);
                BpodSystem.Emulator.GlobalTimerEnd(ThisGlobalTimer) = BpodSystem.Emulator.GlobalTimerStart(ThisGlobalTimer) + BpodSystem.StateMatrix.GlobalTimers.Duration(ThisGlobalTimer);
                BpodSystem.Emulator.GlobalTimersTriggered(ThisGlobalTimer) = 1;
            end
        end
    case 'loop'
        if BpodSystem.Emulator.SoftCode == 0
            BpodSystem.Emulator.CurrentTime = now*100000;
            BpodSystem.Emulator.nCurrentEvents = 0;
            % Add manual overrides to current events
            if ~isempty(ManualOverrideEvent)
                BpodSystem.Emulator.nCurrentEvents = BpodSystem.Emulator.nCurrentEvents + 1;
                VirtualCurrentEvents(BpodSystem.Emulator.nCurrentEvents) = ManualOverrideEvent;
            end
            % Evaluate condition transitions
%             for x = 1:5
%                 ConditionEvent = 0;
%                 if BpodSystem.Emulator.ConditionChannels(x) > 0
%                     ConditionValue = BpodSystem.Emulator.ConditionValues(x);
%                     if ManualOverrideEvent < 9
%                         if BpodSystem.HardwareState.PortSensors(BpodSystem.Emulator.ConditionChannels(x)) == ConditionValue
%                             ConditionEvent = ConditionOffset+x;
%                         end
%                     elseif ManualOverrideEvent < 11
%                         if BpodSystem.HardwareState.BNCInputs(BpodSystem.Emulator.ConditionChannels(x)-8) == ConditionValue
%                             ConditionEvent = ConditionOffset+x;
%                         end
%                     elseif ManualOverrideEvent < 15
%                         if BpodSystem.HardwareState.PortSensors(BpodSystem.Emulator.ConditionChannels(x)-10) == ConditionValue
%                             ConditionEvent = ConditionOffset+x;
%                         end
%                     end
%                 end
%                 if ConditionEvent > 0
%                     VirtualCurrentEvents(BpodSystem.Emulator.nCurrentEvents+1) = ManualOverrideEvent;
%                     VirtualCurrentEvents(BpodSystem.Emulator.nCurrentEvents) = ConditionEvent;
%                     nCurrentEvents = nCurrentEvents + 1;
%                 end
%             end
            % Evaluate global timer transitions
            for x = 1:BpodSystem.HW.n.GlobalTimers
                if BpodSystem.Emulator.GlobalTimersActive(x) == 1
                    if BpodSystem.Emulator.CurrentTime > BpodSystem.Emulator.GlobalTimerEnd(x)
                        BpodSystem.Emulator.nCurrentEvents = BpodSystem.Emulator.nCurrentEvents + 1;
                        VirtualCurrentEvents(BpodSystem.Emulator.nCurrentEvents) = GlobalTimerEndOffset+x;
                        BpodSystem.Emulator.GlobalTimersActive(x) = 0;
                        %setGlobalTimerChannel(x, 0);
                    end
                else
                    if BpodSystem.Emulator.GlobalTimersTriggered(x)
                        if ~BpodSystem.Emulator.GlobalTimersActive(x)
                            if BpodSystem.Emulator.CurrentTime > BpodSystem.Emulator.GlobalTimerStart(x)
                                BpodSystem.Emulator.nCurrentEvents = BpodSystem.Emulator.nCurrentEvents + 1;
                                VirtualCurrentEvents(BpodSystem.Emulator.nCurrentEvents) = GlobalTimerStartOffset+x;
                                BpodSystem.Emulator.GlobalTimersActive(x) = 1;
                                BpodSystem.Emulator.GlobalTimersTriggered(x) = 0;
                                %setGlobalTimerChannel(x, 1);
                            end
                        end
                    end
                end
            end
            % Evaluate global counter transitions
            for x = 1:BpodSystem.HW.n.GlobalCounters
                if BpodSystem.StateMatrix.GlobalCounterEvents(x) ~= 255 && BpodSystem.Emulator.GlobalCounterHandled(x) == 0
                    if BpodSystem.Emulator.GlobalCounterCounts(x) == BpodSystem.StateMatrix.GlobalCounterThresholds(x)
                        BpodSystem.Emulator.nCurrentEvents = BpodSystem.Emulator.nCurrentEvents + 1;
                        VirtualCurrentEvents(BpodSystem.Emulator.nCurrentEvents) = GlobalCounterOffset+x;
                        BpodSystem.Emulator.GlobalCounterHandled(x) = 1;
                    end
                    if VirtualCurrentEvents(1) == BpodSystem.StateMatrix.GlobalCounterEvents(x)
                        BpodSystem.Emulator.GlobalCounterCounts(x) = BpodSystem.Emulator.GlobalCounterCounts(x) + 1;
                    end
                end
            end
            % Evaluate condition transitions
            for x = 1:BpodSystem.HW.n.Conditions
                if BpodSystem.StateMatrix.ConditionSet(x)
                    TargetState = BpodSystem.StateMatrix.ConditionMatrix(BpodSystem.Emulator.CurrentState, x);
                    if TargetState ~= BpodSystem.Emulator.CurrentState
                        ThisChannel = BpodSystem.StateMatrix.ConditionChannels(x);
                        HWState = BpodSystem.HardwareState.InputState(ThisChannel);                        
                        if HWState == BpodSystem.StateMatrix.ConditionValues(x)
                            BpodSystem.Emulator.nCurrentEvents = BpodSystem.Emulator.nCurrentEvents + 1;
                            VirtualCurrentEvents(BpodSystem.Emulator.nCurrentEvents) = ConditionOffset+x;
                        end
                    end
                end
            end
            % Evaluate state timer transitions
            TimeInState = BpodSystem.Emulator.CurrentTime - BpodSystem.Emulator.StateStartTime;
            StateTimer = BpodSystem.StateMatrix.StateTimers(BpodSystem.Emulator.CurrentState);
            if (TimeInState > StateTimer) && (BpodSystem.Emulator.MeaningfulTimer(BpodSystem.Emulator.CurrentState) == 1)
                BpodSystem.Emulator.nCurrentEvents = BpodSystem.Emulator.nCurrentEvents + 1;
                VirtualCurrentEvents(BpodSystem.Emulator.nCurrentEvents) = BpodSystem.HW.StateTimerPosition;
            end
            DominantEvent = VirtualCurrentEvents(1);
            if DominantEvent > 0
                NewMessage = 1;
                OpCodeBytes = [1 BpodSystem.Emulator.nCurrentEvents];
                VirtualCurrentEvents = VirtualCurrentEvents - 1; % Set to c++ index by 0
                BpodSystem.Emulator.Timestamps(BpodSystem.Emulator.nEvents+1:BpodSystem.Emulator.nEvents+BpodSystem.Emulator.nCurrentEvents) = BpodSystem.Emulator.CurrentTime - BpodSystem.Emulator.MatrixStartTime;
                BpodSystem.Emulator.nEvents = BpodSystem.Emulator.nEvents + BpodSystem.Emulator.nCurrentEvents;
            else
                NewMessage = 0;
                OpCodeBytes = [];
                VirtualCurrentEvents = [];
            end
            drawnow;
        else
            NewMessage = 1;
            OpCodeBytes = [2 BpodSystem.Emulator.SoftCode];
            VirtualCurrentEvents = [];
            BpodSystem.Emulator.SoftCode = 0;
        end    
end

function setGlobalTimerChannel(channel, op)
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