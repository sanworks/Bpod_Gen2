%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) Sanworks LLC, Rochester, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}

% This example Bpod code exchanges a byte code with Bonsai via the state machine's APP serial port.
% The APP serial port name can be found from the info (spyglass) icon on the Bpod console GUI.
% Note: This feature is only available on FSM 2 or newer, and requires Firmware v23
%
% To run the example:
% 1. Launch the Bpod console and find your APP serial port name by clicking the info (spyglass) icon  
% 2. Launch Bonsai in this folder and load the workflow in this folder
% 3. In the Bonsai workflow, click on each of the three nodes and change the PortName to the APP serial port name
% 4. Run the workflow (click Start)
% 5. Run this .m file
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

byte2Send = 5;
eventName = ['APP_SoftCode' num2str(byte2Send)]; % Name of event generated when Bonsai returns the byte

% Set up state machine
sma = NewStateMachine(); % Initialize a blank state machine description

sma = AddState(sma, 'Name', 'SendSoftCode2Bonsai', ... % This state sends the byte 0x5 to Bonsai via the APP serial port
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'ReceiveSoftCodeFromBonsai'},...
    'OutputActions', {'APP_SoftCode', byte2Send});

sma = AddState(sma, 'Name', 'ReceiveSoftCodeFromBonsai', ... % This state waits for the APP_SoftCode5 event, then exits the trial
    'Timer', 0,...
    'StateChangeConditions', {eventName, '>exit'},...
    'OutputActions', {});

% Send the state machine description to the Bpod Finite State Machine device
SendStateMachine(sma); 

% Run the state machine, and return event and state timestamps
disp('Running state machine...')
rawEvents = RunStateMachine; 
disp('State machine exited.')

% Make the timestamps human-readable
TE = struct; % Create an empty struct
TE = AddTrialEvents(TE, rawEvents); % Add raw events to the struct

% Calculate and display the round trip latency
startTime = TE.RawEvents.Trial{1}.States.SendSoftCode2Bonsai(1);
endTime = TE.RawEvents.Trial{1}.Events.APP_SoftCode5(1);
disp(['Round trip latency: ' num2str(endTime-startTime) ' seconds']);