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

myBpod.manualOverride('Output', 'Serial', 1, 65) # Send byte 65 on UART port 1 - by default, this is ASCII 'A'
time.sleep(1) # Wait 1s
myBpod.loadSerialMessage(1, 65, (66,67,68)) # Set byte 65 ('A') on UART port 1 to trigger a 3-byte message: 'BCD'
myBpod.manualOverride('Output', 'Serial', 1, 65) # Now, the same command has a different result
time.sleep(1) # Wait 1s
myBpod.resetSerialMessages() # Reset the serial message library. Bytes will now pass through again.
myBpod.manualOverride('Output', 'Serial', 1, 65) # Back to 'A'

# Disconnect Bpod
myBpod.disconnect() # Sends a termination byte and closes the serial port. PulsePal stores current params to its EEPROM.
