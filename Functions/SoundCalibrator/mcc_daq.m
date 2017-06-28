function [data] = mcc_daq(varargin)

options = struct('n_scan',1,'freq',1000,'n_chan',16,'range', 10);

optionNames = fieldnames(options);

nArgs = length(varargin);
if round(nArgs/2)~=nArgs/2
    error('need propertyName/propertyValue pairs')
end

for pair = reshape(varargin,2,[])
    
    inpName = lower(pair{1});
    
    if any(strcmp(inpName,optionNames))
        options.(inpName) = pair{2};
    else
        error('%s is not a recognized parameter name',inpName)
    end
end

%./read-usb1608G n_chan n_scan range freq
[status,cmdout] = system(['./read-usb1608G ' num2str(options.n_chan) ' ' num2str(options.n_scan) ' ' num2str(options.range) ' ' num2str(options.freq)]);
d = sscanf(cmdout,'%f');

try
    data = reshape(d,options.n_chan,options.n_scan);
catch ME
    disp('ERROR')
    disp(cmdout)
end


