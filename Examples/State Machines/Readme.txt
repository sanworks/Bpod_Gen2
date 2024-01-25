This folder contains example Bpod state machine descriptions.
To run an example in this folder,

1. Run the .m file, creating sma in the base workspace
2. At the command prompt, run: SendStateMachine(sma); % Send via USB to Bpod State Machine
3. At the command prompt, run: rawEvents = RunStateMachine; % Run trial and return events

The state machine will run until the '>exit' state is reached.
rawEvents is a struct with event codes, state codes and timestamps.
A table of event codes can be opened from Bpod Console using the magnifier icon.
A list of state codes for the most recent trial is in: BpodSystem.StateMatrix.StateNames

In a behavior protocol, rawEvents is passed to AddTrialEvents() to assemble session data
trial-wise, in a human-readable format.