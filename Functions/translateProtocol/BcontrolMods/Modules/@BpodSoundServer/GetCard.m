% card = GetCard(sm)    
%                Get the active soundcard for LoadSound we are
%                connected to (affect where sounds play when
%                triggered from state machine, etc).
%                See also: SetCard.m and GetNumCards.m
function card = GetCard(sm)

   ChkConn(sm);
   card = DoQueryCmd(sm, 'GET CARD');
   if (isempty(card))
     card = sm.def_card;
   end;
   
   