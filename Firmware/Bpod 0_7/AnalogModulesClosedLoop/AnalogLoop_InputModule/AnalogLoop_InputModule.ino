/*
  ----------------------------------------------------------------------------

  This file is part of the Sanworks Bpod repository
  Copyright (C) 2017 Sanworks LLC, Sound Beach, New York, USA

  ----------------------------------------------------------------------------

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, version 3.

  This program is distributed  WITHOUT ANY WARRANTY and without even the
  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/
// Derived from Analog Module firmware v4.0.0
// Federico Carnevale, Joshua Sanders, May 2017

// ** DEPENDENCIES YOU NEED TO INSTALL FIRST **

// This firmware uses the sdFat library, developed by Bill Greiman. (Thanks Bill!!)
// Download it from here: https://github.com/greiman/SdFat
// and copy it to your /Arduino/Libraries folder.

// This code is a "hello world" example of an analog closed loop, running in parallel with the Bpod state machine.
// Here, Samples measured from the analog input module are sent to the analog output module a regular interval.

// You can configure the sampling rate from this sketch, or by addressing the input module with a USB serial port.
// The maximum sampling rate will depend on: 
// 1. The efficiency of any signal processing code added to this sketch and to the output module sketch
// 2. The number of channels currently streaming (when changed from the serial port, nChannels auto-propagates to the analog output module)
// 3. The signal cable connecting the analog input module to the analog output module (shorter is better, shielded is better, CAT5 < CAT5e < CAT6).
// 4. The baud rate of the Serial2 interface for the two devices (or Serial1 if using Arduino M0's ADC). 
// Using the ~empty processing loop below, streaming 8 channels at 30kHz is possible, using a 1-meter CAT5e cable, with serial interfaces @ at 7.3728Mb/s

// Incoming serial messages can be received from 3 serial interfaces (USB, state machine and Ain module) - 
// samples are sent to the output module by sending byte 'R' (for read) followed by Nchannels*2 bytes (2 bytes per sample x N channels).
// Also see comments in the analog output module closed loop example sketch.

#include "ArCOM.h"
#include "AD7327.h"
#include <SPI.h>

// Params
byte nChannelsToStream = 4; // The number of channels sampled and sent to the analog output module. This can be changed from the USB serial
// interface. IF it is changed by USB, the correct number of channels to expect will automatically propagate to the analog output module.
uint32_t samplingRate = 1000; // in Hz

AD7327 AD(39); // Create an object called AD, representing the AD7327 analog to digital converter IC
byte DebugPin = 18; // One of the pins available from the side of the device. It is set high, and can supply (noisy) 3.3V to a potentiometer.
// It can also be used to measure sample cycles by adding digitalWrite() commands below.

ArCOM USBCOM(SerialUSB); // Creates an ArCOM object called USBCOM, wrapping SerialUSB
ArCOM StateMachineCOM(Serial3); // Creates an ArCOM object called StateMachineCOM
ArCOM OutputStreamCOM(Serial2);

// System objects
IntervalTimer hardwareTimer; // Hardware timer peripheral to ensure even sampling (when its callback is not overloaded)
byte opCode = 0; // Stores a byte read from one of the serial interfaces
byte opSource = 0; // Reports the source of a new message - USB (0), State machine (1) or Analog Output Module (2)
boolean newOpCode = false; // True if a new message arrived from one of the serial interfaces
boolean isStreaming = true; // True if currently streaming to the analog output module
byte outputBuffer[17] = {'R', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ,0 ,0 ,0, 0}; // Reserved memory for outgoing data. The analog output module
// expects 'R' followed by a 16-bit sample for each active channel (2 bytes each). The buffer is written in 1 operation, with syntax Serial.write(buffer, nBytes)

void setup() {
  pinMode(DebugPin, OUTPUT); // Pin 18 (on side of device) is set high, to use as a power source for a potentiometer
  digitalWrite(DebugPin, HIGH);
  Serial2.begin(7372800); // Select the highest value your CAT5e or CAT6 cable supports: 1312500, 2457600, 3686400, 7372800
  Serial3.begin(1312500); // Bpod state machine connection, standard baud rate = 1312500
  SPI.begin();
  for (int i = 0; i < nChannelsToStream; i++) {
    AD.setRange(i, 2); // Set channel i to range 2
  }
  AD.setNchannels(nChannelsToStream); // setNchannels(N) = Set the system to update only channels 1-N
  hardwareTimer.begin(handler, (1/(double)samplingRate)*1000000); // hardwareTimer is an interval timer object - Teensy 3.6's hardware timer
}


void loop() {
  
}

void handler(void) { // This is called once each period of the hardwareTimer (declared above). 
                     //Each call to handler() measures and transmits one sample from each active channel
  
  AD.readADC(); // Update the active ADC channels
  
  // Read any incoming bytes from USB, state machine and input stream serial interfaces
  if (StateMachineCOM.available() > 0) { // If bytes are available from the state machine
    opCode = StateMachineCOM.readByte(); // Read in an op code from the state machine
    opSource = 1; // 1 = State Machine
    newOpCode = true;
  } else if (OutputStreamCOM.available() > 0) {
    opCode = OutputStreamCOM.readByte();
    opSource = 2; // 2 = output stream
    newOpCode = true;
  } else if (USBCOM.available() > 0) {
    opCode = USBCOM.readByte();
    opSource = 0; // 3 = USB
    newOpCode = true;
  }
  
  // Handle any incoming bytes
  if (newOpCode) { // If an op byte arrived from one of the serial interfaces
    newOpCode = false;
    switch (opCode) {
      case 'N': // Set number of channels to stream (also configures analog output module to expect same number)
        if (opSource == 0) { // If the command came from the USB interface
          nChannelsToStream = USBCOM.readByte(); // Update the number of channels to stream
          OutputStreamCOM.writeByte('N'); // Tell the analog output module how many samples to expect from now onwards
          OutputStreamCOM.writeByte(nChannelsToStream);
        }
      break;
      case 'F': // Set sampling frequency
        if (opSource == 0) {
          samplingRate = USBCOM.readUint32();
          hardwareTimer.end(); // Stop the hardware timer
          hardwareTimer.begin(handler, (1/(double)samplingRate)*1000000); // Re-start the hardware timer at the new sampling rate
        }
      break;
    }// end switch(opCode)
  }// end newOpCode

  // Stream
  if (isStreaming) { // If streaming is enabled
    for (int i = 0; i < nChannelsToStream*2; i+=2) { // Copy the latest sample on each channel to the output buffer
      outputBuffer[i+1] = AD.analogData.uint8[i]; 
      outputBuffer[i+2] = AD.analogData.uint8[i+1];
    }
    OutputStreamCOM.writeByteArray(outputBuffer, (nChannelsToStream*2)+1); // Write the samples to the output module
  }
} // End main timer loop


