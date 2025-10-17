function verified = verifyPathing(BpodSystem, varargin)
% Verify that the expected pathing exists for the BpodSystem
% verified = verifyPathing(BpodSystem)

% docstring
% signature
%
% Arguments
% ---------
% BpodSystem : BpodObject
%
% Keyword Arguments
% -----------------
% ThrowErrors : logical (default=true)
%     Whether to throw errors if verification fails.
% verbose : logical (default=true)
%     Whether to display messages in Command Window.
%
% Returns
% -------
% verified : logical
%     Returns true if successful, 0 otherwise

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

p = inputParser();
p.addParameter('ThrowErrors', true)
p.addParameter('verbose', true)
p.parse(varargin{:});

verified = true;
results = cell(1, 1);

liquidcalibrationPath = BpodLib.path.getPath('calibration', BpodSystem);
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
        warning('BpodLib:verifyPathing:PathingIncomplete', 'The pathing of Bpod does not properly exist, refer to list above. Bpod has started up but some functionality may not work as expected.')
    end
end

end