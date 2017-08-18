% This file contains code that will be run whenever there is
% a call to  AutomationSection(obj,'run_autocommands');
%
% Santiago Jaramillo - 2007.09.24

%%% Note: changes actually occur in TrialNumber-1
%%% because of the weird meaning of n_done_trials.

AutoActionsList.value = {'none',...
                    'ChangeContextByBlocks',...
                    'IncreaseCueTime',...
                    'ChangeWaterDelivery',...
                    'TwoBlocksBefore5050',...
                   };
%                    'SNR1',...
%                    'ChangeDistractorVolByBlock',...


switch value(AutoCommandsMenu)

  %%% -------- CHANGING CONTEXT -------
  case {'ChangeContextByBlocks'}
    % -- Automating some parameters --
    autoDistractorVolume=get_sphandle('name','DistractorVolume');
    autoRelevantSide=get_sphandle('name','RelevantSideSPH');
    autoWaterDelivery=get_sphandle('name','WaterDeliverySPH');
    autoPreStimMean=get_sphandle('name','PreStimMean');
    autoPreStimRange=get_sphandle('name','PreStimRange');
    if n_done_trials==2
        autoWaterDelivery{1}.value = 'only if nxt pke corr';
        autoPreStimMean{1}.value = 0.3;
        autoPreStimRange{1}.value = 0.1;
    %elseif any(n_done_trials==[ 150:150:2000 ])
    elseif any(n_done_trials==[ 200:200:2000 ])
        if(strcmp(value(autoRelevantSide{1}),'left'))
            autoRelevantSide{1}.value = 'right';
        else
            autoRelevantSide{1}.value = 'left';
        end
        autoDistractorVolume{1}.value = 0.001;
        SoundsSection(obj,'update_all_sounds');
    end

  %%% -------- CHANGING CONTEXT -------
  case {'TwoBlocksBefore5050'}
    % -- Automating some parameters --
    autoDistractorVolume=get_sphandle('name','DistractorVolume');
    autoRelevantSide=get_sphandle('name','RelevantSideSPH');
    autoWaterDelivery=get_sphandle('name','WaterDeliverySPH');
    autoPreStimMean=get_sphandle('name','PreStimMean');
    autoPreStimRange=get_sphandle('name','PreStimRange');
    autoTargetModIndex=get_sphandle('name','TargetModIndex');
    autoProbingContextEveryNtrialsSPH=get_sphandle('name','ProbingContextEveryNtrialsSPH');
    if n_done_trials==2
        autoWaterDelivery{1}.value = 'only if nxt pke corr';
        autoPreStimMean{1}.value = 0.3;
        autoPreStimRange{1}.value = 0.1;
        autoTargetModIndex{1}.value_callback = 0.004; 
    elseif any(n_done_trials==[ 150:150:2000 ])
    %elseif any(n_done_trials==[ 200:200:2000 ])
        if(strcmp(value(autoRelevantSide{1}),'left'))
            autoRelevantSide{1}.value = 'right';
        else
            autoRelevantSide{1}.value = 'left';
        end
        autoDistractorVolume{1}.value = 0.001;
        SoundsSection(obj,'update_all_sounds');
    end
    if n_done_trials==300
        autoProbingContextEveryNtrialsSPH{1}.value_callback = 2;
    end
    
  %%% -------- CHANGING SIDES, INCREASING CUE TIME -------
  case {'IncreaseCueTime'}
    % -- Automating some parameters --
    %autoSoundDuration=get_sphandle('name','SoundDuration');
    autoDistractorVolume=get_sphandle('name','DistractorVolume');
    autoRelevantSide=get_sphandle('name','RelevantSideSPH');
    autoWaterDelivery=get_sphandle('name','WaterDeliverySPH');
    autoPreStimMean=get_sphandle('name','PreStimMean');
    autoPreStimRange=get_sphandle('name','PreStimRange');
    if ~mod(n_done_trials,5)
        %autoSoundDuration{1}.value_callback = value(autoSoundDuration{1})+0.020;
        autoPreStimMean{1}.value_callback = value(autoPreStimMean{1})+0.020;
    end
    if n_done_trials==20
        %autoWaterDelivery{1}.value = 'only if nxt pke corr';
        %autoWaterDelivery{1}.value = 'nxt corr poke';
        %autoPreStimMean{1}.value = 0.3;
        %autoPreStimRange{1}.value = 0.1;
    elseif any(n_done_trials==[ 1200:120:2000 ])
        if(strcmp(value(autoRelevantSide{1}),'left'))
            autoRelevantSide{1}.value = 'right';
        else
            autoRelevantSide{1}.value = 'left';
        end
        %autoDistractorVolume{1}.value = 0.001;
        %SoundsSection(obj,'update_all_sounds');
    end

  %%% --------------- OPERANT ----------------------
  case {'ChangeWaterDelivery'}
    autoWaterDelivery=get_sphandle('name','WaterDeliverySPH');
    autoPreStimMean=get_sphandle('name','PreStimMean');
    autoPreStimRange=get_sphandle('name','PreStimRange');
    if n_done_trials==5
        autoWaterDelivery{1}.value = 'next corr poke';
    elseif n_done_trials==10
        autoPreStimMean{1}.value = 0.3;
        autoPreStimRange{1}.value = 0.1;
    elseif n_done_trials==30
        autoWaterDelivery{1}.value = 'only if nxt pke corr';
    end        
    
  %%% -------- FOR ELECTROPHYSIOLOGY (SNR=1)-------
  case {'SNR1'}
    autoDistractorVolume=get_sphandle('name','DistractorVolume');
    autoRelevantSide=get_sphandle('name','RelevantSideSPH');
    autoWaterDelivery=get_sphandle('name','WaterDeliverySPH');
    autoPreStimMean=get_sphandle('name','PreStimMean');
    autoPreStimRange=get_sphandle('name','PreStimRange');
    if n_done_trials==10
        autoWaterDelivery{1}.value = 'only if nxt pke corr';
        autoPreStimMean{1}.value = 0.3;
        autoPreStimRange{1}.value = 0.1;
    elseif any(n_done_trials==[ 30:120:1000 ])   %  30 150 270 390 510
        autoDistractorVolume{1}.value = 1;
        SoundsSection(obj,'update_all_sounds');
    elseif  any(n_done_trials==[ 130:120:1000 ]) % 130 250 370 490 610
        if(strcmp(value(autoRelevantSide{1}),'left'))
            autoRelevantSide{1}.value = 'right';
        else
            autoRelevantSide{1}.value = 'left';
        end
        autoDistractorVolume{1}.value = 0.001;
        SoundsSection(obj,'update_all_sounds');
    end
    
    
  %%% -------- CHANGING DISTRACTOR VOLUME BY BLOCKS -------
  case {'ChangeDistractorVolByBlock'}
    % -- Automating some parameters --
    autoDistractorVolume=get_sphandle('name','DistractorVolume');
    autoRelevantSide=get_sphandle('name','RelevantSideSPH');
    autoWaterDelivery=get_sphandle('name','WaterDeliverySPH');
    autoPreStimMean=get_sphandle('name','PreStimMean');
    if n_done_trials==10
        autoWaterDelivery{1}.value = 'only if nxt pke corr';
        autoPreStimMean{1}.value = 0.2;
    elseif any(n_done_trials==[ 50, 180, 310, 440, 570 ])
        autoDistractorVolume{1}.value = 1;
        SoundsSection(obj,'update_all_sounds');
    elseif any(n_done_trials==[ 170, 300, 430, 560 ])
        autoDistractorVolume{1}.value = 0.001;
        SoundsSection(obj,'update_all_sounds');
    elseif n_done_trials==430
        if(strcmp(value(autoRelevantSide{1}),'left'))
            autoRelevantSide{1}.value = 'right';
        else
            autoRelevantSide{1}.value = 'left';
        end
        autoDistractorVolume{1}.value = 0.001;
        SoundsSection(obj,'update_all_sounds');
    end

  %%% --------------- nothing ----------------------
  case {'none'}
    % DO NOTHING
    
  otherwise
    fprintf('AutoAction not recognized.\n');
end


%elseif 0%n_done_trials==50 || n_done_trials==280 || n_done_trials==510 || n_done_trials==640
