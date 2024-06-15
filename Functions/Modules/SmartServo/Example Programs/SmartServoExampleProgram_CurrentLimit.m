% Example Smart Servo motor program demonstrating movement limits.
% Movement 1 is limited by current during its trajectory towards the goal position (100mA).
% Movement 2 is also limited by current during its trajectory towards the goal
% position (20mA). This is analogous to torque control, for movements where
% a limit on the motor's force enroute to the goal is necessary. On the second movement, you will 
% likely find it easier to block the motor shaft with your fingers during the movement. 
% Even if temporarily blocked, the movement will continue until the goal position is reached.

% S = SmartServoModule('COM3'); % Uncomment and replace 'COM3' with the SmartServoModule's serial port name

S.motor(1,1).controlMode = 3; % Mode 3 = current-limited position mode

prog1 = S.newProgram; % Create a new motor program
prog1.moveType = 'current_limit';       % Set motion limit to current (defined in mA)
prog1 = S.addMovement(prog1, 'Channel', 1,...            % Target motor channel (1-3)
                             'Address', 1,...            % Target motor address (1-8)
                             'GoalPosition', 90,...      % degrees
                             'MaxCurrent', 100,...       % Maximum motor current (mA)
                             'OnsetTime', 0);            % seconds after program start

prog1 = S.addMovement(prog1, 'Channel', 1,...            
                             'Address', 1,...
                             'GoalPosition', 0,...      
                             'MaxCurrent', 20,...        
                             'OnsetTime', 1);      

S.loadProgram(2, prog1); % Load prog1 to program index 2 on the device
S.runProgram(2); % Run program 2. This can also be done from the state machine in the output actions of a state:
                 % {'SmartServo1', ['R' 1]}; % Note that 0-indexing is used to address programs on the Arduino side
