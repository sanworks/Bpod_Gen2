# Bpod 2nd Generation Code Repository

This repository includes:
-MATLAB software for Bpod.
-Example settings files
-Example module firmware

To get started, follow the setup instructions on the Bpod Wiki:
https://sites.google.com/site/bpoddocumentation/installing-bpod

### Edits to run without GUI

#### Starting Bpod

Two new parameters have been added to Bpod objects. The third argument is a logical to show the GUI (1) or not (0). The fourth argument is a name you can pass to the Bpod. If you don't pass a name, Bpod runs as normal. If you do use a name, the name will be displayed in the title of the console and liquid calibration windows. Also, the liquid calibration file will be changed from 'LiquidCalibration.mat' to 'LiquidCalibration_<Name>.mat'
  
To begin, just open MATLAB and run:
```
SerialPort = 'EMU'; % for emulator
ForceJava = 0;
ShowGUI = 0; %0 to not show, 1 to run as normal
Name = 'MyBpod';
Bpod(SerialPort, ForceJava, ShowGUI, Name);
```

Next you can open the liquid calibration GUI or run protocols from the command line:
```
BpodLiquidCalibration('Calibrate');

Protocol = 'MyProtocol';
Subject = 'MySubject';
RunProtocol('Start');
``` 

Running a protocol will block the terminal. To manually stop the protocol, you must use a keyboart interrupt (i.e. press Ctrl-C). This will cause Bpod to run `RunProtocol('Stop')`, just as you would manually stop the program using the GUI. It will also throw some benign errors starting with the line: "Operation terminated by user...".

Lastly, if you would like to use the full Bpod Console GUI, you can toggle the GUI on and off by running:
```
BpodSystem.SwitchGUI();
```
The first time `BpodSystem.SwitchGUI();` is run, the console will be initialized (it will take just a few seconds). Each subsequent call will hide and show the GUI quickly.

TODO: Handle the keyboard interrupt more gracefully. Is this possible in MATLAB?
