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
function CloseBpodSaveAsync(pool, dq, saver, varargin)
    % CloseBpodSaveAsyn: Close asynchronous saving process
    % varargin for optional timeout argument

    if nargin > 3
        timeout = varargin{1};
    else
        timeout = 60;
    end

    send(dq, false);

    tic
    while toc < timeout

        if strcmp(saver.State, 'finished')
            break;
        end

    end

    delete(pool);

end
