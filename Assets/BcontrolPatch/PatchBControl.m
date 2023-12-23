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
function PatchBControl
global BpodSystem

if ~ispc
    error('Error: BControl support requires a PC running Windows 7-10')
end
if BpodSystem.MachineType == 1
    error('Error: BControl support requires Bpod State Machine v0.7 or newer.')
end
ImportButtonGFX = imread('ImportButton.bmp');
FigHeight = 220; LabelYpos = 15;
BpodSystem.GUIHandles.FolderConfigFig = figure('Position', [350 480 600 FigHeight],'name','Patch Bcontrol','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('SettingsMenuBG2.bmp');
imagesc(BG); axis off; drawnow;
text(25, LabelYpos,'Select BControl root folder (.../ratter/)','Parent', ha , 'FontName', 'OCRAStd', 'FontSize', 13, 'Color', [0.8 0.8 0.8]);
BpodSystem.GUIHandles.bcontrolFolderEdit = uicontrol(BpodSystem.GUIHandles.FolderConfigFig, 'Style', 'edit',...
    'String', BpodSystem.Path.BpodRoot, 'Position', [30 140 520 25], 'HorizontalAlignment', 'Left',...
    'BackgroundColor', [.8 .8 .8], 'FontSize', 10, 'FontName', 'Arial');
BpodSystem.GUIHandles.bcontrolFolderNav = uicontrol(BpodSystem.GUIHandles.FolderConfigFig, 'Style', 'pushbutton',...
    'String', '', 'Position', [560 140 25 25], 'BackgroundColor', [.8 .8 .8], 'CData', ImportButtonGFX, 'Callback',...
    @folderSetupUIGet);
BpodSystem.GUIHandles.applyPatchButton = uicontrol(BpodSystem.GUIHandles.FolderConfigFig, 'Style', 'pushbutton',...
    'String', 'Patch', 'Position', [265 15 100 50], 'Callback', @applyPatch, 'BackgroundColor', [.4 .4 .4],...
    'ForegroundColor', [1 1 1], 'FontName', 'OCRAStd', 'FontSize', 12, 'Enable', 'off');
text(45, 70,'I made a backup of this BControl folder','Parent', ha , 'FontName', 'OCRAStd', 'FontSize', 13,...
    'Color', [0.8 0.8 0.8]);
BpodSystem.GUIHandles.bcontrolBackupCheck = uicontrol(BpodSystem.GUIHandles.FolderConfigFig, 'Style', 'checkbox',...
    'String', '', 'Position', [50 94 15 15], 'HorizontalAlignment', 'Left', 'BackgroundColor', [.8 .8 .8],...
    'Callback', @enablePatchButton);


function enablePatchButton(a,b)
global BpodSystem
PatchButtonState = get(BpodSystem.GUIHandles.applyPatchButton, 'enable');
switch PatchButtonState
    case 'on'
        set(BpodSystem.GUIHandles.applyPatchButton, 'enable', 'off');
    case 'off'
        set(BpodSystem.GUIHandles.applyPatchButton, 'enable', 'on');
end

function folderSetupUIGet(a,b)
global BpodSystem
SearchStartPath = BpodSystem.Path.BpodRoot;
FolderName = uigetdir(SearchStartPath, 'Select B-control root folder (typically /ratter/ )');
set(BpodSystem.GUIHandles.bcontrolFolderEdit, 'String', FolderName);

function applyPatch(a,b)
global BpodSystem
bcontrolFolder = get(BpodSystem.GUIHandles.bcontrolFolderEdit, 'String');
Contents = dir(bcontrolFolder);
% Make sure this is actually a B-control root folder
ValidBcontrolRoot = 0;
for i = 1:length(Contents)
    if strcmp(Contents(i).name, 'ExperPort')
        if Contents(i).isdir == 1
            ValidBcontrolRoot = 1;
        end
    end
end
if ValidBcontrolRoot == 0
    errordlg('Error: Invalid BControl root folder selected. Please try again.')
end

% -Actually patch B-control- %
PatchPath = fullfile(BpodSystem.Path.BpodRoot, 'Assets', 'BcontrolPatch', 'ExperPort');
copyfile(PatchPath, fullfile(bcontrolFolder, 'ExperPort'));

% -Copy settings_custom.conf with correct path selected- %
switch BpodSystem.MachineType
    case 2
        SettingsFileSource = fullfile(PatchPath, 'Settings', 'Settings_Custom_v0_789.conf');
    case 3
        SettingsFileSource = fullfile(PatchPath, 'Settings', 'Settings_Custom_v2_0.conf');
end

SettingsFileTarget = fullfile(bcontrolFolder, 'ExperPort', 'Settings', 'Settings_Custom.conf');
MyFile = fopen(SettingsFileSource);
SettingsFileData = char(fread(MyFile)');
fclose(MyFile);
CodePos = strfind(SettingsFileData, 'Main_Code_Directory;') + length('Main_Code_Directory;');
DataPos = strfind(SettingsFileData, 'Main_Data_Directory;') + length('Main_Data_Directory;'); 
ProtocolPos = strfind(SettingsFileData, 'Protocols_Directory;') + length('Protocols_Directory;');
TargetCodeFolder = fullfile(bcontrolFolder, 'ExperPort ;');
TargetDataFolder = fullfile(bcontrolFolder, 'SoloData ;');
TargetProtocolFolder = fullfile(bcontrolFolder, 'Protocols ;');
TargetFile = fopen(SettingsFileTarget, 'w');
SFDataPos = 1;
FirstChunk = SettingsFileData(1:CodePos);
fwrite(TargetFile, FirstChunk);
SFDataPos = SFDataPos + length(FirstChunk) - 1;
fwrite(TargetFile, TargetCodeFolder);
% Skip in file to next ;
SFDataPos = FindNextSemi(SettingsFileData, SFDataPos) + 1;
SecondChunk = SettingsFileData(SFDataPos:DataPos);
fwrite(TargetFile, SecondChunk);
SFDataPos = SFDataPos + length(SecondChunk) - 1;
fwrite(TargetFile, TargetDataFolder);
% Skip in file to next ;
SFDataPos = FindNextSemi(SettingsFileData, SFDataPos) + 1;
ThirdChunk = SettingsFileData(SFDataPos:ProtocolPos);
fwrite(TargetFile, ThirdChunk);
SFDataPos = SFDataPos + length(ThirdChunk) - 1;
fwrite(TargetFile, TargetProtocolFolder);
SFDataPos = FindNextSemi(SettingsFileData, SFDataPos) + 1;
fwrite(TargetFile, SettingsFileData(SFDataPos:end));
fclose(TargetFile);
% Update settings file with new path
BpodSystem.Path.BcontrolRootFolder = bcontrolFolder;
BpodSystem.SystemSettings.BcontrolRootFolder = bcontrolFolder;
BpodSystem.SaveSettings();
ExperPortFolder = fullfile(bcontrolFolder, 'ExperPort');
addpath(ExperPortFolder);

% Notify success & remind user to update settings_custom.conf
close(BpodSystem.GUIHandles.FolderConfigFig);
FigHeight = 220; LabelYpos = 20;
BpodSystem.GUIHandles.BcontrolConfirmFig = figure('Position', [350 480 800 FigHeight],'name','Patch Bcontrol','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('SettingsMenuBG2.bmp');
imagesc(BG); axis off; drawnow;
text(25, LabelYpos,'BControl successfully patched! Next,','Parent', ha , 'FontName', 'Courier', 'FontSize', 14, 'Color', [0.9 0.9 0.9]);
text(25, LabelYpos+20,'1. Update settings\_custom.conf if necessary','Parent', ha , 'FontName', 'Courier', 'FontSize', 14, 'Color', [0.9 0.9 0.9]);
text(25, LabelYpos+40,'2. With Bpod open, run: newstartup; dispatcher(''init'');','Parent', ha , 'FontName', 'Courier', 'FontSize', 14, 'Color', [0.9 0.9 0.9]);
BpodSystem.GUIHandles.applyPatchButton = uicontrol(BpodSystem.GUIHandles.BcontrolConfirmFig, 'Style', 'pushbutton',...
    'String', 'Ok', 'Position', [350 20 100 50], 'Callback', @CloseAcq, 'BackgroundColor', [.4 .4 .4],...
    'ForegroundColor', [0.9 0.9 0.9], 'FontName', 'Courier', 'FontSize', 14);

function SemiPos = FindNextSemi(String, Pos)
String = String(Pos:end);
SemiLocations = String == ';';
SemiPos = find(SemiLocations, 1) + Pos;

function CloseAcq(a,b)
global BpodSystem
close(BpodSystem.GUIHandles.BcontrolConfirmFig);