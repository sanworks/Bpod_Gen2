% Create and send state matrix.

% Santiago Jaramillo - 2007.08.24
%
%%% CVS version control block - do not edit manually
%%%  $Revision: 1064 $
%%%  $Date: 2008-01-10 16:50:50 -0500 (Thu, 10 Jan 2008) $
%%%  $Source$



function sma = StateMatrixSection(obj, action)

%call to SetStateProgram occurs outside of this function when using
%dispatcher. Make the embedC matrix global
global G %stuff to send to globals.c
global m %matrix to append to end of statematrix for bitcode

%set in dispatcher, reflects Dout mappins from settings file
global unsorted_channels
global channels

%need to convert the channel mappings for each DOut to binary, then to
%decimal

%%%---OUTPUT SPECIFICATION

bitcode=4;           %binary = 1100,         bitcode is chan2
%lick_1=16;             %binary = 1001,         lick_1 is chan4
festo_trig=16;        %binary = 100001,       festo_trig is chan4 JPL - 11/29/15
lick_2=32;            %binary = 10001,        lick_2 is chan5
%festo_trig=65;        %binary = 100001,       festo_trig is chan6
lick_1=257;         %binary = 10000001,     cue_led1 is chan8
ephus_trig=1025;      %binary = 1000000001,   ephus_trig is chan10
%embc_touch_out=4097;  %binary = 100000000001, DIO line triggered by embc touch sched wave is chan12
i2c_sda= 131071;            % chabn 17
i2c_slc=  262143;              %chabn 18

GetSoloFunctionArgs;

switch action
    case 'update',
        %%%%NEXT TRIAL SETTINGS

        %create bit code
        %------ Signal trial number on digital output given by 'slid':
        % Requires that states 101 through 101+2*numbits be reserved
        % for giving bit signal.

        trialnum = n_completed_trials + 1;

        %first send serial trialnums to whoever is taking serial (whisker
        %computer most like)
        
        %convert trial to 16 bit
        s = serial('com4', 'baud', 250000);
        fopen(s);
        fwrite(s, 35);
        y = typecast(uint16(trialnum), 'uint8');
        fwrite(s, y(2));
        fwrite(s, y(1));
        fclose(s);
        
       %second send i2c to scanimage/wavesurfer
        
        address = uint8(0); %this depends on the port you have set to listen to
                            %on the i2c task in scanimage
        buffer = I2CEncodeBitStream(address,y);
       
        %finally send 10-bit to ephus/wavesurfer via ttl
        
        bittm = 0.003; % bit time
        gaptm = 0.007; % gap (inter-bit) time
        numbits = 10; %2^10=1024 possible trial nums

        x = double(dec2binvec(trialnum)');
        if length(x) < numbits
            x = [x; repmat(0, [numbits-length(x) 1])];
        end
        
        % x is now 10-bit vector giving trial num, LSB first (at top).
        x(x==1) = bitcode;
         
        % Insert a gap state between bits, to make reading bit pattern for EPHUS easier:
        x=[x zeros(size(x))]';
        x=reshape(x,numel(x),1);

        y = (101:(100+2*numbits))';
        t = repmat([bittm; gaptm],[numbits 1]);
        m = [y y y y y y y+1 t x zeros(size(y))];
        
%        %second send i2c to scanimage/wavesurfer as ascii, can go faster b/c
%        %fgpga
%         bittm_i2c = 0.0001; % bit time
%         address = uint8(0); %this depends on the port you have set to listen to
%                             %on the i2c task in scanimage
%         buffer = I2CEncodeBitStream(address,y);
%         % since we don't know the state of the bus at this point start the
%         % transmission with an end of transmission sequence (change SDA up while SCL is high)
%         % this resets FPGA I2C engine
%         % SDA,   SCL
%         resetBit = [ 0, 0;...
%                      0, 1 ;...
%                      1,  1 ];
% 
%         i2cStr=['trial:' num2str(trialnum)];
%         i2cOut=(vertcat(resetBit,buffer));
% 
%         %finally send 10-bit to ephus/wavesurfer via ttl
%         
%         %JPL - this code below is a bit superfluous, and specifies a
%         %statematrix def in the old stype for stats 101+ which used to be
%         %reserved for bitcode. These are NOT the stats Im using, and just
%         %read from the timing and dout column below...but leaving because I
%         %dont feel like breaking anything right now
%         y = (101:(100+2*numbits))';
%         t = repmat([bittm; gaptm],[numbits 1]);
%         m = [y y y y y y y+1 t x zeros(size(y))];
% keyboard
%         %end trial syncing stuff
%         
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     
        %JPL - for some reason, next_type is passed as a soloparamhandle,
        %but all the other next_ type vars are passed as strings
        if strcmp(next_stim_type,'s')
            stim_trial=true;
        else
            stim_trial=false;
        end

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
        cueId=active_locations.cue_id(find((strcmp(next_pos_id,...
            active_locations.name))==1));

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
                
                %IndCueSound = SoundManagerSection(obj, 'get_sound_id', cueId);
                IndCueSound = cell2mat(cueId);

            else %mismatch - dont need to do anything here, changed the pole posn
                 %already in TrialStructure. Leaving this here in case we
                 %ever want to mismatch on cues
                IndCueSound = cell2mat(cueId);
                %JPL - this code doesnt work actually - need to get a list
                %of active cues and use that
                %cueId=randsample(numel(active_locations.cue_id),1);
                %IndCueSound = cell2mat(cueId);
            end
        end
        %this exists as a drop-down menu item in the GUI, but delays here
         %JPL - make editable!
        rand_pole_delay_pool = [0.2 0.4 0.6 0.8];

        if ~strcmp(value(pole_delay), 'random')
            %do nothing
        else
            RandDelay_ind = ceil(length(rand_pole_delay_pool)*rand);
            pole_delay = rand_pole_delay_pool(RandDelay_ind); % set Pole delay time as a random number between 0.5 and 1.5
        end;
  
        %randomize delay period length
        %JPL - make editable!
        rand_delay_period_pool=[0.25 0.5 0.75 1.0 1.25 1.5];
        
        if ~strcmp(value(DelayPeriodTime), 'random')
            %do nothing
        else
            RandDelay_ind = ceil(length(rand_delay_period_pool)*rand);
            DelayPeriodTime = rand_delay_period_pool(RandDelay_ind); % set Pole delay time as a random number between 0.5 and 1.5
        end;
        
        %randomize answer delaqy
        %JPL - make editable!
       rand_delay_answer_pool=[0.25 0.5 0.75 1.0 1.25 1.5];
        
        
        if ~strcmp(value(AnswerDelayDur), 'random')
            %do nothing
        else
            RandDelay_ind = ceil(length(rand_delay_answer_pool)*rand);
            AnswerDelayDur = rand_delay_answer_pool(RandDelay_ind); % set Pole delay time as a random number between 0.5 and 1.5
        end;
        
        %response side / type 
        nxtside=(value(next_side));
        %response type, e.g. 'lick_r', e.g. go or 'none', e.g no go
        %not for now this is limited to go-no until motor gui is fixed
        nxttype=(value(next_type)); 
 
        %determine what AI variables can determine actions taken
        action_mode=value(ActionModeSPH);
        
        %determine what AI variables can determine rewards 
        %lick is a given, but it can be also touch_lick, whisk_lick,etc)
        answer_mode=value(AnswerModeSPH);

        %%%%PASS VARIABLES TO EmbedC)

        % -- Times Section
        %delays in the state machine are coded as multiples of the duty
        %cycle, which is 6 samples per ms. Here we define any delays we
        %wish to implement on AO or AI lines. For example, if we want to
        %change state 600ms after a touch on an AI line, then this value
        %will be 3600
        
        %if you want randomized values, pass a vector of possible values,
        %and these will be sampled - NOT IMPLEMENTED

        cyclesPerMs=6;
        
        %%%specify delays in ms here - MAKE GUI EDITABLE
        pre_pole_delay=pole_delay*1000;  %wait time after touch
        resonance_delay=value(ResonanceTO)*1000; %from pole up time! MAKE EDITIABLE
        answer_delay=AnswerDelayDur*1000;
        delay_period=DelayPeriodTime*1000;
        sample_period = SamplingPeriodTime*1000;
        answer_period = AnswerPeriodTime*1000;
        drink_period = DrinkTime*1000;
        mean_window_length = value(TouchFiltWinMean)*1000;       %3ms is good,time period to average over for signal measure,12 cycles MAKE EDITABLE
        median_window_length = value(TouchFiltWinMedian)*1000;     % 1/2 ms is good needs to be odd an even factor into mean window length MAKE EDITABLE
        baseline_length = value(TouchBaseline)*1000;       %2x mean window is good time period to average over for baseline measure,
        valve_time = WaterValveTime * 1000;
        log_analog_freq = 100;         %log analog values this often, so we dont overload the memory MAKE EDITABLE

        %this is an attempt tp make the delaty period = delay period +
        %resonance, w/ overlap, so poikes plot is accurate. howver, in
        %globals, things got messed up, so disabling for now
        if delay_period>resonance_delay
            %delay_period=resonance_delay+(delay_period-resonance_delay);
        else
            %delay_period=resonance_delay;
            warning('delay period duration is shorter than the resonance TO period!')
        end

        %%%convert
        pre_pole_delay=floor(pre_pole_delay.*cyclesPerMs);
        resonance_delay=floor(resonance_delay.*cyclesPerMs);
        answer_delay=floor(answer_delay.*cyclesPerMs);
        delay_period=floor(delay_period.*cyclesPerMs);
        sample_period=floor(sample_period.*cyclesPerMs);
        answer_period=floor(answer_period.*cyclesPerMs);
        mean_window_length=floor(mean_window_length.*cyclesPerMs);
        median_window_length=floor(median_window_length.*cyclesPerMs);
        baseline_length=floor(baseline_length.*cyclesPerMs);
        log_analog_freq=floor(log_analog_freq.*cyclesPerMs);
        valve_time=floor(valve_time.*cyclesPerMs);
       
        % -- Thresholds Section
        %need so specofcy threshold logic,a s well as state/states in
        %which to apply this threshold
        touch_thresh=value(TouchThreshHigh);   %units of absolute difference mV
       
        try
            touch_thresh_states=value(TouchThreshStates);
        catch
            %touch_thresh_states=[64 65];
            touch_thresh_states=[64 65]; %not yet sure how to pass a vector
        end
        
        try
            lick_thresh=value(LickThresh);   %units of V   
        catch
            lick_thresh=3; %default TTL logic
        end
        
        try
            lick_thresh_states=value(LickThreshStates);
        catch
            %lick_thresh_states=[66 67];
            lick_thresh_states=[66];
        end
        
        whiskvel_thresh=0; %not really doing this yet so dont know the values
        whiskvel_thresh_states=[1]; %there is no state 1

        %----Punishment Section
        intfail=value(InitFail);
        dlyfail=value(DelayFail);
        rspfail=value(ResponseFail);
        rspdlyfail=value(ResponseDelayFail);
        incrspfail=value(IncorrectResponse);

        %provide ids for each sound.
        rew_cue=IndSoundReward;
        go_cue=IndSoundGo;
        fail_cue=IndNoise;
        pole_cue=IndCueSound;

        %'JPL - StateMatrixSection - need to get the protocol name into here to finish the embedC path, but cant figure it out right now...just doing it manually');
        %manual='@pole_detect_jpl_0obj';
        manual='@JustinNoDiscrimn';
        embCPath=[bSettings('get','GENERAL','Protocols_Directory') '\' manual '\' 'embc\'] ;

        %load the string of variables to pass to the FSM
        G=wrap_c_file_in_string([pwd embCPath 'globals.c']);

        %build the embedC string
        %G = preprocessEmbC(G,touch_thresh,pre_pole_delay,...
        %    resonance_delay,answer_delay,delay_period,sample_period,...
        %    answer_period,drink_period,mean_window_length,median_window_length,baseline_length,...
        %    log_analog_freq,valve_time,rew_cue,go_cue,fail_cue,pole_cue);
        %JPL - this is getting unweildly. Maybe time to have the inputs in
        %a struct
        
%         G = preprocessEmbC(G,touch_thresh,touch_thresh_states,lick_thresh,...
%             lick_thresh_states,whiskvel_thresh,whiskvel_thresh_states,...
%             pre_pole_delay,resonance_delay,answer_delay,delay_period,sample_period,...
%             answer_period,drink_period,mean_window_length,median_window_length,baseline_length,...
%             log_analog_freq,valve_time,rew_cue,go_cue,fail_cue,pole_cue,answer_mode,action_mode,...
%             intfail,dlyfail,rspfail,rspdlyfail,incrspfail,nxtside,nxttype);       
        
        %%%%PREPARE STATEMATRIX
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

                %MAIN STATE MACHINE DEFINITION
                
                %-----------SCHED WAVES
                [sma] = add_scheduled_wave(sma,...
                    'name','lickport_1',...
                    'sustain', WaterValveTime,...
                    'dio_line', 0);

                %%-----START------------------------------------------------------
                %send bitcode and start
                
                sma = add_state(sma, 'name', 'start');              %40
                
                %add bitcode / i2c states
                
                %states 41:60
                %bitcode/i2c triggering takes 28ms
                
                for i=1:size(m,1)-1,

                    %ouput actions are:
                    %bitcode bit m,
                    
                    sma = add_state(sma, 'name', ['bitcode_' num2str(i)],...
                        'self_timer', m(i,8),...
                        'output_actions',{'DOut',m(i,9)},...
                        'input_to_statechange',{'Tup',['bitcode_' num2str(i+1)]});
                end
                sma = add_state(sma, 'name', ['bitcode_' num2str(i+1)]);

               
                
                %resume 
                sma = add_state(sma, 'name', 'pre_pole_time');      %61
                sma = add_state(sma, 'name', 'raise_pole');         %62
                sma = add_state(sma, 'name', 'resonance_timeout');  %63
                sma = add_state(sma, 'name', 'delay');              %64
                sma = add_state(sma, 'name', 'cue_and_sample');     %65
                sma = add_state(sma, 'name', 'answer_delay');       %66
                
                %from here we let state control go back to matlab to
                %control the delivery of the reward and decide on hit and
                %miss states.
                sma = add_state(sma, 'name', 'answer_period');      %67
                
                %upon exiting state 47, the dout bypass in embedc gets
                %turned off, so now matlab can trigger the lickport              
                
                sma = add_state(sma, 'name', 'valve');              %68
                
                sma = add_state(sma, 'name', 'drink');              %69     
                
                sma = add_state(sma, 'name', 'hit',...              %70
                    'self_timer', 0.1,...
                    'input_to_statechange',{'Tup','final_state'});  
               
                sma = add_state(sma, 'name', 'miss',...             %71
                    'self_timer', 0.1,...
                    'input_to_statechange',{'Tup','final_state'});  
                
                sma = add_state(sma, 'name', 'timeout');            %72
                sma = add_state(sma, 'name', 'wait');               %73
                
             
                sma = add_state(sma, 'name', 'final_state', ...     %74
                    'self_timer', 0.5,...
                    'input_to_statechange',...
                    {'Tup', 'check_next_trial_ready'});

        case 'test'

                %MAIN STATE MACHINE DEFINITION
                
                %-----------SCHED WAVES
                [sma] = add_scheduled_wave(sma,...
                    'name','lickport_1',...
                    'sustain', WaterValveTime,...
                    'dio_line', 0);

                %%-----START------------------------------------------------------
                %send bitcode and start
                
                sma = add_state(sma, 'name', 'start');              %40
                    
                %add bitcode / i2c states
                
                %states 41:60
                %bitcode/i2c triggering takes 28ms
                
                for i=1:size(m,1)-1,

                    %ouput actions are:
                    %bitcode bit m,
                    
                    sma = add_state(sma, 'name', ['bitcode_' num2str(i)],...
                        'self_timer', m(i,8),...
                        'output_actions',{'DOut',m(i,9)},...
                        'input_to_statechange',{'Tup',['bitcode_' num2str(i+1)]});
                end
                sma = add_state(sma, 'name', ['bitcode_' num2str(i+1)]);

                %resume 
                sma = add_state(sma, 'name', 'pre_pole_time');      %61
                sma = add_state(sma, 'name', 'raise_pole');         %62
                sma = add_state(sma, 'name', 'resonance_timeout');  %63
                sma = add_state(sma, 'name', 'delay');              %64
                sma = add_state(sma, 'name', 'cue_and_sample');     %65
                sma = add_state(sma, 'name', 'answer_delay');       %66
                
                %from here we let state control go back to matlab to
                %control the delivery of the reward and decide on hit and
                %miss states.
                sma = add_state(sma, 'name', 'answer_period');      %67
                
                %upon exiting state 47, the dout bypass in embedc gets
                %turned off, so now matlab can trigger the lickport              
                
                sma = add_state(sma, 'name', 'valve');              %68
                
                sma = add_state(sma, 'name', 'drink');              %69     
                
                sma = add_state(sma, 'name', 'response',...         %70
                    'self_timer', 0.1);  
               
                sma = add_state(sma, 'name', 'noresponse',...       %71
                    'self_timer', 0.1);  
                
                sma = add_state(sma, 'name', 'hit',...              %72
                    'self_timer', 0.1,...
                    'input_to_statechange',{'Tup','final_state'});  
               
                sma = add_state(sma, 'name', 'miss',...             %73
                    'self_timer', 0.1,...
                    'input_to_statechange',{'Tup','final_state'});                 
               
                sma = add_state(sma, 'name', 'false_alarm',...      %74
                    'self_timer', 0.1,...
                    'input_to_statechange',{'Tup','final_state'});  
                
                sma = add_state(sma, 'name', 'correct_reject',...   %75
                    'self_timer', 0.1,...
                    'input_to_statechange',{'Tup','final_state'});                 
                
                sma = add_state(sma, 'name', 'punish');             %76
                
                sma = add_state(sma, 'name', 'wait');               %77
                
                sma = add_state(sma, 'name', 'final_state', ...     %78
                    'self_timer', 0.5,...
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
