% [x, y] = TrialTypeSection(obj, action, x, y)
%
% Section that takes care of choosing the next trial type and keeping
% track of a plot of sides and hit/miss history.
%
% PARAMETERS:
% -----------
%
% obj      Default object argument.
%
% action   One of:
%            'init'      To initialise the section and set up the GUI
%                        for it; also calls 'choose_next_trial_type' and
%                        'update_plot' (see below)
%
%            'reinit'    Delete all of this section's GUIs and data,
%                        and reinit, at the same position on the same
%                        figure as the original section GUI was placed.
%
%            'choose_next_trial_type'  Picks what will be the next correct
%                        side.
%
%            'get_next_trial_type'  Returns either 'l' for left or 'r' for right.
%
%            'update_plot'    Update plot that reports on sides and hit
%                        history
%
% x, y     Relevant to action = 'init'; they indicate the initial
%          position to place the GUI at, in the current figure window
%
% RETURNS:
% --------
%
% [x, y]   When action == 'init', returns x and y, pixel positions on
%          the current figure, updated after placing of this section's GUI.
%
% x        When action = 'get_next_trial_type', x will be either 'l' for
%          left or 'r' for right.
%

function [x, y] = TrialTypeSection(obj, action, x, y)

GetSoloFunctionArgs;


switch action

    case 'init',   % ------------ CASE INIT ----------------
        % Save the figure and the position in the figure where we are
        % going to start adding GUI elements:
        SoloParamHandle(obj, 'my_gui_info', 'value', [x y gcf]);

        % List of intended correct sides
        SoloParamHandle(obj, 'previous_types', 'value', []);
        SoloParamHandle(obj, 'previous_sides', 'value', []);
        SoloParamHandle(obj, 'previous_trial_types', 'value', {});

        % Give read-only access to AnalysisSection.m:
        SoloFunctionAddVars('AnalysisSection', 'ro_args', {'previous_trial_types','previous_types','previous_sides'});


        % Max number of times same side can appear
        MenuParam(obj, 'MaxSame', {'1' '2' '3' '4' '5' '6' '7' '8' '10' '15' '20' '50' 'Inf'}, ...
            '3', x, y);
        next_row(y);

        % Prob of choosing left as correct side
        MenuParam(obj, 'NoGoProb', {'0.1' '0.2' '0.3' '0.4' '0.5' '0.6' '0.7' '0.8' '0.9' '0.99' }, ...
            '0.5', x, y);
        next_row(y);


        % for the vitual pole
        NumeditParam(obj, 'WhiskerThreshLow', 1, x, y,'TooltipString',...
            'Position threshold (low) for real-time whisker detector.');
        next_row(y);
        NumeditParam(obj, 'WhiskerThreshHigh', 2, x, y,'TooltipString',...
            'Position threshold (low) for real-time whisker detector.');
        next_row(y, 1);


        % stimulation delay
        %added (10/12/11)
        MenuParam(obj, 'StimType', {'sample_period','delay_period','on_whisker_contact','mix_sample_delay'}, ...
            'sample_period', x, y);
        next_row(y);
        NumeditParam(obj, 'StimProb', 0, x, y,'TooltipString',...
            'Probability that a trial will have photostimulation.');
        next_row(y);

        SubheaderParam(obj, 'sidestitle', 'Trial type/stim settings', x, y);
        next_row(y);


        % trial selection based on animal's performance
        MenuParam(obj, 'Autolearn', {'On' 'Off' 'fixed' 'antiBias'}, ...
            'Off', x, y);
        next_row(y);

        SubheaderParam(obj, 'sidestitle', 'Left/Right trial probability', x, y);
        next_row(y);

        pos = get(gcf, 'Position');
        SoloParamHandle(obj, 'myaxes', 'saveable', 0, 'value', axes);
        set(value(myaxes), 'Units', 'pixels');
        set(value(myaxes), 'Position', [80 pos(4)-180 pos(3)-100 120]);
        set(value(myaxes), 'YTick', 1:4, 'YLim', [0.5 4.5], 'YTickLabel', ...
            {'Right', 'Left', 'Right_stim', 'Left_stim'});
        NumeditParam(obj, 'ntrials', 100, x, y, ...
            'position', [5 pos(4)-50 40 40], 'labelpos', 'top', ...
            'TooltipString', 'How many trials to show in plot');
        set_callback(ntrials, {mfilename, 'update_plot'});
        xlabel('trial number');
        SoloParamHandle(obj, 'previous_plot', 'saveable', 0);

        TrialTypeSection(obj, 'choose_next_trial_type');
        TrialTypeSection(obj, 'update_plot');


        SoloFunctionAddVars('make_and_upload_state_matrix', 'ro_args', {'WhiskerThreshLow','WhiskerThreshHigh'});

    case 'choose_next_trial_type', % --------- CASE choose_next_trial_type -----


        % next_type, previous_types  --->specifies whether stim trial or not
        % next_side, previous_sides  ---> specifices whether left or right


        switch SessionType
            
            case {'Water-Valve-Calibration','Beam-Break-Indicator','Licking',...
                    'Laser-473nm-On-Min','Laser-473nm-On-Max'},...
                next_type = 'n';
                next_side = 'r';
                next_trial_type = [next_side '_' next_type];
                
                
            case {'Discrim', 'Discrim_delay_sound', 'Discrim_delay_move_lickport'}

                % Decide randomly whether this is a stim trial:
                temp=rand(1)
                if temp <= value(StimProb)
                    next_type = 's';
                else
                    next_type = 'n';
                end


                if next_type == 's'
                    %added (10/12/11)
                    if ~isempty(strfind(value(StimType),'mix_sample_delay'))
                        selectable_period = {'sample_period','delay_period'};
                        next_trial_type = [next_type '_mix_' selectable_period{randsample(length(selectable_period),1)}];
                    else
                        next_trial_type = [next_type '_' value(StimType)];
                    end
                
                elseif next_type == 'n'
                    next_trial_type = next_type;
                end




                % Decide Left/Right
                % If MaxSame doesn't apply yet, choose at random
                if strcmp(value(Autolearn), 'On')
                    index_switch=find(previous_sides(1:n_started_trials)~=previous_sides(n_started_trials));
                    if length(index_switch) ==0
                        index_switch=0;
                    end

                    if  sum(hit_history(index_switch(end)+1:n_started_trials)) >= MaxSame
                        if previous_sides(n_started_trials)=='r', next_side = 'l'; else next_side = 'r'; end
                    else
                        next_side = previous_sides(n_started_trials);
                    end;

                elseif strcmp(value(Autolearn), 'Off')
                    if strcmp(value(MaxSame), 'Inf') | MaxSame > n_started_trials,
                        if rand(1)<=NoGoProb, next_side = 'l'; else next_side = 'r'; end;

                    else
                        % MaxSame applies, check for its rules:
                        % If there's been a string of MaxSame guys all the same, force change:
                        if all(previous_sides(n_started_trials-MaxSame+1:n_started_trials) == ...
                                previous_sides(n_started_trials))
                            if previous_sides(n_started_trials)=='l', next_side = 'r';
                            else next_side = 'l';
                            end;
                        else
                            % Haven't reached MaxSame limits yet, choose at random:
                            if rand(1)<=NoGoProb, next_side = 'l'; else next_side = 'r'; end;
                        end;
                    end
                elseif strcmp(value(Autolearn), 'fixed')    %Block of trials independent of response
                    if n_started_trials <= MaxSame
                        next_side = previous_sides(n_started_trials);
                    else
                        sides = (previous_sides(n_started_trials-MaxSame+1:n_started_trials) == 114)'; % 114 charcode for 'r', 108 for 'l'
                        if sum(sides) == MaxSame
                            next_side = 'l';
                        elseif sum(sides) == 0
                            next_side = 'r';
                        else
                            next_side = previous_sides (n_started_trials);
                        end
                    end
                elseif strcmp(value(Autolearn), 'antiBias')    %choose trial in a way to correct bias
                    %newNoGoProb = PercentCorrect_R / (PercentCorrect_L + PercentCorrect_R)
                    if( length(correct_R_history) >= 20 )   % added by ZG 9/17/11
                        %newNoGoProb = sum(correct_R_history(end-19:end)) / (sum(correct_R_history(end-19:end))+sum(correct_L_history(end-19:end)) );
                        
                        %(10/05/11 added by NL)
                        percent_R_corr = sum(correct_R_history(end-19:end)) / (sum(correct_R_history(end-19:end))+sum(correct_L_history(end-19:end)) )
                        percent_L_incorr = sum(incorrect_L_history(end-19:end)) / (sum(incorrect_R_history(end-19:end))+sum(incorrect_L_history(end-19:end)) )

                        newNoGoProb = percent_R_corr /2+percent_L_incorr /2;
                    else
                        newNoGoProb = NoGoProb;
                    end
                    value(newNoGoProb)   % added by ZG 9/17/11
                    if isnan (value(newNoGoProb))
                        newNoGoProb = NoGoProb;
                    end
                    if strcmp(value(MaxSame), 'Inf') || MaxSame > n_started_trials,
                        if rand(1)<=newNoGoProb, next_side = 'l'; else next_side = 'r'; end;

                    else

                        if all(previous_sides(n_started_trials-MaxSame+1:n_started_trials) == ...
                                previous_sides(n_started_trials))
                            if previous_sides(n_started_trials)=='l', next_side = 'r';
                            else next_side = 'l';
                            end;
                        else
                            % Haven't reached MaxSame limits yet, choose at random:
                            if rand(1)<=newNoGoProb , next_side = 'l'; else next_side = 'r'; end;
                        end;
                    end
                end
                
                % to check to make sure there is not back-to-back stim trials of the same type.  (9/21/11)
                if previous_sides(n_started_trials)==next_side && previous_types(n_started_trials)==next_type && previous_types(n_started_trials)=='s'
                    disp('----------->force change')
                    if next_side == 'l'
                        next_side = 'r';
                    else
                        next_side = 'l';
                    end
                end
                
                next_trial_type = [next_side '_' next_trial_type];
                
        end
        previous_types(n_started_trials+1) = next_type;
        previous_sides(n_started_trials+1) = next_side;
        previous_trial_types{n_started_trials+1} = next_trial_type;

        disp(['Next trial type: ' next_trial_type]);


    case 'get_next_trial_type'   % --------- CASE get_next_trial_type ------
        if isempty(previous_trial_types),
            error('Don''t have next trial type chosen! Did you run choose_next_side?');
        end;
        x = previous_trial_types{length(previous_trial_types)};
        return;


    case 'get_next_stim_type'   % --------- CASE get_next_trial_type ------
        if isempty(previous_types),
            error('Don''t have next stim type chosen! Did you run choose_next_side?');
        end;
        x = previous_types(length(previous_types));
        return;


    case 'get_next_side'   % --------- CASE get_next_trial_type ------
        if isempty(previous_sides),
            error('Don''t have next side chosen! Did you run choose_next_side?');
        end;
        x = previous_sides(length(previous_sides));
        return;


    case 'update_plot'     % --------- UPDATE_PLOT ------


        if ~isempty(value(previous_plot)), delete(previous_plot(:)); end;
        if isempty(previous_trial_types), return; end;

        ps_sides = value(previous_sides);
        ps_types = value(previous_types);
        if      ps_sides(end)=='l' && ps_types(end)=='s'
            hb = line(length(previous_sides), 4, 'Parent', value(myaxes));
        elseif  ps_sides(end)=='r' && ps_types(end)=='s'
            hb = line(length(previous_sides), 3, 'Parent', value(myaxes));
        elseif  ps_sides(end)=='l' && ps_types(end)=='n'
            hb = line(length(previous_sides), 2, 'Parent', value(myaxes));
        elseif  ps_sides(end)=='r' && ps_types(end)=='n'
            hb = line(length(previous_sides), 1, 'Parent', value(myaxes));
        end
        set(hb, 'Color', 'b', 'Marker', '.', 'LineStyle', 'none');

        xgreen = find(hit_history); %all the 1s
        lefts_s  = find(previous_sides(xgreen) == 'l' & previous_types(xgreen) == 's');
        rghts_s  = find(previous_sides(xgreen) == 'r' & previous_types(xgreen) == 's');
        lefts_n  = find(previous_sides(xgreen) == 'l' & previous_types(xgreen) == 'n');
        rghts_n  = find(previous_sides(xgreen) == 'r' & previous_types(xgreen) == 'n');
        ygreen = zeros(size(xgreen)); ygreen(lefts_s) = 4; ygreen(rghts_s) = 3; ygreen(lefts_n) = 2; ygreen(rghts_n) = 1;
        hg = line(xgreen, ygreen, 'Parent', value(myaxes));
        set(hg, 'Color', 'g', 'Marker', '.', 'LineStyle', 'none');

        xred  = find(incorrect_R_history + incorrect_L_history); %no response
        lefts_s = find(previous_sides(xred) == 'l' & previous_types(xred) == 's');
        rghts_s = find(previous_sides(xred) == 'r' & previous_types(xred) == 's');
        lefts_n = find(previous_sides(xred) == 'l' & previous_types(xred) == 'n');
        rghts_n = find(previous_sides(xred) == 'r' & previous_types(xred) == 'n');
        yred = zeros(size(xred)); yred(lefts_s) = 4; yred(rghts_s) = 3; yred(lefts_n) = 2; yred(rghts_n) = 1;
        hr = line(xred, yred, 'Parent', value(myaxes));
        set(hr, 'Color', 'r', 'Marker', '.', 'LineStyle', 'none');

        xmag  = find(noresponse_R_history + noresponse_L_history); %no response
        lefts_s = find(previous_sides(xmag) == 'l' & previous_types(xmag) == 's');
        rghts_s = find(previous_sides(xmag) == 'r' & previous_types(xmag) == 's');
        lefts_n = find(previous_sides(xmag) == 'l' & previous_types(xmag) == 'n');
        rghts_n = find(previous_sides(xmag) == 'r' & previous_types(xmag) == 'n');
        ymag = zeros(size(xmag)); ymag(lefts_s) = 4; ymag(rghts_s) = 3; ymag(lefts_n) = 2; ymag(rghts_n) = 1;
        hm= line(xmag, ymag, 'Parent', value(myaxes));
        set(hm, 'Color', [0.5 0.5 0.5], 'Marker', 'x', 'LineStyle', 'none');


        previous_plot.value = [hb ; hr; hg; hm];

        minx = n_done_trials - ntrials; if minx < 0, minx = 0; end;
        maxx = n_done_trials + 2; if maxx <= ntrials, maxx = ntrials+2; end;
        set(value(myaxes), 'Xlim', [minx, maxx]);
        drawnow;




    case 'reinit',   % ------- CASE REINIT -------------
        currfig = gcf;

        % Get the original GUI position and figure:
        x = my_gui_info(1); y = my_gui_info(2); figure(my_gui_info(3));

        delete(value(myaxes));

        % Delete all SoloParamHandles who belong to this object and whose
        % fullname starts with the name of this mfile:
        delete_sphandle('owner', ['^@' class(obj) '$'], ...
            'fullname', ['^' mfilename]);

        % Reinitialise at the original GUI position and figure:
        [x, y] = feval(mfilename, obj, 'init', x, y);

        % Restore the current figure:
        figure(currfig);
end;


