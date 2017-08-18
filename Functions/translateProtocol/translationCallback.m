function translationCallback%(sph)

global BpodSystem

sph = get(gcbo, 'UserData'); %JPL - sph for us is just the listpos number

% This gets called from the GUI. Thus, at this point in programming, the
% GUI handle has simply generated the callback; the internal
% paramater is still unchanged. This function should sync up the internal
% parameter to whatever the GUI says.

%pairs = { ...
%%    'internal_cbk', 0 ;
%    };
%parse_knownargs(varargin, pairs);

global private_soloparam_list;

switch get_type(sph),
    case 'edit',
        private_soloparam_list{sph}.value = get(get_ghandle(sph), 'String');
        
    case 'textbox',
        private_soloparam_list{sph}.value = get(get_ghandle(sph), 'String');
        
    case 'numedit',
        [d, c ,err] = sscanf(get(get_ghandle(sph), 'String'),'%g',[1 inf]);
        if ~isempty(err)
            d=nan;
        end
        if isnan(d),
            private_soloparam_list{sph}.value = value(sph);
        else
            private_soloparam_list{sph}.value = d;
        end;
        
    case 'disp', return;
        
    case 'menubar',
        
    case 'menu',
        menulist = get(get_ghandle(sph), 'String');
        private_soloparam_list{sph}.value = ...
            menulist{get(get_ghandle(sph), 'Value')};
    
    case 'popupmenu'
        menulist = get(get_ghandle(sph), 'String');
        private_soloparam_list{sph}.value = ...
            menulist{get(get_ghandle(sph), 'Value')};
        
    case 'listbox',
        boxlist = get(get_ghandle(sph), 'String');
        private_soloparam_list{sph}.value = ...
            get(get_ghandle(sph), 'Value');
        
    case 'pushbutton',
        
    case 'radiobutton',
        private_soloparam_list{sph}.value = get(get_ghandle(sph), 'String');
    case 'solotoggler',
        if ~internal_cbk,
            currval = value(private_soloparam_list{sph});
            if currval, private_soloparam_list{sph}.value = 0;
            else        private_soloparam_list{sph}.value = 1;
            end;
        end;
        
    case 'slider',
        private_soloparam_list{sph}.value = get(get_ghandle(sph), 'Value');
        
    case 'logslider',
        gval  = get(get_ghandle(sph), 'Value');
        mmin  = get(get_ghandle(sph), 'Min');
        mmax  = get(get_ghandle(sph), 'Max');
        % Interpret GUI as a number linearly scaled in graphics between 0
        % and 1:
        gval = (gval - mmin)/(mmax - mmin);
        
        % Now turn it into log scale.
        private_soloparam_list{sph}.value = mmin*exp(gval*log(mmax/mmin));
        
    case 'saveable_nonui',
        % do nothing
    case '',
        % Not a GUI: may not have any callbacks associated with it and
        % therefore we return and do nothing.
        return;
        
    otherwise,
        error(['Don''t know how to deal with type ' get_type(sph)]);
end;

% If owned by object:
%   (a) check to see if 'callback' property is not empty; if so,
%       calls that function, with an embty obj as param
%   (b) elseif, a function with the name of the SoloParam exists,
%       calls that, with empty obj as param
%   (c) else does nothing.
%
% Elseif, if not owned by an object -- not defined yet
%
owner = get_owner(sph);
if ~isempty(owner), % Are we owned (i.e., by an object)?
    %cbck = get_callback(private_soloparam_list{sph});
    
    cbck = BpodSystem.ProtocolTranslation.callbacks{sph};
    if ~all(cellfun(@(x) isempty(x),cbck.mfiles)) %if there are no callbacks, dont bother
        if owner(1) == '@'  &&  ...
                (~isempty(cbck) || ...
                exist([owner filesep get_name(sph) '.m'], 'file')),
            
            % Ok, there is a callback fn to be called; try to make empty object
            try
                %obj = feval(owner(2:end),  'empty');
            catch
                fprintf(2, ['When a SoloParamHandle is owned by an object, ' ...
                    'that object must allow constuction with a single '...
                    ' (''empty'') argument\n']);
                rethrow(lasterror)
            end;
            
            % We have an object!
            objname=owner(2:end); %name of object, but dont instantiate. We want this
            %to work without relying on Solo classes or
            %any functions outside the ported protocol
            
            handle_callbacks(objname,owner,get_name(sph),cbck);
            %JPL - old cold
            %parse_and_call_sph_callback(obj, owner, get_name(sph), cbck)
        end;
    end;
end
end

function type=get_type(sph)
global private_soloparam_list;
for b=1:1:numel(private_soloparam_list)
    if private_soloparam_list{b}.listpos==sph
        type=private_soloparam_list{b}.ghandle.Style;
        return
    end
end

end

function ghandle=get_ghandle(sph)
global private_soloparam_list;
for b=1:1:numel(private_soloparam_list)
    if private_soloparam_list{b}.listpos==sph
        ghandle=private_soloparam_list{b}.ghandle;
        return
    end
end

end

function callback=get_callback(sph)
global private_soloparam_list;
global BpodSystem;
callbacks=BpodSystem.ProtocolTranslation.callbacks;
for b=1:1:numel(private_soloparam_list)
    if private_soloparam_list{b}.listpos==sph.listpos
        callback=callbacks{b};
        return
    end
end

end

function owner=get_owner(sph)
global private_soloparam_list;
for b=1:1:numel(private_soloparam_list)
    if private_soloparam_list{b}.listpos==sph
        owner=private_soloparam_list{b}.param_owner;
        return
    end
end

end

function name=get_name(sph)
global private_soloparam_list;
for b=1:1:numel(private_soloparam_list)
    if private_soloparam_list{b}.listpos==sph
        name=private_soloparam_list{b}.param_name;
        return
    end
end

end

function [] = handle_callbacks(obj,owner, sph_name, cbck)
%JPL - duplicates the functionality of 'parse_and_call_sph_callback'
if ~isempty(cbck),
    % We're going to call the functions in sequence.
    if ischar(cbck), 
        cbck = {cbck}; 
    end;
    for i=1:size(cbck,1),
        if  size(cbck,2)==1,
            feval(cbck.mfiles{i,1},[],cbck.methods{i,1});
        elseif size(cbck,2)==2,
            feval(cbck.mfiles{i,2},[],cbck.methods{i,2});
        else
            %JPL - i have no idea when this would ever be called, so expect
            %errors if it is
            if strcmp(cbck.mfiles{i,2}, 'super')  % use fn of superclass, not owner's
                super = get_sphandle('name', 'super', 'owner', owner);
                super = super{1};
                feval(cbck.mfiles{i,1}, value(super), cbck.methods{i,3:end});
            elseif strcmp(cbck{i,2}, 'obj')
                feval(cbck.mfiles{i,1}, [], cbck.methods{i,3:end});
            else
                
                feval(cbck.mfiles{i,1}, obj, cbck.methdods{i,2:end});
            end;
        end;
    end;
    
elseif exist([owner filesep sph_name '.m'], 'file'),
    % Empty callback -- check to see whether a function exists,
    % and if so, call it.
    feval(sph_name, obj);
end;

end

