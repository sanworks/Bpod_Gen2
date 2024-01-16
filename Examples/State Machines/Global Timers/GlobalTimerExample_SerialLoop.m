% Example state matrix: A global timer in "loop mode" triggers the Bpod analog output module in an infinite loop. 
% Looped playback is triggered in the first state. Next, the state machine goes into a state
% where it waits for two events:
% 1. Port1In momentarily enters a state that stops the global timer. The analog output module will stop receiving triggers.
% 2. Port2In Exits the state machine.
% Before the state machine is run, an audio waveform is loaded to the analog output module as sound#2, 
% and a trigger message is loaded to the state machine to trigger sound#2
% on output channel 1.
% NOTE: The analog output module must be loaded with WavePlayer firmware,
% and you must edit the COM port string below to match the correct port on your system.
% Requires: behavior ports or lickometers with visible LEDs connected to Ch1 and Ch2

% Setup analog output module & load waveform
W = BpodWavePlayer('COM3'); % Replace 'COM3' with the analog output module's USB serial port
W.BpodEvents{1} = 'Off'; % Turn off WavePlayer's onset and offset events (there would be too many!)
W.SamplingRate = 44100;
Wave = GenerateSineWave(44100, 2000, 0.05); % Args = SF(Hz), Freq(Hz), Duration(s)
W.loadWaveform(2, Wave);
clear W % Calls the object destructor, frees the serial port

% Set start/stop serial messages on state machine, to trigger the
% WavePlayer. See https://sanworks.github.io/Bpod_Wiki/serial-interfaces/waveplayer-serial-interface/
LoadSerialMessages('WavePlayer1', {['P' 1 1], ['X']}); % These will be referenced below as messages 1 and 2.

% Create state machine
sma = NewStateMachine;
sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', 0.1, 'OnsetDelay', 0,...
                     'Channel', 'WavePlayer1', 'OnMessage', 1, 'OffMessage', 2,...
                     'Loop', 1, 'SendGlobalTimerEvents', 0); % Disable timer start/stop events for each loop cycle
sma = AddState(sma, 'Name', 'TimerTrig', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'WaitForPoke'},...
    'OutputActions', {'GlobalTimerTrig', 1});
sma = AddState(sma, 'Name', 'WaitForPoke', ...
    'Timer', 0,...
    'StateChangeConditions', {'Port1In', 'StopGlobalTimer', 'Port2In', '>exit'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'StopGlobalTimer', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'WaitForPoke'},...
    'OutputActions', {'GlobalTimerCancel', 1});

