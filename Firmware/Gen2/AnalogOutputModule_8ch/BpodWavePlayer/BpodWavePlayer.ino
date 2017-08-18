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

// IMPORTANT: Requires the SDFat-Beta library from:
// https://github.com/greiman/SdFat-beta/tree/master/SdFat

#include "ArCOM.h"
#include <SPI.h>
#include "SdFat.h"
SdFatSdioEX SD;
#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256

#define FirmwareVersion 1

// Module setup
char moduleName[] = "WavePlayer"; // Name of module for manual override UI and state machine assembler

// Parameters
const byte nChannels = 8; // Number of analog output channels
const int maxWaves = 64; // Maximum number of waveforms (used to set up data buffers and to ensure data file is large enough)
const unsigned long bufSize = 1280; // Buffer size (in samples, note: 2 bytes/sample). Larger buffers prevent underruns, but take up memory.
                                    // Each wave in MaxWaves is allocated 1 buffer worth of sRAM (Teensy 3.6 total sRAM = 256k)
const unsigned long maxWaveSize = 1000000; // Maximum number of samples per waveform
const byte maxTriggerProfiles = 64; // Maximum number of trigger profiles (vectors of waves to play on each channel for different trigger bytes) 
union {
    byte byteArray[4];
    float floatVal;
} timerPeriod; // Default hardware timer period during playback, in microseconds (100 = 10kHz). Set as a Union so it can be read as bytes.
float timerPeriod_Idle = 20; // Default hardware timer period while idle (no playback, awaiting commands; determines playback latency)

// Pin definitions
const byte RefEnable1 = 31; // External 3V reference enable pin
const byte SyncPin1=34; // AD5754 Pin 7 (Sync)
const byte LDACPin1=32; // AD5754 Pin 10 (LDAC)
const byte RefEnable2 = 33; // External 3V reference enable pin
const byte SyncPin2=14; // AD5754 Pin 7 (Sync)
const byte LDACPin2=39; // AD5754 Pin 10 (LDAC)

// System objects
SPISettings DACSettings(30000000, MSBFIRST, SPI_MODE2); // Settings for DAC
IntervalTimer hardwareTimer; // Hardware timer to ensure even sampling
File Wave0; // File on microSD card, to store waveform data

// Playback variables
byte opCode = 0; // Serial inputs access an op menu. The op code byte stores the intended operation.
byte opSource = 0; // 0 = op from USB, 1 = op from UART1, 2 = op from UART2. More op code menu options are exposed for USB.
boolean newOpCode = 0; // true if an opCode was read from one of the ports
byte inByte = 0; // General purpose byte for Serial read
byte BpodMessage = 0; // Stores the current message byte to send to the Bpod State Machine (playback start/stop event, bits indicate channels)
byte rangeIndex = 3; // 0 = '0V:5V', 1 = '0V:10V', 2 = '0V:12V', 3 = '-5V:5V', 4 = '-10V:10V', 5 = '-12V:12V' 
byte triggerMode = 0; // Triggers during playback are: 0 = ignored (default) 1 = handled (new waveform starts)  2 = stop playback
boolean triggerProfileEnable = false; // If enabled, each profile is a vector of 4 waveform indexes to play on output channels, on receiving the profile's trigger byte.
byte triggerProfiles[nChannels][maxTriggerProfiles] = {255}; // waves to play on each channel (trigger profile mode; 255 = no wave)
boolean currentTriggerChannels[nChannels] = {0}; // Vector of channels affected by current trigger event
byte currentTriggerWaves[nChannels] = {0}; // Vector of waves to play for current trigger event
unsigned long nSamples[maxWaves] = {0}; // Number of samples in each waveform
unsigned long currentSample[nChannels] = {0}; // Current position in waveform for each channel
byte waveLoaded[nChannels] = {0}; // Waveform currently loaded on each channel (loading is instant on trigger)
boolean playing[nChannels] = {false}; // True for each channel that is playing a waveform
boolean playbackActive = false; // True if any channel is playing a waveform
boolean playbackActiveLastCycle = false; // True if playback was active on the previous hardware timer callback (for resetting timer to idle refresh rate)
boolean schedulePlaybackStop[nChannels] = {0}; // Reminds the program to set playing = false after next DAC update
byte sendBpodEvents[nChannels] = {0}; // Sends a byte to Bpod state machine, to indicate playback start and stop. Bits of byte indicate which channels.
byte loopMode[nChannels] = {0}; // (for each channel) Loops waveform until loopDuration seconds
unsigned long loopDuration[nChannels] = {0}; // Duration of loop for loop mode (in samples)
unsigned long channelTime[nChannels] = {0}; // Time (in samples) since looping channel was triggered (used to compute looped playback end)
byte waveIndex = 0; // Index of current waveform (1-maxWaves; maxWaves is in the "parameters" section above)
byte channelIndex = 0; // Index of current output channel (1-8)
const unsigned long maxWaveSizeBytes = maxWaveSize*2; // Maximum size of a waveform in bytes (maxWaveSize is in the "parameters" section above)
const int bufSizeBytes = bufSize*2; // Size of the buffer in bytes (bufSizeBytes is in the "parameters" section above)
byte currentBuffer[nChannels] = {0}; // Current buffer for each channel (a double buffering scheme allows one to be filled while the other is read)
boolean loadFlag[nChannels] = {0}; // Set true when the buffer switches, to trigger filling of the empty buffer
int bufferPos[nChannels] = {0}; // Position of current sample in the current data buffer, for each output channel
unsigned long filePos[nChannels] = {0}; // Position of current sample in the data file, for each output channel
byte preBuffer[maxWaves][bufSizeBytes] = {0}; // The first buffer worth of each waveform is stored here on load, to achieve super-low latency playback.
boolean preBufferActive[nChannels] = {1}; // Each channel begins playback from the pre-buffer
unsigned short DACBits_ZeroVolts = 32768; // Code (in bits) for 0V. For bipolar ranges, this should be 32768. For unipolar, 0.
byte countdown2Play[nChannels] = {0}; // Set to 2 if a channel has been triggered, and needs to begin playback in 2 cycles. Set to 1 on next cycle, etc.
                                      // This ensures that a cycle burdened with serial reads and triggering logic does not also update the channel voltage.
                                      // The phenotype, if too few cycles are skipped, is a short first sample. 
boolean dac2Active = true; // Set automatically to false if sampling rate is too high to support ch4-8

// Communication variables
const int BpodSerialBaudRate = 1312500; // Communication rate for Bpod UART channel
byte dacBuffer[3] = {0}; // Holds bytes to be written to the DAC
union {
    byte byteArray[nChannels*2];
    uint16_t uint16[nChannels];
} dacValue; // 16-Bit code of current sample on DAC output channels. A union type allows instant conversion between bytes and 16-bit ints
union {
    byte byteArray[2];
    uint16_t uint16[1];
} sdSample;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel1BufferA; // channel1BufferA and channel1BufferB form a double-buffer - one buffer fills while the other drives the DAC
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel1BufferB;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel2BufferA;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel2BufferB;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel3BufferA;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel3BufferB;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel4BufferA;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel4BufferB;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel5BufferA;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel5BufferB;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel6BufferA;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel6BufferB;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel7BufferA;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel7BufferB;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel8BufferA;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} channel8BufferB;

// Wrap serial interfaces
ArCOM USBCOM(Serial); // Creates an ArCOM object called USBCOM, wrapping Serial (for Teensy 3.6)
ArCOM Serial1COM(Serial3); // Creates an ArCOM object called Serial1COM, wrapping Serial3
ArCOM Serial2COM(Serial2); 

// File transfer buffer
const unsigned long fileTransferBufferSize = 32000;
byte fileTransferBuffer[fileTransferBufferSize] = {0};
unsigned long nFullReads = 0;
unsigned long partialReadSize = 0;

void setup() {
  Serial2.begin(1312500);
  Serial3.begin(1312500);
  pinMode(RefEnable1, OUTPUT); // Reference enable pin sets the external reference IC output to 3V (RefEnable=high) or high impedence (RefEnable = low)
  digitalWrite(RefEnable1, LOW); // Disabling external reference IC allows other voltage ranges with DAC internal reference
  pinMode(SyncPin1, OUTPUT); // Configure SPI bus pins as outputs
  pinMode(LDACPin1, OUTPUT);
  pinMode(RefEnable2, OUTPUT); // Reference enable pin sets the external reference IC output to 3V (RefEnable=high) or high impedence (RefEnable = low)
  digitalWrite(RefEnable2, LOW); // Disabling external reference IC allows other voltage ranges with DAC internal reference
  pinMode(SyncPin2, OUTPUT); // Configure SPI bus pins as outputs
  pinMode(LDACPin2, OUTPUT);
  SPI.begin(); // Initialize SPI interface
  SPI.beginTransaction(DACSettings); // Set SPI parameters to DAC speed and bit order
  digitalWrite(LDACPin1, LOW); // Ensure DAC load pin is at default level (low)
  digitalWrite(LDACPin2, LOW); // Ensure DAC load pin is at default level (low)
  ProgramDAC(16, 0, 31); // Power up all channels + internal ref)
  ProgramDAC(12, 0, 3); // Set output range to +/- 5V
  zeroDAC(); // Set all DAC channels to 0V
  SD.begin(); // Initialize microSD card
  timerPeriod.floatVal = 100; // Set a default sampling rate (10kHz)
  hardwareTimer.begin(handler, timerPeriod.floatVal); // hardwareTimer is an interval timer object - Teensy 3.6's hardware timer
}

void loop() { // loop runs in parallel with hardware timer, at lower interrupt priority. Its function is to fill playback buffers from the microSD card.
  for (int i = 0; i < nChannels; i++) {
    if (playing[i]) {
      if (loadFlag[i]) {
        loadFlag[i] = 0;
        Wave0.seek(filePos[i]);
        switch(i) {
          case 0:
            if (currentBuffer[i] == 1) {
              Wave0.read(channel1BufferA.byteArray, bufSizeBytes);
            } else {
              Wave0.read(channel1BufferB.byteArray, bufSizeBytes);
            }
          break;
          case 1:
            if (currentBuffer[i] == 1) {
              Wave0.read(channel2BufferA.byteArray, bufSizeBytes);
            } else {
              Wave0.read(channel2BufferB.byteArray, bufSizeBytes);
            }
          break;
          case 2:
            if (currentBuffer[i] == 1) {
              Wave0.read(channel3BufferA.byteArray, bufSizeBytes);
            } else {
              Wave0.read(channel3BufferB.byteArray, bufSizeBytes);
            }
          break;
          case 3:
            if (currentBuffer[i] == 1) {
              Wave0.read(channel4BufferA.byteArray, bufSizeBytes);
            } else {
              Wave0.read(channel4BufferB.byteArray, bufSizeBytes);
            }
          break;
          case 4:
            if (currentBuffer[i] == 1) {
              Wave0.read(channel5BufferA.byteArray, bufSizeBytes);
            } else {
              Wave0.read(channel5BufferB.byteArray, bufSizeBytes);
            }
          break;
          case 5:
            if (currentBuffer[i] == 1) {
              Wave0.read(channel6BufferA.byteArray, bufSizeBytes);
            } else {
              Wave0.read(channel6BufferB.byteArray, bufSizeBytes);
            }
          break;
          case 6:
            if (currentBuffer[i] == 1) {
              Wave0.read(channel7BufferA.byteArray, bufSizeBytes);
            } else {
              Wave0.read(channel7BufferB.byteArray, bufSizeBytes);
            }
          break;
          case 7:
            if (currentBuffer[i] == 1) {
              Wave0.read(channel8BufferA.byteArray, bufSizeBytes);
            } else {
              Wave0.read(channel8BufferB.byteArray, bufSizeBytes);
            }
          break;
        }
        filePos[i] += bufSizeBytes;
      }
    }
  }
}

void handler(){ // The handler is triggered precisely every timerPeriod microseconds. It processes serial commands and playback logic.
  if (Serial1COM.available() > 0) {
    opCode = Serial1COM.readByte(); // Read in an op code
    opSource = 1; // UART 1
    newOpCode = true;
  } else if (Serial2COM.available() > 0) {
    opCode = Serial2COM.readByte();
    opSource = 2; // UART 2
    newOpCode = true;
  } else if (USBCOM.available() > 0) {
    opCode = USBCOM.readByte();
    opSource = 0; // USB
    newOpCode = true;
  }
  if (newOpCode) { // If an op byte arrived from one of the serial interfaces
    newOpCode = false;
    switch(opCode) {
      case 227: // Handshake
        if (opSource == 0) {
          USBCOM.writeByte(228); // Unique reply-byte
          USBCOM.writeUint32(FirmwareVersion); // Send firmware version
        }
      break;
      case 255: // Return Bpod module info
        if (opSource == 1) { // Only returns this info if requested from state machine device
          returnModuleInfo();
        }
      break;
      case 'N': // Return playback params
        if (opSource == 0){
          USBCOM.writeByte(nChannels);
          USBCOM.writeUint16(maxWaves);
          USBCOM.writeByte(triggerMode);
          USBCOM.writeByte(triggerProfileEnable);
          USBCOM.writeByte(maxTriggerProfiles);
          USBCOM.writeByte(rangeIndex);
          USBCOM.writeByteArray(timerPeriod.byteArray, 4);
          USBCOM.writeByteArray(sendBpodEvents, nChannels);
          USBCOM.writeByteArray(loopMode, nChannels);
          USBCOM.writeUint32Array(loopDuration, nChannels);
        }
      break;
      case 'O': // Set loop mode and duration (for each channel)
      if (opSource == 0){
        for (int i = 0; i < nChannels; i++) {
          loopMode[i] = USBCOM.readByte();
        }
        for (int i = 0; i < nChannels; i++) {
          loopDuration[i] = USBCOM.readUint32();
        }
        USBCOM.writeByte(1); // Acknowledge
      }
      break;
      case 'V': // Set Bpod event reporting (for each channel)
      if (opSource == 0){
        for (int i = 0; i < nChannels; i++) {
          sendBpodEvents[i] = USBCOM.readByte();
        }
        USBCOM.writeByte(1); // Acknowledge
      }
      break;
      case 'T': // Set trigger mode
        if (opSource == 0){
           triggerMode = USBCOM.readByte(); 
           USBCOM.writeByte(1); // Acknowledge
        }
      break;
      case 'B': // Set trigger profile enable
        if (opSource == 0){
           triggerProfileEnable = USBCOM.readByte();
           USBCOM.writeByte(1); // Acknowledge
        }
      break;
      case 'F': // Load trigger profiles
      for (int i = 0; i < nChannels; i++){
        for (int j = 0; j < maxTriggerProfiles; j++) {
          triggerProfiles[i][j] = USBCOM.readByte();
        }
      }
      USBCOM.writeByte(1); // Acknowledge
      break;
      case 'Y': // Create and/or Clear data file on microSD card, with enough space to store all waveforms (to be optimized for speed)
        if (opSource == 0) {
          for (int i = 0; i < fileTransferBufferSize; i++) {
            fileTransferBuffer[i] = 0;
          }
          Wave0 = SD.open("Wave0.wfm", FILE_WRITE);
          Wave0.seek(0); // Set write position to first byte
          for (unsigned long longInd = 0; longInd < (maxWaves*maxWaveSize*2)/fileTransferBufferSize; longInd++) {
            Wave0.write(fileTransferBuffer,fileTransferBufferSize); // Write fileTransferBufferSize zeros
          }
          Wave0.close();
          USBCOM.writeByte(1); // Acknowledge
        }
      break;
      case 'R': // Set DAC range (for all outputs)
        if (opSource == 0) {
          rangeIndex = USBCOM.readByte(); // rangeIndex 0 = '0V:5V', 1 = '0V:10V', 2 = '0V:12V', 3 = '-5V:5V', 4 = '-10V:10V', 5 = '-12V:12V'
          switch(rangeIndex) {
            case 0:
              digitalWrite(RefEnable1, LOW); // Disable external reference IC
              digitalWrite(RefEnable2, LOW);
              ProgramDAC(16, 0, 31); // Power up all channels + internal ref)
              ProgramDAC(12, 0, 0); // Set output range to 0-5V
              DACBits_ZeroVolts = 0; // Update 0V bit code
            break;
            case 1:
              digitalWrite(RefEnable1, LOW); // Disable external reference IC
              digitalWrite(RefEnable2, LOW);
              ProgramDAC(16, 0, 31); // Power up all channels + internal ref)
              ProgramDAC(12, 0, 1); // Set output range to 0-10V
              DACBits_ZeroVolts = 0; // Update 0V bit code
            break;
            case 2:
              ProgramDAC(16, 0, 15); // Power up all channels without internal reference
              digitalWrite(RefEnable1, HIGH); // Enable external reference IC
              digitalWrite(RefEnable2, HIGH);
              ProgramDAC(12, 0, 1); // Set output range to 0-10V (using external ref, this setting = 0-12V)
              DACBits_ZeroVolts = 0; // Update 0V bit code
            break;
            case 3:
              digitalWrite(RefEnable1, LOW); // Disable external reference IC
              digitalWrite(RefEnable2, LOW);
              ProgramDAC(16, 0, 31); // Power up all channels + internal ref)
              ProgramDAC(12, 0, 3); // Set output range to +/- 5V
              DACBits_ZeroVolts = 32768; // Update 0V bit code
            break;
            case 4:
              digitalWrite(RefEnable1, LOW); // Disable external reference IC
              digitalWrite(RefEnable2, LOW);
              ProgramDAC(16, 0, 31); // Power up all channels + internal ref)
              ProgramDAC(12, 0, 4); // Set output range to +/- 10V
              DACBits_ZeroVolts = 32768; // Update 0V bit code
            break;
            case 5:
              ProgramDAC(16, 0, 15); // Power up all channels without internal reference
              digitalWrite(RefEnable1, HIGH); // Enable external reference IC
              digitalWrite(RefEnable2, HIGH);
              ProgramDAC(12, 0, 4); // Set output range to +/- 10V (using external ref, this setting = +/- 12V)
              DACBits_ZeroVolts = 32768; // Update 0V bit code
            break;
          }
          zeroDAC();
          USBCOM.writeByte(1); // Acknowledge
        }
      break;
      case 'L': // Load sound
        if (opSource == 0) {
          waveIndex = USBCOM.readByte();
          if (waveIndex < maxWaves) { // Sanity check
            nSamples[waveIndex] = USBCOM.readUint32();
            Wave0 = SD.open("Wave0.wfm", FILE_WRITE);
            Wave0.seek(maxWaveSizeBytes*waveIndex);
            nFullReads = (unsigned long)(floor((double)nSamples[waveIndex]*2/(double)fileTransferBufferSize));
            for (int i = 0; i < nFullReads; i++) {
              while(Serial.available() == 0) {}
              Serial.readBytes((char*)fileTransferBuffer,fileTransferBufferSize);
              Wave0.write(fileTransferBuffer,fileTransferBufferSize);
              if (i == 0) {
                for (int j = 0; j < bufSizeBytes; j++) {
                  preBuffer[waveIndex][j] = fileTransferBuffer[j];
                }
              }
            }
            partialReadSize = (nSamples[waveIndex]*2)-(nFullReads*fileTransferBufferSize);
            if (partialReadSize > 0) {
              Serial.readBytes((char*)fileTransferBuffer,partialReadSize);
              Wave0.write(fileTransferBuffer,partialReadSize);
              if (nFullReads == 0) {
                if ((nSamples[waveIndex]*2) > fileTransferBufferSize) {
                  for (int j = 0; j < bufSizeBytes; j++) {
                    preBuffer[waveIndex][j] = fileTransferBuffer[j];
                  }
                } else {
                  for (int j = 0; j < nSamples[waveIndex]*2; j++) {
                    preBuffer[waveIndex][j] = fileTransferBuffer[j];
                  }
                }
              }
            }         
            Wave0.close();
            USBCOM.writeByte(1);
            Wave0 = SD.open("Wave0.wfm", FILE_READ);
          }
        }
      break;
      case 'P': // Play a waveform (1 max; any subset of channels)
        if (triggerProfileEnable) {
          switch(opSource) {
            case 0:
              inByte = USBCOM.readByte(); // Profile ID to trigger
            break;
            case 1:
              inByte = Serial1COM.readByte();
            break;
            case 2:
              inByte = Serial2COM.readByte();
            break;
          }
          for (int i = 0; i<nChannels; i++) {
            currentTriggerWaves[i] = triggerProfiles[i][inByte];
            currentTriggerChannels[i] = 0;
            if (currentTriggerWaves[i] != 255) {
              currentTriggerChannels[i] = 1;
            }
          }
        } else {
          switch(opSource) {
            case 0:
              channelIndex = USBCOM.readByte(); // Bits specifying channels to trigger
              waveIndex = USBCOM.readByte();
            break;
            case 1:
              channelIndex = Serial1COM.readByte(); // Bits specifying channels to trigger
              waveIndex = Serial1COM.readByte();
            break;
            case 2:
              channelIndex = Serial2COM.readByte(); // Bits specifying channels to trigger
              waveIndex = Serial2COM.readByte();
            break;
          }
          for (int i = 0; i<nChannels; i++) {
            if bitRead(channelIndex, i) {
              currentTriggerChannels[i] = 1;
              currentTriggerWaves[i] = waveIndex;
            } else {
              currentTriggerChannels[i] = 0;
            }
          }
        }
        BpodMessage = 0;
        for (int i = 0; i<nChannels; i++) {
          if (currentTriggerChannels[i]) {
            switch(triggerMode) {
              case 0: // Normal mode: Trigger only if not already playing
                if (!playing[i]) {
                  triggerChannel(i, currentTriggerWaves[i]);
                  if (sendBpodEvents[i]) {
                    bitSet(BpodMessage, i); 
                  }
                }
              break;
              case 1: // Master Mode: Trigger even if already playing
                triggerChannelMaster(i, currentTriggerWaves[i]);
                if (sendBpodEvents[i]) {
                    bitSet(BpodMessage, i); 
                }
              break;
              case 2:  // Toggle mode: Trigger stops channel if playing
                if (playing[i]) {
                  schedulePlaybackStop[i] = true;
                } else {
                  triggerChannel(i, currentTriggerWaves[i]);
                }
                if (sendBpodEvents[i]) {
                   bitSet(BpodMessage, i); 
                }
              break;
            }
          }
        }
        if (BpodMessage > 0) {
          Serial1COM.writeByte(BpodMessage); 
        }
      break;
      case 'X': // Stop all playback
        zeroDAC();
      break;    
      case 'S':
      if (opSource == 0) {
        USBCOM.readByteArray(timerPeriod.byteArray, 4);
        hardwareTimer.end();
        if (timerPeriod.floatVal < 33) {
          dac2Active = false;
        } else {
          dac2Active = true;
        }
        hardwareTimer.begin(handler, timerPeriod.floatVal);
      }
      break;
    }
  }
  playbackActive = false;
  for (int i = 0; i < nChannels; i++) {
    if (playing[i]) {
      playbackActive = true;
      if (preBufferActive[i]) {
        dacValue.uint16[i] = word(preBuffer[waveLoaded[i]][bufferPos[i]+1], preBuffer[waveLoaded[i]][bufferPos[i]]);
      } else {
        switch(i) {
          case 0:
          if (currentBuffer[i] == 0) {
            dacValue.uint16[i] = channel1BufferA.uint16[bufferPos[i]];
          } else {
            dacValue.uint16[i] = channel1BufferB.uint16[bufferPos[i]];
          }
          break;
          case 1:
          if (currentBuffer[i] == 0) {
            dacValue.uint16[i] = channel2BufferA.uint16[bufferPos[i]];
          } else {
            dacValue.uint16[i] = channel2BufferB.uint16[bufferPos[i]];
          }
          break;
          case 2:
          if (currentBuffer[i] == 0) {
            dacValue.uint16[i] = channel3BufferA.uint16[bufferPos[i]];
          } else {
            dacValue.uint16[i] = channel3BufferB.uint16[bufferPos[i]];
          }
          break;
          case 3:
          if (currentBuffer[i] == 0) {
            dacValue.uint16[i] = channel4BufferA.uint16[bufferPos[i]];
          } else {
            dacValue.uint16[i] = channel4BufferB.uint16[bufferPos[i]];
          }
          break;
          case 4:
          if (currentBuffer[i] == 0) {
            dacValue.uint16[i] = channel5BufferA.uint16[bufferPos[i]];
          } else {
            dacValue.uint16[i] = channel5BufferB.uint16[bufferPos[i]];
          }
          break;
          case 5:
          if (currentBuffer[i] == 0) {
            dacValue.uint16[i] = channel6BufferA.uint16[bufferPos[i]];
          } else {
            dacValue.uint16[i] = channel6BufferB.uint16[bufferPos[i]];
          }
          break;
          case 6:
          if (currentBuffer[i] == 0) {
            dacValue.uint16[i] = channel7BufferA.uint16[bufferPos[i]];
          } else {
            dacValue.uint16[i] = channel7BufferB.uint16[bufferPos[i]];
          }
          break;
          case 7:
          if (currentBuffer[i] == 0) {
            dacValue.uint16[i] = channel8BufferA.uint16[bufferPos[i]];
          } else {
            dacValue.uint16[i] = channel8BufferB.uint16[bufferPos[i]];
          }
          break;
        }
      }
      if (preBufferActive[i]) {
        bufferPos[i]+= 2;
        if (bufferPos[i] >= bufSizeBytes) {
          preBufferActive[i] = false;
          currentBuffer[i] = 1-currentBuffer[i];
          bufferPos[i] = 0;
          loadFlag[i] = 1;
        }
      } else {
        bufferPos[i]++;
        if (bufferPos[i] >= bufSize) {
          currentBuffer[i] = 1-currentBuffer[i];
          bufferPos[i] = 0;
          loadFlag[i] = 1;
        }
      }
      currentSample[i]++;
      channelTime[i]++;
      if (currentSample[i] > nSamples[waveLoaded[i]]) {
        if (loopMode[i]) {
          resetChannel(i);
        } else {
          schedulePlaybackStop[i] = true;
          filePos[i] = maxWaveSize*waveLoaded[i];
          dacValue.uint16[i] = DACBits_ZeroVolts;
        }
      }
      if (loopMode[i]) {
        if (channelTime[i] > loopDuration[i]) {
          schedulePlaybackStop[i] = true;
          filePos[i] = maxWaveSize*waveLoaded[i];
          dacValue.uint16[i] = DACBits_ZeroVolts;
        }
      }
      if (schedulePlaybackStop[i]) {
        dacValue.uint16[i] = DACBits_ZeroVolts;
      }
    }
  }
  if (playbackActive) {
    if (playbackActiveLastCycle == false) {
        hardwareTimer.end();
        hardwareTimer.begin(handler, timerPeriod.floatVal);
    }
    dacWrite();
    BpodMessage = 0;
    for (int i = 0; i < nChannels; i++) {
      if (schedulePlaybackStop[i]) {
        playing[i] = false;
        schedulePlaybackStop[i] = false;
        if (sendBpodEvents[i]) {
          bitSet(BpodMessage, i); 
        }
      }
      if (countdown2Play[i]) {
        countdown2Play[i] = false;
        playing[i] = true;
      }
    }
    if (BpodMessage > 0) {
      Serial1COM.writeByte(BpodMessage);    
    }
    playbackActiveLastCycle = true;
  } else {
    if (playbackActiveLastCycle) {
      playbackActiveLastCycle = false;
      hardwareTimer.end();
      hardwareTimer.begin(handler, timerPeriod_Idle);
    }
    for (int i = 0; i < nChannels; i++) {
      if (countdown2Play[i] == 1) {
        countdown2Play[i] = 0;
        playing[i] = true;
        loadFlag[i] = 1;
      }
      if (countdown2Play[i] == 2) {
        countdown2Play[i] = 1;
      }
    }
  }
}

void ProgramDAC(byte Data1, byte Data2, byte Data3) {
  digitalWrite(LDACPin1,HIGH);
  digitalWrite(SyncPin1,LOW);
  SPI.transfer (Data1);
  SPI.transfer (Data2);
  SPI.transfer (Data3);
  digitalWrite(SyncPin1,HIGH);
  digitalWrite(LDACPin1,LOW);
  digitalWrite(LDACPin2,HIGH);
  digitalWrite(SyncPin2,LOW);
  SPI.transfer (Data1);
  SPI.transfer (Data2);
  SPI.transfer (Data3);
  digitalWrite(SyncPin2,HIGH);
  digitalWrite(LDACPin2,LOW);
}

void dacWrite() {
  digitalWrite(LDACPin1,HIGH);
  if (playing[0]) {
    digitalWrite(SyncPin1,LOW);
    dacBuffer[0] = 3;
    dacBuffer[1] = dacValue.byteArray[1];
    dacBuffer[2] = dacValue.byteArray[0];
    SPI.transfer(dacBuffer,3);
    digitalWrite(SyncPin1,HIGH);
  }
  if (playing[1]) {
    digitalWrite(SyncPin1,LOW);
    dacBuffer[0] = 2;
    dacBuffer[1] = dacValue.byteArray[3];
    dacBuffer[2] = dacValue.byteArray[2];
    SPI.transfer(dacBuffer,3);
    digitalWrite(SyncPin1,HIGH);
  }
  if (playing[2]) {
    digitalWrite(SyncPin1,LOW);
    dacBuffer[0] = 0;
    dacBuffer[1] = dacValue.byteArray[5];
    dacBuffer[2] = dacValue.byteArray[4];
    SPI.transfer(dacBuffer,3);
    digitalWrite(SyncPin1,HIGH);
  }
  if (playing[3]) {
    digitalWrite(SyncPin1,LOW);
    dacBuffer[0] = 1;
    dacBuffer[1] = dacValue.byteArray[7];
    dacBuffer[2] = dacValue.byteArray[6];
    SPI.transfer(dacBuffer,3);
    digitalWrite(SyncPin1,HIGH); 
  }
  if (dac2Active) {
    digitalWrite(LDACPin2,HIGH);
    if (playing[4]) {
      digitalWrite(SyncPin2,LOW);
      dacBuffer[0] = 3;
      dacBuffer[1] = dacValue.byteArray[9];
      dacBuffer[2] = dacValue.byteArray[8];
      SPI.transfer(dacBuffer,3);
      digitalWrite(SyncPin2,HIGH);
    }
    if (playing[5]) {
      digitalWrite(SyncPin2,LOW);
      dacBuffer[0] = 2;
      dacBuffer[1] = dacValue.byteArray[11];
      dacBuffer[2] = dacValue.byteArray[10];
      SPI.transfer(dacBuffer,3);
      digitalWrite(SyncPin2,HIGH);
    }
    if (playing[6]) {
      digitalWrite(SyncPin2,LOW);
      dacBuffer[0] = 0;
      dacBuffer[1] = dacValue.byteArray[13];
      dacBuffer[2] = dacValue.byteArray[12];
      SPI.transfer(dacBuffer,3);
      digitalWrite(SyncPin2,HIGH);
    }
    if (playing[7]) {
      digitalWrite(SyncPin2,LOW);
      dacBuffer[0] = 1;
      dacBuffer[1] = dacValue.byteArray[15];
      dacBuffer[2] = dacValue.byteArray[14];
      SPI.transfer(dacBuffer,3);
      digitalWrite(SyncPin2,HIGH); 
    }
    digitalWrite(LDACPin2,LOW);
  }
  digitalWrite(LDACPin1,LOW); 
}

void zeroDAC() {
  // Set DAC to resting voltage on all channels
  for (int i = 0; i < nChannels; i++) {
    dacValue.uint16[i] = DACBits_ZeroVolts;
    playing[i] = true; // Temporarily set all channels to play-enable, so they get updated
  }
  dacWrite(); // Update the DAC, to set all channels to mid-range (0V)
  for (int i = 0; i < nChannels; i++) {
    playing[i] = false;
  }
}

void triggerChannel(byte channel, byte waveIndex) {
      waveLoaded[channel] = waveIndex; 
      currentSample[channel] = 0;
      channelTime[channel] = 0;
      countdown2Play[channel] = 2;
      currentBuffer[channel] = 1;
      bufferPos[channel] = 0;
      preBufferActive[channel] = true;
      filePos[channel] = (maxWaveSizeBytes*waveIndex) + bufSizeBytes;
}
void triggerChannelMaster(byte channel, byte waveIndex) { // In Master mode, swap waveforms immediately (no countdown2Play)
      waveLoaded[channel] = waveIndex; 
      currentSample[channel] = 0;
      channelTime[channel] = 0;
      playing[channel] = true;
      loadFlag[channel] = 1;
      currentBuffer[channel] = 1;
      bufferPos[channel] = 0;
      preBufferActive[channel] = true;
      filePos[channel] = (maxWaveSizeBytes*waveIndex) + bufSizeBytes;
}
void resetChannel(byte channel) { // Resets playback to first sample (in loop mode)
      currentSample[channel] = 0;
      currentBuffer[channel] = 1;
      bufferPos[channel] = 0;
      loadFlag[channel] = 1;
      preBufferActive[channel] = true;
      filePos[channel] = (maxWaveSizeBytes*waveLoaded[channel]) + bufSizeBytes;
}
void returnModuleInfo() {
  Serial1COM.writeByte(65); // Acknowledge
  Serial1COM.writeUint32(FirmwareVersion); // 4-byte firmware version
  Serial1COM.writeByte(sizeof(moduleName)-1); // Length of module name
  Serial1COM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  Serial1COM.writeByte(0); // 1 if more info follows, 0 if not
}
