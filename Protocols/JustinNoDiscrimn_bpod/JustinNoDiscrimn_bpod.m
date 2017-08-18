%{
----------------------------------------------------------------------------
This file is part of the Sanworks Bpod repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA
----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}
function JustinNoDiscrimn_bpod

global BpodSystem

%if we went through translation, this will ahve some solo stuff in it as
%well
%load([BpodSystem.Path.SettingsDir filesep  'JustinNoDiscrimn_settings.mat']); %load as S

%create prot obj
str='JustinNoDiscrimn';        %get from settings, S!
protobj=feval(str, 'empty');

%and make this a subclass of the translation object 
%transobj=translateProtocol.translateProtocol();

transobj=translateProtocol();
transobj.protocolObj=protobj;

%to be loaded from settings...
transobj.protocolName='JustinNoDiscrimn';              %get from settings, S!
transobj.soloDir='/Users/littlej/Documents/ExperPortNewClient_20170202';   %get from settings, S!
transobj.settingsFile= '/Users/littlej/Documents/ExperPortNewClient_20170202/Settings/Settings_Justin2PRig.conf';  %get from settings, S!

%load solo settings values
transobj=getBControlSettings(transobj); %load settings

BpodSystem.ProtocolTranslation=transobj;

%initiate solo protocol
feval(transobj.protocolName,'init')


% Initialize parameter GUI plugin
%S=[];
%BpodParameterGUI('init', S);

%% Define trials
MaxTrials = 1000;
TrialTypes = ceil(rand(1,1000)*2);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%pause the system
%BpodSystem.Status.Pause = 1;
%HandlePauseCondition;

BpodSystem.ProtocolTranslation.trialnum_indicator_flag=1;
%% Main trial loop
for currentTrial = 1:MaxTrials
    
    BpodSystem.ProtocolTranslation.n_started_trials=currentTrial;
    BpodSystem.ProtocolTranslation.n_completed_trials=currentTrial-1;


    %S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    %create/update sma (BCONTROL END OF TRIAL AND UPDATE )
    %for Bcontrol, call main we look at main protocol file, and call:
    % 'trial_completed'
    % 'prepare_next_trial'
    % 'update' - in reality this should be a process that gets called
    %            multiple times during execution, but this will require
    %            some firmware work
    
    feval(transobj.protocolName,'trial_completed')    %no errors
    feval(transobj.protocolName,'prepare_next_trial') %errors!
    
    
    %if not bcontrol...
    %elseif strcmp('Solo',obj.outSMA.type)
    %for Solo, we need to call make_and_upload_state_matrix with 'init'
    %sma = make_and_upload_state_matrix(obj, 'init');
    %end
    
    keyboard
%     %---translate SMA 
%     sma.settings=obj.inSMA.settings; %make sure this added field gets transferred along
%     obj.inSMA=sma;
%     obj=translateSMA(obj);
%     sma=obj.outSMA;
%     
%     %%% Run the trial
%     SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.BeingUsed == 0
        return
    end
 
        
   % elseif strcmp(obj.outSMA.type,'Solo')
%     %% SOLO END OF TRIAL AND SMA UPDATE
%         % ------------------------------------------------------------------
%         % Call the list of functions in sequence, when a trial is finished:
%         % these are SoloFunctionAddVars added as methids to the protocol obj 
%         
%         % this NECESSARILY involves updated the sma for the next trial, and
%         % if it doesnt, you will be warned
%     
%         tmplist=obj.private_soloparam_list; %can have lots of emptys. ignore these
%         tmplist=tmplist(cellfun(@(x) ~isempty(struct(x)), tmplist,'UniformOutput',false));
%         
%         
%         eotAxIdx = find(cellfun(@(x) strcmp('trial_finished_actions',x.param_name), tmplist)); %get index in private solo param list that matches 'trial_finished_actions'
%         endOfTrialActions=struct(tmplist{eotAxIdx}).value;
%         
%         %execute end of trial actions
%         make_flag=0; %make sure make_and_upload_state_matrix gets called!
%         for i=1:1:numel(endOfTrialActions)
%             feval(endOfTrialActions{i}.param_func, endOfTrialActions{i}.value)
%             if strcmp('make_and_upload_state_matrix',endOfTrialActions{i}.param_func)
%                 make_flag=1;
%             end
%         end
%         
%         updateAxIdx = []; %get index in private solo param list that matches 'within_trial_update_actions'
%         updateActions=struct(tmplist{updateAxIdx}).value;
%         
%         %execute update actions
%         for i=1:1:numel(endOfTrialActions)
%             feval(endOfTrialActions{i}.param_func, endOfTrialActions{i}.value)
%             if make_flag == 0 || strcmp('make_and_upload_state_matrix',endOfTrialActions{i}.param_func)
%                 make_flag=1;
%             end
%         end
%         
%         if make_flag==0
%             error([mfilename ':: sma update function call was not included in end-of-trial actions!'])
%         end
%         
%     else
%         error([mfilename ':: dont know SMA-type '  obj.outSMA.type])
%     end
    
        feval(transobj.protocolName,'update')           
        BpodSystem.ProtocolTranslation.n_completed_trials=currentTrial;

end
end
