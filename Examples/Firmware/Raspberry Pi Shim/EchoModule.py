"""
This script creates a simple echo module for Bpod using Raspberry Pi 3 or 4.
Any bytes arriving from the state machine are returned back to it - with one exception.
Byte 255 is not echoed. Instead, it triggers the Rasp. Pi to send a self-description to the state machine.

Connect Raspberry Pi to the Bpod State Machine using a Bpod Raspberry Pi Shim.
On Raspberry Pi, you must configure a few things to make this work:
1. Open a terminal and run sudo raspi-config
2. Select 'Interfacing Options' > 'Serial'
3. Set the 'Login Shell' to <No>
4. Set the 'Serial Port Hardware Enabled' to <Yes>
5. Select <Finish> to exit the config application
Next, run this Python script. It will run indefinitely, waiting for bytes to arrive.
"""

import serial
import struct
firmwareVersion = 1
moduleName = "EchoModule"
ser = serial.Serial("/dev/ttyS0", 1312500)

while 1:
    bytesAvailable = ser.in_waiting;
    if bytesAvailable > 0:
        inByte = ser.read()
        unpackedByte = struct.unpack('B', inByte)
        if unpackedByte[0] != 255:
            ser.write(inByte)
        else:
            # This code returns a self-description to the state machine.
            Msg = struct.pack('B', 65) # Acknowledgement
            Msg += struct.pack('I', firmwareVersion) # Firmware version as 32-bit unsigned int
            Msg += struct.pack('B', 10) # Length of module name
            Msg += struct.pack(str(len(moduleName)) + 's', moduleName.encode('utf-8')) # Module name
            Msg += struct.pack('B', 0) # 0 to indicate no more self description to follow
            ser.write(Msg)
        ser.flush()