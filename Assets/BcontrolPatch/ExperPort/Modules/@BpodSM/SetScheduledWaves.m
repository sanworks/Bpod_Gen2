% sm = SetScheduledWaves(sm, sched_matrix)                            % Digital I/O line schedwave
% sm = SetScheduledWaves(sm, sched_wave_id, ao_line, loop_bool, two_by_n_matrix) % Analog I/O line schedwave
%
%                 There are two usages of this function, with somewhat
%                 different implications.  The first usage is for a
%                 DIO-line scheduled wave, the second is for an AO-line
%                 scheduled wave.  See descriptions below.
%
%                 Note: it is now necessary to call
%                 SetOutputRouting() in order to specify a column
%                 of the state matrix that actually TRIGGERS these
%                 scheduled waves.  See SetOutputRouting.m
%                 documentation for more details.
%
%
% DIGITAL I/O LINE SCHEDULED WAVE
% -------------------------------
%
% sm = SetScheduledWaves(sm, sched_matrix)
%
%                Specifies the scheduled waves matrix for a state machine.
%                This is an M by 8,9,10,or 11 matrix of the following format
%                per row (The last three columns are optional and are assumed zeros
%                if not passed in):
%                ID IN_EVENT_COL OUT_EVENT_COL DIO_LINE SOUND_TRIG PREAMBLE SUSTAIN REFRACTION [LOOP=0] [WAVES TO TRIGGER ON ENTERING SUSTAIN=0] [WAVES TO UNTRIGGER ON LEAVING SUSTAIN=0]
%                Note that this function doesn't actually modify the
%                SchedWaves of the FSM immediately.  Instead, a new
%                SetStateMatrix call needs to be issued for the effects of
%                this function to take effect in the external RTLinux FSM.
%
% Detailed Explanation of DIO Line Scheduled Wave
% -----------------------------------------------
%
% The sched matrix is an M-by-8, 9, 10, or 11 matrix of the following format
% (each of the last three columns are optional and are assumed zeros if not 
% passed in; note, however, that if you want to pass in the 10th column,
% you need to pass in the 9th; etc.):
%
% ID IN_EVENT_COL OUT_EVENT_COL DIO_LINE SOUND_TRIG PREAMBLE SUSTAIN REFRACTION [LOOP=0] [WAVES TO TRIGGER ON ENTERING SUSTAIN=0] [WAVES TO UNTRIGGER ON LEAVING SUSTAIN=0]
%
% Note that this function doesn't acrually modify the SchedWaves of the
% FSM.  Instead, a new SetStateMatrix (or SetStateProgram)
% call needs to be issued for the effects of this function to actually take
% effect in the external RTLinux FSM.
%
% As for the matrix this function expected, column has the following
% definition:
% ID -
%      the numeric id of the scheduled wave.  Each wave is numbered from
%      0-31.  (NOTE: 0 is a valid ID!). The ID is later used in the
%      StateMatrix SCHED_WAVE column as a bitposition.  So for example if
%      you want wave number with ID 10 to fire, you use 2^10 in the
%      SCHED_WAVE column of the state matrix and 10 as the ID in this
%      matrix.  You can *untrigger* scheduled waves by issuing a
%      negative number.  To untrigger wave ID 10, you would issue
%      -(2^10) in your state matrix.
% IN_EVENT_COL -
%      The column of the state matrix (0 being the first column) which
%      is to be used as the INPUT event column when this wave goes HIGH
%      (edge up). Think of this as a WAVE-IN event. Set this value to -1 to
%      have the state machine not trigger a state matrix input event for
%      edge-up transitions.
% OUT_EVENT_COL -
%      The column of the state matrix (0 being the first column) which
%      is to be used as the INPUT event column when this wave goes LOW
%      (edge down).  Think of this as a WAVE-OUT event.
%      Set this value to -1 to have the state machine not trigger a state
%      matrix input event for edge-down transitions.
% DIO_LINE -
%      The DIO line on which to echo the output of this waveform.  Note
%      that not all waves need have a real DIO line associated with them.
%      Set this value to -1 to not use a DIO line.
% SOUND_TRIG -
%      The sound id to trigger when 'sustain' occurs, and then to untrigger
%      when 'refraction' occurs.  0 for none.
% PREAMBLE (seconds) -
%      The amount of time to wait (in seconds) from the time the scheduled
%      wave is triggered in the state matrix SCHED_WAVE column to the time
%      it actually goes high.  Fractional numbers are ok.  Note the
%      granularity of this time specification is the time quantum
%      of the state machine (typically 166 microsecs), so values smaller
%      than this quantum are probably going to get rounded to the
%      nearest quantum.
% SUSTAIN (seconds) -
%      The amount of time to wait (in seconds) from the time the
%      scheduled wave is goes high to the time it should go low again.
%      Stated another way, the amount of time a scheduled wave
%      sustains a high state.  Fractional numbers are ok.  Note the
%      granularity of this time specification is the time quantum of
%      the state machine (typically 166 microsecs), so values smaller than
%      this quantum are probably going to get rounded to the nearest
%      quantum
% REFRACTION (seconds) -
%      The amount of time to wait (in seconds) from the time the
%      scheduled wave is goes low to the time it can successfully be
%      triggered again by the SCHED_WAVE column of the state
%      matrix. Fractional numbers are ok.  Note the granularity of
%      this time specification is the time quantum of the state
%      machine (typically 166 microsecs), so values smaller than this quantum
%      are probably going to get rounded to the nearest quantum.
% LOOP (integer) -
%      The number of times to repeat the scheduled wave, i.e., at the end
%      of the refraction, start the preamble again. If this is 0, the
%      scheduled wave plays only once. If this is negative, the scheduled
%      wave loops indefinitely, only ending at the end of a trial, i.e.,
%      upon a jump to state 0.
% WAVES TO TRIGGER ON HIGH  (unsigned integer)
%      This is a bit mask, with each non-zero bit indicating a scheduled
%      wave that should be triggered when this wave goes high, i.e.,
%      reaches the end of its preamble and starts its sustain. The least
%      significant bit identifies wave id 0.
% WAVES TO UNTRIGGER ON LOW  (unsigned integer)
%      This is a bit mask, with each non-zero bit indicating a scheduled
%      wave that should be UNtriggered when this wave goes low, i.e.,
%      reaches the end of its sustain and starts its refraction. The least
%      significant bit identifies wave id 0.
%
%
% ANALOG I/O LINE SCHEDULED WAVE ------------------------------
%
% sm = SetScheduledWaves(sm, sched_wave_id, ao_line, loop_bool, two_by_n_matrix)
%                Specifies a scheduled wave using analog I/O for a state
%                machine.  The sched_wave_id is in the same id-space as the
%                digital scheduled waves described above. The ao_line is
%                the analog output channel to use, starting at 1 for the
%                first AO line.  loop_bool, if true, means this is a
%                looping wave (it loops until untriggered).The last
%                parameter, a 2-by-n matrix, is described below.
%
% Detailed Explanation of AO Line Scheduled Wave
% ----------------------------------------------
% Like a digital scheduled wave described above, an analog scheduled wave
% is triggered from the SCHED_WAVES column of the state matrix using a
% 2^sched_wave_id bit position.  Triggering it actually causes samples to
% be written to the ao_line output channel on the DAQ card (AO lines are
% indexed from 1). The samples to be written (along with the events in the
% FSM to trigger) are specified in a two-by-n matrix as the fourth
% parameter to this function.   As the output wave is played, events to the
% state machine can be generated to update/notify the state machine of
% progress during playback (see description of the two-by-n matrix below).
%
% Note that this function doesn't actually modify the SchedWaves of the FSM
% immediately. Instead, a new SetStateMatrix call needs to be issued for
% the effects of this function to take effect in the external RTLinux FSM.
%
% Two-by-n-matrix description
% ---------------------------
% The actual samples to be written to the ao_line are specified in a
% two-by-n matrix.
%
% The first row of this matrix is a row-vector of samples over the range
% [-1,1].  They get automatically scaled to the output range setting of the
% DAQ hardware (0-5V for instance, etc).  The rate at which these samples
% get written is usually 6kHz, but it depends on the rate at which the FSM
% is running, and it cannot be changed from Matlab (it is a parameter to
% the realtime kernel module implementing the actual FSM).
%
% The second row of the matrix may be all zeroes.  If any position in the
% matrix is not zero, then it indicates an input event number in the state
% machine (indexed at 1) to trigger when the corresponding sample (in the
% first row) is played. The purpose of this feature is to allow the state
% machine to be notified when 'interesting' parts of the scheduled analog
% wave are being played, so that the state machine may do something with
% that information such as: change its state, jump to a sub-block of
% states, etc.
%
% Example:
%
% SetScheduledWaves(sm, 0, 1, 0, [ -1 -.999 -.988 0.25 0.26; ...
%                                   0     0     0   1    0   ]);
%
% Would specify a scheduled wave with id 0, on analog line 1 (the first
% line), non-looping.  When wave id 0 is triggered, the state machine is to
% play the five samples in row 1 of the above matrix (normally your output
% matrix will contain more than 5 samples -- this is not very useful since
% it's only 5 samples at 6kHz but it is an example after all).  For all but
% the fourth sample, no event in the state machine is triggered. However,
% as soon as the fourth sample is played by the state machine, input event
% column 1 (the first column) of the state matrix is sent an event (which
% might cause a state transition, depending on the state matrix).
%
% BUGS & QUIRKS
% -------------
%
% Untriggering analog or digital scheduled waves requires you to
% issue a *negative* bitpattern.  So to untrigger waves 1,2,3 and 5
% you would need to issue -(2^1+2^2+2^3+2^5) in your state matrix
% scheduled waves output column.
%
% Triggering sounds from DIO scheduled waves requires the @RTLSM2 to have
% a 'sound' or 'ext' output routing spec (see SetOutputRouting).
% If it doesn't, the FSM doesn't know which sound card to trigger to, so
% nothing is triggered.  Also, more than 1 sound output routing spec
% leads to undefined behavior (as in this case the sound card to trigger
% is ambiguous).
%
% The DIO SetScheduledWaves indexes I/O lines at 0 and state event columns
% at 0 while its analog counterpart indexes I/O lines at 1 and the same
% state event columns at 1.  This is inconsitent. Let me know which one
% should win -- ie if you want consistency tell me if you prefer indexing
% at 1 or at 0.
%
% The DIO SetScheduledWaves specifies *all* DIO sched waves at once as one
% call, whereas the AO SetScheduledWaves specifies one AO wave per call
% (thus requiring multiple calls for multiple AO waves).
%
% If these functions are called and an AO wave has the same id as a
% pre-existing DIO wave (or vice-versa), the existing wave is discarded and a
% warning is issued.
%
function [sm] = SetScheduledWaves(varargin)
if (nargin == 2)
    sm = SetScheduledWavesDIO(varargin{1}, varargin{2});
elseif (nargin == 5)
    sm = SetScheduledWavesAO(varargin{1}, varargin{2}, varargin{3}, varargin{4}, varargin{5});
else
    error('Wrong number of arguments -- SetScheduledWaves takes 2 or 5 arguments');
    return;
end;
return;

function [sm] = SetScheduledWavesDIO(sm, sched_matrix)
[m,n] = size(sched_matrix);
if (~ismember(n, [8 9 10 11]) || m < 0), error('Argment 2 to SetScheduledWaves needs to be an (m x (8 or 9 or 10 or 11)) matrix!'); end;
if n > 8,
    if ~min_server(sm, 16, 'SetScheduledWaves')
        error(['Asking for looping or other wave triggering in sched waves!!!' ...
           ' Can''t just throw a warning:\nNeed server version > 220090628 ' ...
           'to do this (use more than 8 columns in a sched wave spec)!']);
    end;
end;
id_ctr = zeros(32);
% check for dupes
saved = sm.sched_waves;
sm.sched_waves = [];
for i = 1:m
    id = sched_matrix(i, 1)+1;
    if (id > 32), error('Scheduled Wave id must be < 32!'); end;
    dupeidx = IdIsDupe(sm, id-1);
    if (dupeidx),
        warning(sprintf('In SetScheduledWaves: there is already an AO wave having id %d -- overwriting it', id-1));
        sm.sched_waves_ao = DelRow(sm.sched_waves_ao, dupeidx);
    end;
    id_ctr(id) = id_ctr(id) + 1;
    if (id_ctr(id) > 1)
        sm.sched_waves = saved;
        error('In SetScheduledWaves: there is more than one wave having id %d', id-1);
        return;
    end;
end;
% no dupes, accept
sm.sched_waves = sched_matrix;
return;

function [sm] = SetScheduledWavesAO(sm, id, ioline, loop, mat)
sm = sm;
if (ioline < 1),
    error('AO Lines are indexed at 1');
    return;
end;
if (id < 0),
    error('Invalid ID.  IDs for scheduled waves must be >= 0');
    return;
end;
if (id >= 32), error('Scheduled Wave id must be < 32!'); end;
if (~isempty(mat) && size(mat,1) ~= 2),
    error('AO matrix needs to be 2 by n');
    return;
elseif (~isempty(mat)),
    [i,j] = find(mat(1:1,:) > 1 | mat(1:1,:) < -1);
    if (j),
        error(sprintf('AO output matrix (first row) needs samples in the range [-1,1], but encountered values:\n%s\nat positions:\n%s', mat2str(mat(1,j)), mat2str(j)));
        return;
    end;
end;

idx = IdIsDupe(sm, id);

if (idx),
    if (size(sm.sched_waves_ao,1) >= idx && sm.sched_waves_ao{idx,1} == id),
        sm.sched_waves_ao = DelRow(sm.sched_waves_ao, idx);
    elseif(size(sm.sched_waves,1) >= idx && sm.sched_waves(idx, 1) == id),
        warning(sprintf('In SetScheduledWaves: there already is a DIO wave having id %d -- overwriting it', id));
        sm.sched_waves = DelRow(sm.sched_waves, idx);
    end;
end;

if (isempty(mat)), return; end;
if (loop), loop = 1; end;
sm.sched_waves_ao = vertcat(sm.sched_waves_ao, {id, ioline, loop, mat});
return;

function idx = IdIsDupe(sm, id)
idx = 0;
if (~isempty(sm.sched_waves)),
    [i] = find(sm.sched_waves(:,1) == id);
    if (~isempty(i)),
        idx = i;
        return;
    end;
end;
for i=1:size(sm.sched_waves_ao, 1),
    if (sm.sched_waves_ao{i,1} == id),
        idx = i;
        return;
    end;
end;
return;

function it = DelRow(it, idx)
sz1 = size(it,1);
sz2 = size(it,2);

if (idx == sz1 && idx == 1),
    if (isa(it, 'cell')),
        it = cell(0,sz2);
    else
        it = [];
    end;
    return;
elseif (idx == sz1 && idx ~= 1),
    it = it(1:sz1-1,1:sz2);
    return;
elseif (idx == 1)
    it = it(2:sz1,1:sz2);
else
    it = vertcat(it(1:idx-1,1:sz2), it(idx+1:sz1,1:sz2));
end;
return;

