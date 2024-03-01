function firmware = CurrentFirmwareList

% Returns a struct with current firmware versions for state machine + modules.

firmware = struct;
firmware.StateMachine = 23;
firmware.StateMachine_Minor = 10;
firmware.WavePlayer = 6;
firmware.AudioPlayer = 3;
firmware.PulsePal = 4;
firmware.AnalogIn = 7;
firmware.DDSModule = 2;
firmware.DDSSeq = 1;
firmware.I2C = 1;
firmware.PA = 2;
firmware.ValveModule = 2;
firmware.RotaryEncoder = 6;
firmware.EchoModule = 1;
firmware.AmbientModule = 2;
firmware.HiFi = 5;