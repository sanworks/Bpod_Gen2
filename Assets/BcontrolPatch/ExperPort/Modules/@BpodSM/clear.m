% Destruct the sm.handle..
function [] = clear(sm)

     FSMClient('destroy', sm.handle);
     sm.handle = -1;

    error('clear called!!');

end
