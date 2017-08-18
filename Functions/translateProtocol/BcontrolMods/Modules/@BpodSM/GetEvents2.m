% [EventList]   = GetEvents2(sm, int StartEventNumber, int EndEventNumber)
%
%                Improved version of GetEvents.m which supports more than 32
%                input events.  GetEvents.m had the returned event-id be
%                a bitset where the bit corresponding to the event-column that
%                triggered the state transition would be set.  
%                Use of a bitset meant that the event-id would be
%                2^FSM_COLUMN_OF_INPUT_EVENT, which effectively 
%                limited the maximum event id to 2^31 on 32-bit machines.
%
%                GetEvents2.m fixes that by returning the actual event column 
%                number in col2, rather than 2^event_col.
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
%                the second is the event_column number.
%                See SetInputEvents() for a description
%                of what we mean by event columns.
%
%                In the default event column configuration
%                SetInputEvents(sm, 6), you would have as possible event_id's:
%
%                0=Cin, 
%                1=Cout, 
%                2=Lin, 
%                3=Lout, 
%                4=Rin,
%                5=Rout, 
%                -1=TIME'S UP EVENT *or* no detected event, (e.g. when a jump to state 0 is forced)
%               
%                the third is the time, in seconds, at which the
%                event occurred.
%
%                the fourth is the new state that was entered as a
%                result of the state transition
function [eventList] = GetEvents2(sm, start_no, end_no)
    if start_no > end_no,
        eventList = zeros(0,4);
    else
        eventList = DoQueryMatrixCmd(sm, sprintf('GET EVENTS_II %d %d', start_no-1, end_no-1));
    end;

