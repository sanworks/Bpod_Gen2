% check an mfile for compatibilty with current version of matlab
% assumes that any mfile coming from a solo/bcontrol directory has a main
% switch statement controlling function behavior, via the second argument
function isgood=checkFileCompat(obj,fullpath, version)

isgood=1;

%known issues:

% 1) old version of matlab had gcf return a double. now returns a graphics 
%    handle. solution, replace 'gcf' with 'get(gcf,'Number')'

% 2) reserved word lists have changed. So far, the known list of new 
%    words includes: 'table', 'message'

%% fix gcf errors, if necessary
[~,fname,~]=fileparts(fullpath);
data = textread(fullpath,'%s','delimiter','\n','whitespace','');
switchLine = find(cell2mat(cellfun(@(x) ~isempty(strfind(x,'switch')),...
    data,'UniformOutput', false)));

if isempty(switchLine)
    warning('translateProtocol::checkFileCompat: no switch statement found in mfile, cannot profile')
    isgood=0;
    return;
end

switchLine=switchLine(1); %first one should control behavior

caseLines = find(cell2mat(cellfun(@(x) ~isempty(strfind(x,'case')),...
    data,'UniformOutput', false)));

for g=1:1:numel(caseLines)
    beginn=regexp(data{caseLines(g)},[char(39) '\w']);
    endd=regexp(data{caseLines(g)},['\w' char(39)]);
    cases{g}=data{caseLines(g)}(beginn+1:endd);
    
    errors=1;
    keyboard
    while errors==1;
        %run mfile with
        feval(fname,obj,cases{g})
        exception = MException.last;
        
    end
end

