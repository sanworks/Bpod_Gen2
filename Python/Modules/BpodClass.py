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
import struct
import math
class BpodObject(object):
    def __init__(self, serialPortName):
        self.serialObject = 0
        self.firmwareVersion = 0
        self.HW = Struct()
        self.HW.n = Struct()
        self.HW.Pos = Struct()
        self.data = Struct()
        self.HW.inputsEnabled = 0
        self.eventNames = ()
        self.stateMachineInfo = Struct()
        self.stateMachineInfo.Pos = Struct()
        self.stateMachineInfo.nEvents = 0
        self.stateMachineInfo.eventNames = ()
        self.stateMachineInfo.inputChannelNames = ()
        self.stateMachineInfo.nOutputChannels = 0
        self.stateMachineInfo.outputChannelNames = ()
        self.stateMachine = Struct()
        self.status = Struct();
        self.syncConfig = [255, 1] # [Channel,Mode] 255 = no sync, otherwise set to a hardware channel number. Mode 0 = flip logic every trial, 1 = every state
        self.connect(serialPortName)
        self.setup()
    def connect(self, serialPortName):
        from ArCOM import ArCOMObject # Import ArCOMObject
        self.serialObject = ArCOMObject(serialPortName, 115200) # Create a new instance of an ArCOM serial port
        self.serialObject.write('6', 'char') # Test connectivity
        OK = self.serialObject.read('char') # Receive response
        if (OK != '5'):
            raise BpodError('Error: Bpod failed to confirm connectivity. Please reset Bpod and try again.')
        self.serialObject.write(ord('F'), 'uint8') # Request firmware version
        self.firmwareVersion = self.serialObject.read('uint32')
        if (self.firmwareVersion < 8):
            raise BpodError('Error: Old firmware detected. Please update Bpod 0.7+ firmware and try again.')
        # Get hardware description
        self.serialObject.write(ord('H'), 'uint8')
        maxStates = self.serialObject.read('uint16')
        self.HW.cyclePeriod = self.serialObject.read('uint16')
        self.HW.cycleFrequency = 1000000/self.HW.cyclePeriod
        self.HW.n.EventsPerSerialChannel = self.serialObject.read('uint8')
        self.HW.n.GlobalTimers = self.serialObject.read('uint8')
        self.HW.n.GlobalCounters  = self.serialObject.read('uint8')
        self.HW.n.Conditions  = self.serialObject.read('uint8')
        self.HW.n.Inputs = self.serialObject.read('uint8')
        self.HW.Inputs = self.serialObject.readArray(self.HW.n.Inputs, 'char')
        self.HW.n.Outputs = self.serialObject.read('uint8')
        self.HW.Outputs = self.serialObject.readArray(self.HW.n.Outputs, 'char') + 'GGG';
        self.status.newStateMachineSent = 0
        self.stateMachineInfo.nOutputChannels = self.HW.n.Outputs + 3
        self.stateMachineInfo.maxStates = maxStates;
        self.HW.n.UARTSerialChannels = 0
        for i in range(self.HW.n.Inputs):
            if self.HW.Inputs[i] == 'U':
                self.HW.n.UARTSerialChannels += 1
        # Set input channel enable/disable
        self.HW.inputsEnabled = [0]*self.HW.n.Inputs
        PortsFound = 0
        for i in range(self.HW.n.Inputs):
            if self.HW.Inputs[i] == 'B':
                self.HW.inputsEnabled[i] = 1
            elif self.HW.Inputs[i] == 'W':
                self.HW.inputsEnabled[i] = 1
            if PortsFound == 0 and self.HW.Inputs[i] == 'P': # Enable ports 1-3 by default
                PortsFound = 1
                self.HW.inputsEnabled[i] = 1
                self.HW.inputsEnabled[i+1] = 1
                self.HW.inputsEnabled[i+2] = 1
        self.serialObject.write([ord('E')] + self.HW.inputsEnabled, 'uint8');
        Confirmed = self.serialObject.read('uint8');
        if (not Confirmed):
            raise BpodError('Error: Failed to enable Bpod inputs.')
        # Set sync channel config
        self.serialObject.write([ord('K')] + self.syncConfig, 'uint8');
        Confirmed = self.serialObject.read('uint8');
        if (not Confirmed):
            raise BpodError('Error: Failed to configure Sync channel.')
    def setup(self):
        # Generate event and input channel names
        inputChannelNames = ()
        eventNames = ()
        Pos = 0;
        nUSB = 0;
        nUART = 0;
        nBNCs = 0;
        nWires = 0;
        nPorts = 0;
        for i in range(self.HW.n.Inputs):
            if self.HW.Inputs[i] == 'U':
                nUART += 1
                inputChannelNames += ('Serial' + str(nUART),)
                for j in range(self.HW.n.EventsPerSerialChannel):
                    eventNames +=('Serial' + str(nUART) + '_' + str(j+1),)
                    Pos += 1
            elif self.HW.Inputs[i] == 'X':
                if nUSB == 0:
                    self.HW.Pos.Event_USB = Pos
                nUSB += 1
                inputChannelNames += ('USB' + str(nUSB),);
                for j in range(self.HW.n.EventsPerSerialChannel):
                    eventNames += ('SoftCode' + str(j+1),)
                    Pos += 1
            elif self.HW.Inputs[i] == 'P':
                if nPorts == 0:
                    self.HW.Pos.Event_Port = Pos
                nPorts += 1;
                inputChannelNames += ('Port' + str(nPorts),)
                eventNames += (inputChannelNames[-1] + 'In',)
                Pos += 1
                eventNames += (inputChannelNames[-1] + 'Out',)
                Pos += 1
            elif self.HW.Inputs[i] == 'B':
                if nBNCs == 0:
                    self.HW.Pos.Event_BNC = Pos
                nBNCs += 1;
                inputChannelNames += ('BNC' + str(nBNCs),)
                eventNames += (inputChannelNames[-1] + 'In',)
                Pos += 1
                eventNames += (inputChannelNames[-1] + 'Out',)
                Pos += 1
            elif self.HW.Inputs[i] == 'W':
                if nWires == 0:
                    self.HW.Pos.Event_Wire = Pos
                nWires += 1;
                inputChannelNames += ('Wire' + str(nWires),)
                eventNames += (inputChannelNames[-1] + 'In',)
                Pos += 1
                eventNames += (inputChannelNames[-1] + 'Out',)
                Pos += 1
        self.stateMachineInfo.Pos.globalTimerStart = Pos;
        for i in range(self.HW.n.GlobalTimers):
            eventNames += ('GlobalTimer' + str(i+1) + '_Start',)
            Pos += 1
        self.stateMachineInfo.Pos.globalTimerEnd = Pos;
        for i in range(self.HW.n.GlobalTimers):
            eventNames += ('GlobalTimer' + str(i+1) + '_End',)
            Pos += 1
        self.stateMachineInfo.Pos.globalCounter = Pos;
        for i in range(self.HW.n.GlobalCounters):
            eventNames += ('GlobalCounter' + str(i+1) + '_End',)
            Pos += 1
        self.stateMachineInfo.Pos.condition = Pos;
        for i in range(self.HW.n.Conditions):
            eventNames += ('Condition' + str(i+1),)
            Pos += 1
        self.stateMachineInfo.Pos.jump = Pos;
        for i in range(self.HW.n.UARTSerialChannels):
            eventNames += ('Serial' + str(i+1) + 'Jump',)
            Pos += 1
        eventNames += ('SoftJump',)
        Pos += 1
        eventNames += ('Tup',)
        self.stateMachineInfo.Pos.Tup = Pos;
        Pos += 1
        self.stateMachineInfo.inputChannelNames = inputChannelNames;
        self.stateMachineInfo.eventNames = eventNames;
        self.stateMachineInfo.nEvents = Pos;
        # Generate output channel names
        outputChannelNames = ()
        Pos = 0;
        nUSB = 0;
        nUART = 0;
        nSPI = 0;
        nBNCs = 0;
        nWires = 0;
        nPorts = 0;
        for i in range(self.HW.n.Outputs):
            if self.HW.Outputs[i] == 'U':
                nUART += 1
                outputChannelNames += ('Serial' + str(nUART),)
                Pos += 1
            if self.HW.Outputs[i] == 'X':
                if nUSB == 0:
                    self.HW.Pos.output_USB = Pos;
                nUSB += 1
                outputChannelNames += ('SoftCode',)
                Pos += 1
            if self.HW.Outputs[i] == 'S':
                if nSPI == 0:
                    self.HW.Pos.output_SPI = Pos;
                nSPI += 1
                outputChannelNames += ('ValveState',) # Assume an SPI shift register mapping bits of a byte to 8 valves
                Pos += 1
            if self.HW.Outputs[i] == 'B':
                if nBNCs == 0:
                    self.HW.Pos.output_BNC = Pos;
                nBNCs += 1
                outputChannelNames += ('BNC' + str(nBNCs),) # Assume an SPI shift register mapping bits of a byte to 8 valves
                Pos += 1
            if self.HW.Outputs[i] == 'W':
                if nWires == 0:
                    self.HW.Pos.output_Wire = Pos;
                nWires += 1
                outputChannelNames += ('Wire' + str(nWires),) # Assume an SPI shift register mapping bits of a byte to 8 valves
                Pos += 1
            if self.HW.Outputs[i] == 'P':
                if nPorts == 0:
                    self.HW.Pos.output_PWM = Pos;
                nPorts += 1
                outputChannelNames += ('PWM' + str(nPorts),) # Assume an SPI shift register mapping bits of a byte to 8 valves
                Pos += 1
        outputChannelNames += ('GlobalTimerTrig',)
        Pos += 1
        outputChannelNames += ('GlobalTimerCancel',)
        Pos += 1
        outputChannelNames += ('GlobalCounterReset',)
        Pos += 1
        self.stateMachineInfo.outputChannelNames = outputChannelNames;
        self.stateMachineInfo.nOutputChannels = Pos;
    def sendStateMachine(self, sma):
        # Replace undeclared states (at the time they were referenced) with actual state numbers
        for i in range(len(sma.undeclared)):
            undeclaredStateNumber = i+10000
            thisStateNumber = sma.manifest.index(sma.undeclared[i])
            for j in range(sma.nStates):
              if sma.stateTimerMatrix[j] == undeclaredStateNumber:
                  sma.stateTimerMatrix[j] = thisStateNumber
              inputTransitions = sma.inputMatrix[j]
              for k in range(0,len(inputTransitions)):
                  thisTransition = inputTransitions[k]
                  if thisTransition[1] == undeclaredStateNumber:
                      inputTransitions[k] = (thisTransition[0],thisStateNumber)
              sma.inputMatrix[j] = inputTransitions
              inputTransitions = sma.globalTimers.startMatrix[j]
              for k in range(0,len(inputTransitions)):
                  thisTransition = inputTransitions[k]
                  if thisTransition[1] == undeclaredStateNumber:
                      inputTransitions[k] = (thisTransition[0],thisStateNumber)
              sma.globalTimers.startMatrix[j] = inputTransitions
              inputTransitions = sma.globalTimers.endMatrix[j]
              for k in range(0,len(inputTransitions)):
                  thisTransition = inputTransitions[k]
                  if thisTransition[1] == undeclaredStateNumber:
                      inputTransitions[k] = (thisTransition[0],thisStateNumber)
              sma.globalTimers.endMatrix[j] = inputTransitions
              inputTransitions = sma.globalCounters.matrix[j]
              for k in range(0,len(inputTransitions)):
                  thisTransition = inputTransitions[k]
                  if thisTransition[1] == undeclaredStateNumber:
                      inputTransitions[k] = (thisTransition[0],thisStateNumber)
              sma.globalCounters.matrix[j] = inputTransitions
              inputTransitions = sma.conditions.matrix[j]
              for k in range(0,len(inputTransitions)):
                  thisTransition = inputTransitions[k]
                  if thisTransition[1] == undeclaredStateNumber:
                      inputTransitions[k] = (thisTransition[0],thisStateNumber)
              sma.conditions.matrix[j] = inputTransitions
        # Check to make sure all states in manifest exist
        if len(sma.manifest) > sma.nStates:
            raise BpodError('Error: Could not send state machine - some states were referenced by name, but not subsequently declared.')
        Message = (ord('C'),)
        Message += (sma.nStates,)
        for i in range(sma.nStates): # Send state timer transitions (for all states)
            if math.isnan(sma.stateTimerMatrix[i]):
                Message += (sma.nStates,)
            else:
                Message += (sma.stateTimerMatrix[i],)
        for i in range (sma.nStates): # Send event-triggered transitions (where they are different from default)
            currentStateTransitions = sma.inputMatrix[i]
            nTransitions = len(currentStateTransitions)
            Message += (nTransitions,)
            for j in range (nTransitions):
                thisTransition = currentStateTransitions[j]
                Message += (thisTransition[0],)
                destinationState = thisTransition[1]
                if math.isnan(destinationState):
                    Message += (sma.nStates,)
                else:
                    Message += (destinationState,)
        for i in range (sma.nStates): # Send hardware states (where they are different from default)
            currentHardwareState = sma.outputMatrix[i]
            nDifferences = len(currentHardwareState)
            Message += (nDifferences,)
            for j in range (nDifferences):
                thisHardwareConfig = currentHardwareState[j]
                Message += (thisHardwareConfig[0],)
                Message += (thisHardwareConfig[1],)
        for i in range (sma.nStates): # Send global timer-start triggered transitions (where they are different from default)
            currentStateTransitions = sma.globalTimers.startMatrix[i]
            nTransitions = len(currentStateTransitions)
            Message += (nTransitions,)
            for j in range (nTransitions):
                thisTransition = currentStateTransitions[j]
                Message += (thisTransition[0] - self.stateMachineInfo.Pos.globalTimerStart,)
                destinationState = thisTransition[1]
                if math.isnan(destinationState):
                    Message += (sma.nStates,)
                else:
                    Message += (destinationState,)
        for i in range (sma.nStates): # Send global timer-end triggered transitions (where they are different from default)
            currentStateTransitions = sma.globalTimers.endMatrix[i]
            nTransitions = len(currentStateTransitions)
            Message += (nTransitions,)
            for j in range (nTransitions):
                thisTransition = currentStateTransitions[j]
                Message += (thisTransition[0] - self.stateMachineInfo.Pos.globalTimerEnd,)
                destinationState = thisTransition[1]
                if math.isnan(destinationState):
                    Message += (sma.nStates,)
                else:
                    Message += (destinationState,)
        for i in range (sma.nStates): # Send global counter triggered transitions (where they are different from default)
            currentStateTransitions = sma.globalCounters.matrix[i]
            nTransitions = len(currentStateTransitions)
            Message += (nTransitions,)
            for j in range (nTransitions):
                thisTransition = currentStateTransitions[j]
                Message += (thisTransition[0] - self.stateMachineInfo.Pos.globalCounter,)
                destinationState = thisTransition[1]
                if math.isnan(destinationState):
                    Message += (sma.nStates,)
                else:
                    Message += (destinationState,)
        for i in range (sma.nStates): # Send condition triggered transitions (where they are different from default)
            currentStateTransitions = sma.conditions.matrix[i]
            nTransitions = len(currentStateTransitions)
            Message += (nTransitions,)
            for j in range (nTransitions):
                thisTransition = currentStateTransitions[j]
                Message += (thisTransition[0] - self.stateMachineInfo.Pos.condition,)
                destinationState = thisTransition[1]
                if math.isnan(destinationState):
                    Message += (sma.nStates,)
                else:
                    Message += (destinationState,)
        for i in range(self.HW.n.GlobalTimers):
            Message += (sma.globalTimers.channels[i],)
        for i in range(self.HW.n.GlobalTimers):
            Message += (sma.globalTimers.onMessages[i],)
        for i in range(self.HW.n.GlobalTimers):
            Message += (sma.globalTimers.offMessages[i],)
        for i in range(self.HW.n.GlobalCounters):
            Message += (sma.globalCounters.attachedEvents[i],)
        for i in range(self.HW.n.Conditions):
            Message += (sma.conditions.channels[i],)
        for i in range(self.HW.n.Conditions):
            Message += (sma.conditions.values[i],)
        sma.stateTimers = sma.stateTimers[:sma.nStates]
        ThirtyTwoBitMessage = [i*self.HW.cycleFrequency for i in sma.stateTimers] + [i*self.HW.cycleFrequency for i in sma.globalTimers.timers] + [i*self.HW.cycleFrequency for i in sma.globalTimers.onsetDelays] + sma.globalCounters.thresholds
        self.serialObject.write(Message, 'uint8', ThirtyTwoBitMessage, 'uint32')
        self.stateMachine = sma
        self.status.newStateMachineSent = 1;
    def runStateMachine(self):
        from datetime import datetime
        self.stateMachineStartTime = datetime.now()
        RawEvents = Struct()
        eventPos = 0
        currentState = 0
        StateChangeIndexes = []
        RawEvents.Events = []
        RawEvents.EventTimestamps = []
        RawEvents.States = [currentState]
        RawEvents.StateTimestamps = [0]
        RawEvents.TrialStartTimestamp = 0;
        self.serialObject.write(ord('R'), 'uint8')
        if self.status.newStateMachineSent == 1:
            confirmed = self.serialObject.read('uint8')
            if not confirmed:
                raise BpodError('Error: The last state machine sent was not acknowledged by the Bpod device.')
            self.status.newStateMachineSent = 0
        runningStateMachine = True
        while runningStateMachine:
            if self.serialObject.bytesAvailable() > 0:
                opCodeBytes = self.serialObject.readArray(2, 'uint8')
                opCode = opCodeBytes[0]
                if opCode == 1: # Read events
                    nCurrentEvents = opCodeBytes[1]
                    CurrentEvents = self.serialObject.readArray(nCurrentEvents, 'uint8')
                    TransitionEventFound = False
                    for i in range(nCurrentEvents):
                        thisEvent = CurrentEvents[i]
                        if thisEvent == 255:
                            runningStateMachine = False
                        else:
                            RawEvents.Events.append(thisEvent)
                            if not TransitionEventFound:
                                thisStateTransitions = self.stateMachine.inputMatrix[currentState]
                                nTransitions = len(thisStateTransitions)
                                for j in range(nTransitions):
                                    thisTransition = thisStateTransitions[j]
                                    if thisTransition[0] == thisEvent:
                                        currentState = thisTransition[1]
                                        if not math.isnan(currentState):
                                            RawEvents.States.append(currentState)
                                            StateChangeIndexes.append(len(RawEvents.Events)-1)
                                        TransitionEventFound = True
                            if not TransitionEventFound:
                                thisStateTimerTransition = self.stateMachine.stateTimerMatrix[currentState]
                                if thisEvent == self.stateMachineInfo.Pos.Tup:
                                    if not (thisStateTimerTransition == currentState):
                                        currentState = thisStateTimerTransition
                                        if not math.isnan(currentState):
                                            RawEvents.States.append(currentState)
                                            StateChangeIndexes.append(len(RawEvents.Events)-1)
                                        TransitionEventFound = True
                            if not TransitionEventFound:
                                thisGlobalTimerTransitions = self.stateMachine.globalTimers.startMatrix[currentState]
                                nTransitions = len(thisGlobalTimerTransitions)
                                for j in range(nTransitions):
                                    thisTransition = thisGlobalTimerTransitions[j]
                                    if thisTransition[0] == thisEvent:
                                        currentState = thisTransition[1]
                                        if not math.isnan(currentState):
                                            RawEvents.States.append(currentState)
                                            StateChangeIndexes.append(len(RawEvents.Events)-1)
                                        TransitionEventFound = True
                            if not TransitionEventFound:
                                thisGlobalTimerTransitions = self.stateMachine.globalTimers.endMatrix[currentState]
                                nTransitions = len(thisGlobalTimerTransitions)
                                for j in range(nTransitions):
                                    thisTransition = thisGlobalTimerTransitions[j]
                                    if thisTransition[0] == thisEvent:
                                        currentState = thisTransition[1]
                                        if not math.isnan(currentState):
                                            RawEvents.States.append(currentState)
                                            StateChangeIndexes.append(len(RawEvents.Events)-1)
                                        TransitionEventFound = True
                elif opCode == 2: # Handle soft code
                    SoftCode = opCodeBytes[1]
        RawEvents.TrialStartTimestamp =  float(self.serialObject.read('uint32'))/1000 # Start-time of the trial in milliseconds
        nTimeStamps = self.serialObject.read('uint16')
        TimeStamps = self.serialObject.readArray(nTimeStamps, 'uint32')
        RawEvents.EventTimestamps = [i/float(self.HW.cycleFrequency) for i in TimeStamps];
        for i in range(len(StateChangeIndexes)):
            RawEvents.StateTimestamps.append(RawEvents.EventTimestamps[StateChangeIndexes[i]])
        RawEvents.StateTimestamps.append(RawEvents.EventTimestamps[-1])
        return RawEvents
    def addTrialEvents(self, RawEvents):
        if not hasattr(self.data, 'nTrials'):
            self.data.nTrials = 0
            self.data.info = Struct()
            if self.firmwareVersion < 7:
                self.data.info.BpodVersion = 5
            else:
                self.data.info.BpodVersion = 7
            self.data.sessionDateTime = self.stateMachineStartTime
            self.data.sessionStartTime = str(self.stateMachineStartTime)
            self.data.trialStartTimestamp = []
            self.data.rawData = []
            self.data.rawEvents = Struct()
            self.data.rawEvents.Trial = []

        self.data.rawEvents.Trial.append(Struct())
        self.data.rawEvents.Trial[self.data.nTrials].Events = Struct()
        self.data.rawEvents.Trial[self.data.nTrials].States = Struct()
        self.data.trialStartTimestamp.append(RawEvents.TrialStartTimestamp)
        self.data.rawData.append(RawEvents)
        states = RawEvents.States
        events = RawEvents.Events
        nStates = len(states)
        nEvents = len(events)
        nPossibleStates = self.stateMachine.nStates
        visitedStates = [0]*nPossibleStates
        # determine unique states while preserving visited order
        uniqueStates = []
        nUniqueStates = 0
        uniqueStateIndexes = [0]*nStates
        for i in range(nStates):
            if states[i] in uniqueStates:
                uniqueStateIndexes[i] = uniqueStates.index(states[i])
            else:
                uniqueStateIndexes[i] = nUniqueStates
                nUniqueStates += 1
                uniqueStates.append(states[i])
                visitedStates[states[i]] = 1
        uniqueStateDataMatrices = [[] for i in range(nStates)]
        # Create a 2-d matrix for each state in a list
        for i in range(nStates):
            uniqueStateDataMatrices[uniqueStateIndexes[i]] += [(RawEvents.StateTimestamps[i], RawEvents.StateTimestamps[i+1])]
        # Append one matrix for each unique state
        for i in range(nUniqueStates):
            thisStateName = self.stateMachine.stateNames[uniqueStates[i]]
            setattr(self.data.rawEvents.Trial[self.data.nTrials].States, thisStateName, uniqueStateDataMatrices[i])
        for i in range(nPossibleStates):
            thisStateName = self.stateMachine.stateNames[i]
            if not visitedStates[i]:
                setattr(self.data.rawEvents.Trial[self.data.nTrials].States, thisStateName, [(float('NaN'), float('NaN'))])
        for i in range(nEvents):
            thisEvent = events[i]
            thisEventName = self.stateMachineInfo.eventNames[thisEvent]
            thisEventIndexes = [j for j,k in enumerate(events) if k == thisEvent]
            thisEventTimestamps = []
            for i in thisEventIndexes:
                thisEventTimestamps.append(RawEvents.EventTimestamps[i])
            setattr(self.data.rawEvents.Trial[self.data.nTrials].Events, thisEventName, thisEventTimestamps)
        self.data.nTrials += 1
    def manualOverride(self, channelType, channelName, channelNumber, value):
        if channelType.lower() == 'input':
            raise BpodError('Manually overriding a Bpod input channel is not yet supported in Python.')
        elif channelType.lower() == 'output':
            if channelName == 'Valve':
                if value > 0:
                    value = math.pow(2,channelNumber-1)
                channelNumber = self.HW.Pos.output_SPI
                byteString = (ord('O'), channelNumber, value)
            elif channelName == 'Serial':
                 byteString = (ord('U'), channelNumber, value)
            else:
                try:
                    channelNumber = self.stateMachineInfo.outputChannelNames.index(channelName + str(channelNumber))
                    byteString = (ord('O'), channelNumber, value)
                except:
                    raise BpodError('Error using manualOverride: ' + channelName + ' is not a valid channel name.')
            self.serialObject.write(byteString, 'uint8')
        else:
            raise BpodError('Error using manualOverride: first argument must be "Input" or "Output".')
    def loadSerialMessage(self, serialChannel, messageID, message):
        nMessages = 1
        messageLength = len(message)
        if messageLength > 3:
            raise BpodError('Error: Serial messages cannot be more than 3 bytes in length.')
        if (messageID > 255) or (messageID < 1):
            raise BpodError('Error: Bpod can only store 255 serial messages (indexed 1-255).')
        ByteString = (ord('L'), serialChannel-1, nMessages, messageID, messageLength) + message
        print ByteString
        self.serialObject.write(ByteString, 'uint8')
        Confirmed = self.serialObject.read('uint8');
        if (not Confirmed):
            raise BpodError('Error: Failed to set serial message.')
    def resetSerialMessages(self):
        self.serialObject.write(ord('>'), 'uint8')
        Confirmed = self.serialObject.read('uint8');
        if (not Confirmed):
            raise BpodError('Error: Failed to reset serial message library.')
    def disconnect(self):
        self.serialObject.write(ord('Z'), 'uint8')

class Struct:
    pass

class BpodError(Exception):
    pass
