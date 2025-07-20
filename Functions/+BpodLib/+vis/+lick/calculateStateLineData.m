function [times, states] = calculateStateLineData(portins, portouts, endtime)
% Build plot() ready lick line data
% [times, states] = calculateStateLineData(portins, portouts, endtime)
%
% portins and portouts are expected to be the output of cleanPortTimes()
% plot(times, states) will generate a line in up state during lick
%
% Arguments
% ---------
% portins : double
%     Port in times
% portouts : double
%     Port out times, numel() same as portins
% endtime : double
%     A single time to draw the end of the line to
%
% Returns
% -------
% times : double
%     Times of events
% states : double
%     State of port (1 or 0)

% Add 1 for licking, 0 for not licking
data = [[ones(size(portins)) zeros(size(portouts))] ; [portins, portouts]];

% Sort port events according to time
[~, idx] = sort(data(2,:));
data = data(:,idx);

% If no lick literally at start of trial:
% The opposite state to the first recorded was at time 0
if data(2,1) ~= 0 % checks if there's event at time 0
    data = [[mod(1,data(1,1));0], data];
end

% The end state continues to the endtime
% e.g. if the portout never happens then the state remained in/high
if data(2,end) ~= endtime
    data = [data [data(1,end); endtime]];
end

times = data(2, :);
states = data(1, :);
end