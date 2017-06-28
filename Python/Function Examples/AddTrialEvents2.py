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
# Demonstration of AddTrialEvents used in a visual 2AFC session.
# A global timer enforces no Port2 re-entry after the stimulus, following a grace period with warning flashes.
# AddTrialEvents formats each trial's data in a human-readable struct, and adds to myBpod.data (to save to disk later)
# Connect noseports to ports 1-3.

import os, sys, random
sys.path.append(os.path.join(os.path.dirname(__file__)[:-17], "Modules")) # Add Bpod system files to Python path

from BpodClass import BpodObject # Import BpodObject
from StateMachineAssembler import stateMachine # Import state machine assembler

myBpod = BpodObject('COM13') # Create a new instance of a Bpod object on serial port COM13

nTrials = 5
graceTime = 5;
trialTypes = [1,2] # 1 (rewarded left) or 2 (rewarded right)

for i in range(nTrials): # Main loop
    print 'Trial: ' + str(i)
    thisTrialType = random.choice(trialTypes) # Randomly choose trial type =
    if thisTrialType == 1:
        stimulus = 'PWM1' # set stimulus channel for trial type 1
        leftAction = 'Reward'
        rightAction = 'Punish'
        rewardValve = 1
    elif thisTrialType == 2:
        stimulus = 'PWM3' # set stimulus channel for trial type 1
        leftAction = 'Punish'
        rightAction = 'Reward'
        rewardValve = 3
    sma = stateMachine(myBpod) # Create a new state machine (events + outputs tailored for myBpod)
    sma.setGlobalTimer(1, graceTime) # Set timeout
    sma.addState('Name', 'WaitForPort2Poke', # Add a state
                 'Timer', 1,
                 'StateChangeConditions', ('Port2In', 'FlashStimulus'),
                 'OutputActions', ('PWM2', 255))
    sma.addState('Name', 'FlashStimulus',
                 'Timer', 0.1,
                 'StateChangeConditions', ('Tup', 'WaitForResponse'),
                 'OutputActions', (stimulus, 255, 'GlobalTimerTrig', 1))
    sma.addState('Name', 'WaitForResponse',
                 'Timer', 1,
                 'StateChangeConditions', ('Port1In', leftAction, 'Port3In', rightAction, 'Port2In', 'Warning', 'GlobalTimer1_End', 'MiniPunish'),
                 'OutputActions', ())
    sma.addState('Name', 'Warning',
                 'Timer', 0.1,
                 'StateChangeConditions', ('Tup', 'WaitForResponse', 'GlobalTimer1_End', 'MiniPunish'),
                 'OutputActions', ('LED', 1, 'LED', 2, 'LED', 3)) # Reward correct choice
    sma.addState('Name', 'Reward',
                 'Timer', 0.1,
                 'StateChangeConditions', ('Tup', 'exit'),
                 'OutputActions', ('Valve', rewardValve)) # Reward correct choice
    sma.addState('Name', 'Punish',
                 'Timer', 3,
                 'StateChangeConditions', ('Tup', 'exit'),
                 'OutputActions', ('LED', 1, 'LED', 2, 'LED', 3)) # Signal incorrect choice
    sma.addState('Name', 'MiniPunish',
                 'Timer', 1,
                 'StateChangeConditions', ('Tup', 'exit'),
                 'OutputActions', ('LED', 1, 'LED', 2, 'LED', 3)) # Signal incorrect choice
    myBpod.sendStateMachine(sma) # Send state machine description to Bpod device
    RawEvents = myBpod.runStateMachine() # Run state machine and return events
    myBpod.addTrialEvents(RawEvents) # Add trial events to myBpod.data struct, formatted for human readability
    print 'States:'
    print myBpod.data.rawEvents.Trial[i].States.__dict__
    print 'Events:'
    print myBpod.data.rawEvents.Trial[i].Events.__dict__
myBpod.disconnect() # Disconnect Bpod
