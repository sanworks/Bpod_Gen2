% [EventList]   = GetEvents(sm, int StartEventNumber, int EndEventNumber)
%
%                Gets a matrix in which each row corresponds to an
%                Event; the matrix will have
%                EndEventNumber-StartEventNumber+1 rows and 4
%                columns. (If EndEventNumber is bigger than
%                GetEventCounter(), this produces an error).
%
%                Each of the rows in EventList has 4
%                columns: 
%
%                the first is the state that was current when
%                the event occurred
%
%                the second is the event_id, which is
%                2^(event_column) that occurred. event_column is
%                0-indexed.  See SetInputEvents() for a description
%                of what we mean by event columns.
%
%                In the default event column configuration
%                SetInputEvents(sm, 6), you would have as possible event_id's:
%
%                1=Cin, 
%                2=Cout, 
%                4=Lin, 
%                8=Lout, 
%                16=Rin,
%                32=Rout, 
%                64=Tup, 
%                0=no detected event, (e.g. when a jump to state 0 is forced)
%               
%                the third is the time, in seconds, at which the
%                event occurred.
%
%                the fourth is the new state that was entered as a
%                result of the state transition
function [eventList] = GetEvents(sm, start_no, end_no)
    if start_no > end_no,
        eventList = zeros(0,4);
    else
        eventList = DoQueryMatrixCmd(sm, sprintf('GET EVENTS %d %d', start_no-1, end_no-1));
    end;

