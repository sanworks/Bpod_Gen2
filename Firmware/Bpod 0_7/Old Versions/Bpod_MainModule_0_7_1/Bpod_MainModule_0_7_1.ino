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
// Bpod Finite State Machine v 0.7
//
// Requires the DueTimer library from:
// https://github.com/ivanseidel/DueTimer
//
// Also requires a small modification to Arduino, for useful PWM control of light intensity with small (1-10ms) pulses:
// change the PWM_FREQUENCY and TC_FREQUENCY constants to 50000 in the file /Arduino/hardware/arduino/sam/variants/arduino_due_x/variant.h
// or in Windows, \Users\Username\AppData\Local\Arduino15\packages\arduino\hardware\sam\1.6.7\variants\arduino_due_x\variant.h

#include <DueTimer.h>
#include <SPI.h>
#include "ArCOM.h" // ArCOM is a serial interface wrapper developed by Sanworks, to streamline transmission of datatypes and arrays over serial
#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256
ArCOM BpodUSB(SerialUSB); // Creates an ArCOM object called BpodUSB, wrapping SerialUSB
byte FirmwareBuildVersion = 8; // 7 = Bpod 0.6 8 = Bpod 0.7

//////////////////////////////
// Hardware mapping:         /
//////////////////////////////

//     8 Sensor/Valve/LED Ports
byte PortDigitalInputLines[8] = {28, 30, 32, 34, 36, 38, 40, 42};
byte PortPWMOutputLines[8] = {9, 8, 7, 6, 5, 4, 3, 2};

//     wire
byte WireDigitalInputLines[2] = {31, 29};
byte WireDigitalOutputLines[3] = {43, 41, 39};

//     SPI device pins
byte ValveRegisterLatch = 22;
byte fRAMcs = 1;
byte fRAMhold = A3;

//      Bnc
byte BncOutputLines[2] = {25, 24};
byte BncInputLines[2] = {10, 11};

//      Indicator
byte RedLEDPin = 13;
byte GreenLEDPin = 33;
byte BlueLEDPin = 12;

// BNC Optoisolator
boolean IsolatorHighLevel = 0;
boolean IsolatorLowLevel = 1;

//////////////////////////////////
// Initialize system state vars: /
//////////////////////////////////

byte PortPWMOutputState[8] = {0}; // State of all 8 output lines (As 8-bit PWM value from 0-255 representing duty cycle. PWM cycles at 1KHZ)
byte PortValveOutputState = 0;   // State of all 8 valves
byte PortInputsEnabled[8] = {0}; // Enabled or disabled input reads of port IR lines
boolean PortInputLineValue[8] = {0}; // Direct reads of digital values of IR beams
boolean PortInputLineOverride[8] = {0}; // set to 1 if user created a virtual input, to prevent hardware reads until user returns it to low
boolean PortInputLineLastKnownStatus[8] = {0}; // Last known status of IR beams
boolean BNCInputLineValue[2] = {0}; // Direct reads of BNC input lines
boolean BNCInputLineOverride[2] = {0}; // Set to 1 if user created a virtual BNC high event, to prevent hardware reads until user returns low
boolean BNCInputLineLastKnownStatus[2] = {0}; // Last known status of BNC input lines
boolean WireInputLineValue[4] = {0}; // Direct reads of Wire terminal input lines
boolean WireInputLineOverride[2] = {0}; // Set to 1 if user created a virtual wire high event, to prevent hardware reads until user returns low
boolean WireInputLineLastKnownStatus[4] = {0}; // Last known status of Wire terminal input lines
boolean MatrixFinished = false; // Has the system exited the matrix (final state)?
boolean MatrixAborted = false; // Has the user aborted the matrix before the final state?
boolean MeaningfulStateTimer = false; // Does this state's timer get us to another state when it expires?
int CurrentState = 1; // What state is the state machine currently in? (State 0 is the final state)
int NewState = 1;
byte CurrentEvent[10] = {0}; // What event code just happened and needs to be handled. Up to 10 can be acquired per 30us loop.
byte nCurrentEvents = 0; // Index of current event
byte SoftEvent = 0; // What soft event code just happened
byte SyncChannel = 0; // 0 if no sync codes, 1 if BNC output channel 2, 2 if Port 8 LED channel, 3 if wire terminal output ch3, 4 if serial ch3
byte SyncMode = 0; // 0 if low > high on trial start and high < low on trial end, 1 if line toggles with each state change
byte SyncState = 0; // State of the sync line (0 = low, 1 = high)
byte nBNCChannels = 2; // Set to 1 if sync channel is BNC ch2 
byte nWireOutputChannels = 3; // Set to 2 if sync channel is wire ch3
byte nPorts = 8; // Set to 7 if sync channel is port 8 LED

//////////////////////////////////
// Initialize general use vars:  /
//////////////////////////////////

byte CommandByte = 0;  // Op code to specify handling of an incoming USB serial message
byte VirtualEventTarget = 0; // Op code to specify which virtual event type (Port, BNC, etc)
byte VirtualEventData = 0; // State of target
byte Byte1 = 0; byte Byte2 = 0; byte Byte3 = 0; byte Byte4 = 0; // Temporary storage of command and param values read from serial port
unsigned long LongInt = 0;
int nStates = 0;
int nEvents = 0;
int LEDBrightnessAdjustInterval = 5;
byte LEDBrightnessAdjustDirection = 1;
byte LEDBrightness = 0;
byte serialByteBuffer[4] = {0};
byte InputStateMatrix[257][69] = {0}; // Matrix containing all of Bpod's inputs and corresponding state transitions
// Cols: 0-15 = IR beam in...out... 16-19 = BNC1 high...low 20-27 = wire1high...low 28-37=SoftEvents 38=Unused  39=Tup
byte OutputStateMatrix[257][18] = {0}; // Matrix containing all of Bpod's output actions for each Input state
// Cols: 0=Valves 1=BNC 2=Wire 3-5 =Hardware serial (UART) 6 = SoftCode 7=GlobalTimerTrig 8=GlobalTimerCancel
// 9 = GlobalCounterReset 10-17=PWM values (LED channel on port interface board)
byte GlobalTimerMatrix[257][5] = {0}; // Matrix contatining state transitions for global timer elapse events
byte GlobalCounterMatrix[257][5] = {0}; // Matrix contatining state transitions for global counter threshold events
byte ConditionMatrix[257][5] = {0}; // Matrix contatining state transitions for conditions
boolean GlobalTimersActive[5] = {0}; // 0 if timer x is inactive, 1 if it's active.

// To implement
boolean GlobalTimerLoop[5] = {0}; // 0 if timer is one-shot, 1 if loops until matrix end or cancel event.
byte GlobalTimerLinkedChannel[5] = {0}; // Channel code for global timer onset/offset.
byte GlobalTimerLinkedChannelValue[5] = {0}; // Value of channel when global timer is active.

unsigned long GlobalTimerEnd[5] = {0}; // Future Times when active global timers will elapse
unsigned long GlobalTimers[5] = {0}; // Timers independent of states
unsigned long GlobalCounterCounts[5] = {0}; // Event counters
byte GlobalCounterAttachedEvents[5] = {254}; // Event each event counter is attached to
unsigned long GlobalCounterThresholds[5] = {0}; // Event counter thresholds (trigger events if crossed)
byte ConditionChannels[5] = {254}; // Event each channel a condition is attached to
byte ConditionValues[5] = {0}; // The value of each condition
byte ChannelLogic[12] = {0}; // Each digital channel has a number: 1-8 = port i/o, 9-10 = BNC, 11-13 = wire
int CurrentColumn = 0; // Used when re-mapping event codes to columns of global timer and counter matrices
unsigned long StateTimers[257] = {0}; // Timers for each state
unsigned long StartTime = 0; // System Start Time
unsigned long MatrixStartTime = 0; // Trial Start Time
unsigned long MatrixStartTimeMillis = 0; // Used for 32-bit timer wrap-over correction in client
unsigned long StateStartTime = 0; // Session Start Time
unsigned long NextLEDBrightnessAdjustTime = 0; // Used to fade blue light when disconnected
unsigned long CurrentTime = 0; // Current time (units = timer cycles since start; used to control state transitions)
unsigned long TimeFromStart = 0;
unsigned long SessionStartTime = 0;
byte connectionState = 0; // 1 if connected to MATLAB
byte RunningStateMatrix = 0; // 1 if state matrix is running
byte firstLoop= 0; // 1 if first timer callback in state matrix
int Ev = 0; // Index of current event
byte nOverrides = 0; // Number of overrides on a line of the state matrix (for compressed transmission scheme)
byte col = 0; byte val = 0; // col and val are used in compression scheme
union {
  byte Bytes[20];
  int32_t Uint32[5];
} TrialTimeStamps;

void setup() {
  if (FirmwareBuildVersion < 7) {
    IsolatorHighLevel = 1; // The new optoisolator in Bpod 0.6 has an inverting output
    IsolatorLowLevel = 0;
    BncInputLines[0] = 11; // An old quirk was fixed in Bpod0.6 - the BNC channels were wired in reverse order on the board
    BncInputLines[1] = 10;
  }
  for (int x = 0; x < 8; x++) { // Configure port PWM channels and input lines
    pinMode(PortDigitalInputLines[x], INPUT_PULLUP);
    pinMode(PortPWMOutputLines[x], OUTPUT);
    analogWrite(PortPWMOutputLines[x], 0);
  }
  for (int x = 0; x < 2; x++) { // Configure wire terminal lines
    pinMode(WireDigitalInputLines[x], INPUT);
    WireInputLineValue[x] = IsolatorLowLevel;
    WireInputLineLastKnownStatus[x] = IsolatorLowLevel;
  }
  for (int x = 0; x < 3; x++) {
    pinMode(WireDigitalOutputLines[x], OUTPUT);
    digitalWrite(WireDigitalOutputLines[x], LOW);
  }
  for (int x = 0; x < 2; x++) { // Configure BNC lines
    pinMode(BncInputLines[x], INPUT);
    pinMode(BncOutputLines[x], OUTPUT);
    BNCInputLineLastKnownStatus[x] = IsolatorLowLevel;
  }
  pinMode(ValveRegisterLatch, OUTPUT); // CS pin for the valve shift register on the SPI bus
  pinMode(fRAMcs, OUTPUT); // CS pin for the fRAM IC
  pinMode(fRAMhold, OUTPUT); // Hold pin for the fRAM IC
  pinMode(RedLEDPin, OUTPUT);
  pinMode(GreenLEDPin, OUTPUT);
  pinMode(BlueLEDPin, OUTPUT);
  digitalWrite(fRAMcs, HIGH);
  digitalWrite(fRAMhold, HIGH);
  SerialUSB.begin(115200);
  Serial1.begin(1312500); // Serial1 and 2 and 3 are the hardware UART serial ports, labeled "Serial1" - "Serial3" on the enclosure
  Serial2.begin(1312500); // 1312500 // 2625000
  Serial3.begin(1312500); // 2625000
  SPI.begin();
  SetWireOutputLines(0); // Make sure all wire terminal outputs are low
  SetBNCOutputLines(0); // Make sure all wire BNC outputs are low
  updateStatusLED(0); // Begin the blue light display ("Disconnected" state)
  ValveRegWrite(0); // Make sure all valves are closed
  Timer3.attachInterrupt(handler); // Timer3 is a hardware timer, which will trigger the function "handler" precisely every 100us
  Timer3.start(100); // Set hardware timer to 100us and start
}

void loop() {
  // Do nothing
}

void handler() { // This is the timer handler function, which is called every 100us
  if (connectionState == 0) {
    updateStatusLED(1);
  }
  if (BpodUSB.available() > 0) { // If a message has arrived on the USB serial port
    CommandByte = BpodUSB.readByte();  // P for Program, R for Run, O for Override, 6 for Handshake, F for firmware version
    switch (CommandByte) {
      case '6':  // Initialization handshake
        connectionState = 1;
        updateStatusLED(2);
        BpodUSB.writeByte(53);
        delayMicroseconds(100000);
        BpodUSB.flush();
        SessionStartTime = millis();
        break;
      case 'F':  // Return firmware build number
        BpodUSB.writeByte(FirmwareBuildVersion);
        break;
      case 'K': // Set sync channel and mode
        SyncChannel = BpodUSB.readByte();
        SyncMode = BpodUSB.readByte();
        switch (SyncChannel) {
          case 0:
            nBNCChannels = 2;
            nWireOutputChannels = 3; 
            nPorts = 8; 
          break;
          case 1:
            nBNCChannels = 1;
            nWireOutputChannels = 3; 
            nPorts = 8; 
          break;
          case 2:
            nBNCChannels = 2;
            nWireOutputChannels = 3; 
            nPorts = 7; 
          break;
          case 3:
            nBNCChannels = 2;
            nWireOutputChannels = 2; 
            nPorts = 8; 
          break;
          case 4:
            nBNCChannels = 2;
            nWireOutputChannels = 3; 
            nPorts = 8; 
          break;
        }
        break;
      case 'O':  // Override hardware state
        manualOverrideOutputs();
        break;
      case 'I': // Read and return digital input line states (for debugging)
        Byte1 = BpodUSB.readByte();
        Byte2 = BpodUSB.readByte();
        switch (Byte1) {
          case 'B': // Read BNC input line
            Byte3 = digitalReadDirect(BncInputLines[Byte2]);
            break;
          case 'P': // Read port digital input line
            Byte3 = digitalReadDirect(PortDigitalInputLines[Byte2]);
            break;
          case 'W': // Read wire digital input line
            Byte3 = digitalReadDirect(WireDigitalInputLines[Byte2]);
            break;
        }
        BpodUSB.writeByte(Byte3);
        break;
      case 'Z':  // Bpod governing machine has closed the client program
        connectionState = 0;
        connectionState = 0;
        BpodUSB.writeByte('1');
        updateStatusLED(0);
        break;
      case 'S': // Soft code.
        VirtualEventTarget = BpodUSB.readByte(); // P for virtual port entry, B for BNC, W for wire, S for soft event
        VirtualEventData = BpodUSB.readByte();
        break;
      case 'H': // Recieve byte from USB and send to hardware serial channel 1-3
        Byte1 = BpodUSB.readByte();
        Byte2 = BpodUSB.readByte();
        switch (Byte1) {
          case 1:
            Serial1.write(Byte2);
            break;
          case 2:
            Serial2.write(Byte2);
            break;
          case 3:
            Serial3.write(Byte2);
            break;
        }
        break;
      case 'V': // Manual override: execute virtual event
        VirtualEventTarget = BpodUSB.readByte();
        VirtualEventData = BpodUSB.readByte();
        if (RunningStateMatrix) {
          switch (VirtualEventTarget) {
            case 'P': // Virtual poke
              if (PortInputLineLastKnownStatus[VirtualEventData] == LOW) {
                PortInputLineValue[VirtualEventData] = HIGH;
                PortInputLineOverride[VirtualEventData] = true;
              } else {
                PortInputLineValue[VirtualEventData] = LOW;
                PortInputLineOverride[VirtualEventData] = false;
              }
              break;
            case 'B': // Virtual BNC input
              if (BNCInputLineLastKnownStatus[VirtualEventData] == IsolatorLowLevel) {
                BNCInputLineValue[VirtualEventData] = IsolatorHighLevel;
                BNCInputLineOverride[VirtualEventData] = true;
              } else {
                BNCInputLineValue[VirtualEventData] = IsolatorLowLevel;
                BNCInputLineOverride[VirtualEventData] = false;
              }
              break;
            case 'W': // Virtual Wire input
              if (WireInputLineLastKnownStatus[VirtualEventData] == IsolatorLowLevel) {
                WireInputLineValue[VirtualEventData] = IsolatorHighLevel;
                WireInputLineOverride[VirtualEventData] = true;
              } else {
                WireInputLineValue[VirtualEventData] = IsolatorLowLevel;
                WireInputLineOverride[VirtualEventData] = false;
              }
              break;
            case 'S':  // Soft event
              SoftEvent = VirtualEventData;
              break;
          }
        } break;
      case 'C': // Get new compressed state matrix from client
        nStates = BpodUSB.readByte();
        for (int x = 0; x < nStates; x++) { // Set matrix to default
          for (int y = 0; y < 69; y++) {
            InputStateMatrix[x][y] = x;
          }
          for (int y = 0; y < 18; y++) {
            OutputStateMatrix[x][y] = 0;
          }
          for (int y = 0; y < 5; y++) {
            GlobalTimerMatrix[x][y] = x;
          }
          for (int y = 0; y < 5; y++) {
            GlobalCounterMatrix[x][y] = x;
          }
          for (int y = 0; y < 5; y++) {
            ConditionMatrix[x][y] = x;
          }
        }
        for (int x = 0; x < nStates; x++) { // Get Input Matrix differences
          nOverrides = BpodUSB.readByte();
          for (int y = 0; y<nOverrides; y++) {
            col = BpodUSB.readByte();
            val = BpodUSB.readByte();
            InputStateMatrix[x][col] = val;
          }
        }
        for (int x = 0; x < nStates; x++) { // Get Output Matrix differences
          nOverrides = BpodUSB.readByte();
          for (int y = 0; y<nOverrides; y++) {
            col = BpodUSB.readByte();
            val = BpodUSB.readByte();
            OutputStateMatrix[x][col] = val;
          }
        }
        for (int x = 0; x < nStates; x++) { // Get Global Timer Matrix differences
          nOverrides = BpodUSB.readByte();
          if (nOverrides > 0) {
            for (int y = 0; y<nOverrides; y++) {
              col = BpodUSB.readByte();
              val = BpodUSB.readByte();
              GlobalTimerMatrix[x][col] = val;
            }
          }
        }
        for (int x = 0; x < nStates; x++) { // Get Global Counter Matrix differences
          nOverrides = BpodUSB.readByte();
          if (nOverrides > 0) {
            for (int y = 0; y<nOverrides; y++) {
              col = BpodUSB.readByte();
              val = BpodUSB.readByte();
              GlobalCounterMatrix[x][col] = val;
            }
          }
        }
        for (int x = 0; x < nStates; x++) { // Get Condition Matrix differences
          nOverrides = BpodUSB.readByte();
          if (nOverrides > 0) {
            for (int y = 0; y<nOverrides; y++) {
              col = BpodUSB.readByte();
              val = BpodUSB.readByte();
              ConditionMatrix[x][col] = val;
            }
          }
        }
        BpodUSB.readByteArray(GlobalCounterAttachedEvents, 5); // Get global counter attached events
        BpodUSB.readByteArray(ConditionChannels, 5); // Get condition channels
        BpodUSB.readByteArray(ConditionValues, 5); // Get condition values
        BpodUSB.readByteArray(PortInputsEnabled, 8); // Get input channel configurtaion
        BpodUSB.readUint32Array(StateTimers, nStates); // Get state timers
        BpodUSB.readUint32Array(GlobalTimers, 5); // Get global timers
        BpodUSB.readUint32Array(GlobalCounterThresholds, 5); // Get global counter event count thresholds
        BpodUSB.writeByte(1);
      break;
      case 'P':  // Get new state matrix from client
        nStates = BpodUSB.readByte();
        // Get Input state matrix
        for (int x = 0; x < nStates; x++) {
          for (int y = 0; y < 69; y++) {
            InputStateMatrix[x][y] = BpodUSB.readByte();
          }
        }
        // Get Output state matrix
        for (int x = 0; x < nStates; x++) {
          for (int y = 0; y < 18; y++) {
            OutputStateMatrix[x][y] = BpodUSB.readByte();
          }
        }
        // Get global timer matrix
        for (int x = 0; x < nStates; x++) {
          for (int y = 0; y < 5; y++) {
            GlobalTimerMatrix[x][y] = BpodUSB.readByte();
          }
        }
        // Get global counter matrix
        for (int x = 0; x < nStates; x++) {
          for (int y = 0; y < 5; y++) {
            GlobalCounterMatrix[x][y] = BpodUSB.readByte();
          }
        }
        // Get condition matrix
        for (int x = 0; x < nStates; x++) {
          for (int y = 0; y < 5; y++) {
            ConditionMatrix[x][y] = BpodUSB.readByte();
          }
        }
        BpodUSB.readByteArray(GlobalCounterAttachedEvents, 5); // Get global counter attached events
        BpodUSB.readByteArray(ConditionChannels, 5); // Get condition channels
        BpodUSB.readByteArray(ConditionValues, 5); // Get condition values
        BpodUSB.readByteArray(PortInputsEnabled, 8); // Get input channel configurtaion
        BpodUSB.readUint32Array(StateTimers, nStates); // Get state timers
        BpodUSB.readUint32Array(GlobalTimers, 5); // Get global timers
        BpodUSB.readUint32Array(GlobalCounterThresholds, 5); // Get global counter event count thresholds
        BpodUSB.writeByte(1);
        break;
      case 'R':  // Run State Matrix
        updateStatusLED(3);
        NewState = 0;
        CurrentState = 0;
        nEvents = 0;
        SoftEvent = 254; // No event
        MatrixFinished = false;
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

        // Reset event counters
        for (int x = 0; x < 5; x++) {
          GlobalCounterCounts[x] = 0;
        }
        // Read initial state of sensors
        for (int x = 0; x < 8; x++) {
          if (PortInputsEnabled[x] == 1) {
            PortInputLineValue[x] = digitalReadDirect(PortDigitalInputLines[x]); // Read each photogate's current state into an array
            ChannelLogic[x] = PortInputLineValue[x];
            if (PortInputLineValue[x] == HIGH) {
              PortInputLineLastKnownStatus[x] = HIGH; // Update last known state of input line
            } else {
              PortInputLineLastKnownStatus[x] = LOW;
            }
          } else {
            PortInputLineLastKnownStatus[x] = LOW; PortInputLineValue[x] = LOW;
          }
          PortInputLineOverride[x] = false;
        }
        for (int x = 0; x < 2; x++) {
          BNCInputLineValue[x] = digitalReadDirect(BncInputLines[x]);
          ChannelLogic[x+8] = BNCInputLineValue[x];
          if (BNCInputLineValue[x] == IsolatorHighLevel) {
            BNCInputLineLastKnownStatus[x] = IsolatorHighLevel;
          } else {
            BNCInputLineLastKnownStatus[x] = IsolatorLowLevel;
          }
          BNCInputLineOverride[x] = false;
          WireInputLineValue[x] = digitalReadDirect(WireDigitalInputLines[x]);
          ChannelLogic[x+10] = WireInputLineValue[x];
          if (WireInputLineValue[x] == IsolatorHighLevel) {
            WireInputLineLastKnownStatus[x] = IsolatorHighLevel;
          } else {
            WireInputLineLastKnownStatus[x] = IsolatorLowLevel;
          }
          WireInputLineOverride[x] = false;
        }
        // Clear hardware serial buffers
          while (Serial1.available() > 0) {
            Serial1.read();
          }
          while (Serial2.available() > 0) {
            Serial2.read();
          }
          while (Serial3.available() > 0) {
            Serial3.read();
          }
        // Reset timers
        MatrixStartTime = 0;
        StateStartTime = MatrixStartTime;
        CurrentTime = MatrixStartTime;
        RunningStateMatrix = 1;
        firstLoop = 1;
        break;
      case 'X':   // Exit state matrix and return data
        MatrixFinished = true;
        RunningStateMatrix = false;
        setStateOutputs(0); // Returns all lines to low by forcing final state
        break;
    } // End switch commandbyte
  } // End SerialUSB.available
  if (RunningStateMatrix) {
    if (firstLoop == 1) {
      firstLoop = 0;
      MatrixStartTimeMillis = millis();
      SyncWrite();
      setStateOutputs(CurrentState); // Adjust outputs, scheduled waves, serial codes and sync port for first state
    } else {
      nCurrentEvents = 0;
      CurrentEvent[0] = 254; // Event 254 = No event
      CurrentTime++;
      // Refresh state of sensors and inputs
      for (int x = 0; x < 8; x++) {
        if ((PortInputsEnabled[x] == 1) && (!PortInputLineOverride[x])) {
          PortInputLineValue[x] = digitalReadDirect(PortDigitalInputLines[x]);
          ChannelLogic[x] = PortInputLineValue[x];
        }
      }
      for (int x = 0; x < 2; x++) {
        if (!BNCInputLineOverride[x]) {
          BNCInputLineValue[x] = digitalReadDirect(BncInputLines[x]);
          ChannelLogic[x+8] = BNCInputLineValue[x];
        }
      }
      for (int x = 0; x < 2; x++) {
        if (!WireInputLineOverride[x]) {
          WireInputLineValue[x] = digitalReadDirect(WireDigitalInputLines[x]);
          ChannelLogic[x+10] = WireInputLineValue[x];
        }
      }
      // Determine if a handled condition occurred
      Ev = 79;
      for (int x = 0; x < 5; x++) {
        if (ConditionMatrix[CurrentState][x] != CurrentState) { // If this condition is handled
          if (ChannelLogic[ConditionChannels[x]] == ConditionValues[x]) {
            CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
          }
        }
        Ev++;
      }
      // Determine which port event occurred
      Ev = 0; // Since port-in and port-out events are indexed sequentially, Ev replaces x in the loop.
      for (int x = 0; x < 8; x++) {
        // Determine port entry events
        if ((PortInputLineValue[x] == HIGH) && (PortInputLineLastKnownStatus[x] == LOW)) {
          PortInputLineLastKnownStatus[x] = HIGH; CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
        }
        Ev++;
        // Determine port exit events
        if ((PortInputLineValue[x] == LOW) && (PortInputLineLastKnownStatus[x] == HIGH)) {
          PortInputLineLastKnownStatus[x] = LOW; CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
        }
        Ev++;
      }
      // Determine which BNC event occurred
      for (int x = 0; x < 2; x++) {
        // Determine BNC low-to-high events
        if ((BNCInputLineValue[x] == IsolatorHighLevel) && (BNCInputLineLastKnownStatus[x] == IsolatorLowLevel)) {
          BNCInputLineLastKnownStatus[x] = IsolatorHighLevel; CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
        }
        Ev++;
        // Determine BNC high-to-low events
        if ((BNCInputLineValue[x] == IsolatorLowLevel) && (BNCInputLineLastKnownStatus[x] == IsolatorHighLevel)) {
          BNCInputLineLastKnownStatus[x] = IsolatorLowLevel; CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
        }
        Ev++;
      }
      // Determine which Wire event occurred
      for (int x = 0; x < 2; x++) {
        // Determine Wire low-to-high events
        if ((WireInputLineValue[x] == IsolatorHighLevel) && (WireInputLineLastKnownStatus[x] == IsolatorLowLevel)) {
          WireInputLineLastKnownStatus[x] = IsolatorHighLevel; CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
        }
        Ev++;
        // Determine Wire high-to-low events
        if ((WireInputLineValue[x] == IsolatorLowLevel) && (WireInputLineLastKnownStatus[x] == IsolatorHighLevel)) {
          WireInputLineLastKnownStatus[x] = IsolatorLowLevel; CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
        }
        Ev++;
      }
      // Map soft events to event code scheme
      Ev = 29;
      if (SoftEvent < 254) {
        CurrentEvent[nCurrentEvents] = SoftEvent + Ev - 1; nCurrentEvents++;
        SoftEvent = 254;
      }
      // Determine if a hardware serial port returned an event
      Ev = 39;
      if (Serial1.available()>0) {
        Byte1 = Serial1.read();
        if (Byte1 < 11) {
          CurrentEvent[nCurrentEvents] = Byte1 + Ev - 1; nCurrentEvents++;
        }
      }
      Ev = 49;
      if (Serial2.available()>0) {
        Byte1 = Serial2.read();
        if (Byte1 < 11) {
          CurrentEvent[nCurrentEvents] = Byte1 + Ev - 1; nCurrentEvents++;
        }
      }
      Ev = 59;
      if (Serial3.available()>0) {
        Byte1 = Serial3.read();
        if (Byte1 < 11) {
          CurrentEvent[nCurrentEvents] = Byte1 + Ev - 1; nCurrentEvents++;
        }
      }
      Ev = 69;
      // Determine if a global timer expired
      for (int x = 0; x < 5; x++) {
        if (GlobalTimersActive[x] == true) {
          if (CurrentTime >= GlobalTimerEnd[x]) {
            CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
            GlobalTimersActive[x] = false;
          }
        }
        Ev++;
      }
      // Determine if a global event counter threshold was exceeded
      for (int x = 0; x < 5; x++) {
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
      Ev = 28;
      // Determine if a state timer expired
      TimeFromStart = CurrentTime - StateStartTime;
      if ((TimeFromStart >= StateTimers[CurrentState]) && (MeaningfulStateTimer == true)) {
        CurrentEvent[nCurrentEvents] = Ev; nCurrentEvents++;
      }
      // Now determine if a state transition should occur. The first event linked to a state transition takes priority.
      byte StateTransitionFound = 0; int i = 0;
      while ((!StateTransitionFound) && (i < nCurrentEvents)) {
        if (CurrentEvent[i] < 69) {
          NewState = InputStateMatrix[CurrentState][CurrentEvent[i]];
        } else if (CurrentEvent[i] < 74) {
          CurrentColumn = CurrentEvent[0] - 69;
          NewState = GlobalTimerMatrix[CurrentState][CurrentColumn];
        } else if (CurrentEvent[i] < 79) {
          CurrentColumn = CurrentEvent[i] - 74;
          NewState = GlobalCounterMatrix[CurrentState][CurrentColumn];
        } else if (CurrentEvent[i] < 84) {
          CurrentColumn = CurrentEvent[i] - 79;
          NewState = ConditionMatrix[CurrentState][CurrentColumn];
        }
        if (NewState != CurrentState) {
          StateTransitionFound = 1;
        }
        i++;
      }
      if (nCurrentEvents > 5) { // Drop events beyond 5
        nCurrentEvents = 5;
      }
      // Store timestamp of events captured in this cycle
      for (int i = 0; i < nCurrentEvents; i++) {
        TrialTimeStamps.Uint32[i] = CurrentTime;
        nEvents++;
      }
      digitalWriteDirect(fRAMcs, LOW);
      digitalWriteDirect(fRAMhold, HIGH); // Resume logging
      SPI.transfer(TrialTimeStamps.Bytes, nCurrentEvents * 4);
      digitalWriteDirect(fRAMhold, LOW); // Pause logging
      digitalWriteDirect(fRAMcs, HIGH);
  
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
      // Write events captured to USB (if events were captured)
      if (nCurrentEvents > 0) {
        BpodUSB.writeByte(1); // Code for returning events
        BpodUSB.writeByte(nCurrentEvents);
        BpodUSB.writeByteArray(CurrentEvent, nCurrentEvents);
      }
    }
  } // End running state matrix
  if (MatrixFinished) {
    if (SyncMode == 0) {
      ResetSyncLine();
    } else {
      SyncWrite();
    }
    SetBNCOutputLines(0); // Reset BNC outputs
    //digitalWriteDirect(BncOutputLines[0], HIGH); // Uncomment to pulse BNC ch1 for duration of inter-trial dead-time
    SetWireOutputLines(0); // Reset wire outputs
    UpdatePWMOutputStates();
    ValveRegWrite(0); // Reset valves
    MatrixFinished = 0;
    for (int x = 0; x < 8; x++) { // Reset PWM lines
      PortPWMOutputState[x] = 0;
    }
    serialByteBuffer[0] = 1; // Op Code for sending events
    serialByteBuffer[1] = 1; // Read one event
    serialByteBuffer[2] = 255; // Send Matrix-end code
    BpodUSB.writeByteArray(serialByteBuffer, 3);
    // Send trial-start timestamp (in milliseconds, basically immune to microsecond 32-bit timer wrap-over)
    BpodUSB.writeUint32(MatrixStartTimeMillis - SessionStartTime);
    // Send matrix start timestamp (in microseconds)
    BpodUSB.writeUint32(MatrixStartTime);
    BpodUSB.writeUint16(nEvents);

    // Return event times from fRAM IC
    //BpodUSB.writeUint32Array(TimeStamps, nEvents);
    digitalWriteDirect(fRAMhold, HIGH);
    digitalWriteDirect(fRAMcs, LOW);
    SPI.transfer(3); // Send read op code
    SPI.transfer(0); // Send address bytes
    SPI.transfer(0);
    SPI.transfer(0);
    for (int i = 0; i < nEvents * 4; i++) {
      BpodUSB.writeByte(SPI.transfer(0));
    }
    digitalWriteDirect(fRAMcs, HIGH);

    updateStatusLED(0);
    updateStatusLED(2);
    for (int i = 0; i < 5; i++) { // Shut down active global timers
      GlobalTimersActive[i] = false;
    }
  } // End Matrix finished
} // End timer handler

void SetBNCOutputLines(int BNCState) {
  for (int x = 0; x < nBNCChannels; x++) {
    digitalWriteDirect(BncOutputLines[x], bitRead(BNCState, x));
  }
}

int ValveRegWrite(int value) {
  // Write to solenoid valve shift register
  SPI.transfer(value);
  digitalWriteDirect(ValveRegisterLatch, HIGH);
  digitalWriteDirect(ValveRegisterLatch, LOW);
}

void UpdatePWMOutputStates() {
  for (int x = 0; x < nPorts; x++) {
    analogWrite(PortPWMOutputLines[x], PortPWMOutputState[x]);
  }
}
void SetWireOutputLines(int WireState) {
  for (int x = 0; x < nWireOutputChannels; x++) {
    digitalWriteDirect(WireDigitalOutputLines[x], bitRead(WireState, x));
  }
}
void ResetSyncLine() {
  SyncState = 0;
  digitalWriteDirect(BncOutputLines[1], SyncState);
  analogWrite(PortPWMOutputLines[7], SyncState);
  digitalWriteDirect(WireDigitalOutputLines[2], SyncState);
}
void SyncWrite() {
  if (SyncState == 0) {
    SyncState = 1;
  } else {
    SyncState = 0;
  }
  switch(SyncChannel) {
    case 1:
      digitalWriteDirect(BncOutputLines[1], SyncState);
    break;
    case 2:
      analogWrite(PortPWMOutputLines[7], SyncState*255);
    break;
    case 3:
      digitalWriteDirect(WireDigitalOutputLines[2], SyncState);
    break;
  }
}
void updateStatusLED(int Mode) {
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

void setStateOutputs(byte State) {
  byte CurrentTimer = 0; // Used when referring to the timer currently being triggered
  byte CurrentCounter = 0; // Used when referring to the counter currently being reset
  ValveRegWrite(OutputStateMatrix[State][0]);
  SetBNCOutputLines(OutputStateMatrix[State][1]);
  SetWireOutputLines(OutputStateMatrix[State][2]);
  Serial1.write(OutputStateMatrix[State][3]);
  Serial2.write(OutputStateMatrix[State][4]);
  Serial3.write(OutputStateMatrix[State][5]);
  if (OutputStateMatrix[State][6] > 0) {
    serialByteBuffer[0] = 2; // Code for MATLAB to receive soft-code byte
    serialByteBuffer[1] = OutputStateMatrix[State][6]; // Soft code byte
    BpodUSB.writeByteArray(serialByteBuffer, 2);
  }
  for (int x = 0; x < nPorts; x++) {
    analogWrite(PortPWMOutputLines[x], OutputStateMatrix[State][x + 10]);
  }
  // Trigger global timers
  CurrentTimer = OutputStateMatrix[State][7];
  if (CurrentTimer > 0) {
    CurrentTimer = CurrentTimer - 1; // Convert to 0 index
    GlobalTimersActive[CurrentTimer] = true;
    GlobalTimerEnd[CurrentTimer] = CurrentTime + GlobalTimers[CurrentTimer];
  }
  // Cancel global timers
  CurrentTimer = OutputStateMatrix[State][8];
  if (CurrentTimer > 0) {
    CurrentTimer = CurrentTimer - 1; // Convert to 0 index
    GlobalTimersActive[CurrentTimer] = false;
  }
  // Reset event counters
  CurrentCounter = OutputStateMatrix[State][9];
  if (CurrentCounter > 0) {
    CurrentCounter = CurrentCounter - 1; // Convert to 0 index
    GlobalCounterCounts[CurrentCounter] = 0;
  }
  if (InputStateMatrix[State][28] != State) {
    MeaningfulStateTimer = true;
  } else {
    MeaningfulStateTimer = false;
  }
}

void manualOverrideOutputs() {
  byte OutputType = 0;
  OutputType = BpodUSB.readByte();
  switch (OutputType) {
    case 'P':  // Override PWM lines
      for (int x = 0; x < 8; x++) {
        PortPWMOutputState[x] = BpodUSB.readByte();
      }
      UpdatePWMOutputStates();
      break;
    case 'V':  // Override valves
      Byte1 = BpodUSB.readByte();
      ValveRegWrite(Byte1);
      break;
    case 'B': // Override BNC lines
      Byte1 = BpodUSB.readByte();
      SetBNCOutputLines(Byte1);
      break;
    case 'W':  // Override wire terminal output lines
      Byte1 = BpodUSB.readByte();
      SetWireOutputLines(Byte1);
      break;
    case 'S': // Override serial module port 1
      Byte1 = BpodUSB.readByte();  // Read data to send
      Serial1.write(Byte1);
      break;
    case 'T': // Override serial module port 2
      Byte1 = BpodUSB.readByte();  // Read data to send
      Serial2.write(Byte1);
      break;
  }
}

void digitalWriteDirect(int pin, boolean val) {
  if (val) g_APinDescription[pin].pPort -> PIO_SODR = g_APinDescription[pin].ulPin;
  else    g_APinDescription[pin].pPort -> PIO_CODR = g_APinDescription[pin].ulPin;
}

byte digitalReadDirect(int pin) {
  return !!(g_APinDescription[pin].pPort -> PIO_PDSR & g_APinDescription[pin].ulPin);
}

