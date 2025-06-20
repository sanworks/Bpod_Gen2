function Completed = conversionscript(BpodSystem, varargin)
% Convert the Liquid Calibration .mat file to the new .json format

% The conversion script functionality is now an essential part of folder settings
Completed = BpodLib.BpodObject.setup.compatibility.convertSettingsFolder(BpodSystem, varargin{:});