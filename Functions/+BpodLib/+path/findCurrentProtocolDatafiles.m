function fileStructure = findCurrentProtocolDatafiles(BpodSystem)
% fileStructure = findCurrentProtocolDatafiles(BpodSystem)
% Returns the structure of the files in the folder where the data is being saved
%
% Inputs
% ------
% BpodSystem : BpodObject
%
% Outputs
% -------
% fileStructure : struct
%     The structure of the files (from dir()) in the folder where the data is being saved

[savefolder, ~, ~] = fileparts(BpodSystem.Path.CurrentDataFile); % name of the .mat file being saved to

fileStructure = dir(fullfile(savefolder, '*.mat'));

end