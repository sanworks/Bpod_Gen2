/*
----------------------------------------------------------------------------

This file is part of the Pulse Pal Project
Copyright (C) 2017 Joshua I. Sanders, Sanworks LLC, NY, USA

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

// PulseGenerator firmware for Bpod Analog Output Module
// Derived from Pulse Pal firmware v2.0.1
// Josh Sanders, January 2017
//
// ** DEPENDENCIES YOU NEED TO INSTALL FIRST **

// 1. This firmware uses the sdFat beta library, developed by Bill Greiman. (Thanks Bill!!)
// Download it from here: https://github.com/greiman/SdFat-beta/tree/master/SdFat
// and copy it to your /Arduino/Libraries folder.
// 2. This firmware requires Teensyduino. Download and install from here:
// https://www.pjrc.com/teensy/teensyduino.html

// ** Next, upload the firmware to the Bpod analog output module **

#include "ArCOM.h"
#include <SPI.h>
#include "SdFat.h"
SdFatSdioEX SD;
#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256

#define FirmwareVersion 1

// Module setup
char moduleName[] = "PulsePal"; // Name of module for manual override UI and state machine assembler
byte CycleDuration = 100; // in microseconds, time between hardware cycles (each cycle = read trigger channels, update output channels)
const byte nChannels = 4;

// Create an ArCOM USB serial port object (to streamline transfer of different datatypes and arrays over serial)
ArCOM PPUSB(Serial);
ArCOM Serial1COM(Serial3); // Creates an ArCOM object called Serial1COM, wrapping Serial3
ArCOM Serial2COM(Serial2);

// Pin definitions
const byte RefEnable = 32; // External 3V reference enable pin
const byte SyncPin=14; // AD5754 Pin 7 (Sync)
const byte LDACPin=39; // AD5754 Pin 10 (LDAC)

// System objects
SPISettings DACSettings(30000000, MSBFIRST, SPI_MODE2); // Settings for DAC
IntervalTimer hardwareTimer; // Hardware timer to ensure even sampling

// Parameters that define pulse trains currently loaded on the 4 output channels
// For a visual description of these parameters, see https://sites.google.com/site/pulsepalwiki/parameter-guide
// The following parameters are times in microseconds:
unsigned long Phase1Duration[nChannels] = {0}; // Pulse Duration in monophasic mode, first phase in biphasic mode
unsigned long InterPhaseInterval[nChannels] = {0}; // Interval between phases in biphasic mode (at resting voltage)
unsigned long Phase2Duration[nChannels] = {0}; // Second phase duration in biphasic mode
unsigned long InterPulseInterval[nChannels] = {0}; // Interval between pulses
unsigned long BurstDuration[nChannels] = {0}; // Duration of sequential bursts of pulses (0 if not using bursts)
unsigned long BurstInterval[nChannels] = {0}; // Interval between sequential bursts of pulses (0 if not using bursts)
unsigned long PulseTrainDuration[nChannels] = {0}; // Duration of pulse train
unsigned long PulseTrainDelay[nChannels] = {0}; // Delay between trigger and pulse train onset
// The following are volts in bits. 16 bits span -10V to +10V.
uint16_t Phase1Voltage[nChannels] = {0}; // The pulse voltage in monophasic mode, and phase 1 voltage in biphasic mode
uint16_t Phase2Voltage[nChannels] = {0}; // Phase 2 voltage in biphasic mode.
uint16_t RestingVoltage[nChannels] = {32768}; // Voltage the system returns to between pulses (32768 bits = 0V)
// The following are single byte parameters
byte CustomTrainID[nChannels] = {0}; // If 0, uses above params. If 1 or 2, pulse times and voltages are played back from CustomTrain1 or 2
byte CustomTrainTarget[nChannels] = {0}; // If 0, custom times define start-times of pulses. If 1, custom times are start-times of bursts.
byte CustomTrainLoop[nChannels] = {0}; // if 0, custom stim plays once. If 1, custom stim loops until PulseTrainDuration.
byte TriggerMode[2] = {0}; // if 0, "Normal mode", low to high transitions on trigger channels start stimulation (but do not cancel it) 
//                            if 1, "Toggle mode", same as normal mode, but low-to-high transitions do cancel ongoing pulse trains

// Variables used in programming
byte OpMenuByte = 213; // This byte must be the first byte in any serial transmission to Pulse Pal. Reduces the probability of interference from port-scanning software
unsigned long CustomTrainNpulses[4] = {0}; // Stores the total number of pulses in the custom pulse train
byte BrokenBytes[4] = {0}; // Used to store sequential bytes when converting bytes to short and long ints

// Variables used in stimulus playback
byte inByte; byte inByte2; byte inByte3; byte inByte4; byte CommandByte;
byte LogicLevel = 0;
unsigned long SystemTime = 0; // Number of cycles since stimulation start
unsigned long MicrosTime = 0; // Actual system time (microseconds from boot, wraps over every 72m
unsigned long BurstTimestamps[nChannels] = {0};
unsigned long PrePulseTrainTimestamps[nChannels] = {0};
unsigned long PulseTrainTimestamps[nChannels] = {0};
unsigned long NextPulseTransitionTime[nChannels] = {0}; // Stores next pulse-high or pulse-low timestamp for each channel
unsigned long NextBurstTransitionTime[nChannels] = {0}; // Stores next burst-on or burst-off timestamp for each channel
unsigned long PulseTrainEndTime[nChannels] = {0}; // Stores time the stimulus train is supposed to end
unsigned long CustomPulseTimes[4][10001] = {0};
uint16_t CustomVoltages[4][10001] = {0};
int CustomPulseTimeIndex[nChannels] = {0}; // Keeps track of the pulse number of the custom train currently being played on each channel
unsigned long LastLoopTime = 0;
byte PulseStatus[nChannels] = {0}; // This is 0 if not delivering a pulse, 1 if phase 1, 2 if inter phase interval, 3 if phase 2.
boolean BurstStatus[nChannels] = {0}; // This is "true" during bursts and false during inter-burst intervals.
boolean StimulusStatus[nChannels] = {0}; // This is "true" for a channel when the stimulus train is actively being delivered
boolean PreStimulusStatus[nChannels] = {0}; // This is "true" for a channel during the pre-stimulus delay
boolean UsesBursts[nChannels] = {0};
unsigned long PulseDuration[nChannels] = {0}; // Duration of a pulse (sum of 3 phases for biphasic pulse)
byte IsBiphasic[nChannels] = {0};
boolean IsCustomBurstTrain[nChannels] = {0};
byte ContinuousLoopMode[nChannels] = {0}; // If true, the channel loops its programmed stimulus train continuously
byte StimulatingState = 0; // 1 if ANY channel is stimulating, 2 if this is the first cycle after the system was triggered. 
byte LastStimulatingState = 0;
boolean WasStimulating = 0; // true if any channel was stimulating on the previous loop. Used to force a DAC write after all channels end their stimulation, to return lines to 0
int nStimulatingChannels = 0; // number of actively stimulating channels
boolean DACFlag = 0; // true if any DAC channel needs to be updated
byte DefaultInputLevel = 0; // 0 for PulsePal 0.3, 1 for 0.2 and 0.1. Logic is inverted by optoisolator

// Other variables
int ConnectedToApp = 0; // 0 if disconnected, 1 if connected
void handler(void);
boolean SoftTriggered[nChannels] = {0}; // If a software trigger occurred this cycle (for timing reasons, it is scheduled to occur on the next cycle)
boolean SoftTriggerScheduled[nChannels] = {0}; // If a software trigger is scheduled for the next cycle
unsigned long callbackStartTime = 0;
byte maxCommandByte = 0;
byte dacBuffer[3] = {0};
uint16_t DACBits_ZeroVolts = 32768;
union {
    byte byteArray[8];
    uint16_t uint16[4];
} dacValue;
union {
    byte byteArray[4];
    float floatVal;
} timerPeriod; // Default hardware timer period during playback, in microseconds (100 = 10kHz). Set as a Union so it can be read as bytes.

void setup() {
  pinMode(RefEnable, OUTPUT); // Reference enable pin sets the external reference IC output to 3V (RefEnable=high) or high impedence (RefEnable = low)
  digitalWrite(RefEnable, LOW); // Disabling external reference IC allows other voltage ranges with DAC internal reference
  pinMode(SyncPin, OUTPUT); // Configure SPI bus pins as outputs
  pinMode(LDACPin, OUTPUT);
  SPI.begin(); // Initialize SPI interface
  SPI.beginTransaction(DACSettings); // Set SPI parameters to DAC speed and bit order
  digitalWrite(LDACPin, LOW); // Ensure DAC load pin is at default level (low)
  ProgramDAC(16, 0, 31); // Power up all channels + internal ref)
  ProgramDAC(12, 0, 4); // Set output range to +/- 10V
  zeroDAC(); // Set all DAC channels to 0V
  Serial2.begin(1312500);
  Serial3.begin(1312500);
  SD.begin(); // Initialize microSD card
  LoadDefaultParameters();
  maxCommandByte = pow(2,nChannels); // Except for module code 255, command bytes above this are ignored
  SystemTime = 0;
  LastLoopTime = SystemTime;
  timerPeriod.floatVal = CycleDuration; // Set a default sampling rate (10kHz)
  hardwareTimer.begin(handler, timerPeriod.floatVal); // hardwareTimer is an interval timer object - Teensy 3.6's hardware timer
}

void loop() {

}

void handler(void) {                     
  if (StimulatingState == 0) {
      if (LastStimulatingState == 1) { // The cycle on which all pulse trains have finished
        dacWrite(); // Update DAC to final voltages (should be resting voltage)
        DACFlag = 0;
      }
   } else {
//     if (StimulatingState == 2) {
//                // Place to include code that executes on the first cycle of a pulse train
//     }
       StimulatingState = 1;
       if (DACFlag == 1) { // A DAC update was requested
         dacWrite(); // Update DAC
         DACFlag = 0;
       }
       SystemTime++; // Increment system time (# of hardware timer cycles since stim start)
    }
    for (int i = 0; i<nChannels; i++) {
      if(SoftTriggerScheduled[i]) { // Soft triggers are "scheduled" to be handled on the next cycle, since the serial read took too much time.
        SoftTriggered[i] = 1;
        SoftTriggerScheduled[i] = 0;
      }
    }
    LastStimulatingState = StimulatingState;
  if (Serial1COM.available()) {
     CommandByte = Serial1COM.readByte(); // Read a byte
     switch(CommandByte) {
        case 255: // Code to return module info
          returnModuleInfo();
        break;
        default: // Soft-trigger specific output channels. Which channels are indicated as bits of a single byte read.
          if (CommandByte < maxCommandByte) {
            for (int i = 0; i < nChannels; i++) {
              if (((StimulusStatus[i] == 1) || (PreStimulusStatus[i] == 1))) {
                if (TriggerMode[0] == 1) {
                  killChannel(i);
                }
              } else {
                SoftTriggerScheduled[i] = bitRead(CommandByte, i); 
              }
            }
          }
        break;
     }
  }
  if (PPUSB.available()) { // If bytes are available in the serial port buffer
    CommandByte = PPUSB.readByte(); // Read a byte
    if (CommandByte == OpMenuByte) { // The first byte must be 213. Now, read the actual command byte. (Reduces interference from port scanning applications)
      CommandByte = PPUSB.readByte(); // Read the command byte (an op code for the operation to execute)
      switch (CommandByte) {
        case 72: { // Handshake
          PPUSB.writeByte(75); // Send 'K' (as in ok)
          PPUSB.writeUint32(FirmwareVersion); // Send the firmware version as a 4 byte unsigned integer
          ConnectedToApp = 1;
        } break;
        case 73: { // Program the module - total program (can be faster than item-wise, if many parameters have changed)
          PPUSB.readUint32Array(Phase1Duration, nChannels);
          PPUSB.readUint32Array(InterPhaseInterval, nChannels);
          PPUSB.readUint32Array(Phase2Duration, nChannels);
          PPUSB.readUint32Array(InterPulseInterval, nChannels);
          PPUSB.readUint32Array(BurstDuration, nChannels);
          PPUSB.readUint32Array(BurstInterval, nChannels);
          PPUSB.readUint32Array(PulseTrainDuration, nChannels);
          PPUSB.readUint32Array(PulseTrainDelay, nChannels);
          PPUSB.readUint16Array(Phase1Voltage, nChannels);
          PPUSB.readUint16Array(Phase2Voltage, nChannels);
          PPUSB.readUint16Array(RestingVoltage, nChannels);
          PPUSB.readByteArray(IsBiphasic, nChannels);
          PPUSB.readByteArray(CustomTrainID, nChannels);
          PPUSB.readByteArray(CustomTrainTarget, nChannels);
          PPUSB.readByteArray(CustomTrainLoop, nChannels);
         PPUSB.readByteArray(TriggerMode, 1);
         PPUSB.writeByte(1); // Send confirm byte
         for (int x = 0; x < nChannels; x++) {
           if ((BurstDuration[x] == 0) || (BurstInterval[x] == 0)) {UsesBursts[x] = false;} else {UsesBursts[x] = true;}
           if (CustomTrainTarget[x] == 1) {UsesBursts[x] = true;}
           if ((CustomTrainID[x] > 0) && (CustomTrainTarget[x] == 0)) {UsesBursts[x] = false;}
           PulseDuration[x] = ComputePulseDuration(IsBiphasic[x], Phase1Duration[x], InterPhaseInterval[x], Phase2Duration[x]);
           if ((CustomTrainID[x] > 0) && (CustomTrainTarget[x] == 1)) {
            IsCustomBurstTrain[x] = 1;
           } else {
            IsCustomBurstTrain[x] = 0;
           }
           dacValue.uint16[x] = RestingVoltage[x];
         }
         dacWrite();
        } break;
        
        case 74: { // Program one parameter, one channel
          inByte2 = PPUSB.readByte();
          inByte3 = PPUSB.readByte(); // inByte3 = target channels (1-4)
          inByte3 = inByte3 - 1; // Convert channel for zero-indexing
          switch (inByte2) { 
             case 1: {IsBiphasic[inByte3] = PPUSB.readByte();} break;
             case 2: {Phase1Voltage[inByte3] = PPUSB.readUint16();} break;
             case 3: {Phase2Voltage[inByte3] = PPUSB.readUint16();} break;
             case 4: {Phase1Duration[inByte3] = PPUSB.readUint32();} break;
             case 5: {InterPhaseInterval[inByte3] = PPUSB.readUint32();} break;
             case 6: {Phase2Duration[inByte3] = PPUSB.readUint32();} break;
             case 7: {InterPulseInterval[inByte3] = PPUSB.readUint32();} break;
             case 8: {BurstDuration[inByte3] = PPUSB.readUint32();} break;
             case 9: {BurstInterval[inByte3] = PPUSB.readUint32();} break;
             case 10: {PulseTrainDuration[inByte3] = PPUSB.readUint32();} break;
             case 11: {PulseTrainDelay[inByte3] = PPUSB.readUint32();} break;
             case 14: {CustomTrainID[inByte3] = PPUSB.readByte();} break;
             case 15: {CustomTrainTarget[inByte3] = PPUSB.readByte();} break;
             case 16: {CustomTrainLoop[inByte3] = PPUSB.readByte();} break;
             case 17: {RestingVoltage[inByte3] = PPUSB.readUint16();} break;
             case 128: {TriggerMode[inByte3] = PPUSB.readByte();} break;
          }
          if (inByte2 < 14) {
            if ((BurstDuration[inByte3] == 0) || (BurstInterval[inByte3] == 0)) {UsesBursts[inByte3] = false;} else {UsesBursts[inByte3] = true;}
            if (CustomTrainTarget[inByte3] == 1) {UsesBursts[inByte3] = true;}
            if ((CustomTrainID[inByte3] > 0) && (CustomTrainTarget[inByte3] == 0)) {UsesBursts[inByte3] = false;}
          }
          if (inByte2 == 17) {
            dacValue.uint16[inByte3] = RestingVoltage[inByte3];
            dacWrite();
          }
          PulseDuration[inByte3] = ComputePulseDuration(IsBiphasic[inByte3], Phase1Duration[inByte3], InterPhaseInterval[inByte3], Phase2Duration[inByte3]);
          if ((CustomTrainID[inByte3] > 0) && (CustomTrainTarget[inByte3] == 1)) {
            IsCustomBurstTrain[inByte3] = 1;
          } else {
            IsCustomBurstTrain[inByte3] = 0;
          }
          PPUSB.writeByte(1); // Send confirm byte
        } break;
  
        case 75: { // Program custom pulse train
          inByte2 = PPUSB.readByte(); // train Index
          CustomTrainNpulses[inByte2] = PPUSB.readUint32();
          for (int x = 0; x < CustomTrainNpulses[inByte2]; x++) {
            CustomPulseTimes[inByte2][x] = PPUSB.readUint32();
          }
          for (int x = 0; x < CustomTrainNpulses[inByte2]; x++) {
            CustomVoltages[inByte2][x] = PPUSB.readUint16();
          }
          PPUSB.writeByte(1); // Send confirm byte
        } break;     
        
        case 77: { // Soft-trigger specific output channels. Which channels are indicated as bits of a single byte read.
          inByte2 = PPUSB.readByte();
          for (int i = 0; i < nChannels; i++) {
            if (((StimulusStatus[i] == 1) || (PreStimulusStatus[i] == 1))) {
              if (TriggerMode[0] == 1) {
                killChannel(i);
              }
            } else {
              SoftTriggerScheduled[i] = bitRead(inByte2, i); 
            }
          }
        } break;
        case 79: { // Write specific voltage to an output channel (not a pulse train) 
          byte myChannel = PPUSB.readByte();
          myChannel = myChannel - 1; // Convert for zero-indexing
          uint16_t val = PPUSB.readUint16();
          dacValue.uint16[myChannel] = val;
          dacWrite();
          PPUSB.writeByte(1); // Send confirm byte
        } break;
        case 80: { // Soft-abort ongoing stimulation without disconnecting from client
         for (int i = 0; i < nChannels; i++) {
          killChannel(i);
        }
        dacWrite();
       } break;
       case 81: { // Disconnect from client
          ConnectedToApp = 0;
          for (int i = 0; i < nChannels; i++) {
            killChannel(i);
          }
          dacWrite();
         } break;
        case 82:{ // Set Continuous Loop mode (play the current parametric pulse train indefinitely)
          inByte2 = PPUSB.readByte(); // State (0 = off, 1 = on)
          inByte3 = PPUSB.readByte(); // Channel
          ContinuousLoopMode[inByte3] = inByte2;
          if (inByte2) {
            SoftTriggerScheduled[inByte3] = 1;
          } else {
            killChannel(inByte3);
          }
          dacWrite();
          PPUSB.writeByte(1);
        } break;
        case 86: { // Override Arduino IO Lines (for development and debugging only - may disrupt normal function)
          inByte2 = PPUSB.readByte();
          inByte3 = PPUSB.readByte();
          pinMode(inByte2, OUTPUT); digitalWrite(inByte2, inByte3);
        } break; 
        
        case 87: { // Direct Read IO Lines (for development and debugging only - may disrupt normal function)
          inByte2 = PPUSB.readByte();
          pinMode(inByte2, INPUT);
          delayMicroseconds(10);
          LogicLevel = digitalRead(inByte2);
          PPUSB.writeByte(LogicLevel);
        } break; 
        case 91: { // Program a parameter on all 4 channels
          inByte2 = PPUSB.readByte();
          switch (inByte2) { 
             case 1: {PPUSB.readByteArray(IsBiphasic, nChannels);} break;
             case 2: {PPUSB.readUint16Array(Phase1Voltage, nChannels);} break;
             case 3: {PPUSB.readUint16Array(Phase2Voltage, nChannels);} break;
             case 4: {PPUSB.readUint32Array(Phase1Duration,nChannels);} break;
             case 5: {PPUSB.readUint32Array(InterPhaseInterval,nChannels);} break;
             case 6: {PPUSB.readUint32Array(Phase2Duration, nChannels);} break;
             case 7: {PPUSB.readUint32Array(InterPulseInterval, nChannels);} break;
             case 8: {PPUSB.readUint32Array(BurstDuration, nChannels);} break;
             case 9: {PPUSB.readUint32Array(BurstInterval, nChannels);} break;
             case 10: {PPUSB.readUint32Array(PulseTrainDuration, nChannels);} break;
             case 11: {PPUSB.readUint32Array(PulseTrainDelay, nChannels);} break;
             case 14: {PPUSB.readByteArray(CustomTrainID, nChannels);} break;
             case 15: {PPUSB.readByteArray(CustomTrainTarget, nChannels);} break;
             case 16: {PPUSB.readByteArray(CustomTrainLoop, nChannels);} break;
             case 17: {PPUSB.readUint16Array(RestingVoltage, nChannels);} break;
             case 128: {PPUSB.readByteArray(TriggerMode, 2);} break;
          }
          for (int iChan = 0; iChan < nChannels; iChan++) {
            if (inByte2 < 14) {
              if ((BurstDuration[iChan] == 0) || (BurstInterval[iChan] == 0)) {UsesBursts[iChan] = false;} else {UsesBursts[iChan] = true;}
              if (CustomTrainTarget[iChan] == 1) {UsesBursts[iChan] = true;}
              if ((CustomTrainID[iChan] > 0) && (CustomTrainTarget[iChan] == 0)) {UsesBursts[iChan] = false;}
            }
            if (inByte2 == 17) {
              dacValue.uint16[iChan] = RestingVoltage[iChan];
              dacWrite();
            }
            if (inByte2 == 18) {
              if (ContinuousLoopMode[iChan]) {
                SoftTriggerScheduled[iChan] = 1;
              } else {
                killChannel(iChan);
              }
            }
            PulseDuration[iChan] = ComputePulseDuration(IsBiphasic[iChan], Phase1Duration[iChan], InterPhaseInterval[iChan], Phase2Duration[iChan]);
            if ((CustomTrainID[iChan] > 0) && (CustomTrainTarget[iChan] == 1)) {
              IsCustomBurstTrain[iChan] = 1;
            } else {
              IsCustomBurstTrain[iChan] = 0;
            }
          }
          PPUSB.writeByte(1); // Send confirm byte
          dacWrite();
        } break;
        case 92: {
          sendCurrentParams();
        } break;
        case 95: {
          PPUSB.writeByte(nChannels);
        } break;
      }
     }
    } // End if PPUSB.available()
       
    for (int x = 0; x < nChannels; x++) {
      byte KillChannel = 0;
       // If trigger channels are in toggle mode and a trigger arrived, or in gated mode and line is low, shut down any governed channels that are playing a pulse train
       if (((StimulusStatus[x] == 1) || (PreStimulusStatus[x] == 1))) {
        // Cancel playback if trigger arrived in toggle mode
        
      } else {
       // Adjust StimulusStatus to reflect any new trigger events
       if (SoftTriggered[x]) {
         if (StimulatingState == 0) {SystemTime = 0; StimulatingState = 2;}
         PreStimulusStatus[x] = 1; BurstStatus[x] = 1; PrePulseTrainTimestamps[x] = SystemTime; PulseStatus[x] = 0; 
         SoftTriggered[x] = 0;
       }
      }
    }
    if (StimulatingState != 2) {
     StimulatingState = 0; // null condition, will be overridden in loop if any channels are still stimulating.
    }
    // Check clock and adjust line levels for new time as per programming
    for (int x = 0; x < nChannels; x++) {
      byte thisTrainID = CustomTrainID[x];
      byte thisTrainIDIndex = thisTrainID-1;
      if (PreStimulusStatus[x] == 1) {
          if (StimulatingState != 2) {
           StimulatingState = 1;
          }
        if (SystemTime == (PrePulseTrainTimestamps[x] + PulseTrainDelay[x])) {
          PreStimulusStatus[x] = 0;
          StimulusStatus[x] = 1;
          PulseStatus[x] = 0;
          PulseTrainTimestamps[x] = SystemTime;
          PulseTrainEndTime[x] = SystemTime + PulseTrainDuration[x];
          if (CustomTrainTarget[x] > 0)  {
              NextBurstTransitionTime[x] = SystemTime + CustomPulseTimes[thisTrainIDIndex][0];
              BurstStatus[x] = 0;
          } else {
            NextBurstTransitionTime[x] = SystemTime+BurstDuration[x];
          }
          if (CustomTrainID[x] == 0) {
            NextPulseTransitionTime[x] = SystemTime;
            dacValue.uint16[x] = Phase1Voltage[x]; DACFlag = 1;
          } else {
            NextPulseTransitionTime[x] = SystemTime + CustomPulseTimes[thisTrainIDIndex][0]; 
            CustomPulseTimeIndex[x] = 0;
          }
        }
      }
      if (StimulusStatus[x] == 1) { // if this output line has been triggered and is delivering a pulse train
          if (StimulatingState != 2) {
           StimulatingState = 1; 
          }
        if (BurstStatus[x] == 1) { // if this output line is currently gated "on"
          switch (PulseStatus[x]) { // depending on the phase of the pulse
           case 0: { // if this is the inter-pulse interval
            // determine if the next pulse should start now
            if ((CustomTrainID[x] == 0) || ((CustomTrainID[x] > 0) && (CustomTrainTarget[x] == 1))) {
              if (SystemTime == NextPulseTransitionTime[x]) {
                NextPulseTransitionTime[x] = SystemTime + Phase1Duration[x];
                    if (!((UsesBursts[x] == 1) && (NextPulseTransitionTime[x] >= NextBurstTransitionTime[x]))){ // so that it doesn't start a pulse it can't finish due to burst end
                      PulseStatus[x] = 1;
                      if ((CustomTrainID[x] > 0) && (CustomTrainTarget[x] == 1)) {
                        dacValue.uint16[x] = CustomVoltages[thisTrainIDIndex][CustomPulseTimeIndex[x]]; DACFlag = 1;
                      } else {
                        dacValue.uint16[x] = Phase1Voltage[x]; DACFlag = 1;
                      }
                    }
                 }
              } else {
               if (SystemTime == NextPulseTransitionTime[x]) {
                     int SkipNextInterval = 0;
                     if ((CustomTrainLoop[x] == 1) && (CustomPulseTimeIndex[x] == CustomTrainNpulses[thisTrainIDIndex])) {
                            CustomPulseTimeIndex[x] = 0;
                            PulseTrainTimestamps[x] = SystemTime;
                     }
                     if (CustomPulseTimeIndex[x] < CustomTrainNpulses[thisTrainIDIndex]) {
                       if ((CustomPulseTimes[thisTrainIDIndex][CustomPulseTimeIndex[x]+1] - CustomPulseTimes[thisTrainIDIndex][CustomPulseTimeIndex[x]]) > Phase1Duration[x]) {
                         NextPulseTransitionTime[x] = SystemTime + Phase1Duration[x];
                       } else {
                         NextPulseTransitionTime[x] = PulseTrainTimestamps[x] + CustomPulseTimes[thisTrainIDIndex][CustomPulseTimeIndex[x]+1];  
                         SkipNextInterval = 1;
                       }
                     }
                     if (SkipNextInterval == 0) {
                        PulseStatus[x] = 1;
                     }
                     dacValue.uint16[x] = CustomVoltages[thisTrainIDIndex][CustomPulseTimeIndex[x]]; DACFlag = 1;
                     if (IsBiphasic[x] == 0) {
                        CustomPulseTimeIndex[x] = CustomPulseTimeIndex[x] + 1;
                     }
                     if (CustomPulseTimeIndex[x] > (CustomTrainNpulses[thisTrainIDIndex])){
                       CustomPulseTimeIndex[x] = 0;
                       if (CustomTrainLoop[x] == 0) {
                         killChannel(x);
                       }
                     }
                  }
              } 
            } break;
            
            case 1: { // if this is the first phase of the pulse
             // determine if this phase should end now
             if (SystemTime == NextPulseTransitionTime[x]) {
                if (IsBiphasic[x] == 0) {
                  if (CustomTrainID[x] == 0) {
                      NextPulseTransitionTime[x] = SystemTime + InterPulseInterval[x];
                      PulseStatus[x] = 0;
                      dacValue.uint16[x] = RestingVoltage[x]; DACFlag = 1;
                  } else {
                    if (CustomTrainTarget[x] == 0) {
                      NextPulseTransitionTime[x] = PulseTrainTimestamps[x] + CustomPulseTimes[thisTrainIDIndex][CustomPulseTimeIndex[x]];
                    } else {
                      NextPulseTransitionTime[x] = SystemTime + InterPulseInterval[x];
                    }
                    if (CustomPulseTimeIndex[x] == CustomTrainNpulses[thisTrainIDIndex]) {
                      if (CustomTrainLoop[x] == 1) {
                          CustomPulseTimeIndex[x] = 0;
                          PulseTrainTimestamps[x] = SystemTime;
                          dacValue.uint16[x] = CustomVoltages[thisTrainIDIndex][CustomPulseTimeIndex[x]]; DACFlag = 1;
                          if ((CustomPulseTimes[thisTrainIDIndex][CustomPulseTimeIndex[x]+1] - CustomPulseTimes[thisTrainIDIndex][CustomPulseTimeIndex[x]]) > Phase1Duration[x]) {
                            PulseStatus[x] = 1;
                          } else {
                            PulseStatus[x] = 0;
                          }
                          NextPulseTransitionTime[x] = PulseTrainTimestamps[x] + Phase1Duration[x];
                          CustomPulseTimeIndex[x] = CustomPulseTimeIndex[x] + 1;
                      } else {
                        killChannel(x);
                      }
                    } else {
                      PulseStatus[x] = 0;
                      dacValue.uint16[x] = RestingVoltage[x]; DACFlag = 1;
                    }
                  }
     
                } else {
                  if (InterPhaseInterval[x] == 0) {
                    NextPulseTransitionTime[x] = SystemTime + Phase2Duration[x];
                    PulseStatus[x] = 3;
                    if (CustomTrainID[x] == 0) {
                      dacValue.uint16[x] = Phase2Voltage[x]; DACFlag = 1;
                    } else {
                     if (CustomVoltages[thisTrainIDIndex][CustomPulseTimeIndex[x]] < 32768) {
                       dacValue.uint16[x] = 32768 + (32768 - CustomVoltages[thisTrainIDIndex][CustomPulseTimeIndex[x]]); DACFlag = 1;
                     } else {
                       dacValue.uint16[x] = 32768 - (CustomVoltages[thisTrainIDIndex][CustomPulseTimeIndex[x]] - 32768); DACFlag = 1;
                     }
                     if (CustomTrainTarget[x] == 0) {
                         CustomPulseTimeIndex[x] = CustomPulseTimeIndex[x] + 1;
                     }
                    } 
                  } else {
                    NextPulseTransitionTime[x] = SystemTime + InterPhaseInterval[x];
                    PulseStatus[x] = 2;
                    dacValue.uint16[x] = RestingVoltage[x]; DACFlag = 1;
                  }
                }
              }
            } break;
            case 2: {
               if (SystemTime == NextPulseTransitionTime[x]) {
                 NextPulseTransitionTime[x] = SystemTime + Phase2Duration[x];
                 PulseStatus[x] = 3;
                 if (CustomTrainID[x] == 0) {
                   dacValue.uint16[x] = Phase2Voltage[x]; DACFlag = 1;
                 } else {
                   if (CustomVoltages[thisTrainIDIndex][CustomPulseTimeIndex[x]] < 32768) {
                       dacValue.uint16[x] = 32768 + (32768 - CustomVoltages[thisTrainIDIndex][CustomPulseTimeIndex[x]]); DACFlag = 1;
                     } else {
                       dacValue.uint16[x] = 32768 - (CustomVoltages[thisTrainIDIndex][CustomPulseTimeIndex[x]] - 32768); DACFlag = 1;
                   }
                   if (CustomTrainTarget[x] == 0) {
                       CustomPulseTimeIndex[x] = CustomPulseTimeIndex[x] + 1;
                   }
                 }
               }
            } break;
            case 3: {
              if (SystemTime == NextPulseTransitionTime[x]) {
                  if (CustomTrainID[x] == 0) {
                      NextPulseTransitionTime[x] = SystemTime + InterPulseInterval[x];
                  } else {
                    if (CustomTrainTarget[x] == 0) {
                      NextPulseTransitionTime[x] = PulseTrainTimestamps[x] + CustomPulseTimes[thisTrainIDIndex][CustomPulseTimeIndex[x]];
                      if (CustomPulseTimeIndex[x] == (CustomTrainNpulses[thisTrainIDIndex])){
                          killChannel(x);
                     }
                    } else {
                      NextPulseTransitionTime[x] = SystemTime + InterPulseInterval[x];
                    } 
                  }   
                 if (!((CustomTrainID[x] == 0) && (InterPulseInterval[x] == 0))) { 
                   PulseStatus[x] = 0;
                   dacValue.uint16[x] = RestingVoltage[x]; DACFlag = 1;
                 } else {
                   PulseStatus[x] = 1;
                   NextPulseTransitionTime[x] = (NextPulseTransitionTime[x] - InterPulseInterval[x]) + (Phase1Duration[x]);
                   dacValue.uint16[x] = Phase1Voltage[x]; DACFlag = 1;
                 }
               }
            } break;
            
          }
        }
          // Determine if burst status should go to 0 now
       if (UsesBursts[x] == true) {
        if (SystemTime == NextBurstTransitionTime[x]) {
          if (BurstStatus[x] == 1) {
            if (CustomTrainID[x] == 0) {
                     NextPulseTransitionTime[x] = SystemTime + BurstInterval[x];
                     NextBurstTransitionTime[x] = SystemTime + BurstInterval[x];              
            } else if (CustomTrainTarget[x] == 1) {
              CustomPulseTimeIndex[x] = CustomPulseTimeIndex[x] + 1;
              if (CustomTrainID[x] > 0) {
                 if (CustomPulseTimeIndex[x] == (CustomTrainNpulses[thisTrainIDIndex])){
                     killChannel(x);
                 }
                 NextPulseTransitionTime[x] = PulseTrainTimestamps[x] + CustomPulseTimes[thisTrainIDIndex][CustomPulseTimeIndex[x]];
                 NextBurstTransitionTime[x] = NextPulseTransitionTime[x];
              }
            }
              BurstStatus[x] = 0;
              dacValue.uint16[x] = RestingVoltage[x]; DACFlag = 1;
          } else {
          // Determine if burst status should go to 1 now
            NextBurstTransitionTime[x] = SystemTime + BurstDuration[x];
            NextPulseTransitionTime[x] = SystemTime + Phase1Duration[x];
            PulseStatus[x] = 1;
            if ((CustomTrainID[x] > 0) && (CustomTrainTarget[x] == 1)) {
              if (CustomPulseTimeIndex[x] < CustomTrainNpulses[thisTrainIDIndex]){
                 dacValue.uint16[x] = CustomVoltages[thisTrainIDIndex][CustomPulseTimeIndex[x]]; DACFlag = 1;
              }       
            } else {
                 dacValue.uint16[x] = Phase1Voltage[x]; DACFlag = 1;
            }
            BurstStatus[x] = 1;
         }
        }
       } 
        // Determine if Stimulus Status should go to 0 now
        if ((SystemTime == PulseTrainEndTime[x]) && (StimulusStatus[x] == 1)) {
          if (((CustomTrainID[x] > 0) && (CustomTrainLoop[x] == 1)) || (CustomTrainID[x] == 0)) {
            if (ContinuousLoopMode[x] == false) {
                killChannel(x);
            }
          }
        }
     }
   }
}
// End main loop

byte* Long2Bytes(long LongInt2Break) {
  byte Output[4] = {0};
  return Output;
}


void killChannel(byte outputChannel) {
  CustomPulseTimeIndex[outputChannel] = 0;
  PreStimulusStatus[outputChannel] = 0;
  StimulusStatus[outputChannel] = 0;
  PulseStatus[outputChannel] = 0;
  BurstStatus[outputChannel] = 0;
  dacValue.uint16[outputChannel] = RestingVoltage[outputChannel]; DACFlag = 1;
}


void dacWrite() {
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
  digitalWrite(SyncPin,LOW);
  dacBuffer[0] = 0;
  dacBuffer[1] = dacValue.byteArray[5];
  dacBuffer[2] = dacValue.byteArray[4];
  SPI.transfer(dacBuffer,3);
  digitalWrite(SyncPin,HIGH);
  digitalWrite(SyncPin,LOW);
  dacBuffer[0] = 1;
  dacBuffer[1] = dacValue.byteArray[7];
  dacBuffer[2] = dacValue.byteArray[6];
  SPI.transfer(dacBuffer,3);
  digitalWrite(SyncPin,HIGH); 
  digitalWrite(LDACPin,LOW);
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

void LoadDefaultParameters() {
  // This function is called on boot if the EEPROM has an invalid program (or no program).
  for (int x = 0; x < nChannels; x++) {
      Phase1Duration[x] = 10;
      InterPhaseInterval[x] = 10;
      Phase2Duration[x] = 10;
      InterPulseInterval[x] = 90;
      BurstDuration[x] = 0;
      BurstInterval[x] = 0;
      PulseTrainDuration[x] = 10000;
      PulseTrainDelay[x] = 0;
      IsBiphasic[x] = 0;
      Phase1Voltage[x] = 49152;
      Phase2Voltage[x] = 16384;
      RestingVoltage[x] = 32768;
      CustomTrainID[x] = 0;
      CustomTrainTarget[x] = 0;
      CustomTrainLoop[x] = 0;
      UsesBursts[x] = 0;
    }
   TriggerMode[0] = 0; 
}

void AbortAllPulseTrains() {
    for (int x = 0; x < nChannels; x++) {
      killChannel(x);
    }
    dacWrite();
}

unsigned long ComputePulseDuration(byte myBiphasic, unsigned long myPhase1, unsigned long myPhaseInterval, unsigned long myPhase2) {
    unsigned long Duration = 0;
    if (myBiphasic == 0) {
       Duration = myPhase1;
     } else {
       Duration = myPhase1 + myPhaseInterval + myPhase2;
     }
     return Duration;
}

void sendCurrentParams() {
    PPUSB.writeUint32Array(Phase1Duration, nChannels);
    PPUSB.writeUint32Array(InterPhaseInterval, nChannels);
    PPUSB.writeUint32Array(Phase2Duration, nChannels);
    PPUSB.writeUint32Array(InterPulseInterval, nChannels);
    PPUSB.writeUint32Array(BurstDuration, nChannels);
    PPUSB.writeUint32Array(BurstInterval, nChannels);
    PPUSB.writeUint32Array(PulseTrainDuration, nChannels);
    PPUSB.writeUint32Array(PulseTrainDelay, nChannels);
    PPUSB.writeUint16Array(Phase1Voltage, nChannels);
    PPUSB.writeUint16Array(Phase2Voltage, nChannels);
    PPUSB.writeUint16Array(RestingVoltage, nChannels);
    PPUSB.writeByteArray(IsBiphasic, nChannels);
    PPUSB.writeByteArray(CustomTrainID, nChannels);
    PPUSB.writeByteArray(CustomTrainTarget, nChannels);
    PPUSB.writeByteArray(CustomTrainLoop, nChannels);
    PPUSB.writeByteArray(TriggerMode, 1);
}

void zeroDAC() {
  // Set DAC to resting voltage on all channels
  for (int i = 0; i < nChannels; i++) {
    dacValue.uint16[i] = DACBits_ZeroVolts;
  }
  dacWrite(); // Update the DAC, to set all channels to mid-range (0V)
}

void returnModuleInfo() {
  Serial1COM.writeByte(65); // Acknowledge
  Serial1COM.writeUint32(FirmwareVersion); // 4-byte firmware version
  Serial1COM.writeByte(sizeof(moduleName)-1); // Length of module name
  Serial1COM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  Serial1COM.writeByte(0); // 1 if more info follows, 0 if not
}
