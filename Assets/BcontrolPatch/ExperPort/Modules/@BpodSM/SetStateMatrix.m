% sm = SetStateMatrix(sm, Matrix state_matrix, [bool_for_pend_sm_swap_flg=0], {'use_happenings', 0}) 
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
%
%                The second usage of this function specifies an
%                optional flag.  If the flag is true, then the state
%                machine will not swap state matrices right away, but
%                rather, will wait for the next jump to state 0 in
%                the current FSM before swapping state matrices.
%                This is so that one can cleanly exit one FSM by
%                jumping to state 0 of another, and thus have cleaner
%                inter-trial interval handling. 
%
%                Note:
%                   (1) the part of the state matrix that is being
%                   run during intertrial intervals should remain
%                   constant in between any two calls of
%                   Initialize()
%                   (2) that SetStateMatrix() should only be called
%                   in between trials.
%
%
% PARAMETERS:
% -----------
%
% sm                An @RTLSM object
%
% state_matrix      The state matrix
%
% OPTIONAL PARAMS:
% ----------------
%
% pend_sm_swap_flg  If an odd number of params is passed, the third
%                   param should be either a 1 or a zero and it flags
%                   whether the state machine will swap state matrices
%                   right away (0, the default), or wait til the next
%                   state 0 (the behavior if this flag is 1).
%
% use_happenings    If 0 (the default) or empty, the use_happenings flag
%                   will be set to zero with in the RTL machine, and no
%                   happenings will be sent. If non-empty and not a
%                   scalar 0, then it must be a happenings list, with the
%                   same number of entries as state_matrix has rows:
%
%                   The happenings list must be an n-by-1 cell, n = total
%                   number of states in the current state machine diagram.
%                   Each row thus corresponds to a state. Each element must
%                   in turn be a cell, which must have an even number of
%                   entries. All the odd-numbered entries must be strings,
%                   and must be one of the strings defined as a happening
%                   name in the happening spec for the current state
%                   machine diagram (see SetHappeningSpec.m). For example,
%                   these strings might typically be something like 'Clo',
%                   or 'mywave_hi'. The even-numbered elements must be the
%                   state number to jump to if immediately previous
%                   happening (e.g., 'Clo') occurs when in this state. An
%                   example of a simple state machine follows. This toggles
%                   back and forth between two states depending on whether
%                   the center poke beam is interrupted ("C is high") or
%                   not ("C is low"). But in either of those states, it
%                   exits to a third state if the Left poke beam is
%                   interrupted ("L is high") and stays there until the
%                   Right poke beam is interrupted:  
%
%                   happList = { ...
%                      {'Chi'  1  'Lhi'  2} ; ...  % state 0: jump to 1 if Chi, jump to 2 if Lhi
%                      {'Clo'  0  'Lhi'  2} ; ...  % state 1
%                      {'Rhi'  0} ; ...            % state 2
%                   };
%
%                   **NOTE** if use_happenings is not empty, SetStateMatrix
%                   assumes thet SetHappeningSpec(sm) has been called and
%                   set appropriately.
%


function [sm] = SetStateMatrix(sm, mat, varargin)
  numStates = size(mat,1);
  
  if numel(varargin) == 1 && numel(varargin{1})==1 && isnumeric(varargin{1}),
     pend_sm_swap_flg = varargin{1}; 
     varargin = varargin(2:end);
  else 
     pend_sm_swap_flg = 0;
  end;
  pairs = { ...
     'use_happenings'     0                 ;  ...
     'pend_sm_swap_flg'   pend_sm_swap_flg  ; ...
  }; parseargs(varargin, pairs);

  if isempty(use_happenings) || ...
     (numel(use_happenings)==1 && isnumeric(use_happenings) && use_happenings(1)==0), %#ok<NODEF>
     sm.happList = cell(numStates,1);
     sm.happSpec = struct('name', {}, 'detectorFunctionName', {}, 'inputNumber', {}, 'happId', {});
     use_happenings = 0;
  end;
  
  ChkConn(sm);
  [m,n] = size(mat);
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
  % now concatenate the input_event_mapping vector as the last row of the matrix
  % -- server side will deconcatenate it
  vec = zeros(1, n);
  for i = 1:n
      if (i <= n_i) vec(1,i) = sm.input_event_mapping(1,i);
      else vec(1,i) = 0;
      end;
  end;
  m = m + 1; % increment m since we added this vector
  mat(m,1:n) =  vec; 
  
  % now, for each scheduled wave, simply add the spec as elements to the
  % matrix -- note these elements are not at all row-aligned and you can
  % end up with multiple sched_waves per matrix row, or 1 sched_wave taking
  % up more than 1 matrix row.  The server-side will just pop these out in
  % FIFO order to build its own sched_waves data structure.
  % SetDIOSchedWaveSpecLength.m is used to tell it how many columns per
  % wave to expect.
  [m_s, n_s] = size(sm.sched_waves);
  if ismember(n_s, [8 9 10 11]),
     if min_server(sm, 16, 'SetDIOSchedWaveSpecLength')
              sm = SetDIOSchedWaveSpecLength(sm, n_s);
     elseif n_s > 8,
        error('SetStateMatrix:badSpec', ...
           ['Trying to send a scheduled wave spec with %d columns,\n' ...
           'but the FSM server is too old to handle that. Need server\n' ...
           'version newer than 220090628'], n_s);
     end;
  else
      error('SetStateMatrix:badSpec', ...
      ['Trying to send a scheduled wave spec with %d columns,\n', ...
      'but legal column numbers are 8, 9, 10, or 11 only.'], n_s);
  end;
  new_m = m + ceil(m_s * (n_s / n));
  row = m+1;
  col = 1;
  row_s = 1;
  col_s = 1;
  sw_needssound = 0;
  for i = 1:((new_m - m) * n)
      if (row_s > m_s)
          mat(row, col) = 0; % we already consumed sm.sched_wave, so just pad with zeros until row finishes
      else
          mat(row, col) = sm.sched_waves(row_s, col_s);          
          if (col_s == 5 & sm.sched_waves(row_s, col_s) > 0) % check this sched wave to see if it triggers sounds
              sw_needssound = 1;
          end;
      end;
      col = col + 1;
      col_s = col_s + 1;
      if (mod(col_s, n_s)==1) % wrap sm.sched_wave column pointer
          col_s = 1;
          row_s = row_s + 1; 
      end;
      
      if (mod(col, n)==1) % wrap mat column pointer
          col = 1;
          row = row + 1;
      end;
  end;
  if (size(mat) ~= [new_m, n]), 
    error(['INTERNAL ERROR: new matrix size is incorrect when' ...
           ' concatenating sched_waves to the end of the state' ...
           ' matrix!! DEBUG ME!']); 
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
     case { 'sound', 'ext' }
         hassound = 1;
    end;
    output_spec_str = [ ...
        output_spec_str sprintf('\1') s.type sprintf('\2') s.data ...
                      ];      
  end;
  output_spec_str = UrlEncode(sm, output_spec_str);
  
  if (sw_needssound & ~hassound),
      warning(sprintf(['The scheduled waves for this FSM specify a sound to trigger,\n'...
                       'however, this FSM doesn''t actually have any associated sound\n'...
                       'card because the output routing doesn''t contain a spec of type\n'...
                       '''sound'' or type ''ext''!  To fix this, please specify a sound\n'...
                       'output routing for this FSM.']));
  end;

  if isnumeric(use_happenings) && use_happenings==0, 
     if min_server(sm, 16), DoSimpleCmd(sm, 'DO NOT USE HAPPENINGS'); end;
  else
     if min_server(sm, 16), 
        DoSimpleCmd(sm, 'USE HAPPENINGS'); 
     else
        error('BadVersion', 'Cannot use happenings unless the server version >= 220090628');
     end;
  end;
  
  [m,n] = size(mat);
  % format for SET STATE MATRIX command is 
  % SET STATE MATRIX rows cols num_in_events num_sched_waves in_chan_type ready_for_trial_jumpstate IGNORED IGNORED IGNORED OUTPUT_SPEC_STR_URL_ENCODED
  SMmeta = struct;
  SMmeta.smCols = n; 
  SMmeta.smRows = m; 
  SMmeta.nInputs = n_i;
  SMmeta.inChanType = sm.in_chan_type;
  SMmeta.trialJumpState = sm.ready_for_trial_jumpstate;
  SMmeta.outputSpecString = output_spec_str;
  SMmeta.pendingSMSwapFlag = pend_sm_swap_flg;
  [res] = sm.handle.sendstring('SET STATE MATRIX', SMmeta);
  ReceiveREADY(sm, 'SET STATE MATRIX'); % Must get READY reply
  [res] = sm.handle.sendmatrix(mat); % remap and send to SendStateMatrix
     
  if ~isnumeric(use_happenings) || ~(use_happenings==0), % More recent servers will be expecting happening specs and a happening list
     [sm, ok] = SendHappeningSpec(sm, sm.happSpec);
     if ~ok,
        error('RTLSM2:BadCommmunication', 'happening spec couldn''t be sent');
     end;
      
     if iscell(use_happenings),
        myHappList = use_happenings';
     else
        myHappList = sm.happList;
     end;
     if isempty(myHappList), myHappList = cell(numStates,1); end; % default is no happenings
     [sm, ok] = SendHappeningList(sm, myHappList);
     if ~ok,
        error('RTLSM2:BadCommmunication', 'happening list couldn''t be sent');
     end;
  end;
  
  ReceiveOK(sm, 'SET STATE MATRIX');
  
  
  % now, send the AO waves *that changed* Note that sending an empty matrix
  % is like clearing a specific wave
  %
  [res] = SendAllAOWaves(sm,pend_sm_swap_flg);
  
  return;

 