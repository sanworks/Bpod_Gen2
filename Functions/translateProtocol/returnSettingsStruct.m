function [structSO] = returnSettingsStruct(setfile)
commentcharacter                = '%';
delimiter                       = [';' commentcharacter];
reserved_names            = ['all', 'none'];
nametoken       = ['%[^ \b\t\n' delimiter ']'];
formatstring    = [nametoken ' ' nametoken ' %s'];

%     Read the group/name/value tokens into three vectors.
[setting_groups setting_names setting_values] = ...
    textread(setfile                   ...
    ,    formatstring                           ...
    ,    'commentstyle',     'matlab'           ...
    ,    'delimiter',        delimiter          ...
    );

structSO=struct('settings',[]);
j=1;
while j <= length(setting_names),
    groupname       = strtrim(setting_groups{j});
    settingname     = strtrim(setting_names{j});
    settingvalue    = strtrim(setting_values{j});
    settingvalueNum = str2double(settingvalue);
    if ~isnan(settingvalueNum) || strcmpi(settingvalue,'NaN'),
        settingvalue = settingvalueNum;
    end;
    
    if ~isfield(structSO.settings,groupname),
        structSO.settings.(groupname) = struct;
    end;
    
    structSO.settings.(groupname).(settingname) = settingvalue;
    
    j = j + 1;
end;
