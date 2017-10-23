function out = UrlDecode(sm, s)
   if (~ischar(s)), error('UrlDecode only works on strings!'); end;
   out = '';
   len = length(s);
   i=1;
   while (i <= len ),
     xl = s(i);
     if ( (xl == '%') && i+2 <= len && isxdigit(s(i+1)) && ...
          isxdigit(s(i+2)) ),
       numstr = s(i+1:i+2);
       num = sscanf(numstr, '%x');
       out = [ out num ];
       i=i+2;
     else
       out = [ out s(i) ];
     end;
     i = i+1;
   end;
   return;
   
function [b] = isxdigit(s)
  b = 0;
  if ( ((s >= '0') && (s <= '9')) || ((s >= 'a') && (s <= 'f')) || ...
       ((s >= 'A') && (s <= 'F')) ),
    b = 1;
  end;
  return;
  
