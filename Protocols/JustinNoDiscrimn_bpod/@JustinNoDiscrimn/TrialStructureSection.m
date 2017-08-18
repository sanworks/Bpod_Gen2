% [x, y] = TrialStrucutreSection(obj, action, x, y)
%
% Section that takes care of choosing the next trial type and keeping
% track of a plot of sides and hit/miss history.
%
% PARAMETERS:
% -----------
%
% obj      Default object argument.
%
% action   One of:
%            'init'      To initialise the section and set up the GUI
%                        for it; also calls 'choose_next_trial_type' and
%                        'update_plot' (see below)
%
%            'reinit'    Delete all of this section's GUIs and data,
%                        and reinit, at the same position on the same
%                        figure as the original section GUI was placed.
%
%            'choose_next_trial_type'  Picks what will be the next correct
%                        side.
%
%            'get_next_trial_type'  Returns either 'l' for left or 'r' for right.
%
%            'update_plot'    Update plot that reports on sides and hit
%                        history
%
% x, y     Relevant to action = 'init'; they indicate the initial
%          position to place the GUI at, in the current figure window
%
% RETURNS:
% --------
%
% [x, y]   When action == 'init', returns x and y, pixel positions on
%          the current figure, updated after placing of this section's GUI.
%
% x        When action = 'get_next_trial_type', x will be either 'l' for
%          left or 'r' for right.
%

function [x, y] = TrialStructureSection(obj, action, x, y)
GetSoloFunctionArgs;
switch action
    
    case 'init',   % ------------ CASE INIT ----------------
        % Save the figure and the position in the figure where we are
        % going to start adding GUI elements:

        fnum=gcf;
        SoloParamHandle(obj, 'my_gui_info', 'value', [x y fnum.Number]);
        
        % -- Anti-bias methods --
        MenuParam(obj, 'AntiBias_lick', {'none','autolearn_dho','fixed_dho',...
            'antibias_dho','repeat_miss'}, 'none', ...
            x, y, 'TooltipString', 'Method for reducing lick bias');
        next_row(y);
        
        MenuParam(obj, 'AntiBias_pole', {'none','null_predict','repeat_miss','repeat_noaction','reward_mag'}, 'none', ...
            x, y, 'TooltipString', 'Method for reducing bias');
        next_row(y);
        
        % -- Option to disable motors
        MenuParam(obj, 'Move_pole', {'yes','no'}, 'no', ...
            x, y, 'TooltipString', ' option to disable motors');
        next_row(y);
        
        % --- Max times same side ---
        MenuParam(obj, 'MaxSame_side', {'3', '6', '9', '12', '15', '18', 'Inf'}, Inf, ...
            x, y, 'TooltipString', 'Maximum number of times the same side can appear sequentially');
        set_callback(MaxSame_side, {mfilename, 'update_rewardsides'});
        next_row(y);
        
        % --- Max times same pole position ---
        MenuParam(obj, 'MaxSame_pole', {'1', '2', '3', '4', '5', '6', '7', 'Inf'}, 3, ...
            x, y, 'TooltipString', 'Maximum number of times the same position can appear sequentially');
        set_callback(MaxSame_pole, {mfilename, 'update_poleposn'});
        next_row(y);
        
        %--- rewXrs
        NumeditParam(obj, 'rewXrVals', [0 0.5 1 2], x, y,'TooltipString',...
            'Position threshold (low) for real-time touch detector.');
        next_row(y);
        
        %--- threshXrs
        NumeditParam(obj, 'actionXrVals', [0.5 1 2], x, y,'TooltipString',...
            'Position threshold (low) for real-time touch detector.');
        next_row(y);
        
        % how to end the sampe period, from action or timeout
        
        MenuParam(obj, 'SampleEnd',...
            {'timeout', 'action'}, 'timeout', x, y,...
            'label','Sample End On','TooltipString', 'Type of delivery');
        next_row(y);
        
        
        NumeditParam(obj, 'TouchThreshHigh', 0.004, x, y,'TooltipString',...
            'Position threshold (high) for real-time touch detector.');
        next_row(y);
        
        %--- for controlling how trial initiation occurs (free, touching a
        %sensor, or through the real-time whisker video
        MenuParam(obj, 'TrialInit', {'free','sensor','tracking'},'free', x, y,'TooltipString',...
            'Position threshold (low) for real-time touch detector.');
        next_row(y);
        
        % Give read-only access to StateMatrixSection.m:
        SoloFunctionAddVars('StateMatrixSection', 'ro_args',...
            {'TouchThreshHigh','TrialInit','SampleEnd'});
        
        % stimulation delay - JPL move to stimulation section?
        NumeditParam(obj, 'stimEpochs', [45 46 47 48], x, y,'TooltipString',...
            'Vect of state numbers in which to apply stimulus');
        
        %Give StateMatrixSection acces to what it needs
        SoloFunctionAddVars('StateMatrixSection', 'ro_args', {'actionXrVals','rewXrVals','stimEpochs'});
        
        
    case 'choose_next_trial_type', % --------- CASE choose_next_trial_type -----
        
        % next_type, previous_types          ---> specifies type,such as go/nogo por mimsatch
        % next_side, previous_sides          ---> specifices whether left or right, or go no go
        % next_position, previous position   ---> specifies next pole position
        % next_stim_type, previous_stim_type ---> which type of stimulus
        
        %now there will be different things to do depending on the type og
        %behavior we are running
        
        %CHOOSE NEXT POLE POSITION
        
        active_locations_tmp=value(active_locations);
        
        %get pole probabilities
        poleprbs=cell2mat(active_locations.pr);
        repeat_flag=0;
        
        %CHOOSE NEXT POSITION,
        %first note the last position
        try
            tmp=get_history('currentPoleId');
            lastind=tmp(end);
        catch
            lastind=1;
        end
        try
        ind=randsample(numel(cell2mat(value(active_locations.id))),1,'true',poleprbs);
        catch
            keyboard
        end
        next_position=active_locations.coords{ind};
        
        next_pos_id.value=value(active_locations.name(ind));
        next_axial_pos.value=next_position(1);
        next_radial_pos.value=next_position(2);
        
        %change the position, depending on antibias, repeats, etc
        
        if ~strcmp(value(AntiBias_pole), 'none')
            if strcmp(value(AntiBias_pole), 'repeat_noaction') %doing nothing on during sample on trials when they are meant to do something
                %AntibiasSection(obj, 'pole_bias', SamplePeriodActionHistory,PoleHist,'repeat_miss');
                if n_completed_trials >= 1 &&  ~strcmp('none', value(active_locations.sampleAction(lastind)))
                    tmp=get_history('SamplePeriodActionHistory');
                    %WHYYYY
                    try
                        tmp = [tmp value(SamplePeriodActionHistory)]; %last entry not in history yet;
                    catch
                        tmp = [tmp; value(SamplePeriodActionHistory)]; %last entry not in history yet;
                    end
                    dTmp=[0 diff(tmp)']';
                    polehist=get_history('current_location_index');
                    if n_completed_trials < value(MaxSame_pole)
                        padhack=n_completed_trials;
                    else
                        padhack=value(MaxSame_pole);
                    end
                    %should we repeat
                    if ~strcmp(value(MaxSame_pole), 'Inf') ...  %max not sent to inf...
                            && sum(dTmp(end-(value(padhack)-1):end)==0)<= padhack... %and the last n trials were not  action trials
                            && sum([0; diff(polehist(end-(padhack-1):end))]) == 0        %and these trials all had the same pole. phew
                        
                        repeat_flag=1;
                        
                        next_position=active_locations.coords{lastind};
                        next_pos_id.value=value(active_locations.name(lastind));
                        
                        next_axial_pos.value=next_position(1);
                        next_radial_pos.value=next_position(2);
                        
                        previous_positions_id.value=lastind;
                        
                    else %last trial was a touch, does not apply
                        
                        ind=randsample(numel(cell2mat(value(active_locations.id))),1,'true',poleprbs);
                        
                        next_position=active_locations.coords{ind};
                        
                        next_pos_id.value=value(active_locations.name(ind));
                        next_axial_pos.value=next_position(1);
                        next_radial_pos.value=next_position(2);
                        
                        previous_positions_id.value=ind;
                        
                    end
                    
                end
                
            elseif strcmp(value(AntiBias_pole), 'null_predict')
                %AntibiasSection(obj, 'pole_bias', SamplePeriodActionHistory, PoleHist,'null_predict');
            elseif strcmp(value(AntiBias_pole), 'reward_mag')
                %AntibiasSection(obj, 'pole_bias', SamplePeriodActionHistory, PoleHist,'reward_mag');
            end
            
            %apply max same critera if necessarey
            
        else %no antibias method selected. Choose next stimulus strictly based
            %on uniform sampling of all available pole positions,
            %constrained be the MaxSame parameter
            %MaxSame doesnt NOT apply
            if strcmp(value(MaxSame_pole), 'Inf') %| value(MaxSame_pole) >= n_started_trials,
                
                %choose one of the the available pole positions randomly
                ind=randsample(numel(cell2mat(value(active_locations.id))),1,'true',poleprbs);
                
                next_position=active_locations.coords{ind};
                
                next_pos_id.value=value(active_locations.name(ind));
                next_axial_pos.value=next_position(1);
                next_radial_pos.value=next_position(2);
                
                %save the numerical index of of this pole position
                %for MaxSame checking
                
                previous_positions_id.value=ind;
            else
                
                % MaxSame applies, check for its rules:
                % If there's been a string of MaxSame guys all te same, force change:
                tmp=get_history('previous_positions_id');
                if ~iscell(tmp)
                    tmp={tmp};
                end
                tmp=(tmp(~cellfun(@isempty,tmp)));
                %do not ever look here...
                try
                    try
                        crapola=sum([0; diff(cellfun(@cell2mat, {tmp}, 'UniformOutput',false))]);
                    catch
                        crapola=sum([0; diff(cellfun(@cell2mat, tmp))]);
                    end
                catch
                    crapola=sum([0; diff(cell2mat(tmp))]);
                end
                if crapola==0
                    
                    %choose another location at random that is not
                    %the same as the last position
                    
                    ind=randsample(numel(cell2mat(value(active_locations.id))),1,'true',poleprbs);
                    
                    next_pos_id.value=value(active_locations.name(ind));
                    next_position=active_locations.coords{ind};
                    next_axial_pos.value=next_position(1);
                    next_radial_pos.value=next_position(2);
                    previous_positions_id.value=ind;
                else
                    % Haven't reached MaxSame limits yet, choose at random:
                    ind=randsample(numel(cell2mat(value(active_locations.id))),1,'true',poleprbs);
                    next_pos_id.value=value(active_locations.name(ind));
                    next_position=active_locations.coords{ind};
                    next_axial_pos.value=next_position(1);
                    next_radial_pos.value=next_position(2);
                    previous_positions_id.value=ind;
                    
                end
                
            end
        end
        
        %CHOOSE NEXT TRIAL TYPE, completely determined by the pole
        %choice we just made, but subject to mismatches
        
        next_type.value=value(active_locations.go_nogo{ind});
        
        %CHOOSE NEXT SIDE (e.g. left/right)
        
        %JPL - 20161213 - starting to code antbias and maxsameside for
        %licks
        
%         %for now their is only on lick port
%         if ~strcmp(value(AntiBias_lick), 'none')
%             if strcmp(value(AntiBias_lick), 'repeat_noaction') %doing nothing on during sample on trials when they are meant to do something
%                 %AntibiasSection(obj, 'lick_bias', SamplePeriodActionHistory,LickHist,'repeat_miss');
%                 if n_completed_trials >= 1
% %                     tmp=get_history('SamplePeriodActionHistory');
% %                     %WHYYYY
% %                     try
% %                         tmp = [tmp value(SamplePeriodActionHistory)]; %last entry not in history yet;
% %                     catch
% %                         tmp = [tmp; value(SamplePeriodActionHistory)]; %last entry not in history yet;
% %                     end
% %                     dTmp=[0 diff(tmp)']';
% %                     polehist=get_history('current_location_index');
% %                     if n_completed_trials < value(MaxSame_pole)
% %                         padhack=n_completed_trials;
% %                     else
% %                         padhack=value(MaxSame_pole);
% %                     end
%                     %should we repeat
%                     if ~strcmp(value(MaxSame_side), 'Inf') ...  %max not sent to inf...
%                             && sum(dTmp(end-(value(padhack)-1):end)==0)<= padhack... %and the last n trials were not  action trials
%                             && sum([0; diff(polehist(end-(padhack-1):end))]) == 0        %and these trials all had the same pole. phew
%                         
%                         repeat_flag=1;
%                         
%                         next_position=active_locations.coords{lastind};
%                         next_pos_id.value=value(active_locations.name(lastind));
%                         
%                         next_axial_pos.value=next_position(1);
%                         next_radial_pos.value=next_position(2);
%                         
%                         previous_positions_id.value=lastind;
%                         
%                     else %last trial was a touch, does not apply
%                         
%                         ind=randsample(numel(cell2mat(value(active_locations.id))),1,'true',poleprbs);
%                         
%                         next_position=active_locations.coords{ind};
%                         
%                         next_pos_id.value=value(active_locations.name(ind));
%                         next_axial_pos.value=next_position(1);
%                         next_radial_pos.value=next_position(2);
%                         
%                         previous_positions_id.value=ind;
%                         
%                     end
%                     
%                 end
                
        if strmatch(value(active_locations.go_nogo{ind}),'go')
            next_side.value='left';
        elseif strmatch(value(active_locations.go_nogo{ind}),'nogo')
            next_side.value='right';
        elseif strmatch(value(active_locations.go_nogo{ind},'left'))
            next_side.value='left';
        elseif strmatch(value(active_locations.go_nogo{ind},'right'))
            next_side.value='right';
        else
            error(['unknown side choice: ' value(active_locations.go_nogo{ind})])
        end
%         
        %%%CHOOSE PREDICTION OR MISMATCH TRIAL FOR LOCATION
        %if determined to be a mismatch trial,
        %change ONLY the location to a different active location
        %happens randomly for own, but eventually can be subject to a
        %function
        n_completed_trials=0;
        if repeat_flag==0 && n_completed_trials >= 1 %do not allow mismatches when apply antibias repeating, or on first trials
            %get pole mismatch prs
            
            missprbs=value(active_locations.mismatch_pr{ind});
            tmp=randsample(0.1:0.1:1,1);
            
            if tmp <= missprbs(1) %&& sum(strcmp('go',value(active_locations.go_nogo))) > 1 %can only choose another position if other positions exist!
                
                %mismatch it
                poleprbs(ind)=0; %make sure we dont choose the same position
                
                %we keep the id and cue but change the coordinates
                %to a new id2!
                next_pos_id.value=value(active_locations.name(ind));
                ind2=randsample(numel(cell2mat(value(active_locations.id))),1);
                
                next_mismatch_id.value=value(active_locations.name(ind2));
                next_position=value(active_locations.coords{ind2});
                next_axial_pos.value=next_position(1);
                next_radial_pos.value=next_position(2);
                previous_positions_id=ind2;
                
                %set active locations
                active_locations_tmp.isMismatchTrial{ind}(1) = 1;
                active_locations_tmp.mismatchId{ind}(1) = ind2;
                
                next_predict.value='loc:mismatch';
            else
                next_mismatch_id.value='';
                next_predict.value='loc:predict';
            end
        else
            next_mismatch_id.value='';
            next_predict.value='loc:predict';
        end
        
        %%%CHOOSE PREDICTION OR MISMATCH TRIAL FOR REWARD XR
        %if determined to be a mismatch trial,
        %change ONLY the reward Xr value from a defined set in settins
        %happens randomly for own, but eventually can be subject to a
        %function
        if repeat_flag==0 && n_completed_trials >= 1 %do not allow mismatches when apply antibias repeating, or on first trials
            
            missprbs=active_locations.mismatch_pr{ind};
            tmp=randsample(0.1:0.1:1,1);
            
            if tmp <= missprbs(2) %&& sum(strcmp('go',value(active_locations.go_nogo))) > 1 %can only choose another position if other positions exist!
                
                %mismatch it
                ymh_rew=unique(value(rewXrVals));
                ymh_rew(find(ymh_rew==value(active_locations.rewXr{ind}))) = []; %dont let the Xr value NOT change
                if numel(ymh_rew)>1
                    rvind= randsample(numel(ymh_rew),1);
                else
                    rvind=ymh_rew; %only one other option
                end
                next_rewXr_mismatch_id.value=rvind;
                next_predict_rewXr.value='reward:mismatch';
                %set active locations
                active_locations_tmp.isMismatchTrial{ind}(2) = 1;
                active_locations_tmp.mismatchId{ind}(2) = rvind;
            else
                next_rewXr_mismatch_id.value=0;
                next_predict_rewXr.value='reward:predict';
            end
        else
            next_rewXr_mismatch_id.value=0;
            next_predict_rewXr.value='reward:predict';
        end
        %%%CHOOSE PREDICTION OR MISMATCH TRIAL FOR ACTION THRESH XR
        %if determined to be a mismatch trial,
        %change ONLY the action Xr value from a defined set in settins
        %happens randomly for own, but eventually can be subject to a
        %function
        if repeat_flag==0 && n_completed_trials >= 1 %do not allow mismatches when apply antibias repeating, or on first trials
            missprbs=value(active_locations.mismatch_pr{ind});
            tmp=randsample(0.1:0.1:1,1);
            if tmp <= missprbs(3) %&& sum(strcmp('go',value(active_locations.go_nogo))) > 1 %can only choose another position if other positions exist!
                %mismatch it
                ymh_act=unique(value(actionXrVals));
                ymh_act(find(ymh_act==value(active_locations.actionThreshXr{ind}))) = []; %dont let the Xr value NOT change
                if numel(ymh_act)>1
                    axind= randsample(numel(ymh_act),1);
                else
                    axind = ymh_act; %only one other option
                end
                next_actXr_mismatch_id.value=axind;
                %set active locations
                active_locations_tmp.isMismatchTrial{ind}(3) = 1;
                active_locations_tmp.mismatchId{ind}(3) = axind;
                
                next_predict_actionXr.value='action:mismatch';
            else
                next_actXr_mismatch_id.value=0;
                next_predict_actionXr.value='action:predict';
            end
        else
            next_actXr_mismatch_id.value=0;
            next_predict_actionXr.value='action:predict';
        end
        %%%CHOOSE PREDICTION OR MISMATCH TRIAL FOR CUE
        %if determined to be a mismatch trial,
        %change ONLY the cue from pool of all current active cues
        %happens randomly for own, but eventually can be subject to a
        %function
        %NOTE: if we already chose a LOCATION mismatch for this trial, we
        %cannot also mismath the CUE
        %also do not allow mismatches when apply antibias repeating, or on first trials
        if repeat_flag==0 && n_completed_trials >= 1 && strcmp(value(next_predict),'loc:mismatch') == 0;
            missprbs=value(active_locations.mismatch_pr{ind});
            tmp=randsample(0.1:0.1:1,1);
            if tmp <= missprbs(4) && sum(unique(cell2mat(value(active_locations.cue_id)))) > 1 %can only choose another position if other positions exist!
                
                %mismatch it
                ymh_cue=unique(cell2mat(value(active_locations.cue_id)),'stable');
                ymh_cue(find(ymh_cue==value(active_locations.cue_id{ind})))=[]; %remove the assigned cue from the list
                if numel(ymh_cue)>1
                    cueind= randsample(ymh_cue,1);
                else
                    cueind = ymh_cue; %only one other option
                end
                next_cue_mismatch_id.value=cueind;
                %set active locations
                active_locations_tmp.isMismatchTrial{ind}(4) = 1;
                active_locations_tmp.mismatchId{ind}(4) = cueind;
                next_predict_cue.value='cue:mismatch';
            else
                next_cue_mismatch_id.value=0;
                next_predict_cue.value='cue:predict';
            end
        else
            next_cue_mismatch_id.value=0;
            next_predict_cue.value='cue:predict';
        end
        %%%CHOOSE NEXT STIMULUS TRIAL TYPE
        %e.g., is this a trial where we want to stimulate with a
        %laser
        
        %If we are apply some kind of stimulus, decide randomly
        %whether this is a stim trial based on GUI settings
        temp=rand(1);
        %if temp <= value(StimProb)
        if temp <= value(0)
            next_stim_type.value = 'stim';
            %set active locations
            active_locations_tmp.isStimTrial{ind} = 1;
        else
            next_stim_type.value = 'nostim';
        end
        
        %when are we applying the stimulation
        if strcmp(value(next_stim_type), 's')
            %for now just randomly sample the available epochs/state
            next_stim_epoch.value = randsample(value(stimEpochs),1);
            active_locations_tmp.stimEpochId=find(value(stimEpochs)==value(next_stim_epoch));
            
        end
        
        %%%%cleanup and set next trial
        active_locations.value=active_locations_tmp;
        
        previous_types.value = value(next_type);
        previous_stim_types.value = value(next_stim_type);
        previous_sides.value = value(next_side);
        previous_positions_id.value = find(strcmp(next_pos_id,active_locations.name)==1);
        previous_positions.value = [num2str(value(next_position(1))) '_' num2str(value(next_position(1)))];
        previous_predictions.value = value(next_predict);
        previous_predictions_actionXr.value = value(next_predict_actionXr);
        previous_predictions_rewXr.value = value(next_predict_rewXr);
        previos_predictions_cue.value = value(next_predict_cue);
        previous_trial_types.value = value(next_trial_type);
        
        n_started_trials=1;
        
        %send some of this sides info back to the main Protocol
        %mfile
        display(['---------------- Params for Trial # ' num2str(n_started_trials) '----------------'])

        %trial type info
        disp(['Next trial type: ' value(next_type)]);
        disp(['Next trial side: ' value(next_side)]);
        %stim state info
        disp(['Next stim type: ' value(next_stim_type)]);
        disp(['Next stim epoch: ' value(next_stim_epoch)]);
        %pole info
        disp(['Next pole id/name: ' num2str(find(strcmp(next_pos_id,active_locations.name)==1)) ' / ' char(value(next_pos_id))]);
        disp(['Next pole prediction state: ' value(next_predict)]);
        if find(strcmp(next_mismatch_id,active_locations.name)==1)~=0
            disp(['Next real pole id/name: ' num2str(find(strcmp(next_mismatch_id,active_locations.name)==1)) ' / ' char(value(next_mismatch_id))]);
        else
            disp(['Next real pole id/name: / '])
        end
        %cue info
        disp(['Next cue id/name: ' num2str(cell2mat(active_locations.cue_id(find(strcmp(next_pos_id,active_locations.name)==1))))...
            ' / ' char(active_locations.cue_name(find(strcmp(next_pos_id,active_locations.name)==1)))]);
        disp(['Next cue prediction state: ' value(next_predict_cue)]);
        if  value(next_cue_mismatch_id)~=0
            try
                disp(['Next real cue id/name: ' num2str(value(next_cue_mismatch_id)) ' / ' char(active_locations.cue_name(find(cell2mat(active_locations.cue_id)==(value(next_cue_mismatch_id)))))])
            catch
                keyboard
            end
        else
            disp(['Next real cue id/name:  / '])
        end
        %reward info
        disp(['Next reward prediction state: ' value(next_predict_rewXr)]);
        if value(next_rewXr_mismatch_id)~=0
            try
                disp(['Next reward Xr id/value: ' num2str(value(next_rewXr_mismatch_id)) ' / ' num2str(value(rewXrVals(value(value(next_rewXr_mismatch_id)))))]);
            catch
                keyboard
            end
        else
            disp(['Next reward Xr id/value: / ']);
        end
        %action xr info
        disp(['Next action threshold prediction state: ' value(next_predict_actionXr)]);
        if value(next_actXr_mismatch_id)~=0
            try
                disp(['Next action threshold Xr id/value: ' num2str(value(next_actXr_mismatch_id)) ' / ' num2str(value(actionXrVals(value(value(next_actXr_mismatch_id)))))]);
            catch
                keyboard
            end
        else
            disp(['Next action thresold Xr id/value: / '])
        end
        
        %Session types where discrimination is required (e.g. 2AFC,
        %go-nogo, mulitple pole go-nogo,etc)
    case {'Discrim_Sounds', 'Discrim_Poles'}
        
        IrrelevantProb=1-RelevantSideProb; %set implicitly in GUI when we
        
        disp(['Next trial type: ' next_trial_type]);
        
        %end %SWITCH SESSION TYPE
        
    case 'apply_antibias'
        %JPL - not yet implemented, just a linkthru to the antibias plugin
        
        
    case 'setPoleUpSpeed'
        
        %not doing anything with this for the moment
        
        
    case 'updatePredictProb'
        
        updatePredictProb = value(predictProb);
        updateMismatchProb = 1-updatePredictProb;
        
        mismatchProb.value=updateMismatchProb;
        
    case 'updateMismatchProb'
        
        updateMismatchProb = value(mismatchProb);
        updatePredictProb = 1-mismatchProb;
        
        predictProb.value=updatePredictProb;
        
    case 'update_plot'     % --------- UPDATE_PLOT ------
        
        
    case 'reinit',   % ------- CASE REINIT -------------
        currfig = gcf;
        
        % Get the original GUI position and figure:
        x = my_gui_info(1); y = my_gui_info(2); figure(my_gui_info(3));
        
        delete(value(myaxes));
        
        % Delete all SoloParamHandles who belong to this object and whose
        % fullname starts with the name of this mfile:
        delete_sphandle('owner', ['^@' class(obj) '$'], ...
            'fullname', ['^' mfilename]);
        
        % Reinitialise at the original GUI position and figure:
        [x, y] = feval(mfilename, obj, 'init', x, y);
        
        % Restore the current figure:
        figure(currfig);
end;


