%sm = StopDAQ(sm)
%
%                SUMMARY: 
%
%                Stop the currently-running data acquisition.  See StartDAQ().
%
function sm = StopDAQ(sm)
    DoSimpleCmd(sm, 'STOP DAQ');
    
