% Inverse of above..
function [matrx] = GetStateMatrix(sm)

     matrx = DoQueryStringtableCmd(sm, 'GET STATE MATRIX');


