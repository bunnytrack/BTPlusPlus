/*
    BTPlusPlus 0.991
    Copyright (C) 2004-2006 Damian "Rush" Kaczmarek
    + 2010 modifications

    This program is free software; you can redistribute and/or modify
    it under the terms of the Open Unreal Mod License version 1.1.
*/
class BTPlusPlus extends Mutator config(BTPlusPlus);

var const string Version;
var const int MAX_CAPTIME;

var bool bInitialized;
var int CurrentID;
var color GreenColor;
var color RedColor;
var color OrangeColor;

var string LevelName; // current level name
var int lastTimestamp;//save the latest timestamp generated

var bool bSpawnFlags; // used to tell the Timer() function what to do
var bool bFlagsSpawned; // used to control the Timer() behaviour

// Here are the config variables
var config bool bEnabled;
var config bool bAutoLoadInsta;
var config bool bMultiFlags;
var config bool bRespawnAfterCap;
var config bool bAntiBoost;
var config bool bBlockBoostForGood;
var config string AllowBoostOn;
var config bool bNoKilling;
var config string AllowKillingOn;
var config bool bForceMoversKill;
var config string ForceMoversKill[10];
var config bool bNoCapSuicide;
var config int RecordsWithoutBoost; // 0 - disabled, 1 -  enabled, 2 - enabled without cooperation maps
var config bool bDisableInTournament;
var config bool bCarcasses;
var config bool bGhosts;
var config bool bOnlyABGhosts;
var config bool bDisableInNonBTMaps;
var config bool bFocusBestCapper;
var config string BoardLabel;
var config string CountryFlagsPackage;
var config bool bNoSpamBinds; //detect and clear any not plain 'suicide' binding
var bool TimerBugTriggered;
var bool bStandalone;//backup and others only needed for network-games

var PlayerStart playerStarts[50];//list of up to 50 playerstarts - collected on mapstart
var vector actual_PS_Locations[50];//corresponding actual spawning locations

var TeleEffectNotify TEN;

var Actor focusOn;

struct CheckPointTime
{
	var float 	savedTime;//first entering-time of the fastest cap in this game
	var float 	currentTime;//first entering-time measured for this run
};

struct Sides //some data per side (RED/BLUE) - checkpointtimes & myStart
{
	var int 	bestCap;
	var bool 	bGotCap;
	var CheckPointTime CPT[64];//up to 64 zones per map - save separately per side
	var int 	myStart;//if != -1 always spawn at this prefered playerstart
};

struct PlayerInfo
{
	var 		PlayerPawn Player;
	var int 	PlayerID;
	var         BTPPReplicationInfo RI;
	var			ClientData Config;
	var bool	bStartedFirstRun;
	var bool 	bExtractData;//online - extracting data out of the string sent by the user is pending
	var bool 	bSawZoneChange;//know if player moved to a second or further zone on this run
	var bool	bCouldCompare;//know if the player had times to compare to
	var byte	tryCount;
	var byte	myTeam;
	var byte 	ZoneNumber;
	var int		backupLink; //which index in the backups-array this player is assigned to
	var Sides 	side[2];
	var int		lastStart;
};

var PlayerInfo PI[32];

struct SpecInfo
{
	var	PlayerPawn Spec;
	var BTPPReplicationInfo RI;
};
var SpecInfo SI[32];

struct BU_DATA //backup BT++ data for restore if a player reconnects to the same game
{
	var int 	BU_Runs;//BTPPRI->Runs
	var int		BU_Caps;//BTPPRI->Caps
	var int		BU_Deaths;//PRI->Deaths
	var int		BU_Frags;//PRI->Score
	var int		BU_BestTime;//BTPPRI->BestTime
	var string	BU_BestTimeStr;//BTPPRI->BestTimeStr
	var float	BU_JoinTime;//BTPPRI->JoinTime
	var string	BU_PlayerName;//PRI->PlayerName <- THIS IS THE ID TO MATCH
};

var BU_DATA backups[64];//backup data of the first 64 players in a game
var int backupIndex;

var bool bAllowKilling; // can be different than bNoKilling because of AllowKillingOn
var bool bAllowBoost;  // only important if bBlockBoostForGood - ... boosting allowed on current map

var int MapBestTime;
var string MapBestPlayer;

// BTPlusPlus other objects
var BTPPHUDNotify HUD;
var ServerRecords SR;
var Mutator Insta;
var BTPPGameReplicationInfo GRI;

var Actor IpToCountry; // IpToCountry external actor for resolving country names
var bool bNoIpToCountry; // will be true if CountryFlags texture is not in the serverpackages

var bool bCooperationMap;

// actors to which the custom events will be send
var Actor EventHandlers[10];
var int EventHandlersCount;

//====================================
// CheckDisableNeed - Check whether to run and if to use IpToCountry module
// Triggered in: PreBeginPlay
//====================================
function int CheckDisableNeed()
{
	local string packages;
	local BTPlusPlus temp;

	packages = ConsoleCommand("get ini:Engine.Engine.GameEngine ServerPackages");

	if(InStr(Caps(packages), Caps(CountryFlagsPackage)) == -1)
		bNoIpToCountry=True;
	if(!bEnabled)
		return 1;
	if(InStr(Caps(packages), Caps("BTPlusPlusv0"$Version$"_C")) == -1) // check if we're in the serverpackages
		return 2;
	if(!ClassIsChildOf(Level.Game.class, class'CTFGame')) // check for a CTF game
		return 3;
	if(bDisableInTournament && class<DeathMatchPlus>(Level.Game.Class).Default.bTournament) // check for Tournament running
		return 4;
	if(bDisableInNonBTMaps && Caps(Left(string(Level), 3)) !="BT-" && Caps(Left(string(Level), 7)) !="CTF-BT-" && Caps(Left(string(Level), 3)) !="BT+" && Caps(Left(string(Level), 7)) !="CTF-BT+") // check for a BT or BT+ map
		return 5;
	foreach AllActors(class'BTPlusPlus', temp) // check if there isn't another instance running
		if(temp != self)
			return 6;
	return 0;
}

//====================================
// PreBeginPlay - Mutator registration, Auto loading instagib, Spawning classes, Setting scoreboard
//====================================
function PreBeginPlay()
{
	local PlayerStart ps;
	local int i;
	local DeathMatchPlus dmp;
	local PlayerDummy pd;
		
	if(bInitialized)
		return;
	bInitialized = True;
	
	bStandalone = (Level.NetMode == NM_Standalone);
		
	CurTimeStamp();//make first timestamp (for possible reuse: calculate record-ages)
	
	Tag = 'BTPlusPlus';

	log("+-----------------", tag);
	log("| BTPlusPlus v0."$Version$" by [es]Rush*bR", tag);

	//force this:
	Log("| forcing Hardcore mode / 100% Gamespeed / 35% AirControl", tag);
	dmp = DeathMatchPlus(Level.Game);
	if(dmp != None)
	{
		dmp.bHardcoreMode = True;
		dmp.AirControl = dmp.Default.AirControl;
		dmp.MinPlayers = 0;
	}
	if(Level.Game.GameSpeed != 1f)
		Level.Game.SetGameSpeed(1f);
	//having 2 teams through CTFGame (BT2 subclasses with no changes to this)

	
	//collect all playerstarts: (up to 50) + actual locations where players will spawn
	
	i = 0;
	foreach AllActors(class'PlayerStart', ps)
	{
		if(pd == None)
			pd = Level.Spawn(class'PlayerDummy',,, ps.Location);
			
		if(i < 50)
		{
			//see where the player ends if using this playerstart
			pd.SetLocation(ps.Location);
			playerStarts[i] = ps;
			actual_PS_Locations[i] = pd.Location;
			i++;
		}
	}		
	pd.Destroy();
		
	switch (CheckDisableNeed())
	{
		case 1:
			log("| Status: Disabled", tag);
			log("| Reason: bEnabled = False in the config", tag);
			log("+-----------------", tag);
			Destroy();
			return;
		case 2:
			log("| Status: Disabled", tag);
			log("| Reason: BTPlusPlusv0"$Version$"_C is not in ServerPackages!", tag);
			log("+-----------------", tag);
			Destroy();
			return;
		case 3:
			log("| Status: Disabled", tag);
			log("| Reason: Gametype is not based on CTF!", tag);
			log("+-----------------", tag);
			Destroy();
			break;
			return;
		case 4:
			log("| Status: Disabled", tag);
			log("| Reason: Server is in Tournament mode and bDisableInTournament = True", tag);
			log("+-----------------", tag);
			Destroy();
			return;
		case 5:
			log("| Status: Disabled", tag);
			log("| Reason: Map is not a BT map and bDisableInNonBTMaps = True", tag);
			log("+-----------------", tag);
			Destroy();
			return;
		case 6:
			log("| Status: Disabled", tag);
			log("| Reason Another instance of BTPlusPlus detected!", tag);
			log("+-----------------", tag);
			Destroy();
			return;
		case 0:
			log("| Status: Running", tag);
			log("+-----------------", tag);
	}

	Level.Game.BaseMutator.AddMutator(Self);
	Level.Game.RegisterDamageMutator(Self);
	Level.Game.RegisterMessageMutator(Self);
	
	if(bAutoLoadInsta)
	{
		if((!bDisableInTournament || !class<DeathMatchPlus>(Level.Game.Class).Default.bTournament)
		&& (!bDisableInNonBTMaps || (Left(string(Level), 3)=="BT-" || Left(string(Level), 7)=="CTF-BT-")))
		{
			RemoveActorsForInsta();
			Insta = Level.spawn(class'InstaGibBT');
			Insta.DefaultWeapon = class'SuperShockRifleBT';
			Level.Game.BaseMutator.AddMutator(Insta);
		}
	}
	GRI = Level.spawn(class'BTPPGameReplicationInfo');
	HUD = Level.spawn(class'BTPPHUDNotify');
	
	TEN = Level.Spawn(class'TeleEffectNotify');
	GRI.bShowAntiBoostStatus = bAntiBoost;
	if(bAntiBoost)
		GRI.bShowAntiBoostStatus = !bBlockBoostForGood;
	GRI.CountryFlagsPackage = CountryFlagsPackage;
	GRI.BoardLabel = BoardLabel;
	Level.Game.ScoreBoardType = class'BTScoreBoard';
}

//====================================
// PreBeginPlay - initializing ServerRecords, Binding IpToCountry, Retrieving saved records, Setting timer to spawn custom flags, Setting movers to kill, Setting killing block
//====================================
function PostBeginPlay()
{
	local int i;
	
	LevelName = GetLevelName();
		
	// these are the symbols of cooperation maps, for 3 players or 2 players
	if(InStr(LevelName, "-III") != -1 || InStr(LevelName, "-II") != -1)
		bCooperationMap = True;

	SR = spawn(class'ServerRecords');
	
	if(!bNoIpToCountry)
		foreach AllActors(class'Actor', IpToCountry)
		{
			if(string(IpToCountry.class) == "IpToCountry.LinkActor")
				break;
			else
				IpToCountry = None;
		}

	//get index
	i = SR.CheckRecord(LevelName);

	if(i != -1 && SR.getCaptime(i) != 0)
	{
		//get server record ready for usage
		MapBestTime = SR.getCaptime(i);
		MapBestPlayer = SR.getPlayerName(i);

		GRI.MapBestAge = string((lastTimestamp - SR.getTimestamp(i))/86400);//age in whole days
		GRI.MapBestTime = FormatCentiseconds(MapBestTime, False);
		GRI.MapBestPlayer = MapBestPlayer;
	}
	

	//Create ini if doesn't exist.
	SaveConfig();

	
	bSpawnFlags = True;
		// flags aren't here yet so we have to mess with them a moment later ...
		// flags still have to be original after 1 second after the game start cause there is a custom flag mutator on the market which replaces them
	SetTimer(1.1, false);
	bFlagsSpawned = True;

	if(bForceMoversKill)
		CheckMovers();
	if(bNoKilling)
		CheckBlockKilling();
	//if(bAllowBoost)??? huh
		CheckAllowBoost();
		
	
	SendEvent("btpp_started");

}

//====================================
// Tick - New player detection, CheckPointTimes, runtime measurements
// Inherited from class'Actor'
//====================================
function tick(float DeltaTime)
{
	local int i;
	Super.tick(DeltaTime);

	//update run-times
	for(i = 0;i < 32;i++)
	{
		if(PI[i].Player == None)
			continue;
			
		if(PI[i].RI.bNeedsRespawn)//1 update if idle
			PI[i].RI.runTime = 0;
		else
			PI[i].RI.runTime = MeasureTime(i, Level.TimeSeconds);
	}
	
	CheckForNewPlayer();
	CheckPointTimes();
}

//====================================
// Timer - Setting flags collision, Clearing flag list, Sending help
// Triggered in: PostBeginPlay, ModifyPlayer
//====================================
function Timer()
{
	local PlayerPawn PP;
	local FlagDisposer FlagD;
	local CTFFlag TmpFlag;
	local int i;
	local bool bOnceAgain;

	if(bSpawnFlags)
	{
				
		Foreach AllActors(Class'CTFFlag',TmpFlag)
		{
			if(TmpFlag.Team>1)
				continue;
		
			// makes the flag untouchable(disables Touch function in it) - default = multiflag
			TmpFlag.SetCollision(false, false, false);
			//reduce CollisionSize a bit
			TmpFlag.SetCollisionSize(47, 29);

			//generate one FlagDisposer at the same spot as the flag, as malplaced FlagBases may be at a different place than the actual flag(crucial for single flag caps)
			FlagD = Spawn(class'FlagDisposer',,, TmpFlag.Location);
			FlagD.Controller = Self;
			FlagD.Homebase = TmpFlag.HomeBase;
			FlagD.Team = TmpFlag.Team;
			FlagD.Flag = TmpFlag;
		}
		for(i=0;i<4;i++)
		{
			// It makes the flag icons vanish on the player hud so that we can draw our own
			CTFReplicationInfo(Level.Game.GameReplicationInfo).FlagList[i]=None;
		}

		//make Flags touchable for original one-flag behavior
		if(!bMultiFlags)
			SetMultiFlags(False);
		bSpawnFlags = False;
		return;
	}

	//extract cpts?
	for(i = 0;i < 32;i++)
	{
		//Instruction: how to transform recs (comment out this and 'keepmyrecs' on next releases/use this on new versions of btppuser
		if(PI[i].Config != None && PI[i].Config.bGotNoRecords)
		{
			PI[i].Config.bGotNoRecords = False;//one msg
			/* NO MSG RIGHT NOW
			//guide for players how to keep their records done with an older version
			PI[i].Player.ClientMessage(">>> IF you want to transform your old records to the new time", , True);
			PI[i].Player.ClientMessage(">>> do this:");
			PI[i].Player.ClientMessage(">>> Close UT | open UnrealTournament/System/BTRecords.ini");
			PI[i].Player.ClientMessage(">>> edit [BTPlusPlusv097..._C.UserConfig] to [BTPlusPlusv0991_C.UserConfig]");
			PI[i].Player.ClientMessage(">>> save & come back! | enter 'mutate keepmyrecs' into console.");*/
		}
	
		//try to extract the checkpoint-times out of the data sent by the player
		if(PI[i].bExtractData)
		{
			if(PI[i].Player != None)
			{
				//data already there?
				if(PI[i].Config.CPTs[0] ~= "")
				{
					if(++PI[i].tryCount == 10)
						PI[i].bExtractData = False;//end waiting
					else //another call needed
						bOnceAgain = True;
					
					continue; //check the next PI
				}
				
				ExtractData(i);//get the checkpoint-times out of the string the user sent
				CPTInfo(i);
				//successful
				PI[i].bExtractData = False;
			}
			else //player gone
				PI[i].bExtractData = False;
		}
	}
	if(bOnceAgain)
		SetTimer(2f, False);
}

//====================================
// CheckMovers - Set predefined movers to kill players or set the default values
// Triggered in: PostBeginPlay, Mutate
//====================================
function CheckMovers(optional bool bDefaults)
{
	local int i, j, en;
	local bool bMapMatch;
	local mover M;
	local Actor A;

	if(bDefaults)
	{
		Foreach AllActors(Class'Mover',M)
		{
			M.MoverEncroachType = M.default.MoverEncroachType;
		}
	}
	for(i=0;i<10;i++)
	{
		if(ForceMoversKill[i] == "")
			continue;
		en = ElementsNum(SepRight(ForceMoversKill[i]));
		for(j = 1;j <= en;j++)
		{
			if(InStr(Caps(LevelName), Caps(SelElem(SepRight(ForceMoversKill[i]),j, ","))) != -1)
			{
				bMapMatch = True;
				break;
			}
		}
		if(bMapMatch)
		{
			en = ElementsNum(SepLeft(ForceMoversKill[i]));
			for(j = 1;j <= en;j++)
			{
				Foreach AllActors(Class'Mover',M)
				{
					if(string(M.Name) == SelElem(SepLeft(ForceMoversKill[i]), j, ","))
						M.MoverEncroachType = ME_CrushWhenEncroach;
				}
			}
		}
	}
}

//====================================
// CheckBlockKilling - On predefined maps allow killing
// Triggered in: PostBeginPlay, Mutate
//====================================
function bool CheckBlockKilling()
{
	local int i, en;
	local string elem;

	en = ElementsNum(AllowKillingOn);
	for(i=1;i<=en;i++)
	{
		elem = SelElem(AllowKillingOn, i, ",");
		if(elem == "")
			return false;
		if(InStr(Caps(LevelName), Caps(elem)) != -1)
		{
			bAllowKilling = True;
			return True;
			break;
		}
	}
	bAllowKilling = False;
	return False;
}

//====================================
// CheckAllowBoost - On predefined maps allow boosting if it is normally forbidden
// Triggered in: PostBeginPlay, Mutate
//====================================
function bool CheckAllowBoost()
{
	local int i, en;
	local string elem;

	en = ElementsNum(AllowBoostOn);
	for(i = 1;i <= en;i++)
	{
		elem = SelElem(AllowBoostOn, i, ",");
		if(elem == "")
			return false;
		if(InStr(Caps(LevelName), Caps(elem)) != -1)
		{
			bAllowBoost = True;
			return true;
			//break;
		}
	}
	bAllowBoost = False;
	return False;
}


//#########################################################################
//### PLAYER AND RECORD MANAGMENT FUNCTIONS
//#########################################################################

//====================================
// DeleteCP_CMD - Delete the personal checkpoint times on the current map for a player (trigger by a console cmd)
// Triggered in: Mutate
//====================================
function DeleteCP_CMD(int ID, PlayerPawn Sender)
{
	if(PI[ID].side[0].bGotCap || PI[ID].side[1].bGotCap)
	{
		DeleteCPT(ID, True);
		Sender.ClientMessage("Your checkpoint-times on this map are deleted.");
	}
}
//====================================
// CheckForNewPlayer - Check for new player
// Triggered in: Tick, ModifyPlayer
//====================================
function CheckForNewPlayer()
{
	local Pawn Other;
	local PlayerPawn pp;

	if(Level.Game.CurrentID > CurrentID) // At least one new player has joined - sometimes this happens faster than tick
	{
		for( Other=Level.PawnList; Other!=None; Other=Other.NextPawn )
			if(Other.PlayerReplicationInfo.PlayerID == CurrentID)
				break;
		CurrentID++;

		// Make sure it is a player.
		pp = PlayerPawn(Other);
		if(pp == none || !Other.bIsPlayer)
			return;
		if(Other.PlayerReplicationInfo.bIsSpectator && !Other.PlayerReplicationInfo.bWaitingPlayer)
			InitNewSpec(pp);
		else
			InitNewPlayer(pp);
	}
}

//====================================
// InitNewPlayer - Check for new player
// Triggered in: CheckForNewPlayer
//====================================
function InitNewPlayer(PlayerPawn P)
{
	local int i;
	i = FindFreePISlot();
	
	PI[i].Player = P;
	if(!bCarcasses)
		PI[i].Player.CarcassType = None;
	PI[i].PlayerID = P.PlayerReplicationInfo.PlayerID;
		
	PI[i].Config = spawn(class'BTPPUser.ClientData', P);
			
	if(PI[i].RI != none)
	{
		PI[i].RI.Destroy();
		PI[i].RI = None;
	}
	PI[i].RI = spawn(class'BTPPReplicationInfo', P);
	PI[i].RI.IpToCountry = IpToCountry;
	PI[i].RI.PlayerID = P.PlayerReplicationInfo.PlayerID;
	PI[i].RI.JoinTime = Level.TimeSeconds;
	
	PI[i].ZoneNumber = P.FootRegion.ZoneNumber;//don't react on this zonechange (doubled -> also at modifyplayer)
	PI[i].bStartedFirstRun = False;
	PI[i].bSawZoneChange = False;//reset for first run
	PI[i].bCouldCompare = False;
	
	//clear cpt+mystart data of potential previous player
	DeleteCPT(i, False);
	PI[i].side[0].myStart = -1;
	PI[i].side[1].myStart = -1;
	PI[i].lastStart = -1;
	
	if(!bStandalone)//Level.NetMode != NM_Standalone)//online
	{
		//little delay until data is here -> wait & check
		PI[i].bExtractData = True;
		PI[i].tryCount = 0;
		if(TimerRate == 0f)//timer not running?
			SetTimer(1f, False);//start it now
			
			
		//try to restore data for reconnectors
		PI[i].backupLink = RestoreData(P.PlayerReplicationInfo.PlayerName, i);
	
		//Player already did first run? -> preparation for ModifyPlayer needed
		if(P.PlayerReplicationInfo.Deaths != 0 || PI[i].RI.Runs != 0)
		{
			PI[i].bStartedFirstRun = True;//ok not needed
			
			//prepare for regular reset in ModifyPlayer
			PI[i].RI.bNeedsRespawn = True;
			P.AttitudeToPlayer = ATTITUDE_Follow;
		}
		
		if(bNoSpamBinds)
			PI[i].RI.NoSpamBinds();
	}
	else
	{
		//standalone -> just read it (private use)
		ExtractData(i);
		CPTInfo(i);
	}

	//ghost-players if wanted
	if((bAntiBoost && bGhosts && (!bOnlyABGhosts || PI[i].Config.bAntiBoost) && !bBlockBoostForGood) || ((bCooperationMap || bAllowBoost) && bGhosts))
		P.SetDisplayProperties(STY_Translucent, P.default.Texture, P.default.bUnLit, P.Default.bMeshEnviromap);
	
}

//====================================
// InitNewSpec - Check for new spectator
// Triggered in: Tick
//====================================
function InitNewSpec(PlayerPawn P)
{
	local int i;

	i = FindFreeSISlot();
	SI[i].RI = spawn(class'BTPPReplicationInfo', P);
	SI[i].RI.JoinTime = Level.TimeSeconds;
	SI[i].RI.PlayerID = P.PlayerReplicationInfo.PlayerID;
	SI[i].Spec = P;
}

//====================================
// FindFreePISlot - Find a free place in a PlayerInfo struct
// Triggered in: InitNewPlayer
//====================================
function int FindFreePISlot()
{
	local int i;

	for(i=0;i<32;i++)
	{
		if(PI[i].Player == none)
			return i;
		else if(PI[i].Player.Player == none)
				return i;
	}
}

//====================================
// FindFreeSISlot - Find a free place in a SpecInfo struct
// Triggered in: InitNewPlayer
//====================================
function int FindFreeSISlot()
{
	local int i;
	for(i=0;i<32;i++)
		if(SI[i].Spec == none)
			return i;
		else if(SI[i].Spec.Player == none)
			return i;
}

//====================================
// FindPlayer - Find a player in the PlayerInfo struct by a Pawn object
// Triggered in: Almost everywhere :P
//====================================
function int FindPlayer(Pawn P)
{
	local int i, ID;
	ID = P.PlayerReplicationInfo.PlayerID;
	for(i=0;i<32;i++)
	{
		if(PI[i].PlayerID == ID)
			return i;
	}
	return -1;
}

//====================================
// RestoreData - Looks for the PlayerName in the BU-array and returns matching index; -1 if not refound and no capacity left; if an entry matches PlayerName data is restored
// Triggered in: InitNewPlayer
//====================================
function int RestoreData(string PlayerName, int ID)
{
	local int i;

	for(i = 0;i<backupIndex;i++)
	{
		if(backups[i].BU_PlayerName == PlayerName)//refound
		{
			//restore data as it was backed up
			PI[ID].RI.Runs = backups[i].BU_Runs;
			PI[ID].RI.Caps = backups[i].BU_Caps;
			PI[ID].Player.PlayerReplicationInfo.Deaths = backups[i].BU_Deaths;
			PI[ID].Player.PlayerReplicationInfo.Score = backups[i].BU_Frags;
			PI[ID].RI.BestTime = backups[i].BU_BestTime;
			PI[ID].RI.BestTimeStr = backups[i].BU_BestTimeStr;
			PI[ID].RI.JoinTime = backups[i].BU_JoinTime;
			
			//fix the time on the SB
			PI[ID].RI.SetTimeDelta(Level.TimeSeconds - backups[i].BU_JoinTime);
			//reference i 
			return i;
		}
	}
		
	if(backupIndex < 64) //player gets a new entry
	{
		//new Join -> backup JoinTime
		backups[backupIndex].BU_JoinTime = Level.TimeSeconds;//BU_JoinTime = first time the player entered this game
		return backupIndex++;
	}
	else //none left
		return -1;
	
}

//====================================
// FindPlayer - Find a player in the PlayerInfo struct by a PlayerID
// Triggered in: GetItemName
//====================================
function int FindPlayerByID(coerce int ID)
{
	local int i;
	for(i=0;i<32;i++)
		if(PI[i].PlayerID == ID)
			return i;
}

//====================================
// GetBestTimeClient, GetBestTimeServer, GetSTFU, CheckIfBoosted - used to access structs data from FlagDisposer, trying to acces it normally would result in "too complex variable error"
// Triggered in: class'FlagDisposer'.Touch()
//====================================
function int GetBestTimeClient(int ID) { return PI[ID].Config.BestTime; }
function string GetBestTimeClientStr(int ID) { return PI[ID].Config.BestTimeStr; }
function int GetTimeStampClient(int ID){ return PI[ID].Config.TimeStamp; }
function int GetBestTimeServer(int ID) { return PI[ID].RI.BestTime; }
function bool GetSTFU(int ID) { return PI[ID].Config.bSTFU; }
function bool CheckIfBoosted(int ID) { return PI[ID].RI.bBoosted; }
function bool SetNoneFlag(int ID) { PI[ID].RI.SetNoneFlag(); }

//====================================
// SetBestTime - Saves a new record, in clientside if needed, in serverside. It also informs other players about new record.
// Triggered in: class'FlagDisposer'.Touch()
//====================================
function SetBestTime(int Time, int TimeStamp, int i, string ctf)
{
	local int j;
	local string Nick;

	//replicate the captime
	PI[i].RI.lastCap = MAX_CAPTIME - Time;

	if(Time > PI[i].Config.BestTime)
	{
		// save the time clientside
		PI[i].Config.AddRecord(LevelName, Time, TimeStamp);
		//update on the serverside
		PI[i].Config.BestTime = Time;
		PI[i].Config.BestTimeStr = ctf;//FormatCentiseconds(Time, False);
		PI[i].Config.Timestamp = Timestamp;
	}

	if(Time > PI[i].RI.BestTime)
	{
		PI[i].RI.BestTime = Time;
		PI[i].RI.BestTimeStr = ctf;
		
		//try backup
		if(!bStandalone && PI[i].backupLink != -1)
		{
			backups[PI[i].backupLink].BU_BestTime = PI[i].RI.BestTime;
			backups[PI[i].backupLink].BU_BestTimeStr = PI[i].RI.BestTimeStr;
			//name got updated in PlayerCapped()
		}
	}
	
	//Cap of the game
	if(GRI.GameBestTimeInt < Time)//new best cap in this game
	{
		GRI.GameBestTimeInt = Time;
		GRI.GameBestTime = ctf;
		GRI.GameBestPlayer = PI[i].Player.PlayerReplicationInfo.PlayerName;
		
		focusOn = PI[i].Player;
	}
	
	//is this a new server record?
	if(Time > MapBestTime)
	{
		MapBestTime = Time;
		MapBestPlayer = PI[i].Player.PlayerReplicationInfo.PlayerName;
		
		SR.AddRecord(LevelName, MapBestTime, CleanName(MapBestPlayer), TimeStamp);
		
		SendEvent("server_record", PI[i].PlayerID, MapBestTime);
		GRI.MapBestTime = ctf;
		GRI.MapBestPlayer = MapBestPlayer;
		GRI.MapBestAge = "0";//this one is all new
		
		//tell other players & spectators
		for(j=0;j<32;j++)
		{
		 	if(PI[j].RI == none)
		 		continue;
			if(PI[j].Player != PI[i].Player && !PI[j].Config.bSTFU)
			{
    			PI[j].Player.ClearProgressMessages();
    			PI[j].Player.SetProgressTime(5);
				PI[j].Player.SetProgressMessage(MapBestPlayer$" has set up a new server record !!!", 5);
   				PI[j].Player.SetProgressColor(OrangeColor, 6);
				PI[j].Player.SetProgressMessage(GRI.MapBestTime, 6);
			}
		}
		for(j=0;j<32;j++)
		{
			if(SI[j].RI == none)
				continue;

			SI[j].Spec.ClearProgressMessages();
			SI[j].Spec.SetProgressTime(5);
			SI[j].Spec.SetProgressMessage(MapBestPlayer$" has set up a new map record !!!", 5);
			SI[j].Spec.SetProgressColor(OrangeColor, 6);
			SI[j].Spec.SetProgressMessage(GRI.MapBestTime, 6);
		}
	}
}

//====================================
// PlayerCapped - Event on cap, increases some variables.
// Triggered in: class'FlagDisposer'.Touch()
//====================================
function PlayerCapped(int ID)
{
	PI[ID].RI.bNeedsRespawn = True;//no caps before respawn
	PI[ID].RI.Caps++;
	PI[ID].RI.Runs++;
	
	//try backup
	if(!bStandalone && PI[ID].backupLink != -1)
	{
		backups[PI[ID].backupLink].BU_Caps = PI[ID].RI.Caps;
		backups[PI[ID].backupLink].BU_Runs = PI[ID].RI.Runs;
		backups[PI[ID].backupLink].BU_Frags = PI[ID].Player.PlayerReplicationInfo.Score;//just updated +7
		//latest name
		backups[PI[ID].backupLink].BU_PlayerName = PI[ID].Player.PlayerReplicationInfo.PlayerName;
	}
}

//====================================
// MsgAll - Sends message to all players
// Triggered in: Mutate
//====================================
function MsgAll(string Msg)
{
	local int i;

	for(i=0;i<32;i++)
	{
		if(PI[i].RI == None)
			continue;
		if(!PI[i].Config.bSTFU)
			PI[i].Player.ClientMessage(Msg);
	}
}

//====================================
// SetAntiBoostOn - Enables AntiBoost for a specified Pawn
// Triggered in: MutatorTeamMessage, Mutate
//====================================
function SetAntiBoostOn(Pawn P, int ID)
{
	P.ClientMessage("You can't be boosted from now on!");
	if(!PI[ID].Config.bSet) // will be true only first time, cause bSet=true after the next call
		P.ClientMessage("Command 'mutate boost' or 'say boost' will allow boosting.");
	PI[ID].Config.SetAntiBoost(True);
	P.bFromWall = True;
	
	if(bGhosts && bOnlyABGhosts)
		P.SetDisplayProperties(STY_Translucent, P.default.Texture, P.default.bUnLit, P.Default.bMeshEnviromap);
}

//====================================
// SetAntiBoostOff - Disables AntiBoost for a specified Pawn
// Triggered in: MutatorTeamMessage, Mutate
//====================================
function SetAntiBoostOff(Pawn P, int ID)
{
	P.ClientMessage("You can now be boosted !");
	if(!PI[ID].Config.bSet) // will be true only first time, cause bSet=true after the next call
		P.ClientMessage("Command 'mutate noboost' or 'say noboost' will block boosting");
	PI[ID].Config.SetAntiBoost(False);
	P.bFromWall = False;
	
	if(bGhosts && bOnlyABGhosts)
		P.SetDisplayProperties(STY_Normal, P.default.Texture, P.default.bUnLit, P.Default.bMeshEnviromap);
}


//====================================
// MeasureTime - Calculates the current runtime and returns floored CENTISECONDS
// Triggered in: class'FlagDisposer'.Touch, KeepCheckpointTimes
//====================================
function int MeasureTime(int ID, float TimeSeconds)
{
	return 90.909090909*(TimeSeconds - PI[ID].RI.StartTime);
}

//====================================
// CheckPointTimes - detects players entered a new zone -> if wanted a checkpoint-time is taken
// Triggered in: class'BTPlusPlus'.Tick
//====================================
function CheckPointTimes()
{
	local int i;
	local float delta;
	
	for(i=0;i<32;i++)
	{
		//player still there/end of list? ....woot/return = bug
		if(PI[i].Player == None || PI[i].Player.Player == None)
			continue;//return;
		else if(PI[i].RI.bNeedsRespawn || PI[i].Player.PlayerReplicationInfo.bWaitingPlayer)
			continue;//ignore these players' zonechanges (dead or waiting to enter the game);
		
		//did the zone change?
		if(PI[i].Player.FootRegion.ZoneNumber != PI[i].ZoneNumber)
		{
			PI[i].bSawZoneChange = True;
			PI[i].ZoneNumber = PI[i].Player.FootRegion.ZoneNumber;//update
			
			//1st entering only
			if(PI[i].side[PI[i].myTeam].CPT[PI[i].ZoneNumber].currentTime == 0f)
			{
				PI[i].side[PI[i].myTeam].CPT[PI[i].ZoneNumber].currentTime = (Level.TimeSeconds - PI[i].RI.StartTime) / 1.1;
				
				//want's to know and is not running for too long
				if(PI[i].Config.bCheckpoints && int(PI[i].side[PI[i].myTeam].CPT[PI[i].ZoneNumber].currentTime*100) < MAX_CAPTIME)
				{
					PI[i].Player.ClearProgressMessages();
					PI[i].Player.SetProgressTime(2);

					//show difference to best run
					if(PI[i].side[PI[i].myTeam].bGotCap && 
						PI[i].side[PI[i].myTeam].CPT[PI[i].ZoneNumber].savedTime != 0f)//can compare? entered this zone on best run?
					{	
						PI[i].bCouldCompare = True;
						delta = PI[i].side[PI[i].myTeam].CPT[PI[i].ZoneNumber].currentTime - PI[i].side[PI[i].myTeam].CPT[PI[i].ZoneNumber].savedTime;
						if(Abs(delta) < 0.01f)//equal
						{
							PI[i].Player.SetProgressMessage("equal to best run!", 0);
						}
						else if(delta < 0f)//better
						{
							PI[i].Player.SetProgressColor(GreenColor, 0);
							PI[i].Player.SetProgressMessage("checkpoint:  -" $ FormatCentiseconds(-delta*100, True), 0);
						}	
						else //append '+'
						{
							PI[i].Player.SetProgressColor(RedColor, 0);
							PI[i].Player.SetProgressMessage("checkpoint:  +" $ FormatCentiseconds(delta*100, True), 0);
						}
					}
					else //can't compare: just print the time
						PI[i].Player.SetProgressMessage("checkpoint-time:  " $ FormatCentiseconds(PI[i].side[PI[i].myTeam].CPT[PI[i].ZoneNumber].currentTime*100, True), 0);
				}
				else if(PI[i].side[PI[i].myTeam].bGotCap && !PI[i].bCouldCompare && 
						PI[i].side[PI[i].myTeam].CPT[PI[i].ZoneNumber].savedTime != 0f) // see if comparing is possible
					PI[i].bCouldCompare = True;
			}
		}
	}
}

//====================================
// KeepCheckpointTimes - controls checkpointtimes to compare from now on; returns captime ct formatted
// Triggered in: class'FlagDisposer'.Touch
//====================================
function KeepCheckpointTimes(int ID, int ct)
{
	local int i;
	local string ctf;
	local bool bSave;
	
	if(!PI[ID].bSawZoneChange)//no traveling between zones on this successful run 
	{
		//improved slower time with zonechanges with one without -> save nothing
		if(PI[ID].side[PI[ID].myTeam].bGotCap && ct >= PI[ID].side[PI[ID].myTeam].bestCap)
		{
			DeleteCPTOnSide(ID, PI[ID].myTeam);//clear on the server
			bSave = True;//got to change clientside
		}
	}
	else //traveled zones
	{
	/*@todo !!!!if(bSawZoneChange= TRUE HERE && !bCouldCompare) -> no times to compare to -> if there is a ct on this side -> clear it
	-> use current times without restriction*/
	
		//save cpts of a better run?
		if(!PI[ID].side[PI[ID].myTeam].bGotCap || 
			ct > PI[ID].side[PI[ID].myTeam].bestCap ||
			!PI[ID].bCouldCompare)//first cap OR improvement OR cpts from 098 where linked to the wrong side -> discard old (ct already lost; no big use to handle)
		{
			PI[ID].side[PI[ID].myTeam].bestCap = ct;//new best
			PI[ID].side[PI[ID].myTeam].bGotCap = True;
			
			//use this as reference
			for(i = 0;i<64;i++)
				PI[ID].side[PI[ID].myTeam].CPT[i].savedTime = PI[ID].side[PI[ID].myTeam].CPT[i].currentTime;

			bSave = True;
		}
	}
	
	if(bSave)//changes to be saved?
		SaveData(ID);
}

//SaveData - merges mapname, ct+cpts and myStarts and clears or saves current status on the clientside
function SaveData(int ID)
{
	local string sendText;
	local int i;
	
	//clear entry of this map?
	if(!PI[ID].side[0].bGotCap && !PI[ID].side[1].bGotCap && 
		PI[ID].side[0].myStart == -1 && PI[ID].side[1].myStart == -1)
	{
		PI[ID].Config.AddCPT("");
		return;
	}
	
	//compose a string that keeps all checkpoint times collected so far for this map -> save clientside
	sendText = LevelName $ ",";

	//////////////////////////
	//////////////////////////cpts?
	if(PI[ID].side[0].bGotCap || PI[ID].side[1].bGotCap)
	{
		sendText = sendText $ PI[ID].side[0].bestCap $ "," $ PI[ID].side[1].bestCap $ ":";

		//i is used for iteration
		if(PI[ID].side[0].bGotCap)//RED cpts
		{
			for(i = 0;i < 64;i++)
			{
				if(i == 0)//first zone-time
					sendText = sendText $ SaveFormat(PI[ID].side[0].CPT[i].savedTime);
				else //rest is concatenated with commas
					sendText = sendText $ "," $ SaveFormat(PI[ID].side[0].CPT[i].savedTime);
			}
		}

		sendText = sendText $ ":";

		if(PI[ID].side[1].bGotCap)//BLUE
		{
			for(i = 0;i < 64;i++)
			{
				if(i == 0)//first zone-time
					sendText = sendText $ SaveFormat(PI[ID].side[1].CPT[i].savedTime);
				else //rest is concatenated with commas
					sendText = sendText $ "," $ SaveFormat(PI[ID].side[1].CPT[i].savedTime);
			}
		}
	}
	//////////////////////////
	//////////////////////////
	//separate myStarts
	sendText = sendText $ "|";
	
	//////////////////////////
	//////////////////////////myStarts?
	if(PI[ID].side[0].myStart != -1 || PI[ID].side[1].myStart != -1)
	{
		if(PI[ID].side[0].myStart != -1)
			sendText = sendText $ PlayerStartID(playerStarts[PI[ID].side[0].myStart].Name);
			
		sendText = sendText $ ";";
		
		if(PI[ID].side[1].myStart != -1)
			sendText = sendText $ PlayerStartID(playerStarts[PI[ID].side[1].myStart].Name);
	}
	//////////////////////////
	//////////////////////////

	//save @ player:
	PI[ID].Config.AddCPT(sendText);
}

//====================================
// CPTInfo - if present prints info about best runs recorded with cpts
// Triggered in: Mutate, Timer
//====================================
function CPTInfo(int i)
{
	if(PI[i].side[0].bGotCap || PI[i].side[1].bGotCap) //atleast one side with checkpoint-times -> display runtimes
	{
		PI[i].Player.ClientMessage("[BT++] Here on " $ LevelName $ " you got checkpoint-times of",, PI[i].Config.bCheckpoints);
		PI[i].Player.ClientMessage(FormatCentiseconds(PI[i].side[0].bestCap, False) $ " on RED and");
		PI[i].Player.ClientMessage(FormatCentiseconds(PI[i].side[1].bestCap, False) $ " on BLUE for comparison.");
	}
}


//### END OF PLAYER AND RECORD MANAGMENT FUNCTIONS

//#########################################################################
//### TEXT FUNCTIONS - used all over the place :)
//#########################################################################
//====================================
// PlayerStartID - returns the ID of the playerstart identified by startName -> used to save myStart
//====================================
static function string PlayerStartID(name startName)
{
	local string s;
	s = string(startName);//'PlayerStartX'
	if(Left(s, 11) == "PlayerStart")
		return Mid(s, 11);
	else
		return "";
}


//====================================
// CleanName - needed to remove "\? out of playernames
//====================================
static function string CleanName(string playername)
{
	local int i;
		
	i = InStr(playername, Chr(34));
	while(i != -1)
	{
		playername = Left(playername, i) $ Mid(playername, i + 1);
		i = InStr(playername, Chr(34));
	}
	
	i = InStr(playername, "?");
	while(i != -1)
	{
		playername = Left(playername, i) $ Mid(playername, i + 1);
		i = InStr(playername, "?");
	}
	
	i = InStr(playername, "\\");
	while(i != -1)
	{
		playername = Left(playername, i) $ Mid(playername, i + 1);
		i = InStr(playername, "\\");
	}
	return playername;

}

//====================================
// ExtractData - takes the raw string the player submitted and assigns cpts to the variables ready for usage
//====================================
function ExtractData(int index)
{
	local string raw, temp, playerStartName;
	local int i, k, side;
	local bool bCorrectionNeeded;
	

	//get it manually
	if(bStandalone)//Level.NetMode == NM_Standalone)
	{
		i = PI[index].Config.SearchCPT(LevelName);
		if(i != -1)//cut off mapname here
			raw = Mid(PI[index].Config.CPTs[i], 
						InStr(PI[index].Config.CPTs[i], ",") + 1);
	}
	else
		raw = PI[index].Config.CPTs[0];

	
	//new format after mapname was removed from the left: "captime_red,captime_blue:cpts_red:cpts_blue|myStartRED;myStartBLUE"
	
	if(raw ~= "")
		return;//nothing to do - if offline (@todo -> delete all and save)/empty or didn't find

	temp = SepLeft(raw);//get the captimes-part (left of first ":" / Mapname is already removed)
	if(temp != "")
	{
		i = InStr(temp, ",");
	
		if(i != -1)
		{
			//extract captimes to sides/valid cap?
			PI[index].side[0].bestCap = int(Left(temp, i));
			if(PI[index].side[0].bestCap != 0)
				PI[index].side[0].bGotCap = True;

			PI[index].side[1].bestCap = int(Mid(temp, i + 1));
			if(PI[index].side[1].bestCap != 0)
				PI[index].side[1].bGotCap = True;
				
			if(!PI[index].side[0].bGotCap && !PI[index].side[1].bGotCap)//no captimes -> discard cpts
			{
				DeleteCPT(index, False);//clear all cpts data but do not save changes yet
				bCorrectionNeeded = True;//but later we do 
			}
		}
		////////////////////////////////
		//now get all checkpoint-times on red -> single - array from 098 is guessed to be done with the faster ct
		raw = SepRight(raw);//raw = all possible cpts (+ mystarts)
		////////////////////////////////
	}
	// else raw remains unchanged -> just "|myStartRed;myStartBlue"
		
	
	//extract the myStarts (first):
	if(InStr(raw, "|") != -1)
	{
		//get the myStart IDs
		temp = SepRight(raw, "|");
		if(temp != "")//empty = no myStarts
		{
			//red
			k = InStr(temp, ";");
			if(k != -1)//no semicolon = no valid myStart entries
			{
				//try to extract and find in playerStarts
				
				if(k > 0)//set on red
				{
					playerStartName = "PlayerStart" $ Left(temp, k);
					//Log("search " $ playerStartName, 'debug');
					for(i = 0;i<50;i++)
					{
						if(playerStarts[i] == None)
							break;//end-of-list
						if(string(playerStarts[i].name) == playerStartName)//right name
						{
							if(0 == playerStarts[i].TeamNumber)//right team?
							{
								PI[index].side[0].myStart = i;
								//Log("matched " $ playerStartName, 'debug');
							}
							else
							{
								PI[index].side[0].myStart = -1;
								//Log("mystart linking wrong team(0)");
							}
							break;
						}
					}
					//not found/wrong link -> save changed string
					if(PI[index].side[0].myStart == -1)
						bCorrectionNeeded = True;
				}
				
				if(k < Len(temp) - 1)//set on blue
				{
					//... Mid(temp, k+1)
					playerStartName = "PlayerStart" $ Right(temp, Len(temp) - 1 - k);
					//Log("search " $ playerStartName, 'debug');
					for(i = 0;i<50;i++)
					{
						if(playerStarts[i] == None)
							break;
						if(string(playerStarts[i].name) == playerStartName)
						{
							if(1 == playerStarts[i].TeamNumber)
							{
								PI[index].side[1].myStart = i;
								//Log("matched " $ playerStartName, 'debug');
							}
							else
							{
								PI[index].side[1].myStart = -1;
								//Log("mystart linking wrong team(1)");
							}
							break;
						}
					}
					
					//not found/wrong link -> save changed string
					if(PI[index].side[1].myStart == -1)
						bCorrectionNeeded = True;
				}
				
				//laststart is not valid if now a mystart was restored
				//not dead or didn't change team
				if((!PI[index].Player.bHidden || PI[index].myTeam == PI[index].Player.PlayerReplicationInfo.Team) &&
					PI[index].side[PI[index].myTeam].myStart != -1)
						PI[index].lastStart = -1;
				
			}
			else
				bCorrectionNeeded = True;//clear it
		}
		else
			bCorrectionNeeded = True;//@todo ?? | added by default, so no correction needed...
		//prepare cpts extraction
		raw = SepLeft(raw, "|");
	}
	//END_ MYSTARTS EXTRACTION_
	////////////////////////////////
	
	if(raw != "" && (PI[index].side[0].bGotCap || PI[index].side[1].bGotCap))//any cpts data to match?
	{
		if(InStr(raw, ":") != -1)//new format = a second ":"
		{
			temp = SepLeft(raw);//red cpts
			
			//got a ct and cpts here
			if(temp != "" && PI[index].side[0].bGotCap)
			{
				i = InStr(temp, ",");
				for(k = 0;k < 64;k++)
				{
					//extract
					if(k < 63)
						PI[index].side[0].CPT[k].savedTime = float(Left(temp, i));
					else
						PI[index].side[0].CPT[k].savedTime = float(temp);
						
					//next
					if(k < 63)
					{
						temp = Mid(temp, i + 1);//cut off
						if(k < 62)
							i = InStr(temp, ",");//next separator
					}
				}
			}
			else //corrupt data -> clear
			{
				DeleteCPTOnSide(index, 0);
				bCorrectionNeeded = True;//got to save changed data
			}

			
			temp = SepRight(raw);//blue cpts
			if(temp != "" && PI[index].side[1].bGotCap)
			{
				i = InStr(temp, ",");
				for(k = 0;k < 64;k++)
				{
					//extract
					if(k < 63)
						PI[index].side[1].CPT[k].savedTime = float(Left(temp, i));
					else
						PI[index].side[1].CPT[k].savedTime = float(temp);
					
					//next
					if(k < 63)
					{
						temp = Mid(temp, i + 1);//cut off
						if(k < 62)
							i = InStr(temp, ",");//next separator
					}
				}
			}
			else //corrupt data -> clear
			{
				DeleteCPTOnSide(index, 1);
				bCorrectionNeeded = True;//got to save changed data
			}
			
			/*
			//no cpts left -> clear & save & done
			if(!PI[index].side[0].bGotCap && !PI[index].side[1].bGotCap)
			{
				DeleteCPT(index, True);
				return;
			}*/
		}
		else //old format -> match cpts with best ct (it's a guess!)
		{
			//fast exit -> empty cpts
			if(raw == "" || raw == ",,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,")
			{
				DeleteCPT(index, True);
				return;
			}

			bCorrectionNeeded = True;//move to new format
			side = 0;
			//no red ct or the blue time is better -> match with blue ct
			if(!PI[index].side[0].bGotCap || (PI[index].side[1].bestCap > PI[index].side[0].bestCap))
				side = 1;

			//extract out of raw;
			
			//clear ct on other side
			if(side == 0)
			{
				PI[index].side[1].bGotCap = False;//no blue data
				PI[index].side[1].bestCap = 0;
			}
			else
			{
				PI[index].side[0].bGotCap = False;//no red data
				PI[index].side[0].bestCap = 0;
			}

			//extract
			i = InStr(raw, ",");
			for(k = 0;k < 64;k++)
			{
				//extract
				if(k < 63)
					PI[index].side[side].CPT[k].savedTime = float(Left(raw, i));
				else
					PI[index].side[side].CPT[k].savedTime = float(raw);
				
				//next
				if(k < 63)
				{
					raw = Mid(raw, i + 1);//cut off
					if(k < 62)
						i = InStr(raw, ",");//next separator
				}
			}
		}
	}
	else //no data -> delete all
	{
		DeleteCPT(index, True);//actually save and exit; mystarts are processed
		return;
	}
	
	//save updated data
	if(bCorrectionNeeded)
		SaveData(index);
	
}

//DeleteCPT - removes cpt data on current map; client- (save=true) and serverside
function DeleteCPT(int index, bool save)
{
	local int i;
	
	//delete serverside
	PI[index].side[0].bGotCap = False;
	PI[index].side[0].bestCap = 0;
	
	PI[index].side[1].bGotCap = False;
	PI[index].side[1].bestCap = 0;
	
	for(i = 0;i<64;i++)
	{
		PI[index].side[0].CPT[i].savedTime = 0f;
		PI[index].side[1].CPT[i].savedTime = 0f;
	}
	
	//update clientside if wanted
	if(save)
		SaveData(index);
}

//DeleteCPTOnSide - clears cpts on side; used if new best caps without zonechanges happen
function DeleteCPTOnSide(int index, int s)
{
	local int i;

	PI[index].side[s].bGotCap = False;
	PI[index].side[s].bestCap = 0;
	
	for(i = 0;i<64;i++)
		PI[index].side[s].CPT[i].savedTime = 0f;
}


//====================================
// ElementsNum - Counts a specified character in a string(and thus elements) and returns the countresult-1;
//====================================
static final function int ElementsNum(string Str, optional string Char)
{
	local int count, pos;

	if(Char == "")
		Char = ","; // this is a default separator for config lists
	while(true)
	{
		pos = InStr(Str, Char);
		if(pos == -1)
			break;
		Str = Mid(Str, pos+1);
		count++;
	}
	return count+1;
}

//====================================
// SelElem - Selects an element from a string where elements are separated by a "Char"
//====================================
static final function string SelElem(string Str, int Elem, optional string Char)
{
	local int pos, count;
	if(Char == "")
		Char = ":"; // this is a default separator

	while( (Elem--) >1)
	{
		pos = InStr(Str, Char);
		if(pos != -1)
			Str = Mid(Str, pos+1);
		else
			return "";
	}
	pos = InStr(Str, Char);
	if(pos != -1)
    	return Left(Str, pos);
	else
		return Str;
}

//====================================
// SepLeft - Separates a left part of a string with a certain character as a separator
//====================================
static final function string SepLeft(string Input, optional string Char)
{
	local int pos;
	if(Char == "")
		Char = ":"; // this is a default separator

	pos = InStr(Input, Char);
	if(pos != -1)
		return Left(Input, pos);
	else
		return "";
}

//====================================
// SepLeft - Separates a right part of a string with a certain character as a separator
//====================================
static final function string SepRight(string Input, optional string Char)
{
	local int pos;
	if(Char == "")
		Char = ":"; // this is a default separator

	pos = InStr(Input, Char);
	if(pos != -1)
		return Mid(Input, pos+1);
	else
		return "";
}

//====================================
// DelSpaces - Deletes spaces from an end of a string
//====================================
static final function string DelSpaces(string Input)
{
	local int pos;
	pos = InStr(Input, " ");
	if(pos != -1)
		return Left(Input, pos);
	else
		return Input;
}

//====================================
// FormatCentiseconds - formats Score to m:ss.cc
// Triggered in: ?
//====================================
static final function string FormatCentiseconds(coerce int Centis, bool plain)
{
	if(Centis <= 0 || Centis >= Default.MAX_CAPTIME)
		return "-:--";
	
	if(!plain)
		Centis = Default.MAX_CAPTIME - Centis;
	
	if(Centis / 100 < 60)//less than 1 minute -> no formatting needed
	{
		if(Centis % 100 < 10)
			return (Centis / 100) $ ".0" $ int(Centis % 100);
		else
			return (Centis / 100) $ "." $ int(Centis % 100);
	}
	else
	{
		if(Centis % 100 < 10)
			return FormatScore(Centis / 100) $ ".0" $ int(Centis % 100);
		else
			return FormatScore(Centis / 100) $ "." $ int(Centis % 100);
	}
}

//====================================
// FormatScore - format seconds to mm:ss
// Triggered in: PostBeginPlay, SetBestTime
//====================================
static final function string FormatScore(coerce int Score)
{
	local int secs;
	local string sec;

	secs = int(Score % 60);
	if ( secs < 10 )
		sec = "0" $string(secs);
		else
	sec = "" $string(secs);

	return string(Score / 60) $":"$sec;
}

//====================================
// SaveFormat - rounds to centiseconds and returns as string; empty if 0f
// Triggered in: KeepCheckpointTimes
//====================================
static final function string SaveFormat(float seconds)
{
	local string text;
	
	if(seconds == 0f)
		return "";
	
	//round?
	if(seconds % 0.01f >= 0.005f)
		seconds += 0.01f;
	
	text = string(seconds);
	//centiseconds only
	return Left(text, InStr(text, ".") + 3);
}

//====================================
// GetLevelName - Returns a level name(file name) in a readable format
// Triggered in: PostBeginPlay
//====================================
function string GetLevelName()
{
	local string Str;
	local int Pos;

	Str = string(Level);
	Pos = InStr(Str, ".");
	if(Pos != -1)
		return Left(Str, Pos);
	else
		return Str;
}
//### END OF TEXT FUNCTIONS


//#########################################################################
//### MUTATOR FUNCTIONS - inherited from class'Mutator'
//#########################################################################
//====================================
// AddMutator = Little security against initializing this script twice.
//====================================
function AddMutator(Mutator M)
{
	if ( M.Class != Class )
		Super.AddMutator(M);
	else if ( M != Self )
		M.Destroy();
}

//====================================
// MutatorTakeDamage - checks for instagib rays trying to boost a player or to kill someone, it prevents or allows it
// Inherited from class'Mutator'
//====================================
function MutatorTakeDamage( out int ActualDamage, Pawn Victim, Pawn InstigatedBy, out Vector HitLocation, out Vector Momentum, name DamageType)
{
	local int VictimID;
	local int BoosterID;

	//new condition allowing self-boosting with normal weapons
	if(InstigatedBy != None && PlayerPawn(InstigatedBy) != None && Victim != InstigatedBy && PlayerPawn(Victim) != None)
	{
		VictimID = FindPlayer(Victim);
		BoosterID = FindPlayer(InstigatedBy);

		if( (
				(PI[VictimID].Config.bAntiBoost && bAntiBoost) 
				|| (InstigatedBy.PlayerReplicationInfo.Team != Victim.PlayerReplicationInfo.Team) || bBlockBoostForGood) 
			&& !bAllowBoost)
		{
			Momentum = Vect(0,0,0);
		}
		else if((RecordsWithoutBoost == 1 || (RecordsWithoutBoost == 2 && !bCooperationMap)) && InstigatedBy.PlayerReplicationInfo.Team == Victim.PlayerReplicationInfo.Team)
		{
			if(!PI[VictimID].RI.bBoosted)
			{
				PI[VictimID].RI.bBoosted = True;
				//@todo Victim.AttitudeToPlayer = FOLLOW -> instead of check at flagdisposer
				Victim.AttitudeToPlayer = ATTITUDE_Follow;
				SendEvent("boost_record_prevent", PI[VictimID].PlayerID, PI[BoosterID].PlayerID);
			}
		}
		else if(InstigatedBy.PlayerReplicationInfo.Team == Victim.PlayerReplicationInfo.Team)
			SendEvent("boost", PI[VictimID].PlayerID, PI[BoosterID].PlayerID);

		if(((Victim.PlayerReplicationInfo.HasFlag == none || bMultiFlags) && bNoKilling && !bAllowKilling) || (InstigatedBy.PlayerReplicationInfo.Team == Victim.PlayerReplicationInfo.Team))
			ActualDamage = 0;
	}

	if ( NextDamageMutator != None )
		NextDamageMutator.MutatorTakeDamage( ActualDamage, Victim, InstigatedBy, HitLocation, Momentum, DamageType );
}



//====================================
// ScoreKill - Decreases points increased by a standard function, updates number of runs and sets start times for the timer
//====================================
function ScoreKill(Pawn Killer, Pawn Other)
{
	local int ID;
	
	if ( NextMutator != None )
		NextMutator.ScoreKill(Killer, Other);

	if(PlayerPawn(Killer) != None)
		Killer.PlayerReplicationInfo.Score -= 1.0;
	
	ID = FindPlayer(Other);
	
	if(ID != -1)
	{
		PI[ID].RI.Runs ++;
		PI[ID].RI.bNeedsRespawn = True;
		Other.AttitudeToPlayer = ATTITUDE_Follow;

		
		//try backup
		if(!bStandalone && PI[ID].backupLink != -1)
		{
			backups[PI[ID].backupLink].BU_Runs = PI[ID].RI.Runs;
			backups[PI[ID].backupLink].BU_Deaths = Other.PlayerReplicationInfo.Deaths;
			backups[PI[ID].backupLink].BU_Frags = Other.PlayerReplicationInfo.Score;
			//latest name
			backups[PI[ID].backupLink].BU_PlayerName = Other.PlayerReplicationInfo.PlayerName;
		}
	}
	
	//stop the player; as no carcass will be spawned
	if(!bCarcasses)
	{
		Other.AddVelocity(-Other.velocity);
		Other.SetPhysics(PHYS_None);
	}
}


//HandleEndGame - focus on the player with the best captime
function bool HandleEndGame()
{
	local int i, bestTime;
	local PlayerPawn Player;
	local TournamentPlayer tp;
	local Pawn P;
	local TournamentGameReplicationInfo TGRI;
	local bool bRedWon;
	
	if(!bFocusBestCapper)
	{
		if ( NextMutator != None )
			return NextMutator.HandleEndGame();
		else
			return False;
	}
		
	TGRI = TournamentGameReplicationInfo(Level.Game.GameReplicationInfo);
	if(TGRI != None)
	{
//		Log(TGRI.TimeLimit $ " -> " $ TGRI.RemainingTime $ " || " $ TGRI.Teams[0].Score $ " & " $ TGRI.Teams[1].Score );
		//timelimit hit -> accept overtime
		if(TGRI.TimeLimit > 0 && TGRI.Teams[0].Score == TGRI.Teams[1].Score)
			return False;
		
		//Log("handle endgame");
		bRedWon = TGRI.Teams[0].Score > TGRI.Teams[1].Score;
		
		if(focusOn == None)//best capper not available any longer (gone/overtime)
		{
			bestTime = 0;
			for(i = 0;i < 32;i++)//@todo: overtime ended -> seems like the .player != none kicks out here
			{
				//look for remaining player with the best captime
				if(PI[i].Player != None && PI[i].RI.BestTime > bestTime)
				{
					//Log("new best " $ i $ " - " $ PI[i].RI.BestTimeStr);
					bestTime = PI[i].RI.BestTime;
					focusOn = PI[i].Player;
				}
			}
		}
		
		//know the best remaining player now?
		if(focusOn != None)
		{
			//Log("show " $ focusOn);
			//show everyone
			for (P = Level.PawnList; P != None; P = P.NextPawn )
			{
				Player = PlayerPawn(P);
				if (Player != None)
				{
					Player.bBehindView = True;
					if (Player == focusOn)
						Player.ViewTarget = None;
					else
						Player.ViewTarget = focusOn;
	
					//winner- / loser sound
					tp = TournamentPlayer(Player);
					if(tp != None)
						tp.PlayWinMessage(Player.PlayerReplicationInfo.Team == 1 ^^ bRedWon);
				}
			}
			return True;
		}
		else
			return False;
	}
	else
		return False;
}



//====================================
// ModifyPlayer - Checks for new player and sets some variables
//====================================
function ModifyPlayer(Pawn Other)
{
	local int ID, i;
	local vector loc;
	
	CheckForNewPlayer(); // sometimes modifyplayer is being called faster than a tick where usual new player detection is done thus we have to search for new players also here
	
	ID = FindPlayer(Other);
	
	//No bots & ignore waiting players: on gamestart we get another call
	if(ID == -1 && !Other.IsA('TournamentPlayer') || Other.PlayerReplicationInfo.bWaitingPlayer)
	{
		if ( NextMutator != None )
			NextMutator.ModifyPlayer(Other);
		return;
	}
			
	
	//allow grab/cap again
	if(PI[ID].RI.bNeedsRespawn /* && Other.AttitudeToPlayer == ATTITUDE_Follow*/ )
	{
		Other.PlayerReplicationInfo.HasFlag = None;
		Other.AttitudeToPlayer = ATTITUDE_Hate;
		
		PI[ID].RI.bNeedsRespawn = False;//new run -> ready to take the enemy's flag
		Other.SetCollision(Other.Default.bCollideActors);
		PI[ID].RI.lastCap = 0;//get normal timer back on scoreboard/HUD
		
		//protected: only once after cap/death
		PI[ID].RI.StartTime = Level.TimeSeconds;//TIME MEASUREMENT STARTS HERE
		
		//preparations for new checkpoint measurements
		/////////////////////
		PI[ID].ZoneNumber = Other.FootRegion.ZoneNumber;//here we start

		for(i = 0;i < 64;i++)//reset
		{
			PI[ID].side[0].CPT[i].currentTime = 0f;
			PI[ID].side[1].CPT[i].currentTime = 0f;
		}
		/////////////////////

		PI[ID].RI.bBoosted = False;

		Other.bHidden = False; // hidden was set after the cap in class'FlagDisposer' in order to prevent some bugs in showing the player @todo -> is reset @ restartplayer?
		
		PI[ID].bSawZoneChange = False;
		PI[ID].bCouldCompare = False;
		PI[ID].myTeam = Other.PlayerReplicationInfo.Team;
		
		CheckMyStart(ID);
		
	}
	else if(Other.PlayerReplicationInfo.Deaths == 0 && PI[ID].RI.Runs == 0)
	{
		if(!PI[ID].bStartedFirstRun)
		{
			PI[ID].bStartedFirstRun = True;
			PI[ID].RI.StartTime = Level.TimeSeconds;//TIME MEASUREMENT STARTS HERE
			PI[ID].myTeam = Other.PlayerReplicationInfo.Team;

			//Introduce BTPlusPlus / Help cmd
			PI[ID].Player.ClientMessage("BTPlusPlus v0."$Version$" by [es]Rush*bR");
			PI[ID].Player.ClientMessage("Type 'mutate bthelp' in console for more info.");
			
			PI[ID].ZoneNumber = Other.FootRegion.ZoneNumber;//here we start
			CheckMyStart(ID);
			
			//bFromWall = antiboost or not@test
			if(bAntiBoost && PI[ID].Config.bAntiBoost && !bBlockBoostForGood && !bCooperationMap && !bAllowBoost)
				Other.bFromWall = True;
			else
				Other.bFromWall = False;
				
		}
		else if(!TimerBugTriggered)//debug: current try should show this message but prevent the bug
		{
			TimerBugTriggered = True;
			Warn("TimerBug triggered [1]");
		}
	}
	else if(!TimerBugTriggered)//debug: current try should show this message but prevent the bug
	{
		TimerBugTriggered = True;
		Warn("TimerBug triggered [2]");
	}
	
	Other.bBlockPlayers = False;
	

	//like btcp: do & pass on after that
	if ( NextMutator != None )
		NextMutator.ModifyPlayer(Other);
}

//====================================
// MutatorTeamMessage - Allows changing antiboost status also with normal say messages
//====================================
function bool MutatorTeamMessage(Actor Sender, Pawn Receiver, PlayerReplicationInfo PRI, coerce string S, name Type, optional bool bBeep)
{
	local int ID;

	if(Sender == Receiver && Receiver.bIsPlayer && !Receiver.PlayerReplicationInfo.bIsSpectator)
	{
		ID = FindPlayer(PlayerPawn(Sender));
		if(S ~= "MYSTART")
			SetMyStart(ID);
		else if(S ~= "CLEARSTART")
			ClearStart(ID);
		else if(bAntiBoost && !bBlockBoostForGood && !bCooperationMap && !bAllowBoost)
		{
			if(PI[ID].Config.bAntiBoost && S ~= "BOOST")
				SetAntiBoostOff(PlayerPawn(Sender), ID);
			else if(!PI[ID].Config.bAntiBoost && S ~= "NOBOOST")
				SetAntiBoostOn(PlayerPawn(Sender), ID);
		}
	}
	if ( NextMessageMutator != None )
		return NextMessageMutator.MutatorTeamMessage( Sender, Receiver, PRI, S, Type, bBeep );
	else
		return true;
}

//====================================
// Mutate - Shows help, allows to change the settings and provides an interface to searching the record database
//====================================
function Mutate(string MutateString, PlayerPawn Sender)
{
	local string CommandString;
	local string ValueString;
	local string TempString;
	local int i, j, ID, k;
	local bool notDone;

	if ( NextMutator != None )
		NextMutator.Mutate(MutateString, Sender);

	if(!Sender.PlayerReplicationInfo.bIsSpectator)
	{
		ID = FindPlayer(Sender);
		switch(Caps(MutateString))
		{
			case "BTSETTINGS":
				Sender.ClientMessage("BT++ Settings:");
				SendSettings(Sender);
				break;
			case "BTHELP":
			case "BT++HELP":
			case "BTPPHELP":
				Sender.ClientMessage("BT++ Client Commands (type directly in console or bind to key):");
				if(bBlockBoostForGood)
					Sender.ClientMessage("Caution! Boosting is forbidden on this server.");
				Sender.ClientMessage("Mutate +");
				Sender.ClientMessage("- records map/records player ... (Search for time records on current server)");
				Sender.ClientMessage("- myRecs (show all your records)");
				Sender.ClientMessage("- myRecs ... (your records matching the mapname filter ...)");
				Sender.ClientMessage("- myOldRecs X (show all your records that are at least X day(s) old)");
				Sender.ClientMessage("- deleteThisRec (delete your record on this map - only on your side. Server records are not affected)");
				Sender.ClientMessage("- deleteTheseCP (deletes your checkpoint-times on this map)");
				Sender.ClientMessage("- myStart or say 'myStart' (choose last start as myStart)");
				Sender.ClientMessage("- clearStart or say 'clearStart' (back no normal spawning)");
				if(!bBlockBoostForGood)
				{
					Sender.ClientMessage("- boost (Allow others to boost you)");
					Sender.ClientMessage("- noboost (Deny others to boost you)");
				}
				Sender.ClientMessage("- cp_on (show checkpoint times)");
				Sender.ClientMessage("- cp_off (do not show checkpoint times)");
				Sender.ClientMessage("- bthud (Display improved HUD)");
				Sender.ClientMessage("- nobthud (Hide improved HUD)");
				Sender.ClientMessage("- btstfu (Mute BT++ messages)");
				Sender.ClientMessage("- btnostfu (Unmute BT++ messages)");
				Sender.ClientMessage("- btsettings (Reveal BT++ configuration)");
				Sender.ClientMessage("- bthelp (Show this help)");
				Sender.ClientMessage("For admins:");
				Sender.ClientMessage("- BTPP (BT++ settings)");
				if(!bBlockBoostForGood)
					Sender.ClientMessage("** boost and noboost can be just set with SAY instead of MUTATE");
				break;
			case "MYSTART":
				SetMyStart(ID);
				break;
			case "CLEARSTART":
				ClearStart(ID);
				break;
			case "AB_OFF":
			case "BOOST_ON":
			case "BOOST":
				if(PI[ID].Config.bAntiBoost && bAntiBoost && !bBlockBoostForGood && !bCooperationMap && !bAllowBoost)
					SetAntiBoostOff(Sender, ID);
				break;
			case "AB_ON":
			case "BOOST_OFF":
			case "NOBOOST":
				if(!PI[ID].Config.bAntiBoost && bAntiBoost && !bBlockBoostForGood && !bCooperationMap && !bAllowBoost)
					SetAntiBoostOn(Sender, ID);
				break;
			case "ABHELP":
			case "AB_HELP":
			case "BOOSTHELP":
				PI[ID].Player.ClientMessage("BTPlusPlus v0."$Version$" by [es]Rush*bR");
				PI[ID].Player.ClientMessage("Type 'mutate bthelp' in console for more info.");
				break;
			case "NOBTHUD":
				PI[ID].Config.SetBTHud(False);
				break;
			case "BTHUD":
				PI[ID].Config.SetBTHud(True);
				break;
			case "BTSTFU":
				if(PI[ID].Config.bSTFU)
				{
					Sender.ClientMessage("Already set.");
				}
				else
					Sender.ClientMessage("So be it! BTPlusPlus won't say a word to you. 'mutate btnostfu' would make me speak again.");
				PI[ID].Config.SetSTFU(True);
				break;
			case "BTNOSTFU":
				if(!PI[ID].Config.bSTFU)
				{
					Sender.ClientMessage("Already set.");
				}
				else
					Sender.ClientMessage("Yeah, you allowed me to speak again.");
				PI[ID].Config.SetSTFU(False);
				break;
			case "CP_ON":
				if(!PI[ID].Config.bCheckpoints)
				{
					PI[ID].Config.SetCheckpoints(True);
					Sender.ClientMessage("You can see checkpoint-times now (if map uses many zones).");
				}
				//always show status(if cpt-caps there)
				CPTInfo(ID);
				break;
			case "CP_OFF":
				if(PI[ID].Config.bCheckpoints)
				{
					PI[ID].Config.SetCheckpoints(False);
					Sender.ClientMessage("BT++ won't show you your checkpoint-times.");
				}
				break;
			case "MYRECS"://show ALL personal records
				PI[ID].Config.FindAll(lastTimestamp);
				break;
			case "DELETETHISREC":
				if(PI[ID].Config.BestTime != class'ClientData'.Default.BestTime)
				{
					//serverside
					PI[ID].Config.BestTime = class'ClientData'.Default.BestTime;
					PI[ID].Config.BestTimeStr = class'ClientData'.Default.BestTimeStr;
					PI[ID].Config.Timestamp = class'ClientData'.Default.Timestamp;
					//clientside
					PI[ID].Config.DeleteRecord();
					
					//also the game-best time
					PI[ID].RI.BestTime = 0;
					PI[ID].RI.BestTimeStr = "";

					//backup -> delete game-best-time
					if(!bStandalone && PI[ID].backupLink != -1)
					{
						backups[PI[ID].backupLink].BU_BestTime = 0;
						backups[PI[ID].backupLink].BU_BestTimeStr = "";
						//latest name
						backups[PI[ID].backupLink].BU_PlayerName = PI[ID].Player.PlayerReplicationInfo.PlayerName;
					}
					
					Sender.ClientMessage("Your record on this map is deleted");
					
					//including: delete cpts
					DeleteCP_CMD(ID, Sender);
				}
				break;
			case "DELETETHESECP":
				DeleteCP_CMD(ID, Sender);
				break;
			default:
				notDone = True;
				break;
		}
		
		if(!notDone)
			return;//done -> don't go on

		//search own records by mapname			
		if(Left(MutateString, 7) ~= "MYRECS ")
		{
			CommandString = Mid(MutateString, 7);
			if(Len(CommandString) > 0)
				PI[ID].Config.FindByMap(CommandString, lastTimestamp);
			else
				Sender.ClientMessage("No empty space after myrecs or append a substring of a mapname");
			return;
		}
		else if(Left(MutateString, 10) ~= "MYOLDRECS ")
		{
			i = int(Mid(MutateString, 10));
			if(i > 0)
				PI[ID].Config.FindByAge(i, lastTimestamp);
			return;
		}
	}
	if(Left(MutateString, 4) ~= "BTPP" && !Sender.bAdmin )
		Sender.ClientMessage("You cannot set BTPlusPlus until you're a serveradmin.");
	else if(Left(MutateString, 4) ~= "BTPP" && Sender.bAdmin)
	{
		if(Left(MutateString, 4) ~= "BTPP" && Len(MutateString)==4)
		{
			Sender.ClientMessage("BTPlusPlus v0."$Version$" - Configuration menu:");
			Sender.ClientMessage("Settings:");
			SendSettings(Sender);
			Sender.ClientMessage("To set something type 'mutate btpp <option> <value>'.");
			Sender.ClientMessage("Turn BT++ On/Off: 'mutate btpp enabled/disabled'.");
		}
		else if(Left(MutateString, 5) ~= "BTPP ")
		{
			CommandString = Mid(MutateString, 5);
			if(Left(CommandString , 7) ~= "ENABLED" && !bEnabled)
			{
				bEnabled = True;
				Sender.ClientMessage("Applied. So you changed your mind ?");
			}
			else if(Left(CommandString, 8) ~= "DISABLED" && bEnabled)
			{
				bEnabled = False;
				Sender.ClientMessage("Applied. However you need to change the map for it to take effect.");
			}
			else if(Left(CommandString, 10) ~= "DELETEREC ")
			{
				TempString = Mid(CommandString, 10);
				if(SR.DeleteRecord(TempString))//in file
				{
					Sender.ClientMessage("Record gone.");
					//so record of the current map is gone?
					if(TempString ~= LevelName)
					{
						//in current game
						MapBestTime = Default.MapBestTime;
						MapBestPlayer = Default.MapBestPlayer;
						//show that now there is no record
						GRI.MapBestAge = class'BTPPGameReplicationInfo'.Default.MapBestAge;
						GRI.MapBestTime = class'BTPPGameReplicationInfo'.Default.MapBestTime;
						GRI.MapBestPlayer = class'BTPPGameReplicationInfo'.Default.MapBestPlayer;
						
						//also reset the cap-of-the-game
						GRI.GameBestTimeInt = class'BTPPGameReplicationInfo'.Default.GameBestTimeInt;
						GRI.GameBestTime = class'BTPPGameReplicationInfo'.Default.GameBestTime;
						GRI.GameBestPlayer = class'BTPPGameReplicationInfo'.Default.GameBestPlayer;
					}
				}
				else
					Sender.ClientMessage("No record found - give full mapname - browse with 'mutate records map'");
			}
			else if(Left(CommandString, 8) ~="EDITREC ")
			{
				ValueString = Mid(CommandString, 8);
				//replace in BTPlusPlus.ini
				SR.AddRecord(ValueString, -1, "", CurTimestamp());
				//it's the current map -> edit current vars too; read from the ini
				if(Left(ValueString, Len(LevelName)) ~= LevelName)
				{
					//get index
					i = SR.CheckRecord(LevelName);

					if(i != -1 && SR.getCaptime(i) != 0)
					{
						//get server record ready for usage
						MapBestTime = SR.getCaptime(i);
						MapBestPlayer = SR.getPlayerName(i);

						GRI.MapBestAge = string((lastTimestamp - SR.getTimestamp(i))/86400);//age in whole days(roughly)
						GRI.MapBestTime = FormatCentiseconds(MapBestTime, False);
						GRI.MapBestPlayer = MapBestPlayer;
					}
				}
				Sender.ClientMessage("changed record");
			}
			else if(Left(CommandString, 15)~="BAUTOLOADINSTA ")
			{
				ValueString = Mid(CommandString, 15);
				if(ValueString~="TRUE" && !bAutoLoadInsta)
				{
					bAutoLoadInsta = True;
					Sender.ClientMessage("Applied. Instagib will be loaded after the next map start.");
				}
				else if(ValueString~="FALSE" && bAutoLoadInsta)
				{
					bAutoLoadInsta = False;
					Sender.ClientMessage("Applied. However you need to change the map for it to take effect.");
				}
			}
			else if(Left(CommandString, 12)~="BMULTIFLAGS ")
			{
				ValueString = Mid(CommandString, 12);
				if(ValueString ~= "TRUE" && !bMultiFlags)
				{
					bMultiFlags = True;
					SetMultiFlags(True);
					Sender.ClientMessage("Applied.");
				}
				else if(ValueString ~= "FALSE" && bMultiFlags)
				{
					bMultiFlags = False;
					SetMultiFlags(False);
					Sender.ClientMessage("Applied.");
				}
			}
			else if(Left(CommandString, 17) ~="BRESPAWNAFTERCAP ")
			{
				ValueString = Mid(CommandString, 17);
				if(ValueString ~="TRUE" && !bRespawnAfterCap)
				{
					bRespawnAfterCap = True;
					Sender.ClientMessage("Applied.");
				}
				else if(ValueString ~= "FALSE" && bRespawnAfterCap)
				{
					bRespawnAfterCap = False;
					Sender.ClientMessage("Applied.");
				}
			}
			else if(Left(CommandString, 11)~="BANTIBOOST ")
			{
				ValueString = Mid(CommandString, 11);
				if(ValueString ~= "TRUE" && !bAntiBoost)
				{
					bAntiBoost = True;
					GRI.bShowAntiBoostStatus = True;
					Sender.ClientMessage("Applied.");
					MsgAll("AntiBoost function activated.");
				}
				else if(ValueString~="FALSE" && bAntiBoost)
				{
					bAntiBoost = False;
					GRI.bShowAntiBoostStatus = False;
					Sender.ClientMessage("Applied.");
					MsgAll("AntiBoost function disabled.");
				}
			}
			else if(Left(CommandString, 19)~="BBLOCKBOOSTFORGOOD ")
			{
				ValueString = Mid(CommandString, 19);
				if(ValueString ~= "TRUE" && !bBlockBoostForGood)
				{
					bBlockBoostForGood = True;
					if(bAntiBoost)
						GRI.bShowAntiBoostStatus = False;
					Sender.ClientMessage("Applied.");
					MsgAll("Boosting is forbidden from now on.");
				}
				else if(ValueString~="FALSE" && bBlockBoostForGood)
				{
					bBlockBoostForGood = False;
					if(bAntiBoost)
						GRI.bShowAntiBoostStatus = True;
					Sender.ClientMessage("Applied.");
					MsgAll("Boosting is allowed from now on.");
				}
			}
			else if(Left(CommandString, 13)~="ALLOWBOOSTON ")
			{
				ValueString = Mid(CommandString, 13);
				AllowBoostOn = ValueString;
				CheckAllowBoost();
				Sender.ClientMessage("Applied.");
			}
			else if(Left(CommandString, 11)~="BNOKILLING ")
			{
				ValueString = Mid(CommandString, 11);
				if(ValueString~="TRUE" && !bNoKilling)
				{
					bNoKilling = True;
					Sender.ClientMessage("Applied.");
					CheckBlockKilling();
				}
				else if(ValueString~="FALSE" && bNoKilling)
				{
					bNoKilling = False;
					Sender.ClientMessage("Applied.");
				}
			}
			else if(Left(CommandString, 17)~="BFORCEMOVERSKILL ")
			{
				ValueString = Mid(CommandString, 17);
				if(ValueString~="TRUE" && !bForceMoversKill)
				{
					bForceMoversKill = True;
					CheckMovers();
					Sender.ClientMessage("Applied.");
				}
				else if(ValueString~="FALSE" && bForceMoversKill)
				{
					bForceMoversKill = False;
					CheckMovers(True);
					Sender.ClientMessage("Applied.");
				}
			}
			else if(Left(CommandString, 15)~="FORCEMOVERSKILL")
			{
				for(i=0;i<10;i++)
				{
					TempString = Left(CommandString, 15)$"["$string(i)$"]";
					if(Left(CommandString, 18)~=TempString)
					{
						ValueString = Mid(CommandString, 19);
						for(j=0;j<10 && ValueString!="";j++)
						{
							if(ForceMoversKill[j]==ValueString)
								break;
						}

						if(ForceMoversKill[j]==ValueString && ValueString!="")
							Sender.ClientMessage("Error. ForceMoversKill["$string(j)$"] has the same value.");
						else
						{
							if(bForceMoversKill)
								CheckMovers();
							else
								CheckMovers(True);
							Sender.ClientMessage("Applied.");
							ForceMoversKill[i]=ValueString;
							break;
						}
					}
				}
			}
			else if(Left(CommandString, 15)~="ALLOWKILLINGON ")
			{
				ValueString = Mid(CommandString, 15);
				AllowKillingOn = ValueString;
				CheckBlockKilling();
				Sender.ClientMessage("Applied.");
			}
			else if(Left(CommandString, 20)~="RECORDSWITHOUTBOOST ")
			{
				ValueString = Mid(CommandString, 20);
				switch(int(ValueString))
				{
					case 0:
					case 1:
					case 2:
						SetRecordsWithoutBoost(int(ValueString));
						Sender.ClientMessage("Applied.");
						break;
					default:
						Sender.ClientMessage("Must be 0, 1 or 2.");
				}
			}
			else if(Left(CommandString, 21) ~="BDISABLEINTOURNAMENT ")
			{
				ValueString = Mid(CommandString, 21);
				if(ValueString ~="TRUE" && !bDisableInTournament)
				{
					bDisableInTournament = True;
					if(class<DeathMatchPlus>(Level.Game.Class).Default.bTournament)
					{					
						Sender.ClientMessage("Applied. However you need to change the map for it to take effect.");
					}
					else
						Sender.ClientMessage("Applied.");
				}
				else if(ValueString~="FALSE" && bDisableInTournament)
				{
					bDisableInTournament = False;
					Sender.ClientMessage("Applied.");
					if(class<DeathMatchPlus>(Level.Game.Class).Default.bTournament && ((Left(string(Level), 3)=="BT-" || Left(string(Level), 6)=="CTF-BT-") || !bDisableInNonBTMaps ))
					{
						Sender.ClientMessage("Applied. So you've changed your mind ?");
					}
				}
			}
			else if(Left(CommandString, 20)~="BDISABLEINNONBTMAPS ")
			{
				ValueString = Mid(CommandString, 20);
				if(ValueString~="TRUE" && !bDisableInNonBTMaps)
				{
					bDisableInNonBTMaps = True;
					if(Left(string(Level), 3)!="BT-" && Left(string(Level), 6)!="CTF-BT-")
					{
						Sender.ClientMessage("Applied. However you need to change the map for it to take effect.");
					}
					else
						Sender.ClientMessage("Applied.");
				}
				else if(ValueString~="FALSE" && bDisableInNonBTMaps)
				{
					bDisableInNonBTMaps = False;
					Sender.ClientMessage("Applied.");
					if(Left(string(Level), 3)!="BT-" && Left(string(Level), 6)!="CTF-BT-" && (!class<DeathMatchPlus>(Level.Game.Class).Default.bTournament || !bDisableInTournament))
					{
						Sender.ClientMessage("Applied. So you've changed your mind ?");
					}
				}
			}
			else if(Left(CommandString, 17) ~= "BFOCUSBESTCAPPER ")
			{
				ValueString = Mid(CommandString, 17);
				if(ValueString~="TRUE" && !bFocusBestCapper)
				{
					bFocusBestCapper = True;
					Sender.ClientMessage("Will focus player with best cap (if any present).");
				}
				else if(ValueString~="FALSE" && bFocusBestCapper)
				{
					bFocusBestCapper = False;
					Sender.ClientMessage("Don't interfere with the endcams.");
				}
			}
			else if(Left(CommandString, 11)~="BOARDLABEL ")
			{
				ValueString = Mid(CommandString, 11);
				BoardLabel = ValueString;
				Sender.ClientMessage("Applied.");
			}
			else if(Left(CommandString, 4)~="GET ")
			{
				ValueString = Caps(Mid(CommandString, 4));
				switch(ValueString) {
				case "BANTIBOOST":
					Sender.ClientMessage(string(bAntiBoost)); break;
				case "BBLOCKBOOSTFORGOOD":
					Sender.ClientMessage(string(bBlockBoostForGood));
				case "ALLOWBOOSTON":
					Sender.ClientMessage(AllowBoostOn);
				case "BNOKILLING":
					Sender.ClientMessage(string(bNoKilling)); break;
				case "BCARCASSES":
					Sender.ClientMessage(string(bCarcasses)); break;
				case "BGHOSTS":
					Sender.ClientMessage(string(bGhosts)); break;
				case "BONLYABGHOSTS":
					Sender.ClientMessage(string(bOnlyABGhosts)); break;
				case "ALLOWKILLINGON":
					Sender.ClientMessage(AllowKillingOn); break;
				case "BAUTOLOADINSTA":
					Sender.ClientMessage(string(bAutoLoadInsta)); break;
				case "BFORCEMOVERSKILL":
					Sender.ClientMessage(string(bForceMoversKill)); break;
				case "FORCEMOVERSKILL[0]":
					Sender.ClientMessage(ForceMoversKill[0]); break;
				case "FORCEMOVERSKILL[1]":
					Sender.ClientMessage(ForceMoversKill[1]); break;
				case "FORCEMOVERSKILL[2]":
					Sender.ClientMessage(ForceMoversKill[2]); break;
				case "FORCEMOVERSKILL[3]":
					Sender.ClientMessage(ForceMoversKill[3]); break;
				case "FORCEMOVERSKILL[4]":
					Sender.ClientMessage(ForceMoversKill[4]); break;
				case "FORCEMOVERSKILL[5]":
					Sender.ClientMessage(ForceMoversKill[5]); break;
				case "FORCEMOVERSKILL[6]":
					Sender.ClientMessage(ForceMoversKill[6]); break;
				case "FORCEMOVERSKILL[7]":
					Sender.ClientMessage(ForceMoversKill[7]); break;
				case "FORCEMOVERSKILL[8]":
					Sender.ClientMessage(ForceMoversKill[8]); break;
				case "FORCEMOVERSKILL[9]":
					Sender.ClientMessage(ForceMoversKill[9]); break;
				case "RECORDSWITHOUTBOOST":
					Sender.ClientMessage(string(RecordsWithoutBoost)); break;
				case "BDISABLEINTOURNAMENT":
					Sender.ClientMessage(string(bDisableInTournament)); break;
				case "BDISABLEINNONBTMAPS":
					Sender.ClientMessage(string(bDisableInNonBTMaps)); break;
				case "BOARDLABEL":
					Sender.ClientMessage(BoardLabel); break;
				case "BMULTIFLAGS":
					Sender.ClientMessage(string(bMultiFlags)); break;
				case "BRESPAWNAFTERCAP":
					Sender.ClientMessage(string(bRespawnAfterCap)); break;
				}
			}
			SaveConfig();
		}
		return;
	}
	if(Left(MutateString, 8) ~=  "RECORDS ")
	{
		CommandString = Mid(MutateString, 8);
		if(Left(CommandString, 4) ~= "MAP ")
		{
			ValueString = Mid(CommandString, 4);
			if(Len(ValueString) > 1)
				SR.FindByMap(Sender, ValueString, lastTimestamp);//probably not the current timestamp but well enough 
			else
				Sender.ClientMessage("Sorry, the specified string is too short.");
		}
		else if(Left(CommandString, 3) ~= "MAP")
		{
			Sender.ClientMessage("Searches database for map records by map name.");
			Sender.ClientMessage("Use command 'mutate records map <mapname>'");
			Sender.ClientMessage("   Note: It will find all records containing the specified string.");
		}
		else if(Left(CommandString, 7) ~= "PLAYER ")
		{
			ValueString = CleanName(Mid(CommandString, 7));
			if(Len(ValueString) > 1)
				SR.FindByPlayer(Sender, ValueString, lastTimestamp);
			else
				Sender.ClientMessage("Sorry, the specified string is too short.");
		}
		else if(Left(CommandString, 6) ~= "PLAYER")
		{
			Sender.ClientMessage("Searches database for map records by player name.");
			Sender.ClientMessage("Use command 'mutate records map <player>'");
			Sender.ClientMessage("   Note: It will find all records made by players containing the specified string in the name.");
		}
		else
		{
			Sender.ClientMessage("You can do database searches for map records here.");
			Sender.ClientMessage("It can be done in two ways:");
			Sender.ClientMessage("A) By Map - command 'mutate records map <mapname>'");
			Sender.ClientMessage("B) By Player - command 'mutate records player <player>'");
			Sender.ClientMessage("   Note: It will find all records containing the specified string.");
		}
	}
	else if(Left(MutateString, 7) ~=  "RECORDS")
	{
		Sender.ClientMessage("You can do database searches for map records here.");
		Sender.ClientMessage("It can be done in two ways:");
		Sender.ClientMessage("A) By Map - command 'mutate records map <mapname>'");
		Sender.ClientMessage("B) By Player - command 'mutate records player <player>'");
		Sender.ClientMessage("   Note: It will find all records containing the specified string.");
	}
}

//====================================
// SendSettings - Sends current server settings - helper for Mutate
// Triggered in: Mutate
//====================================
function SendSettings(Pawn Sender)
{
	local int i;
	Sender.ClientMessage("  bAutoLoadInsta="$string(bAutoLoadInsta));
	Sender.ClientMessage("  bMultiFlags="$string(bMultiFlags));
	Sender.ClientMessage("  bRespawnAfterCap="$string(bRespawnAfterCap));
	Sender.ClientMessage("  bAntiBoost="$string(bAntiBoost));
	Sender.ClientMessage("  bBlockBoostForGood="$string(bBlockBoostForGood));
	Sender.ClientMessage("  AllowBoostOn="$AllowBoostOn);
	Sender.ClientMessage("  bNoKilling="$string(bNoKilling));
	Sender.ClientMessage("  bCarcasses="$string(bCarcasses));
	Sender.ClientMessage("  bGhosts="$string(bGhosts));
	Sender.ClientMessage("  bOnlyABGhosts="$string(bOnlyABGhosts));
	Sender.ClientMessage("  AllowKillingOn="$AllowKillingOn);
	Sender.ClientMessage("  bForceMoversKill="$string(bForceMoversKill));
	for(i=0;i<10;i++)
		if(ForceMoversKill[i] != "")
			Sender.ClientMessage("  ForceMoversKill["$string(i)$"]="$ForceMoversKill[i]);
	Sender.ClientMessage("  RecordsWithoutBoost="$string(RecordsWithoutBoost));
	Sender.ClientMessage("  bDisableInTournament="$string(bDisableInTournament));
	Sender.ClientMessage("  bDisableInNonBTMaps="$string(bDisableInNonBTMaps));
	Sender.ClientMessage("  BoardLabel="$BoardLabel);
	Sender.ClientMessage("  bFocusBestCapper="$string(bFocusBestCapper));
}
// END OF MUTATOR FUNCTIONS

//====================================
// CheckClassForZP - Checks if a string(which ought to be derived from a class) contains any ZeroPing names
// Triggered in: RemoveActorsForInsta
//====================================
static final function bool CheckClassForZP(coerce string StrClass)
{
		//check for all zp variants
	if (InStr(StrClass,"ZPPure") != -1
	|| InStr(StrClass,"ZeroPing") != -1
	|| InStr(StrClass,"ZPServer") != -1
	|| InStr(StrClass,"ZPBasic") != -1
	|| InStr(StrClass,"ZPColor") != -1
	|| InStr(StrClass,"InstaGibDM") != -1
	|| InStr(StrClass,"ZPDualColor") != -1)
		return true;
	return false;
}

//====================================
// RemoveActorsForInsta - Removes any instagib actors, we have our own one
// Triggered in: PreBeginPlay
//====================================
function RemoveActorsForInsta()
{
	local Inventory I;
	local Actor A;
	local Mutator M, Temp;

	M = Level.Game.BaseMutator;

	while (M.NextMutator != None)
	{
		//check for all zp variants
		if (CheckClassForZP(M.NextMutator.Class))
		{
			Temp = M.NextMutator.NextMutator;
			M.NextMutator.Destroy();
			M.NextMutator = Temp;
			break;
		}
		else
			M = M.NextMutator;
	}

	foreach AllActors(class'Actor', A)
	{
	 	if(CheckClassForZP(A.class))
	 	 	A.Destroy();
	}
}


//CheckMyStart - looks up the playerstart the player is assigned to by the engine; if myStart != None that one is used
//requires PI[].myTeam to be set before
function CheckMyStart(int ID)
{
	local int i;
	local UTTeleportEffect ute;
	
	//no myStart set on this side of the current map -> detect the one currently used
	if(PI[ID].side[PI[ID].myTeam].myStart == -1)
	{
		PI[ID].lastStart = -1;
		for(i = 0;i < 50;i++)
		{
			if(playerStarts[i] == None)//end of list
				break;
		
			if(PI[ID].Player.Location == actual_PS_Locations[i])//found
			{
				PI[ID].lastStart = i;//player may choose this as myStart now
				break;
			}
		}
	}
	else //myStart set
	{
		
		//not already there
		if(PI[ID].Player.Location != actual_PS_Locations[PI[ID].side[PI[ID].myTeam].myStart])
		{

			//see if the spawn effect is available:
			ute = TEN.getMatchingEffect(PI[ID].Player.Location);
			//Log(ute $ " = matching Effect");
			if(ute != None)
			{
				ute.SetLocation(actual_PS_Locations[PI[ID].side[PI[ID].myTeam].myStart]);
				//ute.SetRotation(playerStarts[PI[ID].side[PI[ID].myTeam].myStart].Rotation);
			}
			
			//move the player
			PI[ID].Player.SetLocation(actual_PS_Locations[PI[ID].side[PI[ID].myTeam].myStart]);
			PI[ID].Player.ClientSetRotation(playerStarts[PI[ID].side[PI[ID].myTeam].myStart].Rotation);
			PI[ID].Player.ViewRotation = playerStarts[PI[ID].side[PI[ID].myTeam].myStart].Rotation;
		}
	}
}



//#########################################################################
//### FUNCTIONS TO SWITCH BTPLUSPLUS FEATURES ON/OFF
//#########################################################################

//SetMyStart - called through say mystart or 'mutate mystart'
function SetMyStart(int ID)
{
	if(PI[ID].Player.PlayerReplicationInfo.bWaitingPlayer || PI[ID].myTeam != PI[ID].Player.PlayerReplicationInfo.Team)//not if just changed team
		return;

	if(PI[ID].side[PI[ID].myTeam].myStart != -1)
		PI[ID].Player.ClientMessage("You already got a myStart. Clear it by saying 'clearstart' or with 'mutate clearstart' - and maybe choose another one.");
	else if(PI[ID].lastStart != -1)// do know which playerstart was the last one used?
	{
		PI[ID].side[PI[ID].myTeam].myStart = PI[ID].lastStart;
		PI[ID].lastStart = -1;//clear
		PI[ID].Player.ClientMessage("From now on you will spawn where you just did.");
		SaveData(ID);
	}
	else //no myStart & no lastStart -> probably just deleted myStart and wants to set it again :)
		PI[ID].Player.ClientMessage(":) - maybe respawn?");
		
}

//ClearStart - called through say clearstart or 'mutate clearstart'
function ClearStart(int ID)
{
	if(PI[ID].Player.PlayerReplicationInfo.bWaitingPlayer || PI[ID].myTeam != PI[ID].Player.PlayerReplicationInfo.Team)
		return;
		
	if(PI[ID].side[PI[ID].myTeam].myStart != -1)
	{
		PI[ID].Player.ClientMessage("Back to random spawning.");
		PI[ID].side[PI[ID].myTeam].myStart = -1;
		SaveData(ID);
	}
	else
		PI[ID].Player.ClientMessage("No myStart set.");
}

//====================================
// SetMultiFlags - sets whether a copy of the flag should be given to the player taking it
// Triggered in: Mutate, Timer
//====================================
function SetMultiFlags(bool Status)
{
	local CTFFlag TmpFlag;

	Foreach AllActors(Class'CTFFlag',TmpFlag)
	{
		if(TmpFlag.Team>1 || TmpFlag.IsA('FlagDisposer'))
			continue;
		TmpFlag.SendHome();
		TmpFlag.SetCollision(!Status, false, false);
	}
}

//====================================
// SetRecordsWithoutBoost - sets whether records should not be saved if a scorer was boosted in the way
// Triggered in: Mutate
//====================================
function SetRecordsWithoutBoost(int Status)
{
	local int i;

	RecordsWithoutBoost = Status;

	if(Status == 0 || (Status == 2 && bCooperationMap))
	{
		for(i=0;i<32;i++)
		{
			if(PI[i].RI == None)
				continue;
			PI[i].RI.bBoosted = False;
		}
	}
}
//### END OF FUNCTIONS TO SWITCH BTPLUSPLUS FEATURES ON/OFF

//#########################################################################
//### OTHER FUNCTIONS - couldn't find a place for them(yet)
//#########################################################################
//====================================
// CurTimestamp - returns current timestamp/unixtime
//====================================
function int CurTimestamp()
{
	lastTimestamp = timestamp(Level.Year, Level.Month, Level.Day, Level.Hour, Level.Minute, Level.Second);
	return lastTimestamp;
}

//====================================
// timestamp - returns timestamp/unixdate for a specified date
//====================================
static final function int timestamp(int year, int mon, int day, int hour, int min, int sec)
{
	/*
		Origin of the algorithm below:
			Linux Kernel <time.h>
	*/
	mon -= 2;
	if (mon <= 0) {	/* 1..12 -> 11,12,1..10 */
		mon += 12;	/* Puts Feb last since it has leap day */
		year -= 1;
	}
	return (((
	    (year/4 - year/100 + year/400 + 367*mon/12 + day) +
	      year*365 - 719499
	    )*24 + hour /* now have hours */
	   )*60 + min  /* now have minutes */
	  )*60 + sec; /* finally seconds */
}

//====================================
// timestamp - just in case of destuction, it's better to clean up the stuff and unlink self
// Inherited from class'Actor'
//====================================
function Destroyed()
{
	local Mutator M;

	if ( Level.Game != None ) {
        if ( Level.Game.BaseMutator == Self )
            Level.Game.BaseMutator = NextMutator;
        if ( Level.Game.DamageMutator == Self )
            Level.Game.DamageMutator = NextDamageMutator;
        if ( Level.Game.MessageMutator == Self )
            Level.Game.MessageMutator = NextMessageMutator;
    }
    ForEach AllActors(Class'Engine.Mutator', M) {
        if ( M.NextMutator == Self )
            M.NextMutator = NextMutator;
        if ( M.NextDamageMutator == Self )
            M.NextDamageMutator = NextDamageMutator;
        if ( M.NextMessageMutator == Self )
            M.NextMessageMutator = NextMessageMutator;
    }
}

//====================================
// GetItemName - provides various information to actors not linked with BT++ directly
// Triggered in: class'SuperShockRifleBT'.ProcessTraceHit and any other actor talking with BT++
// Inherited from class'Actor'
//====================================
function string GetItemName(string Input)
{
	local int temp, PlayerID;
	local string retstr;

	if(Left(Input, 4) ~= "get ")
	{
		Input = Mid(Input, 4);
		PlayerID = int(SelElem(Input, 2, " "));
		switch(SelElem(Caps(Input), 1, " "))
		{
			case "CAPS":
				return string(PI[FindPlayerByID(PlayerID)].RI.Caps);
			case "RUNS":
				return string(PI[FindPlayerByID(PlayerID)].RI.Runs);
			case "EFF":
				temp = FindPlayerByID(PlayerID);
				if(PI[temp].RI.Runs > 0)
					return string(int(float(PI[temp].RI.Caps)/float(PI[temp].RI.Runs)*100.0));
				else
					return "0";
			case "BOOSTED":
				return string(PI[FindPlayerByID(PlayerID)].RI.bBoosted);
			case "ABSTATUS":
				if((PI[FindPlayerByID(Input)].Config.bAntiBoost || bBlockBoostForGood) && bAntiBoost)
					return "1";
				else
					return "0";
			case "BNOKILLING":
				if(bNoKilling)
					return "1";
				else
					return "0";
			case "SHOCKRIFLEINFO": // information needed by the class'SuperShockRifleBT'
				if((PI[FindPlayerByID(Input)].Config.bAntiBoost || bBlockBoostForGood) && bAntiBoost)
					retstr = "1";
				else
					retstr = "0";
				if(bNoKilling && !bAllowKilling)
					retstr = retstr$"1";
				else
					retstr = retstr$"0";
				return retstr;
			default:
				return "error";
		}
	}
}

event Touch(Actor A)
{
	local int i;

	if(EventHandlersCount == 10)
		A.GetItemName("-1,event handlers number exceeded");

	for(i=0;i<EventHandlersCount+1;i++)
	{
		if(EventHandlers[i] == None)
		{
			EventHandlers[i] = A;
			A.GetItemName("0,registration successful");
			EventHandlersCount++;
		}
	}
}

//====================================
// SendEvent - Sends custom events to all registered actors
//====================================
function SendEvent(string EventName, optional coerce string Arg1, optional coerce string Arg2, optional coerce string Arg3, optional coerce string Arg4)
{
	local Actor A;
	local int i;
	local string Event;

	if (Level.Game.LocalLog != None)
		Level.Game.LocalLog.LogSpecialEvent(EventName, Arg1, Arg2, Arg3, Arg4);

	Event = EventName;
	if(Arg1 != "")
		Event = Event$chr(9)$Arg1;
	if(Arg2 != "")
		Event = Event$chr(9)$Arg2;
	if(Arg3 != "")
		Event = Event$chr(9)$Arg3;
	if(Arg4 != "")
		Event = Event$chr(9)$Arg4;

	for(i=0;i<EventHandlersCount+1;i++)
	{
		if(EventHandlers[i] != None)
			EventHandlers[i].GetItemName(Event);
	}
}
//### END OF OTHER FUNCTIONS


defaultproperties
{
    Version="991"
	MAX_CAPTIME=600000
    bEnabled=True
    bAutoLoadInsta=True
    bMultiFlags=True
    bRespawnAfterCap=True
    bAntiBoost=True
	bBlockBoostForGood=False
    bNoKilling=True
	bNoSpamBinds=True
    AllowKillingOn="BT-Colors,BT-1point4megs,BT-i4games,BT-Abomination,BT-Allied"
    bForceMoversKill=True
    ForceMoversKill(0)="Mover0,Mover1,Mover2,Mover5:BT-Maverick"
	bNoCapSuicide=True
    RecordsWithoutBoost=2
    bDisableInTournament=True
    bDisableInNonBTMaps=True
	bFocusBestCapper=True
	bCarcasses=True
	bGhosts=True
	bOnlyABGhosts=True
    CountryFlagsPackage=CountryFlags2
    BoardLabel="Bunny Track (BT++)"
    MapBestTime=0
    MapBestPlayer="N/A"
    bAlwaysTick=True
    GreenColor=(G=255)
    RedColor=(R=255)
	OrangeColor=(R=255,G=88)
}
