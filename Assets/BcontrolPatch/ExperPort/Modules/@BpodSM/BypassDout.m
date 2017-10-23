% sm = BypassDout(sm, int d)   
%                Sets the digital outputs to be whatever the
%                state machine would indicate, bitwise or`d with
%                "d." To turn this off, call BypassDout(0).
%
function [sm] = BypassDout(sm, d)

  DoSimpleCmd(sm, sprintf('BYPASS DOUT %d', d));
  sm = sm;
  return;
