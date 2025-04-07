function BpodSystem = getBpodSystem(parsedinputs)
% Retrieve BpodSystem from an input parser
% This function allows custom BpodSystems to be passed by argument
% 
% :param parsedinputs: An inputParser that has BpodSystem as an argument
% :type parsedinputs: inputParser

results = parsedinputs.Results;

if isfield(results, 'BpodSystem')
    if isempty(results.BpodSystem)
        global BpodSystem
    else
        BpodSystem = results.BpodSystem;
    end
else
    global BpodSystem
end
if isempty(BpodSystem)
    error('BpodLib:getBpodSystem:EmptySystem', "BpodSystem is empty, this is likely because it has been used incorrectly.")
end
end