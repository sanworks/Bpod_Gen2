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
function SaveBpodSessionData

    global BpodSystem

    %%% check time and date; create a new data file every 24 hours
    % uses the 'DataTimestamp' field. If this doesn't exist, will ignore

    [newDayTrials, latestFileTime] = CheckBpodSessionDay(BpodSystem.Data);

    if ~isempty(newDayTrials)

        % split data into structs with only old and only new data

        [oldData, newData] = SplitBpodSessionData(BpodSystem.Data, newDayTrials(1));

        % save original data

        SessionData = oldData;
        save(BpodSystem.Path.CurrentDataFile, 'SessionData');

        % set new file path and data

        [fp, fn, ext] = fileparts(BpodSystem.Path.CurrentDataFile);
        fspl = split(fn, '_');
        ctime = datestr(latestFileTime, 'HHMMSS');
        cdate = datestr(now, 'yyyymmdd');
        BpodSystem.Path.CurrentDataFile = fullfile(fp, [fspl{1} '_' fspl{2} '_' cdate '_' ctime ext]);
        
        newData.Info.FileStartTime_MATLAB = latestFileTime;
        BpodSystem.Data = newData;

    end

    SessionData = BpodSystem.Data;
    save(BpodSystem.Path.CurrentDataFile, 'SessionData');

end
