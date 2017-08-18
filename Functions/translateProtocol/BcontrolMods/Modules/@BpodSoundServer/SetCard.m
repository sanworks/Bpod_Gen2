% sm = SetCard(sm, card)    
%                Set the active soundcard that we are connected to
%                (affect where sounds play when triggered from state
%                machine, etc).  See also: GetCard.m and GetNumCards.m
function sm = SetCard(sm, card)

   ChkConn(sm);
   ret = DoSimpleCmd(sm, sprintf('SET CARD %d', card));
   if (~isempty(ret))
     sm.def_card = card;
   end;
   