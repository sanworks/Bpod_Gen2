%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) Sanworks LLC, Rochester, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}

function last_trial_encoder_plot(axes, op, choiceThreshold, varargin)
global BpodSystem
switch op
    case 'init'
        BpodSystem.GUIHandles.EncoderPlot = plot(axes, 0,0, 'k-', 'LineWidth', 2);
        BpodSystem.GUIHandles.EncoderPlotThreshold1Line = line([0,1000],[-choiceThreshold -choiceThreshold], 'Color', 'k', 'LineStyle', ':');
        BpodSystem.GUIHandles.EncoderPlotThreshold2Line = line([0,1000],[choiceThreshold choiceThreshold], 'Color', 'k', 'LineStyle', ':');
        set(axes, 'box', 'off', 'tickdir', 'out');
        ylabel('Position (deg)', 'FontSize', 12); 
        xlabel('Time (s)', 'FontSize', 12);
    case 'update'
        encoderData = varargin{1};
        trialDuration = varargin{2};
        set(BpodSystem.GUIHandles.EncoderPlot, 'XData', encoderData.Times,'YData', encoderData.Positions);
        set(axes, 'ylim', [-choiceThreshold*2 choiceThreshold*2], 'xlim', [0 trialDuration]);
        set(BpodSystem.GUIHandles.EncoderPlotThreshold1Line,'ydata',[-choiceThreshold, -choiceThreshold]);
        set(BpodSystem.GUIHandles.EncoderPlotThreshold2Line,'ydata',[choiceThreshold, choiceThreshold]);
end