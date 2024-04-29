% Example Smart Servo motor program: Two Moves
% This example motor program demonstrates a program with a sequence of two position moves.

%S = SmartServoModule('COM3'); % Replace 'COM3' with the SmartServoModule's serial port name

prog1 = S.newProgram; % Create a new motor program
prog1 = S.addMovement(prog1, 'Channel', 1,...            % Target motor channel (1-3)
                             'Address', 1,...            % Target motor address (1-8)
                             'GoalPosition', 90,...      % degrees
                             'MaxVelocity', 200,...      % units = RPM, use 0 for max
                             'MaxAcceleration', 50,...  % units = rev/min^2, use 0 for max
                             'OnsetTime', 0);            % seconds after program start

prog1 = S.addMovement(prog1, 'Channel', 1,...            
                             'Address', 1,...            
                             'GoalPosition', 0,...       % This time move to 0 degrees
                             'MaxVelocity', 0,...        % Max velocity
                             'MaxAcceleration', 0,...    % Max acceleration
                             'OnsetTime', 1);            % Start this move at 1 second

S.loadProgram(2, prog1); % Load prog1 to program index 2 on the device
S.runProgram(2); % Run program 2. This can also be done from the state machine in the output actions of a state:
                 % {'SmartServo1', ['R' 1]}; % Note that 0-indexing is used to address programs on the Arduino side
