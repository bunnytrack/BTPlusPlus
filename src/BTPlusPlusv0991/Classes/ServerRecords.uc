/*
    BTPPServer.ServerRecords -> separate package containing RecordData from BTPlusPlus
    Copyright (C) 2004-2006 Damian "Rush" Kaczmarek
	save-structure changed by Cruque

    This program is free software; you can redistribute and/or modify
    it under the terms of the Open Unreal Mod License version 1.1.
*/

class ServerRecords expands Actor config(BTPlusPlus);

var const int MAX_CAPTIME;

struct ServerRecord
{
var string m;//=mapname
var int c;//=captime
var int t;//=timestamp
var string p;//=playername - "\? are removed
};

var config ServerRecord Records[3000];

/////////////////////////////////////
//Get X - functions -> access in BTPlusPlus.uc
/////////////////////////////////////
function int getCaptime(int index)
{
	return Records[index].c;
}	

function int getTimestamp(int index)
{
	return Records[index].t;
}

function string getPlayerName(int index)
{
	return Records[index].p;
}


//====================================
// CheckRecord - looks for the server record on the map MapName and returns the index; first empty element if not found; -1 if out of capacity
// Triggered in: class'BTPlusPlus'.PostBeginPlay
//====================================
function int CheckRecord(string MapName)
{
	local int i, empty;

	empty = -1;
	for(i=0;i<3000;i++)
	{
		if(Records[i].c == 0)
		{
			if(empty == -1)//found empty spot
				empty = i;
			continue;
		}
		
		if(Records[i].m ~= MapName)
			return i;
	}
	if(empty == -1)
		Log("->Server - record - list is FULL!", 'BTPlusPlus');
	return empty;
}

//====================================
// DeleteRecord - deletes a record from the server; returns success
// Triggered in: class'BTPlusPlus'.Mutate
//====================================
function bool DeleteRecord(string MapName)
{
	local int index;
	
	index = CheckRecord(MapName);
	
	if(index == -1 || Records[index].c == 0)
		return False;
	
	//make a backup in the logs
	Log("delete this server record: " $ 
		Records[index].m$"?"$Records[index].c$"?"$Records[index].p$"?"$Records[index].t, 'BTPlusPlus');
		
	//save defaults instead
	Records[index].c = 0;
	Records[index].m = "";
	Records[index].t = 0;
	Records[index].p = "";
	SaveConfig();

	return True;
}

//====================================
// AddRecord - alters or adds a new record for the specified map
// Triggered in: class'BTPlusPlus'.SetBestTime, -"-.Mutate
//====================================
function AddRecord(string MapName, int Time, string Player, int Timestamp)
{
	local int i;
	local string temp;

	//-> admin wants to edit a record:
	if(time == -1)
	{
		temp = MapName;//all unparsed inside MapName
		i = InStr(temp, "?");
		if(i < 0)
			return;

		//1st = Mapname
		MapName = Left(temp, i);
		
		temp = Mid(temp, i + 1);
		i = InStr(temp, "?");
		if(i < 0)
			return;

		//2nd = captime
		Time = int(Left(temp, i));
		
		temp = Mid(temp, i + 1);
		i = InStr(temp, "?");

		//3rd = PlayerName
		if(i < 0)
			Player = temp;//and done
		else//use timestamp given
		{
			Player = Left(temp, i);
			Timestamp = int(Mid(temp, i + 1));
		}
		Log("editrecord|new: Map = " $ MapName $ "; captime = " $ Time $ "; player = " $ Player $ "; timestamp = " $ Timestamp, 'BTPlusPlus');
		//now use it!
	}
	
	//search (old) entry:
	i = CheckRecord(MapName);
	
	if(i == -1)
	{
		Log("->Server - record - list is FULL!", 'BTPlusPlus');
		return;
	}
	
	if(Records[i].c != 0)//replacing record -> log old one -> pattern instantly usable for editrec command
		Log("new server-record; old one: mutate btpp editrec " $ 
			Records[i].m$"?"$Records[i].c$"?"$Records[i].p$"?"$Records[i].t, 'BTPlusPlus');
	
	//asign
	if(Records[i].c == 0)//first asign - probably by bt++ -> most likely nice mapname (caps)
		Records[i].m = MapName;
		
	Records[i].c = Time;
	Records[i].p = Player;
	Records[i].t = timestamp;
	
	//save
	SaveConfig();
}

//====================================
// FindByPlayer - Searches database for map records by player name and send messages to the player
// Triggered in: class'BTPlusPlus'.Mutate
//====================================
function FindByPlayer(Pawn P, string Player, int timestamp)
{
	local int i;
	local bool bFound;

	Player = Caps(Player);//eff
	for(i=0;i<3000;i++)
	{
		if(Records[i].c == 0)
			continue;
		
		if(InStr(Caps(Records[i].p), Player) != -1 )
		{
			P.ClientMessage(Records[i].m$" - "$FormatCentiseconds(Records[i].c, False)$" (set by "$Records[i].p @ (timestamp - Records[i].t)/86400 $ " day(s) ago)");
			bFound=True;
		}
		
	}
	if(!bFound)
			P.ClientMessage("Sorry, no records found.");
}

//====================================
// FindByMap - Searches database for map records by map name and send messages to the player
// Triggered in: class'BTPlusPlus'.Mutate
//====================================
function FindByMap(Pawn P, string MapName, int timestamp)
{
	local int i, k;
	local bool bFound;

	MapName = Caps(MapName);//always CAPS now
	
	//don't want list-all-recs here

	if(Level.NetMode != NM_Standalone) //limit bandwith usage through this online
	{
		for(i = Min(6, Len(MapName)); i > 1 ; i--)
		{
			if(InStr("CTF-BT", Left(MapName, i)) != -1)
			{
				MapName = Mid(MapName, i);
				if(Len(MapName) < 2)
				{
					P.ClientMessage("Won't search this. Be more specific.");
					return;
				}
				break;
			}
		}
	}

	for(i=0;i<3000;i++)
	{
		if(Records[i].c == 0)
			continue;
		
		if(InStr(Caps(Records[i].m), MapName) != -1 )
		{
			P.ClientMessage(Records[i].m$" - "$FormatCentiseconds(Records[i].c, False)$" (set by "$Records[i].p @ (timestamp - Records[i].t)/86400 $ " day(s) ago)");
			bFound = True;
		}
		
	}
	if(!bFound)
		P.ClientMessage("Sorry, no records found. Maybe you made a typo ?");
}



//#########################################################################
//### Format captime to readable text
//#########################################################################

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



DefaultProperties
{
	bHidden=True
	MAX_CAPTIME=600000
}
