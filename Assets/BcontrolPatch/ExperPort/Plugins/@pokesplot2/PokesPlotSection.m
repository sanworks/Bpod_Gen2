function varargout = PokesPlotSection(obj, action, varargin)
%POKESPLOTSECTION: Primary routine for the pokesplot2 plugin
%
%   PokesPlotSection is the primary routine that would be called to access
%   all the features of pokesplot2. It is an upgrade from the pokesplot
%   plugin, and has been completely rewritten to incorporate the ability to
%   display scheduled waves, enable the use of wildcards in the Main Sort
%   section, Sub Sort section, Trial Selector section, and alignon section,
%   and to allow the user to differentiate between entities on the axes by
%   displaying information from the cursor's position. In addition, a few
%   minor new features exist, including interactive zooming in and out on
%   the plot, zooming to a rectangular region of interest, and panning.
%
%   A complete list of features will be available at:
%   http://brodylab.princeton.edu/bcontrol/index.php/Plugins:pokesplot2
%
%   SYNTAX:
%   VARARGOUT = POKESPLOTSECTION(OBJ, ACTION, VARARGIN)
%
%   OBJ: Protocol object
%
%   ACTION: Action string
%
%   Examples:
%
%   [x, y] = PokesPlotSection(obj, 'init', x, y): Initialization step, called from
%   your protocol's 'init' section. It places the button to show/hide the
%   PokesPlotSection window on the protocol window at the x and y
%   coordinates passed, and initializes the PokePlot2 GUI and the PokesPlot
%   Preferences Pane GUI. The protocol uses the function files
%   state_colors.m, poke_colors.m, wave_colors.m, and spike_color to set
%   the colors of the states, pokes, waves, and spikes that are to be
%   displayed. If poke_colors.m and spike_color.m are not specified,
%   default values for poke colors and the spike color are used. Also
%   returns the x and y values passed (for backwards compatibility).
%
%   PokesPlotSection(obj, 'init', x, y, state_colors): Deprecated, but here
%   for backwards compatbility. The state_colors structure can be passed
%   directly along with the init call to PokesPlotSection.
%
%   PokesPlotSection(obj, 'update'): Placed in your protocols update
%   section. When placed here, the PokesPlotSection axes will update
%   themselves continuously while your protocol's training session is
%   running.
%
%   PokesPlotSection(obj, 'redraw'): This action clears the axes, the
%   legend panel, and the preferences pane, and reinitializes all three
%   aforementioned entities. The same action can be accomplished by
%   pressing the 'Redraw' button on the PokesPlotSection GUI.
%
%   PokesPlotSection(obj, 'trial_completed'): Here for backwards
%   compatbility, but completely unused in this version.
%
%   PokesPlotSection(obj, 'set_alignon', <alignon value>, <parsing style>): Sets the align
%   time for every trial. The <parsing style argument is optional, and
%   defaults to 'v1 Style Parsing' if not specified. It can be either 'v1
%   Style Parsing' or 'v2 Style Parsing'. If specified as 'v2 Style
%   Parsing', PokePlot2 uses the new parsing style specified in the
%   documentation for eval_pokesplot_expression.m.
%
%   PokesPlotSection(obj, 'close'): Placed in the protocol's 'close'
%   section.

%%

try
    %Nothing that happens in the PokesPlotSection file should affect the
    %rest of the protocol
    
    %GetSoloFunctionArgs(obj)
    GetSoloFunctionArgs(obj);
    
    if ~exist('n_started_trials', 'var')
        n_started_trials = 0;
    end
    
    switch action
        %% CASE init
        case 'init'
            %e.g. PokesPlotSection(obj, 'init', x, y)
            %e.g. PokesPlotSection(obj, 'init', x, y, state_colors)
            
            %Intial Step: Close existing windows if necessary
            feval(mfilename, obj, 'close');
            
            %Step 1: Validation
            if nargin<4 || nargin>5
                error('Invalid number of number of arguments. The number of arguments has to be either 4 or 5.');
            elseif ~isobject(obj)
                error('The first argument has to be the protocol object');
            elseif ~isscalar(varargin{1}) || ~isscalar(varargin{2})
                error('The third and fourth arguments have to be scalars');
            elseif nargin==5 && ~isstruct(varargin{3})
                error('The fifth argument, if present, has to be a valid structure.');
            end
            
            
            x = varargin{1};
            y = varargin{2};
            varargout{1} = x;
            varargout{2} = y;
            if nargin==5
                scolors = varargin{3};
                if isfield(scolors, 'states')
                    scolors = scolors.states;
                end
            elseif ismethod(obj, 'state_colors')
                scolors = state_colors(obj);
            elseif exist('STATE_COLORS', 'var')
                
                if isa(STATE_COLORS, 'SoloParamHandle')
                    scolors = value(STATE_COLORS);
                else
                    scolors = STATE_COLORS;
                end
                
            else
                scolors = struct([]);
            end
            if ismethod(obj, 'wave_colors')
                wcolors = wave_colors(obj);
            elseif exist('WAVE_COLORS', 'var')
                if isa(WAVE_COLORS, 'SoloParamHandle')
                    wcolors = value(WAVE_COLORS);
                else
                    wcolors = WAVE_COLORS;
                end
            else
                wcolors = struct([]);
            end
            if ismethod(obj, 'poke_colors')
                pcolors = poke_colors(obj);
            elseif exist('POKE_COLORS', 'var') && isa(POKE_COLORS, 'SoloParamHandle')
                pcolors = value(POKE_COLORS);
            else
                pcolors = default_poke_colors;
            end
            
            
            %SoloParamHandle definitions
            if isa(obj, 'neurobrowser')
                temp = neurobrowser('get_info');
                temp.settings_file = '';
            elseif any(strcmp('SavingSection', methods(obj,'-full')))
                temp = SavingSection(obj, 'get_all_info');
            end
            
            %SESSION_INFO contains information about the experimenter,
            %ratname, settings_file, and protocol name, and keeps track of
            %these items throughout.
            SoloParamHandle(obj, 'SESSION_INFO', 'value', struct('experimenter', temp.experimenter, 'ratname', temp.ratname, 'settings_file', temp.settings_file, 'protocol', class(obj)));
            
            %I_am_PokesPlotSection: This SoloParamHandle is used by
            %neurobrowser to identify the presence of the PokesPlot window
            SoloParamHandle(obj, ['I_am_' mfilename], 'value', '', 'saveable', true);
            
            SoloParamHandle(obj, 'my_xyfig', 'value', [x y gcf]);
            if ~exist('PokesPlotShow', 'var') || ~isa(PokesPlotShow, 'SoloParamHandle')
                ToggleParam(obj, 'PokesPlotShow', 0, x, y, 'OnString', 'PokesPlot showing', ...
                    'OffString', 'PokesPlot hidden', 'TooltipString', 'Show/Hide Pokes Plot window'); next_row(y);
                set_callback(PokesPlotShow, {mfilename, 'show_hide'});
            end
            SoloParamHandle(obj, 'myfig', 'value', figure('CloseRequestFcn', [mfilename '(' class(obj) ', ''hide'');'], 'MenuBar', 'none', 'Name', mfilename, 'Units', 'normalized'), 'saveable', false);
            HeaderParam(obj, 'textHeader', [mfilename '(' SESSION_INFO.experimenter ', ' SESSION_INFO.ratname ')'], 1, 1);
            HeaderParam(obj, 'textXLimits', 'X Limits: ', 1, 1);
            HeaderParam(obj, 'textto', 'to', 1, 1);
            HeaderParam(obj, 'textto2', 'to', 1, 1);
            HeaderParam(obj, 'textYValuesToShow', 'Y-values to show: ', 1, 1);
            HeaderParam(obj, 'textClickingOnPlot', 'Clicking on plot: ', 1, 1);
            HeaderParam(obj, 'textalignon', 'Align On: ', 1, 1);
            
            %IMRECT is the imrect object created by the imrect function,
            %used by toggleInteractiveZoomRectangle.
            SoloParamHandle(obj, 'IMRECT', 'value', [], 'saveable', false);
            
            %PANOBJ is the graphics.pan object, created by
            %toggleInteractivePan
            SoloParamHandle(obj, 'PANOBJ', 'value', [], 'saveable', false);
            
            %TRIAL_SEQUENCE is the actual sequence of trials which are to
            %be shown on the PokesPlot axes. By default, it is set to
            %1:n_started_trials, but it can be rearranged by the MainSort
            %and SubSort sections in the preferences pane.
            SoloParamHandle(obj, 'TRIAL_SEQUENCE', 'value', [], 'saveable', false);
            
            %PROTOCOL_DATA contains the protocol_data variable obtained
            %from the sessions table
            SoloParamHandle(obj, 'PROTOCOL_DATA', 'value', get_protocol_data(obj), 'saveable', false);
            
            ToggleParam(obj, 'btnRedraw', false, 1, 1, 'OnString', 'Redraw', 'OffString', 'Redraw');
            set_saveable(btnRedraw, false);
            set_callback(btnRedraw, {mfilename, 'btnRedrawCallback'});
            set_callback_on_load(btnRedraw, true);
            
            if ~exist('btnShowHideLegendPanel', 'var') || ~isa(btnShowHideLegendPanel, 'SoloParamHandle')
                ToggleParam(obj, 'btnShowHideLegendPanel', false, 1, 1, 'OnString', '', 'OffString', '');
                set_callback(btnShowHideLegendPanel, {mfilename, 'btnShowHideLegendPanelCallback'});
            end
            
            EditParam(obj, 'editCurrentEntity', '', 1, 1);
            set(get_ghandle(editCurrentEntity), 'FontName', 'Times', 'FontWeight', 'normal', 'FontSize', 10.0);
            delete(get_lhandle(editCurrentEntity));
            
            if ~exist('alignon', 'var') || ~isa(alignon, 'SoloParamHandle')
                EditParam(obj, 'alignon', 'state_0(1, end)', 1, 1);
            end
            
            if ~exist('popupParsingStyle', 'var') || ~isa(popupParsingStyle, 'SoloParamHandle')
                MenuParam(obj, 'popupParsingStyle', {'v1 Style Parsing', 'v2 Style Parsing'}, 'v1 Style Parsing', 1, 1);
                set_callback(popupParsingStyle, {mfilename, 'popupParsingStyleCallback'});
            end
            set_callback(alignon, {mfilename, 'alignon_callback'});
            set_callback_on_load(alignon, false);
            
            if ~exist('STATE_COLORS', 'var') || ~isa(STATE_COLORS, 'SoloParamHandle')
                SoloParamHandle(obj, 'STATE_COLORS', 'value', scolors);
            end
            set_saveable(STATE_COLORS, false);
            set_save_with_settings(STATE_COLORS, false);
            
            if ~exist('WAVE_COLORS', 'var') || ~isa(WAVE_COLORS, 'SoloParamHandle')
                SoloParamHandle(obj, 'WAVE_COLORS', 'value', wcolors);
            end
            set_saveable(WAVE_COLORS, false);
            set_save_with_settings(WAVE_COLORS, false);
                
            if ~exist('POKE_COLORS', 'var') || ~isa(POKE_COLORS, 'SoloParamHandle')
                SoloParamHandle(obj, 'POKE_COLORS', 'value', pcolors);
            end
            set_saveable(POKE_COLORS, false);
            set_save_with_settings(POKE_COLORS, false);
                
            if ~exist('SPIKE_COLOR', 'var') || ~isa(SPIKE_COLOR, 'SoloParamHandle')
                SoloParamHandle(obj, 'SPIKE_COLOR', 'value', default_spike_color);
            end
            set_saveable(SPIKE_COLOR, false);
            set_save_with_settings(SPIKE_COLOR, false);
            
            %The following SoloParamHandles maintain lists of visible
            %entities (or invisible entities)
            if ~exist('VISIBLE_STATES_LIST', 'var') || ~isa(VISIBLE_STATES_LIST, 'SoloParamHandle')
                SoloParamHandle(obj, 'VISIBLE_STATES_LIST', 'value', fieldnames(value(STATE_COLORS)));
            end
            set_saveable(VISIBLE_STATES_LIST, false);
            set_save_with_settings(VISIBLE_STATES_LIST, false);
                
            if ~exist('VISIBLE_POKES_LIST', 'var') || ~isa(VISIBLE_POKES_LIST, 'SoloParamHandle')
                SoloParamHandle(obj, 'VISIBLE_POKES_LIST', 'value', fieldnames(value(POKE_COLORS)));
            end
            set_saveable(VISIBLE_POKES_LIST, false);
            set_save_with_settings(VISIBLE_POKES_LIST, false);
                
            if ~exist('VISIBLE_WAVES_LIST', 'var') || ~isa(VISIBLE_WAVES_LIST, 'SoloParamHandle')
                SoloParamHandle(obj, 'VISIBLE_WAVES_LIST', 'value', fieldnames(value(WAVE_COLORS)));
            end
            set_saveable(VISIBLE_WAVES_LIST, false);
            set_save_with_settings(VISIBLE_WAVES_LIST, false);
            
            if ~exist('SPIKES_VISIBLE', 'var') || ~isa(SPIKES_VISIBLE, 'SoloParamHandle')
                SoloParamHandle(obj, 'SPIKES_VISIBLE', 'value', true);
                set_saveable(SPIKES_VISIBLE, true);
                set_save_with_settings(SPIKES_VISIBLE, true);
            end
            if ~exist('INVISIBLE_TRIALS_LIST', 'var') || ~isa(INVISIBLE_TRIALS_LIST, 'SoloParamHandle')
                SoloParamHandle(obj, 'INVISIBLE_TRIALS_LIST', 'value', []);
                set_saveable(INVISIBLE_TRIALS_LIST, true);
                set_save_with_settings(INVISIBLE_TRIALS_LIST, true);
            end
            
            %These SoloParamHandles control the default limits of the X axis
            SoloParamHandle(obj, 'MIN_TIME', 'value', -200);
            SoloParamHandle(obj, 'MAX_TIME', 'value', 200);
            
            if ~exist('t0', 'var') || ~isa(t0, 'SoloParamHandle')
                NumeditParam(obj, 't0', -5, 1, 1);
            end
            set_callback(t0, {mfilename, 't0_callback'});
            set_callback_on_load(t0, false);
            
            if ~exist('t1', 'var') || ~isa(t1, 'SoloParamHandle')
                NumeditParam(obj, 't1', 15, 1, 1);
            end
            set_callback(t1, {mfilename, 't1_callback'});
            set_callback_on_load(t1, false);
            
            if ~exist('trial_limits', 'var') || ~isa(trial_limits, 'SoloParamHandle')
                MenuParam(obj, 'trial_limits', {'from, to', 'last n'}, 'last n', 1, 1);
            end
            set_callback(trial_limits, {mfilename, 'trial_limits_callback'});
            set_callback_on_load(trial_limits, false);
            
            if ~exist('plotclick_action', 'var') || ~isa(plotclick_action, 'SoloParamHandle')
                MenuParam(obj, 'plotclick_action', {'', 'runs external script'}, '', 1, 1);
                set_callback(plotclick_action, {mfilename, 'plotclick_action_callback'});
            end
            
            if ~exist('start_trial', 'var') || ~isa(start_trial, 'SoloParamHandle')
                NumeditParam(obj, 'start_trial', 1, 1, 1);
            end
            set_callback(start_trial, {mfilename, 'start_trial_callback'});
            set_callback_on_load(start_trial, false);
            
            if ~exist('end_trial', 'var') || ~isa(end_trial, 'SoloParamHandle')
                NumeditParam(obj, 'end_trial', 10, 1, 1);
            end
            set_callback(end_trial, {mfilename, 'end_trial_callback'});
            
            if ~exist('ntrials', 'var') || ~isa(ntrials, 'SoloParamHandle')
                NumeditParam(obj, 'ntrials', value(end_trial) - value(start_trial) + 1, 1, 1);
            end
            set_callback(ntrials, {mfilename, 'ntrials_callback'});
            set_callback_on_load(ntrials, false);
            
            %trial_info is a very important SoloParamHandle. Certain fields
            %continue to exist for precompatibility, but the only fields
            %that are actually used are start_time, align_time, visible, ghandles,
            %mainsort_value, and subsort_value
            if ~exist('trial_info', 'var') || ~isa(trial_info, 'SoloParamHandle')
                empty_trial_info = struct('start_time', [], ...
                    'align_time', [], ...
                    'align_found', [], ...
                    'ydelta', [], ...
                    'visible', [], ...
                    'ghandles', struct('states', [], 'pokes', [], 'waves', [], 'spikes', []), ...
                    'select_value', [], ...
                    'mainsort_value', [], ...
                    'subsort_value', []);
                
                states = fieldnames(scolors); %#ok<NASGU>
                pokes = fieldnames(pcolors); %#ok<NASGU>
                waves = fieldnames(wcolors); %#ok<NASGU>
                
                for guys = {'states', 'pokes', 'waves'}
                    for field = eval(guys{1})
                        if ~isempty(field)
                            empty_trial_info.ghandles.(guys{1}).(field{1}) = [];
                        end
                    end
                end
                
                empty_trial_info = empty_trial_info([]);
                
                SoloParamHandle(obj, 'trial_info', 'value', empty_trial_info);
            end
            
            %Now displaying the legend using the show_legend helper
            %function.
            hndl_uipanelLegend = uipanel('Units', 'normalized', ...
                'Tag', 'uipanelLegend');
            show_legend(hndl_uipanelLegend, value(STATE_COLORS), value(WAVE_COLORS), value(POKE_COLORS));
            
            %Settings panel
            hndl_uipanelSettings = uipanel('Units', 'normalized');
            
            
            %% Formatting graphics elements
            %myfig
            set(value(myfig), ...
                'Units', 'normalized', ...
                'Name', mfilename, ...
                'Position', [0.27031      0.0275     0.46875       0.815]);
            
            %textHeader
            set(get_ghandle(textHeader), ...
                'Units', 'normalized', ...
                'Parent', value(myfig), ...
                'Position', [0.054444     0.94683        0.89    0.027607], ...
                'FontSize', 14, ...
                'FontName', 'monospaced', ...
                'FontWeight', 'bold', ...
                'Tag', 'textHeader', ...
                'TooltipString', mfilename, ...
                'HorizontalAlignment', 'center', ...
                'BackgroundColor', 'cyan');
            
            %btnRedraw
            set(get_ghandle(btnRedraw), ...
                'Parent', value(myfig), ...
                'Units', 'normalized', ...
                'Tag', 'btnRedraw', ...
                'String', 'Redraw', ...
                'TooltipString', 'Reinitialize the legend panel, axes, and preferences pane', ...
                'Visible', 'on', ...
                'Enable', 'off', ...
                'Position', [0.77667-0.023517*2     0.28323         0.1    0.023517]);
            
            
            
            %btnShowHideLegendPanel
            set(get_ghandle(btnShowHideLegendPanel), ...
                'Parent', value(myfig), ...
                'Units', 'normalized', ...
                'Tag', 'btnShowHideLegendPanel', ...
                'String', '', ...
                'TooltipString', 'Show/Hide Legend Panel', ...
                'Visible', 'on', ...
                'Enable', 'on', ...
                'Position', [0.945     0.33333         0.01    0.56339]);
            
            
            %toggleInteractiveZoomIn
            load('pokesplot2_cdata.mat');
            SoloParamHandle(obj, 'toggleInteractiveZoomIn', ...
                'value', uicontrol('Units', 'normalized', ...
                'Parent', value(myfig), ...
                'Tag', 'toggleInteractiveZoomIn', ...
                'TooltipString', 'Zoom In', ...
                'Style', 'togglebutton', ...
                'Callback', [mfilename '(' class(obj) ', ''toggleInteractiveZoomInCallback'');'], ...
                'CData', toggleInteractiveZoomIn_cdata, ...
                'HorizontalAlignment', 'center', ...
                'Position', [0.8767-0.023517*2 0.28323 0.023517 0.023517]), ...
                'saveable', false);
            
            
            %toggleInteractiveZoomOut
            SoloParamHandle(obj, 'toggleInteractiveZoomOut', ...
                'value', uicontrol('Units', 'normalized', ...
                'Parent', value(myfig), ...
                'Tag', 'toggleInteractiveZoomOut', ...
                'TooltipString', 'Zoom Out', ...
                'Style', 'togglebutton', ...
                'Callback', [mfilename '(' class(obj) ', ''toggleInteractiveZoomOutCallback'');'], ...
                'CData', toggleInteractiveZoomOut_cdata, ...
                'HorizontalAlignment', 'center', ...
                'Position', [0.9002-0.023517*2 0.28323 0.023517 0.023517]), ...
                'saveable', false);
            
            
            %toggleInteractiveZoomRectangle
            SoloParamHandle(obj, 'toggleInteractiveZoomRectangle', ...
                'value', uicontrol('Units', 'normalized', ...
                'Parent', value(myfig), ...
                'Tag', 'toggleInteractiveZoomRectangle', ...
                'TooltipString', 'Zoom to a rectanglular region of interest (requires Image Processing Toolbox)', ...
                'Style', 'togglebutton', ...
                'Callback', [mfilename '(' class(obj) ', ''toggleInteractiveZoomRectangleCallback'');'], ...
                'CData', toggleInteractiveZoomRectangle_cdata, ...
                'HorizontalAlignment', 'center', ...
                'Position', [0.9002-0.023517 0.28323 0.023517 0.023517]), ...
                'saveable', false);
            
            
            %toggleInteractivePan
            SoloParamHandle(obj, 'toggleInteractivePan', ...
                'value', uicontrol('Units', 'normalized', ...
                'Parent', value(myfig), ...
                'Tag', 'toggleInteractivePan', ...
                'TooltipString', 'Pan axes', ...
                'Style', 'togglebutton', ...
                'Callback', [mfilename '(' class(obj) ', ''toggleInteractivePanCallback'');'], ...
                'CData', toggleInteractivePan_cdata, ...
                'HorizontalAlignment', 'center', ...
                'Position', [0.9002 0.28323 0.023517 0.023517]), ...
                'saveable', false);
            
            
            %An interactive data cursor
            SoloParamHandle(obj, 'toggleInteractiveDataCursor', ...
                'value', uicontrol('Units', 'normalized', ...
                'Parent', value(myfig), ...
                'Tag', 'toggleInteractiveDataCursor', ...
                'TooltipString', 'Toggle interactive data cursor', ...
                'Style', 'togglebutton', ...
                'Callback', [mfilename '(' class(obj) ', ''toggleInteractiveDataCursorCallback'');'], ...
                'CData', toggleInteractiveDataCursor_cdata, ...
                'HorizontalAlignment', 'center', ...
                'Visible', 'on', ...
                'Position', [0.9002+0.023517 0.28323 0.023517 0.023517]), ...
                'saveable', false);
            
            
            %editCurrentEntity
            set(get_ghandle(editCurrentEntity), ...
                'Units', 'normalized', ...
                'Parent', value(myfig), ...
                'Tag', 'editCurrentEntity', ...
                'Enable', 'inactive', ...
                'HorizontalAlignment', 'center', ...
                'Max', 99999, ...
                'Min', 0, ...
                'TooltipString', 'Display of the states/pokes/waves at the cursor position', ...
                'Position', [0.054444     0.915        0.89    0.03]);
            
            %uipanelSettings
            set(hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Parent', value(myfig), ...
                'Title', 'Settings', ...
                'Tag', 'uipanelSettings', ...
                'Position', [0.054444    0.026585        0.89     0.22699]);
            
            %uipanelLegend
            set(hndl_uipanelLegend, ...
                'Tag', 'uipanelLegend', ...
                'Parent', value(myfig), ...
                'Units', 'normalized', ...
                'Position', [0.66556     0.33333     0.27889     0.56339]);
            
            %sliderX
            uicontrol('Style', 'slider', ...
                'Tag', 'sliderX', ...
                'Units', 'normalized', ...
                'Parent', value(myfig), ...
                'Max', 1.0, ...
                'Min', 0.0, ...
                'SliderStep', [0.001 0.01], ...
                'Callback', [mfilename '(' class(obj), ', ''sliderXCallback'');'], ...
                'Position', [0.11      0.2638     0.55667    0.019427]);
            
            %sliderY
            uicontrol('Style', 'slider', ...
                'Tag', 'sliderY', ...
                'Units', 'normalized', ...
                'Parent', value(myfig), ...
                'Callback', [mfilename '(' class(obj), ', ''sliderYCallback'');'], ...
                'Max', 1.0, ...
                'Min', 0.0, ...
                'Position', [0.02     0.33333    0.021111     0.56339]);
            
            
            %plotclick_action
            set(get_ghandle(plotclick_action), ...
                'Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Tag', 'plotclick_action', ...
                'Position', [0.18946     0.83799     0.22459     0.11732]);
            delete(get_lhandle(plotclick_action));
            
            %trial_limits
            set(get_ghandle(trial_limits), ...
                'Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Tag', 'trial_limits', ...
                'Position', [0.18946      0.7214     0.22459     0.11732]);
            delete(get_lhandle(trial_limits));
            
            %t1
            set(get_ghandle(t1), ...
                'Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Tag', 't1', ...
                'TooltipString', 't1', ...
                'FontSize', 10.0, ...
                'FontName', 'monospaced', ...
                'Position', [0.30615     0.61865    0.056462     0.11732]);
            delete(get_lhandle(t1));
            
            %t0
            set(get_ghandle(t0), ...
                'Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Tag', 't0', ...
                'FontSize', 10.0, ...
                'FontName', 'monospaced', ...
                'TooltipString', 't0', ...
                'Position', [0.18946     0.61865    0.056462     0.11732]);
            delete(get_lhandle(t0));
            
            
            %textXLimits
            set(get_ghandle(textXLimits), ...
                'Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Tag', 'textXLimits', ...
                'HorizontalAlignment', 'right', ...
                'FontSize', 10.0, ...
                'FontWeight', 'normal', ...
                'TooltipString', 'X Limits:', ...
                'Position', [0.017566     0.613     0.16939     0.11732]);
            
            %alignon
            if strcmp(value(popupParsingStyle), 'v1 Style Parsing')
                maxval = 1;
            else
                maxval = 99999;
            end
            set(get_ghandle(alignon), ...
                'Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Tag', 'alignon', ...
                'FontSize', 10.0, ...
                'FontName', 'monospaced', ...
                'Max', maxval, ...
                'Min', 0, ...
                'HorizontalAlignment', 'center', ...
                'Position', [0.18946     0.312     0.3588457     0.30097]);
            delete(get_lhandle(alignon));
            
            
            %menuParsingStyle
            set(get_ghandle(popupParsingStyle), ...
                'Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Tag', 'popupParsingStyle', ...
                'Position', [0.5500514    0.5     0.1304517      0.1107961]);
            delete(get_lhandle(popupParsingStyle));
            
            
            %textalignon, ...
            set(get_ghandle(textalignon), ...
                'Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'ToolTipString', 'Align On', ...
                'Tag', 'textalignon', ...
                'FontSize', 10.0, ...
                'FontWeight', 'normal', ...
                'HorizontalAlignment', 'right', ...
                'Position', [0.017566     0.312     0.16939     0.30097]);
            
            %textto
            set(get_ghandle(textto), ...
                'Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Tag', 'textto', ...
                'FontSize', 10.0, ...
                'FontWeight', 'normal', ...
                'HorizontalAlignment', 'center', ...
                'Position', [0.47177     0.71655    0.056462     0.12291]);
            if strcmp(value(trial_limits), 'last n')
                set(get_ghandle(textto), 'Visible', 'off');
            else
                set(get_ghandle(textto), 'Visible', 'on');
            end
            
            
            %textto2
            set(get_ghandle(textto2), ...
                'Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Tag', 'textto2', ...
                'FontSize', 10.0, ...
                'FontWeight', 'normal', ...
                'HorizontalAlignment', 'center', ...
                'Position', [0.24718     0.61865    0.056462     0.11732]);
            
            %end_trial
            set(get_ghandle(end_trial), ...
                'Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Tag', 'end_trial', ...
                'FontSize', 10.0, ...
                'FontName', 'monospaced', ...
                'HorizontalAlignment', 'center', ...
                'Position', [0.53074      0.7214    0.056462     0.11732]);
            delete(get_lhandle(end_trial));
            
            
            
            %start_trial
            set(get_ghandle(start_trial), ...
                'Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Tag', 'start_trial', ...
                'FontSize', 10.0, ...
                'FontName', 'monospaced', ...
                'HorizontalAlignment', 'center', ...
                'Position', [0.4128      0.7214    0.056462     0.11732]);
            delete(get_lhandle(start_trial));
            
            if strcmpi(value(trial_limits), 'from, to')
                set([get_ghandle(start_trial) get_ghandle(end_trial)], 'Visible', 'on');
            else
                set([get_ghandle(start_trial) get_ghandle(end_trial)], 'Visible', 'off');
            end
            
            
            %ntrials
            set(get_ghandle(ntrials), ...
                'Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Tag', 'ntrials', ...
                'TooltipString', 'ntrials', ...
                'FontSize', 10.0, ...
                'FontName', 'monospaced', ...
                'HorizontalAlignment', 'center', ...
                'Position', get(get_ghandle(start_trial), 'Position'));
            delete(get_lhandle(ntrials));
            if strcmpi(value(trial_limits), 'last n')
                set(get_ghandle(ntrials), 'Visible', 'on');
            else
                set(get_ghandle(ntrials), 'Visible', 'off');
            end
            
            
            %textYValuesToShow
            set(get_ghandle(textYValuesToShow), ...
                'Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Tag', 'textYValuesToShow', ...
                'FontSize', 10.0, ...
                'FontWeight', 'normal', ...
                'HorizontalAlignment', 'right', ...
                'Position', [0.017566     0.72552     0.16939     0.11732]);
            
            %textClickingOnPlot
            set(get_ghandle(textClickingOnPlot), ...
                'Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Tag', 'textClickingOnPlot', ...
                'TooltipString', 'Clicking on plot', ...
                'FontSize', 10.0, ...
                'FontWeight', 'normal', ...
                'HorizontalAlignment', 'right', ...
                'Position',  [0.017566     0.83799     0.16939     0.11732]);
            
            
            
            %checkboxStates
            SoloParamHandle(obj, 'checkboxStates', 'value', ...
                uicontrol('Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Style', 'checkbox', ...
                'String', 'States', ...
                'TooltipString', 'Show/hide states', ...
                'Value', ~isempty(value(VISIBLE_STATES_LIST)), ...
                'Tag', 'checkboxStates', ...
                'Callback', [mfilename '(' class(obj) ', ''checkboxStatesCallback'');'], ...
                'Position', [0.8143     0.84466    0.094103     0.12621]), ...
                'saveable', false);
            
            
            %checkboxPokes
            SoloParamHandle(obj, 'checkboxPokes', 'value', ...
                uicontrol('Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Style', 'checkbox', ...
                'String', 'Pokes', ...
                'TooltipString', 'Show/hide pokes', ...
                'Value', ~isempty(value(VISIBLE_POKES_LIST)), ...
                'Tag', 'checkboxPokes', ...
                'Callback', [mfilename '(' class(obj) ', ''checkboxPokesCallback'');'], ...
                'Position', [0.8143      0.7233    0.094103     0.12621]), ...
                'saveable', false);
            
            
            %checkboxWaves
            SoloParamHandle(obj, 'checkboxWaves', 'value', uicontrol('Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Style', 'checkbox', ...
                'String', 'Waves', ...
                'TooltipString', 'Show/hide scheduled waves', ...
                'Value', ~isempty(value(VISIBLE_WAVES_LIST)), ...
                'Tag', 'checkboxWaves', ...
                'Callback', [mfilename '(' class(obj) ', ''checkboxWavesCallback'');'], ...
                'Position', [0.8143     0.60194    0.094103     0.12621]), ...
                'saveable', false);
            
            %checkboxSpikes
            SoloParamHandle(obj, 'checkboxSpikes', 'value', ...
                uicontrol('Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Style', 'checkbox', ...
                'String', 'Spikes', ...
                'Tag', 'checkboxSpikes', ...
                'TooltipString', 'Show/hide spikes', ...
                'Value', value(SPIKES_VISIBLE), ...
                'Callback', [mfilename '(' class(obj) ', ''checkboxSpikesCallback'');'], ...
                'Position', [0.8143     0.48058    0.094103     0.12621]), ...
                'saveable', false);
            
            %checkboxUseCustomPreferences
            if ~exist('SHOULD_USE_CUSTOM_PREFERENCES', 'var') || ~isa(SHOULD_USE_CUSTOM_PREFERENCES, 'SoloParamHandle')
                SoloParamHandle(obj, 'SHOULD_USE_CUSTOM_PREFERENCES', 'value', false);
                set_saveable(SHOULD_USE_CUSTOM_PREFERENCES, true);
                set_save_with_settings(SHOULD_USE_CUSTOM_PREFERENCES, true);
            end
            SoloParamHandle(obj, 'checkboxUseCustomPreferences', 'value', ...
                uicontrol('Parent', hndl_uipanelSettings, ...
                'Units', 'normalized', ...
                'Style', 'checkbox', ...
                'String', 'Use custom preferences', ...
                'Tag', 'checkboxUseCustomPreferences', ...
                'Value', value(SHOULD_USE_CUSTOM_PREFERENCES), ...
                'TooltipString', ['If checked, ' mfilename ' uses the ''Main Sort'', ''Sub Sort'' and ''Trial Selector'' settings from the preferences panel'], ...
                'Callback', [mfilename '(' class(obj) ', ''checkboxUseCustomPreferencesCallback'');'], ...
                'Position', [0.8143     0.37379     0.17566     0.11165]), ...
                'saveable', false);
            
            
            %axpokesplot
            SoloParamHandle(obj, 'axpokesplot', 'value', axes('Units', 'normalized'), 'saveable', false);
            %hold(value(axpokesplot), 'on');
            if strcmpi(value(trial_limits), 'from, to')
                YLim = [value(start_trial) value(end_trial)];
            elseif strcmpi(value(trial_limits), 'last n')
                ulim = max(value(ntrials), n_started_trials);
                llim = ulim - value(ntrials) + 1;
                YLim = [llim ulim];
            end
            set(value(axpokesplot), ...
                'Units', 'normalized', ...
                'Parent', value(myfig), ...
                'Color', [0.3 0.3 0.3], ...
                'Tag', 'axpokesplot', ...
                'Visible', 'on', ...
                'ButtonDownFcn', [mfilename '(' class(obj) ', ''axpokesplot_callback'');'], ...
                'YLim', [YLim(1)-0.5 YLim(2)+0.5], ...
                'XLim', [value(t0) value(t1)], ...
                'Position', [0.11     0.33333     0.55667     0.56339]);
            xlabel(value(axpokesplot), 'Time (seconds)');
            if get(value(checkboxUseCustomPreferences), 'Value')
                ylabel(value(axpokesplot), '');
            else
                set(value(axpokesplot), 'YTickMode', 'auto');
                ylabel(value(axpokesplot), 'Trial Number');
            end
            
            %btnZoomInX
            PushbuttonParam(obj, 'btnZoomInX', 1, 1);
            set_callback(btnZoomInX, {mfilename, 'btnZoomInXCallback'});
            set(get_ghandle(btnZoomInX), ...
                'Units', 'normalized', ...
                'Parent', value(myfig), ...
                'FontSize', 13.0, ...
                'String', '+', ...
                'Tag', 'btnZoomInX', ...
                'Position', [0.66667      0.2638        0.02    0.018405]);
            
            
            %btnZoomOutX
            PushbuttonParam(obj, 'btnZoomOutX', 1, 1);
            set_callback(btnZoomOutX, {mfilename, 'btnZoomOutXCallback'});
            set(get_ghandle(btnZoomOutX), ...
                'Units', 'normalized', ...
                'Parent', value(myfig), ...
                'FontSize', 13.0, ...
                'String', '-', ...
                'Tag', 'btnZoomOutX', ...
                'Position', [0.68556      0.2638        0.02    0.018405]);
            
            
            %btnZoomInY
            PushbuttonParam(obj, 'btnZoomInY', 1, 1);
            set_callback(btnZoomInY, {mfilename, 'btnZoomInYCallback'});
            set(get_ghandle(btnZoomInY), ...
                'Units', 'normalized', ...
                'Parent', value(myfig), ...
                'FontSize', 13.0, ...
                'String', '+', ...
                'Tag', 'btnZoomInY', ...
                'Position', [0.021111     0.31493        0.02    0.018405]);
            
            
            %btnZoomOutY
            PushbuttonParam(obj, 'btnZoomOutY', 1, 1);
            set_callback(btnZoomOutY, {mfilename, 'btnZoomOutYCallback'});
            set(get_ghandle(btnZoomOutY), ...
                'Units', 'normalized', ...
                'FontSize', 13.0, ...
                'Parent', value(myfig), ...
                'String', '-', ...
                'Tag', 'btnZoomOutY', ...
                'Position', [0.021111     0.29755        0.02    0.018405]);
            
            
            %The following call to btnShowHideLegendPanelCallback uses the
            %saved setting to hide the legend panel if necessary.
            feval(mfilename, obj, 'btnShowHideLegendPanelCallback');
            
            %Setting the slider values to the appropriate position
            feval(mfilename, obj, 'refresh_sliderValues');
            
            %Making sure trial_info.ghandles are empty before anything gets
            %drawm
            feval(mfilename, obj, 'flush_trial_info_handles');
             
            SoloFunctionAddVars(obj, 'pokesplot_preferences_pane', 'rw_args', {'STATE_COLORS', 'POKE_COLORS', 'WAVE_COLORS', 'SPIKE_COLOR', 'TRIAL_SEQUENCE', ...
                'VISIBLE_STATES_LIST', 'VISIBLE_POKES_LIST', 'VISIBLE_WAVES_LIST', 'SPIKES_VISIBLE', 'INVISIBLE_TRIALS_LIST', 'SHOULD_USE_CUSTOM_PREFERENCES', 'myfig', ...
                'checkboxPokes', 'checkboxStates', 'checkboxWaves', 'alignon'});
            SoloFunctionAddVars(obj, 'pokesplot_preferences_pane', 'ro_args', {'trial_info', 't0', 't1'});
            SoloFunctionAddVars(obj, 'eval_pokesplot_expression', 'ro_args', {'trial_info', 'PROTOCOL_DATA'});
            pokesplot_preferences_pane(obj, 'init', 'Position', [0.40652    0.095433     0.20452     0.12291], 'Parent', hndl_uipanelSettings, 'TooltipString', 'Show/hide preferences pane');
            
            
            %Reverting back to main protocol figure window
            figure(my_xyfig(3));
            
            %Setting the WindowButtonMotionFcn to display the entities
            %under the cursor on the axes.
            set(value(myfig), 'WindowButtonMotionFcn', [mfilename '(' class(obj) ', ''update_editCurrentEntity'');']);
            feval(mfilename, obj, 'hide');
           
            
            %% CASE toggleInteractiveZoomInCallback
        case 'toggleInteractiveZoomInCallback'
            if get(value(toggleInteractiveZoomIn), 'Value')
                plotclick_action.value = '';
                if exist('IMRECT', 'var') && isa(value(IMRECT), 'imrect')
                    %This section seems to behave strangely at times.
                    %Hence the try-catch and temporary disabling of the
                    %warning MATLAB:class:DestructorError.
                    try
                        resume(value(IMRECT));
                    catch
                    end
                    try
                        s = warning('query', 'MATLAB:class:DestructorError');
                        warning('off', 'MATLAB:class:DestructorError');
                        delete(value(IMRECT));
                        warning(s.state, 'MATLAB:class:DestructorError');
                    catch
                    end
                end
                set(value(toggleInteractiveZoomOut), 'Value', false);
                set(value(toggleInteractiveZoomRectangle), 'Value', false);
                set(value(toggleInteractivePan), 'Value', false);
                feval(mfilename, obj, 'refresh_sliderValues');
            end
            
            %% CASE toggleInteractiveZoomOutCallback
        case 'toggleInteractiveZoomOutCallback'
            if get(value(toggleInteractiveZoomOut), 'Value')
                plotclick_action.value = '';
                if exist('IMRECT', 'var') && isa(value(IMRECT), 'imrect')
                    try
                        resume(value(IMRECT));
                    catch
                    end
                    try
                        s = warning('query', 'MATLAB:class:DestructorError');
                        warning('off', 'MATLAB:class:DestructorError');
                        delete(value(IMRECT));
                        warning(s.state, 'MATLAB:class:DestructorError');
                    catch
                    end
                end
                set(value(toggleInteractiveZoomIn), 'Value', false);
                set(value(toggleInteractiveZoomRectangle), 'Value', false);
                set(value(toggleInteractivePan), 'Value', false);
                feval(mfilename, obj, 'refresh_sliderValues');
            end
            
            %% CASE toggleInteractiveZoomRectangleCallback
        case 'toggleInteractiveZoomRectangleCallback'
            if get(value(toggleInteractiveZoomRectangle), 'Value')
                plotclick_action.value = '';
                hndlvec = [value(toggleInteractiveZoomIn) ...
                    value(toggleInteractiveZoomOut) ...
                    value(toggleInteractivePan) ...
                    value(toggleInteractiveDataCursor)];
                set(hndlvec, 'Value', false);
                set(hndlvec, 'Enable', 'off');
                
                IMRECT.value = imrect(value(axpokesplot));
                position = wait(value(IMRECT));
                
                if exist('IMRECT', 'var') && isa(value(IMRECT), 'imrect')
                    s = warning('query', 'MATLAB:class:DestructorError');
                    warning('off', 'MATLAB:class:DestructorError');
                    delete(value(IMRECT));
                    warning(s.state, 'MATLAB:class:DestructorError');
                end
                if ~isempty(position)
                    start_trial.value = ceil(position(2)); end_trial.value = floor(position(2)+position(4));
                    ntrials.value = value(end_trial) - value(start_trial) + 1;
                    trial_limits.value = 'from, to';
                    feval(mfilename, obj, 'trial_limits_callback');
                    
                    t0.value = position(1); t1.value = position(1)+position(3);
                    feval(mfilename, obj, 't0_callback');
                end
                set(value(toggleInteractiveZoomRectangle), 'Value', false);
                set(hndlvec, 'Enable', 'on');
                feval(mfilename, obj, 'refresh_sliderValues');
            else
                hndlvec = [value(toggleInteractiveZoomIn) ...
                    value(toggleInteractiveZoomOut) ...
                    value(toggleInteractivePan) ...
                    value(toggleInteractiveDataCursor)];
                set(hndlvec, 'Enable', 'on');
                if exist('IMRECT', 'var') && isa(value(IMRECT), 'imrect')
                    try
                        resume(value(IMRECT));
                    catch
                    end
                    try
                        s = warning('query', 'MATLAB:class:DestructorError');
                        warning('off', 'MATLAB:class:DestructorError');
                        delete(value(IMRECT));
                        warning(s.state, 'MATLAB:class:DestructorError');
                    catch
                    end
                end
                %Programmatically pressing the ESC key seems to be the only
                %way to get rid of the imrect cursor.
                javaobj = java.awt.Robot;
                javaobj.keyPress(27); %ASCII value 27: ESC
            end
            
            
            
            %% CASE toggleInteractivePanCallback
        case 'toggleInteractivePanCallback'
            if get(value(toggleInteractivePan), 'Value')
                plotclick_action.value = '';
                hndlvec = [value(toggleInteractiveZoomIn) ...
                    value(toggleInteractiveZoomOut) ...
                    value(toggleInteractiveZoomRectangle) ...
                    value(toggleInteractiveDataCursor)];
                set(hndlvec, 'Value', false);
                set(hndlvec, 'Enable', 'off');
                
                PANOBJ.value = pan(value(myfig));
                set(value(PANOBJ), 'Enable', 'on', 'ActionPostCallback', [mfilename '(' class(obj) ', ''PANOBJPostCallback'')']);
            else
                hndlvec = [value(toggleInteractiveZoomIn) ...
                    value(toggleInteractiveZoomOut) ...
                    value(toggleInteractiveZoomRectangle) ...
                    value(toggleInteractiveDataCursor)];
                set(hndlvec, 'Enable', 'on');
                if exist('PANOBJ', 'var') && isa(value(PANOBJ), 'graphics.pan');
                    try
                        set(value(PANOBJ), 'Enable', 'off');
                        delete(value(PANOBJ));
                    catch
                    end
                end
            end
            
            %% CASE toggleInteractiveDataCursorCallback
        case 'toggleInteractiveDataCursorCallback'
            if get(value(toggleInteractiveDataCursor), 'Value')
                plotclick_action.value = '';
                hndlvec = [value(toggleInteractiveZoomIn) ...
                    value(toggleInteractiveZoomOut) ...
                    value(toggleInteractiveZoomRectangle) ...
                    value(toggleInteractivePan)];
                set(hndlvec, 'Value', false);
                set(hndlvec, 'Enable', 'off');                
            else
                hndlvec = [value(toggleInteractiveZoomIn) ...
                    value(toggleInteractiveZoomOut) ...
                    value(toggleInteractiveZoomRectangle) ...
                    value(toggleInteractivePan)];
                set(hndlvec, 'Enable', 'on');
            end
            
            %% CASE PANOBJPostCallback
        case 'PANOBJPostCallback'
            XLim = get(value(axpokesplot), 'XLim');
            YLim = get(value(axpokesplot), 'YLim');
            t0.value = XLim(1); t1.value = XLim(2);
            start_trial.value = ceil(YLim(1)); end_trial.value = floor(YLim(2));
            ntrials.value = value(end_trial) - value(start_trial) + 1;
            trial_limits.value = 'from, to';
            feval(mfilename, obj, 'trial_limits_callback');
            feval(mfilename, obj, 't0_callback');
            
            %% CASE get_current_entity
        case 'get_current_entity'
            %str = PokesPlotSection(obj, 'get_current_entity', currpoint)
            currpoint = varargin{1};
            
            str = {};
            xlim = get(value(axpokesplot), 'XLim');
            ylim = get(value(axpokesplot), 'YLim');
            if currpoint(1, 1)>=min(xlim) && currpoint(1, 1)<=max(xlim) && ...
                    currpoint(1, 2)>=min(ylim) && currpoint(1, 2)<=max(ylim)
                
                axes_ycoord = round(currpoint(1, 2));
                if length(TRIAL_SEQUENCE) >= axes_ycoord && axes_ycoord >= 1
                    trialnum = TRIAL_SEQUENCE(axes_ycoord);
                else
                    trialnum = NaN;
                end
                if length(trial_info) >= trialnum
                    %Find all visible objects for trialnum in the
                    %order spikes, waves, pokes, states
                    handles = [];
                    for guys = {'states', 'pokes', 'waves', 'spikes'}
                        if isfield(trial_info(trialnum).ghandles, guys{1}) && isfield(trial_info(trialnum).ghandles.(guys{1}), 'all_handles')
                            handles = [handles(:); trial_info(trialnum).ghandles.(guys{1}).all_handles(:)];
                        end
                    end
                    handles = handles(ishandle(handles));
                    handles = findobj(handles, 'flat', 'Visible', 'on');
                    
                    str = {['Trial:' num2str(trialnum)]};
                    for ctr = 1:length(handles)
                        type = get(handles(ctr), 'Type');
                        if strcmp(type, 'patch');
                            %States and pokes
                            if is_point_in_rectangle([currpoint(1, 1) currpoint(1, 2)], handles(ctr), 'XOnly', true)
                                str{end+1} = [getappdata(handles(ctr), 'pp_Category') ':' getappdata(handles(ctr), 'pp_Name')];
                            end
                        elseif strcmp(type, 'line')
                            %Spikes and waves
                            if is_point_in_line([currpoint(1, 1) currpoint(1, 2)], handles(ctr), 'XOnly', true)
                                str{end+1} = [getappdata(handles(ctr), 'pp_Category') ':' getappdata(handles(ctr), 'pp_Name')];
                            end
                        end
                    end
                    str{end+1} = ['Time:' num2str(currpoint(1, 1)) ' seconds'];
                    
                else
                    str = {['(' num2str(currpoint(1, 1)) ', ' num2str(currpoint(1, 2)) ')']};
                end
            else
                str = {};
            end
            varargout{1} = str;
            
            
            
            %% CASE axpokesplot_callback
        case {'axpokesplot_callback', 'plotclick'}
            %PokesPlotSection(obj, 'axpokesplot_callback', get(gca,
            %'CurrentPoint')
            if nargin==3
                cp = varargin{1};
            elseif nargin==2
                cp = get(value(axpokesplot), 'CurrentPoint');
            end
            
            
            if get(value(toggleInteractiveZoomIn), 'Value') || get(value(toggleInteractiveZoomOut), 'Value')
                XLim = get(value(axpokesplot), 'XLim');
                YLim = get(value(axpokesplot), 'YLim');
                if get(value(toggleInteractiveZoomIn), 'Value')
                    offsetY = 0.4*abs(diff(YLim));
                    offsetX = 0.4*abs(diff(XLim));
                else
                    offsetY = 0.6*abs(diff(YLim));
                    offsetX = 0.6*abs(diff(XLim));
                end
                region_XLim = [cp(1,1)-offsetX cp(1,1)+offsetX];
                region_YLim = [cp(1,2)-offsetY cp(1,2)+offsetY];
                if ceil(region_YLim(1)) == value(start_trial) && floor(region_YLim(2)) == value(end_trial)
                    if get(value(toggleInteractiveZoomIn), 'Value')
                        region_YLim = [cp(1,2)-0.6 cp(1,2)+0.6];
                    else
                        offset = max(abs(diff(region_YLim)), 2)/2 + 0.45252; %Some random positive value
                        region_YLim = [cp(1,2)-offset cp(1,2)+offset];
                    end
                end
                t0.value = region_XLim(1); t1.value = region_XLim(2);
                start_trial.value = ceil(region_YLim(1)); end_trial.value = floor(region_YLim(2));
                ntrials.value = value(end_trial) - value(start_trial) + 1;
                trial_limits.value = 'from, to';
                feval(mfilename, obj, 'trial_limits_callback');
                feval(mfilename, obj, 't0_callback');
                return;
            end
            
            if get(value(toggleInteractiveZoomRectangle), 'Value')
                return;
            end
            
            if get(value(toggleInteractivePan), 'Value')
                return;
            end
            
            if get(value(toggleInteractiveDataCursor), 'Value')
                str = feval(mfilename, obj, 'get_current_entity', cp);
                msgbox(str);
                return;
            end
            
            if ~strcmpi(value(plotclick_action), 'runs external script')
                return;
            end
            
            %msgbox('axpokesplot_callback');
            
            [enable_script_hooks errID1] = bSettings('compare', 'AUX_SCRIPT', 'Disable_Aux_Scripts',0);
            [enable_ppclick_hook errID2] = bSettings('compare', 'AUX_SCRIPT', 'Enable_On_PPClick_Script', 1);
            [script errID3] = bSettings('get', 'AUX_SCRIPT', 'On_PPClick_Script');
            [args errID4] = bSettings('get', 'AUX_SCRIPT', 'On_PPClick_Args');
            
            if errID1 || errID2 || errID3 || errID4 ...
                    || ~enable_script_hooks ...
                    || ~enable_ppclick_hook,
                return;
            elseif ~ischar(script) ...
                    || isempty(script) ...
                    || ~exist(script,'file'),
                warning(['Script hook on pokes plot click is enabled,' ...
                    ' but the script is not specified, the setting is' ...
                    ' not a string, or the file specified does not exist.']); %#ok<WNTAG> (This line OK.)
                return;
            end; %     end if/elseif we should not run the script
            
            %     Add default arguments afterwards.
            fix_date_format=1;
            if find(strcmp('SavingSection', methods(obj, '-full'))),
                [experimenter_v ratname_v savedate_v] = SavingSection(obj,'get_info');
            elseif isa(obj, 'neurobrowser')
                infoS = neurobrowser('get_info');
                experimenter_v = infoS.experimenter; ratname_v = infoS.ratname; savedate_v = infoS.sessdate;
                savedate_v = datestr(savedate_v, 'yyyymmdd');
                fix_date_format=0;
            else
                experimenter_v = '_'; ratname_v = '_'; savedate_v = '_';
            end
            
            if fix_date_format && ~strcmp(savedate_v, '_')
                savedate_v = datestr(savedate_v, 'yyyymmdd');
            end
            %     Note that the savedate_v will be '_' if the saving plugin is
            %       not being used *OR* if get_info returns '_' (meaning that
            %       no save has taken place for this data).
            
            
            %     Calculate trial number, time in trial, and time in
            %       experiment from the position in the figure and event
            %       information.
            
            %     Trial Number
            if round(cp(1, 2))>=1 && n_done_trials>=round(cp(1, 2)) && ~ismember(TRIAL_SEQUENCE(round(cp(1, 2))), value(INVISIBLE_TRIALS_LIST))
                trialNum = TRIAL_SEQUENCE(round(cp(1,2)));
            else
                return;
            end
            
            
            %     temps for convenience
            tInfo_temp = value(trial_info); %     plot info for all trials
            this_trial_info = tInfo_temp(trialNum); %(trial_info defined by GetSoloFunctionArgs)
            
            time_relative_to_trial_align = cp(1, 1);
            
            %     For reasons not worth explaining here, the actual start time
            %       registered for the first trial is not 0, so we subtract it
            %       from all absolute experiment times.
            experiment_start_time = tInfo_temp(1).start_time;
            
            
            %     Handle click on left.
            if time_relative_to_trial_align < value(t0),
                timeTri = 0;                    %     0 seconds into trial
                timeExp = this_trial_info.start_time - experiment_start_time; %     start of this trial
            else %     Otherwise, click was in plot proper.
                %     Time in Experiment
                %     time 0 in trial's row + click distance from 0 in seconds
                timeExp = ...
                    this_trial_info.align_time + time_relative_to_trial_align - experiment_start_time;
                %     Time in Trial
                %     time in exp - time of trial start
                timeTri = timeExp - this_trial_info.start_time + experiment_start_time;
            end;
            %     End-of-Trial time is the same in both cases.
            if length(value(trial_info)) < trialNum + 1, %     If last trial, report that (so that end of experiment time can be used).
                timeExpEoT = '_';
            else
                timeExpEoT = tInfo_temp(trialNum+1).start_time - experiment_start_time; %     If not last trial, report time of start of next trial.
            end;
            
            
            %     Add the information retrieved together into a string of
            %        filename + args.
            evalstring = [	script				...	%     filename of script
            ' '			experimenter_v		...	%     name of experimenter
            ' '			ratname_v			...	%     name of rat
            ' '			savedate_v			...	%     date data was saved
            ' '         int2str(timeExp)	];	%     selected trial's end time

            
            if isunix
                system([evalstring '&']);
            elseif ispc
                system(['start ' evalstring]);
            end
            
            
            %% CASE btnZoomInXCallback
        case 'btnZoomInXCallback'
            curr_XLim = get(value(axpokesplot), 'XLim');
            new_XLim = curr_XLim;
            stepsize = min(abs(diff(new_XLim))*0.5, 1);
            if new_XLim(1)+stepsize < new_XLim(2)
                new_XLim = [new_XLim(1)+stepsize new_XLim(2)];
            end
            if new_XLim(2)-stepsize > new_XLim(1)
                new_XLim = [new_XLim(1) new_XLim(2)-stepsize];
            end
            t0.value = new_XLim(1); t1.value = new_XLim(2);
            set(value(axpokesplot), 'XLim', new_XLim);
            feval(mfilename, obj, 't0_callback');
            
            
            %% CASE btnZoomOutXCallback
        case 'btnZoomOutXCallback'
            curr_XLim = get(value(axpokesplot), 'XLim');
            new_XLim = curr_XLim;
            stepsize = min(abs(diff(new_XLim))*0.5, 1);
            if new_XLim(1)-stepsize < new_XLim(2)
                new_XLim = [new_XLim(1)-stepsize new_XLim(2)];
            end
            if new_XLim(2)+stepsize > new_XLim(1)
                new_XLim = [new_XLim(1) new_XLim(2)+stepsize];
            end
            t0.value = new_XLim(1); t1.value = new_XLim(2);
            set(value(axpokesplot), 'XLim', new_XLim);
            feval(mfilename, obj, 't0_callback');
            
            
            %% CASE btnZoomInYCallback
        case 'btnZoomInYCallback'
            curr_YLim = get(value(axpokesplot), 'YLim');
            new_YLim = curr_YLim;
            if ceil(new_YLim(1))+1 < floor(new_YLim(2))
                new_YLim = [new_YLim(1)+1 new_YLim(2)];
            end
            if floor(new_YLim(2))-1 > ceil(new_YLim(1))
                new_YLim = [new_YLim(1) new_YLim(2)-1];
            end
            start_trial.value = ceil(new_YLim(1)); end_trial.value = floor(new_YLim(2));
            ntrials.value = value(end_trial) - value(start_trial) + 1;
            trial_limits.value = 'from, to';
            feval(mfilename, obj, 'trial_limits_callback');
            
            %% CASE btnZoomOutYCallback
        case 'btnZoomOutYCallback'
            curr_YLim = get(value(axpokesplot), 'YLim');
            new_YLim = curr_YLim;
            if ceil(new_YLim(1))-1 < floor(new_YLim(2))
                new_YLim = [new_YLim(1)-1 new_YLim(2)];
            end
            if floor(new_YLim(2))+1 > ceil(new_YLim(1))
                new_YLim = [new_YLim(1) new_YLim(2)+1];
            end
            start_trial.value = ceil(new_YLim(1)); end_trial.value = floor(new_YLim(2));
            ntrials.value = value(end_trial) - value(start_trial) + 1;
            trial_limits.value = 'from, to';
            feval(mfilename, obj, 'trial_limits_callback');
            
            
            %% CASE refresh_sliderValues
        case 'refresh_sliderValues'
            hndl_sliderX = findobj(value(myfig), 'Tag', 'sliderX');
            hndl_sliderY = findobj(value(myfig), 'Tag', 'sliderY');
            XLim = get(value(axpokesplot), 'XLim'); max_x = value(MAX_TIME); min_x = value(MIN_TIME); difference = value(t1) - value(t0);
            YLim = get(value(axpokesplot), 'YLim'); ntrials_to_show = value(end_trial) - value(start_trial) + 1;
            
            sliderX_value = (-XLim(2) + min_x + difference)/(min_x - max_x + difference);
            sliderX_value = min(sliderX_value, 1); sliderX_value = max(sliderX_value, 0);
            set(hndl_sliderX, 'Value', sliderX_value);
            sliderY_value = (YLim(2) - ntrials_to_show)/(n_started_trials - ntrials_to_show);
            sliderY_value = min(sliderY_value, 1); sliderY_value = max(sliderY_value, 0);
            set(hndl_sliderY, 'Value', sliderY_value);
            
            %% CASE checkboxStatesCallback
        case 'checkboxStatesCallback'
            if get(value(checkboxStates), 'Value')
                pokesplot_preferences_pane(obj, 'btnSelectAllStatesCallback');
            else
                pokesplot_preferences_pane(obj, 'btnSelectNoneStatesCallback');
            end
            
            
            %% CASE checkboxPokesCallback
        case 'checkboxPokesCallback'
            if get(value(checkboxPokes), 'Value')
                pokesplot_preferences_pane(obj, 'btnSelectAllPokesCallback');
            else
                pokesplot_preferences_pane(obj, 'btnSelectNonePokesCallback');
            end
            
            
            %% CASE checkboxWavesCallback
        case 'checkboxWavesCallback'
            if get(value(checkboxWaves), 'Value')
                pokesplot_preferences_pane(obj, 'btnSelectAllWavesCallback');
            else
                pokesplot_preferences_pane(obj, 'btnSelectNoneWavesCallback');
            end
            
            %% CASE checkboxSpikesCallback
        case 'checkboxSpikesCallback'
            set(value(myfig), 'Pointer', 'watch'); drawnow;
            booleanstr = {'off', 'on'};
            SPIKES_VISIBLE.value = get(value(checkboxSpikes), 'Value');
            for ctr = 1:length(value(trial_info))
                if isfield(trial_info(ctr).ghandles, 'spikes') && isfield(trial_info(ctr).ghandles.spikes, 'all_handles')
                    isvisible = ~ismember(ctr, value(INVISIBLE_TRIALS_LIST)) && value(SPIKES_VISIBLE);
                    handle_list = trial_info(ctr).ghandles.spikes.all_handles(ishandle(trial_info(ctr).ghandles.spikes.all_handles));
                    set(handle_list, 'Visible', booleanstr{double(isvisible)+1});
                end
            end
            
            set(value(myfig), 'Pointer', 'arrow'); drawnow;
            
            %% CASE checkboxUseCustomPreferencesCallback
        case 'checkboxUseCustomPreferencesCallback'
            set(value(myfig), 'Pointer', 'watch'); drawnow;
            if get(value(checkboxUseCustomPreferences), 'Value')
                ylabel(value(axpokesplot), '');
                SHOULD_USE_CUSTOM_PREFERENCES.value = true;
                feval(mfilename, obj, 'pokesplot_preferences_pane_callback');
            else
                TRIAL_SEQUENCE.value = 1:n_started_trials;
                INVISIBLE_TRIALS_LIST.value = [];
                SHOULD_USE_CUSTOM_PREFERENCES.value = false;
                set(value(axpokesplot), 'YTickMode', 'auto');
                ylabel(value(axpokesplot), 'Trial Number');
                if isempty(findobj(value(axpokesplot), 'UserData', 1, 'Type', 'patch', '-or', 'Type', 'line'))
                    feval(mfilename, obj, 'refresh_axpokesplot');
                else
                    feval(mfilename, obj, 'update_axpokesplot_trial_sequence');
                end
            end
            set(value(myfig), 'Pointer', 'arrow'); drawnow;
            
            
            %% CASE pokesplot_preferences_pane_callback
        case 'pokesplot_preferences_pane_callback'
            %This action is called when the user presses 'Refresh Plot' on
            %the pokesplot preferences pane.
            if get(value(checkboxUseCustomPreferences), 'Value')
                set(value(myfig), 'Pointer', 'watch');
                set(value(myfig_preferences), 'Pointer', 'watch'); drawnow;
                
                %Obtain string values, getting rid of trailing spaces
                out = regexprep(getascell(get_ghandle(editTrialSelector), 'String'), '\s+$', '');
                TrialSelector_str = cell2str(formatstr(out), '\n');
                out = regexprep(getascell(get_ghandle(editMainSort), 'String'), '\s+$', '');
                MainSort_str = cell2str(formatstr(out), '\n');
                out = regexprep(getascell(get_ghandle(editSubSort), 'String'), '\s+$', '');
                SubSort_str = cell2str(formatstr(out), '\n');
                
                handles = guihandles(value(myfig));
                
                %TRIAL_SEQUENCE: 1 to n_started_trials by default
                TRIAL_SEQUENCE.value = 1:n_started_trials;
                MAINSORT_VALUE_SEQUENCE = NaN(length(TRIAL_SEQUENCE), 1);
                SUBSORT_VALUE_SEQUENCE = NaN(length(TRIAL_SEQUENCE), 1);
                INVISIBLE_TRIALS_LIST.value = [];
                
                
                %Setting local variables, for speed
                trial_info_value = value(trial_info);
                TRIAL_SEQUENCE_value = value(TRIAL_SEQUENCE);
                INVISIBLE_TRIALS_LIST_value = value(INVISIBLE_TRIALS_LIST);
                peh_value = value(parsed_events_history);
                
                
                for ctr = 1:length(TRIAL_SEQUENCE_value)
                    trialnum = TRIAL_SEQUENCE_value(ctr);
                    if trialnum <= length(peh_value)
                        
                        %Step 1: Trial Selector
                        if isempty(strtrim(TrialSelector_str))
                            TrialSelector_str = 'true;';
                        end
                        trial_info_value(trialnum).visible = eval_pokesplot_expression(obj, TrialSelector_str, trialnum);
                        if strcmp(trial_info_value(trialnum).visible, 'ERROR')
                            trial_info_value(trialnum).visible = true;
                        end
                        if ~trial_info_value(trialnum).visible
                            INVISIBLE_TRIALS_LIST_value(end+1) = trialnum;
                        end
                        
                        
                        
                        %Step 2: Main Sort
                        if isempty(strtrim(MainSort_str))
                            MainSort_str = '0;';
                        end
                        trial_info_value(trialnum).mainsort_value = eval_pokesplot_expression(obj, MainSort_str, trialnum);
                        if ~strcmp(trial_info_value(trialnum).mainsort_value, 'ERROR')
                            MAINSORT_VALUE_SEQUENCE(ctr) = trial_info_value(trialnum).mainsort_value;
                        else
                            trial_info_value(trialnum).mainsort_value = NaN;
                        end
                        
                        
                        %Step 3: Sub Sort
                        if isempty(strtrim(SubSort_str))
                            SubSort_str = 'trialnum;';
                        end
                        trial_info_value(trialnum).subsort_value = eval_pokesplot_expression(obj, SubSort_str, trialnum);
                        if ~strcmp(trial_info_value(trialnum).subsort_value, 'ERROR')
                            SUBSORT_VALUE_SEQUENCE(ctr) = trial_info_value(trialnum).subsort_value;
                        else
                            trial_info_value(trialnum).subsort_value = NaN;
                        end
                        
                        
                    end
                end
                
                
                [MAINSORT_VALUE_SEQUENCE, indices] = sort(MAINSORT_VALUE_SEQUENCE);
                SUBSORT_VALUE_SEQUENCE = SUBSORT_VALUE_SEQUENCE(indices);
                TRIAL_SEQUENCE_value = TRIAL_SEQUENCE_value(indices);
                
                %NOW FOR SUBSORT
                %Now we divide MAINSORT_VALUE_SEQUENCE into groups,
                %i.e. extract starting and ending indices of each group
                %Subtle bug, according to MATLAB, NaN ~= NaN, which is
                %understandable, but somehow isequal(NaN, NaN) is also
                %false, and unique(MAINSORT_VALUE_SEQUENCE) treats each NaN
                %as a unique value!!!! So it is important to consider that
                
                %Here is an interesting step. We need NaNs to be
                %considered while performing the subsort operation.
                %Therefore, we identify NaNs by a unique random value,
                %which is greater than the maximum value in
                %MAINSORT_VALUE_SEQUENCE
                if isnan(max(MAINSORT_VALUE_SEQUENCE))
                    addval = 0;
                else
                    addval = max(MAINSORT_VALUE_SEQUENCE);
                end
                MAINSORT_VALUE_SEQUENCE(isnan(MAINSORT_VALUE_SEQUENCE)) = addval + rand;
                num_of_groups = length(unique(MAINSORT_VALUE_SEQUENCE));
                groupindices = zeros(num_of_groups, 2); %Starting and ending indices in the sorted MAINSORT_VALUE_SEQUENCE
                %Padding
                MAINSORT_VALUE_SEQUENCE_padded = [min(MAINSORT_VALUE_SEQUENCE)-1; MAINSORT_VALUE_SEQUENCE(:); max(MAINSORT_VALUE_SEQUENCE)+1];
                %Diff
                MAINSORT_VALUE_SEQUENCE_diff = diff(MAINSORT_VALUE_SEQUENCE_padded);
                %Inverting
                MAINSORT_VALUE_SEQUENCE_diff_inv = ~MAINSORT_VALUE_SEQUENCE_diff;
                
                groupindices(:, 1) = columnvectortransform(find(MAINSORT_VALUE_SEQUENCE_diff(1:end-1)));
                groupindices_col2 = columnvectortransform(find(MAINSORT_VALUE_SEQUENCE_diff_inv(1:end)==0))-1;
                groupindices(:, 2) = groupindices_col2(groupindices_col2 ~= 0);
                
                for ctr = 1:size(groupindices, 1)
                    TRIAL_SEQUENCE_subset = TRIAL_SEQUENCE_value(groupindices(ctr, 1):groupindices(ctr, 2));
                    [dummy, newindices] = sort(SUBSORT_VALUE_SEQUENCE(groupindices(ctr, 1):groupindices(ctr, 2)));
                    TRIAL_SEQUENCE_subset = TRIAL_SEQUENCE_subset(newindices);
                    TRIAL_SEQUENCE_value(groupindices(ctr, 1):groupindices(ctr, 2)) = TRIAL_SEQUENCE_subset;
                end
                
                
                %See whether or not collapsing is needed.
                if value(btnCollapse)
                    visible_trials_list = NaN(length(TRIAL_SEQUENCE_value) - length(INVISIBLE_TRIALS_LIST_value), 1);
                    visible_trials_ctr = 1;
                    for ctr = 1:length(TRIAL_SEQUENCE_value)
                        if ~ismember(TRIAL_SEQUENCE_value(ctr), INVISIBLE_TRIALS_LIST_value)
                            visible_trials_list(visible_trials_ctr) = TRIAL_SEQUENCE_value(ctr);
                            visible_trials_ctr = visible_trials_ctr + 1;
                        end
                    end
                    TRIAL_SEQUENCE_value = [INVISIBLE_TRIALS_LIST_value(:); visible_trials_list(:)];
                    set(handles.sliderY, 'Value', 1.0);
                    feval(mfilename, obj, 'sliderYCallback');
                end
                
                
                trial_info.value = trial_info_value;
                TRIAL_SEQUENCE.value = TRIAL_SEQUENCE_value;
                INVISIBLE_TRIALS_LIST.value = INVISIBLE_TRIALS_LIST_value;
                
                %UserData: trial number
                if isempty(findobj(value(axpokesplot), 'UserData', 1, 'Type', 'patch', '-or', 'Type', 'line'));
                    %If there is nothing on the plot
                    feval(mfilename, obj, 'refresh_axpokesplot');
                else
                    %If the plot has already been drawn, simply reorder if
                    %necessary
                    feval(mfilename, obj, 'update_axpokesplot_trial_sequence');
                end
                set(value(myfig), 'Pointer', 'arrow');
                set(value(myfig_preferences), 'Pointer', 'arrow'); drawnow;
            end
            
            
            %% CASE plotclick_action_callback
        case 'plotclick_action_callback'
            if strcmpi(value(plotclick_action), 'runs external script')
                hndlvec = [value(toggleInteractiveZoomIn);
                    value(toggleInteractiveZoomOut);
                    value(toggleInteractiveZoomRectangle);
                    value(toggleInteractivePan);
                    value(toggleInteractiveDataCursor)];
                set(hndlvec, 'Value', false);
                feval(mfilename, obj, 'toggleInteractiveZoomRectangleCallback');
                feval(mfilename, obj, 'toggleInteractivePanCallback');
                feval(mfilename, obj, 'toggleInteractiveDataCursorCallback');
            end
            
            
            %% CASE trial_limits_callback
        case 'trial_limits_callback'
            if (strcmpi(value(trial_limits), 'from, to') && value(start_trial) <= value(end_trial) || ...
                    strcmpi(value(trial_limits), 'last n') && value(ntrials) >= 1)
                if strcmpi(value(trial_limits), 'from, to')
                    hndl_list = [get_ghandle(start_trial);
                        get_ghandle(end_trial);
                        get_ghandle(textto)];
                    set(hndl_list, 'Visible', 'on');
                    set(get_ghandle(ntrials), 'Visible', 'off');
                    set(value(axpokesplot), 'YLim', [value(start_trial)-0.5 value(end_trial)+0.5]);
                    ntrials.value = value(end_trial) - value(start_trial) + 1;
                elseif strcmpi(value(trial_limits), 'last n')
                    hndl_list = [get_ghandle(start_trial);
                        get_ghandle(end_trial);
                        get_ghandle(textto)];
                    set(hndl_list, 'Visible', 'off');
                    set(get_ghandle(ntrials), 'Visible', 'on');
                    upper_limit = max(length(parsed_events_history)+1, value(ntrials));
                    lower_limit = upper_limit - value(ntrials) + 1;
                    set(value(axpokesplot), 'YLim', [lower_limit-0.5 upper_limit+0.5]);
                    start_trial.value = lower_limit; end_trial.value = upper_limit;
                end
                feval(mfilename, obj, 'refresh_sliderValues');
            end
            
            
            %% CASE sliderXCallback
        case 'sliderXCallback'
            hndl = findobj(value(myfig), 'Tag', 'sliderX');
            sliderX_value = get(hndl(1), 'Value');
            time_difference = value(t1) - value(t0);
            lower_limit = max(value(MIN_TIME), sliderX_value*(value(MAX_TIME) - time_difference - value(MIN_TIME))+value(MIN_TIME));
            upper_limit = lower_limit + time_difference;
            set(value(axpokesplot), 'XLim', [lower_limit upper_limit]);
            t0.value = lower_limit;
            t1.value = upper_limit;
            
            %% CASE sliderYCallback
        case 'sliderYCallback'
            %Step 1: Get ntrials_to_show
            if strcmpi(value(trial_limits), 'last n')
                curr_YLim = get(value(axpokesplot), 'YLim');
                end_trial.value = floor(max(curr_YLim));
                start_trial.value = ceil(min(curr_YLim));
            end
            ntrials_to_show = value(end_trial) - value(start_trial) + 1;
            
            hndl = findobj(value(myfig), 'Tag', 'sliderY');
            sliderY_value = get(hndl(1), 'Value');
            lower_limit = max(1, floor(sliderY_value*(n_started_trials)) - ntrials_to_show + 1);
            upper_limit = lower_limit + ntrials_to_show - 1;
            set(value(axpokesplot), 'YLim', [lower_limit-0.5 upper_limit+0.5]);
            start_trial.value = lower_limit;
            end_trial.value = upper_limit;
            
            ntrials.value = value(end_trial) - value(start_trial) + 1;
            
            trial_limits.value = 'from, to';
            set([get_ghandle(start_trial), get_ghandle(end_trial), get_ghandle(textto)], 'Visible', 'on');
            set(get_ghandle(ntrials), 'Visible', 'off');
            
            
            %% CASE update_axpokesplot_trial_sequence
        case 'update_axpokesplot_trial_sequence'
            %This section takes the value of the SoloParamHandle
            %TRIAL_SEQUENCE and shifts the elements on the Y axis
            %accordingly. TRIAL_SEQUENCE should ALWAYS have a total length
            %equal to length(parsed_events_history)+length(parsed_events)
            assert(length(unique(value(TRIAL_SEQUENCE)))==length(parsed_events_history)+length(parsed_events) && ...
                length(unique(value(TRIAL_SEQUENCE))) == length(TRIAL_SEQUENCE));
            
            booleanstr = {'off', 'on'};
            
            %Local copies for speed
            invisible_trials_list = value(INVISIBLE_TRIALS_LIST);
            visible_states_list = value(VISIBLE_STATES_LIST);
            visible_pokes_list = value(VISIBLE_POKES_LIST);
            visible_waves_list = value(VISIBLE_WAVES_LIST);
            spikes_visible = value(SPIKES_VISIBLE);
            TRIAL_SEQUENCE_value = value(TRIAL_SEQUENCE);
            trial_info_value = value(trial_info);
            
            for ctr = 1:length(TRIAL_SEQUENCE_value)
                %Get all handles
                handle_list = [];
                for guys = {'states', 'pokes', 'waves', 'spikes'}
                    if TRIAL_SEQUENCE_value(ctr)<=length(trial_info_value) && ...
                            isfield(trial_info_value(TRIAL_SEQUENCE_value(ctr)).ghandles, guys{1}) && ...
                            isfield(trial_info_value(TRIAL_SEQUENCE_value(ctr)).ghandles.(guys{1}), 'all_handles')
                        handle_list = [handle_list(:); trial_info_value(TRIAL_SEQUENCE_value(ctr)).ghandles.(guys{1}).all_handles(:)];
                    end
                end
                handle_list = handle_list(ishandle(handle_list));
                
                %Setting visibility
                for ctr2 = 1:length(handle_list)
                    pp_Category = getappdata(handle_list(ctr2), 'pp_Category');
                    pp_Name = getappdata(handle_list(ctr2), 'pp_Name');
                    pp_Name = regexprep(pp_Name, '\(.*\)', '');
                    isvisible = ~ismember(TRIAL_SEQUENCE_value(ctr), invisible_trials_list) && ...
                        (strcmp(pp_Category, 'state') && ismember(pp_Name, visible_states_list) || ...
                        strcmp(pp_Category, 'poke') && ismember(pp_Name, visible_pokes_list) || ...
                        strcmp(pp_Category, 'wave') && ismember(pp_Name, visible_waves_list) || ...
                        strcmp(pp_Category, 'spike') && spikes_visible);
                    set(handle_list(ctr2), 'Visible', booleanstr{double(isvisible)+1});
                end
                
                %Setting YData
                for ctr2 = 1:length(handle_list)
                    old_ydata = get(handle_list(ctr2), 'YData');
                    old_ydata_integer = round(old_ydata);
                    old_ydata_deviation = old_ydata - old_ydata_integer;
                    new_ydata = ctr*ones(size(old_ydata)) + old_ydata_deviation;
                    set(handle_list(ctr2), 'YData', new_ydata);
                end
            end
            
            
            %% CASE update_editCurrentEntity
        case 'update_editCurrentEntity'
            %Called whenever the user moves the cursor over the plot axes
            currpoint = get(value(axpokesplot), 'CurrentPoint');
            str = feval(mfilename, obj, 'get_current_entity', currpoint);
            editCurrentEntity.value = implode(str, filesep);
            
            %% CASE t1_callback, t0_callback
        case {'t1_callback', 't0_callback'}
            if value(t0) < value(t1)
                set(value(axpokesplot), 'XLim', [value(t0) value(t1)]);
                feval(mfilename, obj, 'refresh_sliderValues');
            end
            
            %% CASE start_trial_callback, end_trial_callback
        case {'start_trial_callback', 'end_trial_callback'}
            if value(start_trial) <= value(end_trial)
                ntrials.value = value(end_trial) - value(start_trial) + 1;
                set(value(axpokesplot), 'YLim', [value(start_trial)-0.5 value(end_trial)+0.5]);
                feval(mfilename, obj, 'refresh_sliderValues');
            end
            
            %% CASE ntrials_callback
        case 'ntrials_callback'
            if value(ntrials) >= 1
                upper_limit = max(n_started_trials, value(ntrials));
                lower_limit = upper_limit - value(ntrials) + 1;
                set(value(axpokesplot), 'YLim', [lower_limit-0.5 upper_limit+0.5]);
                start_trial.value = lower_limit; end_trial.value = upper_limit;
                feval(mfilename, obj, 'refresh_sliderValues');
            end
            
            %% CASE popupParsingStyleCallback
        case 'popupParsingStyleCallback'
            if strcmp(value(popupParsingStyle), 'v1 Style Parsing')
                set(get_ghandle(alignon), 'Max', 1.0, 'HorizontalAlignment', 'center');
            elseif strcmp(value(popupParsingStyle), 'v2 Style Parsing')
                set(get_ghandle(alignon), 'Max', 99999, 'HorizontalAlignment', 'left');
            end
            feval(mfilename, obj, 'alignon_callback');
            
            
            %% CASE alignon_callback
        case 'alignon_callback'
            %Called whenever a change is made to the alignon edit window.
            set(value(myfig), 'Pointer', 'watch'); drawnow;
            trial_info_val = value(trial_info);
            for ctr = 1:length(value(parsed_events_history))
                %Get all handles
                handle_list = [];
                for guys = {'states', 'pokes', 'waves', 'spikes'}
                    if isfield(trial_info(ctr).ghandles, guys{1}) && isfield(trial_info(ctr).ghandles.(guys{1}), 'all_handles')
                        handle_list = [handle_list(:); trial_info(ctr).ghandles.(guys{1}).all_handles(:)];
                    end
                end
                handle_list = handle_list(ishandle(handle_list));
                
                %Calculate XDelta
                old_align_time = trial_info_val(ctr).align_time;
                new_align_time = find_align_time(obj, value(alignon), parsed_events_history{ctr}, 'ParsingStyle', value(popupParsingStyle), 'trialnum', ctr);
                trial_info_val(ctr).align_time = new_align_time;
                XDelta = new_align_time - old_align_time;
                
                %Shift
                for ctr2 = 1:length(handle_list)
                    old_XData = get(handle_list(ctr2), 'XData');
                    set(handle_list(ctr2), 'XData', old_XData - XDelta);
                end
            end
            trial_info.value = trial_info_val;
            set(value(myfig), 'Pointer', 'arrow'); drawnow;
            
            
            %% CASE btnShowHideLegendPanelCallback
        case 'btnShowHideLegendPanelCallback'
            handles = guihandles(value(myfig));
            off_axpokesplot_position = [0.11     0.33333     0.55667     0.56339];
            legend_position = get(handles.uipanelLegend, 'Position');
            on_axpokesplot_position = off_axpokesplot_position;
            on_axpokesplot_position(3) = on_axpokesplot_position(3) + legend_position(3);
            if value(btnShowHideLegendPanel)
                set(handles.uipanelLegend, 'Visible', 'off');
                set(handles.axpokesplot, 'Position', on_axpokesplot_position);
            else
                set(handles.uipanelLegend, 'Visible', 'on');
                set(handles.axpokesplot, 'Position', off_axpokesplot_position);
            end
            
            
            
            %% CASE btnRedrawCallback
        case {'btnRedrawCallback', 'redraw'}
            %Refresh textHeader
            btnRedraw.value = false;
            if isa(obj, 'neurobrowser')
                temp = neurobrowser('get_info');
                temp.settings_file = '';
            elseif any(strcmp('SavingSection', methods(obj,'-full')))
                temp = SavingSection(obj, 'get_all_info');
            end
            SESSION_INFO.experimenter = temp.experimenter;
            SESSION_INFO.ratname = temp.ratname;
            SESSION_INFO.settings_file = temp.settings_file;
            textHeader.value = [mfilename '(' SESSION_INFO.experimenter ', ' SESSION_INFO.ratname ')'];
            
            
            %Refresh axis details
            set(value(axpokesplot), 'XLim', [value(t0) value(t1)]);
            if strcmpi(value(trial_limits), 'from, to')
                YLim = [value(start_trial) value(end_trial)];
                ntrials.value = value(end_trial) - value(start_trial) + 1;
            elseif strcmpi(value(trial_limits), 'last n')
                end_trial.value = max(n_started_trials, value(ntrials));
                start_trial.value = value(end_trial) - value(ntrials) + 1;
                YLim = [value(start_trial) value(end_trial)];
            end
            set(value(axpokesplot), 'YLim', [YLim(1)-0.5 YLim(2)+0.5]);
            
            
            %Refresh slider details
            feval(mfilename, obj, 'refresh_sliderValues');
            
            
            %Refresh colors
            if exist('STATE_COLORS', 'var') && isa(STATE_COLORS, 'SoloParamHandle')
                scolors = value(STATE_COLORS);
            elseif ismethod(obj, 'state_colors')
                scolors = state_colors(obj);
            else
                scolors = struct([]);
            end
            if exist('WAVE_COLORS', 'var') && isa(WAVE_COLORS, 'SoloParamHandle')
                wcolors = value(WAVE_COLORS);
            elseif ismethod(obj, 'wave_colors')
                wcolors = wave_colors(obj);
            else
                wcolors = struct([]);
            end
            if exist('POKE_COLORS', 'var') && isa(POKE_COLORS, 'SoloParamHandle')
                pcolors = value(POKE_COLORS);
            elseif ismethod(obj, 'poke_colors')
                pcolors = poke_colors(obj);
            else
                pcolors = default_poke_colors;
            end
            if exist('SPIKE_COLOR', 'var') && isa(SPIKE_COLOR, 'SoloParamHandle')
                spikecolor = value(SPIKE_COLOR);
            elseif ismethod(obj, 'spike_color')
                spikecolor = spike_color(obj);
            else
                spikecolor = default_spike_color;
            end
            
            STATE_COLORS.value = scolors; WAVE_COLORS.value = wcolors; POKE_COLORS.value = pcolors; SPIKE_COLOR.value = spikecolor;
            hndl_uipanelLegend(1) = findobj(value(myfig), 'Tag', 'uipanelLegend');
            show_legend(hndl_uipanelLegend(1), value(STATE_COLORS), value(WAVE_COLORS), value(POKE_COLORS));
            
            %TRIAL_SEQUENCE.value = 1:n_started_trials;
            
            PROTOCOL_DATA.value = get_protocol_data(obj);
            
            handles = guihandles(value(myfig));
            set(handles.checkboxStates, 'Value', ~isempty(value(VISIBLE_STATES_LIST)));
            set(handles.checkboxPokes, 'Value', ~isempty(value(VISIBLE_POKES_LIST)));
            set(handles.checkboxWaves, 'Value', ~isempty(value(VISIBLE_WAVES_LIST)));
            set(handles.checkboxSpikes, 'Value', value(SPIKES_VISIBLE));
            set(handles.checkboxUseCustomPreferences, 'Enable', 'on');
            
            %If pokesplot2 is being called by neurobrowser, by default we
            %would want to use the custom preferences
            if isa(obj, 'neurobrowser')
                SHOULD_USE_CUSTOM_PREFERENCES.value = true;
            end
            set(handles.checkboxUseCustomPreferences, 'Value', value(SHOULD_USE_CUSTOM_PREFERENCES));
            
            feval(mfilename, obj, 'trial_limits_callback');
            feval(mfilename, obj, 'btnShowHideLegendPanelCallback');
            
            pokesplot_preferences_pane(obj, 'reinit');
            
            cla(value(axpokesplot));
            
            %This action would draw the plot on the axes
            feval(mfilename, obj, 'checkboxUseCustomPreferencesCallback');
            
            set(get_ghandle(btnRedraw), 'Enable', 'on');
            
            
            %% CASE flush_trial_info_handles
        case 'flush_trial_info_handles'
            %Two approaches exist, both seemed to have similar speed
            %performance, but the first approach is simpler.
            
            if exist('parsed_events_history', 'var') && ~isempty(value(parsed_events_history)) && iscell(value(parsed_events_history))
                state_names = fieldnames(value(STATE_COLORS));
                poke_names = fieldnames(value(POKE_COLORS));
                wave_names = fieldnames(value(WAVE_COLORS));
                peh_val = value(parsed_events_history);
                trial_info_val = value(trial_info);
                
                for ctr = 1:length(peh_val)
                    trial_info_val(ctr).ghandles.states.all_handles = [];
                    trial_info_val(ctr).ghandles.pokes.all_handles = [];
                    trial_info_val(ctr).ghandles.waves.all_handles = [];
                    trial_info_val(ctr).ghandles.spikes.all_handles = [];
                    
                    for ctr2 = 1:length(state_names)
                        trial_info_val(ctr).ghandles.states.(state_names{ctr2}) = [];
                    end
                    for ctr2 = 1:length(poke_names)
                        trial_info_val(ctr).ghandles.pokes.(poke_names{ctr2}) = [];
                    end
                    for ctr2 = 1:length(wave_names)
                        trial_info_val(ctr).ghandles.waves.(wave_names{ctr2}) = [];
                    end
                end
                
                trial_info.value = trial_info_val;
            end
            
            
            %             if exist('parsed_events_history', 'var') && ~isempty(value(parsed_events_history)) && iscell(value(parsed_events_history))
            %                 state_name_list = fieldnames(value(STATE_COLORS));
            %                 poke_name_list = fieldnames(value(POKE_COLORS));
            %                 wave_name_list = fieldnames(value(WAVE_COLORS));
            %                 for ctr = 1:length(parsed_events_history)
            %                     if isfield(parsed_events_history{ctr}, 'spikes')
            %                         num_of_spikes = length(parsed_events_history{ctr}.spikes);
            %                     else
            %                         num_of_spikes = 0;
            %                     end
            %                     trial_info(ctr).ghandles.spikes.all_handles = NaN(num_of_spikes, 1);
            %
            %                     %Now states
            %                     for ctr2 = 1:length(state_name_list)
            %                         if isfield(parsed_events_history{ctr}.states, state_name_list{ctr2})
            %                             num_of_rows = size(parsed_events_history{ctr}.states.(state_name_list{ctr2}), 1);
            %                         else
            %                             num_of_rows = 0;
            %                         end
            %                         trial_info(ctr).ghandles.states.(state_name_list{ctr2}) = NaN(num_of_rows, 1);
            %                     end
            %
            %
            %                     %Now pokes
            %                     for ctr2 = 1:length(poke_name_list)
            %                         if isfield(parsed_events_history{ctr}.pokes, poke_name_list{ctr2})
            %                             num_of_rows = size(parsed_events_history{ctr}.pokes.(poke_name_list{ctr2}), 1);
            %                         else
            %                             num_of_rows = 0;
            %                         end
            %                         trial_info(ctr).ghandles.pokes.(poke_name_list{ctr2}) = NaN(num_of_rows, 1);
            %                     end
            %
            %
            %                     %Now waves
            %                     for ctr2 = 1:length(wave_name_list)
            %                         if isfield(parsed_events_history{ctr}.waves, wave_name_list{ctr2})
            %                             num_of_rows = size(parsed_events_history{ctr}.waves.(wave_name_list{ctr2}), 1);
            %                         else
            %                             num_of_rows = 0;
            %                         end
            %                         trial_info(ctr).ghandles.waves.(wave_name_list{ctr2}) = NaN(num_of_rows, 1);
            %                     end
            %                 end
            %             end
            
            
            %% CASE refresh_axpokesplot
        case 'refresh_axpokesplot'
            set(value(myfig), 'Pointer', 'watch');
            cla(value(axpokesplot)); drawnow;
            
            peh_adjusted = feval(mfilename, obj, 'adjust_parsed_events_history');
            feval(mfilename, obj, 'flush_trial_info_handles');
            
            %Function to display historical data only. To be used to view
            %existing data files.
            draw_events_history(value(axpokesplot), ...
                value(STATE_COLORS), ...
                value(POKE_COLORS), ...
                value(WAVE_COLORS), ...
                value(SPIKE_COLOR), ...
                value(VISIBLE_STATES_LIST), ...
                value(VISIBLE_WAVES_LIST), ...
                value(VISIBLE_POKES_LIST), ...
                value(SPIKES_VISIBLE), ...
                value(INVISIBLE_TRIALS_LIST), ...
                value(parsed_events), ...
                value(parsed_events_history), ...
                peh_adjusted, ...
                TRIAL_SEQUENCE, ...
                trial_info);
            
            
            set(value(myfig), 'Pointer', 'arrow');
            drawnow;
            
            %% CASE update
        case 'update'
            
            if PokesPlotShow==0
                return;
                % Don't update pokes plot if it is hidden
                
            end
            
            %This step is here because we wouldn't want the custom
            %preferences to slow things down while the protocol is running.
            %I'm wondering if there is a better way to do this.
            set(value(checkboxUseCustomPreferences), 'Value', false);
            SHOULD_USE_CUSTOM_PREFERENCES.value = false;
            set(value(checkboxUseCustomPreferences), 'Enable', 'off');
            
            %This step exists because the imrect method seems to suspend
            %execution.
            set(value(toggleInteractiveZoomRectangle), 'Value', false, 'Enable', 'off');
            if exist('IMRECT', 'var') && isa(value(IMRECT), 'imrect')
                try
                    resume(value(IMRECT));
                catch
                end
                try
                    s = warning('query', 'MATLAB:class:DestructorError');
                    warning('off', 'MATLAB:class:DestructorError');
                    delete(value(IMRECT));
                    warning(s.state, 'MATLAB:class:DestructorError');
                catch
                end
            end
            set(get_ghandle(btnRedraw), 'Enable', 'off');
            
            if strcmpi(value(trial_limits), 'last n')
                feval(mfilename, obj, 'trial_limits_callback');
            end
            draw_latest_events(obj, value(axpokesplot), ...
                n_started_trials, ...
                parsed_events, ...
                latest_parsed_events, ...
                value(STATE_COLORS), ...
                value(POKE_COLORS), ...
                value(WAVE_COLORS), ...
                value(VISIBLE_STATES_LIST), ...
                value(VISIBLE_POKES_LIST), ...
                value(VISIBLE_WAVES_LIST), ...
                value(INVISIBLE_TRIALS_LIST), ...
                dispatcher('get_time'), ...
                value(alignon), ...
                value(popupParsingStyle), ...
                TRIAL_SEQUENCE, ...
                trial_info);
            
            %% CASE set_alignon
        case 'set_alignon'
            %PokesPlotSection(obj, 'set_alignon', <alignon value>, <parsing style>)
            %<parsing style>: 'v1 Style Parsing' by default, or 'v2 Style
            %Parsing'
            alignon.value = varargin{1};
            if length(varargin)==2
                popupParsingStyle.value = varargin{2};
            else
                popupParsingStyle.value = 'v1 Style Parsing';
            end
            feval(mfilename, obj, 'alignon_callback');
            
            %% CASE adjust_parsed_events_history
        case 'adjust_parsed_events_history'
            %Returns parsed_events_history, but with all values of intime
            %and outtime adjusted to use align_time as the reference. Also
            %sets the SPH trial_info(trialnum).align_time for every trial
            %alignon_value = regexprep(value(alignon), '\s+', '');
            alignon_value = value(alignon);
            parsed_events_history_adjusted = value(parsed_events_history);
            state_names = fieldnames(value(STATE_COLORS));
            trial_info_val = value(trial_info);
            parsing_style = value(popupParsingStyle);
            for ctr = 1:length(parsed_events_history_adjusted)
                %First, value(alignon) can contain a value like (reward_(1,
                %end)). We need to adjust alignon_value correctly
                align_time = find_align_time(obj, alignon_value, parsed_events_history_adjusted{ctr}, 'ParsingStyle', parsing_style, 'trialnum', ctr);
                trial_info_val(ctr).align_time = align_time;
                
                
                guys = {'states', 'pokes', 'waves', 'spikes'};
                for ctr2 = 1:length(guys)
                    if isfield(parsed_events_history_adjusted{ctr}, guys{ctr2})
                        if ~strcmp(guys{ctr2}, 'spikes')
                            guys_names = fieldnames(parsed_events_history_adjusted{ctr}.(guys{ctr2}));
                            guys_names = setdiff(guys_names, {'starting_state', 'ending_state'});
                            %guys_names(strcmp('starting_state', guys_names)) = [];
                            %guys_names(strcmp('ending_state', guys_names)) = [];
                            for ctr3 = 1:length(guys_names)
                                %subtract subtract_time
                                %Note: NaN - x = NaN, [] - x = [], x is a
                                %number
                                parsed_events_history_adjusted{ctr}.(guys{ctr2}).(guys_names{ctr3}) = ...
                                    parsed_events_history_adjusted{ctr}.(guys{ctr2}).(guys_names{ctr3}) - align_time;
                            end
                        else
                            parsed_events_history_adjusted{ctr}.(guys{ctr2}) = ...
                                parsed_events_history_adjusted{ctr}.(guys{ctr2}) - align_time;
                        end
                    end
                end
            end
            
            trial_info.value = trial_info_val;
            
            varargout{1} = parsed_events_history_adjusted;
            
            %% CASE trial_completed
        case 'trial_completed'
            
            
            %% CASE close
        case 'close'
            pokesplot_preferences_pane(obj, 'close');
            if exist('myfig', 'var') && isa(myfig, 'SoloParamHandle') && ishandle(value(myfig))
                delete(value(myfig));
            end
            clear(mfilename);
            
            %% CASE hide
        case 'hide'
            set(value(myfig), 'Visible', 'off');
            PokesPlotShow.value = false;
            
            %% CASE show
        case 'show'
            set(value(myfig), 'Visible', 'on');
            PokesPlotShow.value = true;
            feval(mfilename, obj, 'redraw');
            
            %% CASE show_hide
        case 'show_hide'
            if value(PokesPlotShow) %#ok<NODEF>
                feval(mfilename, obj, 'show');
            else
                feval(mfilename, obj, 'hide');
            end
            
            %% OTHERWISE
        otherwise
            error(['Unknown action ' action]);
    end
    
    
catch
    showerror;
end

end



%% FUNCTION show_legend %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function varargout = show_legend(varargin)
%SHOW_LEGEND: Displays the legend information on the pokesplot window
%   e.g. show_legend(parent_hndl, scolors, wcolors, pcolors)

parent_hndl = varargin{1};
scolors = varargin{2};
wcolors = varargin{3};
pcolors = varargin{4};
state_names = fieldnames(scolors);
wave_names = fieldnames(wcolors);
poke_names = fieldnames(pcolors);

delete(get(parent_hndl, 'Children'));

number_of_legend_objects = length(state_names) + ...
    length(wave_names) + ...
    length(poke_names);

%Some free parameters
x_box = 0.1;
width_box = 0.15;
height_box = (1/(number_of_legend_objects+2))*0.95;
x_label = x_box+width_box+0.05;
width_label = 0.6;
height_label = height_box;
y = 0;

uicontrol_params = {'Parent', parent_hndl, ...
    'Units', 'normalized', ...
    'Style', 'text'};

for ctr = 1:number_of_legend_objects
    y = y + height_box/0.95;
    if ctr>=1 && ctr<=length(state_names)
        %States
        backgroundcolor = scolors.(state_names{ctr});
        string = state_names{ctr};
        type = 'state';
    elseif ctr>length(state_names) && ctr<=length(state_names)+length(wave_names)
        %Waves
        backgroundcolor = wcolors.(wave_names{ctr-length(state_names)});
        string = wave_names{ctr-length(state_names)};
        type = 'wave';
    elseif ctr>length(state_names)+length(wave_names) && ctr<=number_of_legend_objects
        %Pokes
        backgroundcolor = pcolors.(poke_names{ctr-length(state_names)-length(wave_names)});
        string = poke_names{ctr-length(state_names)-length(wave_names)};
        type = 'poke';
    end
    uicontrol(uicontrol_params{:}, ...
        'BackgroundColor', backgroundcolor, ...
        'TooltipString', [type ': ' string], ...
        'Position', [x_box y width_box height_box]);
    uicontrol(uicontrol_params{:}, ...
        'String', string, ...
        'TooltipString', [type ': ' string], ...
        'HorizontalAlignment', 'left', ...
        'Position', [x_label y width_label height_label]);
end

end

%% FUNCTION draw_events_history %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function sph_trial_info = draw_events_history(axes_handle, ...
    STATE_COLORS, ...
    POKE_COLORS, ...
    WAVE_COLORS, ...
    SPIKE_COLOR, ...
    VISIBLE_STATES_LIST, ...
    VISIBLE_WAVES_LIST, ...
    VISIBLE_POKES_LIST, ...
    SPIKES_VISIBLE, ...
    INVISIBLE_TRIALS_LIST, ...
    pe, ...
    peh, ...
    peh_adjusted, ...
    sph_TRIAL_SEQUENCE, ...
    sph_trial_info)

%DRAW_EVENTS_HISTORY: Function to display historical data from a data file
%on the PokesPlotSection axes.
%
% sph_trial_info = draw_events_history(axes_handle, ...
%     STATE_COLORS, ...
%     POKE_COLORS, ...
%     WAVE_COLORS, ...
%     SPIKE_COLOR, ...
%     VISIBLE_STATES_LIST, ...
%     VISIBLE_WAVES_LIST, ...
%     VISIBLE_POKES_LIST, ...
%     SPIKES_VISIBLE, ...
%     INVISIBLE_TRIALS_LIST, ...
%     pe, ...
%     peh, ...
%     peh_adjusted, ...
%     sph_TRIAL_SEQUENCE, ...
%     sph_trial_info)
%
%   axes_handle: Axes handle on which the data is to be displayed
%
%   STATE_COLORS, POKE_COLORS, WAVE_COLORS, SPIKE_COLOR: Entity colours
%
%   VISIBLE_STATES_LIST, VISIBLE_POKES_LIST, VISIBLE_WAVES_LIST,
%   SPIKES_VISIBLE, INVISIBLE_TRIALS_LIST: Keep in mind that
%   INVISIBLE_TRIALS_LIST overrides all other visibility variables.
%
%   pe, peh, peh_adjusted: parsed_events, parsed_events_history,
%   parsed_events_history_adjusted (to set the reference to align_time)
%
%   sph_TRIAL_SEQUENCE: TRIAL_SEQUENCE SoloParamHandle
%
%   sph_trial_info: trial_info SoloParamHandle
%
%   Notes:
%   1. Every state and poke drawn is a patch object with additional appdata
%   pp_Name, pp_Category, pp_StartTime, pp_StopTime, pp_TrialNumber.
%   2. Every wave is a line object with the same appdata as states and
%   pokes.
%   3. A complete set of spikes for every trial is really a single line
%   object with appdata pp_Category and pp_Name. The others are not
%   applicable since a single line object is being used.

%For speed, we make a local copy. This actually makes a substantial
%difference. The load time for a data file with 549 trials and spiking data
%was reduced from around 45 seconds to around 13 seconds because of this
%step.
trial_info_value = value(sph_trial_info);

%ZData: This ensures that elements are displayed in the following order:
%states, pokes, waves, spikes
ZData_states = [0 0 0 0].';
ZData_pokes = ZData_states + 1;
ZData_waves = ZData_pokes(1:2) + 1;
ZData_spikes = ZData_waves + 1;

if isempty(value(sph_TRIAL_SEQUENCE))
    sph_TRIAL_SEQUENCE.value = (1:length(peh_adjusted)).';
end
TRIAL_SEQUENCE_val = value(sph_TRIAL_SEQUENCE);

%Pay attention to this assertion, it is very important.
assert(length(unique(TRIAL_SEQUENCE_val)) == length(peh_adjusted)+length(pe) && length(unique(TRIAL_SEQUENCE_val)) == length(TRIAL_SEQUENCE_val));


for ctr = 1:length(TRIAL_SEQUENCE_val)
    if ismember(TRIAL_SEQUENCE_val(ctr), INVISIBLE_TRIALS_LIST)
        trial_info_value(TRIAL_SEQUENCE_val(ctr)).visible = false;
    else
        trial_info_value(TRIAL_SEQUENCE_val(ctr)).visible = true;
    end
end

booleanstr = {'off', 'on'};

state_name_list = fieldnames(STATE_COLORS);
poke_name_list = fieldnames(POKE_COLORS);
wave_name_list = fieldnames(WAVE_COLORS);

waitbar_hndl = waitbar(0, ['Updating ' mfilename '...'], 'Pointer', 'watch', 'CloseRequestFcn', '');


for ctr = 1:length(peh_adjusted) %Looping over each trial
    
    actual_trial_number = TRIAL_SEQUENCE_val(ctr);
    
    eval(['trial_info_value(actual_trial_number).start_time = peh{actual_trial_number}.states.' peh{actual_trial_number}.states.starting_state '(1, end);']);
    
    guys = {'states', 'pokes', 'waves', 'spikes'};
    for ctr2 = 1:length(guys) %Looping over each guy
        
        if isfield(peh_adjusted{actual_trial_number}, guys{ctr2})
            %proceed
            
            switch guys{ctr2}
                
                case 'states'
                    %draw states
                    trial_info_value(actual_trial_number).ghandles.states.all_handles = [];
                    for ctr3 = 1:length(state_name_list)
                        if isfield(peh_adjusted{actual_trial_number}.states, state_name_list{ctr3})
                            isvisible = ismember(state_name_list{ctr3}, VISIBLE_STATES_LIST) && ~ismember(actual_trial_number, INVISIBLE_TRIALS_LIST);
                            isvisible = booleanstr{double(isvisible)+1};
                            num_of_rows = size(peh_adjusted{actual_trial_number}.states.(state_name_list{ctr3}), 1);
                            for ctr4 = 1:num_of_rows; %Looping over each row of guyname
                                %if ~isempty(peh_adjusted{actual_trial_number}.states.(state_name_list{ctr3}))
                                intime = peh_adjusted{actual_trial_number}.states.(state_name_list{ctr3})(ctr4, 1);
                                outtime = peh_adjusted{actual_trial_number}.states.(state_name_list{ctr3})(ctr4, 2);
                                if isnan(intime)
                                    startstate = peh_adjusted{actual_trial_number}.states.starting_state;
                                    if ~isempty(startstate)
                                        eval(['intime = peh_adjusted{actual_trial_number}.states.' startstate '(1, end);']);
                                    end
                                end
                                if isnan(outtime)
                                    endstate = peh_adjusted{actual_trial_number}.states.ending_state;
                                    if ~isempty(endstate)
                                        eval(['outtime = peh_adjusted{actual_trial_number}.states.' endstate '(end, 1);']);
                                    end
                                end
                                if ~isnan(intime) && ~isnan(outtime) && outtime > intime
                                    %UserData: Trial Number
                                    if ~isfield(trial_info_value(actual_trial_number).ghandles.states, state_name_list{ctr3}) || ...
                                            length(trial_info_value(actual_trial_number).ghandles.states.(state_name_list{ctr3}))<ctr4 || ...
                                            ~ishandle(trial_info_value(actual_trial_number).ghandles.states.(state_name_list{ctr3})(ctr4))
                                        rectangle_hndl = patch([intime outtime outtime intime], [ctr-0.5*TOTAL_WIDTH ctr-0.5*TOTAL_WIDTH ctr+0.5*TOTAL_WIDTH ctr+0.5*TOTAL_WIDTH], STATE_COLORS.(state_name_list{ctr3}), ...
                                            'Parent', axes_handle, ...
                                            'HitTest', 'off', ...
                                            'FaceColor', STATE_COLORS.(state_name_list{ctr3}), ...
                                            'EdgeColor', STATE_COLORS.(state_name_list{ctr3}), ...
                                            'UserData', actual_trial_number, ...
                                            'ZData', ZData_states, ...
                                            'Visible', isvisible);
                                        setappdata(rectangle_hndl, 'pp_Category', 'state');
                                        setappdata(rectangle_hndl, 'pp_TrialNumber', actual_trial_number);
                                        setappdata(rectangle_hndl, 'pp_Name', state_name_list{ctr3});
                                        setappdata(rectangle_hndl, 'pp_StartTime', intime);
                                        setappdata(rectangle_hndl, 'pp_StopTime', outtime);
                                        trial_info_value(actual_trial_number).ghandles.states.(state_name_list{ctr3})(ctr4) = rectangle_hndl;
                                    end
                                end
                                %end
                            end
                        end
                        trial_info_value(actual_trial_number).ghandles.states.(state_name_list{ctr3})(trial_info_value(actual_trial_number).ghandles.states.(state_name_list{ctr3})==0) = NaN;
                        append_handle_list = trial_info_value(actual_trial_number).ghandles.states.(state_name_list{ctr3});
                        append_handle_list = append_handle_list(ishandle(append_handle_list));
                        trial_info_value(actual_trial_number).ghandles.states.all_handles = [trial_info_value(actual_trial_number).ghandles.states.all_handles(:); ...
                            append_handle_list(:)];
                    end
                    
                case 'pokes'
                    %draw pokes
                    trial_info_value(actual_trial_number).ghandles.pokes.all_handles = [];
                    for ctr3 = 1:length(poke_name_list)
                        offset = get_poke_offset(poke_name_list{ctr3});
                        if isfield(peh_adjusted{actual_trial_number}.pokes, poke_name_list{ctr3}) && isfield(trial_info_value(actual_trial_number).ghandles.pokes, poke_name_list{ctr3})
                            isvisible = ismember(poke_name_list{ctr3}, VISIBLE_POKES_LIST) && ~ismember(actual_trial_number, INVISIBLE_TRIALS_LIST);
                            isvisible = booleanstr{double(isvisible)+1};
                            num_of_rows = size(peh_adjusted{actual_trial_number}.pokes.(poke_name_list{ctr3}), 1);
                            for ctr4 = 1:num_of_rows
                                %if ~isempty(peh_adjusted{actual_trial_number}.pokes.(poke_name_list{ctr3}))
                                intime = peh_adjusted{actual_trial_number}.pokes.(poke_name_list{ctr3})(ctr4, 1);
                                outtime = peh_adjusted{actual_trial_number}.pokes.(poke_name_list{ctr3})(ctr4, 2);
                                if isnan(intime)
                                    startstate = peh_adjusted{actual_trial_number}.states.starting_state;
                                    if ~isempty(startstate)
                                        eval(['intime = peh_adjusted{actual_trial_number}.states.' startstate '(1, end);']);
                                    end
                                end
                                if isnan(outtime)
                                    endstate = peh_adjusted{actual_trial_number}.states.ending_state;
                                    if ~isempty(endstate)
                                        eval(['outtime = peh_adjusted{actual_trial_number}.states.' endstate '(end, 1);']);
                                    end
                                end
                                if ~isnan(intime) && ~isnan(outtime) && outtime > intime
                                    %UserData: Trial Number
                                    if ~isfield(trial_info_value(actual_trial_number).ghandles.pokes, poke_name_list{ctr3}) || ...
                                            length(trial_info_value(actual_trial_number).ghandles.pokes.(poke_name_list{ctr3}))<ctr4 || ...
                                            ~ishandle(trial_info_value(actual_trial_number).ghandles.pokes.(poke_name_list{ctr3})(ctr4))
                                        rectangle_hndl = patch([intime outtime outtime intime], [ctr+offset ctr+offset ctr+offset+POKE_WIDTH ctr+offset+POKE_WIDTH], POKE_COLORS.(poke_name_list{ctr3}), ...
                                            'Parent', axes_handle, ...
                                            'HitTest', 'off', ...
                                            'FaceColor', POKE_COLORS.(poke_name_list{ctr3}), ...
                                            'EdgeColor', POKE_COLORS.(poke_name_list{ctr3}), ...
                                            'UserData', actual_trial_number, ...
                                            'ZData', ZData_pokes, ...
                                            'Visible', isvisible);
                                        setappdata(rectangle_hndl, 'pp_Category', 'poke');
                                        setappdata(rectangle_hndl, 'pp_TrialNumber', actual_trial_number);
                                        setappdata(rectangle_hndl, 'pp_Name', poke_name_list{ctr3});
                                        setappdata(rectangle_hndl, 'pp_StartTime', intime);
                                        setappdata(rectangle_hndl, 'pp_StopTime', outtime);
                                        trial_info_value(actual_trial_number).ghandles.pokes.(poke_name_list{ctr3})(ctr4) = rectangle_hndl;
                                    end
                                end
                                %end
                            end
                        end
                        trial_info_value(actual_trial_number).ghandles.pokes.(poke_name_list{ctr3})(trial_info_value(actual_trial_number).ghandles.pokes.(poke_name_list{ctr3})==0) = NaN;
                        append_handle_list = trial_info_value(actual_trial_number).ghandles.pokes.(poke_name_list{ctr3});
                        append_handle_list = append_handle_list(ishandle(append_handle_list));
                        trial_info_value(actual_trial_number).ghandles.pokes.all_handles = [trial_info_value(actual_trial_number).ghandles.pokes.all_handles(:); ...
                            append_handle_list(:)];
                    end
                    
                    
                case 'waves'
                    %draw waves
                    trial_info_value(actual_trial_number).ghandles.waves.all_handles = [];
                    for ctr3 = 1:length(wave_name_list)
                        if isfield(peh_adjusted{actual_trial_number}, 'waves') && isfield(peh_adjusted{actual_trial_number}.waves, wave_name_list{ctr3})
                            isvisible = ismember(wave_name_list{ctr3}, VISIBLE_WAVES_LIST) && ~ismember(actual_trial_number, INVISIBLE_TRIALS_LIST);
                            isvisible = booleanstr{double(isvisible)+1};
                            num_of_rows = size(peh_adjusted{actual_trial_number}.waves.(wave_name_list{ctr3}), 1);
                            for ctr4 = 1:num_of_rows; %Looping over each row of guyname
                                %if ~isempty(peh_adjusted{actual_trial_number}.waves.(wave_name_list{ctr3}))
                                intime = peh_adjusted{actual_trial_number}.waves.(wave_name_list{ctr3})(ctr4, 1);
                                outtime = peh_adjusted{actual_trial_number}.waves.(wave_name_list{ctr3})(ctr4, 2);
                                if isnan(intime)
                                    startstate = peh_adjusted{actual_trial_number}.states.starting_state;
                                    if ~isempty(startstate)
                                        eval(['intime = peh_adjusted{actual_trial_number}.states.' startstate '(1, end);']);
                                    end
                                end
                                if isnan(outtime)
                                    endstate = peh_adjusted{actual_trial_number}.states.ending_state;
                                    if ~isempty(endstate)
                                        eval(['outtime = peh_adjusted{actual_trial_number}.states.' endstate '(end, 1);']);
                                    end
                                end
                                if ~isnan(intime) && ~isnan(outtime) && outtime > intime
                                    %UserData: Trial Number
                                    if ~isfield(trial_info_value(actual_trial_number).ghandles.waves, wave_name_list{ctr3}) || ...
                                            length(trial_info_value(actual_trial_number).ghandles.waves.(wave_name_list{ctr3}))<ctr4 || ...
                                            ~ishandle(trial_info_value(actual_trial_number).ghandles.waves.(wave_name_list{ctr3})(ctr4))
                                        ydata = get_wave_ydata(ctr, wave_name_list{ctr3}, WAVE_COLORS);
                                        line_hndl = line([intime outtime], [ydata ydata], 'Parent', axes_handle, ...
                                            'UserData', actual_trial_number, ...
                                            'Visible', isvisible, ...
                                            'HitTest', 'off', ...
                                            'LineWidth', WAVE_WIDTH, ...
                                            'ZData', ZData_waves, ...
                                            'Color', WAVE_COLORS.(wave_name_list{ctr3}));
                                        setappdata(line_hndl, 'pp_Category', 'wave');
                                        setappdata(line_hndl, 'pp_TrialNumber', actual_trial_number);
                                        setappdata(line_hndl, 'pp_Name', [wave_name_list{ctr3} '(sustain)']);
                                        setappdata(line_hndl, 'pp_StartTime', intime);
                                        setappdata(line_hndl, 'pp_StopTime', outtime);
                                        trial_info_value(actual_trial_number).ghandles.waves.(wave_name_list{ctr3})(ctr4) = line_hndl;
                                    end
                                end
                                %end
                            end
                        end
                        trial_info_value(actual_trial_number).ghandles.waves.(wave_name_list{ctr3})(trial_info_value(actual_trial_number).ghandles.waves.(wave_name_list{ctr3})==0) = NaN;
                        append_handle_list = trial_info_value(actual_trial_number).ghandles.waves.(wave_name_list{ctr3});
                        append_handle_list = append_handle_list(ishandle(append_handle_list));
                        trial_info_value(actual_trial_number).ghandles.waves.all_handles = [trial_info_value(actual_trial_number).ghandles.waves.all_handles(:); ...
                            append_handle_list(:)];
                    end
                    
                    
                case 'spikes'
                    %draw spikes
                    if isfield(peh_adjusted{actual_trial_number}, 'spikes')
                        num_of_spikes = length(peh_adjusted{actual_trial_number}.spikes);
                        isvisible = value(SPIKES_VISIBLE) && ~ismember(actual_trial_number, INVISIBLE_TRIALS_LIST);
                        isvisible = booleanstr{double(isvisible)+1};
                        line_XData = NaN(3, num_of_spikes);
                        line_YData = NaN(3, num_of_spikes);
                        for ctr3 = 1:num_of_spikes
                            %if ~isempty(peh_adjusted{actual_trial_number}.spikes)
                            intime = peh_adjusted{actual_trial_number}.spikes(ctr3);
                            outtime = intime;
                            if ~isnan(intime) && ~isnan(outtime)
                                line_XData(1:2, ctr3) = [intime; outtime];
                                line_YData(1:2, ctr3) = [ctr-0.5*TOTAL_WIDTH; ctr+0.5*TOTAL_WIDTH];
                            end
                            %end
                        end
                        
                        line_hndl = line('XData', line_XData(:), 'YData', line_YData(:), 'Parent', axes_handle, ...
                            'UserData', actual_trial_number, ...
                            'Visible', isvisible, ...
                            'Color', SPIKE_COLOR, ...
                            'HitTest', 'off', ...
                            'ZData', ZData_spikes(1)*ones(size(line_YData(:))));
                        setappdata(line_hndl, 'pp_Category', 'spike');
                        setappdata(line_hndl, 'pp_TrialNumber', actual_trial_number);
                        setappdata(line_hndl, 'pp_Name', 'spike');
                        %setappdata(line_hndl, 'pp_StartTime', intime);
                        %setappdata(line_hndl, 'pp_StopTime', outtime);
                        trial_info_value(actual_trial_number).ghandles.spikes.all_handles = line_hndl;
                        
                    end
                    
                    
                otherwise
                    %do nothing
                    
            end
        end
        
    end
    
    if mod(ctr, 100)==0 || ctr==length(peh_adjusted)
        waitbar(ctr/length(peh_adjusted), waitbar_hndl);
    end
    
end

sph_trial_info.value = trial_info_value;

delete(waitbar_hndl);

end

%% FUNCTION default_poke_colors %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function pcolors = default_poke_colors
%Default poke colors
pcolors.C = [0 0 0];
pcolors.L = 0.6*[1 0.66 0];
pcolors.R = 0.9*[1 0.66 0];
pcolors.c = [0 1 0];
pcolors.l = [1 0 0];
pcolors.r = [0 0 1];

end

function spike_color = default_spike_color
%Default spike color
spike_color = [0 0 0];

end


function ydata = get_wave_ydata(trialnum, wave_name, WAVE_COLORS)
%Function to obtain the ydata for each wave being drawn
wave_name_index = find(strcmp(wave_name, fieldnames(WAVE_COLORS)));
num_of_waves = length(fieldnames(WAVE_COLORS));

bin_width = TOTAL_WIDTH/(num_of_waves + 1);

ydata = (trialnum-0.5*TOTAL_WIDTH) + bin_width*wave_name_index;

end


%% FUNCTION is_point_in_rectangle %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function varargout = is_point_in_rectangle(currpoint, rectangle_handle, varargin)
%IS_POINT_IN_RECTANGLE: Checks whether or not a given point is contained
%inside a rectangle (which is actually a patch object in this case).
%   OUT = IS_POINT_IN_RECTANGLE(currpoint, rectangle_handle, varargin)
%
%   RECTANGLE_HANDLE - Handle to the rectangle object
%
%   OUT - true/false
%
%   vararing pairs: 'XOnly', false (default). If set to true, the function
%   only verifies whether the cursor X coordinate is between the X
%   coordinates of the rectangle.
%
%   Convention: Every element on the pokesplot is a patch object or a line object. The
%   appdata pp_Name is the state/poke/wave name, or simply 'spike'. The
%   pp_Category field should contain the entity type which could be one of
%   'state', 'poke', 'wave', 'spike'. Display priority is:
%   1. spike
%   2. wave
%   3. poke
%   4. state i.e. spikes overlap waves overlap pokes overlap states
%
%   This function checks whether or not

pairs = {'XOnly', false};
parseargs(varargin, pairs);

x_subject = currpoint(1);
y_subject = currpoint(2);

rectangle_XData = get(rectangle_handle, 'XData');
rectangle_YData = get(rectangle_handle, 'YData');
if ~isempty(rectangle_XData) && ~isempty(rectangle_YData)
    x1 = rectangle_XData(1); x2 = rectangle_XData(2);
    y1 = rectangle_YData(1); y2 = rectangle_YData(3);

    switch XOnly
        case false
            out = x_subject >= x1 && x_subject < x2 && y_subject >= y1 && y_subject < y2;
        case true
            out = x_subject >= x1 && x_subject < x2;
    end
else
    out = false;
end

varargout{1} = out;

end

function varargout = is_point_in_line(currpoint, line_handle, varargin)
%Similar to is_point_in_rectangle, but checks lines instead.
pairs = {'XOnly', false};
parseargs(varargin, pairs);
x_subject = currpoint(1); y_subject = currpoint(2);

line_XData = get(line_handle, 'XData');
line_YData = get(line_handle, 'YData');
if ~isempty(line_XData) && ~isempty(line_YData)
    switch XOnly
        case false
            out = x_subject >= line_XData(1) && x_subject < line_XData(2) && y_subject >= line_YData(1) && y_subject <= line_YData(2);
        case true
            out = x_subject >= line_XData(1) && x_subject < line_XData(2);
    end
else
    out = false;
end
varargout{1} = out;
end


function offset = get_poke_offset(pokename)

switch pokename
    case 'C'
        %Center
        offset = -POKE_WIDTH*0.5;
    case 'L'
        %Top
        offset = TOTAL_WIDTH*0.5 - POKE_WIDTH;
    case 'R'
        %Bottom
        offset = -TOTAL_WIDTH*0.5;
    otherwise
        %Center
        offset = -POKE_WIDTH*0.5;
end

end

function out = TOTAL_WIDTH
%Total width of each patch object representing a state
out = 0.9;
end

function out = POKE_WIDTH
out = 0.1;
end

function out = WAVE_WIDTH
out = 1.5;
end

%% FUNCTION draw_latest_events %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function draw_latest_events(obj, axes_handle, ...
    trialnum, ...
    pe, ...
    lpe, ...
    STATE_COLORS, ...
    POKE_COLORS, ...
    WAVE_COLORS, ...
    VISIBLE_STATES_LIST, ...
    VISIBLE_POKES_LIST, ...
    VISIBLE_WAVES_LIST, ...
    INVISIBLE_TRIALS_LIST, ...
    currtime, ...
    alignon_value, ...
    parsing_style, ...
    sph_TRIAL_SEQUENCE, ...
    sph_trial_info)

persistent old_align_time;
persistent curr_state_handle; %Only one state at any given instant
persistent curr_poke_handles; %Can have multiple pokes at any given instant
persistent curr_wave_handles; %Can have multiple waves at any given instant
persistent previous_trialnum;

%% LOCAL COPY OF sph_trial_info, for speed
trial_info_value = value(sph_trial_info);
%%

ZData_states = [0 0 0 0].';
ZData_pokes = ZData_states + 1;
ZData_waves = ZData_pokes(1:2) + 1;

state_names = fieldnames(STATE_COLORS);
poke_names = fieldnames(POKE_COLORS);
wave_names = fieldnames(WAVE_COLORS);
booleanstr = {'off', 'on'};
%alignon_value = regexprep(alignon_value, '\s+', '');

if isempty(old_align_time) || ~isequal(previous_trialnum, trialnum)
    eval(['old_align_time = pe.states.' pe.states.starting_state '(1, end);']);
end


%Updating sph_TRIAL_SEQUENCE if necessary
if ~isequal(previous_trialnum, trialnum)
    sph_TRIAL_SEQUENCE.value = 1:trialnum;
end


%Updating previous_trialnum
previous_trialnum = trialnum;


if length(trial_info_value) < trialnum
    trial_info_value(trialnum).ghandles = struct('states', [], 'pokes', [], 'waves', [], 'spikes', []);
    trial_info_value(trialnum).ghandles.states.all_handles = [];
    trial_info_value(trialnum).ghandles.pokes.all_handles = [];
    trial_info_value(trialnum).ghandles.waves.all_handles = [];
    trial_info_value(trialnum).ghandles.spikes.all_handles = [];
    for ctr = 1:length(state_names)
        trial_info_value(trialnum).ghandles.states.(state_names{ctr}) = [];
    end
    for ctr = 1:length(poke_names)
        trial_info_value(trialnum).ghandles.pokes.(poke_names{ctr}) = [];
    end
    for ctr = 1:length(wave_names)
        trial_info_value(trialnum).ghandles.waves.(wave_names{ctr}) = [];
    end
    
    eval(['trial_info_value(trialnum).start_time = pe.states.' pe.states.starting_state '(1, end);']);
end


%% Setting align time%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
align_time = find_align_time(obj, alignon_value, pe, 'ParsingStyle', parsing_style, 'trialnum', trialnum);
trial_info_value(trialnum).align_time = align_time;
if ~isequal(align_time, old_align_time)
    %Align graphics elements
    handle_list = trial_info_value(trialnum).ghandles.states.all_handles;
    handle_list = handle_list(ishandle(handle_list));
    for ctr = 1:length(handle_list)
        pos = get(handle_list(ctr), 'XData');
        new_intime = pos(1) + old_align_time - align_time;
        new_outtime = pos(2) + old_align_time - align_time;
        set(handle_list(ctr), 'XData', [new_intime new_outtime new_outtime new_intime]);
        setappdata(handle_list(ctr), 'pp_StartTime', new_intime);
        if ~isnan(getappdata(handle_list(ctr), 'pp_StopTime'))
            setappdata(handle_list(ctr), 'pp_StopTime', new_outtime);
        end
    end
    
    
    handle_list = trial_info_value(trialnum).ghandles.pokes.all_handles;
    handle_list = handle_list(ishandle(handle_list));
    for ctr = 1:length(handle_list)
        pos = get(handle_list(ctr), 'XData');
        new_intime = pos(1) + old_align_time - align_time;
        new_outtime = pos(2) + old_align_time - align_time;
        set(handle_list(ctr), 'XData', [new_intime new_outtime new_outtime new_intime]);
        setappdata(handle_list(ctr), 'pp_StartTime', new_intime);
        if ~isnan(getappdata(handle_list(ctr), 'pp_StopTime'))
            setappdata(handle_list(ctr), 'pp_StopTime', new_outtime);
        end
    end
    
    
    handle_list = trial_info_value(trialnum).ghandles.waves.all_handles;
    handle_list = handle_list(ishandle(handle_list));
    for ctr = 1:length(handle_list)
        XData = get(handle_list(ctr), 'XData');
        new_intime = XData(1) + old_align_time - align_time;
        new_outtime = XData(2) + old_align_time - align_time;
        XData = [new_intime new_outtime];
        set(handle_list(ctr), 'XData', XData);
        setappdata(handle_list(ctr), 'pp_StartTime', new_intime);
        if ~isnan(getappdata(handle_list(ctr), 'pp_StopTime'))
            setappdata(handle_list(ctr), 'pp_StopTime', new_outtime);
        end
    end
end
old_align_time = align_time;



%% States%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
empty_current_state_handle = false;
if ~isempty(curr_state_handle) && get(curr_state_handle, 'UserData')==trialnum
    state_name = getappdata(curr_state_handle, 'pp_Name');
    intime = getappdata(curr_state_handle, 'pp_StartTime');
    if ~isempty(lpe.states.(state_name))
        outtime = lpe.states.(state_name)(1, end) - align_time;
    else
        outtime = NaN;
    end
    if isnan(outtime)
        outtime = currtime - align_time;
        pp_StopTime = NaN;
    else
        pp_StopTime = outtime;
    end
    if outtime > intime
        set(curr_state_handle, 'XData', [intime outtime outtime intime]);
        setappdata(curr_state_handle, 'pp_StartTime', intime);
        setappdata(curr_state_handle, 'pp_StopTime', pp_StopTime);
        if ~isnan(pp_StopTime)
            empty_current_state_handle = true;
        end
    end
end
for ctr = 1:length(state_names)
    if isfield(lpe.states, state_names{ctr}) && ~isempty(lpe.states.(state_names{ctr}))
        if ~isfield(trial_info_value(trialnum).ghandles.states, state_names{ctr})
            trial_info_value(trialnum).ghandles.states.(state_names{ctr}) = zeros(0, 1);
        end
        isvisible = ismember(state_names{ctr}, VISIBLE_STATES_LIST) && ~ismember(trialnum, INVISIBLE_TRIALS_LIST);
        isvisible = booleanstr{double(isvisible)+1};
        for ctr2 = 1:size(lpe.states.(state_names{ctr}), 1)
            intime = lpe.states.(state_names{ctr})(ctr2, 1) - align_time;
            outtime = lpe.states.(state_names{ctr})(ctr2, end) - align_time;
            if isnan(intime)
                state_subset = pe.states.(state_names{ctr})(1:end-size(lpe.states.(state_names{ctr}), 1)+ctr2, 1);
                index = find(~isnan(state_subset), 1, 'last');
                if ~isempty(index)
                    intime = pe.states.(state_names{ctr})(index, 1) - align_time;
                else
                    eval(['intime = pe.states.' pe.states.starting_state '(1, end) - align_time;']);
                end
            end
            pp_StartTime = intime;
            if isnan(outtime)
                pp_StopTime = NaN;
                outtime = currtime - align_time;
            else
                pp_StopTime = outtime;
            end
            %Sundeep Tuteja: 2010-04-15: Here, if the state we're drawing
            %is starting_state or ending_state, intime = outtime (i.e. it
            %should not be drawn).
            if strcmp('state_0', state_names{ctr}) && isnan(pp_StartTime) && ~isnan(pp_StopTime)
                intime = outtime;
            elseif strcmp('state_0', state_names{ctr}) && isnan(pp_StopTime) && ~isnan(pp_StartTime)
                outtime = intime;
            end
            assert(~isnan(intime) && ~isnan(outtime));
            if ~isnan(intime) && ~isnan(outtime) && outtime > intime
                
                
                %Has this rectangle already been drawn or is it being drawn
                handle_list = trial_info_value(trialnum).ghandles.states.all_handles;
                handle_list = handle_list(ishandle(handle_list));
                already_drawn = false;
                %Find a handle with pp_Name == current_state_name and
                %XData==Desired xdata
                for handle_ctr = 1:length(handle_list)
                    current_state = getappdata(handle_list(handle_ctr), 'pp_Name');
                    current_XData = get(handle_list(handle_ctr), 'XData');
                    if strcmp(current_state, state_names{ctr}) && isequal(current_XData(:), [intime outtime outtime intime]')
                        already_drawn = true;
                        break;
                    end
                end
                
                if ~already_drawn
                    rectangle_hndl = patch([intime outtime outtime intime], [trialnum-0.5*TOTAL_WIDTH trialnum-0.5*TOTAL_WIDTH trialnum+0.5*TOTAL_WIDTH trialnum+0.5*TOTAL_WIDTH], STATE_COLORS.(state_names{ctr}), ...
                        'Parent', axes_handle, ...
                        'HitTest', 'off', ...
                        'FaceColor', STATE_COLORS.(state_names{ctr}), ...
                        'EdgeColor', STATE_COLORS.(state_names{ctr}), ...
                        'UserData', trialnum, ...
                        'ZData', ZData_states, ...
                        'Visible', isvisible);
                    setappdata(rectangle_hndl, 'pp_Category', 'state');
                    setappdata(rectangle_hndl, 'pp_TrialNumber', trialnum);
                    setappdata(rectangle_hndl, 'pp_Name', state_names{ctr});
                    setappdata(rectangle_hndl, 'pp_StartTime', pp_StartTime);
                    setappdata(rectangle_hndl, 'pp_StopTime', pp_StopTime);
                    index = size(pe.states.(state_names{ctr}), 1) - (size(lpe.states.(state_names{ctr}), 1) - ctr2);
                    trial_info_value(trialnum).ghandles.states.(state_names{ctr})(index) = rectangle_hndl;
                    trial_info_value(trialnum).ghandles.states.(state_names{ctr})(trial_info_value(trialnum).ghandles.states.(state_names{ctr})==0) = NaN;
                    trial_info_value(trialnum).ghandles.states.all_handles(end+1, 1) = rectangle_hndl;
                    if isnan(pp_StopTime)
                        curr_state_handle = rectangle_hndl;
                        empty_current_state_handle = false;
                    end
                end
                
            end
        end
    end
end
if empty_current_state_handle
    curr_state_handle = [];
end
%COMPLETED DRAWING STATES%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% %%POKES%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
empty_poke_handles = [];
if ~isempty(curr_poke_handles)
    for ctr = 1:length(curr_poke_handles)
        if get(curr_poke_handles(ctr), 'UserData')==trialnum
            poke_name = getappdata(curr_poke_handles(ctr), 'pp_Name');
            intime = getappdata(curr_poke_handles(ctr), 'pp_StartTime');
            if isfield(lpe, 'pokes') && isfield(lpe.pokes, poke_name) && ~isempty(lpe.pokes.(poke_name))
                outtime = lpe.pokes.(poke_name)(1, end) - align_time;
            else
                outtime = NaN;
            end
            if isnan(outtime)
                outtime = currtime - align_time;
                pp_StopTime = NaN;
            else
                pp_StopTime = outtime;
            end
            if outtime > intime
                set(curr_poke_handles(ctr), 'XData', [intime outtime outtime intime]);
                setappdata(curr_poke_handles(ctr), 'pp_StartTime', intime);
                setappdata(curr_poke_handles(ctr), 'pp_StopTime', pp_StopTime);
                if ~isnan(pp_StopTime)
                    empty_poke_handles(end+1) = curr_poke_handles(ctr);
                end
            end
        end
    end
end
for ctr = 1:length(poke_names)
    offset = get_poke_offset(poke_names{ctr});
    %Sundeep Tuteja: 2010-04-15: lpe.pokes.(pokename) can be empty, but if
    %the starting state is 'in', it looks like its values should be
    %adjusted.
    if isfield(lpe, 'pokes') && isfield(lpe.pokes, poke_names{ctr}) && isempty(lpe.pokes.(poke_names{ctr})) && strcmp(lpe.pokes.starting_state.(poke_names{ctr}), 'in')
        lpe.pokes.(poke_names{ctr}) = [NaN NaN];
        if isempty(pe.pokes.(poke_names{ctr})) || ~all(isnan(pe.pokes.(poke_names{ctr})(end, 1:end)))
            pe.pokes.(poke_names{ctr})(end+1, 1:2) = [NaN NaN];
        end
    end
    if isfield(lpe, 'pokes') && isfield(lpe.pokes, poke_names{ctr}) && ~isempty(lpe.pokes.(poke_names{ctr}))
        if ~isfield(trial_info_value(trialnum).ghandles.pokes, poke_names{ctr})
            trial_info_value(trialnum).ghandles.pokes.(poke_names{ctr}) = zeros(0, 1);
        end
        isvisible = ismember(poke_names{ctr}, VISIBLE_POKES_LIST) && ~ismember(trialnum, INVISIBLE_TRIALS_LIST);
        isvisible = booleanstr{double(isvisible)+1};
        for ctr2 = 1:size(lpe.pokes.(poke_names{ctr}), 1)
            intime = lpe.pokes.(poke_names{ctr})(ctr2, 1) - align_time;
            outtime = lpe.pokes.(poke_names{ctr})(ctr2, end) - align_time;
            if isnan(intime) && isfield(pe, 'pokes') && isfield(pe.pokes, poke_names{ctr})
                poke_subset = pe.pokes.(poke_names{ctr})(1:end-size(lpe.pokes.(poke_names{ctr}), 1)+ctr2, 1);
                index = find(~isnan(poke_subset), 1, 'last');
                if ~isempty(index)
                    intime = pe.pokes.(poke_names{ctr})(index, 1) - align_time;
                else
                    eval(['intime = pe.states.' pe.states.starting_state '(1, end) - align_time;']);
                end
            end
            assert(~isnan(intime));
            pp_StartTime = intime;
            if isnan(outtime)
                pp_StopTime = NaN;
                outtime = currtime - align_time;
            else
                pp_StopTime = outtime;
            end
            assert(~isnan(outtime));
            if ~isnan(intime) && ~isnan(outtime) && outtime > intime
                
                %Has this rectangle already been drawn or is it being drawn
                handle_list = trial_info_value(trialnum).ghandles.pokes.all_handles;
                handle_list = handle_list(ishandle(handle_list));
                already_drawn = false;
                %Find a handle with pp_Name == current_state_name and
                %XData == the intended xdata
                for handle_ctr = 1:length(handle_list)
                    current_poke = getappdata(handle_list(handle_ctr), 'pp_Name');
                    current_XData = get(handle_list(handle_ctr), 'XData');
                    if strcmp(current_poke, poke_names{ctr}) && isequal(current_XData(:), [intime outtime outtime intime]')
                        already_drawn = true;
                        break;
                    end
                end
                
                
                if ~already_drawn
                    rectangle_hndl = patch([intime outtime outtime intime], [trialnum+offset trialnum+offset trialnum+offset+POKE_WIDTH trialnum+offset+POKE_WIDTH], POKE_COLORS.(poke_names{ctr}), ...
                        'Parent', axes_handle, ...
                        'HitTest', 'off', ...
                        'FaceColor', POKE_COLORS.(poke_names{ctr}), ...
                        'EdgeColor', POKE_COLORS.(poke_names{ctr}), ...
                        'UserData', trialnum, ...
                        'ZData', ZData_pokes, ...
                        'Visible', isvisible);
                    setappdata(rectangle_hndl, 'pp_Category', 'poke');
                    setappdata(rectangle_hndl, 'pp_TrialNumber', trialnum);
                    setappdata(rectangle_hndl, 'pp_Name', poke_names{ctr});
                    setappdata(rectangle_hndl, 'pp_StartTime', pp_StartTime);
                    setappdata(rectangle_hndl, 'pp_StopTime', pp_StopTime);
                    index = size(pe.pokes.(poke_names{ctr}), 1) - (size(lpe.pokes.(poke_names{ctr}), 1) - ctr2);
                    trial_info_value(trialnum).ghandles.pokes.(poke_names{ctr})(index) = rectangle_hndl;
                    trial_info_value(trialnum).ghandles.pokes.(poke_names{ctr})(trial_info_value(trialnum).ghandles.pokes.(poke_names{ctr})==0) = NaN;
                    trial_info_value(trialnum).ghandles.pokes.all_handles(end+1, 1) = rectangle_hndl;
                    if isnan(pp_StopTime)
                        curr_poke_handles(end+1) = rectangle_hndl;
                        empty_poke_handles = setdiff(empty_poke_handles, rectangle_hndl);
                    end
                end
            end
        end
    end
end
curr_poke_handles = setdiff(curr_poke_handles, empty_poke_handles);
%%%%COMPLETED DRAWING POKES%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%% WAVES%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
empty_wave_handles = [];
if ~isempty(curr_wave_handles)
    for ctr = 1:length(curr_wave_handles)
        if get(curr_wave_handles(ctr), 'UserData')==trialnum
            wave_name = regexprep(getappdata(curr_wave_handles(ctr), 'pp_Name'), '\(.*\)', '');
            intime = getappdata(curr_wave_handles(ctr), 'pp_StartTime');
            if isfield(lpe, 'waves') && isfield(lpe.waves, wave_name) && ~isempty(lpe.waves.(wave_name))
                outtime = lpe.waves.(wave_name)(1, end) - align_time;
            else
                outtime = NaN;
            end
            if isnan(outtime)
                outtime = currtime - align_time;
                pp_StopTime = NaN;
            else
                pp_StopTime = outtime;
            end
            if outtime > intime
                set(curr_wave_handles(ctr), 'XData', [intime outtime]);
                setappdata(curr_wave_handles(ctr), 'pp_StartTime', intime);
                setappdata(curr_wave_handles(ctr), 'pp_StopTime', pp_StopTime);
                if ~isnan(pp_StopTime)
                    empty_wave_handles(end+1) = curr_wave_handles(ctr);
                end
            end
        end
    end
end
for ctr = 1:length(wave_names)
    if isfield(lpe, 'waves') && isfield(lpe.waves, wave_names{ctr}) && ~isempty(lpe.waves.(wave_names{ctr}))
        if ~isfield(trial_info_value(trialnum).ghandles.waves, wave_names{ctr})
            trial_info_value(trialnum).ghandles.waves.(wave_names{ctr}) = zeros(0, 1);
        end
        isvisible = ismember(wave_names{ctr}, VISIBLE_WAVES_LIST) && ~ismember(trialnum, INVISIBLE_TRIALS_LIST);
        isvisible = booleanstr{double(isvisible)+1};
        for ctr2 = 1:size(lpe.waves.(wave_names{ctr}), 1)
            intime = lpe.waves.(wave_names{ctr})(ctr2, 1) - align_time;
            outtime = lpe.waves.(wave_names{ctr})(ctr2, end) - align_time;
            if isnan(intime) && isfield(pe, 'waves') && isfield(pe.waves, wave_names{ctr})
                wave_subset = pe.waves.(wave_names{ctr})(1:end-size(lpe.waves.(wave_names{ctr}), 1)+ctr2, 1);
                index = find(~isnan(wave_subset), 1, 'last');
                if ~isempty(index)
                    intime = pe.waves.(wave_names{ctr})(index, 1) - align_time;
                else
                    eval(['intime = pe.states.' pe.states.starting_state '(1, end) - align_time;']);
                end
            end
            assert(~isnan(intime));
            pp_StartTime = intime;
            if isnan(outtime)
                pp_StopTime = NaN;
                outtime = currtime - align_time;
            else
                pp_StopTime = outtime;
            end
            assert(~isnan(outtime));
            if ~isnan(intime) && ~isnan(outtime) && outtime > intime
                %Has this rectangle already been drawn or is it being drawn
                handle_list = trial_info_value(trialnum).ghandles.waves.all_handles;
                handle_list = handle_list(ishandle(handle_list));
                already_drawn = false;
                %Find a handle with pp_Name == current_state_name and
                %XData == the intended xdata
                for handle_ctr = 1:length(handle_list)
                    current_wave = getappdata(handle_list(handle_ctr), 'pp_Name');
                    current_wave = regexprep(current_wave, '\(.*\)', '');
                    current_XData = get(handle_list(handle_ctr), 'XData');
                    if strcmp(current_wave, wave_names{ctr}) && isequal(current_XData(:), [intime outtime]')
                        already_drawn = true;
                        break;
                    end
                end
                
                
                if ~already_drawn
                    ydata = get_wave_ydata(trialnum, wave_names{ctr}, WAVE_COLORS);
                    line_hndl = line([intime outtime], [ydata ydata], 'Parent', axes_handle, ...
                        'UserData', trialnum, ...
                        'Visible', isvisible, ...
                        'HitTest', 'off', ...
                        'LineWidth', WAVE_WIDTH, ...
                        'ZData', ZData_waves, ...
                        'Color', WAVE_COLORS.(wave_names{ctr}));
                    setappdata(line_hndl, 'pp_Category', 'wave');
                    setappdata(line_hndl, 'pp_TrialNumber', trialnum);
                    setappdata(line_hndl, 'pp_Name', [wave_names{ctr} '(sustain)']);
                    setappdata(line_hndl, 'pp_StartTime', pp_StartTime);
                    setappdata(line_hndl, 'pp_StopTime', pp_StopTime);
                    index = size(pe.waves.(wave_names{ctr}), 1) - (size(lpe.waves.(wave_names{ctr}), 1) - ctr2);
                    trial_info_value(trialnum).ghandles.waves.(wave_names{ctr})(index) = line_hndl;
                    trial_info_value(trialnum).ghandles.waves.(wave_names{ctr})(trial_info_value(trialnum).ghandles.waves.(wave_names{ctr})==0) = NaN;
                    trial_info_value(trialnum).ghandles.waves.all_handles(end+1) = line_hndl;
                    if isnan(pp_StopTime)
                        curr_wave_handles(end+1) = line_hndl;
                        empty_wave_handles = setdiff(empty_wave_handles, line_hndl);
                    end
                end
            end
        end
    end
end
curr_wave_handles = setdiff(curr_wave_handles, empty_wave_handles);
%%%%COMPLETED DRAWING POKES%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


sph_trial_info.value = trial_info_value;


drawnow;



end

%% FUNCTION find_align_time %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function align_time = find_align_time(obj, alignon_value, pe, varargin) %#ok<STOUT>

try
    
    pairs = {'ParsingStyle', 'v1 Style Parsing';
        'trialnum', 0};
    parseargs(varargin, pairs);
    
    if trialnum==0
        error('Invalid trial number specified');
    end
    
    switch ParsingStyle
        
        case 'v1 Style Parsing'
            
            alignon_value = regexprep(alignon_value, '\s+', '');
            found_align_state = false;
            parenthesis_indices = strfind(alignon_value, '(');
            
            if ~isfield(pe, 'states')
                return;
            end
            
            state_names = fieldnames(pe.states);
            
            if ~ismember(alignon_value(1:parenthesis_indices(end)-1), state_names)
                
                %Sorting state names according to their start time
                %For comparison purposes, we replace the NaN valued local copy of
                %pe.states.statename(1,1) with -Inf
                for ctr = 1:length(state_names)
                    if isempty(pe.states.(state_names{ctr}))
                        state_names{ctr} = '';
                    elseif isnan(pe.states.(state_names{ctr})(1,1))
                        pe.states.(state_names{ctr})(1,1) = -Inf;
                    end
                end
                state_names = state_names(~strcmp('', state_names));
                
                %Sorting
                flag = false;
                while ~flag
                    flag = true;
                    for ctr = 1:length(state_names)-1
                        if pe.states.(state_names{ctr})(1,1) > pe.states.(state_names{ctr+1})(1,1)
                            temp = state_names{ctr};
                            state_names{ctr} = state_names{ctr+1};
                            state_names{ctr+1} = temp;
                            flag = false;
                        end
                    end
                end
                
                for ctr = 1:length(state_names)
                    if ~isempty(regexp(state_names{ctr}, alignon_value(1:parenthesis_indices(end)-1), 'once'))
                        align_state = [state_names{ctr} alignon_value(parenthesis_indices(end):end)];
                        try
                            eval(['align_time = pe.states.' align_state ';']);
                            if isnan(align_time)
                                found_align_state = false;
                            else
                                found_align_state = true;
                                break;
                            end
                        catch
                            found_align_state = false;
                        end
                    end
                end
                
            else
                align_state = alignon_value;
                try
                    eval(['align_time = pe.states.' align_state ';']);
                    found_align_state = ~isnan(align_time);
                catch
                    found_align_state = false;
                end
            end
            if ~found_align_state
                eval(['align_time = pe.states.' pe.states.starting_state '(1, end);']);
            end
            
            return;
            
            
        case 'v2 Style Parsing'
            
            out = regexprep(cellstr(alignon_value), '\s+$', '');
            alignon_value_str = cell2str(formatstr(out), '\n');
            align_time = eval_pokesplot_expression(obj, alignon_value_str, trialnum);
            if strcmp(align_time, 'ERROR') || isnan(align_time) || isinf(align_time)
                eval(['align_time = pe.states.' pe.states.starting_state '(1, end);']);
            end
            
        otherwise
            error(['Unknown parsing style: ' ParsingStyle]);
            
    end
    
catch
    eval(['align_time = pe.states.' pe.states.starting_state '(1, end);']);
end

end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function out = getascell(hndl, property)
result = get(hndl, property);
if ~iscell(result)
    out = cell(size(result, 1), 1);
    for ctr = 1:size(result, 1)
        out{ctr} = result(ctr, :);
    end
else
    out = result;
end
end


function out = cell2str(cellarray, separator)
cellarray = cellarray(:);
cellarray = cellarray';
for ctr = 1:length(cellarray)
    if ctr<length(cellarray)
        cellarray{ctr} = [cellarray{ctr} separator];
    end
end
if ~isempty(cellarray)
    out = cell2mat(cellarray);
else
    out = '';
end
end

function out = formatstr(cellarray)
cellarray = strrep(cellarray, '\', '\\');
cellarray = strrep(cellarray, '%', '%%');
out = cellarray;
end

function out = implode(cellarray, separator)
out = '';
for ctr = 1:length(cellarray)
    out = [out cellarray{ctr}];
    if ctr<length(cellarray)
        out = [out separator];
    end
end
end

function out = get_protocol_data(obj)

try
    %--- JS 2017, to permit running B-control outside of Brody lab 
    try   
        usingBdata = bSettings('get', 'GENERAL', 'use_bdata');
    catch 
        usingBdata = 1;
    end
    if usingBdata 
        out = bdata(['SELECT protocol_data FROM sessions WHERE sessid=' num2str(getSessID(obj))]);
    else
        out = [];
    end
    %--- end JS 2017
    if isempty(out)
        out = [];
    else
        out = out{1};
    end
catch %#ok<CTCH>
    warning([mfilename ':ProtocolDataUnavailable'], 'Protocol Data could not be retrieved');
    out = [];
end


end