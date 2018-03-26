%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2018 Sanworks LLC, Stony Brook, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}
classdef PortArrayModule < handle
    properties
        Port % ArCOM Serial port
        valveState = zeros(1,4);
        ledBrightness = zeros(1,4);
    end
    properties (SetAccess = protected)
        FirmwareVersion = 0;
    end
    properties (Access = private)
        CurrentFirmwareVersion = 1;
        eventsTemplate % Struct with fields for events returned with USB streaming
        timeByteMask % Logical array to index time bytes in USB streaming frames
        eventByteMask % Logical array to index event bytes in USB streaming frames
        usbStreaming = 0; % 1 if module is streaming events via USB, 0 if not 
        Initialized = 0; % Set to 1 after constructor finishes running
    end
    methods
        function obj = PortArrayModule(portString)
            obj.Port = ArCOMObject_Bpod(portString, 115200);
            obj.Port.write(255, 'uint8');
            response = obj.Port.read(1, 'uint8');
            if response ~= 254
                error('Could not connect =( ')
            end
            obj.FirmwareVersion = obj.Port.read(1, 'uint32');
            if obj.FirmwareVersion < obj.CurrentFirmwareVersion
                error(['Error: old firmware detected - v' obj.FirmwareVersion '. The current version is: ' obj.CurrentFirmwareVersion '. Please update the I2C messenger firmware using Arduino.'])
            end
            obj.timeByteMask = repmat(logical([1 1 1 1 1 1 1 1 0 0 0 0]), 1, 1000);
            obj.eventByteMask = repmat(logical([0 0 0 0 0 0 0 0 1 1 1 1]), 1, 1000);
            obj.eventsTemplate = struct;
            obj.eventsTemplate.about = struct;
            obj.eventsTemplate.about.events = 'Event codes for ports: 1 = Port1In, 2 = Port1Out, 3 = Port2In,... 8 = Port4Out';
            obj.eventsTemplate.about.eventTimestamps = 'Time of each port event (in seconds); Reset port array clock with resetClock()';
            obj.eventsTemplate.events = zeros(1,10000);
            obj.eventsTemplate.eventTimestamps = zeros(1,10000);
            obj.Initialized = 1;
        end
        function set.valveState(obj, stateVector)
            if obj.Initialized
                if (length(stateVector) < 4) || (sum(stateVector > 1) > 0) || (sum(stateVector < 0) > 0)
                    error('Error: You must provide a vector of 4 valve states: 0=closed, 1=open (or modify one position of the .valveState vector).')
                end
                ValveBits = sum((stateVector).*(2.^(0:3)));
                obj.Port.write(['B' ValveBits], 'uint8');
                if ~obj.usbStreaming
                    Confirmed = obj.Port.read(1, 'uint8');
                    if Confirmed ~= 1
                        error('Error setting valves. Confirm code not returned.');
                    end
                end
            end
            obj.valveState = stateVector;
        end
        function set.ledBrightness(obj, stateVector)
            if obj.Initialized
                if (length(stateVector) < 4) || (sum(stateVector > 255) > 0) || (sum(stateVector < 0) > 0)
                    error('Error: You must provide a vector of 4 PWM values in range 0-255 (or modify one position of the .ledBrightness vector).')
                end
                obj.Port.write(['W' stateVector], 'uint8');
                if ~obj.usbStreaming
                    Confirmed = obj.Port.read(1, 'uint8');
                    if Confirmed ~= 1
                        error('Error setting valves. Confirm code not returned.');
                    end
                end
            end
            obj.ledBrightness = stateVector;
        end
        function state = getPortStates(obj)
            obj.Port.write('S', 'uint8');
            state = double(obj.Port.read(4, 'uint8'));
        end
        function startEventStream(obj)
            obj.Port.write(['U' 1], 'uint8');
            obj.usbStreaming = 1;
        end
        function events = readEventStream(obj)
            events = obj.eventsTemplate;
            nEventFrames = floor(obj.Port.bytesAvailable/12);
            if nEventFrames > 0
                nBytes = nEventFrames*12;
                Message = obj.Port.read(nBytes, 'uint8');
                newTimes = double(typecast(Message(obj.timeByteMask(1:nBytes)), 'uint64'))/1000000;
                newEvents = Message(obj.eventByteMask(1:nBytes));
                Pos = 1; eventPos = 1;
                for i = 1:nEventFrames
                    thisFrameEvents = newEvents(Pos:Pos+3);
                    eventPositions = thisFrameEvents > 0;
                    nEventsInFrame = sum(eventPositions);
                    events.events(eventPos:eventPos+nEventsInFrame-1) = thisFrameEvents(eventPositions);
                    events.eventTimestamps(eventPos:eventPos+nEventsInFrame-1) = newTimes(i);
                    eventPos = eventPos + nEventsInFrame;
                    Pos = Pos + 4;
                end
                events.events = events.events(1:eventPos-1);
                events.eventTimestamps = events.eventTimestamps(1:eventPos-1);
            else
                events.events = [];
                events.eventTimestamps = [];
            end
        end
        function endEventStream(obj)
            obj.Port.write(['U' 0], 'uint8');
            obj.usbStreaming = 0;
        end
        function resetClock(obj)
            obj.Port.write('R', 'uint8');
        end
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
end