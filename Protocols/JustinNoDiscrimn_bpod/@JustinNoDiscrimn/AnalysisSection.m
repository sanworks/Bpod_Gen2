% [x, y] = AnalysisSection(obj, action, x, y)
%
% For doing online analysis of behavior.
%
%
% PARAMETERS:
% -----------
%
% obj      Default object argument.
%
% action   One of:
%            'init'      To initialise the section and set up the GUI
%                        for it;
%
%            'reinit'    Delete all of this section's GUIs and data,
%                        and reinit, at the same position on the same
%                        figure as the original section GUI was placed.
%
%            Several other actions are available (see code of this file).
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
% x        When action = 'get_next_side', x will be either 'l' for
%          left or 'r' for right.
%

function [x, y] = AnalysisSection(obj, action, x, y)

GetSoloFunctionArgs;

switch action
    
    case 'init',   % ------------ CASE INIT ----------------
        % Save the figure and the position in the figure where we are
        % going to start adding GUI elements:
        %PORTING OVER THE SIDES PLOT FROM OLD SOLO FOR COMFORT OF OLD USERS
        fnum = gcf; 
        SoloParamHandle(obj, 'my_gui_info', 'value', [x y fnum.Number]); next_row(y,1.5);
        SoloParamHandle(obj, 'ignoreMissed', 'value', 0,'type','saveable_nonui');
        
        MenuParam(obj, 'analysis_show', {'view', 'hide'}, 'view', x, y, 'label', 'Analysis', 'TooltipString', 'Online behavior analysis');next_row(y);
        MenuParam(obj, 'Ignore_missed', {'no', 'yes'}, 'no', x, y, 'label', 'MissedTrials', 'TooltipString', 'Online behavior analysis');
        set_callback(Ignore_missed,{mfilename,'missed_trials'});
        set_callback(analysis_show, {mfilename,'hide_show'});
        
        next_row(y);
        SubheaderParam(obj, 'sectiontitle', 'Analysis', x, y);next_row(y,2);
        
        parentfig_x = x; parentfig_y = y;
        % ---  Make new window for online analysis
        SoloParamHandle(obj, 'analysisfig', 'saveable', 0);
        analysisfig.value = figure('Position', [600 600 900 400], 'Menubar', 'none',...
            'Toolbar', 'none','Name','Analysis','NumberTitle','off');
        
        x = 1; y = 1;
        %jpl - dispparamms overwrite the axis?
        DispParam(obj, 'HR', 0, x, y); next_row(y);
        DispParam(obj, 'FAR', 0, x, y); next_row(y);
        DispParam(obj, 'HRMinusFAR', 0, x, y); next_row(y);
        DispParam(obj, 'Dprime', 0, x, y); next_row(y);
        DispParam(obj, 'Dprime_zcorrection', 0, x, y); next_row(y);
        next_row(y);next_row(y);
        SubheaderParam(obj, 'title', 'Go-NoGo D_prime', x, y);
        next_column(x);y=1;
        
        DispParam(obj, 'NumTrials', 0, x, y); next_row(y);
        DispParam(obj, 'NumRewards', 0, x, y); next_row(y);
        DispParam(obj, 'NumResponded', 0, x, y); next_row(y);
        DispParam(obj, 'NumMissed', 0, x, y); next_row(y);
        DispParam(obj, 'PercentCorrect', 0, x, y); next_row(y);
        DispParam(obj, 'PercentNoResp', 0, x, y); next_row(y);
        next_row(y);
        SubheaderParam(obj, 'title', 'Total', x, y);
        next_column(x);y=1;
        
        DispParam(obj, 'NumTrials_L', 0, x, y); next_row(y);
        DispParam(obj, 'NumRewards_L', 0, x, y); next_row(y);
        DispParam(obj, 'NumResponded_L', 0, x, y); next_row(y);
        DispParam(obj, 'NumMissed_L', 0, x, y); next_row(y);
        DispParam(obj, 'PercentCorrect_L', 0, x, y); next_row(y);
        DispParam(obj, 'PercentNoResp_L', 0, x, y); next_row(y);
        DispParam(obj, 'Dprime_L', 0, x, y); next_row(y);
        SubheaderParam(obj, 'title', 'Left / Go', x, y);
        
        next_column(x);y=1;
        DispParam(obj, 'NumTrials_R', 0, x, y); next_row(y);
        DispParam(obj, 'NumRewards_R', 0, x, y); next_row(y);
        DispParam(obj, 'NumResponded_R', 0, x, y); next_row(y);
        DispParam(obj, 'NumMissed_R', 0, x, y); next_row(y);
        DispParam(obj, 'PercentCorrect_R', 0, x, y); next_row(y);
        DispParam(obj, 'PercentNoResp_R', 0, x, y); next_row(y);
        DispParam(obj, 'Dprime_R', 0, x, y); next_row(y);
        SubheaderParam(obj, 'title', 'Right / NoGo', x, y);
        
        
        % display performance as a function of pole position
        pos = get(gcf, 'Position');
        
        SoloParamHandle(obj, 'myaxes_perfplot', 'saveable', 0, 'value', axes('Parent',value(analysisfig)));
        set(value(myaxes_perfplot), 'Units', 'pixels');
        set(value(myaxes_perfplot), 'Position', [90 pos(4)+80 pos(3)-100 120]);
        set(value(myaxes_perfplot), 'YTick', [0:20:100], 'YLim', [0 100], 'YTickLabel', ...
            {'0%', '20%', '40%', '60%', '80%', '100%'});
        NumeditParam(obj, 'ntrials', 100, x, y, ...
            'position', [5 pos(4)-50 40 40], 'labelpos', 'top', ...
            'TooltipString', 'How many trials to show in plot');
        set_callback(ntrials, {mfilename, 'update_plot'});
        xlabel('pole position');
        SoloParamHandle(obj, 'previous_plot_perf', 'saveable', 0);
        
        pos = get(gcf, 'Position');
        SoloParamHandle(obj, 'myaxes_sidesPlot', 'saveable', 0, 'value', axes);
        set(value(myaxes_sidesPlot), 'Units', 'pixels');
        set(value(myaxes_sidesPlot), 'Position', [90 pos(4)-150 pos(3)-100 120]);
        set(value(myaxes_sidesPlot), 'YTick', [1 2], 'YLim', [0.5 2.5], 'YTickLabel', ...
            {'Left / Go', 'Right / No-Go'});
        set_callback(ntrials, {mfilename, 'update_plot'});
        xlabel('trial number');
        
        DeclareGlobals(obj, 'ro_args', {'ignoreMissed','PercentCorrect_R','PercentCorrect_L'});
        SoloFunctionAddVars('AnalysisSection', 'rw_args', 'ignoreMissed');
        
        xlabel('trial number');
        
        SoloParamHandle(obj, 'previous_plot_sides', 'saveable', 0);
        SidesSection(obj, 'update_plot');
        
        AnalysisSection(obj,'hide_show');
        
        x = parentfig_x; y = parentfig_y;
        set(0,'CurrentFigure',value(myfig));
        %return;
        
    case 'update'
        

        % -------- plot performance as function of pole distance ---------
        %JPL - this is ported from Nuo as closely as possible for easiest compatability
        tmp= get_history('previous_positions_id');
        try
        tmp=tmp(~cellfun(@isempty,tmp)); %there is a blank for the first empty trooial
        catch
           tmp=1; 
        end
        pole_pos = tmp(1:n_completed_trials);
        trials_tmp = 1:1:n_completed_trials;
        num_pole_pos = numel(cell2mat(value(active_locations.id)));
        
        resp_perf_at_pole=(cell2mat(value(active_locations.responses))./cell2mat(value(active_locations.appearances))).*100;
        hit_perf_at_pole=(cell2mat(value(active_locations.hits))./cell2mat(value(active_locations.appearances))).*100;
        cr_perf_at_pole=(cell2mat(value(active_locations.CRs))./cell2mat(value(active_locations.appearances))).*100;
        
        if ~isempty(value(previous_plot_perf))
            delete(previous_plot_perf(:));
        end;
        
        %hb = bar(possible_pole_pos-(min(possible_pole_pos)+max(possible_pole_pos))/2, perf_at_pole, 'Parent', value(myaxes));
        %set(hb, 'Color', 'b');
        
        bar([resp_perf_at_pole;hit_perf_at_pole]','stacked', 'Parent', value(myaxes_perfplot))
        set(value(myaxes_perfplot), 'Xlim', [0 numel(active_locations.id)]);
        
        tmp=get_history('previous_sides');
        tmp=tmp(~cellfun(@isempty,tmp)); %there is a blank for the first empty trial       
        
        N_side_L = sum(strcmp(tmp(1:n_completed_trials),'left'));
        N_side_R = sum(strcmp(tmp(1:n_completed_trials),'right'));
        N_side_Go =  N_side_L;
        N_side_NoGo =  N_side_R;
        total_N  = N_side_L + N_side_R;
        
        %this is a bug fix. for first empty trial, HitHistory, etc is a nan. For
        %some reason this isnt being pushed after the first real trial to
        %history, but is fine after that. 
        
        tmpHitHist=get_history('HitHistory');
        tmpCRHist=get_history('CRHistory');
        tmpMissHist=get_history('MissHistory');
        tmpFAHist=get_history('FAHistory');
        tmpPunishHist=get_history('PunishHistory');
        tmpSampRspHist=get_history('SamplePeriodActionHistory');
        tmpRspHist=get_history('ResponseHistory');
         
         if n_completed_trials == 1
             tmpHitHist = get_value('HitHistory');
             tmpCRHist = get_value('CRHistory');
             tmpRspHist = get_value('ResponseHistory');
             tmpMissHist = get_value('MissHistory');
             tmpFAHist = get_value('FAHistory');
             tmpPunishHist = get_value('PunishHistory');
             tmpSampRspHist = get_value('SamplePeriodActionHistory');
         end
       
        N_corr_R = sum(((strcmp(tmp(1:n_completed_trials),'right'))+(tmpHitHist+tmpCRHist))>=2);
        N_corr_L = sum(((strcmp(tmp(1:n_completed_trials),'left'))+(tmpHitHist+tmpCRHist))>=2);
        N_corr_NoGo=N_corr_R;
        N_corr_Go =N_corr_L;
        total_corr = N_corr_R + N_corr_L;
        N_resp_R   =  sum((strcmp(tmp(1:n_completed_trials),'right')+tmpRspHist)==2);
        N_resp_L   = sum((strcmp(tmp(1:n_completed_trials),'left')+tmpRspHist)==2);
        N_resp_NoGo=N_resp_R ;
        N_resp_Go=N_resp_L;
        total_resp = N_resp_R + N_resp_L;
        N_noresp_R   =  sum((strcmp(tmp(1:n_completed_trials),'right')+~tmpRspHist)==2);
        N_noresp_L   = sum((strcmp(tmp(1:n_completed_trials),'left')+~tmpRspHist)==2);
        N_noresp_NoGo=N_noresp_R ;
        N_noresp_Go=N_noresp_L;
        total_noresp = N_noresp_R + N_noresp_L;
        
        num_s1 = sum(tmpHitHist) + sum(tmpMissHist);
        num_s0 = sum(tmpFAHist) + sum(tmpCRHist);
        
        if sum(tmpFAHist)==0
            far = 0;
        else
            far = sum(tmpFAHist)/num_s0;
        end
        
        if sum(tmpHitHist)==0
            hr = 0;
        else
            hr = sum(tmpHitHist)/num_s0;
        end
        
        dp = dprime(hr, far, num_s1, num_s0);
        
        %more from nuo for 2afc
        if N_side_L == 0
            dp_L = 0;
        else
            if ignoreMissed
                if N_side_L - N_noresp_L == 0
                    dp_L = 0;
                else
                    dp_L = dprime_2AFC(N_corr_L/(N_side_L-N_noresp_L),N_side_L-N_noresp_L);
                end
            else
                dp_L = dprime_2AFC (N_corr_L/N_side_L,N_side_L);
            end
        end
        if N_side_R == 0
            dp_R = 0;
        else
            if ignoreMissed
                if N_side_R - N_noresp_R == 0
                    dp_R = 0;
                else
                    dp_R = dprime_2AFC (N_corr_R/(N_side_R-N_noresp_R),N_side_R-N_noresp_R);
                end
            else
                dp_R = dprime_2AFC (N_corr_R/N_side_R,N_side_R);
            end
        end
        
        if total_N == 0
            dp = 0;
            dp_zcorrected = 0;
        else
            
            if ignoreMissed
                if N_side_L-N_noresp_L>0 && N_side_R-N_noresp_R > 0
                    dp_zcorrected = dprime_2AFC_zcorr(N_corr_R/(N_side_R-N_noresp_R),N_corr_L/(N_side_L-N_noresp_L),N_side_R-N_noresp_R,N_side_L-N_noresp_L);
                    dp            = dprime_2AFC ((N_corr_R/(N_side_R-N_noresp_R) + N_corr_L/(N_side_L-N_noresp_L))/2,N_side_R-N_noresp_R+N_side_L-N_noresp_L);
                elseif N_side_R - N_noresp_R > 0
                    dp_zcorrected = dp_R;
                    dp = dp_R;
                elseif N_side_L - N_noresp_L > 0
                    dp_zcorrected = dp_L;
                    dp = dp_L;
                else
                    dp_zcorrected = 0;
                    dp = 0;
                end
                
            else
                if N_side_L>0 && N_side_R > 0
                    dp_zcorrected = dprime_2AFC_zcorr(N_corr_R/N_side_R,N_corr_L/N_side_L,N_side_R,N_side_L);
                    dp            = dprime_2AFC ((N_corr_R/N_side_R + N_corr_L/N_side_L)/2,N_side_R+N_side_L);
                    
                elseif N_side_R > 0
                    dp_zcorrected = dp_R;
                    dp = dp_R;
                elseif N_side_L > 0
                    dp_zcorrected = dp_L;
                    dp = dp_L;
                else
                    dp_zcorrected=0;
                    dp = 0;
                end
            end
        end
        
        NumTrials.value       = total_N;
        NumRewards.value      = total_corr;
        NumResponded.value    = total_resp;
        NumMissed.value       = total_noresp;
        
        if ignoreMissed
            PercentCorrect.value  = total_corr/(total_N-total_noresp);
        else
            PercentCorrect.value  = total_corr/total_N;
        end
        PercentNoResp.value   = total_noresp/total_N;
        Dprime.value             = dp;
        Dprime_zcorrection.value = dp_zcorrected;
        
        NumTrials_L.value      = N_side_L;
        NumRewards_L.value     = N_corr_L;
        NumResponded_L.value   = N_resp_L;
        NumMissed_L.value      = N_noresp_L;
        
        if ignoreMissed
            PercentCorrect_L.value  = N_corr_L/(N_side_L-N_noresp_L);
        else
            PercentCorrect_L.value  = N_corr_L/N_side_L;
        end
        
        PercentNoResp_L.value  = N_noresp_L/N_side_L;
        Dprime_L.value         = dp_L;
        
        NumTrials_R.value      = N_side_R;
        NumRewards_R.value     = N_corr_R;
        NumResponded_R.value   = N_resp_R;
        NumMissed_R.value      = N_noresp_R;
        if ignoreMissed
            PercentCorrect_R.value  = N_corr_R/(N_side_R-N_noresp_R);
        else
            PercentCorrect_R.value  = N_corr_R/N_side_R;
        end
        
        PercentNoResp_R.value  = N_noresp_R/N_side_R;
        Dprime_R.value         = dp_R;
        
        %old gr analysis code
        PercentCorrect.value = (sum(tmpHitHist) + sum(tmpCRHist))/(n_completed_trials);
        HR.value = hr;
        FAR.value = far;
        HRMinusFAR.value = hr-far;
        Dprime.value = dp;
        
        % --------- UPDATE_PLOTs ------
        %FIRSRT OLD SIDES PLOT
        if ~isempty(value(previous_plot_sides)),
            delete(previous_plot_sides(:));
        end;
        if isempty(value(previous_sides)),
            return;
        end;
       
        tmp=get_history('previous_sides');
        tmp=tmp(~cellfun(@isempty,tmp)); %there is a blank for the first empty trial
        
        %if ~isempty(strmatch(tmp(n_completed_trials),'left')), %left is go in go-nogo language
        %    hb = line(n_started_trials-1, 1, 'Parent', value(myaxes_sidesPlot));
        %else
        %    hb = line(n_started_trials-1, 2, 'Parent', value(myaxes_sidesPlot));
        %end;
        %set(hb, 'Color', 'b', 'Marker', '.', 'LineStyle', 'none');
        
        %left ('go' of go-nogo) will be y=1, 
        ycoords_left_green=ones(n_completed_trials,1).*-1; %hits and crs
        ycoords_left_black=ones(n_completed_trials,1).*-1; %no sample respone
        ycoords_left_red=ones(n_completed_trials,1).*-1;   %fas and misses
        ycoords_left_blue=ones(n_completed_trials,1).*-1;   %no answer

        
        ycoords_left_green(sum([(strcmp(tmp(1:n_completed_trials),'left')) tmpHitHist tmpCRHist],2)>=2) = 1;
        ycoords_left_black(sum([(strcmp(tmp(1:n_completed_trials),'left')) ~tmpSampRspHist],2)>=2) = 1;
        ycoords_left_red(sum([(strcmp(tmp(1:n_completed_trials),'left')) tmpMissHist tmpFAHist],2)>=2) = 1;
        ycoords_left_blue(sum([(strcmp(tmp(1:n_completed_trials),'left')) ~tmpRspHist],2)>=2) = 1;

        %right ('nogo' of go-nogo) will be y=2, 
        ycoords_right_green=ones(n_completed_trials,1).*-1; %hits and crs
        ycoords_right_black=ones(n_completed_trials,1).*-1; %no sample respone
        ycoords_right_red=ones(n_completed_trials,1).*-1;   %fas and misses
        ycoords_right_blue=ones(n_completed_trials,1).*-1;   %no answer

        ycoords_right_green(sum([(strcmp(tmp(1:n_completed_trials),'right')) tmpHitHist tmpCRHist],2)>=2) = 2;
        ycoords_right_black(sum([(strcmp(tmp(1:n_completed_trials),'right')) ~tmpSampRspHist],2)>=2) = 2;
        ycoords_right_red(sum([(strcmp(tmp(1:n_completed_trials),'right')) tmpMissHist tmpFAHist],2)>=2) = 2;
        ycoords_right_blue(sum([(strcmp(tmp(1:n_completed_trials),'right')) ~tmpRspHist],2)>=2) = 2;
        
        
        %plot

        %blacks 
        hk = line(1:n_completed_trials, ycoords_left_black, 'Parent', value(myaxes_sidesPlot));
        set(hk, 'Color', 'k', 'Marker', '.', 'LineStyle', 'none');
        hk = line(1:n_completed_trials, ycoords_right_black, 'Parent', value(myaxes_sidesPlot));
        set(hk, 'Color', 'k', 'Marker', '.', 'LineStyle', 'none');
        
        %blue
        hb = line(1:n_completed_trials, ycoords_left_blue, 'Parent', value(myaxes_sidesPlot));
        set(hb, 'Color', 'b', 'Marker', '.', 'LineStyle', 'none');
        hb = line(1:n_completed_trials, ycoords_right_blue, 'Parent', value(myaxes_sidesPlot));
        set(hb, 'Color', 'b', 'Marker', '.', 'LineStyle', 'none');
        
        %plot greens
        hg = line(1:n_completed_trials, ycoords_left_green, 'Parent', value(myaxes_sidesPlot));
        set(hg, 'Color', 'g', 'Marker', '.', 'LineStyle', 'none');
        hg = line(1:n_completed_trials, ycoords_right_green, 'Parent', value(myaxes_sidesPlot));
        set(hg, 'Color', 'g', 'Marker', '.', 'LineStyle', 'none');
        
        %reds
        hr = line(1:n_completed_trials, ycoords_left_red, 'Parent', value(myaxes_sidesPlot));
        set(hr, 'Color', 'r', 'Marker', '.', 'LineStyle', 'none');
        hr = line(1:n_completed_trials, ycoords_right_red, 'Parent', value(myaxes_sidesPlot));
        set(hr, 'Color', 'r', 'Marker', '.', 'LineStyle', 'none');
        
       previous_plot_sides.value = [hb ; hr; hk; hg];
        
        minx = n_completed_trials - value(ntrials);
        if minx < 0,
            minx = 0;
        end;
        maxx = n_completed_trials + 2;
        if maxx <= ntrials,
            maxx = ntrials+2;
        end;
        set(value(myaxes_sidesPlot), 'Xlim', [minx, maxx]);
        drawnow;
        
    case 'hide_show'
        if strcmpi(value(analysis_show), 'hide')
            set(value(analysisfig), 'Visible', 'off');
        elseif strcmpi(value(analysis_show),'view')
            set(value(analysisfig),'Visible','on');
        end;
        return;
        
        
    case 'reinit'
        currfig = gcf;
        
        % Get the original GUI position and figure:
        x = my_gui_info(1); y = my_gui_info(2); figure(my_gui_info(3));
        
        delete(value(myaxes_sidesPlot));
        delete(value(myaxes_perfplot));
        
        % Delete all SoloParamHandles who belong to this object and whose
        % fullname starts with the name of this mfile:
        delete_sphandle('owner', ['^@' class(obj) '$'], ...
            'fullname', ['^' mfilename]);
        
        % Reinitialise at the original GUI position and figure:
        [x, y] = feval(mfilename, obj, 'init', x, y);
        
        % Restore the current figure:
        figure(currfig);
        return;
end


