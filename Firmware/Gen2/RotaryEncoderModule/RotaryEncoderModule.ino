/*
  ----------------------------------------------------------------------------

  This file is part of the Sanworks Bpod_Gen2 repository
  Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

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

// The rotary encoder module, powered by Teensy 3.5, interfaces Bpod with a 1024-position rotary encoder: Yumo E6B2-CWZ3E
// The serial interface allows the user to set position thresholds, which generate Bpod events when crossed.
// The MATLAB interface can then retrieve the last trial's position log, and set new thresholds.
// MATLAB can also stream the current position to a plot, for diagnostics.

#include "ArCOM.h"
#include <SPI.h>
#include "SdFat.h"
SdFatSdioEX SD;
#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256
ArCOM myUSB(SerialUSB); // USB is an ArCOM object. ArCOM wraps Arduino's SerialUSB interface, to
ArCOM StateMachineCOM(Serial3); // UART serial port
ArCOM OutputStreamCOM(Serial2); // UART serial port
// simplify moving data types between Arduino and MATLAB/GNU Octave.
File DataFile; // File on microSD card, to store position data

// Module setup
unsigned long FirmwareVersion = 1;
char moduleName[] = "RotaryEncoder"; // Name of module for manual override UI and state machine assembler
//char* eventNames[] = {"L", "R"}; // Left and right threshold crossings (with respect to position at trial start).
//byte nEventNames = (sizeof(eventNames)/sizeof(char *));

// Output stream setup
char moduleStreamPrefix = 'M'; // Command character to send before each position value when streaming data via output stream jack
byte outputStreamDatatype = 'H'; // Integer type to use when streaming position value. 'H' = 16-bit unsigned int, 'L' = 32-bit unsigned int

// Hardware setup
const byte EncoderPinA = 35;
const byte EncoderPinB = 36;
const byte EncoderPinZ = 37;

// Parameters
const byte maxThresholds = 2;
int16_t thresholds[maxThresholds] = {0}; // Initialized by client. Position range = -512 : 512 encoder tics, corresponding to -180 : +180 degrees
boolean thresholdActive[maxThresholds] = {true}; // Thresholds are inactivated on crossing, until manually reset
byte nThresholds = maxThresholds; // Number of thresholds currently used
int16_t wrapPoint = 512; // Position used to wrap position. At 512, if position > 512 or < -512, position wraps to -512 and 512 respectively.
int nWraps = 0; // number of times (positive or negative) that the wheel position has wrapped since last reset

// State variables
boolean usbStreaming = false; // If currently streaming position and time data to the output-stream port
boolean sendEvents = true; // True if sending threshold crossing events to state machine
boolean isLogging = false; // If currently logging position and time to microSD memory
boolean inTrial = false; // If currently in a trial
boolean moduleStreaming = false; // If streaming position to a separate module via the output stream jack (preconfigured output for DDS module)
int16_t EncoderPos = 0; // Current position of the rotary encoder

// Program variables
byte opCode = 0;
byte opSource = 0;
byte param = 0;
boolean newOp = false;
boolean loggedDataAvailable = 0;
boolean wrappingEnabled = true;
byte terminatingEvent = 0;
boolean EncoderPinAValue = 0;
boolean EncoderPinALastValue = 0;
boolean EncoderPinBValue = 0;
word EncoderPos16Bit =  0;
unsigned long choiceTime = 0;
unsigned long dataPos = 0;
unsigned long dataMax = 4294967295; // Maximim number of positions that can be logged (limited by 32-bit counter)
unsigned long startTime = 0;
unsigned long currentTime = 0;
unsigned long timeFromStart = 0;
int16_t wrapPointInverse = 0;
union {
    byte uint8[4];
    uint16_t uint16;
    uint32_t uint32;
} typeBuffer;

// microSD variables
unsigned long nRemainderBytes = 0;
unsigned long nFullBufferReads = 0;
union {
    byte uint8[800];
    uint32_t int32[200];
} sdWriteBuffer;
const uint32_t sdReadBufferSize = 2048; // in bytes
uint8_t sdReadBuffer[sdReadBufferSize] = {0};

// Interrupt and position buffers
const uint32_t positionBufferSize = 1024;
int16_t positionBuffer[positionBufferSize] = {0};
int32_t timeBuffer[positionBufferSize] = {0};
uint32_t iPositionBuffer = 0;
boolean positionBufferFlag = false;

void setup() {
  // put your setup code here, to run once:
  SerialUSB.begin(115200);
  Serial3.begin(1312500);
  Serial2.begin(1312500);
  pinMode(EncoderPinA, INPUT);
  pinMode (EncoderPinB, INPUT);
  pinMode(13, OUTPUT);
  digitalWrite(13, HIGH);
  SPI.begin();
  SD.begin(); // Initialize microSD card
  SD.remove("Data.wfm");
  DataFile = SD.open("Data.wfm", FILE_WRITE);
  wrapPointInverse = wrapPoint * -1;
  attachInterrupt(EncoderPinA, readNewPosition, RISING);
}

void loop() {
  currentTime = millis();
  if (myUSB.available() > 0) {
    opCode = myUSB.readByte();
    newOp = true;
    opSource = 0;
  } else if (StateMachineCOM.available() > 0) {
    opCode = StateMachineCOM.readByte();
    newOp = true;
    opSource= 1;
  } else if (OutputStreamCOM.available() > 0) {
    opCode = OutputStreamCOM.readByte();
    newOp = true;
    opSource = 2;
  }
  if (newOp) {
    newOp = false;
    switch(opCode) {
      case 255: // Return module name and info
        if (opSource == 1) { // If requested by state machine
          returnModuleInfo();
        }
      break;
      case 'C': // USB Handshake
        if (opSource == 0) {
          myUSB.writeByte(217);
        }
      break;
      case 'S': // Start/Stop USB position+time data stream
        if (opSource == 0) {
          usbStreaming = myUSB.readByte();
          if (usbStreaming) {
            EncoderPos = 0; // Reset position
            nWraps = 0; // Reset wrap counter
            startTime = currentTime;
          }
        }
      break;
      case 'O': // Start/Stop module position data stream
        moduleStreaming = readByteFromSource(opSource);
        if (opSource == 0) {
          myUSB.writeByte(1); // Confirm
        }
      break;
      case 'V': // Set event transmission to state machine (on/off)
      if (opSource == 0) {
        sendEvents = myUSB.readByte();
        myUSB.writeByte(1);
      }
      break;
      case 'W': // Set wrap point (in tics)
      if (opSource == 0) {
        wrapPoint = myUSB.readInt16();
        myUSB.writeByte(1);
        if (wrapPoint != 0) {
          wrappingEnabled = true;
        } else {
          wrappingEnabled = false;
        }
        wrapPointInverse = wrapPoint * -1;
        nWraps = 0;
      }
      break;
      case 'T': // Program thresholds
        if (opSource == 0) {
          param = myUSB.readByte(); // Read number of thresholds to program
          if (param <= maxThresholds) {
            nThresholds = param;
            for (int i = 0; i < nThresholds; i++) {
              thresholds[i] = myUSB.readInt16();
            }
            myUSB.writeByte(1);
          } else {
            myUSB.writeByte(0);
          }
        }
      break;
      case 'I': // Set 1-character prefix preceding each position data point streamed to a receiving Bpod module
        if (opSource == 0) {
          moduleStreamPrefix = myUSB.readByte();
          myUSB.writeByte(1);
        }
      break;
      case ';': // Set enable/disable status of all thresholds
        param = readByteFromSource(opSource);
        for (int i = 0; i < nThresholds; i++) {
          thresholdActive[i] = bitRead(param, i);
        }
      break;
      case 'Z': // Zero position
          EncoderPos = 0;
          nWraps = 0;
      break;
      case 'E': // Enable all thresholds
        for (int i = 0; i < nThresholds; i++) {
          thresholdActive[i] = true;
        }
      break;
      case 'L': // Start microSD logging
        startLogging();
      break;
      case 'F': // finish microSD logging
        logCurrentPosition();
        isLogging = false;
        if (dataPos > 0) {
          loggedDataAvailable = true;
        }
      break;
      case 'R': // Return logged data
        if (opSource == 0) {
          //detachInterrupt(EncoderPinA); // Not necessary
          isLogging = false;
          if (loggedDataAvailable) {
            loggedDataAvailable = false;
            DataFile.seek(0);
            if (dataPos*8 > sdReadBufferSize) {
              nFullBufferReads = (unsigned long)(floor(((double)dataPos)*8 / (double)sdReadBufferSize));
            } else {
              nFullBufferReads = 0;
            }
            myUSB.writeUint32(dataPos);     
            for (int i = 0; i < nFullBufferReads; i++) { // Full buffer transfers; skipped if nFullBufferReads = 0
              DataFile.read(sdReadBuffer, sdReadBufferSize);
              
              myUSB.writeByteArray(sdReadBuffer, sdReadBufferSize);
            }
            nRemainderBytes = (dataPos*8)-(nFullBufferReads*sdReadBufferSize);
            if (nRemainderBytes > 0) {
              DataFile.read(sdReadBuffer, nRemainderBytes);
              myUSB.writeByteArray(sdReadBuffer, nRemainderBytes);     
            }              
            dataPos = 0;
          } else {
            myUSB.writeUint32(0);
          }
          //attachInterrupt(EncoderPinA, readNewPosition, RISING); // Not necessary
        }
      break;
      case 'Q': // Return current encoder position
        if (opSource == 0) {
          myUSB.writeInt16(EncoderPos);
        }
      break;
      case 'P': // Set current encoder position
        if (opSource == 0) {
          EncoderPos = myUSB.readInt16();
          nWraps = 0;
          myUSB.writeByte(1);
        }
      break;
      case 'X': // Reset all params
        usbStreaming = false;
        isLogging = false;
        inTrial = false;
        dataPos = 0;
        EncoderPos = 0;
        nWraps = 0;
        iPositionBuffer = 0;
      break;
    } // End switch(opCode)
  } // End if (SerialUSB.available())

  if(positionBufferFlag) { // If new data points have been added since last loop
    positionBufferFlag = false;
    if (usbStreaming) {
      for (int i = 0; i < iPositionBuffer; i++) {
        myUSB.writeInt16(positionBuffer[i]);
        myUSB.writeUint32(timeBuffer[i]);
      }
      myUSB.flush();
    }
    
    if (moduleStreaming) {
      for (int i = 0; i < iPositionBuffer; i++) {
        OutputStreamCOM.writeByte(moduleStreamPrefix);
        typeBuffer.uint32 = positionBuffer[i]+wrapPoint;
        switch(outputStreamDatatype) {
          case 'H':
            OutputStreamCOM.writeUint16(typeBuffer.uint16);
          break;
          case 'L':
            OutputStreamCOM.writeUint32(typeBuffer.uint32);
          break;
        }
      }
    }
    if (sendEvents) {
      if (nWraps == 0) { // Thresholds are only defined within +/- the range of the wrap point
        for (int i = 0; i < nThresholds; i++) {
          if (thresholdActive[i]) {
             if (thresholds[i] < 0) {
                for (int j = 0; j < iPositionBuffer; j++) {
                  if (positionBuffer[j] <= thresholds[i]) {
                    thresholdActive[i] = false;
                    StateMachineCOM.writeByte(i+1);
                  }
                }
             } else {
                for (int j = 0; j < iPositionBuffer; j++) {
                  if (positionBuffer[j] >= thresholds[i]) {
                    thresholdActive[i] = false;
                    StateMachineCOM.writeByte(i+1);
                  }
                }
             }
          }
        }
      }
    }

    if (isLogging) {
      if (dataPos<dataMax) {
        logCurrentPosition();
      }
    }
    iPositionBuffer = 0;
  }
}

void readNewPosition() {
  // If this function was called, we already know encoder pin A was just driven high
  EncoderPinBValue = digitalRead(EncoderPinB);
  timeFromStart = currentTime - startTime;
  if (EncoderPinBValue == HIGH) {
    EncoderPos++;
  } else {
    EncoderPos--;
  }
  if (wrappingEnabled) {
    if (EncoderPos < wrapPointInverse) {
      EncoderPos = wrapPoint; nWraps--;
    } else if (EncoderPos > wrapPoint) {
      EncoderPos = wrapPointInverse; nWraps++;
    }
  }
  positionBuffer[iPositionBuffer] = EncoderPos;
  timeBuffer[iPositionBuffer] = timeFromStart;
  iPositionBuffer++;
  positionBufferFlag = true;
}

void returnModuleInfo() {
  StateMachineCOM.writeByte(65); // Acknowledge
  StateMachineCOM.writeUint32(FirmwareVersion); // 4-byte firmware version
  StateMachineCOM.writeByte(sizeof(moduleName)-1); // Length of module name
  StateMachineCOM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  StateMachineCOM.writeByte(0); // 1 if more info follows, 0 if not
//  StateMachineCOM.writeByte('#'); // Op code for: Number of behavior events this module can generate
//  StateMachineCOM.writeByte(2); // 2 thresholds
//  StateMachineCOM.writeByte(1); // 1 if more info follows, 0 if not
//  StateMachineCOM.writeByte('E'); // Op code for: Behavior event names
//  StateMachineCOM.writeByte(nEventNames);
//  for (int i = 0; i < nEventNames; i++) { // Once for each event name
//    StateMachineCOM.writeByte(strlen(eventNames[i])); // Send event name length
//    for (int j = 0; j < strlen(eventNames[i]); j++) { // Once for each character in this event name
//      StateMachineCOM.writeByte(*(eventNames[i]+j)); // Send the character
//    }
//  }
//  StateMachineCOM.writeByte(0); // 1 if more info follows, 0 if not
}

void startLogging() {
  DataFile.seek(0);
  dataPos = 0;
  startTime = currentTime;
  isLogging = true;
  timeFromStart = 0;
  iPositionBuffer = 0;
}

void logCurrentPosition() {
  if (iPositionBuffer > 0) {
    //detachInterrupt(EncoderPinA);
    //uint32_t bufPos = 0;
//    for (int i = 0; i < iPositionBuffer; i++) {
//      sdWriteBuffer.int32[bufPos] = positionBuffer[i];
//      sdWriteBuffer.int32[bufPos+1] = timeBuffer[i];
//      bufPos+=2;
//    }
    sdWriteBuffer.int32[0] = positionBuffer[iPositionBuffer-1];
    sdWriteBuffer.int32[1] = timeBuffer[iPositionBuffer-1];
    DataFile.write(sdWriteBuffer.uint8, 8);
    dataPos+=1;
    iPositionBuffer = iPositionBuffer - 1;

    
    //DataFile.write(sdWriteBuffer.uint8, 8*iPositionBuffer);
    //dataPos+=iPositionBuffer;
    //iPositionBuffer = 0;
    //attachInterrupt(EncoderPinA, readNewPosition, RISING);
  }
}

byte readByteFromSource(byte opSource) {
  switch (opSource) {
    case 0:
      return myUSB.readByte();
    break;
    case 1:
      return StateMachineCOM.readByte();
    break;
    case 2:
      return OutputStreamCOM.readByte();
    break;
  }
}
