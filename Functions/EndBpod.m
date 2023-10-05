%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2022 Sanworks LLC, Rochester, New York, USA

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
global BpodSystem
if ~isempty(BpodSystem)
    if  ~verLessThan('MATLAB', '8.4') % In MATLAB earlier than 8.4, figures are sequential integers and figure ID of handle is not guaranteed
        % Close any open GUI figures
        FigureList = {'LiveDispFig', 'SystemInfoFig', 'ModuleUSBFig', 'SettingsMenuFig', 'LaunchManagerFig', 'SyncConfigFig', 'PortConfigFig',...
                      'FolderConfigFig','FlexConfigFig','ConfigureBonsaiFig'};
        for i = 1:length(FigureList)
            try
                eval(['close(BpodSystem.GUIHandles.' FigureList{i} ')'])
            catch
            end
        end
        clear FigureList i
        if isfield(BpodSystem.GUIHandles, 'LiquidCalibrator')
            LiquidCalFigList = {'MainFig', 'ValueEntryFig', 'RunMeasurementsFig', 'TestSpecificAmtFig', 'RecommendedMeasureFig'};
            CalUIHandles = BpodSystem.GUIHandles.LiquidCalibrator;
            for i = 1:length(LiquidCalFigList)
                try
                    eval(['close(CalUIHandles.' LiquidCalFigList{i} ')'])
                catch
                end
            end
        end
    end
    if BpodSystem.Status.BeingUsed == 0
        if BpodSystem.EmulatorMode == 0
            try
                BpodSystem.SerialPort.write('Z', 'uint8');
            catch Error
                disp("Note: The Bpod state machine may have disconnected prematurely. Closing GUI.")
            end
        end
        pause(.1);
        delete(BpodSystem.GUIHandles.MainFig);
        if BpodSystem.EmulatorMode == 0
            if isfield(BpodSystem.PluginSerialPorts, 'TeensySoundServer')
                TeensySoundServer('end');
            end
        end
        if BpodSystem.EmulatorMode == 0
            disp('Bpod successfully disconnected.')
        else
            disp('Bpod emulator successfully closed.')
        end
        BpodSocketServer('close');
        try
            close(BpodSystem.GUIHandles.ConfigureBonsaiFig)
        catch
        end
        try
            close(BpodSystem.GUIHandles.OscopeFig_Builtin)
        catch
        end
        stop(BpodSystem.Timers.AnalogTimer);
        delete(BpodSystem.Timers.AnalogTimer);
        BpodSystem.Timers.AnalogTimer = [];
        stop(BpodSystem.Timers.PortRelayTimer);
        delete(BpodSystem.Timers.PortRelayTimer);
        BpodSystem.Timers.PortRelayTimer = [];
        BpodSystem.SerialPort = [];
        BpodSystem.AnalogSerialPort = [];
        clear global BpodSystem
    else
        msgbox('There is a running protocol. Please stop it first.')
        BpodErrorSound;
    end
else
    clear global BpodSystem
end