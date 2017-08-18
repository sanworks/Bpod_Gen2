% Typical section code-- this file may be used as a template to be added 
% on to. The code below stores the current figure and initial position when
% the action is 'init'; and, upon 'reinit', deletes all SoloParamHandles 
% belonging to this section, then calls 'init' at the proper GUI position 
% again.


% [x, y] = YOUR_SECTION_NAME(obj, action, x, y)
%
% Section that takes care of YOUR HELP DESCRIPTION
%
% PARAMETERS:
% -----------
%
% obj      Default object argument.
%
% action   One of:
%            'init'      To initialise the section and set up the GUI
%                        for it
%
%            'reinit'    Delete all of this section's GUIs and data,
%                        and reinit, at the same position on the same
%                        figure as the original section GUI was placed.
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


function [x, y] = SidesSection(obj, action, x, y)
   
GetSoloFunctionArgs;

switch action
  case 'init',
    % Save the figure and the position in the figure where we are
    % going to start adding GUI elements:
    SoloParamHandle(obj, 'my_gui_info', 'value', [x y gcf]);

    % Max times same side can appear
    NumeditParam(obj, 'MaxWithout', Inf, x, y, 'TooltipString', ...
      sprintf(['\nIf this many trials elapse without a particular stim type being chosen,' ...
      '\nit becomes the obligatory next stim.' ...
      '\nNote that MaxSame rule trumps MaxWithout rule.'])); next_row(y);
    MenuParam(obj, 'MaxSame', {'1', '2', '3', '4', '5', '6', '7', 'Inf'}, 3, ...
        x, y, 'TooltipString', 'Maximum number of times the same side (L or R) can appear');
    next_row(y);
    DispParam(obj, 'ThisPair', 1, x, y, ...
        'TooltipString', 'The id of the stimulus pair being presented for this trial; same as what apppears in StimulusSection');
    next_row(y);
    
    DispParam(obj, 'ThisTrial', 'LEFT', x, y); next_row(y);
    SoloParamHandle(obj, 'previous_sides', 'value', 'l');
    SoloParamHandle(obj, 'previous_pairs', 'value', 1);
    SubheaderParam(obj, 'title', 'Sides Section', x, y);
    next_row(y, 1.5);
    
    % plot of side choices history at top of window
    pos = get(gcf, 'Position');
    SoloParamHandle(obj, 'myaxes', 'saveable', 0, 'value', axes);
    set(value(myaxes), 'Units', 'pixels');
    set(value(myaxes), 'Position', [90 pos(4)-140 pos(3)-130 100]);
    set(value(myaxes), 'YTick', [1 2], 'YLim', [0.5 2.5]);
    NumeditParam(obj, 'ntrials', 20, x, y, ...
                   'position', [pos(3)-100 pos(4)-170 60 20],...
                   'TooltipString', 'How many trials to show in plot');
    set_callback(ntrials, {mfilename, 'update_plot'});    
    set_callback_on_load(ntrials, 1);  % callback for ntrials will always be executed when loading data
    ToggleParam(obj, 'SortBySides', 0, x, y, 'position', [pos(3)-220 pos(4)-180 100 20], ...
      'OnString', 'Order by sides', 'OffString', 'Orig order', ...
      'TooltipString', sprintf(['\nOrder y axis by original stimulus number or sort ' ...
      '\nstimulus stypes first by left/right']));
    set_callback(SortBySides, {mfilename, 'update_plot'});    
    ToggleParam(obj, 'LeftRightOnly', 0, x, y, 'position', [pos(3)-320 pos(4)-180 100 20], ...
      'OnString', 'L/R only', 'OffString', 'stim type', ...
      'TooltipString', sprintf('\nShow all stim types separately or show sort only by L/R'));
    set_callback(LeftRightOnly, {mfilename, 'update_plot'});    

    xlabel('trial number');
    SoloParamHandle(obj, 'previous_plot', 'saveable', 0);
    %feval(mfilename, obj, 'update_plot');
    
    SoloFunctionAddVars('AntibiasSection', 'ro_args', ...
          {'previous_sides'; 'previous_pairs'});

        
% -----------------------------------------------------------------------
%
%         NEXT_TRIAL
%
% -----------------------------------------------------------------------

  case 'next_trial',
    if ~value(go_flg),
        warning('EXTENDEDSTIMULUS:SidesSection', 'Defined sounds are not valid; check message and sounds panel!');
        return;
    end;
    
    
    choiceprobs = AntibiasSection(obj, 'get_posterior_probs');    
    nstimuli = length(choiceprobs);
    
    
    % Check for MaxSame rules if it applies
    if ~strcmpi(value(MaxSame), 'inf') && MaxSame <= n_started_trials,
      % if there's been a string of MaxSame guys all the same, force change
      if all(previous_sides(n_started_trials-MaxSame+1:n_started_trials) == ...
          previous_sides(n_started_trials)), %#ok<NODEF>
        if previous_sides(n_started_trials) == 'l',
          AntibiasSection(obj, 'update_biashitfrac', 'r');
       else
          AntibiasSection(obj, 'update_biashitfrac', 'l');
        end;
        choiceprobs = AntibiasSection(obj, 'get_posterior_probs');
      end;
    end;
    % Check for MaxWithout rules if it applies
    if MaxWithout~=Inf
      max_without_set = []; % This'll be the set of stim type to which rule applies
      for i=1:nstimuli,
        u = find(previous_pairs==i, 1, 'last'); %#ok<NODEF>
        % If it's never been used, it is as if its last use was trial zero:
        if isempty(u), u=0; end;
        % If prior for this stim type isn't zero, and we've gone MaxWithout
        % trials without it, it belongs in the to-be-chosen set:
        if choiceprobs(i) > 0  &&  n_started_trials-u >= MaxWithout,
          max_without_set = [max_without_set i]; %#ok<AGROW>
        end;
      end;
      % If no trial has gone MaxWithout without being used, no rule to enforce:
      if ~isempty(max_without_set)
        % but if there are trial types in the max_without_set, choose only from those.
        set_to_zero = setdiff(1:nstimuli, max_without_set);
        choiceprobs(set_to_zero) = 0;
        choiceprobs = choiceprobs/sum(choiceprobs);
      end;      
    end;
    
    choice_cdf = to_cdf(choiceprobs);
    r = find(choice_cdf > rand(1));
    ThisPair.value = r(1);

    s = StimulusSection(obj, 'get', value(ThisPair), 'side');
    if n_done_trials == 0,
        previous_sides.value = s;
        previous_pairs.value = value(ThisPair);
    elseif n_done_trials > 0,
        previous_sides.value = [previous_sides(:); s];
        previous_pairs.value = [previous_pairs(:); value(ThisPair)]; %#ok<NODEF>
    end

    if strcmp(s, 'l'),
        ThisTrial.value = 'LEFT';
    else
        ThisTrial.value = 'RIGHT';
    end;

% -----------------------------------------------------------------------
%
%         GET_PREVIOUS_SIDES
%
% -----------------------------------------------------------------------

  case 'get_previous_sides', 
    x = value(previous_sides); %#ok<NODEF>

    
% -----------------------------------------------------------------------
%
%         GET_CURRENT_SIDE
%
% -----------------------------------------------------------------------

  case 'get_current_side',
    if strcmp(ThisTrial, 'LEFT'), x = 'l'; %#ok<NODEF>
    else                          x = 'r';
    end;
    
% -----------------------------------------------------------------------
%
%         GET_CURRENT_PAIR
%
% -----------------------------------------------------------------------

  case 'get_current_pair',
    x = value(ThisPair); %#ok<NODEF>

% -----------------------------------------------------------------------
%
%         MAKE_AND_SEND_SUMMARY
%
% -----------------------------------------------------------------------

  case 'make_and_send_summary',
      pd.hits  = value(hit_history);
      pd.pairs = value(previous_pairs);            pd.pairs = pd.pairs(1:length(hit_history));
      Frequencies = get_sphandle('name', 'Frequencies');  % from StimulusSection
      pd.freqs = get_history(Frequencies{1});      pd.freqs = cell2mat(pd.freqs(1:length(hit_history)));
      Durations = get_sphandle('name', 'Durations');  % also from StimulusSection
      pd.durs = get_history(Durations{1});         pd.durs = cell2mat(pd.durs(1:length(hit_history)));
      sides_history = value(previous_sides);
      sides_history = sides_history(1:length(hit_history));
      pd.sides = sides_history;
      sendsummary(obj, 'sides', sides_history, 'protocol_data', pd);

% -----------------------------------------------------------------------
%
%         UPDATE_PLOT
%
% -----------------------------------------------------------------------

  case 'update_plot',
    if ~isempty(value(previous_plot)), delete(previous_plot(:)); end; %#ok<NODEF>
    if isempty(previous_sides), return; end; %#ok<NODEF>

    pp = value(previous_pairs); %#ok<NODEF>
    nstims = StimulusSection(obj, 'get', 'nstims');
    if isempty(nstims), return; end;

    sides = {StimulusSection(obj, 'get', 'all_sides')};
    if nstims==0
        sidemap = 1:1;  % j=sidemap(i) => stimulus number i goes to row j in plot
    else
       sidemap = 1:nstims;  % j=sidemap(i) => stimulus number i goes to row j in plot
    end
    if SortBySides==1,
      [trash, trash2] = sort(sides); 
      [trash, sidemap] = sort(trash2); % j=sidemap(i) => stimulus number i goes to row j in plot
    end;
    if LeftRightOnly==1,
      for i=1:nstims,
        if sides{i}=='l', sidemap(i) = 2; else sidemap(i) = 1; end;
      end;
    end;
    
    hb = line(length(pp), sidemap(pp(end)), 'Parent', value(myaxes));
    set(hb, 'Color', 'b', 'Marker', '.', 'LineStyle', 'none');
    
    xgreen = find(hit_history);
    xred   = find(~hit_history);
    ygreen = zeros(size(xgreen));
    yred   = zeros(size(xred));
    for i = 1:nstims,
        i_green = find(pp(xgreen) == i);
        ygreen(i_green) = sidemap(i); %#ok<FNDSB>
        i_red = find(pp(xred) == i);
        yred(i_red) = sidemap(i); %#ok<FNDSB>
    end;
    
    hg = line(xgreen, ygreen, 'Parent', value(myaxes));
    set(hg, 'Color', 'g', 'Marker', '.', 'LineStyle', 'none');
    hr = line(xred, yred, 'Parent', value(myaxes));
    set(hr, 'Color', 'r', 'Marker', '.', 'LineStyle', 'none');
    
    previous_plot.value = [hb; hr; hg];
          
    minx = 0;
    maxx = n_done_trials + 2; if maxx <= ntrials, maxx = ntrials+2; end;
    set(value(myaxes), 'XLim', [minx, maxx]);
    set(value(myaxes), 'YLim', [0.5 max(sidemap)+0.5], 'YGrid', 'on');
    nrows = length(unique(sidemap));
    ticks = cell(nrows, 1);
    for i = 1:nstims,
        f1_frq = StimulusSection(obj, 'get', i, 'f1_frq');
        f2_frq = StimulusSection(obj, 'get', i, 'f2_frq');
        if LeftRightOnly==0,
          ticks{sidemap(i)} = [sides{i} ', ' sprintf('[%.3g %.3g]', f1_frq, f2_frq)];
        else
          if sides{i}=='l', ticks{sidemap(i)} = 'LEFT'; else ticks{sidemap(i)} = 'RIGHT'; end;
        end;
    end
    set(value(myaxes), 'YTick', 1:nrows, ...
        'YTickLabel', ticks, ...
        'YLim', [0.5 nrows+0.5]);
    %set(value(myaxes), 'YLabel', 'sound pairs');
    drawnow;
      
% -----------------------------------------------------------------------
%
%         REINIT
%
% -----------------------------------------------------------------------

  case 'reinit',
    currfig = gcf;
    
    % Get the original GUI position and figure:
    x = my_gui_info(1); y = my_gui_info(2); figure(my_gui_info(3));

    % Delete all SoloParamHandles who belong to this object and whose
    % fullname starts with the name of this mfile:
    delete_sphandle('owner', ['^@' class(obj) '$'], ...
      'fullname', ['^' mfilename]);

    % Reinitialise at the original GUI position and figure:
    [x, y] = feval(mfilename, obj, 'init', x, y);

    % Restore the current figure:
    figure(currfig);
end;

function [x] = to_cdf(x)
    if isempty(x), return; end;
    for i=2:length(x),
        x(i) = x(i-1)+x(i);
    end;
    

