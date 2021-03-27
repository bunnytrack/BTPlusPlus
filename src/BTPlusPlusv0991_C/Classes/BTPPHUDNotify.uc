/*
    BTPlusPlus 0.991
    Copyright (C) 2004-2006 Damian "Rush" Kaczmarek

    This program is free software; you can redistribute and/or modify
    it under the terms of the Open Unreal Mod License version 1.1.
*/

class BTPPHUDNotify expands SpawnNotify;
/* this class spawns class'BTPPHudMutator' */

simulated function PreBeginPlay()
{
	if(ROLE < ROLE_Authority)
		log("BTPP: PreBeginPlay()");
	bAlwaysRelevant = True;
}

simulated function PostNetBeginPlay()
{
	local ChallengeHUD PlayerHUD;

	/*if(ROLE < ROLE_Authority)
		log("BTPP: PostNetBeginPlay()");*/
	foreach AllActors(Class'ChallengeHUD',PlayerHUD)
		SpawnNotification(PlayerHUD);
}

simulated event Actor SpawnNotification(actor Actor)
{
	local BTPPHUDMutator tmpHUD;

	log("BTPP: SpawnNotification(1)");
	if (Actor != None)
	{
		if (Actor.IsA('HUD') && (HUD(Actor).HUDMutator == None || !HUD(Actor).HUDMutator.IsA('BTPPHUDMutator')))
		{
			log("BTPP: SpawnNotification(2)");
			tmpHUD = spawn(class'BTPPHUDMutator', Actor);
			if (tmpHUD != None)
			{
				tmpHUD.PlayerOwner = PlayerPawn(Actor.Owner);

				log("BTPP: SpawnNotification(3)");
				if (HUD(Actor).HUDMutator == None)
				{
					log("BTPP: SpawnNotification(4)");
					HUD(Actor).HUDMutator = tmpHUD;
				}
				else
				{
					log("BTPP: SpawnNotification(5)");
					tmpHUD.NextHUDMutator = HUD(Actor).HUDMutator;
					HUD(Actor).HUDMutator = tmpHUD;
				}
			}
		}
	}
	return Actor;
}

defaultproperties
{
	ActorClass=class'Engine.HUD'
	NetPriority=5
	bNetTemporary=False //@test
}
