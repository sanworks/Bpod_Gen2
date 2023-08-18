% Example Bpod code that exchanges a byte code with Bonsai via the state machine's APP serial port.
% The APP serial port name can be found from the info (spyglass) icon on the Bpod console GUI.
% Note: This feature is only available on FSM 2 or newer, and requires Firmware v23
%
% To run the example:
% 1. Run the Bonsai app in this folder.
% 2. Run this .m file
%
% How it works:
% - The Bonsai app opens the Bpod APP serial port and acts as an echo server,
%   returning any bytes it reads from the state machine.
% - Bpod enters a state where it sends a byte to Bonsai via the APP port: 0x5. 
% - It then enters a second state where it waits for Bonsai to return the
%   same byte. 
% - On receiving the byte from Bonsai, the state machine exits, and the
%   round-trip latency is calculated from Bpod's timestamps.

try
    Bpod;
catch
    % Bpod was already started
end

Byte2Send = 5;
EventName = ['APP_SoftCode' num2str(Byte2Send)]; % Name of event generated when Bonsai returns the byte

% Set up state machine
sma = NewStateMachine(); % Initialize a blank state machine description

sma = AddState(sma, 'Name', 'SendSoftCode2Bonsai', ... % This state sends the byte 0x5 to Bonsai via the APP serial port
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'ReceiveSoftCodeFromBonsai'},...
    'OutputActions', {'APP_SoftCode', Byte2Send});

sma = AddState(sma, 'Name', 'ReceiveSoftCodeFromBonsai', ... % This state waits for the APP_SoftCode5 event, then exits the trial
    'Timer', 0,...
    'StateChangeConditions', {EventName, '>exit'},...
    'OutputActions', {});

% Send the state machine description to the Bpod Finite State Machine device
SendStateMachine(sma); 

% Run the state machine, and return event and state timestamps
disp('Running state machine...')
RawEvents = RunStateMachine; 
disp('State machine exited.')

% Make the timestamps human-readable
TE = struct; % Create an empty struct
TE = AddTrialEvents(TE, RawEvents); % Add raw events to the struct

% Calculate and display the round trip latency
startTime = TE.RawEvents.Trial{1}.States.SendSoftCode2Bonsai(1);
endTime = TE.RawEvents.Trial{1}.Events.APP_SoftCode5(1);
disp(['Round trip latency: ' num2str(endTime-startTime) ' seconds']);