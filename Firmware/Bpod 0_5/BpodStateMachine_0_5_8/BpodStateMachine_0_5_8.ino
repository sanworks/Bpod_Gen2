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
// Bpod State Machine v 0.5.8
// SYSTEM SETUP:
//
// IF COMPILING FOR Arduino DUE, Requires the DueTimer library from:
// https://github.com/ivanseidel/DueTimer
// Also requires a small modification to Arduino, for useful PWM control of light intensity with small (1-10ms) pulses:
// change the PWM_FREQUENCY and TC_FREQUENCY constants to 50000 in the file /Arduino/hardware/arduino/sam/variants/arduino_due_x/variant.h
// or in Windows, \Users\Username\AppData\Local\Arduino15\packages\arduino\hardware\sam\1.6.7\variants\arduino_due_x\variant.h
//
// IF COMPILING FOR TEENSY 3.6, Requires modifications to Teensy core files:
// In the folder /arduino-1.8.X/hardware/teensy/avr/cores/teensy3, modify the following line in each of the 5 files listed below:
// #define SERIAL1_RX_BUFFER_SIZE 64  --> #define SERIAL1_RX_BUFFER_SIZE 256
// IN FILES: serial1.c, serial2.c, serial3.c, serial4.c, serial5.c
//


// Set device type and version
#define MachineType 1 // 1 = Bpod 0.5-0.8, 2 = Pocket State Machine
#define FirmwareVersion 5

// Set universal board parameters
#define useStatusLED 1 // Set to 0 to disable the board's red/green/blue status LED

// Set board-specific parameters
#if MachineType == 1
  #include "DueTimer.h"
#endif
#include <SPI.h>
#include "ArCOM.h" // ArCOM is a serial interface wrapper developed by Sanworks, to streamline transmission of datatypes and arrays over serial
#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256
#if MachineType == 1
  ArCOM USBCOM(SerialUSB); // Creates an ArCOM object called USBCOM, wrapping SerialUSB
  ArCOM Serial1COM(Serial1); // Creates an ArCOM object called Serial1COM, wrapping Serial1
  ArCOM Serial2COM(Serial2); 
  ArCOM Serial3COM(Serial3); 
#else
  ArCOM USBCOM(Serial); // Creates an ArCOM object called USBCOM, wrapping Serial (for Teensy 3.6)
  ArCOM Serial1COM(Serial1); // Creates an ArCOM object called Serial1COM, wrapping Serial1
  ArCOM Serial2COM(Serial3); 
  ArCOM Serial3COM(Serial2); 
  ArCOM Serial4COM(Serial4); 
  ArCOM Serial5COM(Serial5); 
#endif

////////////////////////////////////////
// State machine hardware description  /
////////////////////////////////////////
// Two pairs of arrays describe the hardware as it appears to the state machine: inputHW / inputCh, and outputHW / outputCh.
// In these arrays, the first row codes for hardware type. U = UART, X = USB, S = SPI,  D = digital, B = BNC (digital/inverted), W = Wire (digital/inverted) 
// P = port (digital channel if input, PWM channel if output). Channels must be listed IN THIS ORDER (this constraint allows efficient code at runtime). 
// The digital,BNC or wire channel currently replaced by 'Y' is the sync channel.
// The second row lists the physical input and output channels on Arduino for B,W,P, and the SPI CS pin is listed for S. Use 0 for UART and USB.

#if MachineType == 1
  #if FirmwareVersion > 7
    byte InputHW[] = {'U','U','U','X','B','B','W','W','P','P','P','P','P','P','P','P'};
    byte InputCh[] = {0,0,0,0,10,11,31,29,28,30,32,34,36,38,40,42};                                         
    byte OutputHW[] = {'U','U','U','X','S','B','B','W','W','W','P','P','P','P','P','P','P','P'};
    byte OutputCh[] = {0,0,0,0,22,25,24,43,41,39,9,8,7,6,5,4,3,2};  
  #else
    byte InputHW[] = {'U','U','X','B','B','W','W','W','W','P','P','P','P','P','P','P','P'};
    byte InputCh[] = {0,0,0,11,10,35,33,31,29,28,30,32,34,36,38,40,42};                                         
    byte OutputHW[] = {'U','U','X','S','B','B','W','W','W','W','P','P','P','P','P','P','P','P'};
    byte OutputCh[] = {0,0,0,22,25,24,43,41,39,37,9,8,7,6,5,4,3,2};  
  #endif
#else
    byte InputHW[] = {'U','U','U','U','U','X','B','B'};
    byte InputCh[] = {0,0,0,0,0,0,16,17};                                         
    byte OutputHW[] = {'U','U','U','U','U','X','B','B'};
    byte OutputCh[] = {0,0,0,0,0,0,36,37};  
#endif

// State machine meta information
const byte nInputs = sizeof(InputHW);
const byte nOutputs = sizeof(OutputHW);
#if MachineType == 1 // Arduino Due-based state machines (Bpod 0.5-0.8)
  #if FirmwareVersion > 6
    const byte nSerialChannels = 4; // Must match total of 'U' and 'X' in InputHW (above)
    const byte maxSerialEvents = 60; // Must be a multiple of nSerialChannels
    const int MaxStates = 256;
    const int SerialBaudRate = 1312500;
  #else
    const byte nSerialChannels = 3;
    const byte maxSerialEvents = 30;
    const int MaxStates = 128;
    const int SerialBaudRate = 115200;
  #endif
#else // Teensy 3.6 based state machines (Pocket state machine)
    const byte nSerialChannels = 6; 
    const byte maxSerialEvents = 120;
    const int MaxStates = 256;
    const int SerialBaudRate = 1312500;
#endif
const byte nGlobalTimers = 5;
const byte nGlobalCounters = 5;
const byte nConditions = 5;
uint16_t timerPeriod = 100; // Hardware timer period, in microseconds (state machine refresh period)

////////////////////////////////////////////
                         
// Other hardware pin mapping
#if MachineType == 1
  #if FirmwareVersion > 5
    byte GreenLEDPin = 33;
  #else
    byte GreenLEDPin = 14;
  #endif
  byte RedLEDPin = 13;
  byte BlueLEDPin = 12;
#else
  byte GreenLEDPin = 30;
  byte RedLEDPin = 29;
  byte BlueLEDPin = 35;
#endif
byte fRAMcs = 1;
byte fRAMhold = A3;
byte SyncRegisterLatch = 23;

// Settings for version-specific hardware (initialized in setup)
boolean usesFRAM = false;
boolean usesSPISync = false;
boolean usesUARTInputs = false;
boolean isolatorHigh = 0;
boolean isolatorLow = 0;

// Bookmarks (positions of channel types in hardware description vectors, to be calculated in setup)
byte USBInputPos = 0;
byte BNCInputPos = 0;
byte WireInputPos = 0;
byte PortInputPos = 0;
byte USBOutputPos = 0;
byte SPIOutputPos = 0;
byte BNCOutputPos = 0;
byte WireOutputPos = 0;
byte PortOutputPos = 0;

// Parameters

const unsigned long ModuleIDTimeout = 100; // timeout for modules to respond to byte 255 (units = 100us cycles). Byte 255 polls for module hardware information

// Initialize system state vars: 
byte outputState[nOutputs] = {0}; // State of outputs
byte inputState[nInputs] = {0}; // Current state of inputs
byte lastInputState[nInputs] = {0}; // State of inputs on previous cycle
byte inputOverrideState[nInputs] = {0}; // Set to 1 if user created a virtual event, to prevent hardware reads until user returns low
byte outputOverrideState[nOutputs] = {0}; // Set to 1 when overriding a digital output line. This prevents state changes from affecting the line until it is manually reset.
byte inputEnabled[nInputs] = {0}; // 0 if input disabled, 1 if enabled
byte logicHigh[nInputs] = {0}; // 1 if standard, 0 if inverted input (calculated in setup for each channel, depending on its type)
byte logicLow[nInputs] = {0}; // Inverse of logicHigh (to save computation time)
const byte nDigitalInputs = nInputs - nSerialChannels; // Number of digital input channels
boolean MatrixFinished = false; // Has the system exited the matrix (final state)?
boolean MatrixAborted = false; // Has the user aborted the matrix before the final state?
boolean MeaningfulStateTimer = false; // Does this state's timer get us to another state when it expires?
int CurrentState = 1; // What state is the state machine currently in? (State 0 is the final state)
int NewState = 1;
const byte maxCurrentEvents = 10;
byte CurrentEvent[maxCurrentEvents] = {0}; // What event code just happened and needs to be handled. Up to 10 can be acquired per 100us loop.
byte nCurrentEvents = 0; // Index of current event
byte SoftEvent = 0; // What soft event code just happened
byte SyncChannel = 255; // 255 if no sync codes, <255 to specify a channel to use for sync
boolean syncOn = false; // If true, sync codes are sent on sync channel
byte SyncChannelHW = 0; // Stores physical pin for sync channel
byte NewSyncChannel = 0; // New digital output channel to use for Sync. (old channel gets reset to its original hardware type)
byte SyncMode = 0; // 0 if low > high on trial start and high < low on trial end, 1 if line toggles with each state change
byte SyncState = 0; // State of the sync line (0 = low, 1 = high)
boolean smaTransmissionConfirmed = false; // Set to true when the last state machine was successfully received, set to false when starting a transmission
boolean newSMATransmissionStarted = false; // Set to true when beginning a state machine transmission
boolean UARTrelayMode[nSerialChannels] = {false};
byte nModuleEvents[nSerialChannels] = {10}; // Stores number of behavior events assigned to each serial module (10 by default)

//////////////////////////////////
// Initialize general use vars:  /
//////////////////////////////////
byte CommandByte = 0;  // Op code to specify handling of an incoming USB serial message
byte VirtualEventTarget = 0; // Op code to specify which virtual event type (Port, BNC, etc)
byte VirtualEventData = 0; // State of target
byte Byte1 = 0; byte Byte2 = 0; byte Byte3 = 0; byte Byte4 = 0; // Temporary storage of values read from serial port
byte nPossibleEvents = 0; // possible events in the state machine (computed in setup)
int nStates = 0; // Total number of states in the current state machine
int nEvents = 0; // Total number of events recorded while running current state machine
int LEDBrightnessAdjustInterval = 5;
byte LEDBrightnessAdjustDirection = 1;
byte LEDBrightness = 0;
byte serialByteBuffer[4] = {0};
// State machine definitions. Each matrix relates each state to some inputs or outputs.
const byte InputMatrixSize = maxSerialEvents + nDigitalInputs*2;
byte actualInputMatrixSize = InputMatrixSize;
byte InputStateMatrix[MaxStates+1][InputMatrixSize] = {0}; // Matrix containing all of Bpod's digital inputs and corresponding state transitions
byte StateTimerMatrix[MaxStates+1] = {0}; // Matrix containing states to move to if the state timer elapses
const byte OutputMatrixSize = nOutputs + 3; // Extra 3 are: GlobalTimerTrigger, GlobalTimerCancel, GlobalCounterReset
byte OutputStateMatrix[MaxStates+1][OutputMatrixSize] = {0}; // Hardware states for outputs. Serial channels > Digital outputs > Virtual (global timer trigger, global timer cancel, global counter reset)
byte GlobalTimerStartMatrix[MaxStates+1][nGlobalTimers] = {0}; // Matrix contatining state transitions for global timer onset events
byte GlobalTimerEndMatrix[MaxStates+1][nGlobalTimers] = {0}; // Matrix contatining state transitions for global timer elapse events
byte GlobalCounterMatrix[MaxStates+1][nGlobalCounters] = {0}; // Matrix contatining state transitions for global counter threshold events
byte ConditionMatrix[MaxStates+1][nConditions] = {0}; // Matrix contatining state transitions for conditions
boolean GlobalTimersTriggered[nGlobalTimers] = {0}; // 0 if timer x was not yet triggered, 1 if it was triggered and had not elapsed.
boolean GlobalTimersActive[nGlobalTimers] = {0}; // 0 if timer x is inactive (e.g. not triggered, or during onset delay after trigger), 1 if it's active.
byte SerialMessageMatrix[MaxStates+1][nSerialChannels][3]; // Stores a 3-byte serial message for each message byte on each port
byte SerialMessage_nBytes[MaxStates+1][nSerialChannels] = {1}; // Stores the length of each serial message
boolean ModuleConnected[nSerialChannels] = {false}; // true for each channel if a module is connected, false otherwise
byte SyncChannelOriginalType = 0; // Stores sync channel's original hardware type
uint32_t PWMChannel[nOutputs] = {0}; // Stores ARM PWM channel for each PWM output pin (assigned in advance in setup, to speed PWM writes)

// Positions of input matrix parts
byte GlobalTimerStartPos = InputMatrixSize; // First global timer event code
byte GlobalTimerEndPos = GlobalTimerStartPos + nGlobalTimers;
byte GlobalCounterPos = GlobalTimerEndPos + nGlobalTimers; // First global counter event code
byte ConditionPos = GlobalCounterPos + nGlobalCounters; // First condition event code
byte JumpPos = ConditionPos+nConditions; // First Jump event code
byte TupPos = JumpPos+nSerialChannels; // State timeup event code
byte DigitalInputPos = maxSerialEvents;
byte GlobalTimerChannel[nGlobalTimers] = {254}; // Channel code for global timer onset/offset.
byte GlobalTimerOnMessage[nGlobalTimers] = {254}; // Message to send when global timer is active (if channel is serial).
byte GlobalTimerOffMessage[nGlobalTimers] = {254}; // Message to send when global timer elapses (if channel is serial).
unsigned long GlobalTimerStart[nGlobalTimers] = {0}; // Future Times when active global timers will start measuring time
unsigned long GlobalTimerEnd[nGlobalTimers] = {0}; // Future Times when active global timers will elapse
unsigned long GlobalTimers[nGlobalTimers] = {0}; // Timers independent of states
unsigned long GlobalTimerOnsetDelays[nGlobalTimers] = {0}; // Onset delay following global timer trigger
unsigned long GlobalCounterCounts[nGlobalCounters] = {0}; // Event counters
byte GlobalCounterAttachedEvents[nGlobalCounters] = {254}; // Event each event counter is attached to
unsigned long GlobalCounterThresholds[nGlobalCounters] = {0}; // Event counter thresholds (trigger events if crossed)
byte ConditionChannels[nConditions] = {254}; // Event each channel a condition is attached to
byte ConditionValues[nConditions] = {0}; // The value of each condition
const int MaxTimestamps = 10000;
#if FirmwareVersion < 7
  unsigned long Timestamps[MaxTimestamps] = {0};
#endif
unsigned long StateTimers[MaxStates+1] = {0}; // Timers for each state
unsigned long StartTime = 0; // System Start Time
unsigned long MatrixStartTime = 0; // Trial Start Time
unsigned long MatrixStartTimeMillis = 0; // Used for 32-bit timer wrap-over correction in client
unsigned long StateStartTime = 0; // Session Start Time
unsigned long NextLEDBrightnessAdjustTime = 0; // Used to fade blue light when disconnected
unsigned long CurrentTime = 0; // Current time (units = timer cycles since start; used to control state transitions)
unsigned long TimeFromStart = 0;
unsigned long SessionStartTime = 0;
boolean cycleMonitoring = 0; // if 1, measures time between hardware timer callbacks when state transitions occur
boolean getModuleInfo = false; // If retrieving module info
unsigned long nBytes = 0; // Number of bytes to read (when transmitting module info)
unsigned long CallbackStartTime = 0; // For self-monitoring to detect hardware timer overruns
unsigned long MeasuredCallbackDuration = 0; // For self-monitoring to detect hardware timer overruns
unsigned short MinCallbackDuration = 0; // Minimum time spent executing a timer callback in cycleMonitoring mode
unsigned short MaxCallbackDuration = 0; // Maximum time spent executing a timer callback in cycleMonitoring mode
unsigned long nCycles = 0; // Number of cycles measured since event X
byte connectionState = 0; // 1 if connected to MATLAB
byte RunningStateMatrix = 0; // 1 if state matrix is running
byte firstLoop= 0; // 1 if first timer callback in state matrix
int Ev = 0; // Index of current event
byte nOverrides = 0; // Number of overrides on a line of the state matrix (for compressed transmission scheme)
byte col = 0; byte val = 0; // col and val are used in compression scheme
byte UARTRelayBuffer[128] = {0}; // Stores bytes to be relayed to a module
union {
  byte Bytes[20];
  int32_t Uint32[5];
} TrialTimeStamps;
#if MachineType == 2
  IntervalTimer hardwareTimer;
#endif


void setup() {
// Resolve hardware peripherals from firmware version and state machine type
if (MachineType == 1) {
  if (FirmwareVersion > 7) {
    usesFRAM = true;
    usesSPISync = false;
    usesUARTInputs = true;
    isolatorHigh = 0;
    isolatorLow = 1;
  } else {
    usesFRAM = false;
    usesSPISync = true;
    usesUARTInputs = false;
    isolatorHigh = 1;
    isolatorLow = 0;
  }
} else if (MachineType == 2) {
    usesFRAM = false;
    usesSPISync = true;
    usesUARTInputs = true;
    isolatorHigh = 0;
    isolatorLow = 1;
}
// Find Bookmarks (positions of channel types in hardware description vectors)
for (int i = 0; i < nInputs; i++) {
  if ((InputHW[i] == 'X') && (USBInputPos == 0)) {
    USBInputPos = i;
  }
  if ((InputHW[i] == 'B') && (BNCInputPos == 0)) {
    BNCInputPos = i;
  }
  if ((InputHW[i] == 'W') && (WireInputPos == 0)) {
    WireInputPos = i;
  }
  if ((InputHW[i] == 'P') && (PortInputPos == 0)) {
    PortInputPos = i;
  }
}
for (int i = 0; i < nOutputs; i++) {
  if ((OutputHW[i] == 'X') && (USBOutputPos == 0)) {
    USBOutputPos = i;
  }
  if ((OutputHW[i] == 'S') && (SPIOutputPos == 0)) {
    SPIOutputPos = i;
  }
  if ((OutputHW[i] == 'B') && (BNCOutputPos == 0)) {
    BNCOutputPos = i;
  }
  if ((OutputHW[i] == 'W') && (WireOutputPos == 0)) {
    WireOutputPos = i;
  }
  if ((OutputHW[i] == 'P') && (PortOutputPos == 0)) {
    PortOutputPos = i;
  }
}  
  // Configure input channels
  Byte1 = 0;
  for (int i = 0; i < nInputs; i++) {
    switch (InputHW[i]) {
      case 'D':
        inputState[i] = 0;
        lastInputState[i] = 0;
        inputEnabled[i] = 1;
        logicHigh[i] = 1;
        logicLow[i] = 0;
      break;
      case 'B':
      case 'W':
        pinMode(InputCh[i], INPUT);
        inputEnabled[i] = 1;
        #if FirmwareVersion > 6
          inputState[i] = 1;
          lastInputState[i] = 1;
        #endif
        logicHigh[i] = isolatorHigh;
        logicLow[i] = isolatorLow;
      break; 
      case 'P':
        pinMode(InputCh[i], INPUT_PULLUP);
        logicHigh[i] = 1;
      break;  
      case 'U': 
          switch(Byte1) {
            case 0:
              Serial1.begin(SerialBaudRate); Byte1++;
            break;
            case 1:
              Serial2.begin(SerialBaudRate); Byte1++;
            break;
            case 2:
              Serial3.begin(SerialBaudRate); Byte1++;
            break;
            #if MachineType == 2
              case 3:
                Serial4.begin(SerialBaudRate); Byte1++;
              break;
              case 4:
                Serial5.begin(SerialBaudRate); Byte1++;
              break;
            #endif
          }
      break;
    }
  }
  resetSerialMessages();
  Byte1 = 0;
  // Configure digital output channels
  for (int i = 0; i < nOutputs; i++) {
    switch (OutputHW[i]) {
      case 'D':
      case 'B':
      case 'W':
      case 'S':
        pinMode(OutputCh[i], OUTPUT);
        digitalWrite(OutputCh[i], LOW);
      break;
      case 'P':
        pinMode(OutputCh[i], OUTPUT);
        analogWrite(OutputCh[i], 0);
        #if MachineType == 1
          PWMChannel[i] = g_APinDescription[OutputCh[i]].ulPWMChannel;
        #endif
      break;
    }
  }
  
  Byte1 = 0;
  pinMode(RedLEDPin, OUTPUT);
  pinMode(GreenLEDPin, OUTPUT);
  pinMode(BlueLEDPin, OUTPUT);
  if (usesFRAM) {
    pinMode(fRAMcs, OUTPUT); // CS pin for the fRAM IC
    pinMode(fRAMhold, OUTPUT); // Hold pin for the fRAM IC
    digitalWrite(fRAMcs, HIGH);
    digitalWrite(fRAMhold, HIGH);
  }
  if (usesSPISync) {
     pinMode(SyncRegisterLatch, OUTPUT); // CS pin for sync shift register IC
     digitalWrite(SyncRegisterLatch, LOW);
  }
  SPI.begin();
  updateStatusLED(0); // Begin the blue light display ("Disconnected" state)
  #if MachineType == 1
    Timer3.attachInterrupt(handler); // Timer3 is Arduino Due's hardware timer, which will trigger the function "handler" precisely every (timerPeriod) us
    Timer3.start(timerPeriod); // Start HW timer
  #else
    hardwareTimer.begin(handler, timerPeriod); // hardwareTimer is Teensy 3.6's hardware timer
  #endif
}

void loop() {
  if (!RunningStateMatrix) {
    relayModuleBytes();
  }
}

void handler() { // This is the timer handler function, which is called every (timerPeriod) us
  if (cycleMonitoring) {
    CallbackStartTime = micros();
  }
  if (connectionState == 0) {
    updateStatusLED(1);
  }
  if (getModuleInfo) { // If a request was sent for connected modules to return self description (request = byte 255)
    nCycles++; // Count cycles since request was sent
    if (nCycles > ModuleIDTimeout) { // If modules have had time to reply
      getModuleInfo = false; 
      relayModuleInfo(Serial1COM); // Function transmits 0 if no module replied, 1 if found, followed by length of description(bytes), then description
      relayModuleInfo(Serial2COM);
      if (nSerialChannels > 3) {
        relayModuleInfo(Serial3COM);
      }
      #if MachineType == 2
        relayModuleInfo(Serial4COM);
        relayModuleInfo(Serial5COM);
      #endif
    }
  }
  if (USBCOM.available() > 0) { // If a message has arrived on the USB serial port
    CommandByte = USBCOM.readByte();  // P for Program, R for Run, O for Override, 6 for Handshake, F for firmware version
    switch (CommandByte) {
      case '6':  // Initialization handshake
        connectionState = 1;
        updateStatusLED(2);
        USBCOM.writeByte(53);
        delayMicroseconds(100000);
        USBCOM.flush();
        SessionStartTime = millis();
        resetSerialMessages();
        disableModuleRelays();
      break;
      case 'F':  // Return firmware and machine type
        USBCOM.writeUint16(FirmwareVersion);
        USBCOM.writeUint16(MachineType);
      break;
      case 'H': // Return local hardware configuration
        USBCOM.writeUint16(MaxStates);
        USBCOM.writeUint16(timerPeriod);
        USBCOM.writeByte(maxSerialEvents);
        USBCOM.writeByte(nGlobalTimers);
        USBCOM.writeByte(nGlobalCounters);
        USBCOM.writeByte(nConditions);
        USBCOM.writeByte(nInputs);
        USBCOM.writeByteArray(InputHW, nInputs);
        USBCOM.writeByte(nOutputs);
        for (int i = 0; i < nOutputs; i++) {
          if (OutputHW[i] == 'Y') {
             USBCOM.writeByte(SyncChannelOriginalType);
          } else {
             USBCOM.writeByte(OutputHW[i]);
          }
        }
      break;
      case 'M': // Probe for connected modules and return module information
        while (Serial1COM.available() >0 ) {
           Serial1COM.readByte();
        }
        while (Serial2COM.available() >0 ) {
           Serial2COM.readByte();
        }
        while (Serial3COM.available() >0 ) {
           Serial3COM.readByte();
        }
        #if MachineType == 2
          while (Serial4COM.available() >0 ) {
             Serial4COM.readByte();
          }
          while (Serial5COM.available() >0 ) {
             Serial5COM.readByte();
          }
        #endif
        Serial1COM.writeByte(255);
        Serial2COM.writeByte(255);
        Serial3COM.writeByte(255);
        #if MachineType == 2
          Serial4COM.writeByte(255);
          Serial5COM.writeByte(255);
        #endif
        nCycles = 0; // Number of cycles since request was sent
        getModuleInfo = true; // Outgoing serial messages are not sent until after timer handler completes - so replies are forwarded to USB in the main loop.
      break;
      case '%': // Set number of events per module (this should be run from MATLAB after all modules event # requests are received by MATLAB and a determination is made how to allocate.
        USBCOM.readByteArray(nModuleEvents, nSerialChannels);
        USBCOM.writeByte(1);
      break;
      case 'E': // Enable ports
        for (int i = 0; i < nInputs; i++) {
          inputEnabled[i] = USBCOM.readByte();
        }
        USBCOM.writeByte(1);
      break;
      case 'J': // set serial module relay mode (when not running a state machine, relays one port's incoming bytes to MATLAB/Python
        disableModuleRelays();
        clearSerialBuffers();
        Byte1 = USBCOM.readByte();
        Byte2 = USBCOM.readByte();
        UARTrelayMode[Byte1] = Byte2;
      break;
      case 'K': // Set sync channel and mode
      NewSyncChannel = USBCOM.readByte();
      SyncMode = USBCOM.readByte();
      if (!usesSPISync) {
        if (NewSyncChannel != SyncChannel){ 
          if (NewSyncChannel == 255) {
            if (SyncChannel < nOutputs) {
              OutputHW[SyncChannel] = SyncChannelOriginalType;
            }
            syncOn = false;
          } else {
            if (NewSyncChannel < nOutputs) {
              if (SyncChannel < 255) {
                if (OutputHW[SyncChannel] == 'Y') {
                  OutputHW[SyncChannel] = SyncChannelOriginalType;
                }
              }
              SyncChannelOriginalType = OutputHW[NewSyncChannel];
              OutputHW[NewSyncChannel] = 'Y';
              syncOn = true;
              SyncChannelHW = OutputCh[NewSyncChannel];
            }
          }
          SyncChannel = NewSyncChannel;
        }
      }
      USBCOM.writeByte(1);
      break;
      case 'O':  // Override digital hardware state
        Byte1 = USBCOM.readByte();
        Byte2 = USBCOM.readByte();
        switch (OutputHW[Byte1]) {
          case 'S':
            spiWrite(Byte2, OutputCh[Byte1]);
          break;
          case 'D':
          case 'B':
          case 'W':
            digitalWriteDirect(OutputCh[Byte1], Byte2);
            outputOverrideState[Byte1] = Byte2;
          break;
          case 'P':
            analogWrite(OutputCh[Byte1], Byte2);
          break;
        }
      break;
      case 'I': // Read and return digital input line states (for debugging)
        Byte1 = USBCOM.readByte();
        Byte2 = digitalReadDirect(InputCh[Byte1]);
        Byte2 = (Byte2 == logicHigh[Byte1]);
        USBCOM.writeByte(Byte2);
      break;
      case 'Q': // Set cycle monitoring mode - 0 = off (default), 1 = on. Measures min and max time to execute timer callback.
        cycleMonitoring = USBCOM.readByte();
        if (cycleMonitoring) {
          MinCallbackDuration = timerPeriod;
          MaxCallbackDuration = 0;
        }
      break;
      case '#': // Return minimum and maximum cycle duration since monitoring mode was: 1. last checked, or 2. last activated
        USBCOM.writeUint16(MinCallbackDuration);
        USBCOM.writeUint16(MaxCallbackDuration);
        MinCallbackDuration = timerPeriod;
        MaxCallbackDuration = 0;
      break;
      case 'Z':  // Bpod governing machine has closed the client program
        disableModuleRelays();
        connectionState = 0;
        connectionState = 0;
        USBCOM.writeByte('1');
        updateStatusLED(0);
      break;
      case 'S': // Echo Soft code.
        VirtualEventData = USBCOM.readByte();
        USBCOM.writeByte(2);
        USBCOM.writeByte(VirtualEventData);
      break;
      case 'T': // Receive bytes from USB and send to hardware serial channel 1-5
        Byte1 = USBCOM.readByte() - 1; // Serial channel
        nBytes = USBCOM.readUint8();
        switch (Byte1) {
          case 0:
            USBCOM.readByteArray(UARTRelayBuffer, nBytes);
            Serial1COM.writeByteArray(UARTRelayBuffer, nBytes);
          break;
          case 1:
            USBCOM.readByteArray(UARTRelayBuffer, nBytes);
            Serial2COM.writeByteArray(UARTRelayBuffer, nBytes);
          break;
          case 2:
            USBCOM.readByteArray(UARTRelayBuffer, nBytes);
            Serial3COM.writeByteArray(UARTRelayBuffer, nBytes);
          break;
          #if MachineType == 2
            case 3:
              USBCOM.readByteArray(UARTRelayBuffer, nBytes);
              Serial4COM.writeByteArray(UARTRelayBuffer, nBytes);
            break;
            case 4:
              USBCOM.readByteArray(UARTRelayBuffer, nBytes);
              Serial5COM.writeByteArray(UARTRelayBuffer, nBytes);
            break;
          #endif
         }
      break;
      case 'U': // Recieve byte CODE from USB and send to hardware serial channel 1-5
        Byte1 = USBCOM.readByte() - 1;
        Byte2 = USBCOM.readByte();
        Byte3 = SerialMessage_nBytes[Byte2][Byte1];
          for (int i = 0; i < Byte3; i++) {
             serialByteBuffer[i] = SerialMessageMatrix[Byte2][Byte1][i];
          }
        switch (Byte1) {
          case 0:
            Serial1COM.writeByteArray(serialByteBuffer, Byte3);
          break;
          case 1:
            Serial2COM.writeByteArray(serialByteBuffer, Byte3);
          break;
          case 2:
            Serial3COM.writeByteArray(serialByteBuffer, Byte3);
          break;
          #if MachineType == 2
            case 3:
              Serial4COM.writeByteArray(serialByteBuffer, Byte3);
            break;
            case 4:
              Serial5COM.writeByteArray(serialByteBuffer, Byte3);
            break;
          #endif
        }
        break;
      case 'L':
        Byte1 = USBCOM.readByte(); // Serial Channel
        Byte2 = USBCOM.readByte(); // nMessages arriving
        for (int i = 0; i < Byte2; i++) {
          Byte3 = USBCOM.readByte(); // Message Index
          Byte4 = USBCOM.readByte(); // Message Length
          SerialMessage_nBytes[Byte3][Byte1] = Byte4;
          for (int j = 0; j < Byte4; j++) {
            SerialMessageMatrix[Byte3][Byte1][j] = USBCOM.readByte();
          }
        }
        USBCOM.writeByte(1);
      break;
      case '>': // Reset serial messages to equivalent byte codes (i.e. message# 4 = one byte, 0x4)
        resetSerialMessages();
        USBCOM.writeByte(1);
      break;
      case 'V': // Manual override: execute virtual event
        VirtualEventTarget = USBCOM.readByte();
        VirtualEventData = USBCOM.readByte();
        if (RunningStateMatrix) {
           inputState[VirtualEventTarget] = VirtualEventData;
           inputOverrideState[VirtualEventTarget] = true;
        }
      break;
      case 'C': // Get new compressed state matrix from MATLAB/Python
        newSMATransmissionStarted = true;
        smaTransmissionConfirmed = false;
        nStates = USBCOM.readByte();
        for (int x = 0; x < nStates; x++) { // Set matrix to default
          StateTimerMatrix[x] = 0;
          for (int y = 0; y < InputMatrixSize; y++) {
            InputStateMatrix[x][y] = x;
          }
          for (int y = 0; y < OutputMatrixSize; y++) {
            OutputStateMatrix[x][y] = 0;
          }
          for (int y = 0; y < nGlobalTimers; y++) {
            GlobalTimerStartMatrix[x][y] = x;
          }
          for (int y = 0; y < nGlobalTimers; y++) {
            GlobalTimerEndMatrix[x][y] = x;
          }
          for (int y = 0; y < nGlobalCounters; y++) {
            GlobalCounterMatrix[x][y] = x;
          }
          for (int y = 0; y < nConditions; y++) {
            ConditionMatrix[x][y] = x;
          }
        }
        for (int x = 0; x < nStates; x++) { // Get State timer matrix
          StateTimerMatrix[x] = USBCOM.readByte();
        }
        for (int x = 0; x < nStates; x++) { // Get Input Matrix differences
          nOverrides = USBCOM.readByte();
          for (int y = 0; y<nOverrides; y++) {
            col = USBCOM.readByte();
            val = USBCOM.readByte();
            InputStateMatrix[x][col] = val;
          }
        }
        for (int x = 0; x < nStates; x++) { // Get Output Matrix differences
          nOverrides = USBCOM.readByte();
          for (int y = 0; y<nOverrides; y++) {
            col = USBCOM.readByte();
            val = USBCOM.readByte();
            OutputStateMatrix[x][col] = val;
          }
        }
        for (int x = 0; x < nStates; x++) { // Get Global Timer Start Matrix differences
          nOverrides = USBCOM.readByte();
          if (nOverrides > 0) {
            for (int y = 0; y<nOverrides; y++) {
              col = USBCOM.readByte();
              val = USBCOM.readByte();
              GlobalTimerStartMatrix[x][col] = val;
            }
          }
        }
        for (int x = 0; x < nStates; x++) { // Get Global Timer End Matrix differences
          nOverrides = USBCOM.readByte();
          if (nOverrides > 0) {
            for (int y = 0; y<nOverrides; y++) {
              col = USBCOM.readByte();
              val = USBCOM.readByte();
              GlobalTimerEndMatrix[x][col] = val;
            }
          }
        }
        for (int x = 0; x < nStates; x++) { // Get Global Counter Matrix differences
          nOverrides = USBCOM.readByte();
          if (nOverrides > 0) {
            for (int y = 0; y<nOverrides; y++) {
              col = USBCOM.readByte();
              val = USBCOM.readByte();
              GlobalCounterMatrix[x][col] = val;
            }
          }
        }
        for (int x = 0; x < nStates; x++) { // Get Condition Matrix differences
          nOverrides = USBCOM.readByte();
          if (nOverrides > 0) {
            for (int y = 0; y<nOverrides; y++) {
              col = USBCOM.readByte();
              val = USBCOM.readByte();
              ConditionMatrix[x][col] = val;
            }
          }
        }
        USBCOM.readByteArray(GlobalTimerChannel, nGlobalTimers); // Get output channels of global timers
        USBCOM.readByteArray(GlobalTimerOnMessage, nGlobalTimers); // Get serial messages to trigger on timer start
        USBCOM.readByteArray(GlobalTimerOffMessage, nGlobalTimers); // Get serial messages to trigger on timer end
        USBCOM.readByteArray(GlobalCounterAttachedEvents, nGlobalCounters); // Get global counter attached events
        USBCOM.readByteArray(ConditionChannels, nConditions); // Get condition channels
        USBCOM.readByteArray(ConditionValues, nConditions); // Get condition values
        USBCOM.readUint32Array(StateTimers, nStates); // Get state timers
        USBCOM.readUint32Array(GlobalTimers, nGlobalTimers); // Get global timers
        USBCOM.readUint32Array(GlobalTimerOnsetDelays, nGlobalTimers); // Get global timer onset delays
        USBCOM.readUint32Array(GlobalCounterThresholds, nGlobalCounters); // Get global counter event count thresholds
        smaTransmissionConfirmed = true;
      break;
      case 'R':  // Run State Machine
        if (newSMATransmissionStarted){
          if (smaTransmissionConfirmed) {
            USBCOM.writeByte(1);
          } else {
            USBCOM.writeByte(0);
          }
          newSMATransmissionStarted = false;
        }
        updateStatusLED(3);
        NewState = 0;
        CurrentState = 0;
        nEvents = 0;
        SoftEvent = 254; // No event
        MatrixFinished = false;
        if (usesFRAM) {
          // Initialize fRAM
          SPI.beginTransaction(SPISettings(40000000, MSBFIRST, SPI_MODE0));
          digitalWriteDirect(fRAMcs, LOW);
          SPI.transfer(6); // Send Write enable code
          digitalWriteDirect(fRAMcs, HIGH); // Must go high afterwards to enable writes
          delayMicroseconds(10);
          digitalWriteDirect(fRAMcs, LOW);
          SPI.transfer(2); // Send write op code
          SPI.transfer(0); // Send address bytes
          SPI.transfer(0);
          SPI.transfer(0);
          digitalWriteDirect(fRAMhold, LOW); // Pause logging
          digitalWriteDirect(fRAMcs, HIGH);
        }
        // Reset event counters
        for (int i = 0; i < 5; i++) {
          GlobalCounterCounts[i] = 0;
        }
        // Read initial state of sensors
        for (int i = BNCInputPos; i < nInputs; i++) {
          if (inputEnabled[i] == 1) {
            inputState[i] =  digitalReadDirect(InputCh[i]);
            lastInputState[i] = inputState[i];
          } else {
            inputState[i] = logicLow[i];
            lastInputState[i] = logicLow[i];
          }
          inputOverrideState[i] = false;
        }
        clearSerialBuffers();
        // Reset timers
        MatrixStartTime = 0;
        StateStartTime = 0;
        CurrentTime = 0;
        RunningStateMatrix = 1;
        firstLoop = 1;
        break;
      case 'X':   // Exit state matrix and return data
        MatrixFinished = true;
        RunningStateMatrix = false;
        resetOutputs(); // Returns all lines to low by forcing final state
        break;
    } // End switch commandbyte
  } // End SerialUSB.available
  if (RunningStateMatrix) {
    if (firstLoop == 1) {
      firstLoop = 0;
      MatrixStartTimeMillis = millis();
      SyncWrite();
      setStateOutputs(CurrentState); // Adjust outputs, global timers, serial codes and sync port for first state
    } else {
      nCurrentEvents = 0;
      CurrentEvent[0] = 254; // Event 254 = No event
      CurrentTime++;
      for (int i = BNCInputPos; i < nInputs; i++) {
          if (inputEnabled[i] && !inputOverrideState[i]) {
            inputState[i] = digitalReadDirect(InputCh[i]); 
          } 
      }
      // Determine if a handled condition occurred
      Ev = ConditionPos;
      for (int i = 0; i < nConditions; i++) {
        if (ConditionMatrix[CurrentState][i] != CurrentState) { // If this condition is handled
          if (inputState[ConditionChannels[i]] == ConditionValues[i]) {
            CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
          }
        }
        Ev++;
      }
      // Determine if a digital low->high or high->low transition event occurred
      Ev = DigitalInputPos;
      for (int i = BNCInputPos; i < nInputs; i++) {
          if (inputEnabled[i] == 1) {
              if ((inputState[i] == logicHigh[i]) && (lastInputState[i] == logicLow[i])) {
                lastInputState[i] = logicHigh[i]; CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
              }
          }
          Ev++;
          if (inputEnabled[i] == 1) {
              if ((inputState[i] == logicLow[i]) && (lastInputState[i] == logicHigh[i])) {
                lastInputState[i] = logicLow[i]; CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
              }
          }
          Ev++;
      }
      // Determine if a USB or hardware serial event occurred
      Ev = 0; Byte1 = 0;
      for (int i = 0; i < BNCInputPos; i++) {
        switch(InputHW[i]) {
          case 'U':
          if (usesUARTInputs) {
            switch(Byte1) {
              case 0:
                if (Serial1COM.available()>0) {
                  Byte2 = Serial1COM.readByte();
                  if (Byte2 <= nModuleEvents[0]) {
                    CurrentEvent[nCurrentEvents] = Byte2 + Ev-1; nCurrentEvents++; 
                  }
                }
                Byte1++;
              break;
              case 1:
                if (Serial2COM.available()>0) {
                  Byte2 = Serial2COM.readByte();
                  if (Byte2 <= nModuleEvents[1]) {
                    CurrentEvent[nCurrentEvents] = Byte2 + Ev-1; nCurrentEvents++; 
                  }
                }
                Byte1++;
              break;
              case 2:
                if (Serial3COM.available()>0) {
                  Byte2 = Serial3COM.readByte();
                  if (Byte2 <= nModuleEvents[2]) {
                    CurrentEvent[nCurrentEvents] = Byte2 + Ev-1; nCurrentEvents++; 
                  }
                }
                Byte1++;
              break;
              case 3:
                #if MachineType == 2
                  if (Serial4COM.available()>0) {
                    Byte2 = Serial4COM.readByte();
                    if (Byte2 <= nModuleEvents[3]) {
                      CurrentEvent[nCurrentEvents] = Byte2 + Ev-1; nCurrentEvents++; 
                    }
                  }
                #endif
                Byte1++;
              break;
              case 4:
                #if MachineType == 2
                  if (Serial5COM.available()>0) {
                    Byte2 = Serial5COM.readByte();
                    if (Byte2 <= nModuleEvents[4]) {
                      CurrentEvent[nCurrentEvents] = Byte2 + Ev-1; nCurrentEvents++; 
                    }
                  }
                #endif
                Byte1++;
              break;
            }
          }
          break;
          case 'X':
              if (SoftEvent < 254) {
                CurrentEvent[nCurrentEvents] = SoftEvent + Ev; nCurrentEvents++;
                SoftEvent = 254;
              }
          break;
        }
        Ev += nModuleEvents[i];
      }
      Ev = GlobalTimerStartPos;
      // Determine if a global timer expired
      for (int i = 0; i < nGlobalTimers; i++) {
        if (GlobalTimersActive[i] == true) {
          if (CurrentTime >= GlobalTimerEnd[i]) {
            CurrentEvent[nCurrentEvents] = Ev+nGlobalTimers; nCurrentEvents++;
            setGlobalTimerChannel(i, 0);
            GlobalTimersTriggered[i] = false;
            GlobalTimersActive[i] = false;
          }
        } else if (GlobalTimersTriggered[i] == true) {
          if (CurrentTime >= GlobalTimerStart[i]) {
            GlobalTimersActive[i] = true;
            CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
            setGlobalTimerChannel(i, 1);
          }
        }
        Ev++;
      }
      Ev = GlobalCounterPos;
      // Determine if a global event counter threshold was exceeded
      for (int x = 0; x < nGlobalCounters; x++) {
        if (GlobalCounterAttachedEvents[x] < 254) {
          // Check for and handle threshold crossing
          if (GlobalCounterCounts[x] == GlobalCounterThresholds[x]) {
            CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
          }
          // Add current event to count (Crossing triggered on next cycle)
          for (int i = 0; i < nCurrentEvents; i++) {
            if (CurrentEvent[i] == GlobalCounterAttachedEvents[x]) {
              GlobalCounterCounts[x] = GlobalCounterCounts[x] + 1;
            }
          }
        }
        Ev++;
      }
      // Determine if a state timer expired
      Ev = TupPos;
      TimeFromStart = CurrentTime - StateStartTime;
      if ((TimeFromStart >= StateTimers[CurrentState]) && (MeaningfulStateTimer == true)) {
        CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
      }
      if (nCurrentEvents > maxCurrentEvents) { // Drop events beyond maxCurrentEvents
        nCurrentEvents = maxCurrentEvents;
      }
      // Now determine if a state transition should occur. The first event linked to a state transition takes priority.
      byte StateTransitionFound = 0; int i = 0; int CurrentColumn = 0;
      while ((!StateTransitionFound) && (i < nCurrentEvents)) {
        if (CurrentEvent[i] < GlobalTimerStartPos) {
          NewState = InputStateMatrix[CurrentState][CurrentEvent[i]];
        } else if (CurrentEvent[i] < GlobalTimerEndPos) {
          CurrentColumn = CurrentEvent[i] - GlobalTimerStartPos;
          NewState = GlobalTimerStartMatrix[CurrentState][CurrentColumn];
        } else if (CurrentEvent[i] < GlobalCounterPos) {
          CurrentColumn = CurrentEvent[i] - GlobalTimerEndPos;
          NewState = GlobalTimerEndMatrix[CurrentState][CurrentColumn];
        } else if (CurrentEvent[i] < ConditionPos) {
          CurrentColumn = CurrentEvent[i] - GlobalCounterPos;
          NewState = GlobalCounterMatrix[CurrentState][CurrentColumn];
        } else if (CurrentEvent[i] < JumpPos) {
          CurrentColumn = CurrentEvent[i] - ConditionPos;
          NewState = ConditionMatrix[CurrentState][CurrentColumn];
        } else if (CurrentEvent[i] == TupPos) {
          NewState = StateTimerMatrix[CurrentState];
        }
        if (NewState != CurrentState) {
          StateTransitionFound = 1;
        }
        i++;
      }

      // Store timestamps of events captured in this cycle
      if (usesFRAM) {
        for (int i = 0; i < nCurrentEvents; i++) {
          TrialTimeStamps.Uint32[i] = CurrentTime;
          nEvents++;
        }
        digitalWriteDirect(fRAMcs, LOW);
        digitalWriteDirect(fRAMhold, HIGH); // Resume logging
        SPI.transfer(TrialTimeStamps.Bytes, nCurrentEvents * 4);
        digitalWriteDirect(fRAMhold, LOW); // Pause logging
        digitalWriteDirect(fRAMcs, HIGH);
      } else {
        if ((nEvents + nCurrentEvents) < MaxTimestamps) {
          for (int x = 0; x < nCurrentEvents; x++) {
            #if FirmwareVersion < 7
              Timestamps[nEvents] = CurrentTime;
              nEvents++;
            #endif
          } 
        }
      } 
      // Write events captured to USB (if events were captured)
      if (nCurrentEvents > 0) {
        USBCOM.writeByte(1); // Code for returning events
        USBCOM.writeByte(nCurrentEvents);
        USBCOM.writeByteArray(CurrentEvent, nCurrentEvents);
      }
      // Make state transition if necessary
      if (NewState != CurrentState) {
        if (NewState == nStates) {
          RunningStateMatrix = false;
          MatrixFinished = true;
        } else {
          if (SyncMode == 1) {
            SyncWrite();
          }
          setStateOutputs(NewState);
          StateStartTime = CurrentTime;
          CurrentState = NewState;
        }
      }
      if (cycleMonitoring) {
        MeasuredCallbackDuration = micros()-CallbackStartTime;
        if (MeasuredCallbackDuration > MaxCallbackDuration) {MaxCallbackDuration = MeasuredCallbackDuration;}
        if (MeasuredCallbackDuration < MinCallbackDuration) {MinCallbackDuration = MeasuredCallbackDuration;}
      }
    } // End code to run after first loop
  }  else { // If not running state matrix
    
   
  } // End if not running state matrix
  if (MatrixFinished) {
    if (SyncMode == 0) {
      ResetSyncLine();
    } else {
      SyncWrite();
    }
    resetOutputs();
// Send trial timing data back to computer
    serialByteBuffer[0] = 1; // Op Code for sending events
    serialByteBuffer[1] = 1; // Read one event
    serialByteBuffer[2] = 255; // Send Matrix-end code
    USBCOM.writeByteArray(serialByteBuffer, 3);
    // Send trial-start timestamp (from millis() clock)
    USBCOM.writeUint32(MatrixStartTimeMillis - SessionStartTime);
    USBCOM.writeUint16(nEvents);
    if (usesFRAM) {
      // Return event times from fRAM IC
      digitalWriteDirect(fRAMhold, HIGH);
      digitalWriteDirect(fRAMcs, LOW);
      SPI.transfer(3); // Send read op code
      SPI.transfer(0); // Send address bytes
      SPI.transfer(0);
      SPI.transfer(0);
      for (int i = 0; i < nEvents * 4; i++) {
        USBCOM.writeByte(SPI.transfer(0));
      }
      digitalWriteDirect(fRAMcs, HIGH);
    } else {
      #if FirmwareVersion < 7
        USBCOM.writeUint32Array(Timestamps, nEvents);
      #endif
    }
    MatrixFinished = false;
    updateStatusLED(0);
    updateStatusLED(2);
  } // End Matrix finished
} // End timer handler

void ResetSyncLine() {
  if (!usesSPISync) {
    SyncState = 0;
    if (SyncChannelOriginalType == 'P') {
      analogWrite(SyncChannelHW, SyncState);
    } else {
      digitalWriteDirect(SyncChannelHW, SyncState);     
    }
  }
}
void SyncWrite() {
  if (!usesSPISync) {
    if (syncOn) { ;
      if (SyncState == 0) {
        SyncState = 1;
      } else {
        SyncState = 0;
      }
      if (SyncChannelOriginalType == 'P') {
        analogWrite(SyncChannelHW, SyncState*255);
      } else {
        digitalWriteDirect(SyncChannelHW, SyncState);     
      }
    }
  }
}
void SyncRegWrite(int value) {
  if (usesSPISync) {
    SPI.transfer(value);
    digitalWriteDirect(SyncRegisterLatch,HIGH);
    digitalWriteDirect(SyncRegisterLatch,LOW);
  }
}
void updateStatusLED(int Mode) {
  if (useStatusLED) {
    CurrentTime = millis();
    switch (Mode) {
      case 0: {
          analogWrite(RedLEDPin, 0);
          digitalWriteDirect(GreenLEDPin, 0);
          analogWrite(BlueLEDPin, 0);
        } break;
      case 1: { // Waiting for matrix
          if (connectionState == 0) {
            if (CurrentTime > NextLEDBrightnessAdjustTime) {
              NextLEDBrightnessAdjustTime = CurrentTime + LEDBrightnessAdjustInterval;
              if (LEDBrightnessAdjustDirection == 1) {
                if (LEDBrightness < 255) {
                  LEDBrightness = LEDBrightness + 1;
                } else {
                  LEDBrightnessAdjustDirection = 0;
                }
              }
              if (LEDBrightnessAdjustDirection == 0) {
                if (LEDBrightness > 0) {
                  LEDBrightness = LEDBrightness - 1;
                } else {
                  LEDBrightnessAdjustDirection = 2;
                }
              }
              if (LEDBrightnessAdjustDirection == 2) {
                NextLEDBrightnessAdjustTime = CurrentTime + 500;
                LEDBrightnessAdjustDirection = 1;
              }
              analogWrite(BlueLEDPin, LEDBrightness);
            }
          }
        } break;
      case 2: {
          analogWrite(BlueLEDPin, 0);
          digitalWriteDirect(GreenLEDPin, 1);
        } break;
      case 3: {
          digitalWrite(GreenLEDPin, HIGH);
          analogWrite(BlueLEDPin, 0);
          analogWrite(RedLEDPin, 128);
        } break;
    }
  }
}

void setStateOutputs(byte State) { 
  byte CurrentTimer = 0; // Used when referring to the timer currently being triggered
  byte CurrentCounter = 0; // Used when referring to the counter currently being reset
  Byte1 = 0;
  SyncRegWrite((State+1)); // If firmware 0.5 or 0.6, writes current state code to shift register
  for (int i = 0; i < nOutputs; i++) {
      switch(OutputHW[i]) {
        case 'U':
        Byte2 = OutputStateMatrix[State][i];
        if (Byte2 > 0) {
          Byte3 = SerialMessage_nBytes[Byte2][Byte1];
          for (int i = 0; i < Byte3; i++) {
             serialByteBuffer[i] = SerialMessageMatrix[Byte2][Byte1][i];
          }
          switch(Byte1) {
            case 0:
              Serial1COM.writeByteArray(serialByteBuffer, Byte3);
            break;
            case 1:
              Serial2COM.writeByteArray(serialByteBuffer, Byte3);
            break;
            case 2:
              Serial3COM.writeByteArray(serialByteBuffer, Byte3);
            break;
            #if MachineType == 2
              case 3:
                Serial4COM.writeByteArray(serialByteBuffer, Byte3);
              break;
              case 4:
                Serial5COM.writeByteArray(serialByteBuffer, Byte3);
              break;
            #endif
          }
        }
        Byte1++;
        break;
        case 'X':
        if (OutputStateMatrix[State][i] > 0) {
          serialByteBuffer[0] = 2; // Code for MATLAB to receive soft-code byte
          serialByteBuffer[1] = OutputStateMatrix[State][i]; // Soft code byte
          USBCOM.writeByteArray(serialByteBuffer, 2);
        }
        break;
        case 'S':
          spiWrite(OutputStateMatrix[State][i], OutputCh[i]);
        break;
        case 'D':
        case 'B':
        case 'W':
          if (outputOverrideState[i] == 0) {
            digitalWriteDirect(OutputCh[i], OutputStateMatrix[State][i]); 
          }
        break;
        case 'P':
          if (outputOverrideState[i] == 0) {   
            #if MachineType == 1
              //Arduino Due PERFORMANCE HACK: the next line is equivalent to: analogWrite(OutputCh[i], OutputStateMatrix[State][i]); 
              PWMC_SetDutyCycle(PWM_INTERFACE, PWMChannel[i], OutputStateMatrix[State][i]);
            #else
              analogWrite(OutputCh[i], OutputStateMatrix[State][i]); 
            #endif
          }
        break;
     }
  }
  // Trigger global timers
  Byte1 = nOutputs;
  CurrentTimer = OutputStateMatrix[State][Byte1];
  if (CurrentTimer > 0) {
    CurrentTimer = CurrentTimer - 1; // Convert to 0 index
    GlobalTimersTriggered[CurrentTimer] = true;
    GlobalTimerStart[CurrentTimer] = CurrentTime;
    if (GlobalTimerOnsetDelays[CurrentTimer] > 0){
      GlobalTimerStart[CurrentTimer] += GlobalTimerOnsetDelays[CurrentTimer];
    } else {
      GlobalTimersActive[CurrentTimer] = true;
      setGlobalTimerChannel(CurrentTimer, 1);
    }
    GlobalTimerEnd[CurrentTimer] = GlobalTimerStart[CurrentTimer] + GlobalTimers[CurrentTimer];
  }
  Byte1++;
  // Cancel global timers
  CurrentTimer = OutputStateMatrix[State][Byte1];
  if (CurrentTimer > 0) {
    CurrentTimer = CurrentTimer - 1; // Convert to 0 index
    GlobalTimersTriggered[CurrentTimer] = false;
    GlobalTimersActive[CurrentTimer] = false;
  }
  Byte1++;
  // Reset event counters
  CurrentCounter = OutputStateMatrix[State][Byte1];
  if (CurrentCounter > 0) {
    CurrentCounter = CurrentCounter - 1; // Convert to 0 index
    GlobalCounterCounts[CurrentCounter] = 0;
  }
  if (StateTimerMatrix[State] != State) {
    MeaningfulStateTimer = true;
  } else {
    MeaningfulStateTimer = false;
  }
}

void resetOutputs() {
  for (int i = 0; i < nOutputs; i++) {
    switch (OutputHW[i]) {
      case 'S':
        spiWrite(0, OutputCh[i]);
        Byte1++;
      break;
      case 'B':
      case 'W':
        digitalWriteDirect(OutputCh[i], 0); 
      break;
      case 'P':
        analogWrite(OutputCh[i], 0); 
      break;
    }
  }
  for (int i = 1; i < nGlobalTimers; i++) {
    GlobalTimersTriggered[i] = false;
  }
  for (int i = 1; i < nGlobalCounters; i++) {  
    GlobalCounterCounts[i] = 0;
  }
  MeaningfulStateTimer = false;
}

void resetSerialMessages() {
  for (int i = 0; i < MaxStates; i++) {
    for (int j = 0; j < nSerialChannels-1; j++) {
      SerialMessageMatrix[i][j][0] = i;
      SerialMessage_nBytes[i][j] = 1;
    }
  }
}

void spiWrite(byte value, byte csChannel) {
  SPI.transfer(value);
  digitalWriteDirect(csChannel, HIGH);
  digitalWriteDirect(csChannel, LOW);
}

void digitalWriteDirect(int pin, boolean val) { // >10x Faster than digitalWrite(), specific to Arduino Due
  #if MachineType == 1
    if (val) g_APinDescription[pin].pPort -> PIO_SODR = g_APinDescription[pin].ulPin;
    else    g_APinDescription[pin].pPort -> PIO_CODR = g_APinDescription[pin].ulPin;
  #else
    digitalWrite(pin, val);
  #endif
}

byte digitalReadDirect(int pin) { // >10x Faster than digitalRead(), specific to Arduino Due
  #if MachineType == 1
    return !!(g_APinDescription[pin].pPort -> PIO_PDSR & g_APinDescription[pin].ulPin);
  #else
    return digitalRead(pin);
  #endif
}

void setGlobalTimerChannel(byte chan, byte op) {
  Byte1 = GlobalTimerChannel[chan];
  switch (OutputHW[Byte1]) {
    case 'U':
      if (op == 1) {
        Byte2 = GlobalTimerOnMessage[chan];
      } else {
        Byte2 = GlobalTimerOffMessage[chan];
      }
      if (Byte2 < 254) {
        Byte3 = SerialMessage_nBytes[Byte2][Byte1];
          for (int i = 0; i < Byte3; i++) {
             serialByteBuffer[i] = SerialMessageMatrix[Byte2][Byte1][i];
          }
        switch (Byte1) {
          case 0:
            Serial1COM.writeByteArray(serialByteBuffer, Byte3);
          break;
          case 1:
            Serial2COM.writeByteArray(serialByteBuffer, Byte3);
          break;
          case 2:
            Serial3COM.writeByteArray(serialByteBuffer, Byte3);
          break;
          #if MachineType == 2
            case 3:
              Serial4COM.writeByteArray(serialByteBuffer, Byte3);
            break;
            case 4:
              Serial5COM.writeByteArray(serialByteBuffer, Byte3);
            break;
          #endif
        }
      }
    break;
    case 'B':
    case 'W':
    case 'D':
      if (op == 1) {
        digitalWriteDirect(OutputCh[Byte1], HIGH);
        outputOverrideState[Byte1] = 1;
      } else {
        digitalWriteDirect(OutputCh[Byte1], LOW);
        outputOverrideState[Byte1] = 0;
      }
    break;
    case 'P':
      if (op == 1) {
        analogWrite(OutputCh[Byte1], GlobalTimerOnMessage[chan]);
        outputOverrideState[Byte1] = 1;
      } else {
        digitalWriteDirect(OutputCh[Byte1], 0);
        outputOverrideState[Byte1] = 0;
      }
    break;
  }
}

void relayModuleInfo(ArCOM serialCOM) {
  boolean moduleFound = false;
  if (serialCOM.available() > 0) {
    Byte1 = serialCOM.readByte();
    if (Byte1 == 'A') { // A = Acknowledge; this is most likely a module
      if (serialCOM.available() > 3) {
        moduleFound = true;
        USBCOM.writeByte(1); // Module detected
        for (int i = 0; i < 4; i++) { // Send firmware version
          USBCOM.writeByte(serialCOM.readByte());
        }
        nBytes = serialCOM.readByte(); // Length of module name
        USBCOM.writeByte(nBytes);
        for (int i = 0; i < nBytes; i++) { // Transfer module name
          USBCOM.writeByte(serialCOM.readByte());
        }
        Byte1 = serialCOM.readByte(); // 1 if more module info follows, 0 if not
        if (Byte1 == 1) { // Optional: module can return additional info with an op code scheme
          while(Byte1 == 1) {
            USBCOM.writeByte(1); // indicate that more info is coming for this module
            CommandByte = serialCOM.readByte();
            switch (CommandByte) {
              case '#': // Number of behavior events to reserve for the module
                USBCOM.writeByte('#');
                USBCOM.writeByte(serialCOM.readByte());
              break;
              case 'E': // Event name strings (replace default event names: ModuleName1_1, etc)
                USBCOM.writeByte('E');
                Byte2 = serialCOM.readByte(); // nEvent names to transmit
                USBCOM.writeByte(Byte2);
                for (int i = 0; i < Byte2; i++) {
                  Byte3 = serialCOM.readByte(); // Length of event name (in characters)
                  USBCOM.writeByte(Byte3);
                  serialCOM.readByteArray(UARTRelayBuffer, Byte3);
                  USBCOM.writeByteArray(UARTRelayBuffer, Byte3);
                }
              break;
            }
            Byte1 = serialCOM.readByte(); // 1 if more module info follows, 0 if not
          }
          USBCOM.writeByte(0); // indicate that no more info is coming for this module 
        } else {
          USBCOM.writeByte(0); // indicate that no more info is coming for this module 
        }
      }
    }
  }
  if (!moduleFound) {
    USBCOM.writeByte(0); // Module not detected
  }
}

void disableModuleRelays() {
  for (int i = 0; i < nSerialChannels; i++) { // Shut off all other channels
    UARTrelayMode[Byte1] = false;
  }
}

void relayModuleBytes() {
  for (int i = 0; i < nSerialChannels; i++) { // If relay mode is on, return any incoming module bytes to MATLAB/Python
      if (UARTrelayMode[i]) {
        switch(i) {
          case 0:
            Byte3 = Serial1COM.available();
            if (Byte3>0) { 
              for (int j = 0; j < Byte3; j++) {
                 USBCOM.writeByte(Serial1COM.readByte());       
              }
            }
          break;
          case 1:
            Byte3 = Serial2COM.available();
            if (Byte3>0) { 
              for (int j = 0; j < Byte3; j++) {
                 USBCOM.writeByte(Serial2COM.readByte());       
              }
            }
          break;
          case 2:
            Byte3 = Serial3COM.available();
            if (Byte3>0) { 
              for (int j = 0; j < Byte3; j++) {
                 USBCOM.writeByte(Serial3COM.readByte());       
              }
            }
          break;
          case 3:
            #if MachineType == 2
              Byte3 = Serial4COM.available();
            if (Byte3>0) { 
              for (int j = 0; j < Byte3; j++) {
                 USBCOM.writeByte(Serial4COM.readByte());       
              }
            }
            #endif
          break;
          case 4:
            #if MachineType == 2
              Byte3 = Serial5COM.available();
            if (Byte3>0) { 
              for (int j = 0; j < Byte3; j++) {
                 USBCOM.writeByte(Serial5COM.readByte());       
              }
            }
            #endif
          break;
        }
      }
    }
}

void clearSerialBuffers() {
  Byte1 = 0;
  for (int i = 0; i < BNCInputPos; i++) {
      switch (InputHW[i]) {
        case 'U': 
            switch(Byte1) {
              case 0:
                while (Serial1COM.available() > 0) {
                  Serial1COM.readByte(); Byte1++;
                }
              break;
              case 1:
                while (Serial2COM.available() > 0) {
                  Serial2COM.readByte(); Byte1++;
                }
              break;
              case 2:
                while (Serial3COM.available() > 0) {
                  Serial3COM.readByte(); Byte1++;
                }
              break;
              #if MachineType == 2
                case 3:
                  while (Serial4COM.available() > 0) {
                    Serial4COM.readByte(); Byte1++;
                  }
                break;
                case 4:
                  while (Serial5COM.available() > 0) {
                    Serial5COM.readByte(); Byte1++;
                  }
                break;
              #endif
            }
       break;
     }
  }
}

