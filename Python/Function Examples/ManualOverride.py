'''
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
'''

import os, sys, time
sys.path.append(os.path.join(os.path.dirname(__file__)[:-17], "Modules")) # Add Bpod system files to Python path

# Initializing Bpod
from BpodClass import BpodObject # Import BpodObject
myBpod = BpodObject('COM13') # Create a new instance of a Bpod object on serial port COM13

myBpod.manualOverride('Output', 'PWM', 2, 255) # Set LED of port 2 to max intensity
time.sleep(0.25) # Wait 250ms
myBpod.manualOverride('Output', 'PWM', 2, 8) # Set LED of port 2 to lower intensity
time.sleep(0.25) # Wait 250ms
myBpod.manualOverride('Output', 'PWM', 2, 0) # Set LED of port 2 to zero intensity

time.sleep(1) # Wait 1s

myBpod.manualOverride('Output', 'Valve', 1, 1) # Set valve of port 1 to "open"
time.sleep(0.25) # Wait 250ms
myBpod.manualOverride('Output', 'Valve', 1, 0) # Set valve of port 1 to "close"

time.sleep(1) # Wait 1s

myBpod.manualOverride('Output', 'Valve', 3, 1) # Set valve of port 3 to "open"
time.sleep(0.25) # Wait 250ms
myBpod.manualOverride('Output', 'Valve', 3, 0) # Set valve of port 3 to "close"

time.sleep(1) # Wait 1s

myBpod.manualOverride('Output', 'BNC', 2, 1) # Set BNC output ch2 to "high"
time.sleep(0.01) # Wait 10ms
myBpod.manualOverride('Output', 'BNC', 2, 0) # Set BNC output ch2 to "low"

time.sleep(1) # Wait 1s

myBpod.manualOverride('Output', 'Wire', 3, 1) # Set Wire output ch3 to "high"
time.sleep(0.01) # Wait 10ms
myBpod.manualOverride('Output', 'Wire', 3, 0) # Set Wire output ch3 to "low"

time.sleep(1) # Wait 1s

myBpod.manualOverride('Output', 'Serial', 2, 65) # Send byte 65 on UART port 2
time.sleep(0.01) # Wait 10ms
myBpod.manualOverride('Output', 'Serial', 1, 66) # Send byte 66 on UART port 1

# Disconnect Bpod
myBpod.disconnect() # Sends a termination byte and closes the serial port. PulsePal stores current params to its EEPROM.
