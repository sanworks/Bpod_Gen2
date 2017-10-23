% [state_matrix, assembled_state_names, state_machine] = send(sma, state_machine)

% Written by Carlos Brody October 2006; modified by Sebastien Awwad 2008
% Additional Input lines added December 2012 CDB

function [stm, assembled_state_names, sm] = send(sma, sm, varargin)

   global private_hack_ignore_next_ready_to_start_trial;

   pairs = { ...
     'do_all_but_send'    0  ; ...
     'run_trial_asap'     1  ; ...
     'input_lines'      struct('C', 1, 'L', 2, 'R', 3)  ; ...
     'dout_lines'       '0-15'   ; ...
     'sound_card_slot'  '0'; ...
   }; parseargs(varargin, pairs);
   
   if ~isempty(setdiff({'C', 'L', 'R'}, fieldnames(input_lines))),
       error(['Sorry, send.m only support input_lines structures with exactly three fields,\n' ...
           '''C'', ''L'', and ''R''. Bug Carlos to extend it to what you need or do it yourself.\n']);
   end;

   % <~> Call SMA.assemble to convert the added states into a state matrix.
   %     The state names and corresponding state numbers are preserved in a
   %       return value (assembled_state_names) that we store.
   %     This state matrix stm will be sent to the state machine at the end
   %       of this method.
   [stm, assembled_state_names, happList] = assemble(sma);
   sma.happList = happList;
   
   
   % <~> Now we perform some configuration on the state machine so that the
   %       new matrix produced above is correctly interpreted - we set the
   %       input and output routing.

   %<~>TODO: The input and output routing code below should be extracted
   %           into its own method and added to Dispatcher or elsewhere.
   %           Then, the sending process itself needs to be taken out of
   %           SMA and placed in the same place. The assemble method in the
   %           SMA should be the last SMA call made in trial preparation.
   %           From what it returns, Dispatcher (or our small, more general
   %           module) should do the sending itself and the io map
   %           submission to the RLSM.
   
   % --- Make right number of inputs ---
   
   input_map = sma.input_map;
   u = find(~strcmp('Tup', input_map(:,1)));
   input_map = input_map(u,:); %#ok<FNDSB>
   
   if sma.n_input_lines==3 && ~sma.use_happenings
	   inputcols    = cell2mat(input_map(:,2)');
	   inputrouting = zeros(size(inputcols));
	   for i=1:length(inputcols),
		   switch input_map{i,1},
			   case 'Cin',  inputrouting(i) = +input_lines.C;
			   case 'Cout', inputrouting(i) = -input_lines.C;
			   case 'Lin',  inputrouting(i) = +input_lines.L;
			   case 'Lout', inputrouting(i) = -input_lines.L;
			   case 'Rin',  inputrouting(i) = +input_lines.R;
			   case 'Rout', inputrouting(i) = -input_lines.R;
			   otherwise,   inputrouting(i) = 0;
		   end;
	   end;
	   sm = SetInputEvents(sm, inputrouting, 'ai');
   else
	   inputcols    = cell2mat(input_map(:,2)');
	   inputrouting = zeros(size(inputcols));
       for i=1:length(inputcols),
           channel_letter = input_map{i,1}(1);
           switch input_map{i,1}(2:end),
               case 'in',  inputrouting(i) =  input_lines.(channel_letter);
               case 'out', inputrouting(i) = -input_lines.(channel_letter);
               otherwise,  inputrouting(i) = 0;
           end;
       end;
	   sm = SetInputEvents(sm, inputrouting, 'ai');
           
%	   sm = SetInputEvents(sm, 2*sma.n_input_lines, 'ai');
   end;
   
   
   % --- Now outputs ---
   outputs = {};
   for i=1:rows(sma.output_map),
      switch sma.output_map{i,1},
       case 'DOut', 
         outputs = [outputs ; ...
                    {struct('type', 'dout', 'data', dout_lines)}];
         
       case 'SoundOut',
         outputs = [outputs ; ...
                    {struct('type', 'sound', 'data', sound_card_slot)}];
         
       case 'SchedWaveTrig',
         outputs = [outputs ; ...
                    {struct('type', 'sched_wave', 'data', [])}];
      end;
   end;
   
   sm = SetOutputRouting(sm, outputs);
   
   
   % --- Now sched waves ---
   %     If "dio_line" associated with a scheduled wave is not -1, this
   %       signifies that when the scheduled wave is triggered, the listed
   %       dio line should be turned on. For example, this allows a
   %       scheduled wave triggering to directly release water, turn on a
   %       light, etc.
   %     However, we need to adjust the dio_line listed by the dout_lines
   %       offset, just as we did above for the other dout_lines entries.
   %     We simply grab the lower end of the range specified in the
   %       dout_lines string (e.g. '6-11' --> 6).
   dio_lines_offset = str2double(strtok(dout_lines, '-'));

   sma.sched_waves = resolve_sched_wave_names(sma.sched_waves);
   
   swm = zeros(0, 11); % 
   for i=1:length(sma.sched_waves),
	  if isempty(sma.sched_waves(i).analog_waveform),  % This is a digital sched wave, add it to digital list
		  if sma.sched_waves(i).dio_line == -1, this_dio_line = -1;
		  else                                  this_dio_line = sma.sched_waves(i).dio_line + dio_lines_offset;
		  end;
		  swm = [swm ; ...                                              %     (previous rows/waves)
			  sma.sched_waves(i).id ...                                 %     col1:  ID
			  sma.sched_waves(i).in_column-1 ...                        %     col2:  IN_EVENT_COL
			  sma.sched_waves(i).out_column-1 ...                       %     col3:  OUT_EVENT_COL
			  this_dio_line ...                                         %     col4:  DIO_LINE
			  sma.sched_waves(i).sound_trig ...                         %     col5:  SOUND_TRIG (NEW!) IN TESTING
			  sma.sched_waves(i).preamble ...                           %     col6:  PREAMBLE
			  sma.sched_waves(i).sustain ...                            %     col7:  SUSTAIN
			  sma.sched_waves(i).refraction ...                         %     col8:  REFRACTION
			  sma.sched_waves(i).loop ...                               %     col9:  LOOP
			  sma.sched_waves(i).trigger_on_up ...                      %     col10: WAVES TO TRIGGER   ON UP
			  sma.sched_waves(i).untrigger_on_down ...                  %     col11: WAVES TO UNTRIGGER ON DOWN
			  ]; %#ok<*AGROW>
	  end;
   end;
   % <~> Measure for backward compatibility:
   %     The old RTLSM system expects a 7-column scheduled waves matrix,
   %       with no sound_trig (new 5th col). We remove that column (5) if
   %       we're not running under the new RT system (i.e. if either
   %       RIGS;fake_rp_box is not (defined or) 20). We prefer for
   %       the SMA to be blind to this sort of thing, but there is backward
   %       compatibility to worry about. ):
   %     If we're NOT RTLSM2 (fake_rp_box is not 20, i.e. is 2 (old RTLSM)
   %       or 3 (emulator compatible with old RTLSM)), then we strip out
   %       the new sound column.
   if ~(bSettings('compare','RIGS','fake_rp_box',20) || bSettings('compare','RIGS','fake_rp_box',30)),
       iSndCol = 5;
       nCols   = size(swm,2);
       swm = swm(:,[1:iSndCol-1 iSndCol+1:nCols]);
   end;
   
   % <~> Send the scheduled waves matrix to the state machine system.
   sm = SetScheduledWaves(sm, swm(:,1:sma.dio_sched_wave_cols));
   % Now loop through all scheduled waves, sending the analog ones
   for i=1:length(sma.sched_waves),
	  if ~isempty(sma.sched_waves(i).analog_waveform),  % this one is an analog one
		  sm = SetScheduledWaves(sm, ...
			  sma.sched_waves(i).id, ...
			  sma.sched_waves(i).ao_line, ...
			  sma.sched_waves(i).loop, ...
			  [1;0]*sma.sched_waves(i).analog_waveform);   % Currently we do not yet support non-zeros in the second line of the analog waveform (the unsupported second line is described) @RTLSM2/SetScheduledWaves.m
	  end;
   end;
   
   if do_all_but_send==1,
       % <~> If the do-not-send-state-matrix flag is set, we return now.
       return; 
   else
       % <~> Otherwise, we send the state matrix to the state machine
       %       system.
       
       if         ~bSettings('compare','RIGS','fake_rp_box',20)  ... %     If we're not running the new RTLSM2 (June 2008. version > 100)
               || ~isUsingEmbC(sma)                             ... %     or we're using RTLSM2 but not using embedded C functionality,
           %     then we use the old SetStateMatrix call.
        if bSettings('compare','RIGS','fake_rp_box',30)
            if sma.use_happenings
                sm = SetHappeningSpec(sm, sma.happSpec);
            end
            if strcmp(varargin{1}, 'run_trial_asap') && varargin{2} == 1
              sendSM2Bpod(sma, 'RunASAP'); 
            else
              sendSM2Bpod(sma);
            end
        else
            if sma.use_happenings,
              sm = SetHappeningSpec(sm, sma.happSpec);
              sm = SetStateMatrix(sm, stm, 'pend_sm_swap_flg', 1, 'use_happenings', sma.happList);
            else
              sm = SetStateMatrix(sm, stm, 'pend_sm_swap_flg', 1, 'use_happenings', 0);
            end;
        end
       else
           % <~> Otherwise, we're on the new RT system and embedded C
           %       functionality is in use, so we must use the new
           %       SetStateProgram call that allows for submission of
           %       embedded C code.
           %     NOTE that this is broken until assemble is modified and
           %       that code is committed. This is because interpretation
           %       of stm must be performed differently by the SMA when
           %       there are strings that need to be interpreted as C code
           %       and sent directly to the RTLSM instead of being
           %       translated in the SMA.
           
           % <~> The new embedded-C feature of the new RT software is now
           %       officially disabled. This is because it its performance is slow
           %       and nobody is currently employing it, and because the
           %       StateMachineAssembler modifications I made to accommodate it
           %       cause problems for dispatcher('disassemble') that do not merit
           %       remedy unless someone is actually using embedded-C.
           error('Error in StateMachineAssembler/send.m: The new embedded-C feature of the new RT software is currently officially disabled. Please read code comments or contact Sebastien for further information.');
           
           %            % <~> The names of the arguments SetStateProgram wants.
           %            nameArgsToSSP = {...
           %                'globals','initfunc','cleanupfunc', 'transitionfunc',...
           %                'tickfunc','thresfunc','entryfuncs','exitfuncs',...
           %                'entrycode','exitcode' ...
           %                };
           %            % <~> Cell array holding the arguments to SetStateProgram.
           %            argsToSSP = {};
           %
           %            for i=nameArgsToSSP, %     for each argument name,
           %                nameArg = i{1};
           %                if ~isempty(sma.(nameArg)),          %     if arg val nonempty,
           %                    argsToSSP{end+1} = nameArg;      %#ok<AGROW> %     add arg name
           %                    argsToSSP{end+1} = sma.(nameArg);%#ok<AGROW> %     add arg value
           %                end;
           %            end;
           %            % <~> Call SSP with the args extracted above, and, of course,
           %            %       the state matrix - in the form of a cell array.
           %            sm = SetStateProgram(sm, 'matrix', stm_to_cell_array(stm), ...
           %                argsToSSP{:});
           
       end;
       % <~> Note that for now I'm going to use the old SetStateMachine
       %       call even on the new RT system if there is no use of the
       %       embedded C functionality. This is to keep usage of new code
       %       to a minimum when it is not required.
       
           
       % <~> Inform the state machine system that it can transition to the
       %       new state program/matrix on the next transition to state 0.
     if run_trial_asap==1,
       sm = ReadyToStartTrial(sm);
       % fprintf(1, 'SENT just did RforT, %s\n', datestr(now));
       private_hack_ignore_next_ready_to_start_trial = 1;
     end;
   end;
   
   
   
end     %     end of method @StateMachineAssembler/send


% -----------------------------------------------
%% resolve_sched_wave_names

function [sched_waves] = resolve_sched_wave_names(sched_waves)

  for i=1:length(sched_waves)
    if ~isempty(sched_waves(i).name),
      eval([sched_waves(i).name ' = ' num2str(2.^(i-1)) ';']);
    end;
  end;

  for i=1:length(sched_waves),
    try
      if isempty(sched_waves(i).trigger_on_up), 
                 sched_waves(i).trigger_on_up = 0;
      else       sched_waves(i).trigger_on_up = eval(sched_waves(i).trigger_on_up);
      end;
    catch me
      error('StateMachineAssembler:Syntax', ...
        'Couldn''t resolve trigger_on_up string "%s" in wave #%d, name "%s"\n    Error was "%s"', ...
        sched_waves(i).trigger_on_up, i, sched_waves(i).name, me.message);
    end;
  
    try
      if isempty(sched_waves(i).untrigger_on_down), 
                 sched_waves(i).untrigger_on_down = 0;
      else       sched_waves(i).untrigger_on_down = eval(sched_waves(i).untrigger_on_down);
      end;
    catch me
      error('StateMachineAssembler:Syntax', ...
        'Couldn''t resolve untrigger_on_down string "%s" in wave #%d, name "%s"\n    Error was "%s"', ...
        sched_waves(i).untrigger_on_down, i, sched_waves(i).name, me.message);
    end;
  end;

  return;
end

