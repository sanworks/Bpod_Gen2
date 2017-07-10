/*
----------------------------------------------------------------------------

This file is part of the Sanworks repository
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

// Simplified Library for programming the AD7327 ADC as installed in the Bpod analog input module
// Usage:
// 1. Create an AD7327 object: 
//    AD = AD7327(myChipSelectPin);
// 2. Instruct the AD7327 to analogRead() channels 1-MaxChannels and store the value(s) in AD.analogData: 
//    AD.readADC();
// 3. Read the value of 1 channel returned from the last conversion: 
//    myChannelData = AD.analogData.uint16[myChannel];

#include <Arduino.h>
#include <SPI.h>
#include "AD7327.h"

int SPI_speed = 10000000;

AD7327::AD7327(byte ADCChipSelect) {
  ChipSelect = ADCChipSelect;
  pinMode(ChipSelect, OUTPUT);
  digitalWrite(ChipSelect, HIGH);
  SPI.begin(); // Initialize SPI interface
  setControlRegister();
}

void AD7327::readADC(){
  SPI.beginTransaction(SPISettings(SPI_speed, MSBFIRST, SPI_MODE2));
  for (int i = 0; i < nChannelsToRead; i++) {
    digitalWrite(ChipSelect, LOW); // take the Chip Select pin low to select the ADC.
    analogData.uint16[ADChannelMap[i]] = SPI.transfer16(0);
    digitalWrite(ChipSelect, HIGH); // take the Chip Select pin high to de-select the ADC.
    bitClear(analogData.uint16[ADChannelMap[i]], 15); 
    bitClear(analogData.uint16[ADChannelMap[i]], 14); 
    bitClear(analogData.uint16[ADChannelMap[i]], 13);
  }
  SPI.endTransaction();
}

void AD7327::setNchannels(byte nChannels) {
  nChannelsToRead = nChannels;
  setControlRegister();
}

void AD7327::setRange(byte channel, byte newRangeIndex) { // See AD7327 datasheet p.24
  channel = ADChannelMap[channel];
  rangeIndexes[channel] = newRangeIndex;
  // Write first 4 ranges
  registerBuffer = 0; // Clear register buffer
  bitSet(registerBuffer, 15); // Set the write bit; if bit 14 = 0 and 13 = 1, this sends the message to range register 1 (ranges for ch1-4)
  bitSet(registerBuffer, 13); // Select range register 1
  for (int i = 0; i < 4; i++) {
    switch (rangeIndexes[i]) {
      case 0: // -10V : +10V = Default value; no change required;
      break;
      case 1: // -5V : +5V
        bitSet(registerBuffer, 12-(i*2)-1);
      break;
      case 2: // -2.5V : +2.5V
        bitSet(registerBuffer, 12-(i*2));
      break;
      case 3: // 0V : 10V
        bitSet(registerBuffer, 12-(i*2));
        bitSet(registerBuffer, 12-(i*2)-1);
      break;
    }
  }
  writeRegisterBuffer();
  setControlRegister();
  // Write last 4 ranges
  registerBuffer = 0; // Clear register buffer
  bitSet(registerBuffer, 15); // Set the write bit; if bit 14 = 0 and 13 = 1, this sends the message to range register 1 (ranges for ch1-4)
  bitSet(registerBuffer, 14); // Select range register 2
  for (int i = 0; i < 4; i++) {
    switch (rangeIndexes[i+4]) {
      case 0: // -10V : +10V = Default value; no change required;
      break;
      case 1: // -5V : +5V
        bitSet(registerBuffer, 12-(i*2)-1);
      break;
      case 2: // -2.5V : +2.5V
        bitSet(registerBuffer, 12-(i*2));
      break;
      case 3: // 0V : 10V
        bitSet(registerBuffer, 12-(i*2));
        bitSet(registerBuffer, 12-(i*2)-1);
      break;
    }
  }
  writeRegisterBuffer();
  setControlRegister();
}

void AD7327::writeRegisterBuffer() {
  SPI.beginTransaction(SPISettings(SPI_speed, MSBFIRST, SPI_MODE2));
  digitalWrite(ChipSelect, LOW);
  SPI.transfer16(registerBuffer);
  digitalWrite(ChipSelect, HIGH);
  SPI.endTransaction();
}

void AD7327::setControlRegister() {
  // Configure default ADC channel sequence type and reference source (all other settings are kept at default)
  registerBuffer = 0; // Clear register buffer
  bitSet(registerBuffer, 15); // Set the write bit (if bits 14+13 are 0, write bit 1 sends the message to the control register)
  if bitRead(nChannelsToRead-1, 2) {
    bitSet(registerBuffer, 12); // This and the next 2 bits set the top channel returned in a serial read
  }
  if bitRead(nChannelsToRead-1, 1) {
    bitSet(registerBuffer, 11);
  }
  if bitRead(nChannelsToRead-1, 0) {
    bitSet(registerBuffer, 10);
  }
  bitSet(registerBuffer, 5); // Select straight binary coding
  bitSet(registerBuffer, 4); // Set reference bit to use internal reference (see AD7327 table 9)
  bitSet(registerBuffer, 3); // Set sequencer to "consecutive" mode (see AD7327 datasheet table 12)
  writeRegisterBuffer();
}

