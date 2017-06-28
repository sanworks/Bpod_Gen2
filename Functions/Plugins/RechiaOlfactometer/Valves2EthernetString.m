function Message = Valves2EthernetString(varargin)
% Argument pairs = 'BankX', valveY --- to send flow through valve y on bank x
% Syntax: Message = Valves2EthernetString('Bank1', 3, 'Bank3', 1)
nLines = nargin/2;
Pos = 1;
Message = [];
for x = 1:nLines    
    Message = [Message 'WRITE ' varargin{Pos} ' ' num2str(varargin{Pos+1})];
    if x < nLines
        Message = [Message char(10)];
    end
    Pos = Pos + 2;
end