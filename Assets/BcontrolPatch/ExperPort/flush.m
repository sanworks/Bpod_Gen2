EndBpod;
delete(get(0,'Children'));
hndls_to_delete = findobj(findall(0));
for ctr = 1:length(hndls_to_delete)
    try
        delete(hndls_to_delete(ctr));
    catch %#ok<CTCH>
    end
end
% delete(timerfindall); % Commented to make this work with new MATLAB
close all;
clear all;
clear classes;
clear functions;

%% Close all existing open serial objects
objlist = instrfind;
for ctr = 1:length(objlist)
    try
        fclose(objlist(ctr));
    catch %#ok<CTCH>
    end
    try
        delete(objlist(ctr));
    catch %#ok<CTCH>
    end
end

clear all;

