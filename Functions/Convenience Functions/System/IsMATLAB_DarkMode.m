function result = IsMATLAB_DarkMode
result = false;
if ~verLessThan('matlab', '25.1')
    if strcmp(settings().matlab.appearance.MATLABTheme.ActiveValue, 'Dark')
        result = true;
    end
end