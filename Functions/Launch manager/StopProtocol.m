%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

----------------------------------------------------------------------------

This program is free software:you can redistribute it and / or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see < http: // www.gnu.org / licenses /> .
%}

% Usage:
% StopProtocol - Stops the running protocol. same as RunProtocol('Stop')

function StopProtocol(varargin)

    global BpodSystem

    if nargin > 0

        if varargin{1}
            SaveBpodSessionData;
        end

    end

    if ~isempty(BpodSystem.Status.CurrentProtocolName)
        disp(' ')
        disp([BpodSystem.Status.CurrentProtocolName ' ended.'])
    end

    warning off % Suppress warning, in case protocol folder has already been removed
    rmpath(fullfile(BpodSystem.Path.ProtocolFolder, BpodSystem.Status.CurrentProtocolName));
    warning on

    BpodSystem.Status.BeingUsed = 0;
    BpodSystem.Status.CurrentProtocolName = '';
    BpodSystem.Path.Settings = '';
    BpodSystem.Status.Live = 0;

    if BpodSystem.EmulatorMode == 0
        BpodSystem.SerialPort.write('X', 'uint8');
        pause(.1);
        nBytes = BpodSystem.SerialPort.bytesAvailable;

        if nBytes > 0
            BpodSystem.SerialPort.read(nBytes, 'uint8');
        end

        if isfield(BpodSystem.PluginSerialPorts, 'TeensySoundServer')
            TeensySoundServer('end');
        end

    end

    BpodSystem.Status.InStateMatrix = 0;
    % Shut down protocol and plugin figures (should be made more general)
    try
        Figs = fields(BpodSystem.ProtocolFigures);
        nFigs = length(Figs);

        for x = 1:nFigs

            try
                close(eval(['BpodSystem.ProtocolFigures.' Figs{x}]));
            catch

            end

        end

        try
            close(BpodNotebook)
        catch
        end

    catch
    end

    if isfield(BpodSystem.GUIHandles, 'MainFig')
        set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.GoButton, 'TooltipString', 'Launch behavior session');
    end

    if BpodSystem.Status.Pause == 1
        BpodSystem.Status.Pause = 0;
    end

    % ---- end Shut down Plugins

end
