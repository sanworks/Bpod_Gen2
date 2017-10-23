function [x, y] = ProtocolsSection(obj, action, x, y)

GetSoloFunctionArgs;

switch action,
  
  case 'init', 
    prot_list = ProtocolsSection(obj, 'scan_protocols');
    MenuParam(obj, 'protocol_list', prot_list, 1, x, y, 'labelfraction', 0.3); next_row(y);
    set_callback(protocol_list, {mfilename, 'protocols'});

    SoloParamHandle(obj, 'OpenProtocolObject', 'value', '');

    SoloFunctionAddVars('RunningSection',  'ro_args', 'OpenProtocolObject');
    SoloFunctionAddVars('MachinesSection', 'ro_args', 'OpenProtocolObject');
    
  case 'rescan_protocols',    
    % Get the new list of protocols:
    new_prot_list = ProtocolsSection(obj, 'scan_protocols');
    curr_prot_name = value(protocol_list);
    % If the currently open protocol is no longer in list, try to close it:
    if ~any(strcmp(curr_prot_name, new_prot_list)),
      try, ProtocolsSection(obj, 'close_protocol'); catch, end;
      curr_prot_name = '';
    end;

    % get the old figure and position of the old SoloParamHandle, and then
    % delete the old one:
    p = get_position(protocol_list); p = p(1,:);
    % We want to put the menu param on the original figure, not necessarily
    % whatever is the current figure. *MUCH* better way to do it would be
    % to allow direct placing of SoloParamHandles on indicated figures,
    % instead of it being by default always the current figure. Oh well.
    % Fix later. [CDB]
    currfig = gcf; f = get(get_ghandle(protocol_list), 'Parent');
    while ~strcmp(get(f, 'Type'), 'figure') && f~=0, f = get(f, 'Parent'); end;
    delete(protocol_list);
    
    figure(f);
    MenuParam(obj, 'protocol_list', new_prot_list, 1, p(1), p(2), 'labelfraction', 0.3); 
    set_callback(protocol_list, {mfilename, 'protocols'});
    figure(currfig);

    % In case a protocol was open and still exists, make sure protocol_list
    % reflects that:
    if any(strcmp(curr_prot_name, new_prot_list)), 
      protocol_list.value = curr_prot_name;
    end;
    
  case 'scan_protocols',
    % Get list of all protocols, defined as any object dirs within
    % the protocols dirs that don't have a corresponing "_obj.m" file in 
    % the protocols dir
    pdirs = bSettings('get', 'GENERAL', 'Protocols_Directory');
    if isempty(pdirs) || (isscalar(pdirs) && isnan(pdirs)), pdirs = './Protocols'; end;
    pdirs = textscan(pdirs, '%s', 'Delimiter', ':'); pdirs = pdirs{1};
    prot_names = [];
    for i=1:numel(pdirs),
      if exist(pdirs{i}, 'dir'),
        prot_names = [prot_names ; dir([pdirs{i} filesep '@*'])]; %#ok<AGROW>
      end;
    end;
    
    [prot_list{1:length(prot_names)}]= deal(prot_names.name);
    % remove @ head:
    for i=1:length(prot_list), prot_list{i} = prot_list{i}(2:end); end;

    % List of mfiles; append an obj to them to match the old-style object
    % names:
    prot_mfiles_dir = dir(['Protocols' filesep '*.m']);
    [prot_mfiles{1:length(prot_mfiles_dir)}]= deal(prot_mfiles_dir.name);
    for i=1:length(prot_mfiles), prot_mfiles{i} = [prot_mfiles{i}(1:end-2) 'obj']; end;
    
    % Exclude the old-style RPBox.m protocols, not compatible with
    % @dispatcher:
    prot_list = prot_list(~ismember(lower(prot_list), lower(prot_mfiles)));

    prot_list = [{''} ; prot_list(:)];
    x = prot_list;
    
    
  case 'restart_protocol',
    current_prot_name = value(protocol_list);
    dispatcher('close_protocol');
    dispatcher('set_protocol', current_prot_name);
    
  case 'get_protocol_object'
    x = value(OpenProtocolObject);
    
  case 'protocols',  % ----- DEALING WITH OPENING AND CLOSING PROTOCOLS -----
    
    if ~strcmp(protocol_list, class(OpenProtocolObject)),
      if ~isa(value(OpenProtocolObject), 'char'),
        RunningSection(obj,  'runstart_disable'); 
        try
          feval(class(value(OpenProtocolObject)), 'close');
          delete_sphandle('owner', ['^@', class(value(OpenProtocolObject)) '$']);
        catch
          le = lasterror;
          fprintf(1, '\n\n*******\n\n');
          fprintf(1, '    WARNING: Unable to complete ''close'' action on protocol\n');
          fprintf(1, '    Last error was: "%s"\n\n', le.message);
          fprintf(1, '\n\n*******\n\n');          
        end
        RunningSection(obj,  'runstart_enable');
        MachinesSection(obj, 'initialize_machines');
      end;
      
      if ~isempty(value(protocol_list)),
        RunningSection(obj,  'runstart_disable'); 
        MachinesSection(obj, 'initialize_machines');
        
        % Get an empty object just to assign ownership of vars we will create
        OpenProtocolObject.value = feval(value(protocol_list), 'empty');
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
          SoloParamHandle(obj, guys{i,1}, 'value', guys{i,2});
          % Give them to the open protocol
          set_owner(eval(guys{i,1}), value(OpenProtocolObject));
        end;
        % And amke them read-onlies of the open protocol
        DeclareGlobals(value(OpenProtocolObject), 'ro_args', guys(:,1)');

        % Now some ro and some rw for RunningSection and MachinesSection here, too:
        runners = find(cell2mat(guys(:,3))==0); machiners = find(cell2mat(guys(:,3))==1);
        SoloFunctionAddVars('RunningSection',  'func_owner', ['@' class(obj)], 'ro_args', guys(machiners,1)');
        SoloFunctionAddVars('RunningSection',  'func_owner', ['@' class(obj)], 'rw_args', guys(runners,1)');

        SoloFunctionAddVars('MachinesSection', 'func_owner', ['@' class(obj)], 'ro_args', guys(runners,1)');
        SoloFunctionAddVars('MachinesSection', 'func_owner', ['@' class(obj)], 'rw_args', guys(machiners,1)');
        
        % Ok, we're ready-- actually open the protocol:
        feval(value(protocol_list), 'init');
        
        RunningSection(obj,  'runstart_enable');
      else
        OpenProtocolObject.value = '';
      end;
    end;
    
  case 'close_protocol',  % ---- CLOSE WHATEVER PROTOCOL IS OPEN. CAN BE USED FROM COMMAND LINE
    % Block comment to disable callback (fails if a crash happened before load, as protocol_list is an ordinary struct) JS 2017
    %%{    
    pause(0.5); % <~> temporary hack to try to tease out all callbacks before unloading a protocol
    protocol_list.value = '';
    callback(protocol_list);
    %%}
  case 'set_protocol',   % --- COMMAND LINE SET PROTOCOL ---
    if nargin < 3 || ~ischar(x),
        % Changed "nargin < 3"  to "nargin<2" since on line 103, in
        % dispatcher, the obj is stripped off varargin and all the
        % varargins are shiffted 
        
      error('''set_protocol'' requires the third arg to be a protocol name');
    end;
    new_protocol = x;
    protliststrs = get(get_ghandle(protocol_list), 'String');
    if ~ismember(x, protliststrs),
      error('"%s" is not in the list of available protocols', x);
    end;
    
    % Looks like its all good: close any existing protocol and open the new one:
    feval(mfilename, obj, 'close_protocol');
    protocol_list.value = x;
    callback(protocol_list);

  case 'get_protocol_list',   % ---- GET_PROTOCOL_LIST --------------
    x = get(get_ghandle(protocol_list), 'String');

end;
