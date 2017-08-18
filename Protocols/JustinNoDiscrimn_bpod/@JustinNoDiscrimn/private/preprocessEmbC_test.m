function R = preprocessEmbC_test(C,touch_thresh_low,touch_thresh_high,states_to_log_touch)
%
% INPUTS:
%   C: An embedded C program as a string.
%   stim_trial: A boolean indicating whether stimulations should be enabled
%               in returned program.
%
% RETURNS:
%
%   R: A preprocessed C program suitable for use as an argument to 
%       @RTLSM/SetStateProgram.m
%
% DHO, 7/10.
%

R = C;

%----------------
find_pattern = 'double touch_thresh_low = XXX'; % This is the default, currently in the C program.
                                                      % 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double touch_thresh_low = ' sprintf('%0.1f',touch_thresh_low)];
ind = strfind(R,find_pattern);
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];

%----------------
find_pattern = 'double touch_thresh_high = XXX'; % This is the default, currently in the C program.
                                                      % 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double touch_thresh_high = ' sprintf('%0.1f',touch_thresh_high)];
ind = strfind(R,find_pattern);
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];


%----------------
find_pattern = 'static unsigned states_to_log_touch[XXX]'; % This is the default, currently in the C program.
                                                      % 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['static unsigned states_to_log_touch[' int2str(length(states_to_log_touch)) ']'];
ind = strfind(R,find_pattern);
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];

%----------------
find_pattern = '{XXX}'; % This is the default, currently in the C program.
                        % 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = int2str(states_to_log_touch);
replace_pattern(findstr(replace_pattern,'  '))=',';
replace_pattern(findstr(replace_pattern,' '))=[];
replace_pattern=['{', replace_pattern, '}'];
ind = strfind(R,find_pattern);
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];

