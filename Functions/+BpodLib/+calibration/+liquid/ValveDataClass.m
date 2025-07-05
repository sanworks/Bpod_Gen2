% ValveDataClass - Handle class for storing and managing valve calibration data.
%
% This class stores calibration data for a single valve, including:
% - Valve name and last modification date
% - Measured durations and liquid amounts
% - Polynomial coefficients for the calibration curve
%
% Properties:
%   ValveName - Name of the valve (char)
%   LastDateModified - ISO 8601 timestamp of last modification (char)
%   Coeffs - Polynomial coefficients for calibration curve (double array)
%   Durations - Valve opening durations in ms (double array)
%   Amounts - Liquid amounts dispensed in uL (double array)
%
% Methods:
%   ValveDataClass - Constructor
%   load - Load data from struct
%   addMeasurement - Add new measurement point
%   removeMeasurement - Remove measurement point
%   updateCoeffs - Update polynomial coefficients
%   getValveTime - Calculate valve time for desired amount
%   struct - Convert object to struct
%   plot - Plot calibration data and curve

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

classdef ValveDataClass < handle
properties
    ValveName  % char: the name of the valve
    LastDateModified  % char: the date the data was last modified (ISO 8601 format)
    Coeffs  % double: the coefficients of the polynomial fit to the data
    Durations  % double: the durations of the valve openings (ms)
    Amounts  % double: the amounts of liquid dispensed (uL)
end

properties (Access = private)
    polynomial = 2
end

methods
    function obj = ValveDataClass()
        obj.ValveName = "";
        obj.Coeffs = [];
        obj.LastDateModified = "";
        obj.Durations = [];
        obj.Amounts = [];
    end

    function load(obj, rawstruct)
        % Load data from saved struct into object
        % obj.load(rawstruct)
        %
        % Inputs:
        %   rawStruct - Struct containing valve data with fields:
        %       ValveName, LastDateModified, Coeffs, Durations, Amounts
        obj.ValveName = rawstruct.ValveName;
        obj.LastDateModified = rawstruct.LastDateModified;
        obj.Coeffs = rawstruct.Coeffs;
        obj.Durations = rawstruct.Durations;
        obj.Amounts = rawstruct.Amounts;
    end

    function addMeasurement(obj, duration, amount)
        % Add a new measurement to the data set
        % addMeasurement(duration, amount)
        % Arguments
        % ---------
        % duration : double
        %     Valve opening duration in milliseconds
        % amount : double
        %     Liquid amount dispensed in microliters

        if isnan(amount) || amount < 0
            error('BpodLib:ValveDataClass:InvalidAmount', 'Amount must be a positive number')
        end
        
        % Note that this allows for multiple measurements of the same duration
        obj.Durations = [obj.Durations; duration];
        obj.Amounts = [obj.Amounts; amount];
        obj.updateCoeffs()
        obj.LastDateModified = BpodLib.utils.isotime();
    end

    function removeMeasurement(obj, value, varargin)
        % Remove a measurement point.
        %
        % Parameters
        % ----------
        % value : double
        %     Either index of measurement to remove or duration value
        %
        % Keyword Arguments
        % -----------------
        % duration : logical, optional
        %     If true, value is treated as duration rather than index (default: false)

        p = inputParser();
        p.addParameter('duration', false)
        p.parse(varargin{:})

        if p.Results.duration
            index = find(obj.Durations == value);
            if numel(index) > 1
                error('BpodLib:ValveDataClass:MultipleDurations', 'Multiple durations for valve %s', obj.ValveName)
            elseif numel(index) == 0
                error('BpodLib:ValveDataClass:NoDurationsFound', 'No matching duration found for %s', obj.ValveName)
            end
        else
            index = value;
        end
        
        obj.Durations(index) = [];
        obj.Amounts(index) = [];
        obj.updateCoeffs()
        obj.LastDateModified = BpodLib.utils.isotime();
    end

    function updateCoeffs(obj)
        % Update the coefficients of the polynomial fit to the data
        if numel(obj.Amounts) < 2
            obj.Coeffs = [];
            return
        end
        % Update the coefficients of the polynomial fit to the data
        warning('off', 'MATLAB:polyfit:PolyNotUnique')  % warning for when 2 points are used in 2nd order polyfit
        obj.Coeffs = polyfit(obj.Amounts, obj.Durations, obj.polynomial);
        warning('on', 'MATLAB:polyfit:PolyNotUnique')
    end

    function valveTime_ms = getValveTime(obj, liquidAmount_uL)
        % Calculate valve time needed for target amount.
        %
        % Parameters
        % ----------
        % liquidAmount_uL : double
        %     Desired liquid amount in microliters
        %
        % Returns
        % -------
        % valveTime_ms : double
        %     Required valve open time in milliseconds

        % Note that time is in ms but state matrix defines time in seconds
        
        assert(numel(obj.Coeffs) > 1, 'BpodLib:ValveDataClass:MissingData', 'Not enough calibration points to calculate time for: %s', obj.ValveName)

        valveTime_ms = polyval(obj.Coeffs, liquidAmount_uL);
        if isnan(valveTime_ms)
            valveTime_ms = 0;
        end
        
        if any(valveTime_ms <= 0)
            error('BpodLib:ValveDataClass:InvalidCalibration', 'Negative open time for valve %s', obj.ValveName);
        end
    end

    function out = struct(obj)
        % Convert the object to a struct
        
        if numel(obj.Durations) ~= numel(obj.Amounts)
            error('BpodLib:ValveDataClass:DataMismatch', 'Durations and Amounts must have the same number of elements');
        end

        out = struct(...
                'ValveName', obj.ValveName,...
                'LastDateModified', obj.LastDateModified,...
                'Coeffs', obj.Coeffs,...
                'Durations', obj.Durations,...
                'Amounts', obj.Amounts...
            );
    end

    function plot(obj, varargin)
        % Visualize calibration data and curve.
        %
        % Keyword Arguments
        % -----------------
        % ax : handle, optional
        %     Axes handle to plot on (default: current axes)
        % color : char, optional
        %     Plot color (default: 'k')
        % linewidth : double, optional
        %     Line width (default: 1.5)
        % legendname : char, optional
        %     Legend entry (default: ValveName)
        %
        % Raises
        % ------
        % BpodLib:ValveDataClass:InsufficientData
        %     If fewer than 2 measurements exist

        p = inputParser();
        p.addParameter('ax', gca, @ishandle);
        p.addParameter('color', 'k', @ischar)
        p.addParameter('linewidth', 1.5, @isnumeric)
        p.addParameter('legendname', obj.ValveName, @ischar)
        p.parse(varargin{:});

        ax = p.Results.ax;
        if isempty(obj.Coeffs)
            error('BpodLib:ValveDataClass:InsufficientData', 'Insufficient data to plot. At least 2 measurements are required.')
        end

        % Plot liquid outputs from 0 to 10% more than the max amount
        amountRange = linspace(0, max(obj.Amounts) + max(obj.Amounts) * .1, 100);
        durationRange = polyval(obj.Coeffs, amountRange);

        % Plot the real data
        scatter(ax, obj.Durations, obj.Amounts, ...
            'markeredgecolor', p.Results.color, 'linewidth', p.Results.linewidth, 'HandleVisibility', 'off')
        hold(ax, 'on')
            
        % Plot the polynomial fit
        plot(ax, durationRange, amountRange,...
        'color', p.Results.color, 'linewidth', p.Results.linewidth, 'DisplayName', p.Results.legendname)
        hold(ax, 'off')

        xlabel(ax, 'Duration (ms)')
        ylabel(ax, 'Amount (uL)')
        title(ax, obj.ValveName)
        grid(ax, 'on')
    end
end
end