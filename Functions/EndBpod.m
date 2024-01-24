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

% EndBpod() closes the Bpod GUI, sends the termination command to the state machine 
% clears timers and releases the USB serial ports. It is called on closing
% the GUI, and can be called manually by the user from the command prompt.
%
% Arguments: None
% Returns: None
% Example usage: EndBpod;

global BpodSystem % Import the global BpodSystem object

if ~isempty(BpodSystem)
    if  ~verLessThan('MATLAB', '8.4') % In MATLAB pre v8.4, figs are sequential integers and handle ID is not guaranteed
        % Close any open GUI figures
        figureList = {'LiveDispFig', 'SystemInfoFig', 'ModuleUSBFig', 'SettingsMenuFig', 'LaunchManagerFig',... 
                      'SyncConfigFig', 'PortConfigFig', 'FolderConfigFig','FlexConfigFig','ConfigureBonsaiFig'};
        for i = 1:length(figureList)
            try
                eval(['close(BpodSystem.GUIHandles.' figureList{i} ')'])
            catch
            end
        end
        clear figureList i

        % Close liquid calibration figures
        if isfield(BpodSystem.GUIHandles, 'LiquidCalibrator')
            liquidCalFigList = {'MainFig', 'ValueEntryFig', 'RunMeasurementsFig', 'TestSpecificAmtFig', 'RecommendedMeasureFig'};
            calUIHandles = BpodSystem.GUIHandles.LiquidCalibrator;
            for i = 1:length(liquidCalFigList)
                try
                    eval(['close(calUIHandles.' liquidCalFigList{i} ')'])
                catch
                end
            end
        end
    end

    % Disconnect from hardware and close remaining figures
    if BpodSystem.Status.BeingUsed == 0
        if BpodSystem.EmulatorMode == 0
            try
                BpodSystem.SerialPort.write('Z', 'uint8');
            catch Error
                disp('Note: The Bpod state machine may have disconnected prematurely. Closing GUI.')
            end
        end
        pause(.1);

        % Close legacy TeensySoundServer if present
        if BpodSystem.EmulatorMode == 0
            if isfield(BpodSystem.PluginSerialPorts, 'TeensySoundServer')
                TeensySoundServer('end');
            end
        end
        
        % Close legacy Bonsai TCP server if open
        BpodSocketServer('close');

        if BpodSystem.EmulatorMode == 0
            disp('Bpod successfully disconnected.')
        else
            disp('Bpod emulator successfully closed.')
        end

        % Close remaining figures
        try
            delete(BpodSystem.GUIHandles.MainFig);
        catch
        end
        try
            close(BpodSystem.GUIHandles.ConfigureBonsaiFig)
        catch
        end
        try
            close(BpodSystem.GUIHandles.OscopeFig_Builtin)
        catch
        end

        % Stop and clear timers
        stop(BpodSystem.Timers.AnalogTimer);
        delete(BpodSystem.Timers.AnalogTimer);
        BpodSystem.Timers.AnalogTimer = [];
        stop(BpodSystem.Timers.PortRelayTimer);
        delete(BpodSystem.Timers.PortRelayTimer);
        BpodSystem.Timers.PortRelayTimer = [];

        % Clear serial port objects, triggering destructors to release ports
        BpodSystem.SerialPort = [];
        BpodSystem.AnalogSerialPort = [];

        % Clear BpodSystem
        clear global BpodSystem
    else
        msgbox('There is a running protocol. Please stop it first.')
        BpodErrorSound;
    end
else
    clear global BpodSystem
end