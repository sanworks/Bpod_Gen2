function BpodErrorDlg(Message)
global BpodSystem
BpodSystem.GUIHandles.BpodErrorFig = figure('Position', [650 480 397 150],...
    'name','Bpod Error','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('ErrorDlgBG.bmp');
image(BG); axis off; drawnow;
text(128, 20,'ERROR', 'FontName', 'OCRAStd', 'FontSize', 16, 'Color', [1 0 0]);
NewLinePos = find(Message == 10);
if isempty(NewLinePos)
    messageLines = {Message};
else
    nSegments = length(NewLinePos)+1;
    NewLinePos = [NewLinePos length(Message)];
    Pos = 1;
    for i = 1:length(NewLinePos)
        messageLines{i} = Message(Pos:NewLinePos(i)-1);
        Pos = Pos + NewLinePos(i);
    end
end
Xpos = 45;
for i = 1:nSegments
    Ypos = 190-(length(messageLines{i})*6.5);
    text(Ypos, Xpos, messageLines{i}, 'FontName', 'OCRAStd', 'FontSize', 12, 'Color', [1 0 0]);
    Xpos = Xpos + 18;
end
BpodSystem.GUIHandles.BpodErrorBtn = uicontrol('Style', 'pushbutton', 'String', 'Ok',...
    'Position', [170 10 60 40], 'Callback', 'evalin(''base'', ''close(BpodSystem.GUIHandles.BpodErrorFig)'')',...
    'FontSize', 12,'Backgroundcolor',[0.7 0.1 0.1], 'FontName', 'OCRAStd');
error(Message);