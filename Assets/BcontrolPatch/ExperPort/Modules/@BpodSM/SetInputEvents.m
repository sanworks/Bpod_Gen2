% sm = SetInputEvents(sm, scalar, string_ai_or_dio)
% sm = SetInputEvents(sm, vector, string_ai_or_dio)
%                Specifies the input events that are caught by the state
%                machine and how they relate to the state matrix.
%                The first simple usage of this function just tells the 
%                state machine that there are SCALAR number of input
%                events, so there should be this many columns used in the
%                state matrix for input events.  The last parameter to 
%                these function(s) is a string specifying either: 'ai' or
%                'dio'.  The string 'ai' signifies we are monitoring AI
%                lines for input events.  'dio' signifies we are monitoring
%                DIO lines for input events.  (All other strings will
%                generate an error, of course.)
%
%                The second usage of this function actually specifies how
%                the state machine should route physical input channels to 
%                state matrix columns.  Each position in the vector 
%                corresponds to a state matrix column, and the value of 
%                each vector position is the channel number to use for that
%                column.  Positive values indicate a rising edge event, and
%                negative indicate a falling edge event (or OUT event). A
%                value of 0 indicates that this is a 'virtual event' that
%                gets its input from the Scheduled Wave specification.
%
%                So [1, -1, 2, -2, 3, -3] tells the state machine to route
%                channel 1 to the first column as a rising edge input
%                event, channel 1 to the second column as a falling edge
%                input event, channel 2 to the third column as a rising
%                edge input event, and so on.  Each scalar in the vector
%                indicates a channel id, and its sign whether the input
%                event is rising edge or falling edge.  Note that channel
%                id's are numbered from 1, unlike the internal id's NI
%                boards would use (they are numbered from 0), so keep that
%                in mind as your id's might be offset by 1 if you are used
%                to thinking about channel id's as 0-indexed.
%    
%                
%                The first usage of this function is shorthand and will
%                create a vector that contains SCALAR entries as follows:
%                [1, -1, 2, -2, ... SCALAR/2, -(SCALAR/2) ] 
%
%                Note: this new input event mapping does not take effect
%                immediately and requires a call to SetStateMatrix().
%
function sm = SetInputEvents(sm, val, str)

    mat = [];

    if isscalar(val)

        if (val < 0) error('Invalid argument to SetInputEvents: the scalar should be non-negative!'); end;

        mat = zeros(1,val);

        for i = 1:(val)

            c = -1;

            if (mod(i,2)) c = 1; end;

            val(1,i) = ceil(i/2) * c;

        end;
 
    end;
 
    mat = val;

    [m,n] = size(mat);

    if (m > 1), error('Specified matrix is invalid -- it neets to be a 1 x n vector!'); end;

    sm.input_event_mapping = mat;

    if ( ~isequal(str, 'ai') && ~isequal(str, 'dio')), error('Please pass either ai or dio as the third argument @RTLSM2/SetInputEvents'); end;

    sm.in_chan_type = str;   

    return;

