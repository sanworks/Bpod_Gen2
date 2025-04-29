function verified = verifyPathing(BpodSystem, varargin)
% verified = verifyPathing(BpodSystem)
% Verify that the expected pathing exists for the BpodSystem

p = inputParser();
p.addParameter('ThrowErrors', true)
p.addParameter('verbose', true)
p.parse(varargin{:});

verified = true;
results = cell(1, 1);

liquidcalibrationPath = BpodLib.path.getPath(BpodSystem, 'liquidcalibration');
if ~isfolder(liquidcalibrationPath)
    verified = false;
    results{1} = liquidcalibrationPath;
end

if ~verified
    if p.Results.verbose
        fprintf('Expected paths not found:\n')
        for x = 1:numel(results)
            fprintf('\t%s\n', results{x})
        end
    end
    if p.Results.ThrowErrors
        error('BpodLib:verifyPathing:PathingIncomplete', 'The pathing of Bpod does not properly exist, refer to list above. Bpod has started up but some functionality may not work as expected.')
    end
end

end