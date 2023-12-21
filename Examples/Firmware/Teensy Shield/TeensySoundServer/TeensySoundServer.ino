/*
  ----------------------------------------------------------------------------

  This file is part of the Sanworks Bpod_Gen2 repository
  Copyright (C) Sanworks LLC, Rochester, New York, USA

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
#include "ArCOM.h"
#include <Audio.h>
#include <Wire.h>
#include <SPI.h>
#include <SD.h>
AudioPlaySdWav     wav;
AudioOutputI2S     dac;
AudioConnection c1(wav, 0, dac, 0); // Connect left channel SD to DAC left
AudioConnection c2(wav, 1, dac, 1); // Connect right channel SD to DAC right
AudioControlSGTL5000 audioShield;
ArCOM USBCOM(Serial);
ArCOM StateMachineCOM(Serial1);

// Module setup
uint32_t FirmwareVersion = 1;
char moduleName[] = "TeensyAudio"; // Name of module for manual override UI and state machine assembler

byte commandByte = 0; byte dataByte = 0;
byte soundIndex = 0;
byte soundCommandReceived = 0;
unsigned long nBytes = 0;
unsigned long LongInt = 0;
char filename[] = "XXX.WAV";;
File myFile;
const unsigned long fileTransferBufferSize = 16000;
byte fileTransferBuffer[fileTransferBufferSize] = {0};
uint32_t nFullReads = 0;
uint32_t partialReadSize = 0;

void setup() {
  Serial.begin(115200);
  Serial1.begin(1312500);
  AudioMemory(5);
  audioShield.enable();
  audioShield.volume(0.5);
  SPI.setMOSI(7); SPI.setSCK(14);
  if (SD.begin(10)) {
    myFile = SD.open("000.WAV", FILE_WRITE);
    myFile.close();
  }
}

void loop() {
  if (USBCOM.available()) {
    commandByte = USBCOM.readByte();
    switch (commandByte) {
      case 'S': // Play file
        soundCommandReceived = 1;
        soundIndex = USBCOM.readByte();
      break;
      case 'F': // Write file
        soundIndex = USBCOM.readByte();
        filename[2] = (soundIndex%10) + 48; soundIndex/= 10;
        filename[1] = (soundIndex%10) + 48; soundIndex/= 10;
        filename[0] = (soundIndex%10) + 48;
        SD.remove(filename);
        myFile = SD.open(filename, FILE_WRITE);
        if (myFile) {
          nBytes = USBCOM.readUint32();
          nFullReads = (unsigned long)(floor((double)nBytes/(double)fileTransferBufferSize));
          for (int i = 0; i < nFullReads; i++) {
            while(Serial.available() == 0) {}
            Serial.readBytes((char*)fileTransferBuffer,fileTransferBufferSize);
            myFile.write(fileTransferBuffer,fileTransferBufferSize);
          }
          partialReadSize = nBytes-(nFullReads*fileTransferBufferSize);
          if (partialReadSize > 0) {
            Serial.readBytes((char*)fileTransferBuffer,partialReadSize);
            myFile.write(fileTransferBuffer,partialReadSize);
          }         
          myFile.close();
        }
     break;
    }
  } 
  if (StateMachineCOM.available()) {
    soundCommandReceived = 1;
    soundIndex = StateMachineCOM.readByte();
  }
  if (soundCommandReceived) {
    if (soundIndex > 0) {
      if (soundIndex < 254) {
        filename[2] = (soundIndex%10) + 48; soundIndex/= 10;
        filename[1] = (soundIndex%10) + 48; soundIndex/= 10;
        filename[0] = (soundIndex%10) + 48;
        wav.play(filename);
      } else if (soundIndex == 254) {
        wav.stop();
      } else {
        returnModuleInfo();
      }
    }
    soundCommandReceived = 0;
  }
}

void returnModuleInfo() { // Return module name and firmware version
  StateMachineCOM.writeByte(65); // Acknowledge
  StateMachineCOM.writeUint32(FirmwareVersion); // 4-byte firmware version
  StateMachineCOM.writeByte(sizeof(moduleName)-1); // Length of module name
  StateMachineCOM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  StateMachineCOM.writeByte(0); // 1 if more info follows, 0 if not
}
