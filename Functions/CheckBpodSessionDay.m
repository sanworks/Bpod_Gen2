%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2019 Sanworks LLC, Stony Brook, New York, USA

----------------------------------------------------------------------------

This program is free software:you can redistribute it and / or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see < http: // www.gnu.org / licenses /> .
%}
function [newDayTrials, latestFileTime] = CheckBpodSessionDay(data)

    newDayTrials = [];
    latestFileTime = [];

    if isfield(data, 'DataTimestamp')

        if isfield(data.Info, 'FileStartTime_MATLAB')
            latestFileTime = data.Info.FileStartTime_MATLAB;
        else
            latestFileTime = data.Info.SessionStartTime_MATLAB;
        end

        newDayTrials = find(data.DataTimestamp - latestFileTime > 1);

    end

end
