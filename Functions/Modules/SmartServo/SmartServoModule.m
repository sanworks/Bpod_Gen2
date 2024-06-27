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

% SmartServoModule is a class to interface with the Bpod Smart Servo Module
% via its USB connection to the PC.
%
% User-configurable device parameters are exposed as class properties. Setting
% the value of a property will trigger its 'set' method to update the device.
%
% The Smart Servo Module has 3 channels, each of which control up to 8
% daisy-chained motors.
%
% Example usage:
%
% S = SmartServoModule('COM3'); % Create an instance of SmartServoModule,
%                               connecting to the Bpod Smart Servo Module on port COM3
%
% ---SmartServoInterface---
% myServo = S.smartServo(2, 1); % Create myServo, a SmartServoInterface object to control
%                                 the servo on channel 2 at address 1
% Note that SmartServoInterface objects for detected servos are auto-initialized at S.motor(channel, address)

% myServo.setPosition(90); % Move servo shaft to 90 degrees using current velocity and acceleration
% myServo.setPosition(0, 1, 100); % Return shaft to 0 degrees at up to 1 rev/s with 100 rev/s^2 acceleration
% myServo.setMode(4); % Set servo to continuous rotation mode with velocity control
% myServo.setVelocity(-0.5); % Start rotating clockwise at 0.5 rev/s
% myServo.setVelocity(0); % Stop rotating
% myServo.setMode(5); % Set servo to step mode (movements defined relative to current position)
% myServo.step(-3000); % Rotate clockwise 3000 degrees using current velocity and acceleration
% clear myServo; 
% 
% ---Motor Programs---
% prog1 = S.newProgram; % Create a new motor program
% prog1 = S.addMovement(prog1, 'Channel', 2,...        % Target motor channel (1-3)
%                          'Address', 1,...            % Target motor address (1-8)
%                          'GoalPosition', 90,...      % degrees
%                          'MaxVelocity', 100,...      % RPM
%                          'MaxAcceleration', 100,...  % rev/min^2
%                          'OnsetTime', 1.520);        % seconds after program start
% % --Note: Add as many steps to prog1 as necessary with additional calls to addStep()
% S.loadProgram(2, prog1); % Load prog1 to program index 2 on the device
% S.runProgram(2); % Run program 2
%
% ---Motor Address Change---
% S.setMotorAddress(1, 2, 4); % Change a motor's address on channel 1 from
%                               2 to 4. This is a necessary step for
%                               setting up multiple daisy-chained motors
%                               per channel. The new address is stored in 
%                               the motor EEPROM and persists across power cycles.
% 
% clear S; % clear the objects from the workspace, releasing the USB serial port

classdef SmartServoModule < handle

    properties
        port % ArCOM Serial port
        firmwareVersion
        hardwareVersion
        dioTargetProgram  % Target motor program for each DIO channel to start/stop
        dioFallingEdgeOp  % 0 = No Operation, 1 = Start Target Program, 
                          % 2 = Stop Target Program, 3 = Emergency Stop-All
        dioRisingEdgeOp   % 0 = No Operation, 1 = Start Target Program, 
                          % 2 = Stop Target Program, 3 = Emergency Stop-All
        dioDebounce       % Debounce interval for DIO channels 
                          % (adjust if required for mechanical pushbuttons)
        motor             % An array of SmartServoInterface objects to control each motor
    end

    properties (Access = private)
        modelNumbers = [1200 1190 1090 1060 1070 1080 1220 1210 1240 1230 1160 1120 1130 1020 1030 ...
                        1100 1110 1010 1000]; % Numeric code for Dynamixel X-series models
        modelNames = {'XL330-M288', 'XL330-M077', '2XL430-W250', 'XL430-W250',...
                      'XC430-T150/W150', 'XC430-T240/W240', 'XC330-T288', 'XC330-T181',...
                      'XC330-M288', 'XC330-M181', '2XC430-W250', 'XM540-W270', 'XM540-W150',...
                      'XM430-W350', 'XM430-W210', 'XH540-W270', 'XH540-W150', 'XH430-W210', 'XH430-W350'};
        liveInstance = zeros(3, 3); % Indicates motors that have been initialized as external SmartServoInterface objects
                                  % 0 = not active, 1 = active. See newSmartServo() below
        isConnected = zeros(3, 3); % Indicates whether a servo was detected at (channel, address)
                                     % 0 = not detected, 1 = detected
        detectedModelName = cell(3, 3); % Stores the model name for each detected motor
        validProgramMoveTypes = {'velocity', 'current_limit'};
        opMenuByte = 212; % Byte code to access op menu via USB
        maxPrograms % Maximium number of motor programs that can be stored on the device
        maxSteps % Maximum number of steps per motor program
        programLoaded  % Indicates whether programs are loaded
    end

    methods
        function obj = SmartServoModule(portString)
            % Constructor, called when a new SmartServoModule object is created

            % Open the USB Serial Port
            obj.port = ArCOMObject_Bpod(portString, 480000000);

            % Handshake
            obj.port.write([obj.opMenuByte 249], 'uint8'); % Handshake
            reply = obj.port.read(1, 'uint8');
            if reply ~= 250
                error(['Error connecting to smart servo module. The device at port ' portString... 
                       ' returned an incorrect handshake.'])
            end

            % Get module information
            obj.port.write([obj.opMenuByte '?'], 'uint8'); 
            obj.firmwareVersion = obj.port.read(1, 'uint32');
            obj.hardwareVersion = obj.port.read(1, 'uint32');
            obj.maxPrograms = double(obj.port.read(1, 'uint32'));
            obj.maxSteps = double(obj.port.read(1, 'uint32'));

            % Detect connected motors
            obj.detectMotors;
            obj.programLoaded = zeros(1, obj.maxPrograms);

            % Set defaults (auto-sync to device)
            obj.dioTargetProgram = [1 1 1];
            obj.dioFallingEdgeOp = [0 0 0];
            obj.dioRisingEdgeOp = [0 0 0];
            obj.dioDebounce = [0.01 0.01 0.01];
        end

        function STOP(obj)
            % EMERGENCY STOP
            % This function stops all motors by setting their torque to 0.
            % It also stops any ongoing motor programs.
            % After an emergency stop, torque must be re-enabled manually by setting motorMode for each motor.
            obj.port.write([obj.opMenuByte '!'], 'uint8');
            confirmed = obj.port.read(1, 'uint8');
            if confirmed ~= 1
                error('***ALERT!*** Emergency stop not confirmed.');
            end
            disp('!! Emergency Stop Acknowledged !!'); 
            disp('All motors now have torque disabled.')
            disp('Re-enable motor torque by setting motorMode for each motor.')
        end

        function stop(obj, chan, addr)
            % Stop a specific motor
            % Arguments:
            % chan: the target motor channel 
            % addr: the target motor address
            obj.port.write([obj.opMenuByte 'X' chan addr], 'uint8');
            obj.confirmTransmission(['stopping motor on channel: ' num2str(chan) ' address: ' num2str(addr)]);
        end

        function set.dioTargetProgram(obj, newPrograms)
            if length(newPrograms) ~= 3
                error('newPrograms must be a 1x3 array of program indexes')
            end
            obj.port.write([obj.opMenuByte '=' newPrograms-1], 'uint8');
            obj.confirmTransmission('setting DIO target program');
            obj.dioTargetProgram = newPrograms;
        end

        function set.dioFallingEdgeOp(obj, newOps)
            if length(newOps) ~= 3 || min(newOps) < 0 || max(newOps) > 3
                error('newOps must be a 1x3 array of operation codes in range 0-3')
            end
            obj.port.write([obj.opMenuByte '-' newOps], 'uint8');
            obj.confirmTransmission('setting falling edge operations');
            obj.dioFallingEdgeOp = newOps;
        end

        function set.dioRisingEdgeOp(obj, newOps)
            if length(newOps) ~= 3 || min(newOps) < 0 || max(newOps) > 3
                error('newOps must be a 1x3 array of operation codes in range 0-3')
            end
            obj.port.write([obj.opMenuByte '+' newOps], 'uint8');
            obj.confirmTransmission('setting rising edge operations');
            obj.dioRisingEdgeOp = newOps;
        end

        function set.dioDebounce(obj, newDebounce)
            if length(newDebounce) ~= 3 || min(newDebounce) < 0 || max(newDebounce) > 1
                error('newDebounce must be a 1x3 array of debounce intervals in range 0-1 seconds')
            end
            obj.port.write([obj.opMenuByte '~'], 'uint8', newDebounce*10000, 'uint32');
            obj.confirmTransmission('setting debounce intervals');
            obj.dioDebounce = newDebounce;
        end

        function newSmartServo = smartServo(obj, channel, address)
            % Create a new smart servo object, addressing a single motor on the module
            % Arguments:
            % channel: The target motor's channel on the smart servo module (1-3)
            % address: The target motor's address on the target channel (1-8)
            %
            % Returns:
            % smartServo, an instance of SmartServoInterface.m connected addressing the target servo
                if obj.isConnected(channel, address)
                    newSmartServo = SmartServoInterface(obj.port, channel, address, obj.detectedModelName{channel, address});
                    obj.liveInstance(channel, address) = 1;
                else
                    error(['No motor registered on channel ' num2str(channel) ' at address ' num2str(address) '.' ...
                           char(10) 'If a new servo was recently connected, run detectMotors().'])
                end
        end

        function detectMotors(obj)
            % detectMotors() detects motors connected to the smart servo module.
            % detectMotors() is run on creating a new SmartServoModule object.
            % This function must be run manually after attaching a new motor.

            disp('Detecting motors...');
            obj.port.write([obj.opMenuByte 'D'], 'uint8');
            pause(1);
            nMotorsFound = floor(obj.port.bytesAvailable/6);
            detectedChannel = [];
            detectedAddress = [];
            for i = 1:nMotorsFound
                motorChannel = obj.port.read(1, 'uint8');
                motorAddress = obj.port.read(1, 'uint8');
                motorModel = obj.port.read(1, 'uint32');
                modelName = 'Unknown model';
                modelNamePos = find(motorModel == obj.modelNumbers);
                if ~isempty(modelNamePos)
                    modelName = obj.modelNames{modelNamePos};
                end
                obj.isConnected(motorChannel, motorAddress) = 1;
                obj.detectedModelName{motorChannel, motorAddress} = modelName;
                disp(['Found: Ch: ' num2str(motorChannel) ' Address: ' num2str(motorAddress) ' Model: ' modelName]);
                detectedChannel = [detectedChannel motorChannel];
                detectedAddress = [detectedAddress motorAddress];
            end

            % Set up motor objects
            obj.motor = repmat(SmartServoInterface(-1, -1, -1, -1), 3, 3);
            for chan = 1:3
                for addr = 1:3
                    if obj.isConnected(chan, addr)
                        obj.motor(chan, addr) = SmartServoInterface(obj.port, chan, addr, obj.detectedModelName{chan, addr});
                        obj.motor(chan, addr).controlMode = 1; % Set default control mode
                    else
                        obj.motor(chan, addr) = SmartServoInterface(obj.port, chan, addr, -1);
                    end
                end
            end
        end

        function setMotorAddress(obj, channel, currentAddress, newAddress)
            % setMotorAddress() sets a new motor address for a motor on a given channel, 
            % e.g. for daisy-chain configuration.
            % The new address is written to the motor's EEPROM, and will persist across power cycles.
            %
            % Arguments:
            % channel: The target motor's channel on the smart servo module (integer in range 1-3)
            % currentAddress: The target motor's current address on the target channel (integer in range 1-3)
            % newAddress: The new address of the target motor
            %
            % Returns:
            % None
            
            if obj.liveInstance(channel, currentAddress)
                error(['setMotorAddress() cannot be used if a user object to control the target motor has ' ...
                       char(10) 'already been created with newSmartServo().'])
            end
            if ~obj.isConnected(channel, currentAddress)
                error(['No motor registered at channel: ' num2str(channel) ' address: ' num2str(currentAddress) '.' ...
                           char(10) 'If a new servo was recently connected, run detectMotors().'])
            end
            if obj.isConnected(channel, newAddress)
                error(['A motor is already registered at channel: ' num2str(channel) ' address: ' num2str(newAddress)])
            end
            
            % Sets the network address of a motor on a given channel
            obj.port.write([obj.opMenuByte 'I' channel currentAddress newAddress], 'uint8');
            obj.confirmTransmission('setting motor address');
            obj.motor(channel, currentAddress) = SmartServoInterface(obj.port, channel, currentAddress, -1);
            obj.isConnected(channel, currentAddress) = 0;
            disp('Address change acknowledged.')
            obj.detectMotors;
            obj.motor(channel, newAddress) = SmartServoInterface(obj.port, channel, newAddress, obj.detectedModelName{channel, newAddress});
        end

        function bytes = param2Bytes(obj, paramValue)
            % param2Bytes() is a convenience function for state machine control. Position,
            % velocity, acceleration, current and rev/s values must be
            % converted to bytes for use with the state machine serial interface.
            % Arguments:
            % paramValue, the value of the parameter to convert (type = double or single)
            %
            % Returns:
            % bytes, a 1x4 vector of bytes (type = uint8)
            bytes = typecast(single(paramValue), 'uint8');
        end

        function program = newProgram(obj)
            % Returns a blank motor program for use with addMovement()
            % and sendMotorProgram().
            % Arguments: None
            % Return: program, a struct containing a blank motor program
                program = struct;
                program.nSteps = 0;
                program.moveType = 'velocity'; % must be either 'velocity' or 'current_limit'
                program.nLoops = 0;
                program.channel = zeros(1, obj.maxSteps);
                program.address = zeros(1, obj.maxSteps);
                program.goalPosition = zeros(1, obj.maxSteps);
                program.movementLimit = zeros(1, obj.maxSteps);
                program.stepTime = zeros(1, obj.maxSteps);
        end

        function program = addMovement(obj, program, varargin)
            % addMovement() adds a movement to an existing motor program.
            %
            % Arguments:
            % program: The program struct to be extended with a new step
            % channel: The target motor's channel on the Smart Stepper Module (integer in range 1-3)
            % address: The target motor's address on the target channel (integer in range 1-8)
            % goalPosition: The position the motor will move to on this step (units = degrees)
            % ***Pass only if moveType = 'velocity':
            %          velocity: The maximum velocity of the movement (units = rev/s).
            %          Use 0 for max velocity.
            % ***Pass only if moveType = 'current_limit':
            %          maxCurrent: The maximum current draw for the movement (unit = mA)
            % ***
            % stepTime: The time when this step will begin with respect to motor
            %           program start (units = seconds)
            %
            % Variable arguments must be given as alternating string/value
            % pairs, e.g. ...'maxVelocity', 100... Strings are ignored, but required to make the 
            % function calls human-readable (see example in comments at the top of this file)
            %
            % Returns:
            % program, the original program struct modified with the added step

            % Extract args
            if nargin ~= 12
                error('Incorrect number of arguments');
            end
            channel = varargin{2};
            address = varargin{4};
            goalPosition = varargin{6};
            movementLimit = varargin{8};
            stepTime = varargin{10};
            nSteps = program.nSteps + 1;
            program.nSteps = nSteps;
            program.channel(nSteps) = channel;
            program.address(nSteps) = address;
            program.goalPosition(nSteps) = goalPosition;
            program.movementLimit(nSteps) = movementLimit;
            program.stepTime(nSteps) = stepTime;
        end

        function program = setLoopDuration(obj, program, loopDuration)
            % setLoopDuration() sets a duration for which to loop an existing motor program.
            % A looping program returns to time 0 each time it completes its sequence of steps, 
            % and continues looping the program until loopDuration seconds.
            %
            % Arguments:
            % program: The program struct to be modified with the new loop duration
            % loopDuration: The duration for which to loop the motor
            % program each time it is run (units = seconds)
            %
            % Returns:
            % program, the original program struct modified with the new loop duration

            program.loopDuration = loopDuration;
        end

        function loadProgram(obj, programIndex, program)
            % loadProgram() loads a motor program to the Smart Servo Module's memory.
            % The Smart Servo Module can store up to 100 programs of up to 256 steps each.
            %
            % Arguments:
            % programIndex: The program's index on the device (integer in range 0-99)
            % program: The program struct to load to the device at position programIndex

            nSteps = program.nSteps;
            nLoops = program.nLoops;
            moveType = program.moveType;
            channel = program.channel(1:nSteps);
            address = program.address(1:nSteps);
            goalPosition = program.goalPosition(1:nSteps);
            movementLimit = program.movementLimit(1:nSteps);
            stepTime = program.stepTime(1:nSteps)*1000;

            % If necessary, sort moves by timestamps
            if sum(diff(stepTime) < 0) > 0 % If any timestamps are out of order
                [~, sIndexes] = sort(stepTime);
                channel = channel(sIndexes);
                address = address(sIndexes);
                goalPosition = goalPosition(sIndexes);
                movementLimit = movementLimit(sIndexes);
                stepTime = stepTime(sIndexes);
            end
            
            % Convert move type string to integer
            [~, moveTypeInteger] = ismember(moveType, obj.validProgramMoveTypes);

            % Convert the program to a byte string
            programBytes = [obj.opMenuByte 'L' uint8(programIndex-1) uint8(nSteps) uint8(moveTypeInteger-1)...
                            uint8(channel) uint8(address)...
                            typecast(single(goalPosition), 'uint8')...
                            typecast(single(movementLimit), 'uint8')...
                            typecast(uint32(stepTime), 'uint8')...
                            typecast(uint32(nLoops), 'uint8')];

            % Send the program and read confirmation
            obj.port.write(programBytes, 'uint8');
            obj.confirmTransmission('loading motor program');
            obj.programLoaded(programIndex) = 1;
        end

        function runProgram(obj, programIndex)
            % runProgram() runs a previously loaded motor program. Programs
            % can also be run directly from the state machine with the 'R'
            % command (see 'Serial Interfaces' section on the Bpod wiki)
            % 
            % Arguments: 
            % programIndex: The index of the program to run (integer, range = 0-99)
            if obj.programLoaded(programIndex) == 0
                error(['Cannot run motor program ' num2str(programIndex)... 
                       '. It must be loaded to the device first.'])
            end
            obj.port.write([obj.opMenuByte 'R' programIndex-1], 'uint8');
        end


        function delete(obj)
            % Class destructor, called when the SmartServoModule is cleared
            obj.port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end

    end
    methods (Access = private)
        function confirmTransmission(obj, opName)
            % Read op confirmation byte, and throw an error if confirm not returned
            
            confirmed = obj.port.read(1, 'uint8');
            if confirmed == 0
                error(['Error ' opName ': the module denied your request.'])
            elseif confirmed ~= 1
                error(['Error ' opName ': module did not acknowledge the operation.']);
            end
        end
    end
end