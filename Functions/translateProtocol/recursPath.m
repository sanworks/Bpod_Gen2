%%Recursive Path Explorer Function
%   Returns struct with fields similar to fields 'name' and 'isdir' from 'dir'
%   Args:
%       1) directory name: must be cell with full-path string to a directory
%       
%       2) options structure with fields:
%               'debug':      logical, run debug func to check output against bash
%               'include_wc': cell array, wildcards to dir contents to include

%Justin Little, 2016

function [names,isdir]=recursPath(varargin)
%% check input argsm num args, and parse

%option defaults
debug=false;
include_wc=[];

if numel(varargin)==0
    error('recursPath::dirErr', 'must provide at least one input, a directory')
elseif numel(varargin)==1
    directory=varargin{1};
    if ~strcmp(directory(end),filesep)
        directory=[directory filesep];
    end
elseif numel(varargin)==2 && isstruct(varargin{2})
    %parse
    directory=varargin{1};
    if ~strcmp(directory(end),filesep)
        directory=[directory filesep];
    end
    opt_in_fields=fields(varargin{2});
    for i=1:numel(opt_in_fields)
        switch opt_in_fields{i}
            case 'debug'
                debug=varargin{2}.(opt_in_fields{i});
            case 'include_wc'
                 include_wc=varargin{2}.(opt_in_fields{i});
            otherwise
                display(['recursPath:: unknown option "' sprintf('%s',opt_in_fields{i}) '". Ignoring']);
        end
                
       %checks on options
       if ~islogical(debug)
           warning('recursPath:: "debug" option must be logical or convertible to logical. Setting to 0')
       end
       if ~iscell(include_wc)
           try
               exclude_wc={exclude_wc};
           catch 
                warning('recursPath::wildcards must be cell arrays or convertible to cell arrays. Setting to {''}')
           end
       end
    end
elseif numel(varargin)>=3
    error('recursPath:: too many inputs')
end

%is directory a cell?
if ~iscell(directory)
    %convert to cell if possible
    if ischar(directory)
        directory={directory};
    else
        error('recursPath:: input must be a cell or convertible to cell')
    end
end

%is directory on path?
if ~exist(directory{1})
    try %cd there (and back after finished)
        start_dir=pwd;
        cd(directory{1})
    catch
        error('recursPath:: cannot find directory')
    end
end
%%

%make sure the output persistent var is cleared
if exist('memlist')
    clear memlist;
end

%generate file/directory structure
[directory,strout]=getSubdirs(directory,include_wc);

%if we had to cd to dir, go back
if exist('start_dir')
    cd(start_dir)
end

%debug?
if debug
    display('                              ')
    display('..............................')
    display('Done crawling. Hit any key to debug (optional) and display results')
    pause
    
    debugCrawler(directory,strout)
    display('                              ')
    char(strout.names)
end

names={strout.names};
isdir=cellfun(@(x) logical(x),{strout.isdir});

clear memlist
end

%% getSubdirs
%main recursive function, returning subdirs and file contents of the current dir
function [directory,str]=getSubdirs(directory,iwcs)

%var for results
persistent memlist;

for g=1:1:numel(directory)
    
    tmp_struct=[];
    
    %get directory contents, with filters applied
    dir_contents=returnDirContents(directory{g},iwcs);
    
    %check for trailing slash
    if directory{g}(end)~=filesep
        directory=[directory filesep];
    end
    
    %formatting
    fullpath_names=cellfun(@(x) [directory{g} x filesep],{dir_contents.name}, 'UniformOutput',false);
    fullpath_dir_names=fullpath_names(cell2mat({dir_contents.isdir}));
    
    %get subdirectories
    getSubdirs(fullpath_dir_names,iwcs);
    
    %push data into a temporary struct
    tmp_struct.names=directory{g};
    tmp_struct.isdir=1;
    if ~isempty('fullpath_names') 
        for i=1:numel(fullpath_names)
            tmp_struct(i+1).names=fullpath_names{i};
            tmp_struct(i+1).isdir=dir_contents(i).isdir;
        end
    end
    
    %merge temporarary struct into memlist
    if ~isempty(memlist)
        memlist=[memlist,tmp_struct];
    else
        memlist=tmp_struct;
    end
    [~,ix]=unique({memlist.names});
    memlist=memlist(ix);
end
%output assignment
str=memlist;

%cd back to orig pwd if necessary
if exist('start_dir')
    cd(start_dir)
end
end

%% returnDirContents
%helper function for returning directory contents, with filters from user
function [dir_contents]=returnDirContents(directory,iwcs)

dir_contents=dir(directory);

%chuck '.' dirs ALWAYS, and hidden files (osX)
bad_idx=strcmp({dir_contents.name},'.') + ...
    strcmp({dir_contents.name},'..')   + ...
    strcmp({dir_contents.name},['.' filesep]);

%apply user wc filters
reject_idxs=[];
if ~isempty(iwcs)
    for i=1:1:numel(iwcs)
        %wcs passes as *-type, but using strfind, so remove *
        if ~isempty(strfind(iwcs{i},'*'))
            iwcs{i}(strfind(iwcs{i},'*'))=[];
        end
        dir_idxs=cell2mat({dir_contents.isdir}); %preserve dirs from being iltered
        %apply file filter
        keepfile_idxs=cellfun(@(x) ~isempty(x), strfind({dir_contents.name},iwcs{i}));
        
        tmp=[bad_idx | ~dir_idxs];
        tmp(keepfile_idxs)=0;
        reject_idxs = [reject_idsx | tmp];
        
    end
else
    reject_idxs=bad_idx;
end

dir_contents(find(reject_idxs))=[];

end

%% debugCrawler
%test fucntion that compares results to a known good result via bash
function debugCrawler(directory,strout)

%generate ground-truth comparison with bash
if strcmp(pwd,directory)
    [~,gt]=system('find "$PWD"');
else
    try
        [~,gt]=system(['find "$' directory '"']);
    catch
        %where are we? just cd
        curdir=pwd;
        cd(directory{1})
        [~,gt]=system('find "$PWD"');
        cd(curdir);
    end
end

%compare bash result to recursive result.\
%slow, but with some reformating of char(strout.name) could use a diff
%script
notfind_idx=[]; %no real use for this now, but keep it for future
for i=1:1:numel(strout)
    if strout(i).names(end)==filesep
        strout(i).names(end)=[];
    end
    sstart=findstr(gt,strout(i).names);
    if ~isempty(sstart)
        gt(sstart:sstart+numel(strout(i).names))=[];
    else
        %keep the index case we want to do something with that
        notfind_idx=[notfind_idx i];
    end
end

%print remaining text from bash string returned from system
display(sprintf('Text not found by Recursive Path Explorer: %s',gt))
end
