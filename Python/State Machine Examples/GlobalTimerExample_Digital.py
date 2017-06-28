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

import os, sys
sys.path.append(os.path.join(os.path.dirname(__file__)[:-22], "Modules")) # Add Bpod system files to Python path

# Initializing Bpod
from BpodClass import BpodObject # Import BpodObject
from StateMachineAssembler import stateMachine # Import state machine assembler

myBpod = BpodObject('COM13') # Create a new instance of a Bpod object on serial port COM13
sma = stateMachine(myBpod) # Create a new state machine (events + outputs tailored for myBpod)
# Set global timer 1 for 3 seconds, following a 1.5 second onset delay after trigger. Link to channel BNC2.
sma.setGlobalTimer('TimerID', 1, 'Duration', 3, 'OnsetDelay', 1.5, 'Channel', 'BNC2')
sma.addState('Name', 'TimerTrig', # Trigger global timer
    'Timer', 0,
    'StateChangeConditions', ('Tup', 'Port1Lit'),
    'OutputActions', ('GlobalTimerTrig', 1))
sma.addState('Name', 'Port1Lit', # Infinite loop (with next state). Only a global timer can save us.
    'Timer', .25,
    'StateChangeConditions', ('Tup', 'Port3Lit', 'GlobalTimer1_End', 'exit'),
    'OutputActions', ('PWM1', 255))
sma.addState('Name', 'Port3Lit',
    'Timer', .25,
    'StateChangeConditions', ('Tup', 'Port1Lit', 'GlobalTimer1_End', 'exit'),
    'OutputActions', ('PWM3', 255))
myBpod.sendStateMachine(sma) # Send state machine description to Bpod device
RawEvents = myBpod.runStateMachine() # Run state machine and return events
print RawEvents.__dict__ # Print events to console

# Disconnect Bpod
myBpod.disconnect() # Sends a termination byte and closes the serial port. PulsePal stores current params to its EEPROM.
