// 100ms blinks LED on Pin13, to indicate value of bytes that arrive (i.e. byte 3 = 3 blinks)
byte BlinkIndex = 0;

void setup()
{
  Serial5.begin(115200);
  pinMode(13, OUTPUT); 
}

void loop()
{
  if (Serial5.available()) {
    BlinkIndex = Serial5.read();
    for (int x = 0; x < BlinkIndex; x++) {
      digitalWrite(13, HIGH); delay(100);
      digitalWrite(13, LOW);  delay(100);
    }
  }    
}
