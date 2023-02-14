This example Bonsai workflow sends a byte (3) directly to the state machine's App serial port, resulting in an APP_SoftCode3 event.
NOTE: This example requires state machine r2 or newer, with firmware v23 and Bpod Console v1.71 or newer
ALSO NOTE: This example relies on a C# workaround. Future versions of Bonsai may include a specialized source and sink for 
           writing bytes to serial ports.

Usage:
-From the Bpod Console, click the info icon (magnifying glass)
-Note the name of the App Serial Port in the 'State Machine' hardware description (on the left side of the info panel). 
 It should be 'COM3' or similar.
-In the Bonsai workflow, select the 'USBSerial' sink and set the 'PortName' property equal to the app serial port name.
-The default byte to send is 3. To send a different byte (in range 0-14) select the 'Byte' source and adjust the 'Value' property.
-Run any Bpod protocol
-When the Bonsai workflow is run, the APP_SoftCode3 event will be received by the state machine.