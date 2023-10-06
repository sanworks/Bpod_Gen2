In this example, Bonsai acts as an echo server. It opens the state machine's app serial port and waits for bytes to arrive. Bonsai reads any bytes arriving from the state machine, and sends the same bytes back, generating Bpod events.

To get started, follow the instructions in the APP_SoftCode_Example.m file in this folder.

Important notes: 
1. In Bonsai, the "Bonsai - System Library" package must be installed. Add packages using 
Tools > Manage Packages.

2. In the Bonsai layout, in the 'CreateSerialPort', 'SerialRead' and 'SerialWrite' nodes, you'll need to update the name of the port to match the state machine's App serial port (see 'Info' by clicking the spyglass icon on the Bpod console). Also note that the 'DtrEnable' property must be set to 'true'.