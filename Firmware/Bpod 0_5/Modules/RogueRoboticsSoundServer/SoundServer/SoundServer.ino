/*{
----------------------------------------------------------------------------

This file is part of the Bpod Project
Copyright (C) 2014 Joshua I. Sanders, Cold Spring Harbor Laboratory, NY, USA

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
#include <RogueMP3.h>
#include <SoftwareSerial.h>

SoftwareSerial rmp3_s(8, 9);
RogueMP3 rmp3(rmp3_s);
byte SoundIndex = 0;
byte isPlaying = 0;

void setup()
{
  Serial.begin(115200);
  Serial1.begin(115200);
  rmp3_s.begin(9600);
  rmp3.sync();
  rmp3.stop();
  pinMode(6, INPUT); 
  pinMode(7, INPUT); 
}

void loop()
{
if (Serial.available()) {SoundIndex = Serial.read();}
if (Serial1.available()) {SoundIndex = Serial1.read();}  
  switch(SoundIndex){
    case 1:
    rmp3.playfile("1.wav");
    break; 
    case 2:
    rmp3.playfile("2.wav");
    break;
    case 3:
    rmp3.playfile("3.wav");
    break;
    case 4:
    rmp3.playfile("4.wav");
    break;
    case 5:
    rmp3.playfile("5.wav");
    break;
    case 6:
    rmp3.playfile("6.wav");
    break;
    case 7:
    rmp3.playfile("7.wav");
    break;
    case 8:
    rmp3.playfile("8.wav");
    break;
    case 9:
    rmp3.playfile("9.wav");
    break;
    case 10:
    rmp3.playfile("10.wav");
    break;
    case 255:
    rmp3.stop();
    }
    SoundIndex = 0;
}
