% @ExtendedStimulus/AntibiasSection.m

% [x, y] = AntibiasSection(obj, action, [arg1], [arg2], [arg3])    
% This is a generalization of the Antibias plugin to an arbitrary number of
% choices

% Bing, Oct. 2007

function [x, y, w, h] = AntibiasSection(obj, action, varargin)
   
GetSoloFunctionArgs(obj);
   
switch action
    
  case 'init',   % ------------ CASE INIT ----------------
    x = varargin{1}; y = varargin{2}; y0 = y;
    % Save the figure and the position in the figure where we are
    % going to start adding GUI elements:
    SoloParamHandle(obj, 'my_gui_info', 'value', [x y gcf]);

    LogsliderParam(obj, 'HitFracTau', 30, 10, 400, x, y, 'label', 'hits frac tau', ...
      'TooltipString', ...
      sprintf(['\nnumber of trials back over which to compute fraction of correct trials.\n' ...
      'This is just for displaying info-- for the bias calculation, see BiasTau above']));
    set_callback(HitFracTau, {mfilename, 'update_hitfrac'});
    next_row(y);
    DispParam(obj, 'LtHitFrac', 0, x, y); next_row(y);
    DispParam(obj, 'RtHitFrac', 0, x, y); next_row(y);
    DispParam(obj, 'HitFrac',   0, x, y); next_row(y);
    
    next_row(y, 0.5);
    LogsliderParam(obj, 'BiasTau', 30, 10, 400, x, y, 'label', 'antibias tau', ...
      'TooltipString', ...
      sprintf(['\nnumber of trials back over\nwhich to compute fraction of correct trials\n' ...
      'for the antibias function.'])); next_row(y);
    NumeditParam(obj, 'Beta', 0, x, y, ...
      'TooltipString', ...
      sprintf(['When this is 0, past performance doesn''t affect choice\n' ...
      'of next trial. When this is large, the next trial is ' ...
      'almost guaranteed\nto be the one with smallest %% correct'])); next_row(y);
    set_callback({BiasTau, Beta}, {mfilename, 'update_biashitfrac'});
    SoloParamHandle(obj, 'BiasHitFrac', 'value', []);
    SoloParamHandle(obj, 'ChoicesProb', 'value', []);
    
    SoloParamHandle(obj, 'LocalLeftProb',   'value', 0.5);
    SoloParamHandle(obj, 'LocalHitHistory', 'value', []);
    SoloParamHandle(obj, 'LocalPrevSides',  'value', []);

    
    SubheaderParam(obj, 'title', mfilename, x, y);
    next_row(y, 1.5);

    w = gui_position('get_width');
    h = y-y0;
    
    
  case 'update',    % --- CASE UPDATE -------------------
    feval(mfilename, obj, 'update_hitfrac');
    feval(mfilename, obj, 'update_biashitfrac');
    
    
   
  case 'update_biashitfrac',     % ------- CASE UPDATE_BIASHITFRAC -------------   
    if isempty(stims), return; end;
    
    % if varargin{1} is 'l' or 'r', then compute choices among those sound
    % pairs that are 'l' or 'r' by setting the prior probabilities of the
    % choices on the other side to 0.
    if nargin > 2, set_side = varargin{1}; 
    else           set_side = '';
    end;
    
    %JPL
    if iscell(stims)
        PriProb = cell2mat(stims(:,5));
        Sides = cell2mat(stims(:,1));
    else
        PriProb = stims(:,5);
        Sides = stims(:,1);
    end
    
    if strcmp(set_side, 'l') || strcmp(set_side, 'r'),
        sc = (Sides == set_side);
        PriProb = PriProb .* sc;
    end;
    hit_history = colvec(value(hit_history));
    PrevPairs = value(previous_pairs);
    
    % at the beginning of the day, when there aren't very many done trials,
    % antibias can come to quickly and incorrectly prefer the stims the rat
    % happened to have gotten wrong in the first few trials.  one hacky way to
    % fix this is to pad the hit_history with extra 1's in front when 
    % n_done_trials < BiasTau
    if n_done_trials < BiasTau,
        pad = int16(BiasTau - n_done_trials);
        hit_history = [ones(pad, 1); hit_history];
        BiasHitFrac.value = ones(1,rows(stims));
        kernel = exp(-(0:length(hit_history)-1)/BiasTau)';
        kernel = kernel(end:-1:1);
        try
            PrevPairs = PrevPairs(1:n_done_trials)';
        catch
            PrevPairs = [];
        end;
        for k = 1:rows(stims),
            pad_PrevPairs = [k*ones(1,pad) PrevPairs];
            khit = find(pad_PrevPairs == k);
            if isempty(khit), BiasHitFrac(k) = 1;
            else              BiasHitFrac(k) = sum(hit_history(khit).*kernel(khit))/sum(kernel(khit));
            end;
        end;
    else  % business as usual
        BiasHitFrac.value = ones(1,rows(stims));

        kernel = exp(-(0:length(hit_history)-1)/BiasTau)';
        kernel = kernel(end:-1:1);

        try
            PrevPairs = PrevPairs(1:length(hit_history))';
        catch
            PrevPairs = [];
        end;

        for k = 1:rows(stims),
            khit = find(PrevPairs == k);
            if isempty(khit), BiasHitFrac(k) = 1;
            else              BiasHitFrac(k) = sum(hit_history(khit).*kernel(khit))/sum(kernel(khit));
            end;
        end;
    end;
    
    choices = probabilistic_trial_selector(value(BiasHitFrac), PriProb', value(Beta));
    ChoicesProb.value = choices;
    push_history(ChoicesProb);

  case 'get_posterior_probs',      % ------- CASE GET_POSTERIOR_PROBS -------------
    x = value(ChoicesProb); 
    
  case 'get_biashitfrac'  % ------- CASE GET_HITFRAC ----------------
    % returns a row vector where every entry is the weighted hitfrac for a
    % particular stimulus pair, as indexed in StimulusSection
    x = value(BiasHitFrac);  
  
  case 'update_hitfrac',     % ------- CASE UPDATE_HITFRAC -------------
    hit_history = colvec(value(hit_history));
    prevs = value(previous_sides); 
    
    if length(hit_history)>0, 
      kernel = exp(-(0:length(hit_history)-1)/HitFracTau)';
      kernel = kernel(end:-1:1);
      HitFrac.value = sum(hit_history .* kernel)/sum(kernel);
    
      if ~isempty(prevs),
          prevs = prevs(1:length(hit_history))';
      end;
      u = find(prevs == 'l');
      if isempty(u), LtHitFrac.value = NaN;
      else           LtHitFrac.value = sum(hit_history(u) .* kernel(u))/sum(kernel(u));
      end;
        
      u = find(prevs == 'r');
      if isempty(u), RtHitFrac.value = NaN;
      else           RtHitFrac.value = sum(hit_history(u) .* kernel(u))/sum(kernel(u));
      end;
    end;
    
            
  case 'reinit',   % ------- CASE REINIT -------------
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
   
   
      

function [x] = colvec(x)
    if size(x,2) > size(x,1), x = x'; end;
    return;

function [x] = to_cdf(x)
    if length(x) < 2, return; end;
    for i = 2:length(x),
        x(i) = x(i) + x(i-1);
    end;
    return;
