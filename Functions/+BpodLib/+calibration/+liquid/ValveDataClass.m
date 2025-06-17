% Class definition for ValveDataClass
% This class is used to store data for a single valve, including the valve name, the durations and amounts of liquid dispensed, the coefficients of the polynomial fit to the data, and the date the data was last modified.
% Note that this is a handle class, so the object is passed by reference and modifications to the object will be reflected in all references to the object.


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
        % Load data from the saved struct
        % :param rawstruct: struct with fields ValveName, LastDateModified, Coeffs, Durations, Amounts
        % :type rawstruct: struct
        obj.ValveName = rawstruct.ValveName;
        obj.LastDateModified = rawstruct.LastDateModified;
        obj.Coeffs = rawstruct.Coeffs;
        obj.Durations = rawstruct.Durations;
        obj.Amounts = rawstruct.Amounts;
    end

    function addMeasurement(obj, duration, amount)
        %addMeasurement(duration, amount)
        % Add a new measurement to the data set
        % :param duration: the duration of the valve opening (ms)
        % :type duration: double
        % :param amount: the amount of liquid dispensed (uL)
        % :type amount: double

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
        % Remove a measurement from the data set
        % :param value: the index of the measurement to remove, can be duration 
        % :type value: double
        % :param isduration: flag for duration instead of index
        % :type isduration: bool

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
        %valveTime_ms = getValveTime(liquidAmount_uL)
        % Get the valve open time for a given liquid amount
        % :param liquidAmount_uL: the amount of liquid to dispense (uL)
        % :type liquidAmount_uL: double
        % :return: the time to open the valve (ms)
        % :rtype: double

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
        % Ensures the object data is in save formatted struct
        % :return: the object data as a struct
        % :rtype: struct
        
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
        % Plot the data
        % :param ax: the axes to plot on (default: current axes)
        % :type ax: handle
        % :param color: the color of the plot (default: 'k')
        % :type color: char
        % :param legendname: the name for the legend (default: ValveName)
        % :type legendname: char

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