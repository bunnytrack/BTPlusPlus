/*
    BTPlusPlus 0.991
    Copyright (C) 2004-2006 Damian "Rush" Kaczmarek

    This program is free software; you can redistribute and/or modify
    it under the terms of the Open Unreal Mod License version 1.1.
*/

class BTPPReplicationInfo expands ReplicationInfo;

var bool bBoosted;
var bool bNeedsRespawn;//indicates if the player needs a respawn to take flag/also stops the timers on him

var int PlayerID; // used to identify the owner

var float StartTime;

var float JoinTime; // works just as the original PlayerReplicationInfo.StartTime, but the original can be messed up by BunnyTruck.u
var float timeDelta; // used to restore the Time on the scoreboard of reconnectors
var int Runs;
var int Caps;

var int lastCap;//Time of the last cap -> show in scoreboard and HUD
var int runTime;//last update from the server: length of the current run
var int BestTime; // in current game
var string BestTimeStr; //reuse it on the scoreboard

// IpToCountry stuff
var string CountryPrefix;
var Actor IpToCountry;

var bool bReadyToPlay;
var bool bTournament;


replication {
reliable if (Role == ROLE_Authority)
	PlayerID, bBoosted, StartTime, BestTime, BestTimeStr, JoinTime, Runs, Caps, CountryPrefix, bReadyToPlay, bNeedsRespawn, lastCap, runTime, SetNoneFlag, SetTimeDelta, NoSpamBinds;
}

event Spawned()
{
	if(ROLE == ROLE_Authority)
	{
		SetTimer(0.5, true);
		bTournament = DeathMatchPlus(Level.Game).bTournament;
	}
}

function Timer()
{
	local string temp;
	local PlayerPawn P;

	if(Owner == None)
		Destroy();
	else 
	{
		if(IpToCountry != None)
		{
			if(CountryPrefix == "")
			{
				P = PlayerPawn(Owner);
				if(NetConnection(P.Player) != None)
				{
					temp = P.GetPlayerNetworkAddress();
					temp = Left(temp, InStr(temp, ":"));
					temp = IpToCountry.GetItemName(temp);
					if(temp == "!Disabled") /* after this return, iptocountry won't resolve anything anyway */
						IpToCountry = None;
					else if(Left(temp, 1) != "!") /* good response */
					{
						CountryPrefix = SelElem(temp, 5);
						if(CountryPrefix == "") /* the country is probably unknown(maybe LAN), so as the prefix */
							IpToCountry = None;
							
						if(!bTournament || bReadyToPlay)
							SetTimer(0.0, False);
					}
				}
				else
					IpToCountry = None;
			}
			else
				IpToCountry = None;
		}
		
			
		if(bTournament && PlayerPawn(Owner).bReadyToPlay != bReadyToPlay)
		{
			bReadyToPlay = PlayerPawn(Owner).bReadyToPlay; // replicate this variable normally being serverside only
			if(bReadyToPlay && IpToCountry == None)//player is ready and we know it; job done
				SetTimer(0.0, False);
		}
		
	}
}

static final function string SelElem(string Str, int Elem, optional string Char)
{
	local int pos;
	if(Char == "")
		Char = ":";

	while(Elem>1)
	{
		Str = Mid(Str, InStr(Str, Char)+1);
		Elem--;
	}
	pos = InStr(Str, Char);
	if(pos != -1)
    	Str = Left(Str, pos);
    return Str;
}

simulated function SetNoneFlag()
{
	if(PlayerPawn(Owner) != None)
		PlayerPawn(Owner).PlayerReplicationInfo.HasFlag = None;
}

simulated function SetTimeDelta(float delta)
{
	//if(Role == ROLE_Authority)
	timeDelta = delta;
}

//NoSpamBinds - look at plain keybindings: suicide cmd + anything else -> becomes a plain suicide cmd
simulated function NoSpamBinds()
{
	local PlayerPawn pp;
	local int i, loc, length, k;
	local string keyCode, bindText, temp;
	local bool bLeftIsValid, bRightIsValid;//check if left and right of 'suicide' there is nothing breaking the cmd

	pp = PlayerPawn(Owner);
	if (pp != None && pp.Player != None && pp.Player.Console != None)
	{
		for (i=0; i<256; i++)
		{
			bLeftIsValid = False;
			bRightIsValid = False;
			keyCode = pp.ConsoleCommand("keyname"@i);
			bindText = pp.ConsoleCommand("keybinding"@keyCode);
			length = Len(bindText);
			loc = InStr(bindText, "suicide");

						
			//maybe command found
			if(loc != -1)
			{
				if(length == 7)//plain
					continue;
			
					//LEFT SIDE
				if(loc == 0)
					bLeftIsValid = True;
				else
				{
					k = loc;
					while(--k > -1 && Mid(bindText, k, 1) == " "){}
					
					if(k == -1 || Mid(bindText, k, 1) == "|")//valid
					{
						bLeftIsValid = True;
					}
					
				}
				
				//RIGHT SIDE
				if(loc + 7 == length)//at the end
					bRightIsValid = True;
				else
				{
					k = loc + 7;
	
					if(Mid(bindText, k, 1) == "|" || Mid(bindText, k, 1) == " ")//valid
					{
						bRightIsValid = True;
					}
				}
				
				if(bRightIsValid && bLeftIsValid) //change it
				{
					pp.ClientMessage("turned '"$ bindText $ "' @ " $ keyCode $ " into plain suicide command");
					pp.ConsoleCommand("set input "$keyCode$" suicide");
					
				}
			}
		}
	}
}

defaultproperties
{
  NetPriority=9.0
  PlayerID=-1
}
