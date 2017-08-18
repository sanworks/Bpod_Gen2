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

from BpodClass import BpodObject # Import BpodObject
from StateMachineAssembler import stateMachine # Import state machine assembler

myBpod = BpodObject('COM13') # Create a new instance of a Bpod object on serial port COM13

sma = stateMachine(myBpod) # Create a new state machine (events + outputs tailored for myBpod)
sma.setCondition(1, 'Port2', 1) #Arguments: (ConditionNumber, ConditionChannel, ConditionValue; 1 = high/in, 0 = low/out)
sma.addState('Name', 'Port1Light', # Add a state
             'Timer', 1,
             'StateChangeConditions', ('Tup', 'Port2Light'),
             'OutputActions', ('PWM1', 255))
sma.addState('Name', 'Port2Light',
             'Timer', 1,
             'StateChangeConditions', ('Tup', 'Port3Light', 'Condition1', 'Port3Light'),
             'OutputActions', ('PWM2', 255))
sma.addState('Name', 'Port3Light',
             'Timer', 1,
             'StateChangeConditions', ('Tup', 'exit'),
             'OutputActions', ('PWM3', 255))
print sma.conditions.matrix
myBpod.sendStateMachine(sma) # Send state machine description to Bpod device
RawEvents = myBpod.runStateMachine() # Run state machine and return events
print RawEvents.__dict__ # Print events to console

myBpod.disconnect() # Disconnect Bpod
