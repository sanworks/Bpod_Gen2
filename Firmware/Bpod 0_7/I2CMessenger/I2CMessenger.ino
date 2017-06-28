/*
  ----------------------------------------------------------------------------

  This file is part of the Sanworks Bpod repository
  Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

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
#include <Wire.h>
#include "ArCOM.h" // ArCOM is a serial interface wrapper developed by Sanworks, to streamline transmission of datatypes and arrays over serial
#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256
ArCOM myUSB(SerialUSB); // Creates an ArCOM object called myUSB, wrapping SerialUSB
ArCOM myUART(Serial1); // Creates an ArCOM object called myUART, wrapping Serial1

// Module setup
unsigned long FirmwareVersion = 1;
char moduleName[] = "I2C"; // Name of module for manual override UI and state machine assembler

uint32_t firmwareVer = 1;
byte opCode = 0; 
byte currentMessage = 0; // Index of current message
byte slaveAddress = 1; // Address of I2C slave that will receive outgoing messages
byte nBytes = 0;
byte nMessages = 0;
byte messageID = 0;
byte transferSpeed = 1; // 0 = I2C standard (100kb/s), 1 = I2C fast mode (400kb/s)
const byte maxMessageLength = 16;
byte mappingMode = 0; // What to do with incoming UART bytes 0 = pass through to I2C, 1 = trigger I2C message, 2 = pass through to USB, 3 = trigger USB message
byte messages[256][maxMessageLength] = {0};
byte messageAddress[256] = {0};
byte messageBuffer[maxMessageLength] = {0};
byte messageLength[256] = {0};
void setup() {
  // put your setup code here, to run once:
  Serial1.begin(1312500); //1312500 //2625000
  Wire.begin(); // join i2c bus (address optional for master)
  Wire.setClock(400000); // Set to I2C fast mode
}

void loop() {
  if (myUSB.available()>0) {
    opCode = myUSB.readByte();
    switch (opCode) {
      case 'C': // Acknowledge connection and send firmware version
        myUSB.writeByte(225);
        myUSB.writeUint32(firmwareVer);
      break;
      case 'B': // Return current settings
        myUSB.writeByte(slaveAddress);
        myUSB.writeByte(transferSpeed);
        myUSB.writeByte(mappingMode);
      break;
      case 'I': // Send byte to I2C
        I2CsendByte(myUSB.readByte());
      break;
      case 'G': // Send message to I2C
        I2CsendMessage(myUSB.readByte());
      break;
      case 'S': // Send byte to UART
        myUART.writeByte(myUSB.readByte());
      break;
      case 'A': // Change I2C address
        slaveAddress = myUSB.readByte();
        myUSB.writeByte(1); // Confirm
      break;
      case 'R': // Change I2C transfer speed
        transferSpeed = myUSB.readByte();
        if (transferSpeed == 0) {
            Wire.setClock(100000); // I2C standard mode
            messageID = 1;
        } else if (transferSpeed == 1) {
            Wire.setClock(400000); // I2C fast mode
            messageID = 1;
        } else {
            messageID = 0;
        }
        myUSB.writeByte(messageID); // Confirm
      break;
      case 'M': // Change mapping mode
        mappingMode = myUSB.readByte();
        if (mappingMode > 3) {
          mappingMode = 0;
          myUSB.writeByte(0); // Send error
        } else {
          myUSB.writeByte(1); // Confirm
        }
      break;
      case 'P': // Program message library
        nMessages = myUSB.readByte();
        for (int i = 0; i<nMessages; i++){
          messageID = myUSB.readByte();
          messageAddress[messageID] = myUSB.readByte();
          nBytes = myUSB.readByte();
          messageLength[messageID] = nBytes;
          for (int j = 0; j<nBytes; j++) {
            messages[messageID][j] = myUSB.readByte();
          }
        }
        myUSB.writeByte(1); // Confirm
      break;
      case 'X': // Clear messages
        for (int i = 0; i < 256; i++) {
          messageAddress[i] = 0;
          messageLength[i] = 0;
        }
      break;
    }
  }
  if (myUART.available()) {
    opCode = myUART.readByte();
    switch(opCode) {
      case 255: // Return module name and info
        returnModuleInfo();
      break;
      case 1:
         currentMessage = myUART.readByte();
         switch(mappingMode) {
          case 0:
            I2CsendByte(currentMessage);
          break;
          case 1:
            I2CsendMessage(currentMessage);
          break;
          case 2:
            myUSB.writeByte(currentMessage);
          break;
          case 3:
            for (int i = 0; i < messageLength[currentMessage]; i++) {
              messageBuffer[i] = messages[currentMessage][i];
            }
            myUSB.writeByteArray(messageBuffer, messageLength[currentMessage]);
          break;
         }
      break;
    }
  }
}

void I2CsendByte(byte aByte) {
  Wire.beginTransmission(slaveAddress);
  Wire.write(aByte); 
  Wire.endTransmission();
}

void I2CsendMessage(byte messageIndex) {
  Wire.beginTransmission(messageAddress[messageIndex]);
  for (int i = 0; i < messageLength[messageIndex]; i++) {
    messageBuffer[i] = messages[messageIndex][i];
  }
  Wire.write(messageBuffer, messageLength[messageIndex]); 
  Wire.endTransmission();
}

void returnModuleInfo() {
  myUART.writeByte(65); // Acknowledge
  myUART.writeUint32(FirmwareVersion); // 4-byte firmware version
  myUART.writeByte(sizeof(moduleName)-1); // Length of module name
  myUART.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  myUART.writeByte(0); // 1 if more info follows, 0 if not
}
