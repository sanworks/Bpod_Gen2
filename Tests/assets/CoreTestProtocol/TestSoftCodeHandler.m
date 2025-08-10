function TestSoftCodeHandler(softCode)
% Tests whether the soft code handler function is called correctly.

global BpodSystem

assert(isinstance(softCode, 'numeric'), 'Soft code must be numeric');