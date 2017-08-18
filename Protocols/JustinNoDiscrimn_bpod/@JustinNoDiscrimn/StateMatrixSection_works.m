% Create and send state matrix.

% Santiago Jaramillo - 2007.08.24
%
%%% CVS version control block - do not edit manually
%%%  $Revision: 1064 $
%%%  $Date: 2008-01-10 16:50:50 -0500 (Thu, 10 Jan 2008) $
%%%  $Source$


%%% BUGS:
%
% [2007.10.04] If the duration of sound is changed, the State Matrix is not
% updated but the sound duration is.  This is a problem if Duration is
% changed
% from large value to a small one, since there will still be punishment after
% the sound off-set.  Updating the matrix on update_sounds didn't work.


function sma = StateMatrixSection(obj, action)

%call to SetStateProgram occurs outside of this function when using
%dispatcher. Make the embedC matrix global
global G

%set in dispatcher, reflects Dout mappins from settings file
global unsorted_channels
global channels

%need to convert the channel mappings for each DOut to binary, then to
%decimal

%%%---OUTPUT SPECIFICATION

bitcode=4;           %binary = 1100,         bitcode is chan2
lick_1=16;             %binary = 1001,         lick_1 is chan4
lick_2=32;            %binary = 10001,        lick_2 is chan5
festo_trig=65;        %binary = 100001,       festo_trig is chan6
cue_led1=257;         %binary = 10000001,     cue_led1 is chan8
ephus_trig=1025;      %binary = 1000000001,   ephus_trig is chan10
embc_touch_out=4097;  %binary = 100000000001, DIO line triggered by embc touch sched wave is chan12

GetSoloFunctionArgs;

switch action
    case 'update',
        %%%%NEXT TRIAL SETTINGS

        %JPL - for some reason, next_type is passed as a soloparamhandle,
        %but all the other next_ type vars are passed as strings
        if strcmp(next_stim_type,'s')
            stim_trial=true;
        else
            stim_trial=false;
        end

        %set stimulation parameters
        %we arent really doing stim at the moment, but this is where you
        %want to load these settings

        %%%%AO/AI SPECIFCATIONS (EmbedC)

        % -- Delays Section
        %delays in the state machine are coded as multiples of the duty
        %cycle, which is 6 samples per ms. Here we define any delays we
        %wish to implement on AO or AI lines. For example, if we want to
        %change state 600ms after a touch on an AI line, then this value
        %will be 3600

        %eventually need to build this into the GUI, but its here for now

        %what is the sampling period of this state machine?
        taskPeriodsPerMs=6;
        %%%specify delays in ms here
        %%%note: we can make this a variable that %changes state-to-state
        postTouch_wait_period_ms=500;  %wait time after touch
        %postDelayInterupt_wait_period_ms=500; %wait time after touch-out during delay and trial reinit
        %%%convert
        postTouch_wait_period=floor(postTouch_wait_period_ms*taskPeriodsPerMs);
        %postDelayInterupt_wait_period=floor(postDelayInterupt_wait_period_ms*taskPeriodsPerMs);

        % -- States Section
        %specify states during which AO or AI actions will take place. Last
        %entry must be the state the ends a particular (e.g. sampling,
        %delay) period;
        pre_sample_period_states=[43 44 45]; %43=pole ascends, 44=pole delay, 45=raise pole
        stimulus_delay_period_states=[46]; %46=delay period
        sample_period_states=[47 48]; %47=cue and sample, 48=touch
        
        states_to_log_touch=[pre_sample_period_states stimulus_delay_period_states sample_period_states ];
        
        % JPL - DHO used this for activating stimulation lasers. Maybe we
        % want to do something like this later, but for now, just using it
        % for state transitions.

        if ~isempty(strfind(next_stim_type,'sample_period'))
            stim_state_for_EmbC=[1 sample_period_states];
        elseif ~isempty(strfind(next_stim_type,'delay_period'))
            stim_state_for_EmbC=[1 delay_period_states];
        elseif ~isempty(strfind(next_stim_type,'on_touch'))
            stim_state_for_EmbC=[0 sample_period_states];
        elseif ~isempty(strfind(next_stim_type,'n'))
            %dummy in case the other stuff is happening
            stim_state_for_EmbC=[0 sample_period_states];
        else
            %JPL - not using this now anyway
            %error('Unrecognized stim type selection');
        end

        %'JPL - StateMatrixSection - need to get the protocol name into here to finish the embedC path, but cant figure it out right now...just doing it manually');
        manual='@pole_detect_jpl_0obj';
        embCPath=[bSettings('get','GENERAL','Protocols_Directory') '\' manual '\' 'embc\'] ;

        %load the string of variables to pass to the FSM
        G=wrap_c_file_in_string([pwd embCPath 'globals.c']);


        %JPL TO DO - make these GUI-editable
        touch_thresh_low=-0.01;   %units of standard deviation!
        touch_thresh_high=0.01;  %units of standard deviation!
        baseline_in_ms = 5;     %time period to get std and mean for threhsolding
        signal_in_ms = 1;       %time period to average over for signal measure

        %convert times to cycles
        numCycThresh = floor(baseline_in_ms*taskPeriodsPerMs);
        numCycVal = floor(signal_in_ms*taskPeriodsPerMs);
        
        %build the embedC string
        G=preprocessEmbC_test(G,touch_thresh_low,touch_thresh_high,states_to_log_touch);
        
        %%%%REGULAR STATE MACHINE STUFF

        %SOUNDS
        IndsAll =  SoundManagerSection(obj, 'get_sound_id', 'all');
        IndNoise = SoundManagerSection(obj, 'get_sound_id', 'noise');
        IndSoundReward = SoundManagerSection(obj, 'get_sound_id', 'reward');
        IndSoundGo = SoundManagerSection(obj, 'get_sound_id', 'go');
        IndSoundInit = SoundManagerSection(obj, 'get_sound_id', 'init');

        %get all sound names
        soundNames =  SoundManagerSection(obj, 'get_sound_names','all');

        %get the id for the pole associated with the current position
        cueId=active_locations.cue_id(strmatch(next_pos_id,...
            active_locations.name,'exact'));

        %cueId here will be empty if we arent moving poles...hack it for
        %now. later, put in a real control statement
        if isempty(cueId)
            cueId='none';
        end

        %if we arent moving poles, forget about loading pole cues...this
        %will be controlled later to make sure no sounds are played if we
        %so specificy (or the ones we do) but need a default value at this
        %point
        if strmatch(SessionType,'Water_Valve_Calibration','exact')
            IndCueSound=IndSoundGo;
        else
            %if this isnt a mismatch trial, use the proper cue
            if strmatch(next_predict, 'predict') %predicted
                %just load the sound
                IndCueSound = SoundManagerSection(obj, 'get_sound_id', cueId);

            else %mismatch
                cueId=randsample(numel(active_locations.cue_id),1);
                IndCueSound = SoundManagerSection(obj,'get_sound_id', cueId);
            end
        end
        %this exists as a drop-down menu item in the GUI, but delays here
        rand_pole_delay_pool = [0.25  0.5  0.75 1.0];

        if ~strcmp(value(pole_delay), 'random')
            %do nothing
        else
            RandDelay_ind = ceil(length(rand_pole_delay_pool)*rand);
            pole_delay = rand_pole_delay_pool(RandDelay_ind); % set Pole delay time as a random number between 0.5 and 1.5
        end;
  
        %randomize delay period length
        rand_delay_period_pool=[0.5 0.75 1.0 1.25 1.5];
        
        
        if ~strcmp(value(DelayPeriodTime), 'random')
            %do nothing
        else
            RandDelay_ind = ceil(length(rand_delay_period_pool)*rand);
            DelayPeriodTime = rand_delay_period_pool(RandDelay_ind); % set Pole delay time as a random number between 0.5 and 1.5
        end;
        
        
        %determine reward side output
        if strmatch(value(next_side),'left') %whats the next side?
            lickOut='LIn';  %code for corectglick port set in assembler code
            lickBad='RIn';  %incorrect lick port
        else
            lickOut='RIn';  %code for left lick port set in assembler code
            lickBad='LIn';  %incorrect lick port
        end


        sma = StateMachineAssembler('full_trial_structure');

        %switch for different behavior types
        switch SessionType
            case 'Touch_Test'
                
                %%%------SCHEDULED WAVES SECTION-----------------
                [sma] = add_scheduled_wave(sma,...
                    'name','touch_onsets',...
                    'sustain', 0.1,...
                    'dio_line', 12);

                sma = add_scheduled_wave(sma,'name', 'goWave',...
                    'sustain',GoCueDur,...
                    'sound_trig', IndSoundGo);

                %%%------SMA SECTION-----------------
                %play a sound every time a touch is detected
                sma = add_state(sma, 'name', 'start', ...
                    'input_to_statechange', {'touch_onsets_In', 'play_sound'});

                sma = add_state(sma, 'name', 'play_sound', ...
                    'output_actions', {'SchedWaveTrig','goWave'}, ...
                    'input_to_statechange', {'Tup','final_state'});

                sma = add_state(sma, 'name', 'final_state', ...
                    'self_timer', 0.01,...
                    'input_to_statechange', {'Tup', 'check_next_trial_ready'});
                
            case 'Licking'
                
                %G=[];
                
                %%%------SMA SECTION-----------------

                %send bitcode and start
                sma = add_state(sma, 'name', 'start', ...
                    'input_to_statechange', {lickOut, 'valve';'Tup', 'final_state'});
                
              
                sma = add_state(sma, 'name', 'valve', ...
                    'self_timer', WaterValveTime,...
                    'output_actions',{'DOut',lick_1},...
                    'input_to_statechange', {'Tup', 'final_state'});


                sma = add_state(sma, 'name', 'final_state', ...
                    'self_timer', 0.01,...
                    'input_to_statechange', {'Tup', 'check_next_trial_ready'});

            
            case 'noDiscrim'
                %%%------SCHEDULED WAVES SECTION-----------------

                %%first make a scheldued wave we can use for reporting touch onsets
                %%and offsets detected in the embeddedC code

                %this wave gets triggered and untriggered within globals.c
                %/ the
                %embedC functionality. It is triggered when there is a
                %touch
                %(threshold crossing on touch sensor channel)and produces an output
                %on DIO line 12. This gets shuttled via the breakout box to the
                %'TouchIn' input line (14)

                [sma] = add_scheduled_wave(sma,...
                    'name','touch_onsets',...
                    'sustain', 0.1,...
                    'dio_line', 12);

                %wave with same 'In' event timing as the delay wave, but then
                %causes an 'Out' event after the sample period time + go cue time
                sma = add_scheduled_wave(sma,'name', 'PoleUpWave',...
                    'sustain',DelayPeriodTime+SamplingPeriodTime+GoCueDur,...
                    'dio_line',6);

                %wave that runs for the delay period time, then causes an 'In'
                %event, and plays the go cue, and triggers an end event
                %after the0
                %end of the cue
                sma = add_scheduled_wave(sma,'name', 'delayWave',...
                    'sustain', DelayPeriodTime);

                %wave that triggers the pole cue at the beginning of the trial
                sma = add_scheduled_wave(sma,'name', 'cueWave',...
                    'sustain',PoleCueDur,...
                    'sound_trig', IndCueSound);

                %wave that triggers the pole cue at the beginning of the trial
                sma = add_scheduled_wave(sma,'name', 'goWave',...
                    'sustain',GoCueDur,...
                    'sound_trig', IndSoundGo);
                
                %wave that triggers the white noise/fail cue
                sma = add_scheduled_wave(sma,'name', 'noiseWave',...
                    'sustain',FailCueDur,...
                    'sound_trig', IndNoise);
                
                %wave that triggers the reward click
                sma = add_scheduled_wave(sma,'name', 'rewardWave',...
                    'sustain',RewCueDur,...
                    'sound_trig', IndSoundReward);

                %MAIN STATE MACHINE DEFINITION

                %%-----START------------------------------------------------------
                %send bitcode and start
                sma = add_state(sma, 'name', 'start', ...
                    'self_timer', 0.01,...
                    'output_actions',{'DOut',bitcode},...
                    'input_to_statechange', {'Tup', 'ephus_trig'});

                %send ephus trigger signal outs
                sma = add_state(sma, 'name', 'ephus_trig', ...
                    'self_timer', 0.01,...
                    'output_actions',{'DOut',ephus_trig},...
                    'input_to_statechange', {'Tup', 'play_cue'});

                sma = add_state(sma, 'name', 'play_cue', ...
                    'self_timer',PoleCueDur, ...
                    'output_actions', {'SchedWaveTrig','cueWave'}, ...
                    'input_to_statechange', {'Tup', 'pre_pole_time'});

                %%------POLE UP, DELAY, AND SAMPLING SECTION-----------------------------

                sma = add_state(sma, 'name', 'pre_pole_time', ...
                    'self_timer', pole_delay,...
                    'input_to_statechange', {'Tup','raise_pole'});

                %trigger a voltage-high to raise the festo pole. Wait for
                %the 'In'
                %event from delay sched. wave, and then trigger the go cue from the
                %scheduled wave In event

                sma = add_state(sma, 'name', 'raise_pole', ...
                   'self_timer', 1.5, ... %delay for sensore resonance
                   'output_actions', {'SchedWaveTrig','PoleUpWave'}, ...
                   'input_to_statechange', {'Tup','delay'});
                
                
                %sma = add_state(sma, 'name', 'raise_pole', ...
                %   'output_actions', {'SchedWaveTrig','PoleUpWave+delayWave'}, ...
                %   'input_to_statechange', {'PoleUpWave_In','delay'});


             sma = add_state(sma, 'name', 'delay', ...
                 'self_timer', DelayPeriodTime, ...
                 'input_to_statechange', {'Tup','cue_and_sample';'touch_onsets_In','timeout'});

             
                %triggers to touch state when the duration of the first
                %touch is over. Or on timeout, go to notouch state
                sma = add_state(sma, 'name', 'cue_and_sample', ...
                    'output_actions', {'SchedWaveTrig','goWave'}, ...
                    'input_to_statechange', {'touch_onsets_In','touch';...
                    'PoleUpWave_Out','notouch'});

                %if the touch onset scheduled wave (triggered in embedC)is triggered,
                %then untriggered, the first touch is over. From there, we
                %can
                %continue with the sampling period, or remove the pole,
                %depending on settings
                sma = add_state(sma, 'name', 'touch', ...
                    'input_to_statechange', ...
                    {'PoleUpWave_Out', 'answer_delay'});

                sma = add_state(sma, 'name', 'answer_delay', ...
                    'self_timer',AnswerDelayDur,...
                    'input_to_statechange', ...
                    {'Tup', 'rew_cue';lickOut,'abort'});

                %play reward cue
                sma = add_state(sma, 'name', 'rew_cue', ...
                    'output_actions', {'SchedWaveTrig','rewardWave'}, ...
                    'self_timer', RewCueDur,...
                    'input_to_statechange', {'Tup', 'answer_period'});


                sma = add_state(sma, 'name', 'answer_period', ...
                    'self_timer',AnswerPeriodTime,...
                    'input_to_statechange', ...
                    {'Tup', 'miss';lickOut,'hit'});


                %--------FINAL STATE AND CLEANUP--------------------------

                %assign what happend during this trial to various end states that
                %will help compute peformance, d', etc

                % NO TIMEOUT END STATES
                %if we are advancing trials on touches and licks

                sma = add_state(sma, 'name', 'hit', ...
                    'output_actions',{'DOut',lick_1},...
                    'self_timer', WaterValveTime,...
                    'input_to_statechange', {'Tup', 'final_state'});

%                 sma = add_state(sma, 'name', 'miss', ...
%                     'output_actions', {'SchedWaveTrig','noiseWave'}, ...
%                     'self_timer', 0.1,...
%                     'input_to_statechange', {'Tup', 'final_state'});

                sma = add_state(sma, 'name', 'miss', ...
                    'self_timer', 0.1,...
                    'input_to_statechange', {'Tup', 'final_state'});

%                 sma = add_state(sma, 'name', 'false_alarm', ...
%                     'self_timer', 0.1,...
%                     'output_actions', {'SoundOut', IndNoise},...
%                     'input_to_statechange', {'Tup', 'final_state'});
                
                sma = add_state(sma, 'name', 'false_alarm', ...
                    'self_timer', 0.1,...
                    'input_to_statechange', {'Tup', 'final_state'});

                sma = add_state(sma, 'name', 'correct_reject', ...
                    'output_actions',{'DOut',lick_1},...
                    'self_timer', WaterValveTime,...
                    'input_to_statechange', {'Tup', 'final_state'});

                sma = add_state(sma, 'name', 'abort', ...
                    'self_timer', 0.1,...
                    'input_to_statechange', {'Tup', 'timeout'});

                sma = add_state(sma, 'name', 'timeout', ...
                    'output_actions', {'SchedWaveTrig','noiseWave'}, ...
                    'self_timer', 0.1,...
                    'input_to_statechange', {'Tup', 'final_state'});

                sma = add_state(sma, 'name', 'notouch', ...
                    'self_timer', 0.1,...
                    'input_to_statechange', {'Tup', 'final_state'});

                sma = add_state(sma, 'name', 'final_state', ...
                    'self_timer', 0.1,...
                    'input_to_statechange',...
                    {'Tup', 'check_next_trial_ready'});

            case 'Water_Valve_Calibration'
                % On beam break (eg, by hand), trigger ndrops water deliveries
                % with delay second delays.
                ndrops = 100; delay = 1; valve=lick_1;
                keyboard
                for b=1:1:ndrops;
                    sma = add_state(sma, 'name', ['openvalve_' num2str(b)], ...
                        'self_timer', WaterValveTime,...
                        'output_actions',{'DOut',valve},...
                        'input_to_statechange', {'Tup', ['delayToNextDrop_' num2str(b)]});
                    if b==ndrops
                        sma = add_state(sma, 'name', ['delayToNextDrop_' num2str(b)], ...
                            'self_timer', delay,...
                            'output_actions', {'SoundOut',IndSoundGo},...  %play a cue so we know when its over
                            'input_to_statechange', {'Tup', 'final_state'});

                        sma = add_state(sma, 'name', 'final_state', ...
                            'self_timer', 0.01,...
                            'input_to_statechange', {'Tup', 'check_next_trial_ready'});
                    else
                        sma = add_state(sma, 'name', ['delayToNextDrop_' num2str(b)], ...
                            'self_timer', delay,...
                            'input_to_statechange', {'Tup', ['openvalve_' num2str(b+1)]});
                    end
                end

            case 'Sound_Calibration'
                %Play a series of sounds (defined in SoundSection.m) at
                %diff frequecnies and volumes

                cindex=1;
                windex=1;
                for p=2:1:numel(soundNames)
                    if ~isempty(cell2mat(strfind(soundNames(p),'c_')))
                        calibNameIndex(cindex)=p;
                        calibName{cindex}=soundNames(p);
                        cindex=cindex+1;
                    elseif ~isempty(cell2mat(strfind(soundNames(p),'white_')))
                        whiteNameIndex(windex)=p;
                        whiteName{windex}=soundNames(p);
                        windex=windex+1;
                    end
                end

                IndsAll=[calibNameIndex whiteNameIndex];
                cindex=1;
                windex=1;

                %calibration volumes...copied from SoundSection
                minVol=1;
                maxVol=100000;
                volInterval=10000;
                volVec=[minVol:volInterval:maxVol];
                
                %loop through freuqnecies / defined sounds
                g=1;
                for b=1:1:numel(calibNameIndex)+numel(whiteNameIndex);
                    %get the sound name
                    if b<=numel(calibNameIndex)
                        soundName=[calibName{cindex} '_' num2str(b*g)];
                    elseif b>numel(calibNameIndex)
                        soundName=[whiteName{windex} '_' num2str(b*g)];
                    end

                    %volume changing loop
                    for g=1:1:numel(volVec)-1

                        if g>1

                            SoundSection(obj,'update_volume',soundName,volVec(g))

                        end

                        %first, trigger ephus to record the mic input
                        sma = add_state(sma, 'name', ['ephus_trig_' num2str(b*g)], ...
                            'self_timer', 0.01,...
                            'output_actions',{'DOut',ephus_trig},...
                            'input_to_statechange', {'Tup', ['baseline_' soundName{:}]});

                        %if this isnt the last iteration...
                        if b~=numel(calibNameIndex)+numel(whiteNameIndex)
                            sma = add_state(sma, 'name', ['baseline_' soundName{:}], ...
                                'self_timer', 0.1,... %pause
                                'input_to_statechange', {'Tup', ['playSound_' soundName{:}]});
                            %if this is the last calibration sound
                            if b==numel(calibNameIndex)
                                soundName1=calibName{cindex};
                                %soundName2=whiteName{windex};
                                sma = add_state(sma, 'name', ['playSound_' soundName1{:}], ...
                                    'output_actions',{'SoundOut',calibNameIndex(cindex)},...
                                    'self_timer', 0.2,... %play sounds (should be 100ms long
                                    'input_to_statechange', {'Tup', ['ephus_trig_' num2str(b+1)]});
                                %if this is a white noise sound
                            elseif b>numel(calibNameIndex)
                                soundName1=whiteName{windex};
                                %soundName2=whiteName{windex+1};
                                sma = add_state(sma, 'name', ['playSound_' soundName1{:}], ...
                                    'output_actions',{'SoundOut',whiteNameIndex(windex)},...
                                    'self_timer', 0.2,... %play sounds (should be 100ms long
                                    'input_to_statechange', {'Tup', ['ephus_trig_' num2str(b+1)]});

                                windex=windex+1;
                                %if this any calibation sound but the last
                            else
                                soundName1=calibName{cindex};
                                %soundName2=calibName{cindex+1};
                                sma = add_state(sma, 'name', ['playSound_' soundName1{:}], ...
                                    'output_actions',{'SoundOut',calibNameIndex(cindex)},...
                                    'self_timer', 0.2,... %play sounds (should be 100ms long
                                    'input_to_statechange', {'Tup', ['ephus_trig_' num2str(b+1)]});

                                cindex=cindex+1;
                            end

                            %on the last iteration...
                        else
                            soundName=whiteName{windex};
                            sma = add_state(sma, 'name', ['baseline_' soundName{:}], ...
                                'self_timer', 0.01,... %pause
                                'input_to_statechange', {'Tup', ['playSound_' soundName{:}]});

                            sma = add_state(sma, 'name', ['playSound_' soundName{:}], ...
                                'output_actions',{'SoundOut',whiteNameIndex(windex)},...
                                'self_timer', 0.01,... %play sounds (should be 100ms long
                                'input_to_statechange', {'Tup', ['final_state']});

                            sma = add_state(sma, 'name', 'final_state', ...
                                'self_timer', 0.01,...
                                'input_to_statechange', {'Tup', 'check_next_trial_ready'});
                        end
                    end
                end

            otherwise
        end
        dispatcher('send_assembler', sma, 'final_state');
end %%% SWITCH action
