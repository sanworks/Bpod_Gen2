% Example state machine: Writes a byte to serial devices 1 and 2. 

ByteForSerial1 = 65;
ByteForSerial2 = 66;

sma = NewStateMachine();

sma = AddState(sma, 'Name', 'SendSerial1', 'Timer', 0, ... 
                    'StateChangeConditions', {'Tup', 'exit'}, ... 
                    'OutputActions', {'Serial1', ByteForSerial1, 'Serial2', ByteForSerial2});