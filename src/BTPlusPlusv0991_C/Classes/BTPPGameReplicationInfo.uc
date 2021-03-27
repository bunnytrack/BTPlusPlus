/*
    BTPlusPlus 0.991
    Copyright (C) 2004-2006 Damian "Rush" Kaczmarek

    This program is free software; you can redistribute and/or modify
    it under the terms of the Open Unreal Mod License version 1.1.
*/

class BTPPGameReplicationInfo expands ReplicationInfo;
/* class holding global information needed by the class'BTPPHUDMutator' and class'BTScoreboard' */

var bool bShowAntiBoostStatus; // whether to show antiboost status, depends on class'BTPlusPlus'.bAntiBoost and class'BTPlusPlus'.bBlockBoostForGood

// variables needed by either BTScoreboard or BTPPHUDMutator, set by class'BTPlusPlus'
var string MapBestTime;
var string MapBestPlayer;
var string MapBestAge;

var string 	GameBestTime;
var string 	GameBestPlayer;
var int 	GameBestTimeInt;

var string CountryFlagsPackage;
var string BoardLabel;


replication {
	reliable if (ROLE == ROLE_Authority)
			MapBestTime, MapBestPlayer, MapBestAge, bShowAntiBoostStatus, CountryFlagsPackage, BoardLabel, GameBestTime, GameBestPlayer;
}

defaultproperties {
  NetPriority=9.0
  CountryFlagsPackage="CountryFlags2"
  MapBestTime="-:--"
  MapBestAge="0"
  MapBestPlayer="N/A"
}