function setDarkMode(ax)
% Apply dark mode styling to axes and its children
% setDarkMode(ax) configures the axes with a dark color scheme
%
% Input:
%       ax - Axes handle or figure handle to modify

% Define colors
dark_bg = [0.1 0.1 0.1];    % Dark background
light_text = [0.9 0.9 0.9]; % Light text/line color
grid_color = [0.3 0.3 0.3]; % Subdued grid color

% Check if input is figure or axes
if strcmp(get(ax,'Type'), 'figure')
    fig = ax;
    ax = findobj(fig, 'Type', 'axes');
else
    fig = ancestor(ax, 'figure');
end

% Set figure properties
set(fig, ...
    'Color', dark_bg, ...
    'InvertHardcopy', 'off'); % Preserve colors when printing

% Set axes properties
set(ax, ...
    'Color', dark_bg, ...
    'XColor', light_text, ...
    'YColor', light_text, ...
    'ZColor', light_text, ...
    'GridColor', grid_color, ...
    'MinorGridColor', grid_color, ...
    'GridAlpha', 0.5, ...
    'MinorGridAlpha', 0.2);

% Set title and labels
title_handle = get(ax, 'Title');
xlabel_handle = get(ax, 'XLabel');
ylabel_handle = get(ax, 'YLabel');
zlabel_handle = get(ax, 'ZLabel');

set([title_handle, xlabel_handle, ylabel_handle, zlabel_handle], ...
    'Color', light_text);

% todo: this modifies the patchs behind axes
% Modify all children (lines, patches, etc.)
% children = findobj(ax, '-property', 'Color');
% for i = 1:length(children)
%     try
%         % Skip if it's a histogram (special case)
%         if ~isa(children(i), 'matlab.graphics.chart.primitive.Histogram')
%             set(children(i), 'Color', light_text);
%         end
%     catch
%         continue
%     end
% end

% Set colormap to something that works well with dark background
colormap(ax, 'parula'); % or 'viridis', 'plasma'

% If there's a legend, update its colors
leg = findobj(fig, 'Type', 'legend');
if ~isempty(leg)
    set(leg, ...
        'TextColor', light_text, ...
        'Color', dark_bg, ...
        'EdgeColor', grid_color);
end

% If there's a colorbar, update it
cb = findobj(fig, 'Type', 'colorbar');
if ~isempty(cb)
    set(cb, ...
        'Color', light_text, ...
        'YColor', light_text, ...
        'XColor', light_text);
end
end