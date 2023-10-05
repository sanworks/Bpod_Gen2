% Example state matrix: Switches states when soft code 5 arrives from an 
% external app connected to the state machine's app serial port.
% The name of the app serial port is at: BpodSystem.HW.AppSerialPortName
% Note: This feature is only available on FSM 2 or newer, and requires Firmware v23
%
% To test the soft code within MATLAB, you'll need access to the command line - so
% you can't use RunStateMachine(). Instead, create a TrialManagerObject:
% T = TrialManagerObject;
% Then create an ArCOM serial object with the app serial port:
% A = ArCOMObject_Bpod(BpodSystem.HW.AppSerialPortName);
% Then, Run the state machine with:
% T.startTrial(sma);
% While the trial is running, send soft code 5 with:
% A.write(5, 'uint8');
% When the trial is over, get the raw data with:
% RawEvents = T.getTrialData;
% Finally, clear the trial manager and the app serial port:
% clear A T
%
% IMPORTANT NOTE: app event byte codes are 0-indexed, in range 0-14

sma = NewStateMatrix();

sma = AddState(sma, 'Name', 'Port1LightOn', ...
    'Timer', 1,...
    'StateChangeConditions', {'APP_SoftCode5', 'Port2LightOn'},...
    'OutputActions', {'PWM1', 255});
sma = AddState(sma, 'Name', 'Port2LightOn', ...
    'Timer', 1,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', {'PWM2', 255});