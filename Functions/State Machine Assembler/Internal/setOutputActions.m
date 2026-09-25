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

function sma = setOutputActions(sma, stateNumber, stateName, outputActions)
% setOutputActions() sets the output actions of one state in a state machine description.
% AddState() and EditState() both use it, so they interpret output actions identically.
% Outputs not named in outputActions are left unchanged.
%
% Arguments:
% sma: A state machine description created with NewStateMachine()
% stateNumber: The index of the state in sma.StateNames
% stateName: The name of the state (used in error messages)
% outputActions: A cell array of output action names and values, e.g. {'LEDState', 1, 'BNC1', 1}
%
% Returns: sma, the updated state machine description

global BpodSystem % Import the global BpodSystem object

outputChannelNames = BpodSystem.StateMachineInfo.OutputChannelNames;
metaActions = {'ValveState', 'LED', 'LEDState', 'BNCState', 'WireState', 'Valve'};
% ValveState is a byte whose bits control an array of valves
% LED is an alternate syntax for PWM1-8,specifying one LED to set to max brightness (1-8)
% LEDState is an alternate syntax for PWM1-8. A byte coding for binary sets which LEDs are at max brightness
% BNCState and WireState are added for backwards compatability with Bpod
% 0.5. A byte is converted to bits to control logic on the BNC and Wire outputs channel arrays

% Check for duplicate outputs
outputChannels = outputActions(1:2:end);
[~, uniqueIndexes] = unique(outputChannels, 'stable');
if length(outputChannels) > length(uniqueIndexes)
    firstViolation = find(uniqueIndexes' ~= 1:length(uniqueIndexes), 1);
    if isempty(firstViolation)
        firstViolation = length(uniqueIndexes)+1;
    end
    outputChDuplicated = outputChannels{firstViolation};
    error(['Duplicate output actions detected in state: ' stateName '. Only one value for ' outputChDuplicated ' is allowed.'])
end

% Add output actions
for x = 1:2:length(outputActions)
    metaAction = find(strcmp(outputActions{x}, metaActions));
    if ~isempty(metaAction)
        value = outputActions{x+1};
        switch metaAction
            case 1
                valvePos = BpodSystem.HW.Pos.Output_Valve;
                valveLogic = double(dec2bin(value) == '1');
                valveLogic = valveLogic(end:-1:1);
                nValvesAddressed = length(valveLogic);
                if nValvesAddressed > BpodSystem.HW.n.Valves
                    error(['Error: tried to access valve# ' num2str(nValvesAddressed) ' but only '...
                        num2str(BpodSystem.HW.n.Valves) ' valves exist on the connected state machine.'])
                else
                    valveLogic = [valveLogic zeros(1,BpodSystem.HW.n.Valves-length(valveLogic))];
                    sma.OutputMatrix(stateNumber,valvePos:valvePos+BpodSystem.HW.n.Valves-1) = valveLogic;
                end
            case 2
                if value > 0
                    sma.OutputMatrix(stateNumber,BpodSystem.HW.Pos.Output_PWM+value-1) = 255;
                end
            case 3
                for i = 1:BpodSystem.HW.n.Ports
                    sma.OutputMatrix(stateNumber,BpodSystem.HW.Pos.Output_PWM+i-1) = bitget(value, i)*255;
                end
            case 4
                for i = 1:BpodSystem.HW.n.BNCOutputs
                    sma.OutputMatrix(stateNumber,BpodSystem.HW.Pos.Output_BNC+i-1) = bitget(value, i)*255;
                end
            case 5
                for i = 1:BpodSystem.HW.n.WireOutputs
                    sma.OutputMatrix(stateNumber,BpodSystem.HW.Pos.Output_Wire+i-1) = bitget(value, i)*255;
                end
            case 6
                if value > 0
                    sma.OutputMatrix(stateNumber,BpodSystem.HW.Pos.Output_Valve+value-1) = 1;
                end
        end
    else
        targetOutputChannel = find(strcmp(outputActions{x}, outputChannelNames));
        if ~isempty(targetOutputChannel)
            value = outputActions{x+1};
            implicitMessageAdded = false;
            if targetOutputChannel <= BpodSystem.HW.n.Outputs
                if BpodSystem.HW.Outputs(targetOutputChannel) == 'U'
                    if length(value) > 1 || ischar(value)
                        [sma, value] = addImplicitSerialMessage(sma, targetOutputChannel, value);
                        implicitMessageAdded = true;
                    end
                end
            end
            if ~implicitMessageAdded
                vLength = length(value);
                if vLength == 1
                    if (targetOutputChannel == BpodSystem.HW.Pos.GlobalTimerTrig) || (targetOutputChannel == BpodSystem.HW.Pos.GlobalTimerCancel)
                        % For backwards compatability, integers specifying
                        % global timers convert to equivalent binary decimals. To
                        % specify binary, use a string of bits.
                        value = 2^(value-1);
                    elseif BpodSystem.MachineType == 4
                        if (targetOutputChannel >= BpodSystem.HW.Pos.Output_FlexIO) && (targetOutputChannel < BpodSystem.HW.Pos.Output_BNC)
                            % If FlexIO channel is analog output, convert volts to bits
                            targetFlexIOChannel = targetOutputChannel - (BpodSystem.HW.Pos.Output_FlexIO-1);
                            if BpodSystem.HW.FlexIO_ChannelTypes(targetFlexIOChannel) == 3
                                maxFlexIOVoltage = 5;
                                if (value > maxFlexIOVoltage) || (value < 0)
                                    error('Error: Flex I/O channel voltages must be in range [0, 5]');
                                end
                                value = uint16((value/maxFlexIOVoltage)*4095);
                            else
                                value = uint16(value);
                            end
                        else
                            value = uint16(value);
                        end
                    else
                        value = uint8(value);
                    end
                elseif ischar(value) && ((sum(value == '0') + sum(value == '1')) == length(value))
                    % Assume binary string, convert to decimal
                    value = bin2dec(value);
                end
            end
            sma.OutputMatrix(stateNumber,targetOutputChannel) = value;
        else
            error(['Unknown output action found: ''' outputActions{x} ''' in state: ''' stateName '''.' char(10)...
                'A list of registered output action names is given <a href="matlab:BpodSystemInfo;">here</a>.']);
        end
    end
end
