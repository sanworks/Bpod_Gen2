% [VarLogList]   = GetVarLog(sm, int StartLogPos, int EndLogPos)
%
%                Gets a cell array in which each row corresponds to
%                a variable logged by the Embedded C state machine.
%                The cell array will have EndLogPos-StartLogPos+1
%                rows and 3 columns. (If EndLogPos is bigger than
%                GetVarLogCounter(), this produces an error).
%
%                Each of the rows in VarLogList has 3
%                columns: 
%
%                the first is the timestamp in seconds
%
%                the second is the name of the log item, a string
%
%                the third is the value of the logged item, a
%                double precision value
%
function [ret] = GetVarLog(sm, start_no, end_no)
    if start_no > end_no,
        ret = cell(0,3);
    else
        ret = DoQueryStringtableCmd(sm, sprintf('GET VARLOG %d %d', start_no-1, end_no-1));
    end;

    [m, n] = size(ret);
    % convert first and third columns to a numeric value
    for i=1:m,
      ret{i,1} = sscanf(ret{i,1}, '%f', 1);
      ret{i,3} = sscanf(ret{i,3}, '%f', 1);
    end;
    