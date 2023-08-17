This Bonsai example acts as an echo server. It opens the state machine's app serial port and waits for bytes to arrive. Bonsai reads any bytes arriving from the state machine, and sends the same bytes back, generating Bpod events.

Use this with /Bpod_Gen2/Examples/State Machines/USB Soft Codes/SoftCode_2_App.m
This example sends byte 0x5 to Bonsai, and waits for 1 second. Bonsai immediately returns the byte, creating a APP_SoftCode5 event. On our test PC, round trip latency was 0.5ms.

In the Bonsai layout, in the 'CreateSerialPort' source, you'll need to update the name of the port to match the state machine's App serial port (see 'Info' by clicking the spyglass icon on the Bpod console). Also note that the 'DtrEnable' property must be set to 'true'.