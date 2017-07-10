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
// NOTE: Load with Arduino 1.8.1 until otherwise notified.

// This is firmware for the Bpod DDS module, powered by Teensy 3.2, encapsulating the AD9834 DDS IC.
// Amplitude control (menu function 'A') is provided in the range [150mV p2p --- 650mV p2p] by a separate DAC chip: AD5620.
// The module can output sine or triangle waves (menu function 'W') in frequencies between 1Hz and 100kHz.
// Frequency (menu function 'F') can be controlled from: (0) USB, (1) the state machine or (2) a separate Bpod module, or any subset of these simultaneously.

// This firmware supports playback of pure tone sequences.

#include "ArCOM.h"
#include <SPI.h>
#include "ad983x.h"
ArCOM USBCOM(Serial);
ArCOM StateMachineCOM(Serial1);
ArCOM ModuleCOM(Serial2);
SPISettings DACSettings(4000000, MSBFIRST, SPI_MODE2); // Settings for DAC

// Module setup
uint32_t FirmwareVersion = 1;
char moduleName[] = "DDSSeq"; // Name of module for manual override UI and state machine assembler

// Pins
const byte DACcs = 14; // DAC chip select
const byte DDScs = 15; // DDS chip select

// DDS object
AD983X_SW myDDS(DDScs, 10);

// Timer object
IntervalTimer hardwareTimer; // Hardware timer to ensure even sampling

// Params
uint32_t samplingRate = 10; // in Hz 
uint32_t toneDuration = 1; // in samples
uint32_t toneDurationMicroseconds = 100000; // in microseconds
float frequency = 0; // Hz
byte dataFormat = 0; // 0 = vector of frequencies 1 = alternating frequencies and onset times, using onset+toneDuration for offsets

// Vars
unsigned int dacVal = 0;
union {
  byte Bytes[2];
  uint16_t Uint16[1];
} dacBuffer;
byte dacBytes[2] = {0};

unsigned long frequencyInt = 0;
uint16_t adcValue = 0;
uint32_t ampValue = 10000; // Value of amplitude scaling (0:10,000) 0 = 150mV, 10,000 = 650mV
byte op = 0;
boolean newOp = false;
byte opSource = 0;
byte currentFrequencyRegister = 0;
byte currentWaveform = 0; // 0 = sine, 1 = triangle
const int maxSamples = 10000;
double timerPeriod = 0;
double idlePeriod = 100; // Period of timer while waiting for instructions
uint32_t FreqPattern[maxSamples+2] = {0}; // Frequencies (+2 for look-ahead)
uint16_t AMenvelope[17] = {8000, 7500, 7000, 6500, 6000, 5500, 5000, 4500, 4000, 3500, 3000, 2500, 2000, 1500, 1000, 500, 0};
uint16_t nSamples = 0;
uint16_t iPattern = 0; // Index in the current pattern
uint32_t iPulse = 0; // index in the current pulse
uint16_t currentSample = 0;
uint32_t currentTime = 0;
uint32_t nextToneOnsetTime = 0;
uint32_t toneOffsetTime = 0;
uint32_t patternEndTime = 0;
uint32_t patternEndTimeMicroseconds = 0;
boolean playingPattern = false;

void setup() {
  Serial1.begin(1312500);
  Serial2.begin(1312500);
  SPI.begin();
  SPI.beginTransaction(DACSettings);
  pinMode(DACcs, OUTPUT);
  digitalWrite(DACcs, HIGH);
  frequency = 0;
  myDDS.begin();
  delay(10);
  myDDS.setFrequency(0, frequency);
  myDDS.setOutputMode(OUTPUT_MODE_SINE); // OUTPUT_MODE_SINE OUTPUT_MODE_TRIANGLE
  dacVal = 0;
  dacWrite(dacVal);
  timerPeriod = (1/(double)samplingRate)*1000000;
  hardwareTimer.begin(handler, idlePeriod); // hardwareTimer is an interval timer object - Teensy 3.6's hardware timer
}

void loop() {
  
}

void handler() {
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
      case 'A': // Set amplitude. Range = 0 : 10000 ~ 150mV : 650mV p2p
        switch (opSource) {
            case 0:
              ampValue = USBCOM.readUint32();
              USBCOM.writeByte(1);
            break;
            case 1:
              ampValue = StateMachineCOM.readUint32();
            break;
            case 2:
              ampValue = ModuleCOM.readUint32();
            break;
        }
        dacVal = (uint16_t)(16383 - ((double)ampValue/10000)*16383);
        dacWrite(dacVal);
      break;
      case 'Q': // USB request to return current parameters
        USBCOM.writeUint32((uint32_t)(frequency*1000));
        USBCOM.writeUint32((uint32_t)(ampValue*1000));
        USBCOM.writeUint32(samplingRate);
        USBCOM.writeByte(currentWaveform);
      break;
      case 'D': // Set tone duration
        toneDurationMicroseconds = USBCOM.readUint32();
        USBCOM.writeByte(1); // Confirm byte
        toneDuration = (uint32_t)((double)toneDurationMicroseconds/(double)timerPeriod);
      break;
      case 'V': // USB request to return frequency
        USBCOM.writeUint32((uint32_t)(frequency*1000));
      break;
      case 'T': // Set pattern offset time (loop mode)
        patternEndTimeMicroseconds = USBCOM.readUint32();
        patternEndTime = (uint32_t)((double)patternEndTimeMicroseconds/(double)timerPeriod);
        USBCOM.writeByte(1); // Confirm byte
      break;
      case ';': // Write directly to DAC
        dacWrite(USBCOM.readUint16());
      break;
      case 'S': // Change sampling frequency
          if (opSource == 0) {
            samplingRate = USBCOM.readUint32();
            hardwareTimer.end();
            timerPeriod = (1/(double)samplingRate)*1000000;
            hardwareTimer.begin(handler, timerPeriod);
            USBCOM.writeByte(1); // Confirm byte
            toneDuration = (uint32_t)((double)toneDurationMicroseconds/(double)timerPeriod);
            patternEndTime = (uint32_t)((double)patternEndTimeMicroseconds/(double)timerPeriod);
          }
      break;
      case 'L': // Load pattern
        if (opSource == 0) {
          dataFormat = USBCOM.readByte();
          nSamples = USBCOM.readUint16();
          USBCOM.readUint32Array(FreqPattern, nSamples+(nSamples*dataFormat));
          USBCOM.writeByte(1);
        }
      break;
      case 'P': // Play pattern
        playingPattern = true;
        currentTime = 0;
        currentSample = 0;
        iPattern = 0;
        nextToneOnsetTime = 0;
        if (dataFormat > 0) {
          nextToneOnsetTime = FreqPattern[1];
        }
        hardwareTimer.end();
        hardwareTimer.begin(handler, timerPeriod); // hardwareTimer is an interval timer object - Teensy 3.6's hardware timer
      break;
      case 'X': // Stop pattern
        freezeDDS();
        stopPlayback();
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
  if (playingPattern) {
    if (currentSample == nSamples) {
      if (patternEndTime > 0) {
        iPattern = 0;
        currentSample = 0;
      }
    }
    if (currentSample < nSamples) {
      if ((dataFormat == 0) || (currentTime == nextToneOnsetTime)) {
        iPulse = 0;
        dacWrite(AMenvelope[iPulse]);
        frequency = ((double)FreqPattern[iPattern])/1000;
        myDDS.setFrequency(0, frequency);
        myDDS.setFrequency(1, frequency);
        if (dataFormat > 0) { 
          iPattern++;
          nextToneOnsetTime = FreqPattern[iPattern+2];
          toneOffsetTime = currentTime + toneDuration;
        }
        iPattern++;
        currentSample++;
      }
    } else {
      if ((dataFormat == 0) && (patternEndTime == 0)) {
          freezeDDS();
          stopPlayback();
      }
    }
    if (dataFormat > 0) {
      if (currentTime == toneOffsetTime) {
        freezeDDS();
        if (currentSample == nSamples) {
          if (patternEndTime == 0) {
            stopPlayback();
          } else {
            iPattern = 0;
            currentSample = 0;
          }
        }
      }
    }
    if (iPulse < 17) {
      dacWrite(AMenvelope[iPulse]);
    }
    currentTime++;
    iPulse++;
    if ((currentTime >= patternEndTime) && (patternEndTime > 0)) {
      freezeDDS();
      playingPattern = false;
      hardwareTimer.end();
      hardwareTimer.begin(handler, idlePeriod);
    }
  }
}

void freezeDDS() {
  frequency = 0;
  myDDS.setFrequency(0, frequency);
  myDDS.setFrequency(1, frequency);
}

void stopPlayback() {
  playingPattern = false;
  hardwareTimer.end();
  hardwareTimer.begin(handler, idlePeriod);
}

void dacWrite(uint16_t value) {
  dacBuffer.Uint16[0] = value;
  digitalWrite(DACcs, LOW);
  SPI.transfer(dacBuffer.Bytes[1]);
  SPI.transfer(dacBuffer.Bytes[0]);
  digitalWrite(DACcs, HIGH);
}

void returnModuleInfo() { // Return module name and firmware version
  StateMachineCOM.writeByte(65); // Acknowledge
  StateMachineCOM.writeUint32(FirmwareVersion); // 4-byte firmware version
  StateMachineCOM.writeByte(sizeof(moduleName)-1); // Length of module name
  StateMachineCOM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  StateMachineCOM.writeByte(0); // 1 if more info follows, 0 if not
}
