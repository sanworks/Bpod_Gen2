function out = UrlEncode(sm, s)
   out = '';
   if (~ischar(s)), error('UrlEncode only works on strings!'); end;
   for i=1:length(s),
     xl = s(i);
     if (((xl >= 65) && (xl <= 90)) || ((xl <= 57) && (xl >= 48)) || ((xl <= 122) && (xl >= 97))),
       out = [ out xl ];
     else
       out = [ out sprintf('%%%02x',xl) ];
     end;
   end;
     
