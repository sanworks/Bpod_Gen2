function bpodMeta = getBpodSoftwareMetadata()
% bpodMeta = getBpodMetadata
% Find information about the current 
% 
% Returns
% -------
% bpodMeta : struct
%   A struct containing information about the current Bpod software
%   With fields:
%       semanticversion : str
%           The semantic version of the Bpod software
%       BpodFilepath : str
%           The path to the Bpod software
%       gitInfo : struct, empty if not .git folder is found
%           A struct containing information about the git repository

bpodMeta = struct;
bpodMeta.semanticversion = BpodSoftwareVersion_Semantic;
bpodMeta.BpodFilepath = functions(@Bpod).file;

bpodgen2folder = fileparts(bpodMeta.BpodFilepath);
gitInfo = BpodLib.util.getGitInfo(fullfile(bpodgen2folder, '.git'));
if ~isempty(gitInfo)
    bpodMeta.gitInfo = gitInfo;
else
    bpodMeta.gitInfo = [];
end
end