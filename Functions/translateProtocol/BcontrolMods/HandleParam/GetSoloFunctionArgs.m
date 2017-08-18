function [arglist] = GetSoloFunctionArgs(varargin)
%
% Instantiates, in the caller's workspace, all the SoloParamHandles
% that have been previously registered for the caller function's owner
% and the caller function's function name. Also instantiates any
% globals declared for the function's owner; globals are assigned
% first, so local variables assigned through GetSoloFunctionArgs will
% override global variables of the same name.
%
% If the first argument is an object, then the class of that object is
% interpreted as the 'func_owner' argument. Further optional arguments are
% allowed (including 'func_owner', in which case the latter will override
% the first arg). Thus, the following two are equivalent:
%
%    >> GetSoloFunctionArgs('func_owner', ['@' class(obj)]);
%    >> GetSoloFunctionArgs(obj);
%
%
% SoloParamHandles that were registered as READ-WRITE for this
% owner/funcion combination will be instantiated as SoloParamHandles.
%
% SoloParamHandles that were registered as READ-ONLY for this
% owner/function combination will be instantiated as their value, and
% the name of the variable, with '_history' appended, will be
% instantiated as the history of the SoloParamHandle. By getting only the
% value, not the SoloParamHandle itself, the caller will not be able to
% write a new value to that SoloParamHandle.
%
%
% EXAMPLE:  'bloop' and 'dweeb' have been registered as read-write and
% read-only SoloParamHandles for @myprotocol/foobar.m. They currently
% have values 10 and 34, respectively. If foobar.m calls
% GetSoloFunctionArgs, a variable called 'bloop' will be
% instantiated within foobar.m's workspace. It will be a
% SoloParamHandle, and changing its value will change the value that
% every other function with access to 'bloop' sees. In contrast, a
% variable called 'dweeb' will also be instantiated, but this one will
% simply be a double, with value 34, not a SoloParamHandle, and
% changing its value will affect no other functions.
%
% OPTIONAL PARAMS:
% ----------------
%
% 'arg_list'      This is not the name of a standard (paramname, paramvalue)
%                 If GetSoloFunctionArgs.m is called with first parameter
%                 'arglist', ** it then expects to have exactly three
%                 parameters in its call, the second being func_owner, and
%                 the third being func_name. In this case, the function
%                 instantiates nothing but instead has a single return
%                 value, a cell vector list containing the names of all
%                 vars that would have been instantiated if called in
%                 normal mode. The list doesn't distinguish between
%                 read/write and read-only variables.
%
% func_name       The full name of the function that is asking for
%                 SoloParamHandles. Defaults to the result of calling
%                 determine_fullfuncname.m.
%
% func_owner      Id identifying the owner of the SoloParamHandles that
%                 will be instantiated in the caller's workspace. This
%                 defaults to the result of determine_owner.m
%
% all_read_only   Default is 'off'; if this param is set to 'on', then
%                 all variables resulting from this call are treated as
%                 read_only, regardless of whether they were registered
%                 as read-write or read-only.
%
% name            By default, empty. If non-empty, must be a string. Only
%                 the SoloParamHandles whose name starts with the passed
%                 string are instantiated.

% If the first thing passed in is an object, then use that as the owner
% otherwise try to 'determine_owner'
if nargin>0 && isobject(varargin{1}),
    default_owner = ['@' class(varargin{1})]; varargin = varargin(2:end);
else
    default_owner = determine_owner;
end;

% if the first things passed in is the string 'arglist' then pass back
% the list of variables for that function.

if ~isempty(varargin) && ischar(varargin{1}) && ...
        strcmp(varargin{1}, 'arglist'),
    % Just want the list of arguments, no variable assignment
    if length(varargin)~=3,
        error('when called with ''arglist'', there must be 3 args total');
    end;
    get_arglist = 1;
    func_owner = varargin{2};
    func_name  = varargin{3};
else
    % Normal operation, will do variable assignments.
    get_arglist = 0;
    pairs = { ...
        'func_name'       determine_fullfuncname   ; ...
        'func_owner'      default_owner            ; ...
        'all_read_only'   'off'                    ; ...
        'name'            ''				          	   ; ...
        }; parseargs(varargin, pairs);
end;

global BpodSystem
%JPL - this needs to assighnin some individual vars from .settings! like
%the dio stuff, machine stuf
%assignin bpod global var
assignin('caller','BpodSystem', BpodSystem)

global private_solofunction_list
% private_solofunction_list is a cell array with three columns. The
% first column contains owner ids. Each row is unique. For each row
% with an owner id, the second column contains a cell array that
% corresponds to the set of function names that are registered for that
% owner. The third row contains the globals declared for that owner.

% First find the list of functions registered to func_owner:
if isempty(private_solofunction_list)
    return;
else
    mod = find(strcmp(func_owner, private_solofunction_list(:,1)));
end;
if isempty(mod)
    return;
end;

% Get the global arguments for this func_owner
global_rw_args = private_solofunction_list{mod,3}{1};
global_ro_args = private_solofunction_list{mod,3}{2};

% Now find the func_name within the list of functions:
funclist = private_solofunction_list{mod, 2};
if isempty(funclist)
    return;
else
    fun = find(strcmp(func_name, funclist(:,1)));
end;

% Each funclist is a cell array with three columns. The first column
% contains function names; each row is unique. For each row, the
% second column contains a cell column vector of read/write args;
% the third column contains a cell column vector of read-only args.
if ~isempty(fun),
    rw_args = funclist{fun,2};
    ro_args = funclist{fun,3};
else
    rw_args = cell(0,2);
    ro_args = cell(0,2);
end;

% ---- IF WANT ONLY ARGLIST, GET IT NOW AND EXIT
if get_arglist,
    arglist = {};
    if ~isempty(global_rw_args), arglist=           global_rw_args(:,1); end;
    if ~isempty(global_ro_args), arglist=[arglist ; global_ro_args(:,1)];end;
    if ~isempty(rw_args),        arglist=[arglist ; rw_args(:,1)]; end;
    if ~isempty(ro_args),        arglist=[arglist ; ro_args(:,1)]; end;
    arglist = unique(arglist);
    return;
end;
% -------------------------------


% Now find the specific variables that we want within the list of variables:
if ~isempty(rw_args) && ~isempty(name)
    rw_arg_cidx=strfind(rw_args(:,1),name);
    rw_arg_idx=zeros(size(rw_arg_cidx));
    
    for dx=1:numel(rw_arg_idx)
        rw_arg_idx(dx)=~isempty(rw_arg_cidx{dx});
    end
    
    rw_args=rw_args(rw_arg_idx==1,:);
    
    %if isempty(funclist), return;
end;

if ~isempty(ro_args) && ~isempty(name)
    ro_arg_cidx=strfind(ro_args(:,1),name);
    ro_arg_idx=zeros(size(ro_arg_cidx));
    
    for dx=1:numel(ro_arg_idx)
        ro_arg_idx(dx)=~isempty(ro_arg_cidx{dx});
    end
    ro_args=ro_args(ro_arg_idx==1,:);
    %if isempty(funclist), return;
end;

% DO EVERY ASSIGN TWICE: FIRST FOR GLOBALS, THEN REGULARS:

% ---- globals first : -------
% If we're getting everything in read-only mode, then pile 'em all
% into the read-only list:
if strcmp('all_read_only', 'on'),
    global_ro_args = [global_rw_args ; global_ro_args];
    global_rw_args = {};
end;

for i=1:size(global_rw_args,1),
    if is_validhandle(global_rw_args{i,2}),
        assignin('caller', global_rw_args{i,1}, global_rw_args{i,2});
    end;
end;

for i=1:size(global_ro_args,1),
    if ~isa(global_ro_args{i,2}, 'SoloParamHandle')
        assignin('caller', global_ro_args{i,1}, global_ro_args{i,2});
    else
        if is_validhandle(global_ro_args{i,2}),
            assignin('caller', global_ro_args{i,1}, ...
                value(global_ro_args{i,2}));
            assignin('caller',[global_ro_args{i,1} '_history'], ...
                get_history(global_ro_args{i,2}));
        end;
    end;
end;


% ---- now regular vars : -------
% If we're getting everything in read-only mode, then pile 'em all
% into the read-only list:
if strcmp('all_read_only', 'on'),
    ro_args = [rw_args ; ro_args];
    rw_args = {};
end;

for i=1:size(rw_args,1),
    if is_validhandle(rw_args{i,2}),
        assignin('caller', rw_args{i,1}, rw_args{i,2});
    end;
end;

for i=1:size(ro_args,1),
    if ~isa(ro_args{i,2}, 'SoloParamHandle')
        assignin('caller', ro_args{i,1}, ro_args{i,2});
    else
        if is_validhandle(ro_args{i,2}),
            assignin('caller', ro_args{i,1}, value(ro_args{i,2}));
            assignin('caller',[ro_args{i,1} '_history'], ...
                get_history(ro_args{i,2}));
        end;
    end;
end;


