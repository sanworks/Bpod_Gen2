%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright(C) 2019 Sanworks LLC, Stony Brook, New York, USA

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
function [pool, saverQueue, saver] = StartBpodSaveAsync(varargin)
    % StartBpodSaveAsync: Start asynchronous saving process
    % varargin for timeout

    if nargin > 0
        timeout = varargin{1};
    else
        timeout = 60;
    end

    global BpodSystem

    pool = gcp('nocreate');

    if isempty(pool)
        pool = parpool('local', 1);
    end

    protocolQueue = parallel.pool.PollableDataQueue;
    saver = parfeval(pool, @SaveBpodSessionDataAsync, 0, BpodSystem.Path.CurrentDataFile, BpodSystem.Data, protocolQueue);
    [saverQueue, ok] = poll(protocolQueue, timeout);

    if ~ok
        saver.cancel()
        delete(pool)
        ME = MException('Bpod:AsyncSaveError', ...
            'Could not get pollable queue from asynchronous save process! Please consider using a longer timeout');
        throw(ME)

    end
