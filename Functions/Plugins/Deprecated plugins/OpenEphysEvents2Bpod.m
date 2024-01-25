%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2023 Sanworks LLC, Rochester, New York, USA

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

% IMPORTANT NOTE! This script is for Bpod State Machine r0.5 ONLY. Newer
% state machine models use an improved synchronization scheme.

% IMPORTANT DEPENDENCY! Add to the MATLAB path:
% https://github.com/open-ephys/analysis-tools/blob/master/load_open_ephys_data.m

function [DecimalEvents, Timestamps] = OpenEphysEvents2Bpod(filename)
% This script reads an Open Ephys event file and converts its native format
% to a vector of Bpod state codes and their equivalent timestamps on the
% Open Ephys system clock.
%
% Input arguments: 
% - filename (string). The full path and file name of the Open Ephys event data file.
%
% Output Arguments:
% - DecimalEvents (double). A list of the Bpod state codes recovered from
%   Open Ephys. Values are integers in range [0, 127]
%
% - Timestamps (double). For each event in DecimalEvents, a timestamp on
%   the Open Ephys system clock. The time units are the same as the raw
%   Ephys data to ensure proper alignment.

[data, pinChangeTimestamps, info] = load_open_ephys_data(filename);
Pos = find(info.eventId==1, 1, 'first');
BinaryEventCode = '0000000';
nPinChanges = length(pinChangeTimestamps)-Pos+1;
nTotalTimestamps = length(pinChangeTimestamps);
DecimalEvents = zeros(1,nPinChanges);
Timestamps = zeros(1,nPinChanges);
nEvents = 0;

while Pos <= nTotalTimestamps
    nPinsChanged = sum(pinChangeTimestamps == pinChangeTimestamps(Pos));
    for x = 1:nPinsChanged
        BinaryEventCode(8-(data(Pos)+1)) = num2str(info.eventId(Pos));
        Pos = Pos + 1;
    end
    nEvents = nEvents + 1;
    if (Pos <= nTotalTimestamps)
        DecimalEvents(nEvents) = bin2dec(BinaryEventCode);
        Timestamps(nEvents) = pinChangeTimestamps(Pos);
    else
        i = nPinChanges;
    end
end
DecimalEvents = DecimalEvents(1:nEvents-1);
Timestamps = Timestamps(1:nEvents-1);
% Some systems that read TTL inputs exactly during sync pin update will
% report a false value, followed by the true value on the next measurement.
% The following code will filter out Bpod events that appear to occur less than 1 ephys
% cycle (50us) apart. Note that the Bpod State Machine cycles every 100us, so 100us is the
% smallest possible difference between Bpod events.
RealEvents = diff(Timestamps) > 0.00005;
RealEvents = [1 RealEvents]; % Add a 1 so the indexes of the misreads align
DecimalEvents = DecimalEvents(RealEvents);
Timestamps = Timestamps(RealEvents);