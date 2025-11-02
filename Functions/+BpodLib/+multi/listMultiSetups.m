function setupList = listMultiSetups(configDir)
% List all multi setups available.
% setupList = listMultiSetups(configDir)
%
% Arguments
% ---------
% configDir : char
%     Path to the Config/ directory containing multi setup folders (or not).
%
% Returns
% -------
% setupList : cell array of char
%     List of multi setup names found in the configDir. Is empty if no multi setups are found.

filelist = dir(fullfile(configDir, 'Machine-*'));

setupList = strcat({filelist.name}');

end