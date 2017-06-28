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
'''
Example state machine: A global timer triggers passage through two infinite loops. It is
triggered in the first state, but begins measuring its 3-second Duration
after a 1.5s onset delay. During the onset delay, an infinite loop
toggles two port LEDs (Port1, Port3) at low intensity. When the timer begins measuring,
it sets port 2 LED to maximum brightness, and triggers transition to a second infinite loop with brighter port 1+3 LEDs.
When the timer's 3 second duration elapses, Port2LED is returned low,
and a GlobalTimer1_End event occurs (handled by exiting the state machine).
'''
import os, sys
sys.path.append(os.path.join(os.path.dirname(__file__)[:-22], "Modules")) # Add Bpod system files to Python path

# Initializing Bpod
from BpodClass import BpodObject # Import BpodObject
from StateMachineAssembler import stateMachine # Import state machine assembler

myBpod = BpodObject('COM13') # Create a new instance of a Bpod object on serial port COM13
sma = stateMachine(myBpod) # Create a new state machine (events + outputs tailored for myBpod)
# Set global timer 1 for 3 seconds, following a 1.5 second onset delay after trigger. Link to LED of port 2.
#
sma.setGlobalTimer('TimerID', 1, 'Duration', 3, 'OnsetDelay', 1.5, 'Channel', 'PWM2', 'OnMessage', 255)
sma.addState('Name', 'TimerTrig', # Trigger global timer
    'Timer', 0,
    'StateChangeConditions', ('Tup', 'Port1Lit_Pre'),
    'OutputActions', ('GlobalTimerTrig', 1))
sma.addState('Name', 'Port1Lit_Pre',
    'Timer', .25,
    'StateChangeConditions', ('Tup', 'Port3Lit_Pre', 'GlobalTimer1_Start', 'Port1Lit_Post'),
    'OutputActions', ('PWM1', 16))
sma.addState('Name', 'Port3Lit_Pre',
    'Timer', .25,
    'StateChangeConditions', ('Tup', 'Port1Lit_Pre', 'GlobalTimer1_Start', 'Port3Lit_Post'),
    'OutputActions', ('PWM3', 16))
sma.addState('Name', 'Port1Lit_Post',
    'Timer', .25,
    'StateChangeConditions', ('Tup', 'Port3Lit_Post', 'GlobalTimer1_End', 'exit'),
    'OutputActions', ('PWM1', 255))
sma.addState('Name', 'Port3Lit_Post',
    'Timer', .25,
    'StateChangeConditions', ('Tup', 'Port1Lit_Post', 'GlobalTimer1_End', 'exit'),
    'OutputActions', ('PWM3', 255))

myBpod.sendStateMachine(sma) # Send state machine description to Bpod device
RawEvents = myBpod.runStateMachine() # Run state machine and return events
print RawEvents.__dict__ # Print events to console

# Disconnect Bpod
myBpod.disconnect() # Sends a termination byte and closes the serial port. PulsePal stores current params to its EEPROM.
