// Open a USB serial terminal for the module.
// Numbers entered will be converted to bytes (not their ASCII values)
byte inByte = 0;
void setup() {
  // put your setup code here, to run once:
  Serial5.begin(1312500); //2625000
}

void loop() {
  if (SerialUSB.available()>0) {
    inByte = SerialUSB.read();
    Serial5.write(inByte-48); // Sends ASCII numbers as actual numbers
  }
  if (Serial5.available()) {
   inByte = Serial5.read();
   SerialUSB.write(inByte);
  }
}
