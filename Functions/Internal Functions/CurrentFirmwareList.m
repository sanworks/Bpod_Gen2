function Firmware = CurrentFirmwareList

% Retuns a struct with current firmware versions for 
% state machine + all curated modules.

Firmware = struct;
Firmware.StateMachine = 20;
Firmware.WavePlayer = 1;
Firmware.AudioPlayer = 2;
Firmware.PulsePal = 1;
Firmware.AnalogIn = 1;
Firmware.DDSModule = 2;
Firmware.DDSSeq = 1;
Firmware.I2C = 1;
Firmware.ValveDriver = 1;
Firmware.RotaryEncoder = 1;
Firmware.EchoModule = 1;