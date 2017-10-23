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
// Bpod State Machine Firmware Ver. 18
//
// SYSTEM SETUP:
//
// IF COMPILING FOR Arduino DUE, Requires a small modification to Arduino, for useful PWM control of light intensity with small (1-10ms) pulses:
// change the PWM_FREQUENCY and TC_FREQUENCY constants to 50000 in the file /Arduino/hardware/arduino/sam/variants/arduino_due_x/variant.h
// or in Windows, \Users\Username\AppData\Local\Arduino15\packages\arduino\hardware\sam\1.6.7\variants\arduino_due_x\variant.h
//
// IF COMPILING FOR TEENSY 3.6, Requires modifications to Teensy core files:
// In the folder /arduino-1.8.X/hardware/teensy/avr/cores/teensy3, modify the following line in each of the 5 files listed below:
// #define SERIAL1_RX_BUFFER_SIZE 64  --> #define SERIAL1_RX_BUFFER_SIZE 256
// IN FILES: serial1.c, serial2.c, serial3.c, serial4.c, serial5.c

//////////////////////////////////////////
// Set hardware series (0.5, 0.7+, etc)  /
//////////////////////////////////////////
// 1 = Bpod 0.5 (Arduino Due); 2 = Bpod 0.7-0.9 (Arduino Due); 3 = Bpod 1.0.0 (Teensy 3.6)

#define MachineType 3 

//////////////////////////////////////////
//             Config Profile            /
//////////////////////////////////////////
// A profile of state machine params (max numbers of global timers, counters and conditions). 
// 0 = Bpod Native on HW 0.5-0.9 (5,5,5)
// 1 = Bpod Native on HW 1.0 (16,8,16)
// 2 = Bpod for BControl on HW 0.7-0.9 (8,2,8) 
// 3 = Bpod for Bcontrol on HW 1.0 (20,2,20)

#define ConfigProfile 3

//////////////////////////////////////////
//          Set Firmware Version         /
//////////////////////////////////////////
// Current firmware version (single firmware file, compiles for MachineTypes set above)

#define FirmwareVersion 18

//////////////////////////////////////////
//      Live Timestamp Transmission      /
//////////////////////////////////////////
// 0 to return timestamps after trial, 1 to return timestamps as events happen 

#define LiveTimestamps 1

//////////////////////////////////////////
//          Board configuration          /
//////////////////////////////////////////

// Board configuration (universal)
#define useStatusLED 1 // Set to 0 to disable the board's red/green/blue status LED

// Board configuration (machine-specific)
#if MachineType < 3
  #include "DueTimer.h"
#endif
#include <SPI.h>
#include "ArCOM.h" // ArCOM is a serial interface wrapper developed by Sanworks, 
                   // to streamline transmission of datatypes and arrays over USB and UART
#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256
#if MachineType == 1
  ArCOM USBCOM(SerialUSB); // Creates an ArCOM object called USBCOM, wrapping SerialUSB
  ArCOM Serial1COM(Serial1); // Creates an ArCOM object called Serial1COM, wrapping Serial1
  ArCOM Serial2COM(Serial2); 
#elif MachineType == 2
  ArCOM USBCOM(SerialUSB); 
  ArCOM Serial1COM(Serial1); 
  ArCOM Serial2COM(Serial2); 
  ArCOM Serial3COM(Serial3);
#elif MachineType == 3
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
// In these arrays, the first row codes for hardware type. U = UART, X = USB, S = SPI,  D = digital, B = BNC (digital/inverted), W = Wire (digital/inverted), V = Valve (digital) 
// P = port (digital channel if input, PWM channel if output). Channels must be listed IN THIS ORDER (this constraint allows efficient code at runtime). 
// The digital,BNC or wire channel currently replaced by 'Y' is the sync channel (none by default).
// The second row lists the physical input and output channels on Arduino for B,W,P, and the SPI CS pin is listed for S. Use 0 for UART and USB.

#if MachineType == 1 // Bpod state machine v0.5
    byte InputHW[] = {'U','U','X','B','B','W','W','W','W','P','P','P','P','P','P','P','P'};
    byte InputCh[] = {0,0,0,11,10,35,33,31,29,28,30,32,34,36,38,40,42};                                         
    byte OutputHW[] = {'U','U','X','B','B','W','W','W','W','P','P','P','P','P','P','P','P','V','V','V','V','V','V','V','V'};
    byte OutputCh[] = {0,0,0,25,24,43,41,39,37,9,8,7,6,5,4,3,2,22,22,22,22,22,22,22,22};   
#elif MachineType == 2 // Bpod State Machine r0.7+
    byte InputHW[] = {'U','U','U','X','B','B','W','W','P','P','P','P','P','P','P','P'};
    byte InputCh[] = {0,0,0,0,10,11,31,29,28,30,32,34,36,38,40,42};                                         
    byte OutputHW[] = {'U','U','U','X','B','B','W','W','W','P','P','P','P','P','P','P','P','V','V','V','V','V','V','V','V'};
    byte OutputCh[] = {0,0,0,0,25,24,43,41,39,9,8,7,6,5,4,3,2,22,22,22,22,22,22,22,22};  
#elif MachineType == 3 // Bpod State Machine r2.0+
    byte InputHW[] = {'U','U','U','U','U','X','B','B','P','P','P','P'};
    byte InputCh[] = {0,0,0,0,0,0,6,5,39,38,18,15};                                         
    byte OutputHW[] = {'U','U','U','U','U','X','B','B','P','P','P','P','V','V','V','V'};
    byte OutputCh[] = {0,0,0,0,0,0,4,3,37,14,16,17,23,22,20,21};  
#endif

// State machine meta information
const byte nInputs = sizeof(InputHW);
const byte nOutputs = sizeof(OutputHW);
#if MachineType == 1 // State machine (Bpod 0.5)
  const byte nSerialChannels = 3; // Must match total of 'U' and 'X' in InputHW (above)
  const byte maxSerialEvents = 30; // Must be a multiple of nSerialChannels
  const int MaxStates = 128;
  const int SerialBaudRate = 115200;
  const int maxSerialBaudRate = 115200;
#elif MachineType == 2 // Bpod State Machine r0.7+
  const byte nSerialChannels = 4; 
  const byte maxSerialEvents = 60; 
  const int MaxStates = 256;
  const int SerialBaudRate = 1312500;
  const int maxSerialBaudRate = 2625000;
#elif MachineType == 3  // Teensy 3.6 based state machines (r1.0.0+)
  const byte nSerialChannels = 6; 
  const byte maxSerialEvents = 90;
  const int MaxStates = 256;
  const int SerialBaudRate = 1312500;
  const int maxSerialBaudRate = 7372800;
#endif

#if ConfigProfile == 0
  #define nGlobalTimers 5
  #define nGlobalCounters 5
  #define nConditions 5
#elif ConfigProfile == 1
  #define nGlobalTimers 16
  #define nGlobalCounters 8
  #define nConditions 16
#elif ConfigProfile == 2
  #define nGlobalTimers 8
  #define nGlobalCounters 2
  #define nConditions 8
#elif ConfigProfile == 3
  #define nGlobalTimers 20
  #define nGlobalCounters 2
  #define nConditions 20
#endif

uint16_t timerPeriod = 100; // Hardware timer period, in microseconds (state machine refresh period)

#if nGlobalTimers > 16
  #define globalTimerByteWidth 4
#elif nGlobalTimers > 8
  #define globalTimerByteWidth 2
#else
  #define globalTimerByteWidth 1
#endif

// Vars to hold number of timers, counters and conditions actually used in the current state matrix
byte nGlobalTimersUsed = nGlobalTimers;
byte nGlobalCountersUsed = nGlobalCounters;
byte nConditionsUsed = nConditions;
                         
// Other hardware pin mapping
#if MachineType == 1
  byte GreenLEDPin = 14;
  byte RedLEDPin = 13;
  byte BlueLEDPin = 12;
  byte valveCSChannel = 22;
#elif MachineType == 2
  byte GreenLEDPin = 33;
  byte RedLEDPin = 13;
  byte BlueLEDPin = 12;
  byte valveCSChannel = 22;
#elif MachineType == 3
  byte GreenLEDPin = 2;
  byte RedLEDPin = 36;
  byte BlueLEDPin = 35;
  byte ValveEnablePin = 19;
  byte valveCSChannel = 0;
#endif

byte fRAMcs = 1;
byte fRAMhold = A3;
byte SyncRegisterLatch = 23;

// Settings for version-specific hardware (initialized in setup)
boolean usesFRAM = false;
boolean usesSPISync = false;
boolean usesSPIValves = false;
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
byte ValvePos = 0;

// Parameters

const unsigned long ModuleIDTimeout = 100; // timeout for modules to respond to byte 255 (units = 100us cycles). Byte 255 polls for module hardware information

// Initialize system state vars: 
byte outputState[nOutputs] = {0}; // State of outputs
byte inputState[nInputs+nGlobalTimers] = {0}; // Current state of inputs
byte lastInputState[nInputs+nGlobalTimers] = {0}; // State of inputs on previous cycle
byte inputOverrideState[nInputs] = {0}; // Set to 1 if user created a virtual event, to prevent hardware reads until user returns low
byte outputOverrideState[nOutputs] = {0}; // Set to 1 when overriding a digital output line. This prevents state changes from affecting the line until it is manually reset.
byte inputEnabled[nInputs] = {0}; // 0 if input disabled, 1 if enabled
byte logicHigh[nInputs] = {0}; // 1 if standard, 0 if inverted input (calculated in setup for each channel, depending on its type)
byte logicLow[nInputs] = {0}; // Inverse of logicHigh (to save computation time)
const byte nDigitalInputs = nInputs - nSerialChannels; // Number of digital input channels
boolean MatrixFinished = false; // Has the system exited the matrix (final state)?
boolean MeaningfulStateTimer = false; // Does this state's timer get us to another state when it expires?
int CurrentState = 1; // What state is the state machine currently in? (State 0 is the final state)
int NewState = 1;
int CurrentStateTEMP = 1; // Temporarily holds current state during transition
// Event vars
const byte maxCurrentEvents = 10; // Max number of events that can be recorded during a single 100 microsecond cycle
byte CurrentEvent[maxCurrentEvents] = {0}; // What event code just happened and needs to be handled. Up to 10 can be acquired per 100us loop.
byte CurrentEventBuffer[maxCurrentEvents+6] = {0}; // Current events as packaged for rapid vector transmission 
byte nCurrentEvents = 0; // Index of current event
byte SoftEvent = 0; // What soft event code just happened
// Trial / Event Sync Vars
byte SyncChannel = 255; // 255 if no sync codes, <255 to specify a channel to use for sync
boolean syncOn = false; // If true, sync codes are sent on sync channel
byte SyncChannelHW = 0; // Stores physical pin for sync channel
byte NewSyncChannel = 0; // New digital output channel to use for Sync. (old channel gets reset to its original hardware type)
byte SyncMode = 0; // 0 if low > high on trial start and high < low on trial end, 1 if line toggles with each state change
byte SyncState = 0; // State of the sync line (0 = low, 1 = high)
// Others
boolean smaTransmissionConfirmed = false; // Set to true when the last state machine was successfully received, set to false when starting a transmission
boolean newSMATransmissionStarted = false; // Set to true when beginning a state machine transmission
boolean UARTrelayMode[nSerialChannels] = {false};
byte nModuleEvents[nSerialChannels] = {10}; // Stores number of behavior events assigned to each serial module (10 by default)
uint16_t stateMatrixNBytes = 0; // Number of bytes in the state matrix about to be transmitted
boolean using255BackSignal = 0; // If enabled, only 254 states can be used and going to "state 255" returns system to the previous state


//////////////////////////////////
// Initialize general use vars:  /
//////////////////////////////////
const byte discoveryByte = 222; // Unique byte to send to any serial port on first connection (for USB serial port auto-discovery)
const byte discoveryByteInterval = 100; // ms between discovery byte transmissions
boolean RunStateMatrixASAP = false; // On state matrix transmission, set to 1 if the new state matrix should auto-run after the trial ends
byte CommandByte = 0;  // Op code to specify handling of an incoming USB serial message
byte VirtualEventTarget = 0; // Op code to specify which virtual event type (Port, BNC, etc)
byte VirtualEventData = 0; // State of target
byte Byte1 = 0; byte Byte2 = 0; byte Byte3 = 0; byte Byte4 = 0; // Temporary storage of values read from serial port
byte nPossibleEvents = 0; // possible events in the state machine (computed in setup)
int nStates = 0; // Total number of states in the current state machine
int nEvents = 0; // Total number of events recorded while running current state machine
byte previousState = 0; // Previous state visited. Used if 255 is interpreted as a "back" signal (see using255BackSignal above)
int LEDBrightnessAdjustInterval = 5;
byte LEDBrightnessAdjustDirection = 1;
byte LEDBrightness = 0;
byte serialByteBuffer[4] = {0};

// Vars for state machine definitions. Each matrix relates each state to some inputs or outputs.
const byte InputMatrixSize = maxSerialEvents + nDigitalInputs*2;
byte InputStateMatrix[MaxStates+1][InputMatrixSize] = {0}; // Matrix containing all of Bpod's digital inputs and corresponding state transitions
byte StateTimerMatrix[MaxStates+1] = {0}; // Matrix containing states to move to if the state timer elapses
const byte OutputMatrixSize = nOutputs;
byte OutputStateMatrix[MaxStates+1][OutputMatrixSize] = {0}; // Hardware states for outputs. Serial channels > Digital outputs > Virtual (global timer trigger, global timer cancel, global counter reset)
byte smGlobalCounterReset[MaxStates+1] = {0}; // For each state, global counter to reset.
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

// Global timer triggers (data type dependent on number of global timers; using fewer = faster SM switching, extra memory for other configs)
#if globalTimerByteWidth == 1
  uint8_t GlobalTimerOnsetTriggers[nGlobalTimers] = {0}; // Bits indicate other global timers to trigger when timer turns on (after delay)
  uint8_t smGlobalTimerTrig[MaxStates+1] = {0}; // For each state, global timers to trigger. Bits indicate timers.
  uint8_t smGlobalTimerCancel[MaxStates+1] = {0}; // For each state, global timers to cancel. Bits indicate timers.
#elif globalTimerByteWidth == 2
  uint16_t GlobalTimerOnsetTriggers[nGlobalTimers] = {0};
  uint16_t smGlobalTimerTrig[MaxStates+1] = {0};
  uint16_t smGlobalTimerCancel[MaxStates+1] = {0};
#elif globalTimerByteWidth == 4
  uint32_t GlobalTimerOnsetTriggers[nGlobalTimers] = {0};
  uint32_t smGlobalTimerTrig[MaxStates+1] = {0};
  uint32_t smGlobalTimerCancel[MaxStates+1] = {0};
#endif

// Positions of input matrix parts
byte GlobalTimerStartPos = InputMatrixSize; // First global timer event code
byte GlobalTimerEndPos = GlobalTimerStartPos + nGlobalTimers;
byte GlobalCounterPos = GlobalTimerEndPos + nGlobalTimers; // First global counter event code
byte ConditionPos = GlobalCounterPos + nGlobalCounters; // First condition event code
byte TupPos = ConditionPos+nConditions; // First Jump event code
byte DigitalInputPos = maxSerialEvents;


byte GlobalTimerChannel[nGlobalTimers] = {254}; // Channel code for global timer onset/offset.
byte GlobalTimerOnMessage[nGlobalTimers] = {254}; // Message to send when global timer is active (if channel is serial).
byte GlobalTimerOffMessage[nGlobalTimers] = {254}; // Message to send when global timer elapses (if channel is serial).
unsigned long GlobalTimerStart[nGlobalTimers] = {0}; // Future Times when active global timers will start measuring time
unsigned long GlobalTimerEnd[nGlobalTimers] = {0}; // Future Times when active global timers will elapse
unsigned long GlobalTimers[nGlobalTimers] = {0}; // Timers independent of states
unsigned long GlobalTimerOnsetDelays[nGlobalTimers] = {0}; // Onset delay following global timer trigger
unsigned long GlobalTimerLoopIntervals[nGlobalTimers] = {0}; // Configurable delay between global timer loop iterations
byte GlobalTimerLoop[nGlobalTimers] = {0}; // Number of loop iterations. 0 = no loop. 1 = loop until shut-off. 2-255 = number of loops to execute
byte GlobalTimerLoopCount[nGlobalTimers] = {0}; // When GlobalTimerLoop > 1, counts the number of loops elapsed
boolean GTUsingLoopCounter[nGlobalTimers] = {false}; // If this timer's GlobalTimerLoop > 1 (i.e. terminated by loop counter)
byte SendGlobalTimerEvents[nGlobalTimers] = {0}; // true if events are returned to the state machine (especially useful to disable in loop mode)
unsigned long GlobalCounterCounts[nGlobalCounters] = {0}; // Event counters
byte GlobalCounterAttachedEvents[nGlobalCounters] = {254}; // Event each event counter is attached to
unsigned long GlobalCounterThresholds[nGlobalCounters] = {0}; // Event counter thresholds (trigger events if crossed)
byte ConditionChannels[nConditions] = {254}; // Event each channel a condition is attached to
byte ConditionValues[nConditions] = {0}; // The value of each condition
const int MaxTimestamps = 10000;
#if MachineType != 2
  unsigned long Timestamps[MaxTimestamps] = {0};
#endif
unsigned long StateTimers[MaxStates+1] = {0}; // Timers for each state
unsigned long StartTime = 0; // System Start Time
uint64_t MatrixStartTimeMicros = 0; // Start time of state matrix (in us)
uint64_t MatrixEndTimeMicros = 0; // End time of state matrix (in us)
uint32_t currentTimeMicros = 0; // Current time (for detecting 32-bit clock rollovers)
uint32_t lastTimeMicros = 0; // Last time read (for detecting  32-bit clock rollovers)
unsigned long nCyclesCompleted= 0; // Number of HW timer cycles since state matrix started
unsigned long StateStartTime = 0; // Session Start Time
unsigned long NextLEDBrightnessAdjustTime = 0; // Used to fade blue light when disconnected
unsigned long CurrentTime = 0; // Current time (units = timer cycles since start; used to control state transitions)
unsigned long TimeFromStart = 0;
uint64_t sessionStartTimeMicros = 0;
uint32_t nMicrosRollovers = 0; // Number of micros() clock rollovers since session start
boolean cycleMonitoring = 0; // if 1, measures time between hardware timer callbacks when state transitions occur
boolean getModuleInfo = false; // If retrieving module info
unsigned long nBytes = 0; // Number of bytes to read (when transmitting module info)
unsigned long CallbackStartTime = 0; // For self-monitoring to detect hardware timer overruns
unsigned long DiscoveryByteTime = 0; // Last time a discovery byte was sent (for USB serial port auto-discovery)
unsigned long nCycles = 0; // Number of cycles measured since event X
byte connectionState = 0; // 1 if connected to MATLAB
byte RunningStateMatrix = 0; // 1  if state matrix is running
byte firstLoop= 0; // 1 if first timer callback in state matrix
int Ev = 0; // Index of current event
byte nOverrides = 0; // Number of overrides on a line of the state matrix (for compressed transmission scheme)
byte col = 0; byte val = 0; // col and val are used in compression scheme
const uint16_t StateMatrixBufferSize = 50000;
#if MachineType > 1
  byte StateMatrixBuffer[StateMatrixBufferSize] = {0}; // Stores next trial's state matrix
#endif
const uint16_t SerialRelayBufferSize = 256;
byte SerialRelayBuffer[SerialRelayBufferSize] = {0}; // Stores bytes to be transmitted to a serial device (i.e. module, USB)
uint16_t bufferPos = 0;
boolean smaPending = false; // If a state matrix is ready to read into the serial buffer (from USB)
boolean smaReady2Load = false; // If a state matrix was read into the serial buffer and is ready to read into sma vars with LoadStateMatrix()
boolean runFlag = false; // True if a command to run a state matrix arrives while an SM transmission is ongoing. Set to false once new SM starts.
uint16_t nSMBytesRead = 0;

union {
  byte Bytes[maxCurrentEvents*4];
  uint32_t Uint32[maxCurrentEvents];
} CurrentTimeStamps; // For trial timestamp conversion

union {
    byte byteArray[4];
    uint16_t uint16;
    uint32_t uint32;
} typeBuffer; // For general purpose type conversion

union {
    byte byteArray[16];
    uint32_t uint32[4];
    uint64_t uint64[2];
} timeBuffer; // For time transmission on trial end

#if MachineType == 3
  IntervalTimer hardwareTimer;
#endif


void setup() {
// Resolve hardware peripherals from machine type
if (MachineType == 1) {
    usesFRAM = false;
    usesSPISync = true;
    usesSPIValves = true;
    usesUARTInputs = false;
    isolatorHigh = 1;
    isolatorLow = 0;
} else if (MachineType == 2) {
    usesFRAM = true;
    usesSPISync = false;
    usesSPIValves = true;
    usesUARTInputs = true;
    isolatorHigh = 0;
    isolatorLow = 1;
} else if (MachineType == 3) {
    usesFRAM = false;
    usesSPISync = false;
    usesSPIValves = false;
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
  if ((OutputHW[i] == 'B') && (BNCOutputPos == 0)) {
    BNCOutputPos = i;
  }
  if ((OutputHW[i] == 'W') && (WireOutputPos == 0)) {
    WireOutputPos = i;
  }
  if ((OutputHW[i] == 'P') && (PortOutputPos == 0)) {
    PortOutputPos = i;
  }
  if ((OutputHW[i] == 'V') && (ValvePos == 0)) {
    ValvePos = i;
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
        #if MachineType > 1 // NOTE: Previously if FirmwareVerison > 6 (0.7-0.9 but not 0.5 or 1.0.0+)
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
            #if MachineType > 1
              case 2:
                Serial3.begin(SerialBaudRate); Byte1++;
              break;
            #endif  
            #if MachineType == 3
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
      case 'V':
        pinMode(OutputCh[i], OUTPUT);
        digitalWrite(OutputCh[i], LOW);
      break;
      case 'P':
        pinMode(OutputCh[i], OUTPUT);
        analogWrite(OutputCh[i], 0);
        #if MachineType < 3
          PWMChannel[i] = g_APinDescription[OutputCh[i]].ulPWMChannel;
        #endif
      break;
    }
  }
  
  Byte1 = 0;
  pinMode(RedLEDPin, OUTPUT);
  pinMode(GreenLEDPin, OUTPUT);
  pinMode(BlueLEDPin, OUTPUT);
  #if MachineType == 3
    pinMode(ValveEnablePin, OUTPUT);
    digitalWrite(ValveEnablePin, LOW);
  #endif
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
  CurrentEventBuffer[0] = 1;
  SPI.begin();
  updateStatusLED(0); // Begin the blue light display ("Disconnected" state)
  #if MachineType < 3
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
  #if MachineType > 1
    if (smaPending) { // If a request to read a new state matrix arrived during a trial, read here at lower priority (in free time between timer interrupts)
      USBCOM.readByteArray(StateMatrixBuffer, stateMatrixNBytes);
      smaTransmissionConfirmed = true;
      smaReady2Load = true;
      smaPending = false;
    }
  #endif
  currentTimeMicros = micros();
  if (currentTimeMicros < lastTimeMicros) {
    nMicrosRollovers++;
  }
  lastTimeMicros = currentTimeMicros;
}

void handler() { // This is the timer handler function, which is called every (timerPeriod) us
  if (connectionState == 0) { // If not connected to Bpod software
    if (millis() - DiscoveryByteTime > discoveryByteInterval) { // At a fixed interval, send discovery byte to any connected USB serial port
      USBCOM.writeByte(discoveryByte);
      DiscoveryByteTime = millis();
    }
    updateStatusLED(1); // Update the indicator LED (cycles blue intensity)
  }
  if (runFlag) { // If an SM run command was delayed because an SM transmission is ongoing
    if (smaTransmissionConfirmed) {
      runFlag = false;
      startSM();
    }
  }
  if (getModuleInfo) { // If a request was sent for connected modules to return self description (request = byte 255)
    nCycles++; // Count cycles since request was sent
    if (nCycles > ModuleIDTimeout) { // If modules have had time to reply
      getModuleInfo = false; 
      relayModuleInfo(Serial1COM, 1); // Function transmits 0 if no module replied, 1 if found, followed by length of description(bytes), then description
      relayModuleInfo(Serial2COM, 2);
      #if MachineType > 1
        if (nSerialChannels > 3) {
          relayModuleInfo(Serial3COM, 3);
        }
      #endif
      #if MachineType == 3
        relayModuleInfo(Serial4COM, 4);
        relayModuleInfo(Serial5COM, 5);
      #endif
    }
  }
  if ((USBCOM.available() > 0) && (smaPending == false)) { // If a message has arrived on the USB serial port
    CommandByte = USBCOM.readByte();  // P for Program, R for Run, O for Override, 6 for Handshake, F for firmware version, etc
    switch (CommandByte) {
      case '6':  // Initialization handshake
        connectionState = 1;
        updateStatusLED(2);
        USBCOM.writeByte(53);
        delayMicroseconds(100000);
        USBCOM.flush();
        resetSessionClock();
        resetSerialMessages();
        disableModuleRelays();
        #if MachineType == 3
          digitalWrite(ValveEnablePin, HIGH); // Enable valve driver
        #endif
      break;
      case 'F':  // Return firmware and machine type
        USBCOM.writeUint16(FirmwareVersion);
        USBCOM.writeUint16(MachineType);
      break;
      case '*': // Reset session clock
        resetSessionClock();
        USBCOM.writeByte(1);
      break;
      case 'G':  // Return timestamp transmission scheme
        USBCOM.writeByte(LiveTimestamps);
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
        #if MachineType > 1
          while (Serial3COM.available() >0 ) {
             Serial3COM.readByte();
          }
        #endif
        #if MachineType == 3
          while (Serial4COM.available() >0 ) {
             Serial4COM.readByte();
          }
          while (Serial5COM.available() >0 ) {
             Serial5COM.readByte();
          }
        #endif
        Serial1COM.writeByte(255);
        Serial2COM.writeByte(255);
        #if MachineType > 1
          Serial3COM.writeByte(255);
        #endif
        #if MachineType == 3
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
          case 'D':
          case 'B':
          case 'W':
            digitalWriteDirect(OutputCh[Byte1], Byte2);
            outputOverrideState[Byte1] = Byte2;
          break;
          case 'V':
            if (usesSPIValves) {
              outputState[Byte1] = Byte2;
              valveWrite();
            } else {
              digitalWriteDirect(OutputCh[Byte1], Byte2);
            }
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
      case 'Z':  // Bpod governing machine has closed the client program
        disableModuleRelays();
        connectionState = 0;
        connectionState = 0;
        USBCOM.writeByte('1');
        updateStatusLED(0);
        DiscoveryByteTime = millis();
        #if MachineType == 3
          digitalWrite(ValveEnablePin, LOW); // Disable valve driver
        #endif
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
            USBCOM.readByteArray(SerialRelayBuffer, nBytes);
            Serial1COM.writeByteArray(SerialRelayBuffer, nBytes);
          break;
          case 1:
            USBCOM.readByteArray(SerialRelayBuffer, nBytes);
            Serial2COM.writeByteArray(SerialRelayBuffer, nBytes);
          break;
          #if MachineType > 1
            case 2:
              USBCOM.readByteArray(SerialRelayBuffer, nBytes);
              Serial3COM.writeByteArray(SerialRelayBuffer, nBytes);
            break;
          #endif
          #if MachineType == 3
            case 3:
              USBCOM.readByteArray(SerialRelayBuffer, nBytes);
              Serial4COM.writeByteArray(SerialRelayBuffer, nBytes);
            break;
            case 4:
              USBCOM.readByteArray(SerialRelayBuffer, nBytes);
              Serial5COM.writeByteArray(SerialRelayBuffer, nBytes);
            break;
          #endif
         }
      break;
      case 'U': // Recieve serial message index from USB and send corresponding message to hardware serial channel 1-5
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
          #if MachineType > 1
            case 2:
              Serial3COM.writeByteArray(serialByteBuffer, Byte3);
            break;
          #endif
          #if MachineType == 3
            case 3:
              Serial4COM.writeByteArray(serialByteBuffer, Byte3);
            break;
            case 4:
              Serial5COM.writeByteArray(serialByteBuffer, Byte3);
            break;
          #endif
        }
        break;
      case 'L': // Load serial message library
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
      case '~': // USB soft code
        SoftEvent = USBCOM.readByte();
        if (!RunningStateMatrix) {
          SoftEvent = 255; // 255 = No Event
        }
      break;
      case 'C': // Get new compressed state matrix from MATLAB/Python 
        newSMATransmissionStarted = true;
        smaTransmissionConfirmed = false;
        USBCOM.readByteArray(typeBuffer.byteArray, 4);
        RunStateMatrixASAP = typeBuffer.byteArray[0];
        using255BackSignal = typeBuffer.byteArray[1];
        typeBuffer.byteArray[0] = typeBuffer.byteArray[2];
        typeBuffer.byteArray[1] = typeBuffer.byteArray[3];
        stateMatrixNBytes = typeBuffer.uint16;
        if (stateMatrixNBytes < StateMatrixBufferSize) {
          if (RunningStateMatrix) {
            #if MachineType > 1
              nSMBytesRead = 0;
              smaPending = true;
            #else
              USBCOM.writeByte(0);
            #endif
          } else {
            #if MachineType > 1
              USBCOM.readByteArray(StateMatrixBuffer, stateMatrixNBytes); // Read data in 1 batch operation (much faster than item-wise)
              smaTransmissionConfirmed = true;
            #endif
            loadStateMatrix(); // Loads the state matrix from the buffer into the relevant variables
            if (RunStateMatrixASAP) {
              RunStateMatrixASAP = false;
              startSM(); // Start the state matrix without waiting for an explicit 'R' command.
            }
          }
        }
      break;
      case 'R':  // Run State Machine
        startSM();
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
      MatrixStartTimeMicros = sessionTimeMicros(); 
      timeBuffer.uint64[0] = MatrixStartTimeMicros;
      USBCOM.writeByteArray(timeBuffer.byteArray,8); // Send trial-start timestamp (from micros() clock)
      SyncWrite();
      setStateOutputs(CurrentState); // Adjust outputs, global timers, serial codes and sync port for first state
    } else {
      //nCurrentEvents = 0;
      //CurrentEvent[0] = 254; // Event 254 = No event
      CurrentTime++;
      for (int i = BNCInputPos; i < nInputs; i++) {
          if (inputEnabled[i] && !inputOverrideState[i]) {
            inputState[i] = digitalReadDirect(InputCh[i]); 
          } 
      }
      // Determine if a handled condition occurred
      Ev = ConditionPos;
      for (int i = 0; i < nConditionsUsed; i++) {
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
                #if MachineType > 1
                  if (Serial3COM.available()>0) {
                    Byte2 = Serial3COM.readByte();
                    if (Byte2 <= nModuleEvents[2]) {
                      CurrentEvent[nCurrentEvents] = Byte2 + Ev-1; nCurrentEvents++; 
                    }
                  }
                #endif
                Byte1++;
              break;
              case 3:
                #if MachineType == 3
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
                #if MachineType == 3
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
              if (SoftEvent < 255) {
                CurrentEvent[nCurrentEvents] = SoftEvent + Ev; nCurrentEvents++;
                SoftEvent = 255;
              }
          break;
        }
        Ev += nModuleEvents[i];
      }
      Ev = GlobalTimerStartPos;
      // Determine if a global timer expired
      for (int i = 0; i < nGlobalTimersUsed; i++) {
        if (GlobalTimersActive[i] == true) {
          if (CurrentTime >= GlobalTimerEnd[i]) {
            setGlobalTimerChannel(i, 0);
            GlobalTimersTriggered[i] = false;
            GlobalTimersActive[i] = false;
            if (GlobalTimerLoop[i] > 0) {
              if (GlobalTimerLoopCount[i] < GlobalTimerLoop[i])  {
                GlobalTimersTriggered[i] = true;
                GlobalTimerStart[i] = CurrentTime + GlobalTimerLoopIntervals[i];
                GlobalTimerEnd[i] = GlobalTimerStart[i] + GlobalTimers[i];
                if (SendGlobalTimerEvents[i]) {
                  CurrentEvent[nCurrentEvents] = Ev+nGlobalTimers; nCurrentEvents++;
                }
                if (GTUsingLoopCounter[i]) {
                  GlobalTimerLoopCount[i] += 1;
                }
              } else {
                if (SendGlobalTimerEvents[i]) {
                  CurrentEvent[nCurrentEvents] = Ev+nGlobalTimers; nCurrentEvents++;
                }
              }
            } else {
              CurrentEvent[nCurrentEvents] = Ev+nGlobalTimers; nCurrentEvents++;
            }
          }
        } else if (GlobalTimersTriggered[i] == true) {
          if (CurrentTime >= GlobalTimerStart[i]) {
            GlobalTimersActive[i] = true;
            if (GlobalTimerLoop[i]) {
              if (SendGlobalTimerEvents[i]) {
                CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
              }
            } else {
              CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
            }
            if (GlobalTimerOnsetTriggers[i] > 0) {
              for (int j = 0; j < nGlobalTimersUsed; j++) {
                if (bitRead(GlobalTimerOnsetTriggers[i], j)) {
                  if (j != i) {
                    triggerGlobalTimer(j);
                  }
                }
              }
            }
            setGlobalTimerChannel(i, 1);
          }
        }
        Ev++;
      }
      
      Ev = GlobalCounterPos;
      // Determine if a global event counter threshold was exceeded
      for (int x = 0; x < nGlobalCountersUsed; x++) {
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
      NewState = CurrentState;
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
        } else if (CurrentEvent[i] < TupPos) {
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
      #if LiveTimestamps == 0
        #if MachineType == 2
          for (int i = 0; i < nCurrentEvents; i++) {
            CurrentTimeStamps.Uint32[i] = CurrentTime;
            nEvents++;
          }
          digitalWriteDirect(fRAMcs, LOW);
          digitalWriteDirect(fRAMhold, HIGH); // Resume logging
          SPI.transfer(CurrentTimeStamps.Bytes, nCurrentEvents * 4);
          digitalWriteDirect(fRAMhold, LOW); // Pause logging
          digitalWriteDirect(fRAMcs, HIGH);
        #else
          if ((nEvents + nCurrentEvents) < MaxTimestamps) {
            for (int x = 0; x < nCurrentEvents; x++) {
              Timestamps[nEvents] = CurrentTime;
              nEvents++;
            } 
          }
        #endif
      #endif
      // Write events captured to USB (if events were captured)
      if (nCurrentEvents > 0) {
        CurrentEventBuffer[1] = nCurrentEvents;
        for (int i = 2; i < nCurrentEvents+2; i++) {
          CurrentEventBuffer[i] = CurrentEvent[i-2];
        }
        #if LiveTimestamps == 0
          USBCOM.writeByteArray(CurrentEventBuffer, nCurrentEvents+2);
        #else  
          typeBuffer.uint32 = CurrentTime;
          CurrentEventBuffer[nCurrentEvents+2] = typeBuffer.byteArray[0];
          CurrentEventBuffer[nCurrentEvents+3] = typeBuffer.byteArray[1];
          CurrentEventBuffer[nCurrentEvents+4] = typeBuffer.byteArray[2];
          CurrentEventBuffer[nCurrentEvents+5] = typeBuffer.byteArray[3];
          USBCOM.writeByteArray(CurrentEventBuffer, nCurrentEvents+6);
        #endif   
      }
      nCurrentEvents = 0;
      CurrentEvent[0] = 254; // 254 = no event
      // Make state transition if necessary
      if (NewState != CurrentState) {
        if (NewState == nStates) {
          RunningStateMatrix = false;
          MatrixFinished = true;
        } else {
          if (SyncMode == 1) {
            SyncWrite();
          }
          StateStartTime = CurrentTime;
          if (using255BackSignal && (NewState == 255)) {
            CurrentStateTEMP = CurrentState;
            CurrentState = previousState;
            previousState = CurrentStateTEMP;
          } else {
            previousState = CurrentState;
            CurrentState = NewState;
          }
          setStateOutputs(CurrentState);
        }
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
    MatrixEndTimeMicros = sessionTimeMicros();
    resetOutputs();
// Send trial timing data back to computer
    serialByteBuffer[0] = 1; // Op Code for sending events
    serialByteBuffer[1] = 1; // Read one event
    serialByteBuffer[2] = 255; // Send Matrix-end code
    USBCOM.writeByteArray(serialByteBuffer, 3);
    #if LiveTimestamps == 1
      timeBuffer.uint32[0] = CurrentTime;
      timeBuffer.uint32[1] = nCyclesCompleted;
      timeBuffer.uint64[1] = MatrixEndTimeMicros;
      USBCOM.writeByteArray(timeBuffer.byteArray, 16);
      //USBCOM.writeUint32(CurrentTime);
    #else
      USBCOM.writeUint32(nCyclesCompleted);
      timeBuffer.uint64[0] = MatrixEndTimeMicros;
      USBCOM.writeByteArray(timeBuffer.byteArray, 8);
    #endif
    
    #if LiveTimestamps == 0
      USBCOM.writeUint16(nEvents);
      #if MachineType == 2
        // Return event times from fRAM IC
        digitalWriteDirect(fRAMhold, HIGH);
        digitalWriteDirect(fRAMcs, LOW);
        SPI.transfer(3); // Send read op code
        SPI.transfer(0); // Send address bytes
        SPI.transfer(0);
        SPI.transfer(0);
        uint16_t nFullBufferReads = 0; // A buffer array (SerialRelayBuffer) will store data read from RAM and dump it to USB
        uint16_t nRemainderBytes = 0;
        if (nEvents*4 > SerialRelayBufferSize) {
          nFullBufferReads = (unsigned long)(floor(((double)nEvents)*4 / (double)SerialRelayBufferSize));
        } else {
          nFullBufferReads = 0;
        }  
        for (int i = 0; i < nFullBufferReads; i++) { // Full buffer transfers; skipped if nFullBufferReads = 0
          SPI.transfer(SerialRelayBuffer, SerialRelayBufferSize);
          USBCOM.writeByteArray(SerialRelayBuffer, SerialRelayBufferSize);
        }
        nRemainderBytes = (nEvents*4)-(nFullBufferReads*SerialRelayBufferSize);
        if (nRemainderBytes > 0) {
          SPI.transfer(SerialRelayBuffer, nRemainderBytes);
          USBCOM.writeByteArray(SerialRelayBuffer, nRemainderBytes);   
        }
        digitalWriteDirect(fRAMcs, HIGH);
      #else
        USBCOM.writeUint32Array(Timestamps, nEvents);
      #endif  
    #endif   
    MatrixFinished = false;
    if (smaReady2Load) { // If the next trial's state matrix was loaded to the serial buffer during the trial
      loadStateMatrix();
      smaReady2Load = false;
    }
    updateStatusLED(0);
    updateStatusLED(2);
    if (RunStateMatrixASAP) {
      RunStateMatrixASAP = false;
      if (newSMATransmissionStarted){
          if (smaTransmissionConfirmed) {
            startSM();
          } else {
            runFlag = true; // Set run flag to true; new SM will start as soon as its transmission completes
          }
      } else {
        startSM();
      }
    }
  } // End Matrix finished
  nCyclesCompleted++;
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
  uint16_t CurrentTimer = 0; // Used when referring to the timer currently being triggered
  byte CurrentCounter = 0; // Used when referring to the counter currently being reset
  byte thisChannel = 0;
  byte thisMessage = 0;
  byte nMessageBytes = 0;
  boolean reqValveUpdate = false;
  SyncRegWrite((State+1)); // If firmware 0.5 or 0.6, writes current state code to shift register
  
  // Cancel global timers
  CurrentTimer = smGlobalTimerCancel[State];
  if (CurrentTimer > 0) {
    for (int i = 0; i < nGlobalTimersUsed; i++) {
      if (bitRead(CurrentTimer, i)) {
        if (GlobalTimersActive[i]) {
          GlobalTimersTriggered[i] = false;
          GlobalTimersActive[i] = false;
          setGlobalTimerChannel(i, 0);
          CurrentEvent[nCurrentEvents] = i+GlobalTimerEndPos; nCurrentEvents++;
        } else if (GlobalTimersTriggered[i]) {
          GlobalTimersTriggered[i] = false;
        }
      }
    }
  }
  
  // Trigger global timers
  CurrentTimer = smGlobalTimerTrig[State];  
  if (CurrentTimer > 0) {
    for (int i = 0; i < nGlobalTimersUsed; i++) {
      if (bitRead(CurrentTimer, i)) {
        triggerGlobalTimer(i);
      }
    }
  }
  
  // Update output channels
  for (int i = 0; i < nOutputs; i++) {
      switch(OutputHW[i]) {
        case 'U':
        thisMessage = OutputStateMatrix[State][i];
        if (thisMessage > 0) {
          nMessageBytes = SerialMessage_nBytes[thisMessage][thisChannel];
          for (int i = 0; i < nMessageBytes; i++) {
             serialByteBuffer[i] = SerialMessageMatrix[thisMessage][thisChannel][i];
          }
          switch(thisChannel) {
            case 0:
              Serial1COM.writeByteArray(serialByteBuffer, nMessageBytes);
            break;
            case 1:
              Serial2COM.writeByteArray(serialByteBuffer, nMessageBytes);
            break;
            #if MachineType > 1
              case 2:
                Serial3COM.writeByteArray(serialByteBuffer, nMessageBytes);
              break;
            #endif
            #if MachineType == 3
              case 3:
                Serial4COM.writeByteArray(serialByteBuffer, nMessageBytes);
              break;
              case 4:
                Serial5COM.writeByteArray(serialByteBuffer, nMessageBytes);
              break;
            #endif
          }
        }
        thisChannel++;
        break;
        case 'X':
        if (OutputStateMatrix[State][i] > 0) {
          serialByteBuffer[0] = 2; // Code for MATLAB to receive soft-code byte
          serialByteBuffer[1] = OutputStateMatrix[State][i]; // Soft code byte
          USBCOM.writeByteArray(serialByteBuffer, 2);
        }
        break;
        case 'D':
        case 'B':
        case 'W':
          if (outputOverrideState[i] == 0) {
            digitalWriteDirect(OutputCh[i], OutputStateMatrix[State][i]); 
          }
        case 'V':
          if (outputOverrideState[i] == 0) {
            if (usesSPIValves) {
              outputState[i] = OutputStateMatrix[State][i];
              reqValveUpdate = true;
            } else {
              digitalWriteDirect(OutputCh[i], OutputStateMatrix[State][i]); 
            }
          }
        break;
        case 'P':
          if (outputOverrideState[i] == 0) {   
            #if MachineType < 3
              //Arduino Due PERFORMANCE HACK: the next line is equivalent to: analogWrite(OutputCh[i], OutputStateMatrix[State][i]); 
              PWMC_SetDutyCycle(PWM_INTERFACE, PWMChannel[i], OutputStateMatrix[State][i]);
            #else
              analogWrite(OutputCh[i], OutputStateMatrix[State][i]); 
            #endif
          }
        break;
     }
  }
  // Update valves
  if (reqValveUpdate) {
    valveWrite();
    reqValveUpdate = false;
  }
  // Reset event counters
  CurrentCounter = smGlobalCounterReset[State];
  if (CurrentCounter > 0) {
    CurrentCounter = CurrentCounter - 1; // Convert to 0 index
    GlobalCounterCounts[CurrentCounter] = 0;
  }

  // Enable state timer only if handled
  if (StateTimerMatrix[State] != State) {
    MeaningfulStateTimer = true;
  } else {
    MeaningfulStateTimer = false;
  }
}

void triggerGlobalTimer(byte timerID) {
  GlobalTimersTriggered[timerID] = true;
  GlobalTimerStart[timerID] = CurrentTime;
  if (GlobalTimerOnsetDelays[timerID] > 0){
    GlobalTimerStart[timerID] += GlobalTimerOnsetDelays[timerID];
  } else {
    if (!GlobalTimersActive[timerID]) {
      GlobalTimersActive[timerID] = true;
      setGlobalTimerChannel(timerID, 1);
      if (GlobalTimerOnsetTriggers[timerID] > 0) {
        for (int j = 0; j < nGlobalTimersUsed; j++) {
          if (bitRead(GlobalTimerOnsetTriggers[timerID], j)) {
            if (j != timerID) {
              triggerGlobalTimer(j);
            }
          }
        }
      }
      CurrentEvent[nCurrentEvents] = timerID+GlobalTimerStartPos; nCurrentEvents++;
    }
  }
  GlobalTimerEnd[timerID] = GlobalTimerStart[timerID] + GlobalTimers[timerID];
  if (GTUsingLoopCounter[timerID]) {
    GlobalTimerLoopCount[timerID] = 1;
  } 
}

void resetOutputs() {
  for (int i = 0; i < nOutputs; i++) {
    switch (OutputHW[i]) {
      case 'B':
      case 'W':
      case 'V':
        digitalWriteDirect(OutputCh[i], 0);
        outputOverrideState[i] = 0; 
        outputState[i] = 0;
      break;
      case 'P':
        analogWrite(OutputCh[i], 0); 
        outputOverrideState[i] = 0; 
      break;
    }
  }
  valveWrite();
  for (int i = 0; i < nGlobalTimers; i++) {
    GlobalTimersTriggered[i] = false;
    GlobalTimersActive[i] = false;
    GlobalTimerLoopCount[i] = 0;
  }
  for (int i = 0; i < nGlobalCounters; i++) {  
    GlobalCounterCounts[i] = 0;
  }
  MeaningfulStateTimer = false;
}

uint64_t sessionTimeMicros() {
   uint32_t currentTimeMicros = 0;
   uint64_t sessionTime = 0;
   currentTimeMicros = micros();
   sessionTime = ((uint64_t)currentTimeMicros + ((uint64_t)nMicrosRollovers*4294967295)) - sessionStartTimeMicros;
   return sessionTime;
}

void resetSessionClock() {
    sessionStartTimeMicros = micros();
    nMicrosRollovers = 0;
}

void resetSerialMessages() {
  for (int i = 0; i < MaxStates; i++) {
    for (int j = 0; j < nSerialChannels-1; j++) {
      SerialMessageMatrix[i][j][0] = i;
      SerialMessage_nBytes[i][j] = 1;
    }
  }
}

void valveWrite() {
  byte value = 0;
  for (int i = ValvePos; i < nOutputs; i++) {
    if (outputState[i] == 1) {
      bitSet(value, i-ValvePos);
    }
  }
  SPI.transfer(value);
  digitalWriteDirect(valveCSChannel, HIGH);
  digitalWriteDirect(valveCSChannel, LOW);
}

void digitalWriteDirect(int pin, boolean val) { // >10x Faster than digitalWrite(), specific to Arduino Due
  #if MachineType < 3
    if (val) g_APinDescription[pin].pPort -> PIO_SODR = g_APinDescription[pin].ulPin;
    else    g_APinDescription[pin].pPort -> PIO_CODR = g_APinDescription[pin].ulPin;
  #else
    digitalWrite(pin, val);
  #endif
}

byte digitalReadDirect(int pin) { // >10x Faster than digitalRead(), specific to Arduino Due
  #if MachineType < 3
    return !!(g_APinDescription[pin].pPort -> PIO_PDSR & g_APinDescription[pin].ulPin);
  #else
    return digitalRead(pin);
  #endif
}

void setGlobalTimerChannel(byte timerChan, byte op) {
  byte thisChannel = 0; 
  byte thisMessage = 0;
  byte nMessageBytes = 0;
  thisChannel = GlobalTimerChannel[timerChan];
  switch (OutputHW[thisChannel]) {
    case 'U': // UART
      if (op == 1) {
        thisMessage = GlobalTimerOnMessage[timerChan];
      } else {
        thisMessage = GlobalTimerOffMessage[timerChan];
      }
      if (thisMessage < 254) {
        nMessageBytes = SerialMessage_nBytes[thisMessage][thisChannel];
          for (int i = 0; i < nMessageBytes; i++) {
             serialByteBuffer[i] = SerialMessageMatrix[thisMessage][thisChannel][i];
          }
        switch (thisChannel) {
          case 0:
            Serial1COM.writeByteArray(serialByteBuffer, nMessageBytes);
          break;
          case 1:
            Serial2COM.writeByteArray(serialByteBuffer, nMessageBytes);
          break;
          #if MachineType > 1
            case 2:
              Serial3COM.writeByteArray(serialByteBuffer, nMessageBytes);
            break;
          #endif
          #if MachineType == 3
            case 3:
              Serial4COM.writeByteArray(serialByteBuffer, nMessageBytes);
            break;
            case 4:
              Serial5COM.writeByteArray(serialByteBuffer, nMessageBytes);
            break;
          #endif
        }
      }
    break;
    case 'B': // Digital IO (BNC, Wire, Digital, Valve-line)
    case 'W':
    case 'D':
      if (op == 1) {
        digitalWriteDirect(OutputCh[thisChannel], HIGH);
        outputOverrideState[thisChannel] = 1;
      } else {
        digitalWriteDirect(OutputCh[thisChannel], LOW);
        outputOverrideState[thisChannel] = 0;
      }
    break;
    case 'V':
      if (usesSPIValves) {
        outputState[thisChannel] = op;
        valveWrite();
      } else {
        if (op == 1) {
          digitalWriteDirect(OutputCh[thisChannel], HIGH);
        } else {
          digitalWriteDirect(OutputCh[thisChannel], LOW);
        }
      }
      outputOverrideState[thisChannel] = op;
    break;
    case 'P': // Port (PWM / LED)
      if (op == 1) {
        analogWrite(OutputCh[thisChannel], GlobalTimerOnMessage[timerChan]);
        outputOverrideState[thisChannel] = 1;
      } else {
        analogWrite(OutputCh[thisChannel], 0);
        outputOverrideState[thisChannel] = 0;
      }
    break;
  }
  inputState[nInputs+timerChan] = op;
}

void relayModuleInfo(ArCOM serialCOM, byte moduleID) {
  boolean moduleFound = false;
  boolean setBaudRate = false;
  uint32_t newBaudRate = 0;
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
                  serialCOM.readByteArray(SerialRelayBuffer, Byte3);
                  USBCOM.writeByteArray(SerialRelayBuffer, Byte3);
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
          #if MachineType > 1
            case 2:
              Byte3 = Serial3COM.available();
              if (Byte3>0) { 
                for (int j = 0; j < Byte3; j++) {
                   USBCOM.writeByte(Serial3COM.readByte());       
                }
              }
            break;
          #endif
          #if MachineType == 3
            case 3:
                Byte3 = Serial4COM.available();
                if (Byte3>0) { 
                  for (int j = 0; j < Byte3; j++) {
                     USBCOM.writeByte(Serial4COM.readByte());       
                  }
                }
            break;
            case 4:
                Byte3 = Serial5COM.available();
              if (Byte3>0) { 
                for (int j = 0; j < Byte3; j++) {
                   USBCOM.writeByte(Serial5COM.readByte());       
                }
              }
            break;
          #endif
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
              #if MachineType > 1
                case 2:
                  while (Serial3COM.available() > 0) {
                    Serial3COM.readByte(); Byte1++;
                  }
                break;
              #endif
              #if MachineType == 3
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

void loadStateMatrix() { // Loads a state matrix from the serial buffer into the relevant local variables
  #if MachineType > 1
    nStates = StateMatrixBuffer[0];
    nGlobalTimersUsed = StateMatrixBuffer[1];
    nGlobalCountersUsed = StateMatrixBuffer[2];
    nConditionsUsed = StateMatrixBuffer[3];
  #else
    nStates = USBCOM.readByte();
    nGlobalTimersUsed = USBCOM.readByte();
    nGlobalCountersUsed = USBCOM.readByte();
    nConditionsUsed = USBCOM.readByte();
  #endif
  bufferPos = 4; // Current position in serial relay buffer
  for (int x = 0; x < nStates; x++) { // Set matrix to default
    StateTimerMatrix[x] = 0;
    for (int y = 0; y < InputMatrixSize; y++) {
      InputStateMatrix[x][y] = x;
    }
    for (int y = 0; y < OutputMatrixSize; y++) {
      OutputStateMatrix[x][y] = 0;
    }
    smGlobalTimerTrig[x] = 0;
    smGlobalTimerCancel[x] = 0;
    smGlobalCounterReset[x] = 0;
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
  #if MachineType > 1 // Bpod 0.7+; Read state matrix from RAM buffer
    for (int x = 0; x < nStates; x++) { // Get State timer matrix
      StateTimerMatrix[x] = StateMatrixBuffer[bufferPos]; bufferPos++;
    }
    for (int x = 0; x < nStates; x++) { // Get Input Matrix differences
      nOverrides = StateMatrixBuffer[bufferPos]; bufferPos++;
      for (int y = 0; y<nOverrides; y++) {
        col = StateMatrixBuffer[bufferPos]; bufferPos++;
        val = StateMatrixBuffer[bufferPos]; bufferPos++;
        InputStateMatrix[x][col] = val;
      }
    }
    for (int x = 0; x < nStates; x++) { // Get Output Matrix differences
      nOverrides = StateMatrixBuffer[bufferPos]; bufferPos++;
      for (int y = 0; y<nOverrides; y++) {
        col = StateMatrixBuffer[bufferPos]; bufferPos++;
        val = StateMatrixBuffer[bufferPos]; bufferPos++;
        OutputStateMatrix[x][col] = val;
      }
    }
    for (int x = 0; x < nStates; x++) { // Get Global Timer Start Matrix differences
      nOverrides = StateMatrixBuffer[bufferPos]; bufferPos++;
      if (nOverrides > 0) {
        for (int y = 0; y<nOverrides; y++) {
          col = StateMatrixBuffer[bufferPos]; bufferPos++;
          val = StateMatrixBuffer[bufferPos]; bufferPos++;
          GlobalTimerStartMatrix[x][col] = val;
        }
      }
    }
    for (int x = 0; x < nStates; x++) { // Get Global Timer End Matrix differences
      nOverrides = StateMatrixBuffer[bufferPos]; bufferPos++;
      if (nOverrides > 0) {
        for (int y = 0; y<nOverrides; y++) {
          col = StateMatrixBuffer[bufferPos]; bufferPos++;
          val = StateMatrixBuffer[bufferPos]; bufferPos++;
          GlobalTimerEndMatrix[x][col] = val;
        }
      }
    }
    for (int x = 0; x < nStates; x++) { // Get Global Counter Matrix differences
      nOverrides = StateMatrixBuffer[bufferPos]; bufferPos++;
      if (nOverrides > 0) {
        for (int y = 0; y<nOverrides; y++) {
          col = StateMatrixBuffer[bufferPos]; bufferPos++;
          val = StateMatrixBuffer[bufferPos]; bufferPos++;
          GlobalCounterMatrix[x][col] = val;
        }
      }
    }
    for (int x = 0; x < nStates; x++) { // Get Condition Matrix differences
      nOverrides = StateMatrixBuffer[bufferPos]; bufferPos++;
      if (nOverrides > 0) {
        for (int y = 0; y<nOverrides; y++) {
          col = StateMatrixBuffer[bufferPos]; bufferPos++;
          val = StateMatrixBuffer[bufferPos]; bufferPos++;
          ConditionMatrix[x][col] = val;
        }
      }
    }
    for (int i = 0; i < nGlobalTimersUsed; i++) {
      GlobalTimerChannel[i] = StateMatrixBuffer[bufferPos]; bufferPos++;
    }
    for (int i = 0; i < nGlobalTimersUsed; i++) {
      GlobalTimerOnMessage[i] = StateMatrixBuffer[bufferPos]; bufferPos++;
    }
    for (int i = 0; i < nGlobalTimersUsed; i++) {
      GlobalTimerOffMessage[i] = StateMatrixBuffer[bufferPos]; bufferPos++;
    }
    for (int i = 0; i < nGlobalTimersUsed; i++) {
      GlobalTimerLoop[i] = StateMatrixBuffer[bufferPos]; bufferPos++;
      if (GlobalTimerLoop[i] > 1) {
        GTUsingLoopCounter[i] = true;
      } else {
        GTUsingLoopCounter[i] = false;
      }
    }
    for (int i = 0; i < nGlobalTimersUsed; i++) {
      SendGlobalTimerEvents[i] = StateMatrixBuffer[bufferPos]; bufferPos++;
    }
    for (int i = 0; i < nGlobalCountersUsed; i++) {
      GlobalCounterAttachedEvents[i] = StateMatrixBuffer[bufferPos]; bufferPos++;
    }
    for (int i = 0; i < nConditionsUsed; i++) {
      ConditionChannels[i] = StateMatrixBuffer[bufferPos]; bufferPos++;
    }
    for (int i = 0; i < nConditionsUsed; i++) {
      ConditionValues[i] = StateMatrixBuffer[bufferPos]; bufferPos++;
    }
    for (int i = 0; i < nStates; i++) {
      smGlobalCounterReset[i] = StateMatrixBuffer[bufferPos]; bufferPos++;
    }

    #if globalTimerByteWidth == 1
        for (int i = 0; i < nStates; i++) {
          smGlobalTimerTrig[i] = StateMatrixBuffer[bufferPos]; bufferPos++;
        }
        for (int i = 0; i < nStates; i++) {
          smGlobalTimerCancel[i] = StateMatrixBuffer[bufferPos]; bufferPos++;
        }
        for (int i = 0; i < nGlobalTimersUsed; i++) {
          GlobalTimerOnsetTriggers[i] = StateMatrixBuffer[bufferPos]; bufferPos++;
        }
    #elif globalTimerByteWidth == 2
        for (int i = 0; i < nStates; i++) {
          typeBuffer.byteArray[0] = StateMatrixBuffer[bufferPos]; bufferPos++;
          typeBuffer.byteArray[1] = StateMatrixBuffer[bufferPos]; bufferPos++;
          smGlobalTimerTrig[i] = typeBuffer.uint16;
        }
        for (int i = 0; i < nStates; i++) {
          typeBuffer.byteArray[0] = StateMatrixBuffer[bufferPos]; bufferPos++;
          typeBuffer.byteArray[1] = StateMatrixBuffer[bufferPos]; bufferPos++;
          smGlobalTimerCancel[i] = typeBuffer.uint16;
        }
        for (int i = 0; i < nGlobalTimersUsed; i++) {
          typeBuffer.byteArray[0] = StateMatrixBuffer[bufferPos]; bufferPos++;
          typeBuffer.byteArray[1] = StateMatrixBuffer[bufferPos]; bufferPos++;
          GlobalTimerOnsetTriggers[i] = typeBuffer.uint16;
        }
     #elif globalTimerByteWidth == 4
        for (int i = 0; i < nStates; i++) {
          typeBuffer.byteArray[0] = StateMatrixBuffer[bufferPos]; bufferPos++;
          typeBuffer.byteArray[1] = StateMatrixBuffer[bufferPos]; bufferPos++;
          typeBuffer.byteArray[2] = StateMatrixBuffer[bufferPos]; bufferPos++;
          typeBuffer.byteArray[3] = StateMatrixBuffer[bufferPos]; bufferPos++;
          smGlobalTimerTrig[i] = typeBuffer.uint32;
        }
        for (int i = 0; i < nStates; i++) {
          typeBuffer.byteArray[0] = StateMatrixBuffer[bufferPos]; bufferPos++;
          typeBuffer.byteArray[1] = StateMatrixBuffer[bufferPos]; bufferPos++;
          typeBuffer.byteArray[2] = StateMatrixBuffer[bufferPos]; bufferPos++;
          typeBuffer.byteArray[3] = StateMatrixBuffer[bufferPos]; bufferPos++;
          smGlobalTimerCancel[i] = typeBuffer.uint32;
        }
        for (int i = 0; i < nGlobalTimersUsed; i++) {
          typeBuffer.byteArray[0] = StateMatrixBuffer[bufferPos]; bufferPos++;
          typeBuffer.byteArray[1] = StateMatrixBuffer[bufferPos]; bufferPos++;
          typeBuffer.byteArray[2] = StateMatrixBuffer[bufferPos]; bufferPos++;
          typeBuffer.byteArray[3] = StateMatrixBuffer[bufferPos]; bufferPos++;
          GlobalTimerOnsetTriggers[i] = typeBuffer.uint32;
        }
    #endif
    for (int i = 0; i < nStates; i++) {
      typeBuffer.byteArray[0] = StateMatrixBuffer[bufferPos]; bufferPos++;
      typeBuffer.byteArray[1] = StateMatrixBuffer[bufferPos]; bufferPos++;
      typeBuffer.byteArray[2] = StateMatrixBuffer[bufferPos]; bufferPos++;
      typeBuffer.byteArray[3] = StateMatrixBuffer[bufferPos]; bufferPos++;
      StateTimers[i] = typeBuffer.uint32;
    }
    for (int i = 0; i < nGlobalTimersUsed; i++) {
      typeBuffer.byteArray[0] = StateMatrixBuffer[bufferPos]; bufferPos++;
      typeBuffer.byteArray[1] = StateMatrixBuffer[bufferPos]; bufferPos++;
      typeBuffer.byteArray[2] = StateMatrixBuffer[bufferPos]; bufferPos++;
      typeBuffer.byteArray[3] = StateMatrixBuffer[bufferPos]; bufferPos++;
      GlobalTimers[i] = typeBuffer.uint32;
    }
    for (int i = 0; i < nGlobalTimersUsed; i++) {
      typeBuffer.byteArray[0] = StateMatrixBuffer[bufferPos]; bufferPos++;
      typeBuffer.byteArray[1] = StateMatrixBuffer[bufferPos]; bufferPos++;
      typeBuffer.byteArray[2] = StateMatrixBuffer[bufferPos]; bufferPos++;
      typeBuffer.byteArray[3] = StateMatrixBuffer[bufferPos]; bufferPos++;
      GlobalTimerOnsetDelays[i] = typeBuffer.uint32;
    }
    for (int i = 0; i < nGlobalTimersUsed; i++) {
      typeBuffer.byteArray[0] = StateMatrixBuffer[bufferPos]; bufferPos++;
      typeBuffer.byteArray[1] = StateMatrixBuffer[bufferPos]; bufferPos++;
      typeBuffer.byteArray[2] = StateMatrixBuffer[bufferPos]; bufferPos++;
      typeBuffer.byteArray[3] = StateMatrixBuffer[bufferPos]; bufferPos++;
      GlobalTimerLoopIntervals[i] = typeBuffer.uint32;
    }
    for (int i = 0; i < nGlobalCountersUsed; i++) {
      typeBuffer.byteArray[0] = StateMatrixBuffer[bufferPos]; bufferPos++;
      typeBuffer.byteArray[1] = StateMatrixBuffer[bufferPos]; bufferPos++;
      typeBuffer.byteArray[2] = StateMatrixBuffer[bufferPos]; bufferPos++;
      typeBuffer.byteArray[3] = StateMatrixBuffer[bufferPos]; bufferPos++;
      GlobalCounterThresholds[i] = typeBuffer.uint32;
    }
  #else // Bpod 0.5; Read state matrix from serial port
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
    if (nGlobalTimersUsed > 0) {
      USBCOM.readByteArray(GlobalTimerChannel, nGlobalTimersUsed); // Get output channels of global timers
      USBCOM.readByteArray(GlobalTimerOnMessage, nGlobalTimersUsed); // Get serial messages to trigger on timer start
      USBCOM.readByteArray(GlobalTimerOffMessage, nGlobalTimersUsed); // Get serial messages to trigger on timer end
      USBCOM.readByteArray(GlobalTimerLoop, nGlobalTimersUsed); // Get global timer loop state (true/false)
      for (int i = 0; i < nGlobalTimersUsed; i++) {
        if (GlobalTimerLoop[i] > 1) {
          GTUsingLoopCounter[i] = true;
        } else {
          GTUsingLoopCounter[i] = false;
        }
      }
      USBCOM.readByteArray(SendGlobalTimerEvents, nGlobalTimersUsed); // Send global timer events (enabled/disabled)
    }
    if (nGlobalCountersUsed > 0) {
      USBCOM.readByteArray(GlobalCounterAttachedEvents, nGlobalCountersUsed); // Get global counter attached events
    }
    if (nConditionsUsed > 0) {
      USBCOM.readByteArray(ConditionChannels, nConditionsUsed); // Get condition channels
      USBCOM.readByteArray(ConditionValues, nConditionsUsed); // Get condition values
    }
    USBCOM.readByteArray(smGlobalCounterReset, nStates);
    #if globalTimerByteWidth == 1
        USBCOM.readByteArray(smGlobalTimerTrig, nStates);
        USBCOM.readByteArray(smGlobalTimerCancel, nStates);
        USBCOM.readByteArray(GlobalTimerOnsetTriggers, nGlobalTimersUsed);
    #elif globalTimerByteWidth == 2
        USBCOM.readUint16Array(smGlobalTimerTrig, nStates);
        USBCOM.readUint16Array(smGlobalTimerCancel, nStates);
        USBCOM.readUint16Array(GlobalTimerOnsetTriggers, nGlobalTimersUsed);
    #elif globalTimerByteWidth == 4
        USBCOM.readUint32Array(smGlobalTimerTrig, nStates);
        USBCOM.readUint32Array(smGlobalTimerCancel, nStates);
        USBCOM.readUint32Array(GlobalTimerOnsetTriggers, nGlobalTimersUsed);
    #endif
    
    USBCOM.readUint32Array(StateTimers, nStates); // Get state timers
    if (nGlobalTimersUsed > 0) {
      USBCOM.readUint32Array(GlobalTimers, nGlobalTimersUsed); // Get global timers
      USBCOM.readUint32Array(GlobalTimerOnsetDelays, nGlobalTimersUsed); // Get global timer onset delays
      USBCOM.readUint32Array(GlobalTimerLoopIntervals, nGlobalTimersUsed); // Get loop intervals
    }
    if (nGlobalCountersUsed > 0) {
      USBCOM.readUint32Array(GlobalCounterThresholds, nGlobalCountersUsed); // Get global counter event count thresholds
    }
    smaTransmissionConfirmed = true;
  #endif
}
void startSM() {  
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
  previousState = 0;
  CurrentState = 0;
  nEvents = 0;
  SoftEvent = 255; // No event
  MatrixFinished = false;
  #if LiveTimestamps == 0
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
  #endif
  // Reset event counters
  for (int i = 0; i < nGlobalCounters; i++) {
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
  for (int i = nInputs; i < nInputs+nGlobalTimers; i++) { // Clear global timer virtual lines
    inputState[i] = 0;
  }
  clearSerialBuffers();
  // Reset timers
  StateStartTime = 0;
  CurrentTime = 0;
  nCurrentEvents = 0;
  nCyclesCompleted = 0;
  CurrentEvent[0] = 254; // 254 = no event
  RunningStateMatrix = 1;
  firstLoop = 1;
}

