/*
    BTPPUser; coming from BTPlusPlus_Client package
	Copyright (C) 2004-2006 Damian "Rush" Kaczmarek
	save-structure changed by Cruque

    This program is free software; you can redistribute and/or modify
    it under the terms of the Open Unreal Mod License version 1.1.
*/

class ClientData expands Info config(BTRecords);
/* class holding information(records, config) clientside  */

var const int MAX_MAPS;
var const int MAX_CAPTIME;

struct PersonalRecord
{
	var int c;//=time
	var int t;//=timestamp
	var string m;//=mapname
};

var config bool bSet; // is set to true after the first antiboost status change, if it is false, BT++ will send a more detailed help
var config bool bAntiBoost; // for storing AntiBoost status between switching servers
var config bool bBTHud; // indicates showing BTPPHudMutator
var config bool bSTFU; // prevents from recieving BT++ messages
var config bool bCheckpoints; //display checkpoint-times
//////////////////
var config PersonalRecord Records[1500];
var int rec_index;
var config string CPTs[1500];//checkpoint times
var int cpts_index;
//////////////////
var int BestTime; // record read from the ini
var int Timestamp;
var string BestTimeStr;
var bool bGotNoRecords;

var PlayerPawn P;

replication {
	reliable if(Role == ROLE_Authority)
		SetBTHudClient, SetSTFUClient, SetAntiBoostClient, SetCheckpointsClient, AddRecord, AddCPT, SearchCPT, Reload, FindByMap, FindByAge, FindAll, DeleteRecord;
	reliable if(Role < ROLE_Authority)
		SetServerVars;
}

// destroy self if owner leaves the server
function Tick(float DeltaTime)
{
	if(PlayerPawn(Owner) == None)
		Destroy();
}

//====================================
// PostNetBeginPlay - Checks a remote client's record and set client's vars to the server
//====================================
simulated function PostNetBeginPlay()
{
	local string temp;

	if(ROLE < ROLE_Authority)
	{
		//determine if player got no records saved -> use this to 
		if(Records[0].c == 0 && Records[1].c == 0 && Records[2].c == 0 && Records[3].c == 0)
			bGotNoRecords = True;
		///////////////////Personal Record//////////////
		//find it
		temp = GetLevelName();
		rec_index = CheckRecord(temp);
		if(rec_index != -1 && Records[rec_index].c != 0)
		{
			BestTime = Records[rec_index].c;
			Timestamp = Records[rec_index].t;
			BestTimeStr = FormatCentiseconds(BestTime, False);
		}
		
		//////////////////////Checkpoints//////////////
		cpts_index = SearchCPT(temp);
		
		if(cpts_index >= 0)
			temp = Mid(CPTs[cpts_index], InStr(CPTs[cpts_index], ",") + 1);//remove mapname - less nettraffic
		else
			temp = "";
		
		SetServerVars(BestTime, BestTimeStr, Timestamp, bSet, bAntiBoost, bSTFU, bCheckpoints, bGotNoRecords, temp);
	}
}

//====================================
// SetServerVars - Set server vars with client vars
// Triggered in: PostNetBeginPlay
//====================================
simulated function SetServerVars(int ClientBestTime, string ClientBestTimeStr, int ClientTimestamp, bool bClientSet, bool bClientAntiBoost, bool bClientSTFU, bool bClientCheckpoints, bool bClientGotNoRecords, string data)
{
	if(ROLE == ROLE_Authority && bNetOwner)
	{
		BestTime=ClientBestTime;
		BestTimeStr=ClientBestTimeStr;
		Timestamp=ClientTimestamp;
		bSet=bClientSet;
		bAntiBoost=bClientAntiBoost;
		bSTFU=bClientSTFU;
		bCheckpoints=bClientCheckpoints;
		bGotNoRecords = bClientGotNoRecords;
		if(data != "")
			CPTs[0]=data;
	}
}
//====================================
// SetAntiBoostClient - Updates antiboost status clientside
// Triggered in: SetAntiBoost
//====================================
simulated function SetAntiBoostClient(bool Status)
{
	bAntiBoost=Status;
	bSet=True; // meaning that it will do it only once if bSet is false
	SaveConfig();
}

//====================================
// SetAntiBoostClient - Updates antiboost status serverside and triggers the clientside update
// Triggered in: class'BTPlusPlus': SetAntiBoostOn, SetAntiBoostOff, Mutate, MutatorTeamMessage
//====================================
function SetAntiBoost(bool Status)
{
	bAntiBoost=Status;
	bSet=True;
	SetAntiBoostClient(Status);
}

//====================================
// SetCheckpointsClient - Updates checkpoints-display setup
// Triggered in: SetCheckpoints
//====================================
simulated function SetCheckpointsClient(bool Status)
{
	bCheckpoints=Status;
	SaveConfig();
}

//====================================
// SetCheckpoints - Updates the status of bCheckpoints serverside and calls SetCheckpointsClient
// Triggered in: class'BTPlusPlus': Mutate
//====================================
function SetCheckpoints(bool Status)
{
	bCheckpoints=Status;
	SetCheckpointsClient(Status);
}

// similiar to the uppper SetAntiBoost and SetAntiBoostClient
simulated function SetBTHudClient(bool Status)
{
	bBTHud=Status;
	SaveConfig();
}

// similiar to the uppper SetAntiBoost and SetAntiBoostClient
function SetBTHud(bool Status)
{
	bBTHud=Status;
	SetBTHudClient(Status);
}

// similiar to the uppper SetAntiBoost and SetAntiBoostClient
simulated function SetSTFUClient(bool Status)
{
	bSTFU=Status;
	SaveConfig();
}

// similiar to the uppper SetAntiBoost and SetAntiBoostClient
function SetSTFU(bool Status)
{
	bSTFU=Status;
	SetSTFUClient(Status);
}

//AddCPT - Saves the CPT clientside right where it(or an empty element) was found before
simulated function AddCPT(string data)
{
	if(ROLE == ROLE_Authority && Level.NetMode != NM_Standalone)
		return;
	//save clientside
	CPTs[cpts_index] = data;
	SaveConfig();
}

//AddRecord - adds a new record; replaces IF an old one was found before or at least open capacity was detected
simulated function AddRecord(string map, int time, int timestamp, optional bool doTransform, optional int index)
{
	if(doTransform)
		rec_index = index;

	if(ROLE == ROLE_Authority || rec_index == -1 || (doTransform && (time <= Records[rec_index].c || time >= MAX_CAPTIME))) // runs only on client - found entry/empty element at the beginning? - better than present one; remove last condition on next VERSION OF BTPPUSER
		return;

	if(!doTransform)//this is just to optimize rec transformation to 098; remove this on next VERSION OF BTPPUSER
	{
		BestTime = time;
		//format clientside -> used on the HUD
		BestTimeStr = FormatCentiseconds(time, False);
	}

	Records[rec_index].c = 	time;
	Records[rec_index].t = 	timestamp;
	Records[rec_index].m =	map;
	if(!doTransform)//this is just to optimize rec transformation to 098; remove this on next VERSION OF BTPPUSER
		SaveConfig();
}

//DeleteRecord - deletes the record the player made on the current map
simulated function DeleteRecord()
{
	if(ROLE == ROLE_Authority || rec_index == -1 || Records[rec_index].c == 0)
		return;
		
	Records[rec_index].c = 0;
	Records[rec_index].t = 0;
	Records[rec_index].m = "";
	
	BestTime = 0;
	Timestamp = 0;
	BestTimeStr = Default.BestTimeStr;
	SaveConfig();
}


simulated function string GetLevelName()
{
	local string Str;
	local int Pos;

	Str=string(Level);
	Pos = InStr(Str, ".");
	if(Pos != -1)
		return Left(Str, Pos);
	else
		return Str;
}

//====================================
// SearchCPT - looks up the MapName; returns the index at which it is stored in the client's .ini; or new index if not found; or -1 if no capacity left
// Triggered in: PostNetBeginPlay
//====================================
simulated function int SearchCPT(string MapName)
{
	local int i, length;
	
	if(ROLE == ROLE_Authority && Level.NetMode != NM_Standalone)
		return -1;

	length = Len(MapName);
	cpts_index = -1;

	for(i = 0;i < MAX_MAPS;i++)
	{
		if(CPTs[i] ~= "")
		{
			if(cpts_index == -1)
				cpts_index = i;
			continue;
		}
		if(Left(CPTs[i], length) == MapName) //ignore case?
		{
			cpts_index = i;
			break;
		}
	}

	return cpts_index;
}


//====================================
// CheckRecord - looks for the player's personal record on the map MapName and returns the index; index of empty element if not found; -1 if not
// Triggered in: PostNetBeginPlay
//====================================
simulated function int CheckRecord(string MapName)
{
	local int i, k;
	
	if(ROLE == ROLE_Authority)
		return -1;
	
	k = -1;
	for(i=0;i<MAX_MAPS;i++)
	{
		if(Records[i].c == 0)//no valid entry
		{
			if(k == -1)//found empty spot
				k = i;
			continue;
		}
		else if(Records[i].m ~= MapName)
			return i;
	}
	if(k == -1)
		Log("Your record-list is full!", 'BTPlusPlus');
	return k;
}

//====================================
// Reload - updates personal record/output string/timestamp after rec transformation @todo remove on next VERSION OF BTPPUSER
// Triggered in: BTPlusPlus
//====================================
simulated function Reload()
{
	if(ROLE < ROLE_Authority)
	{
		rec_index = CheckRecord(GetLevelName());
		BestTime = Records[rec_index].c;
		Timestamp = Records[rec_index].t;
		BestTimeStr = FormatCentiseconds(BestTime, False);
		//update serverside
		SetServerVars(BestTime, BestTimeStr, Timestamp, bSet, bAntiBoost, bSTFU, bCheckpoints, bGotNoRecords, "");
	}
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
// FormatScore - Format BunnyTrack score to a readable format - the code is stupid because it has to be like in the original one in BunnyTrack mod to maintain compatibility
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
// FindByAge - searches all personal records that are atleast age days old
// Triggered in: class'BTPlusPlus'.Mutate
//====================================
simulated function FindByAge(int age, int timestamp)
{
	local int i;
	local bool bFound;
	
	if(ROLE == ROLE_Authority)
		return;
		
	if(P == None && PlayerPawn(Owner) != None)
		P = PlayerPawn(Owner);

	age *= 86400;//get seconds

	for(i=0;i<MAX_MAPS;i++)
	{
		if(Records[i].c == 0)
			continue;
		
		if((timestamp - Records[i].t) >= age)
		{
			P.ClientMessage(Records[i].m$" - "$FormatCentiseconds(Records[i].c, False)$" (" $ (timestamp - Records[i].t)/86400 $ " day(s) ago)");
			bFound=True;
		}
		
	}
	if(!bFound)
		P.ClientMessage("Sorry, no records found. Maybe you made a typo ?");
}


//====================================
// FindByMap - Searches database for map records by map name and send messages to the player; copy from RecordData
// Triggered in: class'BTPlusPlus'.Mutate
//====================================
simulated function FindByMap(string MapName, int timestamp)
{
	local int i;
	local bool bFound;
	
	if(ROLE == ROLE_Authority)
		return;
		
	if(P == None && PlayerPawn(Owner) != None)
		P = PlayerPawn(Owner);

	if(Left(Caps(MapName), 4) == "CTF-") // remove confusion with different naming conventions CTF-BT/BT-
	{
		if(Len(MapName) < 6)//too short now
			return;
		MapName=Caps(Mid(MapName, 4));
	}
	else
		MapName = Caps(MapName);//always CAPS now


	for(i=0;i<MAX_MAPS;i++)
	{
		if(Records[i].c == 0)
			continue;
		
		if(InStr(Caps(Records[i].m), MapName) != -1 )
		{
			P.ClientMessage(Records[i].m$" - "$FormatCentiseconds(Records[i].c, False)$" (" $ (timestamp - Records[i].t)/86400 $ " day(s) ago)");
			bFound=True;
		}
		
	}
	if(!bFound)
		P.ClientMessage("Sorry, no records found. Maybe you made a typo ?");
}

//====================================
// FindAll - Prints out all personal records
// Triggered in: class'BTPlusPlus'.Mutate
//====================================
simulated function FindAll(int timestamp)
{
	local int i;
	local bool bFound;

	if(ROLE == ROLE_Authority)
		return;
	
	if(P == None && PlayerPawn(Owner) != None)
		P = PlayerPawn(Owner);
	
	for(i=0;i<MAX_MAPS;i++)
	{
		if(Records[i].c == 0)
			continue;
		bFound = True;
		P.ClientMessage(Records[i].m$" - "$FormatCentiseconds(Records[i].c, False)$" (" $ (timestamp - Records[i].t)/86400 $ " day(s) ago)");
	}
	
	if(!bFound)
		P.ClientMessage("Sorry - found no records.");
}


DefaultProperties
{
	bAntiBoost=True
	bCheckpoints=True
	BestTimeStr="-:--"
	bBTHud=True
	MAX_CAPTIME=600000
	MAX_MAPS=1500
}
