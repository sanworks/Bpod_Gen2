function R = preprocessEmbC(C,touch_thresh,lick_thresh,whiskvel_thresh,whiskang_thresh,...
            pre_pole_delay,resonance_delay,answer_delay,delay_period,sample_period,...
            answer_period,drink_period,mean_window_length,median_window_length,baseline_length,...
            log_analog_freq,valve_time,rew_cue,go_cue,fail_cue,pole_cue,answerAction,sampleAction,sampend_mode,...
            sampfail,sampdlyfail,ansfail,ansdlyfail,nxtside,nxttype,time_out_time,init_hold_time,...
            punish_on,actionXr,rewXr,stim_epoch) 
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
find_pattern = 'double touch_thresh = XXX'; % This is the default, currently in the C program.
replace_pattern = ['double touch_thresh = ' sprintf('%0.5f',touch_thresh)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------

find_pattern = 'double lick_thresh = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double lick_thresh = ' sprintf('%0.5f',lick_thresh)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];

%----------------
%----------------

find_pattern = 'double whiskvel_thresh = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double whiskvel_thresh = ' sprintf('%0.5f',whiskvel_thresh)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];

%----------------
%----------------

find_pattern = 'double whiskang_thresh = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double whiskang_thresh = ' sprintf('%0.5f',whiskang_thresh)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];

%----------------
%----------------
find_pattern = 'double pre_pole_delay = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double pre_pole_delay = ' sprintf('%0.5f',pre_pole_delay)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'double resonance_delay = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double resonance_delay = ' sprintf('%0.5f',resonance_delay)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'double answer_delay = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double answer_delay = ' sprintf('%0.5f',answer_delay)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'double delay_period = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double delay_period = ' sprintf('%0.5f',delay_period)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'double sample_period = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double sample_period = ' sprintf('%0.5f',sample_period)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'double answer_period = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double answer_period = ' sprintf('%0.5f',answer_period)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'double drink_period = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double drink_period = ' sprintf('%0.5f',drink_period)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'double vVect1[XXX]'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double vVect1[' num2str(mean_window_length) ']'];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];

%----------------
%----------------
find_pattern = 'double tmpMeanVect[XXX]'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double tmpMeanVect[' num2str(mean_window_length+median_window_length-1) ']'];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'double tmpMedianVect[XXX]'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double tmpMedianVect[' num2str(median_window_length) ']'];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'double valve_time = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double valve_time = ' sprintf('%0.5f',valve_time)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'int go_cue = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['int go_cue = ' num2str(go_cue)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'int fail_cue = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['int fail_cue = ' num2str(fail_cue)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'int pole_cue = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['int pole_cue = ' num2str(pole_cue)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'int rew_cue = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['int rew_cue = ' num2str(rew_cue)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'char *answer_mode = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['char *answer_mode  = ' '"' [eval('answerAction') '"' ]];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'char *response_mode = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['char *response_mode  = ' '"' [eval('sampleAction') '"' ]];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'char *sampend_mode = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['char *sampend_mode  = ' '"' [eval('sampend_mode') '"' ]];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'char *dlyfail = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['char *dlyfail  = ' '"' [eval('sampdlyfail') '"' ]];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'char *rspfail = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['char *rspfail  = ' '"' [eval('ansfail') '"' ]];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'char *rspdlyfail = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['char *rspdlyfail  = ' '"' [eval('ansdlyfail') '"' ]];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'char *sampfail = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['char *sampfail  = ' '"' [eval('sampfail') '"' ]];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'char *nxtside = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['char *nxtside  = ' '"' [eval('nxtside') '"' ]];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'int nxttype = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['int nxttype = ' sprintf('%0.0f',nxttype)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------

find_pattern = 'int time_out_time = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['int time_out_time = ' sprintf('%0.0f',time_out_time)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------

find_pattern = 'int punish_on = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['int punish_on = ' num2str(punish_on)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'double actionXr = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double actionXr = ' num2str(actionXr)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'double rewXr = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double rewXr = ' num2str(rewXr)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------
find_pattern = 'double stim_epoch = XXX'; % This is the default, currently in the C program.
% 'XXX' is not defined and will error absent this preprocessing.
replace_pattern = ['double stim_epoch = ' num2str(stim_epoch)];
ind = strfind(R,find_pattern);
if isempty(ind)
    error(['preprocessEmbC:: cannot find string' find_pattern ' in the embedC file!'])
end
pre = R(1:(ind-1));
post = R((ind+length(find_pattern)):end);
R = [pre replace_pattern post];
%----------------
%----------------