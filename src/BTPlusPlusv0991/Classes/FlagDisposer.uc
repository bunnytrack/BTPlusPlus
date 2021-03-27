/*
    BTPlusPlus 0.991
    Copyright (C) 2004-2006 Damian "Rush" Kaczmarek

    This program is free software; you can redistribute and/or modify
    it under the terms of the Open Unreal Mod License version 1.1.
*/

class FlagDisposer extends Actor;

var BTPlusPlus Controller;
var byte Team;
var FlagBase	HomeBase;
var CTFFlag Flag;
var Pawn Holder;
var CTFFlag NewFlag;

function SetHolderLighting()
{
	Holder.AmbientGlow = 254;
	LightType = LT_None;
	Holder.LightEffect = LE_NonIncidence;
	Holder.LightBrightness = 255;
	//red light for red flag and blue for blue flag
	if(Team == 0)
		Holder.LightHue = 0;
	else
		Holder.LightHue = 170;
	Holder.LightRadius = 6;
	Holder.LightSaturation = LightSaturation;
	Holder.LightType = LT_Steady;
}

function ScoreFlag(Pawn Scorer, CTFFlag theFlag, int time)
{
	local pawn TeamMate;
	local Actor A;

	CTFGame(Level.Game).Teams[Scorer.PlayerReplicationInfo.Team].Score += 1.0;
	
	Scorer.PlayerReplicationInfo.Score += 7.0f;

	BroadcastLocalizedMessage( class'CTFMessage', 0, Scorer.PlayerReplicationInfo, None, TheFlag );

	for (TeamMate = Level.PawnList; TeamMate != None; TeamMate = TeamMate.NextPawn )
	{
		if ( TeamMate.IsA('TournamentPlayer'))
			PlayerPawn(TeamMate).ClientPlaySound(CTFGame(Level.Game).CaptureSound[Scorer.PlayerReplicationInfo.Team]);
	}
	if ( theFlag.HomeBase.Event != '' )
		foreach Allactors(class'Actor', A, theFlag.HomeBase.Event )
			A.Trigger(theFlag.HomeBase,	Scorer);
			
    if((CTFGame(Level.Game).bOverTime || (CTFGame(Level.Game).GoalTeamScore != 0)) && (CTFGame(Level.Game).Teams[Scorer.PlayerReplicationInfo.Team].Score >= CTFGame(Level.Game).GoalTeamScore) )
		CTFGame(Level.Game).EndGame("teamscorelimit");
	else if ( CTFGame(Level.Game).bOverTime )
		CTFGame(Level.Game).EndGame("timelimit");
}

function Touch(Actor Other)
{
	local CTFFlag 	aFlag;
	local TournamentPlayer aTPawn;
	local int 		ID, delta;
	local int 		BestTime, BestTimeClient, TimeStampClient;
	local int 		NewTime;
	local int 		TimeStamp;
	local string 	BestTimeClientStr, ctf;
	local float		Stamp;
	
	//real player showing up?
	aTPawn = TournamentPlayer(Other);
	if(aTPawn != None)
	{
		Stamp = Level.TimeSeconds;
				
		ID = Controller.FindPlayer(aTPawn);

		if(aTPawn.AttitudeToPlayer == ATTITUDE_Follow || aTPawn.Health <= 0)
			return;//go respawning dude

		//no boost caps if recs are not allowed || disabled: -> if player was boosted his attitudetoplayer is follow[atm keep for safety]
		if(Controller.CheckIfBoosted(ID) && (Controller.RecordsWithoutBoost == 1 || (Controller.RecordsWithoutBoost == 2 && !Controller.bCooperationMap)))
			return;

		// check if scored capture
		if (aTPawn.PlayerReplicationInfo.Team == Team)
		{
			if (CTFFlag(aTPawn.PlayerReplicationInfo.HasFlag) != None)
			{
				//CAPTURE
				//keep old trick for polycap - protection
				aTPawn.AttitudeToPlayer = ATTITUDE_Follow;
				
				aTPawn.SetCollision(False);
				//Score!
				aFlag = CTFFlag(aTPawn.PlayerReplicationInfo.HasFlag);
				//measure captime
				NewTime = Controller.MAX_CAPTIME - Controller.MeasureTime(ID, Stamp);
				
				TimeStamp = Controller.CurTimestamp();//make the timestamp
				BestTime = Controller.GetBestTimeServer(ID); // on the current map
				BestTimeClient = Controller.GetBestTimeClient(ID); // set in client's user.ini
				BestTimeClientStr = Controller.GetBestTimeClientStr(ID);
				TimestampClient = Controller.GetTimeStampClient(ID);
				
				Controller.SendEvent("btcap", aTPawn.PlayerReplicationInfo.PlayerID, NewTime, TimeStamp);

				//BT++ ignores 100 minutes +
				if(newTime > 0)
				{
					//see if this was a new reference-run
					Controller.KeepCheckpointTimes(ID, NewTime);
					ctf = Controller.FormatCentiseconds(NewTime, False);
					
					//tell the player
					if(Team == 0)
						aTPawn.ClientMessage("You capped " $ Controller.LevelName $ " on RED in " $ ctf $ ".");
					else if(Team == 1)
						aTPawn.ClientMessage("You capped " $ Controller.LevelName $ " on BLUE in " $ ctf $ ".");
	
					if(!Controller.GetSTFU(ID))
					{
						//hide the scoreboard
						//aTPawn.bShowScores = False;
					
						aTPawn.ClearProgressMessages();
						aTPawn.SetProgressTime(9);
						
						aTPawn.SetProgressColor(Controller.OrangeColor, 0);
						aTPawn.SetProgressMessage("Cap Time: "$ctf, 0);
													
						if(NewTime > BestTime)//improved captime or first cap in this game
						{
							//maprecord broken
							if(NewTime > Controller.MapBestTime && Controller.MapBestTime != 0)
							{
								if(BestTimeClient!=0 && BestTimeClient != -1 && NewTime > BestTimeClient)
								{
									//show improvement
									delta = NewTime - BestTimeClient;
									aTPawn.SetProgressMessage("You have beaten your record (" $ ((Timestamp - TimestampClient)/86400) $ " day(s) old) by "$Controller.FormatCentiseconds(delta, True)$ " !", 2);
									aTPawn.SetProgressMessage("Previous was: "$BestTimeClientStr, 3);
									
									//improvement of the server record
									delta = NewTime - Controller.MapBestTime;
									aTPawn.SetProgressMessage("You have beaten the server record by " $ Controller.FormatCentiseconds(delta, True) $" !!!", 4);
									aTPawn.SetProgressMessage("Previous was "$Controller.GRI.MapBestTime$" (set by "$Controller.MapBestPlayer@Controller.GRI.MapBestAge$ " day(s) ago)", 5);

								}
								else
								{
									//improvement of the server record
									delta = NewTime - Controller.MapBestTime;
									aTPawn.SetProgressMessage("You have beaten the server record by " $ Controller.FormatCentiseconds(delta, True) $" !!!", 2);
									aTPawn.SetProgressMessage("Previous was: "$Controller.GRI.MapBestTime$" (set by "$Controller.MapBestPlayer@Controller.GRI.MapBestAge$ " day(s) ago)", 3);
									
									//ignore PB; rare case that not improved own but broke maprecord
								}
							}
							else if(BestTimeClient > 0)//valid pb time was saved and transmitted to the server
							{
								if(NewTime > BestTimeClient)//improved personal record
								{
									//show improvement
									delta = NewTime - BestTimeClient;
									aTPawn.SetProgressMessage("You have beaten your record (" $ ((Timestamp - TimestampClient)/86400) $ " day(s) old) by "$Controller.FormatCentiseconds(delta, True)$ " !", 2);
									aTPawn.SetProgressMessage("Previous was: "$BestTimeClientStr, 3);
									if(Controller.MapBestTime != 0)
										aTPawn.SetProgressMessage("Server record is "$Controller.GRI.MapBestTime$" (set by "$Controller.MapBestPlayer@Controller.GRI.MapBestAge$ " day(s) ago)",4);
								}
								else //1st cap = worse than personal record
								{
									aTPawn.SetProgressMessage("Your record is "$BestTimeClientStr, 2);
									if(Controller.MapBestTime != 0)
										aTPawn.SetProgressMessage("Server record is "$Controller.GRI.MapBestTime$" (set by "$Controller.MapBestPlayer@Controller.GRI.MapBestAge$ " day(s) ago)", 3);

									//show difference to personal record
									delta = BestTimeClient - NewTime;
									aTPawn.SetProgressColor(Controller.OrangeColor, 4);
									if(delta != 0)
										aTPawn.SetProgressMessage("Compared to your record +" $ Controller.FormatCentiseconds(delta, True), 4);
									else
										aTPawn.SetProgressMessage("Same time as your record :)", 4);
								}
							}
							else if(Controller.MapBestTime != 0)//no pb present
							{
								aTPawn.SetProgressMessage("First cap on this map? Congratulations!",2);
								aTPawn.SetProgressMessage("Server record is "$Controller.GRI.MapBestTime$" (set by "$Controller.MapBestPlayer@Controller.GRI.MapBestAge$ " day(s) ago)",3);
							}
							else //also no server record
								aTPawn.SetProgressMessage("You did the first cap on record for this map.",2);
						}
						else //worse cap for this game -> worse than pb
						{
							if(BestTimeClient != 0)
								aTPawn.SetProgressMessage("Your record is: "$BestTimeClientStr,2);
							if(Controller.MapBestTime != 0)
								aTPawn.SetProgressMessage("Server record is "$Controller.GRI.MapBestTime$" (set by "$Controller.MapBestPlayer@Controller.GRI.MapBestAge$ " day(s) ago)",3);

							//show difference to personal record
							delta = - NewTime + BestTimeClient;
							aTPawn.SetProgressColor(Controller.OrangeColor, 4);
							if(delta != 0)
								aTPawn.SetProgressMessage("Compared to your record +" $ Controller.FormatCentiseconds(delta, True), 4);
							else
								aTPawn.SetProgressMessage("Same time as your record :)", 4);

						}
					}
					
					Controller.SetBestTime(NewTime, TimeStamp, ID, ctf);
				}
				
				if(Controller.bNoCapSuicide && InStr(Caps(string(Level.Game.class)), Caps("BunnyTrack")) != -1)
					ScoreFlag(aTPawn, aFlag, NewTime);
				else
					CTFGame(Level.Game).ScoreFlag(aTPawn, aFlag);
			
				//stats/backup
				Controller.PlayerCapped(ID);

				if(Controller.bRespawnAfterCap)
				{
					aTPawn.Weapon.bCanThrow = false; // just in case someone doesn't play with Insta
					Level.Game.DiscardInventory(aTPawn);
					//stop the player
					aTPawn.AddVelocity(-aTPawn.velocity);
					aTPawn.Acceleration = vect(0, 0, 0);
					aTPawn.SetPhysics(PHYS_None);

					// if not the end of game, teleport the player to the start point
					if(!Level.Game.bGameEnded)
					{
						Level.Game.PlayTeleportEffect(aTPawn, True, True);
						aTPawn.bHidden = True;
						aTPawn.SoundDampening = 0.5;
						aTPawn.GoToState('Dying');
					}
				}
				
				//get rid of flag = last action
				aFlag.SendHome();
				aTPawn.PlayerReplicationInfo.HasFlag = None;
				Controller.SetNoneFlag(ID);
				if(Controller.bMultiFlags)//multiflags -> destroy this one
					aFlag.Destroy(); 

				// make the lights around the player normal
				aTPawn.AmbientGlow = aTPawn.Default.AmbientGlow;
				aTPawn.LightType = LT_None;
			}
		}
		// no flag ? please take one :) - this only for multiflag-behaviour
		else if(Controller.bMultiFlags && aTPawn.PlayerReplicationInfo.HasFlag == None)
		{
			// Let me see .... which one to spawn ? Red or blue one ?
			if(Team == 1)
				NewFlag = Spawn(class'BTPPFlagBlue');
			else
				NewFlag = Spawn(class'BTPPFlagRed');
			// Spawning from external package failure ....
			if(NewFlag==None)
			{
				log("BTPlusPlus: Error, you did not add BTPlusPlusv0991_C to ServerPackages !!!");
				if(Team==1)
					NewFlag = Spawn(class'CTFFlag');
				else
					NewFlag = Spawn(class'RedFlag');
			}
			//Need to set a few variables to avoid Accessed Nones
			NewFlag.Skin = Flag.Skin;
			NewFlag.Team = Team;
			NewFlag.HomeBase = HomeBase;
			NewFlag.Holder = aTPawn;
			NewFlag.GotoState('Held');
			Flag.bHome = True;  //Fixes the CTFHud
			HomeBase.bHidden = false;  //Changes the variable set by GoToState('Held')
			NewFlag.Skin = Flag.Skin; //Compatibility with custom flag textures
			Holder = aTPawn;
			Holder.MoveTimer = -1;
			Holder.PlayerReplicationInfo.HasFlag = NewFlag;
			//Do everything as the normal flag script do ....
			Holder.MakeNoise(2.0);
			SetHolderLighting();
			if ( Holder.IsA('TournamentPlayer') && TournamentPlayer(Holder).bAutoTaunt )
				Holder.SendTeamMessage(None, 'OTHER', 2, 10);

			if (Level.Game.LocalLog != None)
				Level.Game.LocalLog.LogSpecialEvent("flag_taken", Holder.PlayerReplicationInfo.PlayerID, CTFGame(Level.Game).Teams[Team].TeamIndex);
			BroadcastLocalizedMessage( class'CTFMessage', 6, Holder.PlayerReplicationInfo, None, CTFGame(Level.Game).Teams[Team] );
		}
	}
}

defaultproperties
{
     CollisionRadius=48.000000
     CollisionHeight=30.000000
     bStatic=False
     bHidden=True
     bCollideActors=True
     NetPriority=3.000000
}
