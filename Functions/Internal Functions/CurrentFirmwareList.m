function Firmware = CurrentFirmwareList

% Retuns a struct with current firmware versions for 
% state machine + all curated modules.

Firmware = struct;
Firmware.StateMachine = 23;
Firmware.StateMachine_Minor = 10;
Firmware.WavePlayer = 4;
Firmware.AudioPlayer = 3;
Firmware.PulsePal = 4;
Firmware.AnalogIn = 5;
Firmware.DDSModule = 2;
Firmware.DDSSeq = 1;
Firmware.I2C = 1;
Firmware.PA = 2;
Firmware.ValveDriver = 1;
Firmware.RotaryEncoder = 6;
Firmware.EchoModule = 1;
Firmware.AmbientModule = 2;
Firmware.HiFi = 4;