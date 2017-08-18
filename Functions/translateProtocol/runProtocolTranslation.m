%main script to run for protocol translation

%% warn about bcontrol updates

%some automation here under develop,emt

%[names,isdir]=recursPath(dirr);
%fnames=names(~isdir);
%outstring='';
%tab='       ';
%options.Resize='on';
%options.WindowStyle='normal';
%options.Interpreter='tex';
%for b=1:1:numel(fnames)
%    if b==numel(fnames)
%        outstring=[outstring fnames{b} '\n\n'];
%    else
%        outstring=[outstring fnames{b} '\n' tab];
%    end
%end
%prompt=sprintf(['Warning! Protocol translation requires modifications to the Bcontrol directories:\n\n       '...
%    outstring...
%    '\n Working off a local copy of your main Bcnontrol directory is advisable \n'...
%    '\n Do you still want to be being translation (yes/no)? \n']);

prompt=sprintf(['Warning! Protocol translation requires modifications to the Bcontrol directories!\n\n       '...
    '\n Working off a local copy of your main Bcnontrol directory is advisable \n'...
    '\n Do you still want to be being translation (yes/no)? \n']);

answer = inputdlg(prompt, 'Unassigned Solo Channels');

if strcmp(answer,'no')
    return
end

%% Determine matlab version
whichVer=[];
if verLessThan('matlab','8.4.0')
    % R2014a or earlier, return a double figure handle
    whichVer='old';
else
    % execute code for R2014b or later
    whichVer='new';
end

%% Load headless bpod, if Bpod not open
port='AUTO';
t=whos();

if ~any(strcmp({t.name},'BpodSystem'))
    try
        Bpod({port},'headless')
    catch
        error('runProtocolTranslation: no Bpod detected!')
    end
end

global BpodSystem

%% Solo / Bcontrol directory selection

%select a main solo directory
uiwait(msgbox('Please select the main Solo/Bcontrol directory'));
answer = uigetdir(pwd,'Select directory');

soloDir=answer;

%add it to the path
pathCell = regexp(path, pathsep, 'split');
if ispc
    onPath = any(strcmpi(soloDir, pathCell));
else
    onPath = any(strcmp(soloDir, pathCell));
end

if ~onPath
    addpath(genpath(soloDir))
end

%% 'install' necessary modifications for translation

%TODO: find folders and files in /transalateProtocol/BcontrolMods/ folder
%on Bcontrol path, and replace...manually done below for now

%TODO: if already installed, dont bother

%--copy @BpodSM module to Bcontrol Modules
ndir=[soloDir filesep 'Modules' filesep '@BpodSM'];
mkdir(ndir);
rehash();
cpdir=[BpodSystem.Path.BpodRoot filesep 'Functions' filesep...
    'translateProtocol' filesep 'BcontrolMods' filesep 'Modules'];
copyfile(cpdir,ndir,'f')

%--copy @BpodSoundServer module to Bcontrol Modules
ndir=[soloDir filesep 'Modules' filesep '@BpodSoundServer' ];
mkdir(ndir);
rehash();
cpdir=[BpodSystem.Path.BpodRoot filesep 'Functions' filesep...
    'translateProtocol' filesep 'BcontrolMods' filesep 'Modules'];
copyfile(cpdir,ndir,'f')

%--copy modificitation to @dispatcher class
dispatchdir=[soloDir filesep 'Modules' filesep '@dispatcher'];

delete([dispatchdir filesep 'dispatcher.m']);
display('"dispatcher/dispatcher.m" has been deleted!')
delete([dispatchdir filesep 'ProtocolsSection.m']);
display('"dispatcher/ProtocolsSection.m" has been deleted!')
delete([dispatchdir filesep 'RunningSetion.m']);
display('"dispatcher/RunningSection.m" has been deleted!')
delete([dispatchdir filesep 'MachinesSection.m']);
display('"dispatcher/MachinesSection.m" has been deleted!')

cpdir=[BpodSystem.Path.BpodRoot filesep 'Functions' filesep...
    'translateProtocol' filesep 'BcontrolMods' filesep 'Modules' filesep '@dispatcher'];

copyfile([cpdir filesep 'dispatcher.m'],dispatchdir,'f')
display('"dispatcher/dispatcher.m" has been replaced!')
copyfile([cpdir filesep 'ProtocolsSection.m'],dispatchdir,'f')
display('"dispatcher/ProtocolsSection.m" has been replaced!')
copyfile([cpdir filesep 'RunningSection.m'],dispatchdir,'f')
display('"dispatcher/RunningSection.m" has been replaced!')
copyfile([cpdir filesep 'MachinesSection.m'],dispatchdir,'f')
display('"dispatcher/MachinesSection.m" has been replaced!')

%--copy modificitation to @SoloParam class
sParamDir=[soloDir filesep 'HandleParam' filesep '@SoloParam'];

delete([sParamDir filesep 'SoloParam.m']);
display('"SoloParam/SoloParam.m" has been deleted!')

cpdir=[BpodSystem.Path.BpodRoot filesep 'Functions' filesep...
    'translateProtocol' filesep 'BcontrolMods' filesep 'HandleParam'...
    filesep '@SoloParam'];

copyfile([cpdir filesep 'SoloParam.m'],sParamDir,'f')
display('"SoloParam/SoloParam.m" has been replaced!')

%--copy modificitation to HandleParam functions
handleDir=[soloDir filesep 'HandleParam'];

delete([handleDir filesep 'uigetfile.m']);
display('"HandleParam/uigetfile.m" has been deleted!')
delete([handleDir filesep 'GetSoloFunctionArgs.m']);
display('"HandleParam/GetSoloFunctionArgs.m" has been deleted!')

cpdir=[BpodSystem.Path.BpodRoot filesep 'Functions' filesep...
    'translateProtocol' filesep 'BcontrolMods' filesep 'HandleParam'];

copyfile([cpdir filesep 'uigetfile.m'],handleDir,'f')
display('"HandleParam/uigetfile.m" has been replaced!')
copyfile([cpdir filesep 'GetSoloFunctionArgs.m'],handleDir,'f')
display('"HandleParam/GetSoloFunctionArgs.m" has been replaced!')

%--copy modificitation to Modules functions
modDir=[soloDir filesep 'Modules'];

delete([modDir filesep 'Settings.m']);
display('"Modules/Settings.m" has been deleted!')
delete([modDir filesep 'bSettings.m']);
display('"Modules/bSettings.m" has been deleted!')

cpdir=[BpodSystem.Path.BpodRoot filesep 'Functions' filesep...
    'translateProtocol' filesep 'BcontrolMods' filesep 'Modules'];

copyfile([cpdir filesep 'Settings.m'],modDir,'f')
display('"Modules/Settings.m" has been replaced!')
copyfile([cpdir filesep 'bSettings.m'],modDir,'f')
display('"Modules/bSettings.m" has been replaced!')

%% Select a protocol to translate, and copy
uiwait(msgbox('Please select the name of a Solo/Bcontrol protocol folder/class'));
protPath = uigetdir(soloDir,'Protocol Selection');

%check if on path, add if not
pathCell=strsplit(path,':');
if  ~any(strcmp(pathCell,protPath))
    addpath(protPath)
end

%find main protocol m file...assuming it has the same name the containing
%class
[~,protocol,~]=fileparts(protPath);

%remove @
if ~isempty(strfind(protocol, '@'))
    protocol=strrep(protocol,'@','');
end

%add '_bpod' protPath name
newprotPath=[protPath '_bpod'];
newprotocol=[protocol '_bpod'];

%make a renamed copy of this protocol in the same dir
if isdir(newprotPath)
    %overwrite warning
    prompt=sprintf(['Warning! there exists a Bpod Protocol with the name:\n\n       '...
        newprotocol...
        '\n Do you want to overwrite it (yes/no)? \n']);
    
    answer2 = inputdlg(prompt, 'Existing protoco;;');
    
    if strcmp(answer2,'yes')
        %create directory and copy solo class in
        delete([newprotPath]);
        mkdir([newprotPath]);
        rehash();
        copyfile(protPath,newprotPath,'f')
    elseif strcmp(answer,'no')
        return;
    end
else
    %create directory and copy solo class in
    try
        mkdir([newprotPath]);
        rehash();
    catch
        %need to do better excpetion handling, but this is likely a permissions issue
        %try and resolve...
        keyboard
    end
    copyfile(protPath,newprotPath,'f')
end


ms=dir(newprotPath);
if any(strcmp({ms.name},[protocol '.m']))
    %rename the main class file
    data= fileread([newprotPath filesep protocol '.m']);
    newdata=strrep(data,protocol,newprotocol);
    %save
    delete([newprotPath filesep newprotocol '.m'])
    fid = fopen([newprotPath filesep newprotocol '.m'], 'a');
    fprintf(fid, '%s', newdata);
    fclose(fid);
    delete([newprotPath filesep protocol '.m']);
else
    error('runProtocolTranslation::Unable to find main protocol function. Must have same name as class folder');
end

protPath=[BpodSystem.Path.ProtocolFolder newprotocol];

%add solo protocols dir to the BpodSettings
load([BpodSystem.Path.SettingsDir filesep 'BpodSettings.mat'])
BpodSettings.SoloProtocolFolder=[soloDir filesep 'Protocols/'];
save([BpodSystem.Path.SettingsDir filesep 'BpodSettings.mat'],'BpodSettings');

%% check for errors resulting from calling this protocol

% IN DEVELOPMENT, so issue a warning
prompt=sprintf(['Warning! Errors may occur when translating protocols written in older versions of Matlab!\n\n       '...
    '\n A common problem is use of words for variables that are now reserved for Matlab-only use. \n'...
    '\n These will be auto-fixed in later versions. \n']);
handle=warndlg(prompt,'Compatability Warning');
waitfor(handle)
try
    close(handle)
catch
end

mfiles=dir([newprotPath filesep '*.m']);
%obj=feval(newprotocol(1:end),'empty');
for v=1:1:numel(mfiles)
    %isgood(v)=checkFileCompat(obj,[protPath filesep mfiles(v).name],whichVer);
end

%% get the settings file
% in new solo, this is a .conf
% in old solo, I believe this is a something titled 'mystartup.mat'
%
uiwait(msgbox('Please locate your settings file'));
settingsFile=uigetfile({'*.conf';'*.m'},'Settings File Selection');

[sfdir,sfname,sfext]=fileparts(settingsFile);


%% create a protocol translation object
obj=translateProtocol();

%default name for wrapper func
newname=[newprotocol '_wrapper'];

obj.protocolName=newprotocol;
obj.soloDir=soloDir;
obj.fullSoloPath=recursPath(soloDir);
obj.soloProtocol=newprotPath;
obj.bpodSoloWrap=[soloDir filesep 'Protocols' filesep newname];
%check the settings file for a bug:
%in RIGS section, its possible to set 'fake_rp_box'=20, 
%or to set 'new_rt' = 1 to specify use of @RTLSM2. 
%however, 'send' checks fake_rp_box ~= 2 only, thus if you dont have 
%'new_rt' in RIGS, this will give the wrong sized sm. 
%so, if in settings 'fake_rp_box'=20 and there is no 'new_rt' field, then
%make one

setStruct=returnSettingsStruct([soloDir filesep 'Settings' filesep settingsFile]);

if ~isfield(setStruct.settings.RIGS,'new_rt') &&...
        (setStruct.settings.RIGS.fake_rp_box==20 || setStruct.settings.RIGS.fake_rp_box==4)
    new_rt_str=sprintf(['RIGS; fake_rp_box;          20\nRIGS; new_rt;               1']); %string to add
    ftext=fileread([soloDir filesep 'Settings' filesep settingsFile]);
    ftext=strrep(ftext,['RIGS; fake_rp_box;          ' num2str(setStruct.settings.RIGS.fake_rp_box)],new_rt_str);
    
    delete([soloDir filesep 'Settings' filesep settingsFile]);
    fid=fopen([soloDir filesep 'Settings' filesep settingsFile], 'a');
    fprintf(fid, '%s', ftext);
    fclose(fid);
end

obj.settingsFile=[soloDir filesep 'Settings' filesep settingsFile];
%%

%HERE WE DIVERGE FOR OLD AND NEW SOLO

if strcmp(sfext,'.conf') %Bcontrol protocols
    
    obj.buildMfile();  %make modifications to the template bpod protocol we just copied in
    
    %-- remap inputs and outputs
    %create an SMA for the protocol we are translating
    %first need to determine what kind of sma by examing 'StateMatrixSection'
    %
    %%%WARNING; assumes a call to 'dispatcher' within a function called
    %
    prompt=sprintf(['Warning! translation assumes a call to "dispatcher" within a method called "StateMatrixSection"!\n\n       '...
        '\n If your procotol doesnt follow this standard, for now it must be changed. \n'...
        '\n These will be auto-fixed in later versions. \n']);
    
    handle=warndlg(prompt,'Protocol Object Method Assumptions');
    waitfor(handle)
    try
        close(handle)
    catch
    end
    
    sma_types= {'no_dead_time_technology',...
        'standard_state35_technology',...
        'full_trial_structure'};
    sms_text=fileread([obj.soloDir filesep 'Protocols' filesep...
        '@' obj.protocolName filesep 'StateMatrixSection.m']);
    
    if isempty(sms_text)
        error(['runProtocolTranslation:: couldnt find a method file in your protocol called "StateMatrixSection"\n'...
            'Please rename the function in your protocol that calls "dispatcher" to "StateMatrixSection"']);
    end
    
    sma_type=sma_types{find(cellfun(@(x) ~isempty(strfind(sms_text,x)), sma_types))};
    
    clear sma;
    obj.inSMA=struct(StateMachineAssembler(sma_type));
    
    obj=getBControlSettings(obj);
    
    
elseif strcmp(sfext,'.m') %old solo protocol
    
    % UNDER DEVELOPMENT
    
    %    %%%WARNING; assumes a call to 'make_and_upload_state_matrix' within a function called
    %    % %%         'rpbox'
    %
    %
    %    tmp=dir([newprotPath filesep '*.m']);
    %
    %    if ~any(cellfun(@(x) ~isempty(strfind(x,'make_and_upload_state_matrix')),{tmp.name}))
    %        error(['runProtocolTranslation:: couldnt find a file in your protocol called "StateMatrixSection"\n'...
    %            'Please rename the function in your protocol that calls dispatcher to "StateMatrixSection"'];
    %    end
    
    %only way to do this is ask the user to manually input a vector of
    %string ids, and numerical ids, as is done in
    %'make_and_upload_state_matrix', since there doesnt appear to be any
    %formalized way to define these in old solo
    
    %for inputs, we will assume 6: Cin,Cout,Lin,Lout,Rin, Rout, with IDs
    %1,-1, 2, -2, 3, -3...but make it editable
    
    %for outputs, just have to enter amnually
    
    handle = oldSoloPreRemapper(obj,[]);
    
    %pause script until finish button clicked in gui and figure is closed
    waitfor(handle)
    
    %obj.inSMA = [];
    
end


% assign protocol translation obj into bpod obj
BpodSystem.ProtocolTranslation=obj;

%% start the i/o remapping gui
handle=SoloPortRemapper_export(obj,[]);

%pause script until finish button clicked in gui and figure is closed
waitfor(handle)

try
    close(handle)
catch
    %
end

%% save translation info into a bpod settings file
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
S.translationObject=obj;

%set some Bcontrol globals
S.translationObject.fake_rp_box=4; %signifies use of Bpod in updated dispatcher
S.translationObject.state_machine_server='localhost'; %not used, Bcontrol values as placeholder
S.translationObject.sound_machine_server='localhost'; %not used, Bcontrol values as placeholder

save([BpodSystem.Path.SettingsDir filesep newprotocol '_settings.mat'],'S')

%% close everything

flush;   %close solo stuff

clear all;

close all;





