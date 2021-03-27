/*
    BTPlusPlus 0.991
    Copyright (C) 2004-2006 Damian "Rush" Kaczmarek

    This program is free software; you can redistribute and/or modify
    it under the terms of the Open Unreal Mod License version 1.1.
*/

class BTPPFlagRed extends RedFlag;
/* custom flag which vanishes after being dropped */

event Destroyed()
{
	Super.Destroyed();
	/* this is crucial for simulating the natural flags behaviour when bMultiFlags=False, we copy the original flag and set bHidden on the base flag,
	when the copy is destroyed, the base gets visible again */
	HomeBase.bHidden=False;
}

/* flag detaches itself from the player setting all parameters to normal and annihilates itself */
function Drop(vector newVel)
{
	BroadcastLocalizedMessage( class'CTFMessage', 3, None, None, CTFGame(Level.Game).Teams[Team] );
	if (Level.Game.WorldLog != None)
		Level.Game.WorldLog.LogSpecialEvent("flag_returned_timeout", CTFGame(Level.Game).Teams[Team].TeamIndex);
	if (Level.Game.LocalLog != None)
		Level.Game.LocalLog.LogSpecialEvent("flag_returned_timeout", CTFGame(Level.Game).Teams[Team].TeamIndex);
	Holder.PlayerReplicationInfo.HasFlag = None;
	Holder.AmbientGlow = Holder.Default.AmbientGlow;
	LightType = LT_Steady;
	Holder.LightType = LT_None;
	if ( Holder.Inventory != None )
		Holder.Inventory.SetOwnerDisplay();
	Destroy();
}

defaultproperties
{
}
