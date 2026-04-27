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

% MouseGate is a class to interface with the Bpod Mouse Gate
% via its connection to the Bpod Smart Servo Module.

% Example usage:
%
% S = SmartServoModule('COM3'); % Create an instance of SmartServoModule,
%                               connecting to the Bpod Smart Servo Module on port COM3
% G = MouseGate(S, 1, 1); % Create an instance of MouseGate using Smart Servo 1 on Channel 1
% G.open() % Open the gate (45 degrees, enough for a mouse to pass)
% G.close() % Close the gate
% G.openMax() % Open the gate fully (for removal of the acrylic lining)
% G.setMotorProgram('open', 1); % Set Smart Servo Module program 1 to open the gate
% G.setMotorProgram('close', 2); % Set Smart Servo Module program 2 to close the gate
% clear G % Clear the instance of MouseGate
% clear S % Clear the instance of Smart Servo, freeing its USB serial port

classdef MouseGate < handle

    properties
        openPosition = 45; % Motor position of the gate when open (degrees)
        openCurrent = 100; % Max motor current when opening (mA)
        closedPosition = 0; % Motor position of the gate when closed (degrees)
        closeCurrent = 50; % Max motor current when closing (mA). Keep this value low for safety.
    end

    properties (Access = private)
        S            % The attached instance of SmartServoModule
        motorChannel % The channel the motor is connected to on the Smart Servo Module
        motorAddress   % The address of the motor on its respective channel on the Smart Servo Module
    end

    methods
        function obj = MouseGate(SmartServo, motorChannel, motorAddress)
            obj.S = SmartServo;
            obj.motorChannel = motorChannel;
            obj.motorAddress = motorAddress;
            modelName = obj.S.motor(motorChannel,motorAddress).info.modelName;
            if ~contains(obj.S.motor(motorChannel,motorAddress).info.modelName, 'XC330')
                error(['MouseGate requires an XC330 series motor. Target motor is: ' modelName])
            end
            currentPosition = obj.S.motor(obj.motorChannel, obj.motorAddress).getPosition;
            if currentPosition > 180
                obj.S.motor(obj.motorChannel, obj.motorAddress).controlMode = 5;
                obj.S.motor(obj.motorChannel, obj.motorAddress).step(361-currentPosition);
                pause(.5);
            end
            obj.S.motor(obj.motorChannel, obj.motorAddress).controlMode = 3;
            obj.S.motor(obj.motorChannel, obj.motorAddress).setCurrentLimitedPos(0, obj.openCurrent);
        end
        function open(obj)
            obj.S.motor(obj.motorChannel, obj.motorAddress).setCurrentLimitedPos(obj.openPosition, obj.openCurrent);
        end

        function close(obj)
            obj.S.motor(obj.motorChannel, obj.motorAddress).setCurrentLimitedPos(obj.closedPosition, obj.closeCurrent);
        end

        function openMax(obj)
            obj.S.motor(obj.motorChannel, obj.motorAddress).setCurrentLimitedPos(90, obj.openCurrent);
        end

        function setMotorProgram(obj, programType, programIndex)
            % setMotorProgram() Creates a program to open or close the door and saves it to the  
            % Smart Servo Module's program library.
            % programType: 'open' or 'close'
            % programIndex: The position of the program in the Smart Servo Module's library (1-100)
            % The state machine can then trigger the program in the
            % OutputActions section of AddState() with: {'SmartServo1', ['R' programIndex]}
            % The program can also be triggered using the TTL input channels on the 
            % Smart Servo Module (see docs for configuration)

            switch lower(programType)
                case 'open'
                    goalPosition = obj.openPosition;
                    goalCurrent = obj.openCurrent;
                case 'close'
                    goalPosition = obj.closedPosition;
                    goalCurrent = obj.closeCurrent;
                otherwise
                    error('MouseGate.setMotorProgram(): programType argument must be equal to ''open'' or ''close''')
            end

            prog = obj.S.newProgram; % Create a new motor program
            prog.moveType = 'current_limit';       % Set motion limit to current (defined in mA)
            prog = obj.S.addMovement(prog,    'Channel', obj.motorChannel,...
                                              'Address', obj.motorAddress,...
                                              'GoalPosition', goalPosition,... % degrees
                                              'MaxCurrent', goalCurrent,... % Maximum motor current (mA)
                                              'OnsetTime', 0);            % seconds after program start
            obj.S.loadProgram(programIndex, prog);
        end

        function delete(obj)
            % Class destructor, called when the MouseGate is cleared
            obj.S = [];
        end
    end

end