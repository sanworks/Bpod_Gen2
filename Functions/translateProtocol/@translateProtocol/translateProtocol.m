% %JPL - 2017 - translateProtocol, now a class
%
%takes Solo/Bcontrol Protocol and translates to a Bpod protocol

classdef translateProtocol < dynamicprops

    
    properties
        inSMA                       %SMA to be translated
        outSMA                      %type of SMA to translate to
        funclist                    %olo functions from original protocol
        param_struct                %struct version of 'SoloParam'
        param_vals                  %values for the handles
        owner_classes               %owner classes for the 'SoloParams'
        owner_classes_full          %slightly different format for above. Necessary?
        callbacks                   %callbacks for the 'SoloParams'
        settings                    %actual settings
        settingsFile                %name of settings file
        soloDir                     %main solo directory
        fullSoloPath                %full path under 'soloDir'
        protocolName                %main dir to be translted
        bpodProtocol                %full oath to bpod protocol
        soloProtocol                %points to new protocol in solo dir
        bpodSoloWrap                %points to wrapper m-filef or 'soloProtocol'
        BpodEvents                  %sotre bpod style raw events while in solo mode
        isClass                     %flag for if protocol is a class
        sm                          %fully assembled numerical state matrix
        soloRemapInput              %remapping structs
        soloRemapOutput
        protocolObj                 %empty solo protocol obj. read out during mfile translation from original mfile
        dispatcherObj               %empty dispatcher obj
        templateProtFile            %location of template protocol
        fake_rp_box                 %Bcontrol global specififying the use of Bpod as the SM (see updated 'MachinesSection')
        state_machine_server        %Bcontrol global, not really used for now other than to prevent not-found errors
        sound_machine_server        %Bcontrol global, not really used for now other than to prevent not-found errors
        
    end
    
    methods
        
        %%%EXTERNAL METHODS
        
        obj=translationCallback(obj); %new callback for all solo callbacks
        
        %%%INTERNAL METHODS
        
        function obj=translateProtocol(varargin)
            %main constructor for class
            global BpodSystem
            obj.templateProtFile=[BpodSystem.Path.BpodRoot filesep 'Functions/translateProtocol/@translateProtocol/TemplateProtocol.m'];
            
            % check inputs are correct
            if numel(varargin)==0
                display('translateProtocol:: creating empty translation object')
            else
                if numel(varargin) == 1
                    warning('ranslateProtocol:: assuming pwd is your main Solo directory')
                    obj.soloDir=pwd;
                    obj.protocolName=varargin{2};
                    if ~isdir([pwd filesep obj.protocolName]);
                        warning('translateProtocol:: protocol directory not on path')
                        warning('translateProtocol:: attempting to cd to directory')
                        try
                            cd obj.protocolName
                        catch
                            %let matlab throw the usual errors
                        end
                    end
                elseif numel(varargin) == 2 || numel(varargin) == 3 %JPL so ugly, fix
                    obj.soloDir=varargin{1};
                    obj.protocolName=varargin{2};
                    if ~isdir([obj.soloDir filesep obj.protocolName])
                        warning('translateProtocol:: protocol directory not on path')
                        warning('translateProtocol:: attempting to cd to directory')
                        try
                            cd obj.protocolName
                        catch
                            %let matlab throw the usual errors
                        end
                    end
                end
                
                if ~isempty(strfind(obj.protocolName,'@'))
                    %clearly a class
                    obj.isClass=1;
                else
                    %what if we add an @?
                    
                    [~,f,~]=fileparts(obj.protocolName);
                    if isdir([obj.soloDir filesep 'Protocols/@' f])
                        obj.isClass=1;
                    else
                        obj.isClass=0;
                    end
                end
                
                % try and load a settings file
                
                if numel(varargin) == 3
                    %third arg is optional, for specifying a settings file
                    obj.settingsFile=varargin{3};
                else
                    obj.settingsFile='';
                end
                
            end
        end
        
        function obj=buildMfile(obj)
            
            global BpodSystem
            
            templateDir=obj.templateProtFile;
                        
            mText=fileread(templateDir);
            
            [~,mfilename]=fileparts(obj.bpodSoloWrap);
              
            %---begin modifications to template
            
            templateStr = 'function TemplateProtocol';
            mText=strrep(mText,templateStr,['function ' mfilename]);
            
            [~,newname,~]=fileparts(obj.bpodSoloWrap);
            
            templateStr = 'TemplateProtocol';
            
            mText=strrep(mText,templateStr,strrep(mfilename,'_wrapper',''));

            %save
            if exist([obj.soloDir filesep 'Protocols' filesep newname '.m'])
                delete([obj.soloDir filesep 'Protocols' filesep newname '.m'])
            end
            fid = fopen([obj.soloDir filesep 'Protocols' filesep newname '.m'], 'a');
            fprintf(fid, '%s', mText);
            fclose(fid);

        end
        
        function genBpodSoloParams(obj)
            
            global BpodSystem
            
            %put the translation obj on the Bpod obj to make it global
            BpodSystem.ProtocolTranslation = obj;
            
            %% Define parameters
            
            %assignin the new non-Solo handleso
            GetSoloFunctionArgs;
            S=[];
            S_bad=[]; %for varioius figs, handles, axes, etc we dont want
            %read all solo params into the Bpod Parameter GUI
            if isempty(S)  % If settings file was an empty struct, populate struct with default settings
                %loop through SoloParamHandles
                for i=1:1:numel(obj.param_struct)
                    %add parameter to GUI
                    %exclude types that are incompatible with the BPod GUI
                    if isnumeric(obj.param_struct{i}.value) || ischar(obj.param_struct{i}.value)
                        S.GUI.(obj.param_struct{i}.param_name) = obj.param_vals{i};
                    else %add the parameter but not to the GUI since it doesnt play well with arbitraty types
                        
                        S_bad.(class(obj.param_struct{i}.param_name)).(obj.param_struct{i}.param_name) = obj.param_vals{i};
                    end
                end
            end
            
            [~,a,~]=fileparts(obj.protocolName);
            save([BpodSystem.Path.SettingsDir filesep a '_settings.mat'],'S')
            save([BpodSystem.Path.SettingsDir filesep a '_badsettings.mat'],'S_bad')
            
        end
        
        function assigninParams(obj)
            
            if isempty(strfind('@',obj.protocolName));
                origProtClass=['@' obj.protocolName];
                origProtFunc=obj.protocolName;
            else
                origProtClass=obj.protocolName;
                origProtFunc=obj.protocolName;
            end
            
            %first translate the SoloParam fielsd into structures
            for h=1:1:numel(obj.param_struct)
                if strcmp(origProtClass,obj.param_struct{h}.param_owner)
                    obj.param_struct{h}.param_owner=mfilename;
                end
                if ~isempty(strfind(obj.param_struct{h}.param_fullname,origProtFunc))
                    obj.param_struct{h}.param_fullname=[mfilename '_' obj.param_struct{h}.param_name];
                end
            end
            
            %and maintain a seperate list of [SoloParam].values
            for h=1:1:numel(obj.param_vals)
                if isa(obj.param_vals{h},origProtFunc) %sort of a hack
                    obj.param_vals{h}=struct(obj.param_vals{h});
                end
            end
            
            %now translate the Solofunction data
            idx=find(strcmp(origProtClass,obj.funclist(:,1))); %index of functions matching our orig protocol class name
            for h=1:1:numel(idx)
                obj.funclist(idx(h),1) = {obj.protocolName};
                %now index function files that match our original protocol;
                %second column has function names
                idx2=find(strcmp(origProtFunc,obj.funclist{idx(h),2}(:,1)));
                for b=1:1:numel(idx2)
                    obj.funclist{idx(h),2}(idx2(b),1) = {obj.protocolName};
                end
                
            end
            
            %for any ui that has a callback (which will be go through
            %'generic_callback', set to 'translation_callback', which will call the
            %appropriate m-file with the proper string arg, from the 'callbacks' struct
            
            %assignin the new non-Solo handles
            
            GetSoloFunctionArgs;

        end
        
        function obj=translateSMA(obj,varargin)
            
            global BpodObject
            
            %begin translation of the SMA for the protocol.
            %will depend on the type of the input SMA and output SMA.
            
            if isempty(varargin)
                %already have an sma assigned in, presumably
                if isempty(obj.inSMA)
                    error('translateProtocol.translateSMA:: inSMA must be provided if not alreayd assigned!')
                end
                
            else
                %probably want some checks here
                obj.inSMA=varargin{1};
            end
            
            %get sma type
            [~,in_sma_type]=get_sma_type(obj);
            
            switch in_sma_type
                case 'Bpod'
                    
                case 'Solo'
                    obj=SolotoBpod(obj);
                    %this nees to be based on something in obj.inSMA
                    %obj.type='Solo';
                case 'Bcontrol'
                    obj=BCtoBpod(obj);
                    %this nees to be based on something in obj.inSMA
                    %obj.type='Bcontrol';
                otherwise
                    error('translateSMA::dont know this SMA type. Add a new SMA config file');
            end
            
        end
        
        function obj=getBControlSettings(obj,varargin)
            
            if ~isempty(varargin)
                obj.settingsFile=varargin{1};
            end
            
            %get settings. if multiple, use the default.
            BControl_Settings=SettingsObject();
            
            if isempty(obj.settingsFile)
                obj.settingsFile='';
            end
            
            if exist([obj.settingsFile],'file') %make sure the specified settings file exists
                display(['translateProtocol.translateProtocol.getSoloParams::using settings file "' obj.settingsFile '"'])
            else
                
                if isdir([obj.soloDir filesep 'Settings'])
                    confFiles=dir([obj.soloDir filesep 'Settings']);
                else
                    warning('translateProtocol.translateProtocol.getSoloParams::couldnt locate a "Settings" dir. Please provide full path')
                    
                    dirct=0;
                    while dirct==0
                        dirct=uigetdir(pwd,'Please select a settings directory');
                    end
                    confFiles=dir(dirct);
                end
                
                if numel(confFiles)>1
                    %search for 'default' in title
                    idx=find(cell2mat(cellfun(@(x) ~isempty(strfind(x,'Default')),{confFiles.name},'UniformOutput',false)));
                    if idx
                        display('translateProtocol.translateProtocol.getSoloParams::founding a default settings file. Using that')
                        obj.settingsFile=confFiles(idx).name;
                    else
                        error('translateProtocol.translateProtocol.getSoloParams::could not locate a settings file! Need a settings file to determine IO map for BControl SMAs!')
                    end
                else
                    obj.settingsFile=confFiles.name;
                end
            end
            
            %load the settings
            [BControl_Settings errID_internal errmsg_internal] = LoadSettings(BControl_Settings, obj.settingsFile);
            tmp=struct(BControl_Settings);
            obj.settings=tmp.settings; %
            
        end
        
        function obj=getSoloParams(obj,varargin)
            
            %%%main function to transfer handles from solo/bcontrol to bpod
            
            %use: getSoloParams(soloDir,protocol_name,settings)
            
            %where 'soloDir' is the full path to the main Solo/Bcontrol dir,
            %where 'protocol_name' is the name of a protocol in the
            %    Protocols subdir you want transleted. Can also be a full
            %    path, e.g. if there isnt a protocol director
            % [OPTIONAL] where 'settings' is the name of the .config
            %    settings file you want use. If not provided, use anything
            %    matching 'default', or the only file in the directory
            
            
            %%
            
            % create SOLO dispatcher obj, and attempt to load settings files
            dispatcher_obj=dispatcher('empty');
            
            %load the protocol
            
            %create empty protocol object
            SoloParamHandle(dispatcher_obj, 'OpenProtocolObject', 'value', '');
            
            SoloFunctionAddVars('RunningSection',  'ro_args', 'OpenProtocolObject');
            SoloFunctionAddVars('MachinesSection', 'ro_args', 'OpenProtocolObject');
            
            % Get an empty object just to assign ownership of vars we will create
            if obj.isClass

                [~,str]=obj.asFunction(obj.protocolName);

                OpenProtocolObject.value = feval(str, 'empty');
            else

                tmp=strsplit(obj.protocolName,filesep);
                OpenProtocolObject.value = feval(tmp, 'empty');
            end
            
            % Now make sure all old variables owned by this class are smoked away:
            delete_sphandle('owner', ['^@', class(value(OpenProtocolObject)) '$']);
            
            % Make a set of global read_only vars that all protocol objects
            % will have and give them to the protocol object. First col is
            % varname, second is init value, third is 1 if rw for
            % RunningSection, 0 if rw for MachinesSection. All vars will be ro
            % for other section (other of RunningSection and MachineSection, that is).
            guys = { ...
                'raw_events'             []    0  ; ...
                'parsed_events'          []    0  ; ...
                'latest_parsed_events',  []    0  ; ...
                'n_done_trials'           0    0  ; ...
                'n_started_trials'        0    0  ; ...
                'n_completed_trials'      0    0  ; ...
                'current_assembler'      []    1  ; ...
                'prepare_next_trial_set' {}    1  ; ...
                };
            
            for i=1:size(guys,1),
                % Make all of these variables:
                SoloParamHandle(dispatcher_obj, guys{i,1}, 'value', guys{i,2});
                % Give them to the open protocol
                set_owner(eval(guys{i,1}), value(OpenProtocolObject));
            end;
            
            % And amke them read-onlies of the open protocol
            DeclareGlobals(value(OpenProtocolObject), 'ro_args', guys(:,1)');
            
            % Now some ro and some rw for RunningSection and MachinesSection here, too:
            runners = find(cell2mat(guys(:,3))==0); machiners = find(cell2mat(guys(:,3))==1);
            SoloFunctionAddVars('RunningSection',  'func_owner', ['@' class(dispatcher_obj)], 'ro_args', guys(machiners,1)');
            SoloFunctionAddVars('RunningSection',  'func_owner', ['@' class(dispatcher_obj)], 'rw_args', guys(runners,1)');
            
            SoloFunctionAddVars('MachinesSection', 'func_owner', ['@' class(dispatcher_obj)], 'ro_args', guys(runners,1)');
            SoloFunctionAddVars('MachinesSection', 'func_owner', ['@' class(dispatcher_obj)], 'rw_args', guys(machiners,1)');
            
            % Ok, we're ready-- actually open the protocol:
            % we load really only so 'private_soloparam_list' gets created
            
            [~,str]=fileparts(obj.protocolName);
            
            %tmp=strsplit(str,'/');
            feval(str, 'init');
            
            %some temp global defs for compatability with SoloParams.
            %these will not persist in the fully translated protocol
            global private_solofunction_list;  %this is populated by SoloFunction/SoloFunctionAddVars, etc
            global private_soloparam_list;     %this is populated by SoloParamHandle/SoloParam, etc
            global BControl_Settings
            
            %load the settings
            %need to cd back to the original directory...
            BControl_Settings=SettingsObject();
            [BControl_Settings errID_internal errmsg_internal] = LoadSettings(BControl_Settings, obj.settingsFile);
            tmp=struct(BControl_Settings);
            obj.settings=tmp.settings; %
            
            %%%%Deal with SoloFunc list
            
            % private_solofunction_list is a cell array with three columns. The
            % first column contains owner ids. Each row is unique. For each row
            % with an owner id, the second column contains a cell array that
            % corresponds to the set of function names that are registered for that
            % owner. The third row contains the globals declared for that owner.
            % so,we need to crawl through cell arrays in columns 2 and 3, look at the
            % second columns of the resulting columns for SoloParamHandle types, and
            % turn these into structures
            % ideally would want to do this recursively but I think the cell arrays only
            % go 2 or 3 deep, so lets just loop
            
            % TODO this is really ugly since I dont know if the construction of these nested
            %cell arrays is in any way systematic
            %what I know is that there are nested cell arrays of either 2 or 3 columns,
            %so we
            
            obj.funclist=private_solofunction_list;
            
            %loop through this stupid data structure
            columns=[2 3];
            for g=1:1:size(private_solofunction_list,1) %loop through functions
                for v=1:1:numel(columns) %loop through data columns, depth of 1
                    for z=1:1:numel(columns) %loop through data columns, depth of 2
                        for c=1:1:size(private_solofunction_list{g,columns(v)},1)
                            %second and third columns have slightly different internal
                            %structures, and dont really know if its systematic or not
                            try
                                if columns(z)<= numel(private_solofunction_list{g,columns(v)}(c,:))
                                    for x=1:1:size(private_solofunction_list{g,columns(v)}{c,columns(z)},1)
                                        if x>0
                                            tmp = value(private_solofunction_list{g,columns(v)}{c,columns(z)}{x,2});
                                            obj.funclist{g,columns(v)}{c,columns(z)}{x,2} = tmp;
                                        end
                                    end
                                end
                            catch %some peices of the structure dont know rows of cells. catch them here
                                for x=1:1:size(private_solofunction_list{g,columns(v)}{c},1)
                                    if x>0
                                        tmp = value(private_solofunction_list{g,columns(v)}{c}{x,2});
                                        obj.funclist{g,columns(v)}{c}{x,2} = tmp;
                                    end
                                end
                                
                            end
                        end
                    end
                end
            end
            
            %now replace private_solofunction_list with a struct
            private_solofunction_list=obj.funclist;
                        
            %%%%Deal with SoloParam list
            
            %main loop through SoloParamHandles. Will auto-create the Matlab obj
            %version of everything for each
            
            %the 'BpodObject' class has 'GUIHandle' and 'GUIData' properties.
            %I assume this is where most of the SoloParam info needs to go
            
            %list of unique param owner funcs.
            obj.owner_classes{1}=[];
            obj.owner_classes_full{1}=[];
            
            %list of allmfile names for callbacks and 'methods'. Dont care about
            %uniqueness for now
            obj.callbacks{1}= struct('mfiles','','methods','');
            
            %count=1;
            for i=1:1:numel(private_soloparam_list)
                
                %convert SoloParams to structures
                obj.param_struct{i} = struct(private_soloparam_list{i});
                %also keep their values
                obj.param_vals{i} = value(private_soloparam_list{i});
                
                if ~isempty(fields(obj.param_struct{i}))
                    
                    obj.owner_classes{i}=obj.param_struct{i}.param_owner;
                    obj.owner_classes_full{i}=obj.param_struct{i}.param_fullname; %
                    
                    %check that param callbacks m-files are accesible to us
                    %Callbacks are an n x m cell array, where rows (n) are the name of
                    %an m-file, and columns (m) are a string index into a switch statement
                    %inside that m-function. This is how SoloParamHandles worked.
                    
                    tmp=obj.param_struct{i}.callback_fn;
                    if ~iscell(tmp)
                        tmp={tmp};
                    end
                    
                    for g = 1:1:size(tmp,1) %loop through m-files
                        obj.callbacks{i}.mfiles{g,1}=tmp{g,1};
                        if ~isempty(strmatch(tmp{g,1},''))
                            obj.callbacks{i}.methods{g,2}=tmp{g,1};
                        else
                            for b = 1:1:size(tmp,2)-1 %loop through 'methods'
                                obj.callbacks{i}.methods{g,b}=tmp{g,b+1};
                            end
                        end
                        %finally, set the callback to 'translation_callback'
                        %param_struct{i}.callback_fn='translation_callback';
                        %obj.param_struct{i}.ghandle.Callback='translation_callback';
                        obj.param_struct{i}.ghandle.Callback='translateProtocol.translationCallback';
                    end
                else
                    obj.owner_classes{i}='';
                    obj.owner_classes_full{i}='';
                    obj.callbacks{i}='';
                    %obj.param_struct{i}.ghandle.Callback='translateProtocol.translationCallback';
                    
                end
                
            end
            
            %now replace private_soloparam_list with a struct
            private_soloparam_list=obj.param_struct;
            
            %build struct to mimic a solo protocol object
            %also requires determination of available plugins
            
            %first, detect any plugins we might want to use
            plugins=dir([obj.soloDir filesep 'Plugins']);
            
            if ~isempty(plugins)
                display(['translateProtocol.buildMFile:: found plugins. Adding all to the protocol obj'])
            else
                display(['translateProtocol.buildMFile:: no plugins found'])
                answer=inputdlg('No Plugins directory found. Would you like to point to one (yes/no)?');
                if strcmp(answer,'yes')
                    plugins=uigetdir(obj.soloDir, 'Pick a Directory');
                else
                    plugins='';
                end
            end
            
            plugins=plugins(find(cell2mat(...
                cellfun(@(x) isempty(strfind('.',x(1))), {plugins.name},...
                'UniformOutput',false))));
            
            
            protocolObj = struct('mfilename',mfilename);
            
            %add fields for each plugin we found
            for i=1:1:numel(plugins)
                if plugins(i).isdir==1;
                    name=plugins(i).name;
                    if strfind(name,'@')
                        name=name(2:end);
                    end
                elseif strfind(plugins(i).name,'.m')
                    name=named(1:strfind('.m',plugins(i).name));
                end
                protocolObj.(name)=name;
            end
            
            %assign the default protocol obj into the translation object
            obj.protocolObj=protocolObj;
            
            
        end
        
        function [obj,strOut]=asFunction(obj,strIn)
            %helper function to translate between Protocol name as a class, and as a function
            idx=strfind(strIn,'@');
            strOut=strIn;
            strOut(idx)=[];
        end
        
        function [obj] = createSM(obj)
            %attempt to create a valid state matrix for the protocol
            
        end
        
        function [obj,smaType]=get_sma_type(obj,varargin)
            
            %load config files for the approporate sma type...should be a file which
            %returns an empty sma struct. This is easy
            
            smaType=['Bcontrol'];
        end

        function obj=toBcontrol(obj,varargin)
            
            %make empty Bcontrol sma...but there are multiple types!
            obj.outSMA = StateMachineAssembler('full_trial_structure');
            
            
        end
    end
end