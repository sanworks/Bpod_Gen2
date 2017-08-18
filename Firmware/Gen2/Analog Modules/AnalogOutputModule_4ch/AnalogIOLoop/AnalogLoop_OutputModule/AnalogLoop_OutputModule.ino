// This code is a "hello world" example of an analog closed loop, running in parallel with the Bpod state machine.
// It is temporary, and will be significantly improved once the Bpod analog input module becomes available.
// For now, input module code is available for developers. It pairs with an ad-hoc analog input module: 
// Arduino M0's built-in ADC + Bpod Arduino shield v0.7+ (firmware in /AnalogLoop_InputModule).
// Normally the Analog input module would have a second serial channel to return events to the state machine, a wider input range,
// greater bit-depth and significantly more CPU available for digital processing.

// Here, Samples from the analog input module are read in, code is marked below where behavioral events would be extracted, 
// and an output waveform would be synthesized.
// For this example, the 16-bit samples are copied directly from the analog input module's 4 channels to the output module's 4 channels. 
// Unlike the other examples using the analog output module, this code does not use a hardware timer. Instead, the analog input module
// uses its hardware timer to sample, and returns measurements for all 4 channels once each millisecond. 
// The code here waits in a loop for data to become available,
// and processes the samples immediately.

// The same sample transmission scheme is used to read data from all 3 serial interfaces (USB, state machine and Ain module) - 
// samples are sent to the output module by sending byte 'R' (for read) followed by 8 bytes (2 samples per channel x 4 channels).
// Josh Sanders, March 2017

#include "ArCOM.h"
#include "AD5754R.h"
#define SERIAL_TX_BUFFER_SIZE 256
#define SERIAL_RX_BUFFER_SIZE 256

// Module setup
#define FirmwareVersion 1
char moduleName[] = "AnlgLoopOut"; // Name of module for manual override UI and state machine assembler
const byte nOutputChannels = 4;
const byte nInputChannels = 4; // Number of input channels in ADC module

// Pin definitions
AD5754R DAC(14, 39, 32); // Creates an object called DAC representing the AD5754R DAC IC. Arguments = Sync pin, LDAC pin, RefEnable pin

// Communication variables
byte opCode = 0; // Serial inputs access an op menu. The op code byte stores the intended operation.
byte opSource = 0; // 0 = op from USB, 1 = op from UART1 (Bpod state machine), 2 = op from UART2 (analog input module). 
boolean newOpCode = 0; // true if an opCode was read from one of the serial ports

union {
    byte byteArray[nInputChannels*2];
    uint16_t uint16[nInputChannels];
} adcValues; // 16-Bit code of current sample received from ADC input channels. A union type allows instant conversion between bytes and 16-bit ints

unsigned short DACBits_ZeroVolts = 32768; // Code (in bits) for 0V. For bipolar ranges, this should be 32768. For unipolar, 0.

// Wrap 3 serial interfaces
ArCOM USBCOM(Serial); // Creates an ArCOM object called USBCOM, wrapping Serial (the USB connection for Teensy 3.6)
ArCOM Serial1COM(Serial3); // Creates an ArCOM object called Serial1COM, wrapping Serial3 (physical channel 3 is module channel 1)
ArCOM Serial2COM(Serial2); 

void setup() {
  Serial2.begin(1312500); 
  Serial3.begin(1312500);
  DAC.setRange(3); // rangeIndex 0 = '0V:5V', 1 = '0V:10V', 2 = '0V:12V', 3 = '-5V:5V', 4 = '-10V:10V', 5 = '-12V:12V'
}

void loop() {
  if (Serial1COM.available() > 0) {
    opCode = Serial1COM.readByte(); // Read in an op code
    opSource = 1; // message from UART 1 (Bpod state machine)
    newOpCode = true;
  } else if (Serial2COM.available() > 0) {
    opCode = Serial2COM.readByte();
    opSource = 2; // message from UART 2 (Analog input module)
    newOpCode = true;
  } else if (USBCOM.available() > 0) {
    opCode = USBCOM.readByte();
    opSource = 0; // message from USB / MATLAB / Python
    newOpCode = true;
  }
  if (newOpCode) { // If an op byte arrived from one of the serial interfaces
    newOpCode = false;
    switch(opCode) {
      case 255: // Return Bpod module info
        if (opSource == 1) { // Only returns this info if requested from state machine device
          returnModuleInfo();
        }
      break;
      case 'R': // Read and process new ADC samples
        // Read new samples from serial source (i.e. analog input module, USB, etc)
        switch (opSource) {
          case 0:
             USBCOM.readUint16Array(adcValues.uint16, nInputChannels); // Read new voltage values (12 actual bits) from all 4 input channels
          break;
          case 1:
             Serial1COM.readUint16Array(adcValues.uint16, nInputChannels);
          break;
          case 2:
             Serial2COM.readUint16Array(adcValues.uint16, nInputChannels);
          break;
        }
        
        // Run a filter on samples (+ history if you recorded it) to extract behavior events
        
        // Return behavior events to Bpod state machine. Discrete events are sent as Serial1COM.writeByte(myEvent), where myEvent is an event byte code.
        
        // Map new ADC samples to DAC output voltages. For this "hello world" example, the bits are copied directly from the ADC to the DAC
        for (int i = 0; i < nInputChannels; i++) {
          DAC.SetOutput(i, adcValues.uint16[i]); // Sets DAC output value, but voltage does not change until the next call to DAC.dacWrite()
        }
        DAC.dacWrite(); // Update DAC with new values
      break;
    }
  }
}

void returnModuleInfo() {
  Serial1COM.writeByte(65); // Acknowledge
  Serial1COM.writeUint32(FirmwareVersion); // 4-byte firmware version
  Serial1COM.writeByte(sizeof(moduleName)-1); // Length of module name
  Serial1COM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  Serial1COM.writeByte(0); // 1 if more info follows, 0 if not
}
