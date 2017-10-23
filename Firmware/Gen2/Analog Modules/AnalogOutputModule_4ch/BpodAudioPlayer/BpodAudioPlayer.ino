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
char moduleName[] = "AudioPlayer"; // Name of module for manual override UI and state machine assembler

// Parameters
const byte maxWaves = 64; // Maximum number of waveforms (used to set up data buffers and to ensure data file is large enough)
const uint32_t bufSize = 1280; // Buffer size (in samples). Larger buffers prevent underruns, but take up memory.
                                    // Each wave in MaxWaves is allocated 1 buffer worth of sRAM (Teensy 3.6 total sRAM = 256k)
const uint32_t maxWaveSize = 1000000; // Maximum number of samples per waveform
const uint16_t maxEnvelopeSize = 10000; // Maximum size of AM onset/offset envelope (in samples)
const uint32_t maxSamplingRate = 96000;

union {
    byte byteArray[4];
    float floatVal;
} timerPeriod; // Default hardware timer period during playback, in microseconds (100 = 10kHz). Set as a Union so it can be read as bytes.
float timerPeriod_Idle = 20; // Default hardware timer period while idle (no playback, awaiting commands; determines playback latency)

// Pin definitions
const byte RefEnable = 32; // External 3V reference enable pin
const byte SyncPin=14; // AD5754 Pin 7 (Sync)
const byte LDACPin=39; // AD5754 Pin 10 (LDAC)

// System objects
SPISettings DACSettings(30000000, MSBFIRST, SPI_MODE2); // Settings for DAC
IntervalTimer hardwareTimer; // Hardware timer to create even sampling
File Wave0; // File on microSD card, to store waveform data

// Playback variables
byte opCode = 0; // Serial inputs access an op menu. The op code byte stores the intended operation.
byte opSource = 0; // 0 = op from USB, 1 = op from UART1, 2 = op from UART2. More op code menu options are exposed for USB.
boolean newOpCode = 0; // true if an opCode was read from one of the ports
byte inByte = 0; // General purpose byte for Serial read
byte BpodMessage = 0; // Stores the current message byte to send to the Bpod State Machine (playback start/stop event, bits indicate channels)
byte triggerMode = 0; // Triggers during playback are: 0 = ignored (default) 1 = handled (new waveform starts)  2 = stop playback
unsigned long currentPlaySample = 0; // Current position in waveform
byte iWavePlaying = 0; // Index of waveform currently being played
boolean playing = false; // True if playing a waveform
boolean loading2SD = false; // True if loading from USB -> microsd
boolean playingLastCycle = false; // True if playback was active on the previous hardware timer callback (for resetting timer to idle refresh rate)
boolean schedulePlaybackStop = 0; // Reminds the program to set playing = false after next DAC update
boolean sendBpodEvents = false; // Sends a byte to Bpod state machine, to indicate playback start and stop.
byte loopMode = 0; // (for each channel) Loops waveform until loopDuration seconds
uint32_t loopDuration = 0; // Duration of loop for loop mode (in samples)
uint32_t channelTime = 0; // Time (in samples) since loop was triggered (used to compute looped playback end)
byte waveIndex = 0; // Index of current waveform used for local op (1-maxWaves; maxWaves is in the "parameters" section above) Note: iWavePlaying = current playback waveform
byte wave2Play = 0; // Index of waveform being triggered (before playback begins)
byte channelIndex = 0; // Index of current output channel (1-4)
const uint32_t maxWaveSizeBytes = maxWaveSize*4; // Maximum size of a stereo waveform in bytes (maxWaveSize is in the "parameters" section above)
const int bufSizeBytes = bufSize*2; // Size of the buffer in bytes (bufSizeBytes is in the "parameters" section above)
byte currentPlayBuffer = 0; // Current buffer for each channel (a double buffering scheme allows one to be filled while the other is read)
uint32_t bufferSideBOffset = maxWaves*maxWaveSizeBytes; // Offset of first sample of sound 1 in buffer B on microSD card (computed at setup)
boolean newWaveLoaded[maxWaves] = {false}; // True if a new sound was loaded; on next trial start signal, currentLoadBuffer is swapped.
boolean loadFlag = false; // Set true when the buffer switches, to trigger filling of the empty buffer
int playBufferPos = 0; // Position of current sample in the current data buffer
uint32_t playbackFilePos = 0; // Position of current sample in the data file being played from microSD -> DAC
uint32_t loadingFilePos = 0; // Position of current sample in the data file being loaded from USB -> microSD
byte preBuffer[maxWaves][bufSizeBytes] = {0}; // The first buffer worth of each waveform is stored here on load, to achieve super-low latency playback.
boolean preBufferActive = 1; // Playback begins from the pre-buffer
uint16_t DACBits_ZeroVolts = 32768; // Code (in bits) for 0V.
uint32_t nPreBufferBytesLoaded = 0; // Number of pre-buffer samples loaded
byte countdown2Play = 0; // Set to 2 if a channel has been triggered, and needs to begin playback in 2 cycles. Set to 1 on next cycle, etc.
                                      // This ensures that a cycle burdened with serial reads and triggering logic does not also update the channel voltage.
                                      // The phenotype, if too few cycles are skipped, is a short first sample. 
uint32_t nBytesLoaded2SD = 0; // During load, number of bytes loaded to the SD card
boolean preBufferLoaded = false; // During load, whether the sound's RAM pre-buffer has been loaded
byte waveLoading = 0; // During load, index of waveform being loaded
byte bufLoading = 0; // During load, load-buffer side of waveform being loaded
uint32_t nBytes2LoadThisCycle = 0; // During load, the number of bytes to read from USB and write to microSD this cycle
// Waveform metadata
boolean isStereo[maxWaves] = {false}; // True if stereo, false if mono
byte nBytesPerSample[maxWaves] = {2}; // Number of bytes per sample; 2 if mono, 4 if stereo
uint32_t nWaveformBytes[maxWaves] = {0}; //Number of bytes in each waveform
uint32_t nSamples[maxWaves] = {0}; // Number of samples in each waveform

// AM onset/offset envelope
boolean useAMEnvelope = false; // True if using AM envelope on sound start/stop
boolean inEnvelope = false; // True while playing the envelope, false during remaining playback samples
boolean inFadeOut = false; // True if playback has been stopped, and envelope is playing in reverse (i.e. Fade-out)
uint16_t envelopeSize = maxEnvelopeSize;
uint16_t envelopePos = 0; // Current position in envelope
boolean envelopeDir = 0; // Current envelope playback direction 0 = forward (for sound onset), 1 = reverse (for sound offset)
union { // Floating point amplitude in range 1 (max intensity) -> 0 (silent). Data in forward direction.
    byte byteArray[maxEnvelopeSize*4];
    float floatArray[maxEnvelopeSize];
} AMenvelope; // Default hardware timer period during playback, in microseconds (100 = 10kHz). Set as a Union so it can be read as bytes.
int16_t CurrentSampleAmplitude = 0; // Stores difference between current sample and 0V
byte skipLoading = 0;
// Communication variables
const int BpodSerialBaudRate = 1312500; // Communication rate for Bpod UART channel
byte dacBuffer[3] = {0}; // Holds bytes to be written to the DAC
union {
    byte byteArray[4];
    uint16_t uint16[2];
} dacValue; // 16-Bit code of current sample on DAC output channels. A union type allows instant conversion between bytes and 16-bit ints
union {
    byte byteArray[2];
    uint16_t uint16[1];
} sdSample;
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} BufferA; // channel1BufferA and channel1BufferB form a double-buffer - one buffer fills while the other drives the DAC
union {
    byte byteArray[bufSizeBytes];
    uint16_t uint16[bufSize];
} BufferB; 

boolean USBDataReady = false;
uint32_t fbPos= 0;
boolean setSMBaud = false;

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
  pinMode(RefEnable, OUTPUT); // Reference enable pin sets the external reference IC output to 3V (RefEnable=high) or high impedence (RefEnable = low)
  digitalWrite(RefEnable, LOW); // Disabling external reference IC allows other voltage ranges with DAC internal reference
  pinMode(SyncPin, OUTPUT); // Configure SPI bus pins as outputs
  pinMode(LDACPin, OUTPUT);
  SPI.begin(); // Initialize SPI interface
  SPI.beginTransaction(DACSettings); // Set SPI parameters to DAC speed and bit order
  digitalWrite(LDACPin, LOW); // Ensure DAC load pin is at default level (low)
  ProgramDAC(16, 0, 31); // Power up all channels + internal ref)
  ProgramDAC(12, 0, 3); // Set output range to +/- 5V
  zeroDAC(); // Set all DAC channels to 0V
  SD.begin(); // Initialize microSD card
  timerPeriod.floatVal = 22.675737; // Set a default sampling rate (44.1kHz)
  hardwareTimer.begin(handler, timerPeriod.floatVal); // hardwareTimer is an interval timer object - Teensy 3.6's hardware timer
  Wave0 = SD.open("Wave0.wfm", FILE_WRITE);
}

void loop() { // loop runs in parallel with hardware timer, at lower interrupt priority. Its function is to fill playback buffers from the microSD card.
  if (playing && loadFlag) {
    loadFlag = false;
    Wave0.seek(playbackFilePos);
    if (currentPlayBuffer == 1) {
      Wave0.read(BufferA.byteArray, bufSizeBytes);
    } else {
      Wave0.read(BufferB.byteArray, bufSizeBytes);
    }
    playbackFilePos += bufSizeBytes;
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
  } else if (USBCOM.available()) {
    if (!loading2SD) {
      opCode = USBCOM.readByte();
      opSource = 0; // USB
      newOpCode = true;
    }
  }
  if (newOpCode) { // If an op byte arrived from one of the serial interfaces
    newOpCode = false;
    switch(opCode) {
      case 229: // Handshake
        if (opSource == 0) {
          USBCOM.writeByte(230); // Unique reply-byte
          USBCOM.writeUint32(FirmwareVersion); // Send firmware version
        }
        for (int i = 0; i < maxWaves; i++) { // Clear meta-data for loaded sounds
            newWaveLoaded[i] = false;
            nSamples[i] = 0;
        }
      break;
      case 255: // Return Bpod module info
        if (opSource == 1) { // Only returns this info if requested from state machine device
          returnModuleInfo();
        }
      break;
      case 'N': // Return playback params
        if (opSource == 0){
          USBCOM.writeByte(0); // 0 = Standard mode (this file), 1 = Live mode (BpodAudioPlayer_Live firmware)
          USBCOM.writeUint16(maxWaves);
          USBCOM.writeUint16(maxEnvelopeSize);
          USBCOM.writeUint32(maxSamplingRate);
          USBCOM.writeByte(triggerMode);
          USBCOM.writeByteArray(timerPeriod.byteArray, 4);
          USBCOM.writeByte(sendBpodEvents);
          USBCOM.writeByte(loopMode);
          USBCOM.writeUint32(loopDuration);
        }
      break;
      case 'O': // Set loop mode and duration (for each channel)
      if (opSource == 0){
          loopMode = USBCOM.readByte();
          loopDuration = USBCOM.readUint32();
        USBCOM.writeByte(1); // Acknowledge
      }
      break;
      case 'V': // Set Bpod event reporting (for each channel)
      if (opSource == 0){
        sendBpodEvents = USBCOM.readByte();
        USBCOM.writeByte(1); // Acknowledge
      }
      break;
      case 'E': // Use/disuse AM envelope
        useAMEnvelope = USBCOM.readByte();
        USBCOM.writeByte(1); // Acknowledge
        envelopePos = 0;
        envelopeDir = 0;
      break;
      case '*': // Swap load buffer sides for newly loaded sounds (see AudioPlayerLive firmware)
        if (opSource == 0) {
          USBCOM.writeByte(1); // Acknowledge
        }
      break;
      case 'M': // Load AM envelope
          envelopeSize = USBCOM.readUint16();
          if (envelopeSize <= maxEnvelopeSize) {
            USBCOM.readByteArray(AMenvelope.byteArray, envelopeSize*4);
            USBCOM.writeByte(1); // Acknowledge
          } else {
            USBCOM.writeByte(0); // Acknowledge
          }
      break;
      case 'T': // Set trigger mode
        if (opSource == 0){
           triggerMode = USBCOM.readByte(); 
           USBCOM.writeByte(1); // Acknowledge
        }
      break;
      case 'Y': // Create and/or Clear data file on microSD card, with enough space to store all waveforms (to be optimized for speed)
        if (opSource == 0) {
          for (int i = 0; i < fileTransferBufferSize; i++) {
            fileTransferBuffer[i] = 0;
          }
          Wave0.close();
          Wave0 = SD.open("Wave0.wfm", FILE_WRITE);
          Wave0.seek(0); // Set write position to first byte
          for (unsigned long longInd = 0; longInd < (bufferSideBOffset)/fileTransferBufferSize; longInd++) {
            Wave0.write(fileTransferBuffer,fileTransferBufferSize); // Write fileTransferBufferSize zeros
          }
          Wave0.close();
          USBCOM.writeByte(1); // Acknowledge
        }
      break;
      case 'L': // Load sound
        if (opSource == 0) {
          waveIndex = USBCOM.readByte();
          if (waveIndex < maxWaves) { // Sanity check
            isStereo[waveIndex] = USBCOM.readByte();
            nSamples[waveIndex] = USBCOM.readUint32();
            nBytesPerSample[waveIndex] = 2+(isStereo[waveIndex]*2);
            nWaveformBytes[waveIndex] = nSamples[waveIndex]*nBytesPerSample[waveIndex];
            Wave0.seek(maxWaveSizeBytes*waveIndex);
            nFullReads = (unsigned long)(floor((double)nWaveformBytes[waveIndex]/(double)fileTransferBufferSize));
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
            partialReadSize = (nWaveformBytes[waveIndex])-(nFullReads*fileTransferBufferSize);
            if (partialReadSize > 0) {
              Serial.readBytes((char*)fileTransferBuffer,partialReadSize);
              Wave0.write(fileTransferBuffer,partialReadSize);
              if (nFullReads == 0) {
                if ((nWaveformBytes[waveIndex]) > bufSizeBytes) {
                  for (int j = 0; j < bufSizeBytes; j++) {
                      preBuffer[waveIndex][j] = fileTransferBuffer[j];
                  }
                } else {
                  for (int j = 0; j < nWaveformBytes[waveIndex]; j++) {
                    preBuffer[waveIndex][j] = fileTransferBuffer[j];
                  }  
                }
              }
            }         
            USBCOM.writeByte(1); Serial.send_now();
            newWaveLoaded[waveIndex] = true;
          }
        }
      break;
      case 'P': // Play a waveform
          switch(opSource) {
            case 0:
              wave2Play = USBCOM.readByte();
            break;
            case 1:
              wave2Play = Serial1COM.readByte();
            break;
            case 2:
              wave2Play = Serial2COM.readByte();
            break;
          }
          envelopeDir = 0;
          startEnvelope();
          BpodMessage = 0;
          switch(triggerMode) {
            case 0: // Normal mode: Trigger only if not already playing
              if (!playing) {
                startPlayback(wave2Play);
                if (sendBpodEvents) {
                  BpodMessage = wave2Play+1; 
                }
              }
            break;
            case 1: // Master Mode: Trigger even if already playing
              startPlaybackMaster(wave2Play);
              if (sendBpodEvents) {
                BpodMessage = wave2Play+1; 
              }
            break;
            case 2:  // Toggle mode: Trigger stops channel if playing
              if (playing) {
                if (useAMEnvelope) {
                  inFadeOut = true;
                  envelopeDir = 1;
                  startEnvelope();
                } else {
                  schedulePlaybackStop = true;
                }
              } else {
                startPlayback(wave2Play);
              }
              if (sendBpodEvents) {
                 BpodMessage = wave2Play+1; 
              }
            break;
          }
          if (BpodMessage > 0) {
            Serial1COM.writeByte(BpodMessage); 
          }
      break;
      case 'X': // Stop all playback
        if (useAMEnvelope) {
          inFadeOut = true;
          envelopeDir = 1;
          startEnvelope();
        } else {
          zeroDAC();
        }
      break;    
      case 'S':
      if (opSource == 0) {
        USBCOM.readByteArray(timerPeriod.byteArray, 4);
        hardwareTimer.end();
        hardwareTimer.begin(handler, timerPeriod.floatVal);
      }
      break;
    }
  }
  if (playing) {
    if (preBufferActive) {
      dacValue.uint16[0] = word(preBuffer[iWavePlaying][playBufferPos+1], preBuffer[iWavePlaying][playBufferPos]);
      if (isStereo[iWavePlaying]) { 
        dacValue.uint16[1] = word(preBuffer[iWavePlaying][playBufferPos+3], preBuffer[iWavePlaying][playBufferPos+2]);
      } else {
        dacValue.uint16[1] = word(preBuffer[iWavePlaying][playBufferPos+1], preBuffer[iWavePlaying][playBufferPos]);
      }
    } else {
      if (currentPlayBuffer == 0) {
          dacValue.uint16[0] = BufferA.uint16[playBufferPos];
        if (isStereo[iWavePlaying]) { 
          dacValue.uint16[1] = BufferA.uint16[playBufferPos+1];
        } else {
          dacValue.uint16[1] = BufferA.uint16[playBufferPos];
        }
      } else {
        dacValue.uint16[0] = BufferB.uint16[playBufferPos];
        if (isStereo[iWavePlaying]) { 
          dacValue.uint16[1] = BufferB.uint16[playBufferPos+1];
        } else {
          dacValue.uint16[1] = BufferB.uint16[playBufferPos];
        }
      } 
    }
    if (preBufferActive) {
      if (isStereo[iWavePlaying]) { 
        playBufferPos += 4;
      } else {
        playBufferPos += 2;
      }
      if (playBufferPos >= bufSizeBytes) {
        preBufferActive = false;
        currentPlayBuffer = 1-currentPlayBuffer;
        playBufferPos = 0;
        loadFlag = true;
      }
    } else {
      if (isStereo[iWavePlaying]) { 
        playBufferPos += 2;
      } else {
        playBufferPos++;
      }
      if (playBufferPos >= bufSize) {
        currentPlayBuffer = 1-currentPlayBuffer;
        playBufferPos = 0;
        loadFlag = true;
      }
    }
 
    if (useAMEnvelope) {
      if (inEnvelope) {
        for (int i = 0; i < 2; i++) {
          CurrentSampleAmplitude = dacValue.uint16[i] - DACBits_ZeroVolts;
          if (envelopeDir == 0) {
            dacValue.uint16[i] = DACBits_ZeroVolts + ((float)CurrentSampleAmplitude*AMenvelope.floatArray[envelopePos]);
          } else {
            dacValue.uint16[i] = DACBits_ZeroVolts + ((float)CurrentSampleAmplitude*AMenvelope.floatArray[envelopeSize-envelopePos-1]);
          }
        }
        envelopePos++;
        if (envelopePos == envelopeSize) {
          inEnvelope = false;
          if (inFadeOut) {
            inFadeOut = false;
            schedulePlaybackStop = true;
          }
        }
      }
    }
    currentPlaySample++;
    channelTime++;
    if (currentPlaySample > nSamples[iWavePlaying]) {
      if (loopMode) {
        resetChannel();
      } else {
        schedulePlaybackStop = true;
        playbackFilePos = (maxWaveSizeBytes*iWavePlaying);
        dacValue.uint16[0] = DACBits_ZeroVolts;
        dacValue.uint16[1] = DACBits_ZeroVolts;
      }
    } else {
      if ((useAMEnvelope) && (!inFadeOut) && (!loopMode)) {
        if (currentPlaySample > nSamples[iWavePlaying] - envelopeSize - 1) {
          inFadeOut = true;
          envelopeDir = 1;
          startEnvelope();
        }
      }
    }
    if (loopMode) {
      if (channelTime > loopDuration) {
        schedulePlaybackStop = true;
        playbackFilePos = (maxWaveSizeBytes*iWavePlaying);
      }
    }
    if (schedulePlaybackStop) {
      dacValue.uint16[0] = DACBits_ZeroVolts;
      dacValue.uint16[1] = DACBits_ZeroVolts;
      inFadeOut = false;
    }
  }
  if (playing) {
    if (playingLastCycle == false) {
        hardwareTimer.end();
        hardwareTimer.begin(handler, timerPeriod.floatVal);
    }
    dacWrite();
    BpodMessage = 0;
    if (schedulePlaybackStop) {
      playing = false;
      schedulePlaybackStop = false;
      if (sendBpodEvents) {
        BpodMessage = iWavePlaying+1; 
      }
    }
    if (countdown2Play) {
      countdown2Play = false;
      playing = true;
      skipLoading = 2;
    }
    if (BpodMessage > 0) {
      Serial1COM.writeByte(BpodMessage);    
    }
    playingLastCycle = true;
  } else {
    if (playingLastCycle) {
      playingLastCycle = false;
      hardwareTimer.end();
      hardwareTimer.begin(handler, timerPeriod_Idle);
    }
    if (countdown2Play == 1) {
      countdown2Play = 0;
      playing = true;
      loadFlag = true;
    }
    if (countdown2Play == 2) {
      countdown2Play = 1;
    }
  }
}

void ProgramDAC(byte Data1, byte Data2, byte Data3) {
  digitalWrite(LDACPin,HIGH);
  digitalWrite(SyncPin,LOW);
  SPI.transfer (Data1);
  SPI.transfer (Data2);
  SPI.transfer (Data3);
  digitalWrite(SyncPin,HIGH);
  digitalWrite(LDACPin,LOW);
}

void dacWrite() {
  if (playing) {
    digitalWrite(LDACPin,HIGH);
    digitalWrite(SyncPin,LOW);
    dacBuffer[0] = 3;
    dacBuffer[1] = dacValue.byteArray[1];
    dacBuffer[2] = dacValue.byteArray[0];
    SPI.transfer(dacBuffer,3);
    digitalWrite(SyncPin,HIGH);
    digitalWrite(SyncPin,LOW);
    dacBuffer[0] = 2;
    dacBuffer[1] = dacValue.byteArray[3];
    dacBuffer[2] = dacValue.byteArray[2];
    SPI.transfer(dacBuffer,3);
    digitalWrite(SyncPin,HIGH);
    digitalWrite(LDACPin,LOW);
  }
}

void zeroDAC() {
  // Set DAC to resting voltage
  dacValue.uint16[0] = DACBits_ZeroVolts;
  dacValue.uint16[1] = DACBits_ZeroVolts;
  playing = true; // Temporarily set all channels to play-enable, so they get updated
  dacWrite(); // Update the DAC, to set all channels to mid-range (0V)
  playing = false;
}

void startPlayback(byte thisWave) {
    iWavePlaying = thisWave; 
    currentPlaySample = 0;
    channelTime = 0;
    countdown2Play = 2;
    currentPlayBuffer = 1;
    playBufferPos = 0;
    envelopePos = 0;
    inFadeOut = false;
    inEnvelope = false;
    preBufferActive = true;
    playbackFilePos = (maxWaveSizeBytes*thisWave) + bufSizeBytes;
}
void startPlaybackMaster(byte thisWave) { // In Master mode, swap waveforms immediately (no countdown2Play)
    iWavePlaying = thisWave; 
    currentPlaySample = 0;
    channelTime = 0;
    inFadeOut = false;
    inEnvelope = false;
    playing = true;
    loadFlag = 1;
    currentPlayBuffer = 1;
    playBufferPos = 0;
    preBufferActive = true;
    playbackFilePos = (maxWaveSizeBytes*thisWave) + bufSizeBytes;
}
void resetChannel() { // Resets playback to first sample (in loop mode)
    currentPlaySample = 0;
    currentPlayBuffer = 1;
    playBufferPos = 0;
    loadFlag = 1;
    preBufferActive = true;
    playbackFilePos = (maxWaveSizeBytes*iWavePlaying) + bufSizeBytes;
}
void startEnvelope() {
  if (useAMEnvelope) {
    inEnvelope = true;
    envelopePos = 0;
  }
}
void returnModuleInfo() {
  Serial1COM.writeByte(65); // Acknowledge
  Serial1COM.writeUint32(FirmwareVersion); // 4-byte firmware version
  Serial1COM.writeByte(sizeof(moduleName)-1); // Length of module name
  Serial1COM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  Serial1COM.writeByte(1); // 1 if more info follows, 0 if not
  Serial1COM.writeByte('#'); // Op code for: Number of behavior events this module can generate
  Serial1COM.writeByte(maxWaves);
  Serial1COM.writeByte(0); // 1 if more info follows, 0 if not
}
