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
%                valid properties and their meanings is illustrated below:
%
%                Property list for SetStateProgram.m
%                -----------------------------------
%
%                'matrix' (REQUIRED)
%
%                  The argument that follows should be an MxN cell
%                  array of strings and/or numbers that get
%                  evaluated to C expressions of type double.  All
%                  variables appearing in the cells need to either
%                  be declared as globals (see the 'globals'
%                  property) or they need to exist in the C API
%                  (see the C API below).
%
%                'globals' (OPTIONAL)
%
%                  The argument that follows should be a string
%                  that is the free-form C-code that delcares all
%                  globals, typedefs, and implements all functions
%                  that your'matrix' (or other code in your state program)
%                  will reference.  Basically, because this is C, you
%                  need to declare everything, and this is the
%                  place to do it.  Do not forget to implement
%                  functions here too!
%                  
%                'initfunc' (OPTIONAL)
%
%                  The argument that follows should be a string that
%                  is the name of a C function that you would like
%                  executed when the new state machine program starts.
%                  The function should exist in the 'globals' section
%                  described above, or else there will be a runtime
%                  error when the new state machine program is
%                  compiled and/or executed. The function should have
%                  C type signature void (*)(void).
%
%                'cleanupfunc' (OPTIONAL)
%
%                  The argument that follows should be a string that
%                  is the name of a C function that you would like
%                  executed when the new state machine program is
%                  exited and/or destroyed.  The function should exist
%                  in the 'globals' section described above, or else
%                  there will be a runtime error when the new state
%                  machine program tries to execute.  The function
%                  should have C type signature void (*)(void).
%
%                'transitionfunc' (OPTIONAL)
%
%                  The argument that follows should be a string that
%                  is the name of a C function that you would like
%                  executed whenever a state transition occurs. The
%                  function is executed even for 'jump-to-self'
%                  transitions.  The function should exist in the
%                  'globals' section described above, or else there
%                  will be a runtime error when the new state machine
%                  program tries to execute.  The function should have
%                  C type signature void (*)(void).
%
%                'tickfunc' (OPTIONAL)
%
%                  The name of the function (declared and defined in
%                  the 'globals' above) to call for each tick of the
%                  FSM.  This function will be called once for every
%                  FSM cycle (at the beginning of the cycle, before
%                  anything happens)!  This is going to be called as
%                  many times per second as the FSM's cycle rate,
%                  which by default is 6000!  The type of this
%                  function is void(*)(void).
%
%                'threshfunc' (OPTIONAL)
%
%                  The name of the function (declared and defined in
%                  the 'globals' above) to call for AI threshold 
%                  detection in the FSM.  This function will be called 
%                  once for every AI sample acquired for each FSM task 
%                  cycle, so make sure it is a fast, lightweight function!
%                  The type of this function is TRISTATE(*)(int,double).
%                  And the return type is a TRISTATE which can take values:
%                  POSITIVE for upward threshhold crossing, 
%                  NEGATIVE for downward threshold crossing,
%                  or NEUTRAL for no change (historesis band).
%                  Here is the internal function the state machine uses by 
%                  default: 
%
%                  TRISTATE threshold_detect(int chan, double v) 
%                  {
%                    if (v >= 4.0) return POSITIVE; /* if above 4.0 V, 
%                                                      above threshold */
%                    if (v <= 3.0) return NEGATIVE;/* if below 3.0,
%                                                     below threshold */
%                    return NEUTRAL; /* otherwise unsure, so no change */
%                  }
%
%                  Note how the function implements a historesis band
%                  between 3.0 and 4.0 volts.  This is recommended in your 
%                  custom function as well in order to prevent threshold 
%                  detection from flip-flopping back and forth in cases 
%                  where the input signal is noisy.
%
%                'entryfuncs' (OPTIONAL)
%
%                  An associative array of state numbers to function
%                  names.  Functions have type void(*)(void) and will
%                  be called whenever said state number is entered,
%                  but before outputs are done for that state.  Note
%                  that the entryfuncs are called only when a new
%                  state is entered and not for state transitions that
%                  'jump to self'.  This is in accordance with the
%                  state output semantics.  The format for this
%                  parameter is an Mx2 cell matrix where the first
%                  column is the numeric state number
%                  (zero-indexed) and the second column is the name
%                  of the function to call.
%
%                'exitfuncs' (OPTIONAL)
%
%                  An associative array of state numbers to function
%                  names.  Functions have type void(*)(void) and will
%                  be called whenever said state number is
%                  exited. Note that the exitfuncs are called only
%                  when a new state is entered and not for state
%                  transitions that 'jumps to self'.  This is in
%                  accordance with the state output semantics.  The
%                  format for this parameter is an Mx2 cell matrix
%                  where the first column is the numeric state number
%                  (zero-indexed) and the second column is the name of
%                  the function to call.
%
%                'entrycode' (OPTIONAL)
%
%                  Associative array of state numbers to actual C code
%                  to be executed.  Code gets executed upon state
%                  entry (as in entryfuncs above).  The C code gets
%                  inserted into a C statement block '{ }' before it
%                  is compiled, so you may declare local variables at
%                  the beginning of this block.  Note: This is like
%                  entryfuncs above, differing in usage only.  With
%                  entryfuncs you specify just function names that
%                  need to be defined elsewhere (in the 'globals'
%                  section actually), whereas with this code you give
%                  actual C code that gets executed for particular
%                  states.
%
%                'exitcode' (OPTIONAL)
%               
%                  Like 'entrycode' above but using the semantics
%                  of 'exitfuncs' above.
%
%
%                'fsm_swap_on_state_0' (OPTIONAL)
%
%                  Boolean value indicating whether to swap-in the
%                  new FSM program immediately (false), or when a
%                  transition/jump to state 0 occurs in the
%                  currently-running state program (true).
%
%                  C API Available to your embedded C code
%                  --------------------------------------- 
% /* Runtime Environment The
%    following functions and variables are available to a running FSM.
%    This means any embedded C code has access to the below variables and
%    functions:
%
%    (This is in addition to any globals you declared yourself).
%
% */
%    // just some typedefs
%    typedef unsigned long ulong;
%    typedef unsigned int uint;
%    typedef unsigned short ushort;
%    extern double time(); // the current time, in seconds
%    extern unsigned state(); // the current state we are in
%    extern unsigned transitions(); // a count of the number of state transitions thus far for this FSM
%    extern unsigned long long cycle(); // the count of the number of cycles since the last time the FSM was reset.  The duration of a cycle is 1.0/rate seconds (see rate variable below).
%    extern unsigned rate(); // the sampling rate, in Hz, that the FSM is running at.
%    extern unsigned fsm(); // the id number of the fsm.  usually 0 but if 1 machine is running multiple FSMs, maybe larger than 0
%
%    // a struct that encapsulates the last state transition.  Note that
%    // transition.to normally is the same value as 'state'
%
%    struct EmbCTransition {
%       double time; // the time in seconds that this transition occurred
%       uint from; // the state we came from
%       uint to; // the state we went to
%       uint event; // the event id that led to this transition,  this is log2 of the event ID as it would appear to the matlab side (so it's the actual ID, not the bit-id)
%    };
%    extern struct EmbCTransition transition(); // returns the last state transition that occurred
%
%  /** Forces the state machine to immediately jump to a state -- bypassing normal
%      event detection mechanism. Note that in the new state, pending events are 
%      not cleared, so that they may be applied to the new state if and only if 
%      they haven't yet been applied to the *old* state.  (If you don't like this 
%      behavior let Calin know and he can change it or hack the code yourself.)
%  
%      This call is advanced and not recommended as it breaks the simplicity and 
%      clarity of the finite state machine paradigm, but it might be useful as a 
%      hack to make some protocols easier to write.
%      Returns 1 on success or 0 on error. */
%   extern int forceJumpToState(unsigned state, int event_id_for_history);
%  
%   /*------------------------
%    C Library Functions
%    ------------------------*/
% extern void *memset(void *, int c, unsigned long);
% extern void *memcpy(void *, const void *, unsigned long);
% extern unsigned long strlen(const char *s);
% extern int strcmp(const char *, const char *);
% extern int strncmp(const char *, const char *, unsigned long);
% extern int strcasecmp(const char *, const char *);
% extern int strncasecmp(const char *, const char *, unsigned long);
% extern char *strchr(const char *, int);
% extern char *strnchr(const char *, unsigned long, int);
% extern char *strstr(const char *, const char *);
% extern char *strcat(char *, const char *);
% extern char *strncat(char *, const char *, unsigned long);
%
%   /*------------------------
%    LOW LEVEL I/O FUNCTONS 
%    ------------------------*/
%  
%  /** Read an AI channel -- note that if the AI channel was not enabled,
%      that is, it was not part of the InputEvents spec for any running state machine, the read will 
%      have to actually go to the DAQ hardware and could potentially be slowish because it requires
%      an immediate hardware conversion. However the good news is subsequent reads on the same channel 
%      are always cached for that task cycle. Channel id's are 0-indexed (correspond to the 
%      hardware's real channel-id-space). */
%  extern double readAI(unsigned chan);
%
%  /** Write to a physical analog output channel.  Note that no caching is ever done and a call to this
%      function physically results in a new conversion and voltage being written to the hardware DAC. 
%      Returns true on success, false on failure. */
%  extern int  writeAO(unsigned chan, double voltage);
%
%  /** Read from a physical digital I/O line.  Channel id's are 0-indexed and 
%      refer to the absolute channel number on the hardware.  The read is not done
%      immediately, but is just the cached value that the state machine read at
%      the beginning of the task cycle.
%      Note that the line should already have been configured for digital input
%      (normally done by telling the state machine to use input events of 
%      type 'dio').
%      Returns 0/1 for the bitvalue or negative on failure.
%      Failure reasons include an invalid channel id or trying to read from a 
%      channel that is currently configured for digital output. */
%  extern int readDIO(unsigned chan);
%
%  /** Write to a physical digital I/O line (this overrides normal state 
%      machine output). Channel id's are 0-indexed and refer to the absolute 
%      channel number on the hardware.  The writes themselves don't take effect
%      immediately, but rather at the end of the current task cycle (this is an
%      optimization to make all DIO lines take effect at once).  Note that the 
%      DIO channel 'chan' should have already been configured for digital output.
%      This happens automatically if you are using input routing of type 'ai' 
%      (thus freeing up all DIO channels to be digital outputs).
%      [Note that output routing is not checked, so that chan is the global
%      hardware channel ID and not relative to the first channel in the output 
%      routing spec. (As compared to how BypassDOut works).]
%      Returns true on success or 0 on failure. 
%      Failure reasons may include: an invalid channel ID, or trying to write
%      to a channel that is currently configured for digital input. */
%  extern int writeDIO(unsigned chan, unsigned bitval);
%
%  /** Similar to the matlab client-side BypassDOout call -- simultaneously forces
%      all of the channels in bitmask to be on until the next call to bypassDOut(0). Note 
%      that the channels in this specification are actually relative to the output routing spec
%      for this state machine! 
%      Returns 1 on success or 0 on failure. */
%  extern int bypassDOut(unsigned bitmask);
%
%  /** Similar to the 'tcp' output routing type.  Basically, sometime in the 
%      future,a userspace non-realtime thread will initiate a connection to 
%      host:port and send data of length datalen, then it will close the connection. */
%  extern void sendTCPPacket(const char *host, unsigned short port, const void *data, unsigned datalen);
%
%  /** Similar to above -- a shortcut for sending string data: expects a NUL-terminated string */
%  extern void sendTCPPacketStr(const char *host, unsigned short port, const char *str);
%
%  /** Similar to the 'udp' output routing type.  Basically, sometime in the future,
%      a userspace non-realtime thread will send dataString as a datagram to 
%      host:port. */
%  extern void sendUDPPacket(const char *host, unsigned short port, const void *data, unsigned datalen);
%
%  /** Similar to above -- a shortcut for sending string data: expects a NUL-terminated string */
%  extern void sendUDPPacketStr(const char *host, unsigned short port, const char *str);
%
%  /** Call the external triggerable addon passing it data 'which' and trigger 'trig'.  
%      This is typically how you trigger sound! */
%  extern void triggerExt(unsigned which, int trig);
%
%  /** Synonym for triggerExt() but named triggerSound() for convenience */
%  extern void triggerSound(unsigned card, unsigned snd);
%
%  extern untriggerSound(unsigned card, unsigned snd);
%
%  /** Trigger a scheduled wave to play.  */
%  extern void triggerSchedWave(unsigned wave_id);
%
%  /** Un-trigger a scheduled wave.  */
%  extern void untriggerSchedWave(unsigned wave_id);
%  
%
%   /*------------------------
%    LOGGING FUNCTONS 
%    ------------------------*/
%  
%   /* LOGGING -- the below function can be called from your code in order to
%      log values of variables in real-time.  Each call to a log*() function 
%      creates a record with fields: timestamp, varname, value. 
%      See other documentation about retriving the variables log from the FSM. */
%
%   // logs a single value
%   extern void logValue(const char *varname, double val);
%
%   // logs an entire array of num_elems size.  Each element of the array creates a separate timestamp, name, value record in the log.
%   extern void logArray(const char *varname, const double *array, uint num_elems);
%
%   /// get the number of items currently in the log, or 0 if empty
%   extern unsigned logGetSize(void);
% 
%   #define EMBC_LOG_NAME_SZ 33
%   struct EmbCLogItem
%   {
%       double ts; /**< timestamp in seconds */
%       char name[EMBC_LOG_NAME_SZ];
%       double value;
%   };
% 
%   typedef struct EmbCLogItem EmbCLogItem;
%
%   /// retrieve a specific item from the variable log.  May return a bogus item if 'pos' is >= logGetSize().
%   extern const EmbCLogItem *logGetAt(unsigned pos);
%
%   /// get the most recently logged item
%   extern const EmbCLogItem *logTop(void);
% 
%   /// searches for an item named 'name', but only searches the last 'lastNToSearch' log items.  Returns a dummy  with an empty name and 0 value if not found!!
%   extern const EmbCLogItem *logFindLastN(const char *name, unsigned lastNToSearch);
%
%   /// searches the entire log for a specific item named 'name'.  Returns a dummy if not found!!
%   extern const EmbCLogItem *logFind(const char *name);
%
%   // prints a message (most likely to the kernel log buffer)
%   extern int printf(const char *format, ...);
%
%   // print formatted to a string buffer
%   extern int snprintf(char *buf, unsigned long bufsz, const char *format, ...);
%
%
%   /*------------------------
%    MATH FUNCTIONS
%    ------------------------*/
%
%   // returns a uniformly distributed random number in the range [0, 1.0]
%   extern double rand(void);
%   // returns a normally distributed random number with mean 0 and variance 1.0  
%   extern double randNormalized(void);
%
%   // just like math library -- do man (unix man page) on these to see
%   // what they do
%   extern double sqrt(double);
%   extern double exp(double);
%   extern double log(double);
%   extern double log2(double);
%   extern double log10(double);
%   extern double sin(double);
%   extern double cos(double);
%   extern double tan(double);
%   extern double atan(double);
%   extern double round(double);
%   extern double ceil(double);
%   extern double floor(double);
%   extern double fabs(double d);
%   extern double acosh(double d);
%   extern double asin(double d); 
%   extern double asinh(double d);
%   extern double atanh(double d);
%   extern double cosh(double d); 
%   extern double expn(int i, double d); 
%   extern double fac(int i); 
%   extern double gamma(double d);
%   extern int isnan(double d); 
%   extern double powi(double d, int i); 
%   extern double sinh (double d);
%   extern double tanh(double d);
%
%                Note:
%                   (1) the part of the state matrix that is being
%                   run during intertrial intervals should remain
%                   constant in between any two calls of
%                   Initialize()
%                   (2) that SetStateProgram() should only be called
%                   in between trials.
%                   (3) all variables get cleared when a new trial
%                   begins -- cross-trial persistence is altogether missing.
function [sm] = SetStateProgram(varargin)
  if (nargin < 3 | ~mod(nargin, 2)),  error ('invalid number of arguments'); end;
  sm = varargin{1};

  matrix = {};
  globals = '';
  initfunc = '';
  cleanupfunc = '';
  transitionfunc = '';
  tickfunc = '';
  threshfunc = '';
  entryfuncs = {};
  exitfuncs = {};
  entrycode = {};
  exitcode  = {};
  fsm_swap_on_state_0 = 0;

  for i=2:2:nargin,
    nam = varargin{i};
    val = varargin{i+1};
    if (~ischar(nam)),
      error (['Arguments to this function are of the form ''property1'',' ...
              ' value1, ''property2'', value2 ...']);
    end;
    switch nam,
     case 'matrix',
      if (isnumeric(val)), val = num2cell(val); end;
      if (~iscell(val)), error('Matrix needs to be an MxN cell array'); end;
      matrix = val;
     case 'globals',
      if (~ischar(val)), 
        error(['Argument to ' nam ' needs to be a string.']); 
      end;
      globals = val;
     case 'initfunc',
      if (~ischar(val)), 
        error(['Argument to ' nam ' needs to be a string.']); 
      end;
      initfunc = val;
     case 'cleanupfunc',
      if (~ischar(val)), 
        error(['Argument to ' nam ' needs to be a string.']); 
      end;
      cleanupfunc = val;
     case 'transitionfunc',
      if (~ischar(val)), 
        error(['Argument to ' nam ' needs to be a string.']); 
      end;
      transitionfunc = val;
     case 'tickfunc',
      if (~ischar(val)), 
        error(['Argument to ' nam ' needs to be a string.']); 
      end;
      tickfunc = val;
     case 'threshfunc',
      if (~ischar(val)), 
        error(['Argument to ' nam ' needs to be a string.']); 
      end;
      threshfunc = val;
     case 'entryfuncs',
      if (~iscell(val) | size(val, 2) ~= 2),
        error(['Argument to ' nam ' needs to be an Mx2 array where' ...
               ' column 1 is numeric and column 2 is strings.']); 
      end;
      entryfuncs = val;      
     case 'exitfuncs',
      if (~iscell(val) | size(val, 2) ~= 2),
        error(['Argument to ' nam ' needs to be an Mx2 array where' ...
               ' column 1 is numeric and column 2 is strings.']); 
      end;
      exitfuncs = val;      
     case 'entrycode',
      if (~iscell(val) | size(val, 2) ~= 2),
        error(['Argument to ' nam ' needs to be an Mx2 array where' ...
               ' column 1 is numeric and column 2 is strings.']); 
      end;
      entrycode = val;      
     case 'exitcode',
      if (~iscell(val) | size(val, 2) ~= 2),
        error(['Argument to ' nam ' needs to be an Mx2 array where' ...
               ' column 1 is numeric and column 2 is strings.']); 
      end;
      exitcode = val;      
     case 'fsm_swap_on_state_0',
      if (~isnumeric(val) | length(val) ~= 1), 
        error(['Argument to ' nam ' needs to be a single number.']); 
      end;
      fsm_swap_on_state_0 = val == 1;
     otherwise
      error([ 'Unknown argument ' nam ]);
    end;
  end;
  
  if (isempty(matrix)), 
    error(['State matrix must be non-empty cell array of strings' ...
           ' or numeric array!' ]);
  end;
  
  ChkConn(sm);
  [m,n] = size(matrix);
  [m_i, n_i] = size(sm.input_event_mapping);  
  orouting = sm.output_routing;
  endcols = 2 + size(orouting,1); % 2 fixed columns for timer at the
                                  % end, plus output cols
  if (~isempty(sm.sched_waves) || ~isempty(sm.sched_waves_ao)), 
    % verify that there is at least 1 sched_waves output column
    found = 0;
    for i=1:size(orouting,1),
      if (strcmp(orouting{i}.type, 'sched_wave')),
        found = 1; 
        break;
      end;
    end;
    if (~found),
      warning(sprintf(['The state machine has a sched_waves specification but\n' ...
                     ' no sched_wave output routing defined!\n' ...
                     'Please specify a sched_wave output column using SetOutputRouting!\n' ...
                     'Will try to auto-add an output routing specifying the last column\n' ...
                     'as the sched_wave trigger column, but please fix your code!\n\n' ...
                     '  See SetOutputRouting.m help for more details.']));
      orouting = [ orouting; struct('type', ...
                                    'sched_wave', ...
                                    'data', ...
                                    'THIS STRUCT FIELD IGNORED') ];
      endcols = endcols + 1;
    end;
  end;
  
  if (n ~= endcols + n_i), 
    % verify matrix is sane with respect to number of columns
    error(['Specified matrix has %d columns but\n' ...
           '%d(input) + 2(timeout) + %d(outputs) = %d total\n' ...
           'columns are required due to FSM specification\n' ...
           'such as the number of input events, the output\n' ...
           'routing specified, etc.  Please pass a sane matrix\n'...
           'that meets your input and output routing specification!'], ...
           n, n_i, endcols-2, endcols+n_i); 
  end;
  if (n_i > n), 
    error(['INTERNAL ERROR: How can the number of input events exceed' ...
           ' the space allocated them in the matrix??']); 
  end;
  

  % input_spec_str format is 'ID1, ID2...'
  input_spec_str = '';
  for i = 1:n_i,
    comma = '';
    if (i > 1), comma = ',';  end;
    input_spec_str = [ input_spec_str comma ...
                       sprintf('%d', sm.input_event_mapping(1,i)) ...
                     ];
  end;
  
  hassound = 0;
  % format and urlencode the output_spec_str..  it is of format:
  % \1.type\2.data\1.type\2.data... where everything is
  % urlencoded (so \1 becomes %01, \2 becomes %02, etc)
  output_spec_str = '';
  for i = 1:size(orouting,1),
    s = orouting{i};
    switch (s.type)
     case { 'tcp', 'udp' }
        % force trailing newline for tcp/udp text packets..
        if (s.data(length(s.data)) ~= sprintf('\n')),
          s.data = [ s.data sprintf('\n') ];
        end;
     case { 'ext', 'sound' }
        hassound = 1;            
    end;
    output_spec_str = [ ...
        output_spec_str sprintf('\1') s.type sprintf('\2') s.data ...
                      ];      
  end;
      
 
  input_spec_str = FormatBlock(sm, UrlEncode(sm, input_spec_str));
  output_spec_str = FormatBlock(sm, UrlEncode(sm, output_spec_str));    
  globals_str = FormatBlock(sm, UrlEncode(sm, globals) );
  initfunc_str = FormatBlock(sm, UrlEncode(sm, initfunc));
  cleanupfunc_str = FormatBlock(sm, UrlEncode(sm, cleanupfunc));
  transitionfunc_str = FormatBlock(sm, UrlEncode(sm, transitionfunc));
  tickfunc_str = FormatBlock(sm, UrlEncode(sm, tickfunc));
  threshfunc_str = FormatBlock(sm, UrlEncode(sm, threshfunc));
  entryfuncs_str = FormatNumStringAssociativeArray(sm, entryfuncs);
  exitfuncs_str = FormatNumStringAssociativeArray(sm, exitfuncs);
  entrycodes_str = FormatNumStringAssociativeArray(sm, entrycode);
  exitcodes_str = FormatNumStringAssociativeArray(sm, exitcode);
  [ sched_wave_spec_str, sw_needssound ] = FormatSchedWaves(sm);
  in_chan_type_str = FormatBlock(sm, UrlEncode(sm, sm.in_chan_type));
  matrix_str = FormatMatrix(sm, matrix);

  if (sw_needssound & ~hassound),
      warning(sprintf(['The scheduled waves for this FSM specify a sound to trigger,\n'...
                       'however, this FSM doesn''t actually have any associated sound\n'...
                       'card because the output routing doesn''t contain a spec of type\n'...
                       '''sound'' or type ''ext''!  To fix this, please specify a sound\n'...
                       'output routing for this FSM.']));
  end;

% format for SET STATE PROGRAM command is 
%          SET STATE PROGRAM
%          BEGIN META
%          GLOBALS
%            URLEncoded Block of Globals Section code
%          INITFUNC
%            urlencoded name of init func
%          CLEANUPFUNC
%            urlencoded name of cleanup func
%          TRANSITIONFUNC
%            urlencoded name of transition func
%          TICKFUNC
%            urlencoded name of tick func
%          THRESHFUNC
%            urlencoded name of threshold detector func
%          ENTRYFUNCS
%            state_number -> urlencoded func name
%            etc ...
%          EXITFUNCS
%            state_number -> urlencoded func name
%            etc ...
%          ENTRYCODES
%            state_number -> urlencoded code block
%            etc ...
%          EXITCODES
%            state_number -> urlencoded code block
%            etc ...
%          IN CHAN TYPE 
%            ai|dio
%          INPUT SPEC STRING
%            input spec string (id1, id2, id3, etc..)
%          OUTPUT SPEC STRING
%            URLEncoded output spec string
%          SCHED WAVES
%            URLEncoded sched wave spec
%          READY FOR TRIAL JUMPSTATE
%            number
% //         SWAP FSM ON STATE 0 ONLY
% //           boolean_number
%          END META
%          num_rows num_cols
%            UrlEncoeded matrix cells, one per line

  cmd = sprintf( [ 'SET STATE PROGRAM\n' ...
      'BEGIN META\n' ...
      'GLOBALS\n' ...
      '%s'... % str already has nl
      'INITFUNC\n' ...
      '%s'... % str already has nl
      'CLEANUPFUNC\n' ...
      '%s'... % str already has nl
      'TRANSITIONFUNC\n' ...
      '%s'... % str already has nl
      'TICKFUNC\n' ...
      '%s'... % str already has nl
      'THRESHFUNC\n' ...
      '%s'... % str already has nl
      'ENTRYFUNCS\n' ...
      '%s'... % str already has nl      
...%            state_number -> urlencoded func name
...%            etc ...
      'EXITFUNCS\n' ...
      '%s'... % str already has nl      
...%            state_number -> urlencoded func name
...%            etc ...
      'ENTRYCODES\n' ...
      '%s'... % str already has nl      
...%            state_number -> urlencoded code block
...%            etc ...
      'EXITCODES\n' ...
      '%s'... % str already has nl      
...%            state_number -> urlencoded code block
...%            etc ...
      'IN CHAN TYPE\n' ...
      '%s'... % str already has nl
...%            ai|dio
      'INPUT SPEC STRING\n' ...
      '%s'... % str already has nl      
...%            input spec string (id1, id2, id3, etc..)
      'OUTPUT SPEC STRING\n' ...
      '%s'... % str already has nl
...%            URLEncoded output spec string
      'SCHED WAVES\n' ...
      '%s'... % str already has nl      
...%            URLEncoded sched wave spec
      'READY FOR TRIAL JUMPSTATE\n' ...
      '  %d\n' ...
...%            number
      'SWAP FSM ON STATE 0 ONLY\n' ...
      '  %d\n' ...
      'END META\n' ...
      '%d %d\n' ... % num_rows num_cols
...%            UrlEncoeded matrix cells, one per line
      '%s' ], ... % str already has nl
      globals_str, initfunc_str, cleanupfunc_str, transitionfunc_str, ...
      tickfunc_str, threshfunc_str, entryfuncs_str, exitfuncs_str, entrycodes_str, ...
      exitcodes_str, in_chan_type_str, input_spec_str, output_spec_str, ...
      sched_wave_spec_str, sm.ready_for_trial_jumpstate, ...
      fsm_swap_on_state_0, m, n, matrix_str);
  [res] = FSMClient('sendstring', sm.handle, cmd);
  ReceiveOK(sm, 'SET STATE PROGRAM');
  
  res = SendAllAOWaves(sm, fsm_swap_on_state_0);
  
  return;

function [ret] = FormatBlock(sm, str)

  ret = '';
  for i = 1:80:length(str), 
    endpos = i+79;
    if (endpos > length(str)), endpos = length(str); end;
    ret = [ ret '  ' str(i:endpos) sprintf('\n') ];
  end;
  return;
  
function [ret] = FormatNumStringAssociativeArray(sm, arr)
  ret = '';
  for i=1:size(arr,1),
    str = cell2mat(arr(i,2));
    ret = sprintf('%s  %d -> %s,\n', ret, cell2mat(arr(i, 1)), UrlEncode(sm, str));
  end;
  return;
  
function [ret, sw_needsound] = FormatSchedWaves(sm)
  [m, n] = size(sm.sched_waves);
  ret = '';
  sw_needsound = 0;
  for i = 1:m,
    ret = sprintf('%s\1', ret);
    for j = 1:n,
      if (j == 5 & sm.sched_waves(i,j) > 0), % the 5th column is sound trig, if it's nonzero this schedswave spec uses sound!  Caller is interested in this information in order to issue a proper warning
          sw_needsound = 1;
      end;            
      ret = sprintf('%s\2%d', ret, sm.sched_waves(i,j));
    end;
  end;
  ret = FormatBlock(sm, UrlEncode(sm, ret));
  return;
  
function [ret] = FormatMatrix(sm, matrix)
  ret = '';
  [m, n] = size(matrix);
  
  for i=1:m,
    for j=1:n,
      val = matrix{i,j};
      if (~ischar(val)), val = sprintf('%d', val); end;
      ret = sprintf('%s  %s\n', ret, UrlEncode(sm, val));
    end;
  end;
  
  return;
