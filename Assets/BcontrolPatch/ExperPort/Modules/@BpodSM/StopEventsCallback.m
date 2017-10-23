% sm = StopEventsCallback(sm) 
%                Disables asynchronous notification, unregistering 
%                any previously-regsitered callbacks. 
%                See RegisterEventsCallback.m
function [sm] = StopEventsCallback(sm)
      FSMClient('stopNotifyEvents', sm.handle);      
      return;
