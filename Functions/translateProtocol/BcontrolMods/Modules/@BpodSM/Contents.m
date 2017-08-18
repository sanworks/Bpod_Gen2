
% This directory contains the StateMachine object for the RTLinux
% state machine.
%
% Methods:
%
% sm = RTLSM2(host, port, which_state_machine)
%                Create a new RTLinux state machine handle that
%                connects to the state machine server running on
%                host, port.  Since a state machine server can
%                handle more than one virtual state machine,
%                which_state_machine specifies which of the 6 state
%                machines on the server to use.  See
%                GetStateMachine.m for more details. 
%
%                Parameter #2, port, defaults  to 3333 if not
%                specified.  
%
%                Parameter #3, which_state_machine defaults to 0
%
%                The new state machine will have the following
%                default properties set:
%
%                  fsm = SetOutputRouting(fsm, struct('type', 'dout', ...
%                                         'data', '0-15') ; ...
%                                         struct('type', 'sound', ...
%                                         'data', sprintf('%d', which_state_machine)))
%                  fsm = SetInputEvents(sm, 6);
%
%                The sm will not have any SchedWave matrix, or any
%                state matrix.
%
% sm = Initialize(sm) 
%                This is equivalent to a reboot of the
%                StateMachine. It clears all variables, including
%                the state matrices, and initializes the
%                FSM. Initialize() does not start the
%                StateMachine running.   It is necessary to call
%                Run() to do that.
% 
% sm = Run(sm)   Unpauses a halted StateMachine: events have an effect
%                again. After an Initialize(), Run() starts the
%                machine in state 0. After a Halt(), Run() restarts
%                the machine in whatever state is was halted. Note
%                that calling Run() before the state matrices have
%                been defined produces undefined behavior and
%                should be avoided.
%
% sm = Halt(sm)  Stops the StateMachine, putting it in a halted
%                state. In this state, input events do not have 
%                any effect and state transitions are not made. 
%                Variables are not cleared, however, and so they
%                can be read by other programs (such as your Matlab
%                code).  Calling Run() will resume a halted state machine.
%
%                NB: A freshly Initialize()'d StateMachine is in the *halted*
%                state. Halting an already halted StateMachine has
%                no effect.
%
% sm = SetStateMatrix(sm, Matrix state_matrix) 
%
%                This command defines the state matrix that governs
%                the control algorithm during behavior trials. 
%           
%                It is an M x N matrix where M is the number of
%                states (so each row corresponds to a state) and N
%                is the number of input events + output events per state.
%
%                This state_matrix can have nearly unlimited rows 
%                (i.e., states), and has a variable number of
%                columns, depending on how many input events are
%                defined.  
%
%                To specify the number of input events,
%                see SetInputEvents().  The default number of input
%                events is 6 (CIN, COUT, LIN, LOUT, RIN, ROUT).  In
%                addition to the input event columns, the state matrix
%                also has 4 or 5 additional columns: TIMEOUT_STATE
%                TIMEOUT_TIME CONT_OUT TRIG_OUT and the optional
%                SCHED_WAVE.
%
%                Note:
%                   (1) the part of the state matrix that is being
%                   run during intertrial intervals should remain
%                   constant in between any two calls of
%                   Initialize()
%                   (2) that SetStateMatrix() should only be called
%                   in between trials.
%
% sm = Set_StateMatrix(sm, Matrix state_matrix)
%                An alias for SetStateMatrix().  See the help for
%                that function instead.
%
% sm = AddHappeningSpec(sm, spec)   Add to the available happening specs.
%                Will not take effect until next SetStateMatrix
%
% prog = GetStateProgram(sm)
%                Query the FSM server to retreive the exact
%                text of the C program it is using.
%
% sm = SetStateProgram(sm, ...) 
%
%                This command defines the embedded C state matrix
%                program that governs the control algorithm during 
%                behavioral trials.   It works in much the same way
%                as SetStateMatrix.m, except that it allows you to
%                specify a more powerful specification -- that of
%                an embedded C based state matrix program.
%
%                The embedded C state program is an MxN cell array
%                of strings and/or numbers where M is the number of
%                states (so each row corresponds to a state) and N
%                is the number of input events + output events per
%                state.
%
%                The contents of a cell get evaluated to a C
%                expression at runtime, so that a numeric cell
%                becomes a literal number in C.   A string cell
%                becomes a C expression.  All cells in the matrix
%                should evaluate to a numeric type, ultimately.
%                For example, the following is a valid state matrix program:
%
%                { 1 0  0 0 0 '0' 1 'log(a)' 0 0 ; ...
%                  1 0 '1' 1 1 1 0 'log(b)' 0 0 };
%
%
%                Where 'a' and 'b' are two variables that exist in your
%                C program, and 'log' is a function provided by the
%                C API (see C API Functions below). 
%                The variables 'a' and 'b' above need to be
%                declared as 'globals' in your program (see globals
%                property below).
%
%                This state matrix program can have nearly unlimited rows 
%                (i.e., states), and has a variable number of
%                columns, depending on how many input events are
%                defined.  
%
%                To specify the number of input events,
%                see SetInputEvents().  The default number of input
%                events is 6 (CIN, COUT, LIN, LOUT, RIN, ROUT).  In
%                addition to the input event columns, the state matrix
%                also has 4 or 5 additional columns: TIMEOUT_STATE
%                TIMEOUT_TIME CONT_OUT TRIG_OUT and the optional
%                SCHED_WAVE.
%
%                This function is like other matlab functions in
%                that it takes a variable number of arguments in
%                the form of 'property', propertyval.  A list of
%                valid properties and their meanings is illustrated
%                in the documentation for SetStateProgram.m
%
%                Note:
%                   (1) the part of the state matrix that is being
%                   run during intertrial intervals should remain
%                   constant in between any two calls of
%                   Initialize()
%                   (2) that SetStateProgram() should only be called
%                   in between trials.
%                   (3) all variables get cleared when a new trial
%                   begins -- cross-trial persistence is altogether
%                   missing.
%
% num = GetStateMachine(fsm)
%                Query the FSM server to find out which of the 6
%                state machines we are connected to.
%
% fsm = SetStateMachine(fsm, which_sm)
%                Tell the FSM server to start using which_sm.
%                which_sm is a value from 0 to 5 to indicate which
%                of the 6 state machines on the FSM server we are
%                going to use.  
%
%                Note it is important to also make sure the number
%                of the state machine corresponds to the number of
%                the soundcard used for sound triggering.  See 
%                SetOutputRouting.m
%
% mapping = GetInputEvents(sm)
%                Returns the input event mapping vector for this FSM.  This
%                vector was set with a call to SetInputEvents (or was 
%                default).  The format for this vector is described in
%                SetInputEvents() above.
%
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
% a_cell = GetOutputRouting(fsm)
%                Retreive the currently specified output routing
%                for the fsm.  Note that output routing takes
%                effect on the next call to SetStateMatrix().  For
%                more documentation on output routing see the help
%                for SetOutputRouting.m
%
% fsm = SetOutputRouting(fsm, routing)
%                Modify the output routing for a state machine.
%                Output routing is the specification that the state
%                machine uses for doing output when a new state is
%                entered.  Using this call, you can specify the
%                precise number and meaning of the last few columns of
%                the state machine (which are typically output
%                columns).  New output routings take effect after the
%                next call to SetStateMatrix.
%
%                Default output routing is:
%
%                { struct('type', 'dout', ...
%                         'data', '0-15') ; ...
%                  struct('type', 'sound', ...
%                         'data', sprintf('%d', fsm.fsm_id)) };
%
%                See SetOutputRouting.m help for more details on
%                this specification.
%
% sm = ForceTimeUp(sm) 
%                Sends a signal to the state machine that is
%                equivalent to there being a TimeUp event in the
%                state that the machine is in when the
%                ForceTimeUp() signal is received. Note that due to
%                the asynchronous nature of the link between Matlab
%                and StateMachines, the StateMachine framework
%                itself provides no guarantees as to what state the
%                machine will be in when the ForceTimeUp() signal
%                is received.
%
% sm = ReadyToStartTrial(sm)  
%                Signals to the StateMachine that it is ok
%                to start a new trial. After this routine is called,
%                the next time that the StateMachine reaches state 35,
%                it will immediately jump to state 0, and a new trial starts.
%
% sm = SetScheduledWaves(sm, sched_matrix)
%                Specifies the scheduled waves matrix for a state machine.  
%                This is an M by 9 matrix of the following format
%                per row:
%                ID IN_EVENT_COL OUT_EVENT_COL DIO_LINE SOUND_TRIG PREAMBLE SUSTAIN REFRACTION LOOP
%                Note that this function doesn't actually modify the 
%                SchedWaves of the FSM immediately.  Instead, a new 
%                SetStateMatrix call needs to be issued for the effects of 
%                this function to actually get uploaded to the external
%                RTLinux FSM.
%                See SetScheduledWaves.m for a full description.
%
%                Note: it is now necessary to call SetOutputRouting()
%                in order to specify a column of the state matrix that
%                actually TRIGGERS these scheduled waves.  See
%                SetOutputRouting.m documentation for more details.
%
% sm = SetScheduledWaves(sm, sched_wave_id, ao_line, loop_bool, two_by_n_matrix)
%                Specifies a scheduled wave using analog I/O for a state 
%                machine.  The sched_wave_id is in the same id-space as the
%                digital scheduled waves described above. The ao_line is
%                the analog output channel to use, starting at 1 for the
%                first AO line.  loop_bool determines whether this AO wave
%                should loop until untriggered. The last parameter, a
%                2-by-n matrix, is described in the detailed documentation.  
%                See SetScheduledWaves.m for a full description.
%
%                Note: it is now necessary to call
%                SetOutputRouting() in order to specify a column
%                of the state matrix that actually TRIGGERS these
%                scheduled waves.  See SetOutputRouting.m
%                documentation for more details.
%
% sm = ClearScheduledWaves(sm)
%                 Clears all the scheduled waves specified by calls to
%                 SetScheduledWaves.  Like SetScheduledWaves, this takes
%                 effect after the next call to SetStateMatrix.
%
% scheds = GetDIOScheduledWaves(sm)
%                Get copy of the DIO scheduled waves registered with
%                SetScheduledWaves.  
%
% sm = StartDAQ(sm, vector_of_chan_ids, optional_preferred_range_vector)
%                Specify a set of channels for analog data
%                acquisition, and start the acquisition.
%
%                Pass a vector of channel id's which is the set of
%                analog input channels that should appear in each scan.
%                
%                For the purposes of this function, channel id's are
%                indexed from 1.  
%                See StartDAQ.m documentation for a full description info.
%
% scan_matrix = GetDAQScans(sm)
%                Retreive the latest block of scans available (if
%                the state machine is acquiring data).  See StartDAQ().
%
%                The returned matrix is MxN where M is the number of scans
%                available since the last call to GetDAQScans and N
%                is a timestamp column followed by the scan voltage
%                value.
%
% sm = StopDAQ(sm)
%                Stop the currently-running data acquisition.  See
%                StartDAQ().
%
% sm = RegisterEventsCallback(sm, callback) 
% sm = RegisterEventsCallback(sm, callback, callback_on_connection_failure) 
%                Enable asynchronous notification as the FSM gets new
%                events (state transitions).  Your callback code is
%                executed as new events are generated by the FSM.
%                Your code is evaluated (using the equivalent of an
%                eval).  When your code runs, the event(s) that just
%                occurred are in an Mx4 matrix (as would be returned
%                from GetEvents()) as the special variable 'ans'.
%                Thus, your callback code should save this variable
%                right away lest it be destroyed by subsequent matlab
%                statements.  Pass an empty callback to disable the
%                EventsCallback mechanism (or call
%                StopEventsCallback).
%
%                Optionally you can pass a third parameter, an
%                additional callback to use so that your code can be
%                notified if there is an unexpected TCP connection
%                loss to the FSM server.  This is so that your code
%                can be notified that no more events will come in due
%                to a connection loss.  Otherwise, it would be
%                impossible to know that no more events are possible
%                -- your code might wait forever for events that will
%                never arrive.  Possible actions to take in this
%                callback include displaying error messages in matlab
%                and/or trying to restart the connection by calling
%                RegisterEventsCallback again.
%
%                Note: This entire callback mechanism only works under
%                Windows currently and requires that the executable
%                FSM_Event_Notification_Helper_Process.exe be in your
%                Windows PATH or in the current working directory!
%
%                Note 2: The events callback mechanism is highly
%                experimental and as such, only a maximum of 1
%                callbacks may be registered and enabled at a time
%                globally for all instances of RTLSM2 objects in the
%                matlab session.  What does this mean?  That
%                subsequent calls to this function for *any* insance
%                of an @RTLSM2 will actually kill/disable the existing
%                callback that was previously registered/active for
%                any other instance of an @RTLSM2.  
%
% sm = StopEventsCallback(sm) 
%                Disables asynchronous notification, unregistering 
%                any previously-regsitered callbacks. 
%                See RegisterEventsCallback.m
%
% [] = Close(sm) Begone! Begone!
%
%
% sm = BypassDout(sm, int d)  
%                Sets the digital outputs to be whatever the
%                state machine would indicate, bitwise or'd with
%                "d." To turn this off, call BypassDout(0).
%
% [] = Trigger(sm, int d) 
%                Bypass the control over output triggers, and set
%                off the indicated trigger. (In the RM1 implementation
%                in use in August 2005, these triggers go to the analog
%                outputs of the RM1 box.) 
% %
% [int nevents] = GetEventCounter(sm)   
%                Get the number of events that have occurred since
%                the last call to Initialize().
%
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
%
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
%                -1=TUP or no detected event, (e.g. when a jump to state 0 is forced)
% 
%                the third is the time, in seconds, at which the
%                event occurred.
%
%                the fourth is the new state that was entered as a
%                result of the state transition
%
% [double time] = GetTime(sm)    
%                Gets the time, in seconds, that has elapsed since
%                the last call to Initialize().
%
% [struct]=      GetTimeEventsAndState(sm, first_event_num)
%                Gets the time, in seconds, that has elapsed since
%                the last call to Initialize(), as well as the Events matrix
%                starting from first_event_num up until the present.
%
%                The returned struct has the following 4 fields:
%                        time: (time in seconds)
%                        state: (state number state machine is currently in)
%                        event_ct: (event number of the latest event)
%                        events: (m by 5 matrix of events)
%
% [int r]       = IsRunning(sm)  return 1 if running, 0 if halted    
%
% [int n_vars] = GetVarLogCounter(sm)   
%                Get the number of variables that have been logged
%                since the last call to Initialize().
%
% [mode]       = GetAIMode(sm)
%                Retrieve the current data acquisition mode for the AI 
%                subdevice.  Possible modes returned are:
%                'asynch' -- asynchronous acquisition -- this is faster 
%                            since it happens independent of the FSM, but 
%                            is less compatible with all boards.
%                'synch'  -- synchronous acquisition -- the default
%                            works reliably with all boards.
%
% [sm]         = SetAIMode(sm, mode)
%                Set the data acquisition mode to use for the AI 
%                subdevice.  Possible modes to use are:
%                'asynch' -- asynchronous acquisition -- this is faster 
%                            since it happens independent of the FSM, but 
%                            is less compatible with all boards.
%                'synch'  -- synchronous acquisition -- the default
%                            works reliably with all boards.
%
% ----- Control issues ----------
%
%
% sm = FlushQueue(sm)   
%
%                In the RTLSM2, this does nothing.
%
%                Some state machines (e.g., RM1s, RTLinux boxes)
%                will be self-running; others need a periodic ping
%                to operate on events in their incoming events
%                queue. This function is used for the latter type
%                of StateMachines. In self-running state machines,
%                it is o.k. to define this function to do nothing.
%
% [intvl_ms] = PreferredPollingInterval(sm)    
%
%                In the RTLSM2 this does nothing.
%
%                For machines that require FlushQueue() calls, this
%                function returns the preferred interval between
%                calls. Note that there is no guarantee that this
%                preferred interval will be respected. intvl_ms is
%                in milliseconds. 
%
