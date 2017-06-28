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
// This code is a "hello world" example of an analog closed loop, running in parallel with the Bpod state machine.
// Here, Samples from the analog input module become available at a regular interval, and are read in from the input stream serial port.
// For this simple example, the incoming 12-bit samples are mapped to 16-bits, and written to the output module's channels without further 
// filtering or feature extraction. 

// You can configure the sampling rate from the AnalogLoop_InputModule sketch, or by addressing the input module with a USB serial port.
// The maximum sampling rate will depend on: 
// 1. The efficiency of any signal processing code added to this sketch and to the input module sketch
// 2. The number of channels currently streaming (configurable from the analog input module sketch, changes auto-propagate to this code)
// 3. The signal cable connecting the analog input module to the analog output module (shorter is better, shielded is better, CAT5 < CAT5e < CAT6).
// 4. The baud rate of the Serial2 interface for the two devices (or Serial1 if using Arduino M0's ADC). 
// Using the ~empty processing loop below, streaming 8 channels at 30kHz is possible, using a 1-meter CAT5e cable, with serial interfaces @ at 7.3728Mb/s

// Incoming serial messages can be received from 3 serial interfaces (USB, state machine and Ain module) - 
// samples are sent to the output module by sending byte 'R' (for read) followed by Nchannels*2 bytes (2 bytes per sample x N channels).
// Also see comments in the analog input module closed loop example sketch.
// Josh Sanders, May 2017

#include "ArCOM.h"
#include "AD5754R.h"
#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256

// Module setup
#define FirmwareVersion 1
#define OutputModuleType 2 // 1 = 4-channel analog output module, 2 = 8-channel analog output module
char moduleName[] = "AnlgLoopOut"; // Name of module for manual override UI and state machine assembler
const byte nOutputChannels = 8; // Number of physical analog output channels (used to reserve memory, 8 will work for 4-channel module)
byte nActiveChannels = 4; // Number of channels currently active (being mapped from input stream)

// Pin definitions
#if OutputModuleType == 1
  AD5754R DAC(14, 39, 32); // Creates an object called DAC representing the AD5754R DAC IC. Arguments = Sync pin, LDAC pin, RefEnable pin
#endif
#if OutputModuleType == 2
  AD5754R DAC(34, 32, 31); // Creates an object called DAC representing the AD5754R DAC IC. Arguments = Sync pin, LDAC pin, RefEnable pin
  AD5754R DAC2(14, 39, 33); // The 8-channel analog output module has a second AD5754R IC, so it needs a separate object.
#endif
// Communication variables
byte opCode = 0; // Serial inputs access an op menu. The op code byte stores the intended operation.
byte opSource = 0; // 0 = op from USB, 1 = op from UART1 (Bpod state machine), 2 = op from UART2 (analog input module). 
byte inByte = 0; // Byte for temporary storage
boolean newOpCode = 0; // true if an opCode was read from one of the serial ports

union {
    byte byteArray[nOutputChannels*2];
    uint16_t uint16[nOutputChannels];
} adcValues; // 16-Bit code of current sample received from ADC input channels. A union type allows instant conversion between bytes and 16-bit ints

unsigned short DACBits_ZeroVolts = 32768; // Code (in bits) for 0V. For bipolar ranges, this should be 32768. For unipolar, 0.

// Wrap 3 serial interfaces
ArCOM USBCOM(Serial); // Creates an ArCOM object called USBCOM, wrapping Serial (the USB connection for Teensy 3.6)
ArCOM StateMachineCOM(Serial3); // Creates an ArCOM object called StateMachineCOM, wrapping Serial3 (physical channel 3 is module channel 1)
ArCOM InputModuleCOM(Serial2); 

void setup() {
  Serial2.begin(7372800); // Select the highest value your CAT5e/CAT6 cable supports without dropped bytes: 1312500, 2457600, 3686400, 7372800
  Serial3.begin(1312500);
  DAC.setRange(3); // rangeIndex 0 = '0V:5V', 1 = '0V:10V', 2 = '0V:12V', 3 = '-5V:5V', 4 = '-10V:10V', 5 = '-12V:12V'
}

void loop() {
  if (StateMachineCOM.available() > 0) {
    opCode = StateMachineCOM.readByte(); // Read in an op code
    opSource = 1; // message from UART 1 (Bpod state machine)
    newOpCode = true;
  } else if (InputModuleCOM.available() > 0) {
    opCode = InputModuleCOM.readByte();
    opSource = 2; // message from UART 2 (Analog input module)
    newOpCode = true;
  } else if (USBCOM.available() > 0) {
    opCode = USBCOM.readByte();
    opSource = 0; // message from USB / MATLAB / Python
    newOpCode = true;
  }
  if (newOpCode) { // If an op byte arrived from one of the serial interfaces
    newOpCode = false;
    switch(opCode) {
      case 255: // Return Bpod module info
        if (opSource == 1) { // Only returns this info if requested from state machine device
          returnModuleInfo();
        }
      break;
      case 'N': // Set number of channels
        if (opSource == 2) { // Only returns this info if requested from state machine device
          inByte = InputModuleCOM.readByte();
          if ((inByte > 0) && (inByte <= nOutputChannels)) {
            nActiveChannels = inByte;
          }
        }
      break;
      case 'R': // Read and process new ADC samples
        // Read new samples from serial source (i.e. analog input module, USB, etc)
        if (opSource == 2) {
          InputModuleCOM.readUint16Array(adcValues.uint16, nActiveChannels);
          
          for (int i = 0; i < nActiveChannels; i++) {
            adcValues.uint16[i] = adcValues.uint16[i] << 3; // Map incoming 13-bit samples to 16-bit output range
          }
          // Run a filter on samples (+ history if you recorded it) to extract behavior events
          
          // Return behavior events to Bpod state machine. Discrete events are sent as StateMachineCOM.writeByte(myEvent), where myEvent is an event byte code.
          
          // Map new ADC samples to DAC output voltages. For this "hello world" example, the bits are copied directly from the ADC to the DAC
          if (nActiveChannels < 5) {
            for (int i = 0; i < nActiveChannels; i++) {
              DAC.SetOutput(i, adcValues.uint16[i]); // Sets DAC output value, but voltage does not change until the next call to DAC.dacWrite()
            }
          } else {
            for (int i = 0; i < 4; i++) {
              DAC.SetOutput(i, adcValues.uint16[i]); // Sets DAC output value, but voltage does not change until the next call to DAC.dacWrite()
            }
            #if OutputModuleType == 2
              for (int i = 0; i < nActiveChannels-4; i++) {
                DAC2.SetOutput(i, adcValues.uint16[i+4]); // Sets DAC output value, but voltage does not change until the next call to DAC.dacWrite()
              }
              DAC2.dacWrite();
            #endif
          }
          DAC.dacWrite(); // Update DAC with new values
        }
      break;
    }
  }
}

void returnModuleInfo() {
  StateMachineCOM.writeByte(65); // Acknowledge
  StateMachineCOM.writeUint32(FirmwareVersion); // 4-byte firmware version
  StateMachineCOM.writeByte(sizeof(moduleName)-1); // Length of module name
  StateMachineCOM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  StateMachineCOM.writeByte(0); // 1 if more info follows, 0 if not
}
