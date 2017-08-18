% [ncards] = GetNumCards(sm)
%                Query the sound machine to find out how many soundcards it 
%                has installed.
%
function [ncards] = GetNumCards(sm)
     ncards = str2double(DoQueryCmd(sm, 'GET NCARDS'));
     return;
