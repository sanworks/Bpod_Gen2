function message = startupMessage()
%STARTUPMESSAGE Displays a startup message when Bpod is initialized.

message = sprintf('** Starting Bpod Console v%s **\nInitialized: %s', BpodSoftwareVersion_Semantic, BpodLib.utils.isotime());
% todo: add datetime and git head 