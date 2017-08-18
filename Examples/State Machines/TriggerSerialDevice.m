<<<<<<< HEAD
% Example state matrix: Writes a byte to serial devices 1 and 2. 
global BpodSystem
ByteForSerial1 = 65;
ByteForSerial2 = 66;
ByteForSerial3 = 67;

sma = NewStateMatrix();
if BpodSystem.FirmwareBuild > 6
% For Bpod 0.7
sma = AddState(sma, 'Name', 'SendSerial1', 'Timer', 0, ... 
                    'StateChangeConditions', {'Tup', 'exit'}, ... 
                    'OutputActions', {'Serial1', ByteForSerial1, 'Serial2', ByteForSerial2, 'Serial3', ByteForSerial3});
else
% For Bpod 0.5
sma = AddState(sma, 'Name', 'SendSerial1', 'Timer', 0, ... 
                    'StateChangeConditions', {'Tup', 'exit'}, ... 
                    'OutputActions', {'Serial1', ByteForSerial1, 'Serial2', ByteForSerial2});
end
=======
% Example state machine: Writes a byte to serial devices 1 and 2. 

ByteForSerial1 = 65;
ByteForSerial2 = 66;

sma = NewStateMachine();

sma = AddState(sma, 'Name', 'SendSerial1', 'Timer', 0, ... 
                    'StateChangeConditions', {'Tup', 'exit'}, ... 
                    'OutputActions', {'Serial1', ByteForSerial1, 'Serial2', ByteForSerial2});
>>>>>>> 9dd1b1005e57c9d9ff3bf3532524677d5dfa1801
