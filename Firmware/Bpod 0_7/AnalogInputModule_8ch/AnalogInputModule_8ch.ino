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
// Analog Module firmware v4.0.0
// Federico Carnevale, October 2016
// Revised by Josh Sanders, May 2017

// ** DEPENDENCIES YOU NEED TO INSTALL FIRST **

// This firmware uses the sdFat library, developed by Bill Greiman. (Thanks Bill!!)
// Download it from here: https://github.com/greiman/SdFat
// and copy it to your /Arduino/Libraries folder.

// ALSO Requires modifications to Teensy core files:
// In the folder /arduino-1.8.X/hardware/teensy/avr/cores/teensy3, modify the following line in each of the 5 files listed below:
// #define SERIAL1_RX_BUFFER_SIZE 64  --> #define SERIAL1_RX_BUFFER_SIZE 256
// IN FILES: serial1.c, serial2.c, serial3.c

#include "ArCOM.h" // A wrapper for Arduino serial interfaces. See https://sites.google.com/site/sanworksdocs/arcom
#include "AD7327.h" // Library for the AD7327 Analog to digital converter IC
#include <SPI.h>
#include <SdFat.h> // Library for microSD
SdFatSdioEX SD;

#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256

// Module setup
unsigned long FirmwareVersion = 1;
char moduleName[] = "AnalogIn"; // Name of module for manual override UI and state machine assembler

AD7327 AD(39); // Create AD, an AD7327 ADC object.

ArCOM USBCOM(SerialUSB); // Creates an ArCOM object called USBCOM, wrapping SerialUSB. See https://sites.google.com/site/sanworksdocs/arcom
ArCOM StateMachineCOM(Serial3); // Creates an ArCOM object for the state machine
ArCOM OutputStreamCOM(Serial2); // Creates an ArCOM object for the output stream

// Digital i/o pins available from side of enclosure (not currently used; can be configured as an I2C interface)
byte DigitalPin1 = 18;
byte DigitalPin2 = 19;

// System objects
SPISettings ADCSettings(10000000, MSBFIRST, SPI_MODE2);
IntervalTimer hardwareTimer; // Hardware timer to ensure even sampling
File DataFile; // File on microSD card, to store waveform data

// Op menu variable
byte opCode = 0; // Serial inputs access an op menu. The op code byte stores the intended operation.
byte opSource = 0; // 0 = op from USB, 1 = op from UART1, 2 = op from UART2. More op code menu options are exposed for USB.
boolean newOpCode = 0; // this flag is true if an opCode was read from one of the ports
byte OpMenuByte = 213; // This byte must be the first byte in any USB serial transmission. Reduces the probability of interference from port-scanning software
byte inByte = 0; // General purpose temporary byte

// Channel counts
const byte nPhysicalChannels = 8; // Number of physical channels on device
byte nActiveChannels = 8; // Number of channels currently being read (consecutive, starting at ch1)

// State Flags
boolean StreamSignalToUSB = false; // Stream to USB
boolean StreamSignalToModule = false; // Send adc reads to output or DDS module through serial port
boolean LoggingDataToSD = false; // Logs active channels to SD card
boolean SendEventsToUSB = false; // Send threshold crossing events to USB
boolean SendEventsToStateMachine = false; // Send threshold crossing events to state machine

// State variables
byte streamChan2Module[nPhysicalChannels] = {0}; // List of channels streaming to module
byte streamChan2USB[nPhysicalChannels] = {0}; // List of channels streaming to USB
byte voltageRanges[nPhysicalChannels] = {0}; // Voltage range indexes of channels
uint32_t samplingRate = 1000; // in Hz 
double timerPeriod = 0;

// Voltage threshold-crossing detection variables
byte eventChannels[nPhysicalChannels] = {0}; // Indicates channels that generate events when events are turned on globally
boolean eventEnabled[nPhysicalChannels] = {1}; // Events are disabled after a threshold crossing, until the value crosses resetValue
uint16_t thresholdValue[nPhysicalChannels] = {8192}; // Voltage (in bits) of threshold. Default = max range (13-bits)
uint16_t resetValue[nPhysicalChannels] = {0}; // Voltage (in bits) of reset event
boolean thresholdDirection[nPhysicalChannels] = {0}; // Indicates whether resetValue is less than (0) or greater than (1) thresholdValue
                                                     // This also determines whether a voltage greater than (0) or less than (1) threshold
                                                     // will trigger an event.
boolean thresholdEventDetected[nPhysicalChannels] = {0};

// SD variables
uint32_t nFullBufferReads = 0; // Number of full buffer reads in transmission
uint32_t nRemainderBytes = 0; // Number of bytes remaining after full transmissions
const uint32_t sdReadBufferSize = 2048; // in bytes
uint8_t sdReadBuffer[sdReadBufferSize] = {0};
const uint32_t sdWriteBufferSize = 2048; // in bytes
uint16_t sdWriteBuffer[nPhysicalChannels*sdWriteBufferSize*2] = {0}; // These two buffers store data to be written to microSD. 
                                                                     // One is dumped to microSD in the main loop,
                                                                     // while the other is filled in the timer callback.
uint16_t sdWriteBuffer2[nPhysicalChannels*sdWriteBufferSize*2] = {0};
uint32_t writeBufferPos = 0;
uint32_t writeBuffer2Pos = 0;
byte currentBuffer = 0; // Current buffer being written to microSD


// Other variables
uint32_t nSamplesAcquired = 0; // Number of samples acquired since logging started
uint32_t maxSamplesToAcquire = 0; // maximum number of samples to acquire on startLogging command. 0 = infinite
boolean writeFlag = false; // True if a write buffer contains samples to be written to SD

// Error messages stored in flash.
#define error(msg) sd.errorHalt(F(msg))

void setup() {
  pinMode(DigitalPin1, OUTPUT);
  digitalWrite(DigitalPin1, HIGH); // This allows a potentiometer to be powered from the board, for coarse diagnostics
  Serial2.begin(7372800); // Select the highest value your CAT5e/CAT6 cable supports without dropped bytes: 1312500, 2457600, 3686400, 7372800
  Serial3.begin(1312500);
  SPI.begin();
  SD.begin(); // Initialize microSD card
  SD.remove("Data.wfm");
  DataFile = SD.open("Data.wfm", FILE_WRITE);
  timerPeriod = (1/(double)samplingRate)*1000000;
  hardwareTimer.begin(handler, timerPeriod); // hardwareTimer is an interval timer object - Teensy 3.6's hardware timer
}


void loop() {
  if (writeFlag) { // If data is available to be written to microSD
    if (currentBuffer == 0) { // If the data was loaded into buffer 0
      currentBuffer = 1; // Make the current buffer = 1
      DataFile.write(sdWriteBuffer, writeBufferPos*2); // Write to microSD
      writeBufferPos = 0; // Reset buffer write position
    } else {
      currentBuffer = 0;
      DataFile.write(sdWriteBuffer2, writeBuffer2Pos*2);
      writeBuffer2Pos = 0;
    }
    writeFlag = false;
  }
}

void handler(void) {
  if (StateMachineCOM.available() > 0) { // If bytes arrived from the state machine
    opCode = StateMachineCOM.readByte(); // Read in an op code
    opSource = 1; // 0 = USB, 1 = State machine, 2 = output stream (DDS, Analog output module, etc)
    newOpCode = true;
  } else if (OutputStreamCOM.available() > 0) {
    opCode = OutputStreamCOM.readByte();
    opSource = 2; // UART 2
    newOpCode = true;
  } else if (USBCOM.available() > 0) {
    if (USBCOM.readByte() == OpMenuByte) { // This extra menu access byte avoids most issues with auto-polling software (some versions of Ubuntu)
      opCode = USBCOM.readByte();
      opSource = 0; // USB
    };
    newOpCode = true;
  }

  if (newOpCode) { // If an op byte arrived from one of the serial interfaces
    newOpCode = false;
    switch (opCode) {
      case 'O': // USB initiated new connection; reset all state variables
        if (opSource == 0) {
          USBCOM.writeByte(161); // Send acknowledgement byte
          USBCOM.writeUint32(FirmwareVersion); // Send firmware version
          StreamSignalToUSB = false;
          SendEventsToUSB = false;
          LoggingDataToSD = false;
          SendEventsToStateMachine = false;
          StreamSignalToModule = false;
          samplingRate = 1000;
          nActiveChannels = 8;
          AD.setNchannels(nActiveChannels);
          for (int i = 0; i > nPhysicalChannels; i++) {
            streamChan2Module[i] = 0;
            streamChan2USB[i] = 0;
            voltageRanges[i] = 0;
            AD.setRange(i, 0);
            eventChannels[i] = 0;
            eventEnabled[i] = 0;
            thresholdValue[i] = 0;
            thresholdDirection[i] = 0;
            resetValue[i] = 0;
            thresholdDirection[i] = 0;
            thresholdEventDetected[i] = 0;
          }
          hardwareTimer.end();
          timerPeriod = (1/(double)samplingRate)*1000000;
          hardwareTimer.begin(handler, timerPeriod);
        }
      break;

      case 255: // Return Bpod module info
        if (opSource == 1) { // Only returns this info if requested from state machine device
          returnModuleInfo();
        } 
      break;

      case 'S': // Start/Stop data streaming
        inByte = readByteFromSource(opSource);
        switch (inByte) {
          case 0:
            StreamSignalToUSB = (boolean)readByteFromSource(opSource);
          break;
          case 1:
            StreamSignalToModule = (boolean)readByteFromSource(opSource);
            if (StreamSignalToModule) { // Send number of streaming channels to expect
              inByte = 0;
              for (int i = 0; i < nActiveChannels; i++) {
                inByte += streamChan2Module[i];
              }
              OutputStreamCOM.writeByte('N');
              OutputStreamCOM.writeByte(inByte);
            }
          break;
        }
      break;

      case 'E': // Start/Stop threshold event detection + transmission
        inByte = readByteFromSource(opSource);
        switch (inByte) {
          case 0:
            SendEventsToUSB = (boolean)readByteFromSource(opSource);
          break;
          case 1:
            SendEventsToStateMachine = (boolean)readByteFromSource(opSource);
          break;
        }
        for (int i = 0; i < nPhysicalChannels; i++) {
          eventEnabled[i] = true; // All channels start out enabled until first threshold crossing (though only eventChannels are evaluated)
        }
        if (opSource == 0) {
          USBCOM.writeByte(1); // Send confirm byte
        }
      break;

      case 'L': // Start/Stop logging data from active channels to microSD card
        inByte = readByteFromSource(opSource);
        switch (inByte) {
          case 0: // Stop logging
            stopLogging();
          break;
          case 1: // Start logging
            DataFile.seek(0);
            LoggingDataToSD = true;
            nSamplesAcquired = 0;
            writeBufferPos = 0;
            writeBuffer2Pos = 0;
            currentBuffer = 0;
          break;
        }
        if (opSource == 0) {
          USBCOM.writeByte(1); // Send confirm byte
        }
      break;

      case 'C': // Set subset of channels to stream raw data (USB and module)
        if (opSource == 0) {
          USBCOM.readByteArray(streamChan2USB, nPhysicalChannels);
          USBCOM.readByteArray(streamChan2Module, nPhysicalChannels);
          USBCOM.writeByte(1); // Send confirm byte
        }
      break;

      case 'R': // Select ADC Voltage range for each channel
          if (opSource == 0) {
            if (!LoggingDataToSD){
              USBCOM.readByteArray(voltageRanges, nPhysicalChannels);
              for (int i = 0; i < nPhysicalChannels; i++) {
                AD.setRange(i, voltageRanges[i]);
              }
              USBCOM.writeByte(1); // Send confirm byte
            } else {
              for (int i = 0; i < nPhysicalChannels; i++) { // Clear input buffer (more elegantly in future ArCOM versions)
                USBCOM.readByte();
              }
              USBCOM.writeByte(0); // Send error byte
            }
          }
      break;

      case 'A': // Set max number of actively sampled channels
        if (opSource == 0) {
          if (!LoggingDataToSD) {
            nActiveChannels = USBCOM.readByte();
            AD.setNchannels(nActiveChannels);
            USBCOM.writeByte(1); // Send confirm byte
          } else {
            USBCOM.readByte();
            USBCOM.writeByte(0); // Send error byte
          }
        }
      break;

      case 'T': // Set thresholds and reset values
        if (opSource == 0) {
          for (int i = 0; i < nPhysicalChannels; i++) { // Read in threshold values (in bits)
            thresholdValue[i] = USBCOM.readUint16();
          }
          for (int i = 0; i < nPhysicalChannels; i++) { // Read in reset values (in bits)
            resetValue[i] = USBCOM.readUint16();
          }
          for (int i = 0; i < nPhysicalChannels; i++) { // Set sign of reset value with respect to threshold
            if (resetValue[i] < thresholdValue[i]) {
              thresholdDirection[i] = 0;
            } else {
              thresholdDirection[i] = 1;
            }
          }
          USBCOM.writeByte(1); // Send confirm byte
        }
      break;
      
      case 'K': // Set channels that generate events
        if (opSource == 0) {
          USBCOM.readByteArray(eventChannels, nPhysicalChannels);
          USBCOM.writeByte(1); // Send confirm byte
        }
      break;

      case 'D': // Read SD card and send data to USB
        if (opSource == 0) {
            LoggingDataToSD = false;
            while (writeFlag) {};
            DataFile.seek(0);
            if (nSamplesAcquired*2 > sdReadBufferSize) {
              nFullBufferReads = (unsigned long)(floor(((double)nSamplesAcquired)*double(nActiveChannels)*2 / (double)sdReadBufferSize));
            } else {
              nFullBufferReads = 0;
            }
            USBCOM.writeUint32(nSamplesAcquired);     
            for (int i = 0; i < nFullBufferReads; i++) { // Full buffer transfers; skipped if nFullBufferReads = 0
              DataFile.read(sdReadBuffer, sdReadBufferSize);
              USBCOM.writeByteArray(sdReadBuffer, sdReadBufferSize);
            }
            nRemainderBytes = (nSamplesAcquired*nActiveChannels*2)-(nFullBufferReads*sdReadBufferSize);
            if (nRemainderBytes > 0) {
              DataFile.read(sdReadBuffer, nRemainderBytes);
              USBCOM.writeByteArray(sdReadBuffer, nRemainderBytes);     
            }
          }
      break;

      case 'F': // Change sampling frequency
          if (opSource == 0) {
            if (!LoggingDataToSD) {
              samplingRate = USBCOM.readUint32();
              hardwareTimer.end();
              timerPeriod = (1/(double)samplingRate)*1000000;
              hardwareTimer.begin(handler, timerPeriod);
              USBCOM.writeByte(1); // Confirm byte
            } else {
              USBCOM.readUint32();
              USBCOM.writeByte(0); // Error byte
            }
          }
      break;

      case 'W': // Set maximum number of samples to acquire on command to log data
        if (opSource == 0) {
          if (!LoggingDataToSD) {
            maxSamplesToAcquire = USBCOM.readUint32();
            USBCOM.writeByte(1);
          } else {
            USBCOM.readUint32();
            USBCOM.writeByte(0); // Error byte
          }
        }
      break;
    }// end switch(opCode)
  }// end newOpCode

  AD.readADC(); // Reads all active channels and stores the result in a buffer in the AD object: AD.analogData[]

  for (int i = 0; i < nActiveChannels; i++) { // Detect threshold crossings and send to targets
    if (eventChannels[i]) { // If event reporting is enabled for this channel
      thresholdEventDetected[i] = false;
      if (eventEnabled[i]) { // Check for threshold crossing
        if (thresholdDirection[i] == 0) { // If crossing is from low to high voltage
          if (AD.analogData.uint16[i] >= thresholdValue[i]) {
            thresholdEventDetected[i] = true;
          }
        } else { // If crossing is from high to low voltage
          if (AD.analogData.uint16[i] <= thresholdValue[i]) {
            thresholdEventDetected[i] = true;
          }
        }
        if (thresholdEventDetected[i]) {
          if (SendEventsToUSB) {
            USBCOM.writeByte(i+1); // Convert to event code (event codes are indexed by 1)
          }
          if (SendEventsToStateMachine) {
            StateMachineCOM.writeByte(i+1); // Convert to event code (indexed by 1)
          }
          eventEnabled[i] = false;
        }
      } else { // Check for re-enable
        if (thresholdDirection[i] == 0) {
          if (AD.analogData.uint16[i] <=  resetValue[i]) {
            eventEnabled[i] = true;
          }
        } else {
          if (AD.analogData.uint16[i] >=  resetValue[i]) {
            eventEnabled[i] = true;
          }
        }
      }
    }
  }
  
  if (LoggingDataToSD) {
    LogData();
  }
    
  if (StreamSignalToUSB) { // Stream data to USB
    USBCOM.writeByte('R');
    for (int i = 0; i < nActiveChannels; i++) {
      if (streamChan2USB[i]) {
        USBCOM.writeUint16(AD.analogData.uint16[i]);
      }
    }
    USBCOM.flush();
  }
  if (StreamSignalToModule) {
    OutputStreamCOM.writeByte('R');
    for (int i = 0; i < nActiveChannels; i++) {
      if (streamChan2Module[i]) {
        OutputStreamCOM.writeUint16(AD.analogData.uint16[i]);
      }
    }
  }
} // End main timer loop

// Log data
void LogData() {
  if (currentBuffer == 0) {
    for (int i = 0; i < nActiveChannels; i++) {
      sdWriteBuffer[writeBufferPos] = AD.analogData.uint16[i]; writeBufferPos++;
    }
  } else {
    for (int i = 0; i < nActiveChannels; i++) {
      sdWriteBuffer2[writeBuffer2Pos] = AD.analogData.uint16[i]; writeBuffer2Pos++;
    }
  }
  writeFlag = true;
  nSamplesAcquired++;
  if (nSamplesAcquired == maxSamplesToAcquire) {
    stopLogging();
  }
}

void stopLogging() {
  LoggingDataToSD = false;
}

byte readByteFromSource(byte opSource) {
  switch (opSource) {
    case 0:
      return USBCOM.readByte();
    break;
    case 1:
      return StateMachineCOM.readByte();
    break;
    case 2:
      return OutputStreamCOM.readByte();
    break;
  }
}

void returnModuleInfo() {
  StateMachineCOM.writeByte(65); // Acknowledge
  StateMachineCOM.writeUint32(FirmwareVersion); // 4-byte firmware version
  StateMachineCOM.writeByte(sizeof(moduleName) - 1); // Length of module name
  StateMachineCOM.writeCharArray(moduleName, sizeof(moduleName) - 1); // Module name
  StateMachineCOM.writeByte(0);
}

