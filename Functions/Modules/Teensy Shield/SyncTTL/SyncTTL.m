%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) Sanworks LLC, Rochester, New York, USA

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

% SyncTTL is a class to sync an incoming TTL signal with the state machine.
% Uses SyncTTL example firmware for Teensy with the Bpod teensy shield.
% Teensy monitors for TTLs on pins 4-6, and byte codes from the state machine in range 0-254
% This class captures and formats Teensy's timestamps for both data streams.
% Note: Teensy will capture TTLs even while the state machine is idle between trials,
% providing an alternative to continuous acquisition with TrialManager.

% Usage:
% SYNC = SyncTTL('COM3'); % Initialize, where 'COM3' is the device's serial port
% SYNC.startAcq; % Start acquiring new sync timestamps
% SyncData = SYNC.SyncData; % Get all sync data captured since first call to startAcq
% clear SYNC % Disconnect from serial port, clear SYNC object and all data

% Data:
% SyncData.values stores the value of the event in range 0,1 for TTLs, 0,254 for FSM byte codes
% SyncData.channels stores the channel of the event. 0 = State Machine, 4-6 = Teensy pins 4-6
% SyncData.times stores the timestamp in seconds

classdef SyncTTL < handle
    properties
        Port % ArCOM Serial port
        SyncData % Sync data struct
    end
    properties (Access = private)
        Timer % MATLAB timer (for reading incoming sync bytes from the serial buffer)
    end
            
    methods
        function obj = SyncTTL(portString)
            % Destroy any orphaned timers from previous instances
            t = timerfindall;
            for i = 1:length(t)
                thisTimer = t(i);
                thisTimerTag = get(thisTimer, 'tag');
                if strcmp(thisTimerTag, ['STTL_' portString])
                    warning('off');
                    delete(thisTimer);
                    warning('on');
                end
            end
            % Create ArCOM wrapper for USB communication with Teensy
            obj.Port = ArCOMObject_Bpod(portString, 115200);
            obj.Port.write(255, 'uint8');
            ack = obj.Port.read(1, 'uint8');
            if ack ~= 250
                error('SyncTTL: Incorrect handshake byte returned');
            end
            obj.SyncData = struct;
            obj.SyncData.values = []; % value of sync message
            obj.SyncData.channels = []; % origin channel of sync message. 0 = state machine byte-code (in range 0-127), 4-6 = Teensy channel 4-6
            obj.SyncData.times = []; % timestamp of sync message
        end

        function startAcq(obj)
            obj.SyncData.values = [];
            obj.SyncData.channels = [];
            obj.SyncData.times = [];
            obj.Timer = timer('TimerFcn',@(h,e)obj.readUSBStream(), 'ExecutionMode', 'fixedRate', 'Period', 0.2, 'Tag', ['STTL_' obj.Port.PortName]);
            start(obj.Timer);
        end

        function endAcq(obj)
            if ~isempty(obj.Timer)
                stop(obj.Timer);
                delete(obj.Timer);
                obj.Timer = [];
            end
        end

        function delete(obj)
            obj.endAcq;
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
    
    methods (Access = private)
        function readUSBStream(obj)
            nPackets2Read = floor(obj.Port.bytesAvailable/10); % Sync packet size = 9 bytes; 8 (64-bit timestamp) + 1 (value)
            if nPackets2Read > 0
                newPackets = obj.Port.read(nPackets2Read*10, 'uint8');
                newChannels = newPackets(9:10:end);
                newValues = newPackets(10:10:end);
                newPackets(9:10:end) = [];
                newPackets(9:9:end) = [];
                newTimes = double(typecast(newPackets, 'uint64'))/1000000;
                obj.SyncData.values = [obj.SyncData.values uint8(newValues)];
                obj.SyncData.channels = [obj.SyncData.channels uint8(newChannels)];
                obj.SyncData.times = [obj.SyncData.times newTimes];
            end
        end
    end
end