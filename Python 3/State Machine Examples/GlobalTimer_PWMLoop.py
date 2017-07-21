'''
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
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
'''
'''
Example state machine: A global timer triggers a port LED to flash in a 0.1s on / 0.1s off loop. 
It is triggered in the first state, but begins measuring its 3-second Duration
after a 0.5s onset delay. Entering port 1 cancels the global timer. Entering port 2 ends the trial.
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
sma.setGlobalTimer('TimerID', 1, 'Duration', 0.1, 'OnsetDelay', 0.5, 'Channel', 
                   'PWM2', 'OnMessage', 255, 'OffMessage', 0, 'Loop', 1, 
                   'SendGlobalTimerEvents', 1, 'LoopInterval', 0.1)
sma.addState('Name', 'TimerTrig', # Trigger global timer
    'Timer', 0,
    'StateChangeConditions', ('Tup', 'WaitForPoke'),
    'OutputActions', ('GlobalTimerTrig', 1))
sma.addState('Name', 'WaitForPoke',
    'Timer', 0,
    'StateChangeConditions', ('Port1In', 'CancelTimer', 'Port2In', 'exit'),
    'OutputActions', ())
sma.addState('Name', 'CancelTimer',
    'Timer', .25,
    'StateChangeConditions', ('Tup', 'WaitForPoke'),
    'OutputActions', ('GlobalTimerCancel', 1))


myBpod.sendStateMachine(sma) # Send state machine description to Bpod device
RawEvents = myBpod.runStateMachine() # Run state machine and return events
print(RawEvents.__dict__) # Print events to console

# Disconnect Bpod
myBpod.disconnect() # Sends a termination byte and closes the serial port. PulsePal stores current params to its EEPROM.
