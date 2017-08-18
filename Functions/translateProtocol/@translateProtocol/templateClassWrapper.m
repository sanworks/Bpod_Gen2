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
function templateClassWrapper

global BpodSystem
%Bcontrol globals from settings
global fake_rp_box;
global state_machine_server;
global sound_machine_server;

load([BpodSystem.Path.SettingsDir filesep  'templateClassWrapper_settings.mat']); %load as S

fake_rp_box=S.translationObject.fake_rp_box;
state_machine_server=S.translationObject.state_machine_server;
sound_machine_server=S.translationObject.sound_machine_server;

%create prot obj
protobj=feval(S.translationObject.protocolName, 'empty'); %and make this a subclass of the translation object

transobj=S.translationObject;

addpath(genpath(transobj.soloDir)); 
BpodSystem.ProtocolTranslation=transobj;

%initate a dispatcher object to get its its solo params (
BpodSystem.ProtocolTranslation.dispatcherObj=dispatcher('init');
dispatcher(BpodSystem.ProtocolTranslation.dispatcherObj,'set_protocol',S.translationObject.protocolName);

% Initialize parameter GUI plugin
S=[];
if ~isempty(S)
    BpodParameterGUI('init', S);
end

%% Define trials
MaxTrials = 1000;
TrialTypes = ceil(rand(1,1000)*2);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%pause the system
BpodSystem.Status.Pause = 1;
HandlePauseCondition;

%% Main trial loop

for currentTrial = 1:MaxTrials
    
    if ~isempty(S)
        S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    end
    
    feval(transobj.protocolName,'prepare_next_trial')
    
    RawEvents = BpodSystem.ProtocolTranslation.BpodEvents;
    
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        if ~isempty(S)
            BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        end
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
    
    
    feval(transobj.protocolName,'update')
    
    feval(transobj.protocolName,'trial_completed')    %no errors

end
end
