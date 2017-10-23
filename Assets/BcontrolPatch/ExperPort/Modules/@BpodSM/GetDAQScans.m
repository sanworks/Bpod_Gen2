%scan_matrix = GetDAQScans(sm)
%
%                SUMMARY: 
%
%                Retreive the latest block of scans available (if
%                the state machine is acquiring data).  See StartDAQ().
%
%                The returned matrix is MxN where M is the number of scans
%                available since the last call to GetDAQScans and N
%                is a timestamp column followed by the scan voltage
%                value.
%
%                EXAMPLES:
%
%                To retreive the acquired data call:
%
%                scans = GetDAQScans(sm);
%
function scans = GetDAQScans(sm)


    
     scans = DoQueryMatrixCmd(sm, 'GET DAQ SCANS');
%     try 
%      scans = DoQueryMatrixCmd(sm, 'GET DAQ SCANS');
%     catch
%         error(sprintf([...
%                        'GetDAQScans command failed -- the FSM returned' ...
%                        ' an error status.\n' ...
%                        'Possible source of error:\n' ...
%                        '- the connection to the server was lost?\n' ...
%                        '- a data acquisition is not running\n' ...
%                        '- the FSM version is too old to support DAQ' ...
%                       ]));
%     end;
    return;
    
    