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
// NOTE: Load with Arduino 1.8.2 until otherwise notified.

// This is firmware for the Bpod DDS module, powered by Teensy 3.2, encapsulating the AD9834 DDS IC.
// Amplitude control (menu function 'A') is provided in the range [0mV p2p <---> 650mV p2p] by a separate DAC chip: AD5620.
// The module can output sine or triangle waves (menu function 'W') in frequencies between 1Hz and 100kHz.
// Frequency (menu function 'F') can be controlled from: (0) USB, (1) the state machine or (2) a separate Bpod module, or any subset of these simultaneously.

// This firmware supports streaming input control of frequency.
// From separate module input (2), when setting frequency with 'F', a streaming value is specified in bits (16-bit resolution), 
// and a configurable mapping function maps this value to compute frequency.
// Inputs 0 and 1 set frequency with the 'F' menu function directly, by specifying it in Hz.

#include "ArCOM.h"
#include <SPI.h>
#include "ad983x.h"
#include <EEPROM.h>
ArCOM USBCOM(Serial);
ArCOM StateMachineCOM(Serial1);
ArCOM ModuleCOM(Serial2);
SPISettings DACSettings(4000000, MSBFIRST, SPI_MODE2); // Settings for DAC

// Module setup
uint32_t FirmwareVersion = 2;
char moduleName[] = "DDSModule"; // Name of module for manual override UI and state machine assembler

// Pins
const byte DACcs = 14; // DAC chip select
const byte DDScs = 15; // DDS chip select

// DDS object
AD983X_SW myDDS(DDScs, 10);

// Vars
unsigned int dacVal = 0;
union {
  byte Bytes[2];
  int16_t Uint16[1];
} dacBuffer;
byte dacBytes[2] = {0};
float frequency = 0;
unsigned long frequencyInt = 0;
uint16_t adcValue = 0;
uint16_t adcZeroCode = 0; // Bits coding for a 0V p2p output (must be calibrated with 'C' function)
uint16_t defaultZeroCode = 7750;
uint32_t ampValue = 10000; // Value of amplitude scaling (0:10,000) 0 = 0mV, 10,000 = 650mV
uint32_t lastAmpValue = 10000; // Previous value
byte op = 0;
boolean newOp = false;
byte opSource = 0;
byte currentFrequencyRegister = 0;
byte mappingFunctionIndex = 1; // 0 = linear, 1 = exponential
byte currentWaveform = 0; // 0 = sine, 1 = triangle
uint16_t inputBitRange[2] = {0, 65535}; // Range of bits to expect on input channel (for mapping to frequency range)
unsigned long outputFrequencyRange[2] = {20, 17000}; // Mapped output frequency range. low end, high end in kHz, Preset to human auditory range


void setup() {
  Serial1.begin(1312500);
  Serial2.begin(1312500);
  SPI.begin();
  SPI.beginTransaction(DACSettings);
  pinMode(DACcs, OUTPUT);
  digitalWrite(DACcs, HIGH);
  frequency = 1000;
  myDDS.begin();
  delay(10);
  myDDS.setFrequency(0, frequency);
  myDDS.setOutputMode(OUTPUT_MODE_SINE); // OUTPUT_MODE_SINE OUTPUT_MODE_TRIANGLE
  dacVal = 0;
  adcZeroCode = EEPROMreadUint16(0); // Argument = read-start address, function below
  if (adcZeroCode == 0) { // Not yet calibrated; use a sensible value
    adcZeroCode = defaultZeroCode;
  }
  dacWrite(dacVal);
}

void loop() {
  if (USBCOM.available() > 0) {
    op = USBCOM.readByte();
    newOp = true;
    opSource = 0;
  } else if (StateMachineCOM.available() > 0) {
    op = StateMachineCOM.readByte();
    newOp = true;
    opSource= 1;
  } else if (ModuleCOM.available() > 0) {
    op = ModuleCOM.readByte();
    newOp = true;
    opSource = 2;
  }
  if (newOp) {
    newOp = false;
    switch(op) {
      case 255: // State machine request for module info
        if (opSource == 1) {
          returnModuleInfo();
        }
      break;
      case 251: // USB request to confirm connectivity and return firmware version
        if (opSource == 0) {
          USBCOM.writeByte(252);
          USBCOM.writeUint32(FirmwareVersion);
        }
      break;
      case 'F': // Set frequency
        switch (opSource) {
          case 0:
            frequencyInt = USBCOM.readUint32();
            USBCOM.writeByte(1);
          break;
          case 1:
            frequencyInt = StateMachineCOM.readUint32();
          break;
          case 2:
            frequencyInt = ModuleCOM.readUint32();
          break;
        }
        frequency = ((double)frequencyInt)/1000;
        myDDS.setFrequency(0, frequency);
        myDDS.setFrequency(1, frequency);
      break;
      case 'M': // Map 16-bit value to frequency
        switch (opSource) {
          case 0:
            adcValue = USBCOM.readUint16();
            USBCOM.writeByte(1);
          break;
          case 1:
            adcValue = StateMachineCOM.readUint16();
          break;
          case 2:
            adcValue = ModuleCOM.readUint16();
          break;
        }
        switch (mappingFunctionIndex) {
          case 0:
            frequency = linearMap(adcValue, inputBitRange[0], inputBitRange[1], outputFrequencyRange[0], outputFrequencyRange[1]);
          break;
          case 1:
            frequency = expMap(adcValue, inputBitRange[0], inputBitRange[1], outputFrequencyRange[0], outputFrequencyRange[1]);
          break;
        }
        myDDS.setFrequency(0, frequency);
        myDDS.setFrequency(1, frequency);
      break;
      case 'A': // Set amplitude. Range = 0 : 10000 = 0mV : 650mV p2p
        switch (opSource) {
          case 0:
            ampValue = USBCOM.readUint16();
            USBCOM.writeByte(1);
          break;
          case 1:
            ampValue = StateMachineCOM.readUint16();
          break;
          case 2:
            ampValue = ModuleCOM.readUint16();
          break;
        }
        if (ampValue > lastAmpValue) {
          for (int i = lastAmpValue; i < ampValue; i+=2) {
            dacVal = (uint16_t)(adcZeroCode - ((double)i/10000)*adcZeroCode);
            dacWrite(dacVal);
          }
        } else {
          for (int i = lastAmpValue; i > ampValue; i-=2) {
            dacVal = (uint16_t)(adcZeroCode - ((double)i/10000)*adcZeroCode);
            dacWrite(dacVal);
          }
        }
        lastAmpValue = ampValue;
      break;
      case 'Q': // USB request to return current parameters
        USBCOM.writeUint32((uint32_t)(frequency*1000));
        USBCOM.writeUint32((uint32_t)(ampValue*1000));
        USBCOM.writeByte(currentWaveform);
        USBCOM.writeByte(mappingFunctionIndex);
        USBCOM.writeUint16(inputBitRange[0]);
        USBCOM.writeUint16(inputBitRange[1]);
        USBCOM.writeUint32(outputFrequencyRange[0]*1000);
        USBCOM.writeUint32(outputFrequencyRange[1]*1000);
      break;
      case 'V': // USB request to return frequency
        USBCOM.writeUint32((uint32_t)(frequency*1000));
      break;
      case 'D': // Set amplitude bits (useful for evaluating zero code)
        if (opSource == 0) {
          dacVal = USBCOM.readUint16();
          dacWrite(dacVal);
          USBCOM.writeByte(1);
        }
      break;
      case 'C': // Calibrate code for zero-amplitude
        if (opSource == 0) {
          adcZeroCode = USBCOM.readUint16();
          EEPROMwriteUint16(0, adcZeroCode);
          defaultZeroCode = EEPROMreadUint16(0);
          if (defaultZeroCode == adcZeroCode) {
            USBCOM.writeByte(1);
          } else {
            USBCOM.writeByte(0);
          }
        }
      break;
      case 'B': // Set bit-range to expect on input channel
        switch (opSource) {
          case 0:
            USBCOM.readUint16Array(inputBitRange, 2);
            USBCOM.writeByte(1);
          break;
          case 1:
            StateMachineCOM.readUint16Array(inputBitRange, 2);
          break;
        }
      break;
      case 'R': // Set frequency output range
        switch (opSource) {
          case 0:
            outputFrequencyRange[0] = USBCOM.readUint32();
            outputFrequencyRange[1] = USBCOM.readUint32();
            USBCOM.writeByte(1);
          break;
          case 1:
            outputFrequencyRange[0] = StateMachineCOM.readUint32();
            outputFrequencyRange[1] = StateMachineCOM.readUint32();
          break;
          case 2:
            outputFrequencyRange[0] = ModuleCOM.readUint32();
            outputFrequencyRange[1] = ModuleCOM.readUint32();
          break;
        }
      break;
      case 'N': // Set mapping function by index
        switch (opSource) {
          case 0:
            mappingFunctionIndex = USBCOM.readByte();
            USBCOM.writeByte(1);
          break;
          case 1:
            mappingFunctionIndex = StateMachineCOM.readByte();
          break;
          case 2:
            mappingFunctionIndex = ModuleCOM.readByte();
          break;
        }
      break;
      case 'W': // Set waveform by index
        switch (opSource) {
          case 0:
            currentWaveform = USBCOM.readByte();
            USBCOM.writeByte(1);
          break;
          case 1:
            currentWaveform = StateMachineCOM.readByte();
          break;
          case 2:
            currentWaveform = ModuleCOM.readByte();
          break;
        }
        switch(currentWaveform) {
          case 0:
            myDDS.setOutputMode(OUTPUT_MODE_SINE);
          break;
          case 1:
            myDDS.setOutputMode(OUTPUT_MODE_TRIANGLE);
          break;
        }
      break;
    }
  }
}

void dacWrite(uint16_t value) {
  dacBuffer.Uint16[0] = value;
  digitalWrite(DACcs, LOW);
  SPI.transfer(dacBuffer.Bytes[1]);
  SPI.transfer(dacBuffer.Bytes[0]);
  digitalWrite(DACcs, HIGH);
}

double linearMap(uint16_t x, uint32_t in_min, uint32_t in_max, uint32_t out_min, uint32_t out_max) {
  return ((double)x - (double)in_min) * ((double)out_max - (double)out_min) / ((double)in_max - (double)in_min) + (double)out_min;
}

double expMap(uint16_t input, uint32_t in_min, uint32_t in_max, uint32_t out_min, uint32_t out_max) {
  uint32_t inputRange = in_max - in_min;
  uint32_t outputRange = out_max - out_min;
  return ((sq((double)input-(double)in_min)/sq((double)inputRange))*(double)outputRange)+(double)out_min;
}
uint16_t EEPROMreadUint16(int startAddress) {
  dacBuffer.Bytes[0] = EEPROM.read(0);
  dacBuffer.Bytes[1] = EEPROM.read(1);
  return dacBuffer.Uint16[0];
}
uint16_t EEPROMwriteUint16(int startAddress, uint16_t value) {
  dacBuffer.Uint16[0] = value;
  EEPROM.write(0, dacBuffer.Bytes[0]);
  EEPROM.write(1, dacBuffer.Bytes[1]);
}
void returnModuleInfo() { // Return module name and firmware version
  StateMachineCOM.writeByte(65); // Acknowledge
  StateMachineCOM.writeUint32(FirmwareVersion); // 4-byte firmware version
  StateMachineCOM.writeByte(sizeof(moduleName)-1); // Length of module name
  StateMachineCOM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  StateMachineCOM.writeByte(0); // 1 if more info follows, 0 if not
}
