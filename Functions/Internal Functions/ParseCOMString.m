function words = ParseCOMString(string)
string = strtrim(string);
string = lower(string);
nSpaces = sum(string == ' ') + sum(string == char(10));
if nSpaces > 0
    Spaces = find((string == ' ') + (string == char(10)));
    Pos = 1;
    words = cell(1,nSpaces);
    for x = 1:nSpaces
        words{x} = string(Pos:Spaces(x) - 1);
        Pos = Pos + length(words{x}) + 1;
    end
    words{x+1} = string(Pos:length(string));
else
    words{1} = string;
end