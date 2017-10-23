function [sm] = SetAllowedTrigs(sm, trigs)

    if (~isnumeric(trigs) | size(trigs,1) ~= 1),
          error('Please pass a numeric 1xN array');
    end;
    
    mydata = get(sm.myfig, 'UserData');
    mydata.allowed_trigs = trigs;
    set(sm.myfig, 'UserData', mydata);
    
    return;
    
            