function click(handle)
% Simulate a user click on an object
% click(handle)

% tc = matlab.uitest.TestCase.forInteractiveUse;
% pressed = false;
% try
%     tc.press(handle)
%     pressed = true;
% catch ME
%     % If we move to uifigure framework for the UI elements then this would work.
%     if strcmp(ME.identifier, 'MATLAB:uiautomation:Driver:MustBelongToUIFigure')
%     elseif strcmp(ME.identifier, 'MATLAB:uiautomation:Driver:GestureNotSupportedForClass')
%     else
%         rethrow(ME)
%     end
% end
% if pressed
%     return
% end
feval(get(handle, 'Callback'))