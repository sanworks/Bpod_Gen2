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
function SaveBpodSessionData(varargin)

    global BpodSystem

    if nargin > 0
        checkDay = varargin{1};
    else
        checkDay = false;
    end

    if checkDay

        %%% create new data file every 24 hours %%%
        seconds_per_day = 60 * 60 * 24;
        [oldData, newData] = SplitBpodSessionData(BpodSystem.Data, seconds_per_day);

        if ~isequal(newData, struct())

            % save original data
            SessionData = oldData;
            save(BpodSystem.Path.CurrentDataFile, 'SessionData');

            % set new file path
            [fp, fn, ext] = fileparts(BpodSystem.Path.CurrentDataFile);
            fspl = split(fn, '_');
            fspl{3} = datestr(datetime(fspl{3}, "InputFormat", "yyyyMMdd") + 1, "yyyymmdd");
            BpodSystem.Path.CurrentDataFile = fullfile(fp, [strjoin(fspl, "_"), ext]);

            % set new data
            BpodSystem.Data = newData;

        end

    end

    SessionData = BpodSystem.Data;
    save(BpodSystem.Path.CurrentDataFile, 'SessionData');

end
