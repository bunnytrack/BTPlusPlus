/*
    BTPlusPlus 0.991
    Copyright (C) 2011 Cruque
	
    This program is free software; you can redistribute and/or modify
    it under the terms of the Open Unreal Mod License version 1.1.
*/
class TeleEffectNotify extends SpawnNotify;

var UTTeleportEffect ute[32];
var int index;


simulated event Actor SpawnNotification(Actor A)
{
	if(A != None)
	{
		//collect
		if(index < 31)
			ute[index++] = UTTeleportEffect(A);
		else
		{
			ute[31] = UTTeleportEffect(A);
			index = 0;
		}
		
	}
	return A;
}

//getMatchingEffect - returns a new spawn effect on the list matching the Location 
function UTTeleportEffect getMatchingEffect(vector Location)
{
	local int i;
	local UTTeleportEffect _ute;
	
		
	if(index > 0)
	{
		//part I
		for(i = index - 1;i>-1;i--)
		{
			_ute = ute[i];
			if(_ute != None && _ute.LifeSpan == class'UTTeleportEffect'.Default.LifeSpan && _ute.Location == Location)
				return _ute;
		}
		
		//part II
		for(i = 31;i>index-1;i--)
		{
			_ute = ute[i];
			if(_ute != None && _ute.LifeSpan == class'UTTeleportEffect'.Default.LifeSpan && _ute.Location == Location)
				return _ute;
		}
	}
	else //one-line search from the back
	{
		for(i = 31;i > -1;i--)
		{
			_ute = ute[i];
			if(_ute != None && _ute.LifeSpan == class'UTTeleportEffect'.Default.LifeSpan && _ute.Location == Location)
				return _ute;
		}
	}
	return None;
}

defaultproperties
{
	ActorClass=Class'BotPack.UTTeleportEffect'
}