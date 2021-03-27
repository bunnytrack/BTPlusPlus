               / \     / \
              {   }   {   }
              {   {   }   }
               \   \ /   /
                \   Y   /
                .-"`"`"-.
              ,`         `.
             /             \
            /               \      Why are you running away?
           {     ;"";,       }        Read this README!!!
           {  /";`'`,;       }
            \{  ;`,'`;.     /
            {  }`""`  }   /}
            {  }      {  // cyd
            {||}      {  /
            `"'       `"'

BTPlusPlus 0.991
Copyright (C) 2004-2006 Damian "Rush" Kaczmarek
+ 2010 modification for IpToCountry
since v097r4 development by Cruque


This program is free software; you can redistribute and/or modify
it under the terms of the Open Unreal Mod License version 1.1.

--- by [es]Rush*bR

////
SECTIONS:
== ABOUT
== FEATURES
== INSTALLATION
== UPGRADING
== SETTINGS
== INGAME COMMANDS
== CHANGELOG
== COMPILATION
== EVENT SYSTEM
== RANDOM FUTURE IDEAS
== THX TO
== CONTACT & FEEDBACK
\\\\


##########
## ABOUT:
#
BTPlusPlus stands for BunnyTrack Plus Plus. It is a full blown addon for
servers running BunnyTrack mod and even a pure CTF game type with BT maps.
It tries to prevent n00bs from spoiling a good game while not limiting
the freedom of others. It also adds many useful improvements to the game
while still being compatible with the original BunnyTrack mod.
Read the next section for details.


##########
## FEATURES:
#
 - MultiFlags - Only a copy of the flag is given to a player, the original
   flag stays on its place allowing multiple players capping at the same time.

 - Flag Protection - To avoid cheating, dropped flags immediately disappear.

 - Multicap Protection - Multicapping means scoring two or more flags in one
   run, the trick can be performed only on some maps, and only with the help
   of some other player, also provided that no killing player after cap mod is
   enabled(like original BunnyTrack mod). Basically the Multicap Protection
   respawns players back on the spawn points just after capping, it tries to
   simulate original BunnyTrack's killing behaviour but WITHOUT killing,
   killing someone just because he/her capped a flag is IMO stupid, who would
   be stupid enough in the real world to score a flag just to be killed. :)

 - Timer - On top of the HUD you can see how fast and how well you are doing.
   Great for training in achieving World Records! The timer is compatible with
   the original BunnyTrack's implementation so the achieved records are
   comparable ones to the original BunnyTrack ones.

 - Verbose capping - After achieving a cap you will be able to see your
   current time, your best time and also a current server record! Also when
   someone beats a record, it will be announced to everyone in the same way.

 - Record saving - With this feature, your best caps won't disappear.
   The config file BTRecords.ini can store about 1500 separate records! Not
   only the records are being saved on the server, they are also being saved
   client-side so that you can somewhat compare your own records to the ones
   on other servers. The records file can easily be parsed and displayed
   in a readable form for example on a http server.

 - Kill protection - Blocks players from killing members of other team(except
   the Enemy Flag Carrier if MultiFlags are off). However, as there are some
   maps which must allow killing because of some fancy killing zones, there is
   a config var to provide a list of such maps.

 - Ghost mode - Players staying for some time in one place become translucent
   and one can walk through them, you may also force the ghost mode on
   everyone so that nobody interferes with each other.

 - Antiboost - n000bs can be reeaaally annoying on a public server, boosting
   and pushing others just to interfere! Imagine yourself rushing for a map
   record and when you're almost finished, you hear BAH, and you've been
   shot straight into the lava pit. Pitiful isn't it ? Here comes Antiboost
   into action, every player has control over his/her own Antiboost status and
   if you want a boost you can just say 'boost', your friend gives you one,
   and then you can disable it by saying 'noboost'. There are also mutate
   commands for it, and some global variables for admins.

 - Enhanced HUD - The Timer has already been mentioned, it is being displayed
   on top of the HUD, but there are also other goodies like current map
   records and Antiboost status being displayed.

 - Enhanced Scoreboard - BT++ incorporates a custom scoreboard which is
   designed specifically for Bunny Track, not only it displays cap times but
   also number of deaths, number of caps, efficiency and connection info. All
   is shown with a shadowed font and with mixed colors which should make it
   pleasant to read. The scoreboard also supports IpToCountry mod which allows
   to display a country flag near each player's nickname.

 - Auto Disabling - If you owe a clan server and you are playing also other
   game types besides BT, this feature is just for you. BT++ can automatically
   disable itself when a non-BT map is detected, it can also disable itself
   when bTournament mode is detected.

 - Possibility to disable most of the features if some are not desired.

 - And other useful features that didn't make up to this list.

\\\\\\\\\\\\\\\\|////////////////
 CHANGES COMING WITH BT++ v0.98
////////////////|\\\\\\\\\\\\\\\\
FOR PLAYERS:   
 - Old BT-Time is dead. There was chance involved that could get you +1 second or -1 second for the same run.
   BT++ adopted the time introduced by the i4G BT mod, which runs as fast as clocks in RL.
   Thus this is currently THE TIME representing BunnyTracking captures.
   
 - Checkpoints: 098 takes the zones of the map to give you checkpoint-times; you see your current time if you got no
   complete run on on that side of the map. Else you get the difference to your best run there. 
   Turn this off with "mutate cp_off" (only the output; your times are still recorded) and back on with "mutate cp_on"
   in the console. The times are saved and when you load a map and you capped atleast one side you get an 
   info into your console about the captimes per side you can chase (recall it with "mutate cp_on").
   [default = on]
   
 - deciseconds on the HUD: time may jump back a bit towards captime as timer runs on until server confirmed and submitted capture.

 - search personal records: open console and enter 'mutate myrecs' to see all personal records
   or e.g. 'mutate myrecs rush' to see all your records made on maps named something with 'rush'.
   
 - search records you didn't improve for a long time. E.g. 'mutate myOldRecs 90' to see all your 
   records that are 90 days or older.
  
 - 'mutate deleteThisRec': delete your record on this map - only on your side. Server records are not affected. 
   E.g. get rid of a helped rec.
   
 - 'mutate deleteTheseCP': clear your checkpoint-times on the current map.
   
 - on the scoreboard: if you see no timer but -:-- in grey, the player is dead but did not respawn yet.
   If there is a static time shown, this is the last captime of that player. It is visible as long as repawn 
   of that player is missing.
 
 - no need to edit headers in BTRecords.ini if BT++ is not changing something on client setup/records.
   IF you want to get your old BT-time records transformed, do this:
	-> shutdown UT
	-> open UnrealTournament\System\BTRecords.ini
	-> find your records under [BTPlusPlusv097XXX_C.UserConfig] and edit to [BTPlusPlusv098_C.UserConfig]
	-> save and start UT
	-> enter BT server with 098 
	-> enter 'mutate keepmyrecs' in console
	 
FOR ADMINS
 - edit server-records: enter 'mutate btpp editrec MAPNAME?CAPTIME?PLAYERNAME?TIMESTAMP' into
   console; use the same format for MAPNAME, CAPTIME and TIMESTAMP as it is used in the BTPlusPlus.ini (@ [BTPlusPlus.ServerRecords]). 
   don't use ? for anything but separation; '?TIMESTAMP' is optional - if not given, the current timestamp is used.
   !!! use a text editor and compose there carefully !!! - or search "new server-record; old one:" in the LOG to find the
   string representing the replaced record ready for copying right when it happened.
   Example: "mutate btpp editRec CTF-BT-Blahblahblah-v2?592969?bestPlayer?1289018995"
		 or "mutate btpp editRec CTF-BT-Blahblahblah-v2?592969?bestPlayer"

 - delete server-record: 'mutate btpp deleteRec MAPNAME'. MAPNAME is the complete mapname as it is
   saved inside BTPlusPlus.ini. Search for it with 'mutate records map SUBSTRING'.

 - second client package: new entry
	ServerPackages=BTPPUser 				<<<<---- NEW
	ServerPackages=BTPlusPlusv0991_C
	
 - transform server records to new time:
	-> rename header of the old recs in BTRecords.ini to [BTPlusPlus.RecordData]
	-> login as admin
	-> type 'mutate btpp transformRecs'
 
 - server setup AND server records are saved in BTPlusPlus.ini
	
FOR Rec-Editing:
 - new format of the captimes in BTRecords/Logs/EventListening(cap):
	You still get an int, but now you use "600000 - Value" and you get full centiseconds (10^(-2) seconds).

\\\\\\\\\\\\\\\\|////////////////
 CHANGES COMING WITH BT++ v0.99
////////////////|\\\\\\\\\\\\\\\\
Q&A:
----
Q: Any edits needed?
A: Not for players as BTPPUser didn't change.

Q: Why is the insta hitting well below the crosshair?
A: This is exactely the way the normal insta/shock does. Don't ask me for reasons.

Q: What about spawnjumping.
A: Well I tried alot and found this:
Spawnjumping only happens on network - games and:
	a) happens when die accelerating(-ted?)
	b) continues endlessly if you respawn without doing the jump+suicide fix (or some other movement) yourself
	c) dodging when dead causes a spawnjump too
At least b+c are gone now. So if you spawnjump you only have to respawn again to be safe on the next run.


FOR Admins:
 - bGhostWhenCamping, CampTime, CampRadius, bEverybodyGhosts ARE REMOVED
 NOW:
 a) bGhosts = False
    All players look like normal UT players
 b) bGhosts = True + bOnlyABGhosts = False
	All players look like ghosts (see-through)
 c) bGhosts = True + bOnlyABGhosts = True
	All players with antiboost on are ghosts; boostable players look normal
	
 - bFocusBestCapper
	If True: after a game ended the player present with the best captime in this game is focused
	- FAILING WITH OVERTIME

FOR Players:
 - myStart: Normally you spawn at a random start and often some are more advantageous than others.
  Instead of respawning 10+ times for every try respawn until you hit a prefered start and then
  type 'mutate mystart' or say "mystart" and then it is your start! Before choosing a new one you
  have to clear the old one with 'mutate clearstart' or saying "clearstart".
  
##########
### INSTALLATION:
#
Alright, you can run it both as a ServerActor or as a Mutator. Choose one:

 - Running as a ServerActor:
  Copy all files EXCEPT BTPlusPlusv0991.int to your System directory and add the below lines to the [Engine.GameEngine] section of UnrealTournament.ini
  ServerActors=BTPlusPlusv0991.BTPlusPlus
  ServerPackages=BTPPUser
  ServerPackages=BTPlusPlusv0991_C

 - Running as a Mutator:
  Copy ALL files to your System directory and and add the below line to the [Engine.GameEngine] section of UnrealTournament.ini
  ServerPackages=BTPPUser
  ServerPackages=BTPlusPlusv0991_C
  You can add it to you server's startup script by putting BTPlusPlusv0991.BTPlusPlus there. For example:
  ucc BT-Maverick.unr?game=Botpack.CTFGame?mutator=BDBMapVote304.BDBMapVote,BTPlusPlusv0991.BTPlusPlus
  Note: The int file gives you the advantage to select BTPlusPlus as a mutator in various lists, for example in webadmin


##########
### UPGRADING:
#
Backup BTPlusPlus.ini for safety.
Rename both headers in BTPlusPlus.ini from the last version used
to [BTPlusPlusv0991.BTPlusPlus] and [BTPlusPlusv0991.ServerRecords] respectively.

##########
### SETTINGS
#
Edit BTPlusPlus.ini to your needs or use a "mutate btpp" command while logged
as server admin to change the following variables..

bEnabled=True
 - Well, quite obvious, isn't it? :>

bBTScoreboard=True
 - Triggers the use of an enhanced scoreboard.

bAutoLoadInsta=True
 - Will autoload a customized instagib mutator, shooting blue rays when
   target is unaffected. It should also automatically unload all zeroping
   mods.
   Note: The last is sorta experimental, let me know whether it works.

bMultiFlags=True
 - Toggles the MultiFlags feature which makes the flags being copied instead
   of being given away to players. More than one player can carry the flag
   at the same time thanks to this. Dropped flags will automatically
   be destroyed.

bRespawnAfterCap=True
 - When set to true, players just after capping will be teleported back to
   the respawn points.

bAntiBoost=True
 - Toggles the AntiBoost usage, it also affects options bDefaultAllowBoost and
   bBlockBoostForGood. By default, AntiBoost function allows players to allow
   or disallow boosting for themselves.

bBlockBoostForGood=False
 - When bAntiBoost=True, it will simply disable all boosting just as the name
   says.

AllowBoostOn=
 - Here you can set maps which you would like to globally allow boosting on
   when it is forbidden by other settings. The maps should be separated by
   a comma ',', and the names should be set the way to match many variations
   of a map name. For example 'BT-TeamPlayMap' will also trigger this option
   on any maps containing this string, like for example on
   'CTF-BT-TeamPlayMap-xyz'. Note that is is case in-sensitive.

bNoKilling=True
 - Blocks players from killing members of other team. One exception is an
   Enemy Flag Carrier(but only when bMultiFlags=false). The reason for the
   exception is that on some buggy maps it may be possible to steal a flag
   from the other side making it impossible for that team to cap. And that's
   why I advice to use bMultiFlags=True.

AllowKillingOn=BT-Colors,BT-1point4megs,BT-i4games,BT-Abomination,BT-Allied
 - Here you can set maps which you would like to globally allow killing on
   when it is forbidden by bNoKilling. The maps should be separated by a
   comma ',', and the names should be set the way to match many variations of
   a map name. For example 'BT-Colors' will also trigger this option on any
   maps containing this string, like for example on 'CTF-BT-Colors-xyz'.
   Note that is case in-sensitive. The feature is useful for maps containing
   special frag zones, but make sure that these maps are bug-free to not allow
   shooting on any other zones.

bForceMoversKill=True
 - Toggles the use of ForceMoversKill[] list.

ForceMoversKill[0-9]
   (default for:)ForceMoversKill[0]=Mover0,Mover1,Mover2,Mover5:BT-Maverick
 - Forces specified movers to kill players encrouching/blocking them.
   Format=%Mover%,%Mover%,... :%Map%,%Map%
   Up to ten movers and maps in one setting.
   Note: You get mover names from UnrealEd. Edit the map, find a mover, right
   click on it, Object -> Name.
   Note2: When map is set to BT-Maverick it will work for CTF-BT-MaverickCB
   also cause it checks for the inclusion of one string in another, it is also
   case insensitive.

bNoCapSuicide=True
 - This option is mandatory for bRespawnAfterCap to work with BunnyTrack mod
   which kills every player who finishes a map, this option disables that
   behaviour allowing bRespawnAfterCap to work.

RecordsWithoutBoost=0
 - This option accepts three settings:
   0 - Records will be saved no matter whether a player has been boosted.
   1 - Records will be saved only when a player hasn't been boosted.
   2 - Same as 1, but it excludes teamplay maps(maps containing -II or -III).

bDisableInTournament=True
 - Useful when you use the same server for clanwars.

bDisableInNonBTMaps=True
 - Useful when you run a public server with other gametypes. Non-BT maps are
   maps without a prefix BT- and CTF-BT.

BoardLabel=BunnyTrack (BT++)
 - This is the text that appears on the top of the scoreboard. Change it
   to your liking.

CountryFlagsPackage=CountryFlags2
 - If you have IpToCountry installed, make sure that this variable is set to
   a real country flags package you have. Remember that the package has to be
   also in ServerPackages.

bGhosts & bOnlyABGhosts
 a) bGhosts = False
    All players look like normal UT players
 b) bGhosts = True + bOnlyABGhosts = False
	All players look like ghosts (see-through)
 c) bGhosts = True + bOnlyABGhosts = True
	All players with antiboost on are ghosts; boostable players look normal

bFocusBestCapper
	If True: after a game ended the player present with the best captime in this game is focused
	- FAILING WITH OVERTIME	
	
bCarcasses
	Simply allowing dead bodies or not. Did remove them on 098 because there were server-crashes
	related to them: http://www.unrealadmin.org/forums/showpost.php?p=159908&postcount=956



##########
## INGAME COMMANDS:
#
 - mutate ab_on  - Disallows others to boost you.
 - say noboost   - Same as above
 - mutate ab_off - Allows others to boost you
 - say boost     - Same as above
 - mutate cp_on  - show checkpoint-times (and show available times)
 - mutate cp_off - do not show checkpoint-times
 - mutate deleteThisRec - delete your record on the current map
 - mutate deleteTheseCP - delete your checkpoint-times on this map
 - mutate bthelp - Prints out help.
 - mutate btpp - Configuration menu for admins. One has to be logged.
 - mutate btpp get <value> -
 - mutate records - Help for record searching.
 - mutate records map <mapname> - Searches record database by map name.
 - mutate records player <playername> - Searches record database by player name.
 - mutate myrecs <mapname> - Searches personal records made on maps containing <mapname>
 - mutate myOldRecs X - search personal records at least X days old
 - mutate mystart or say "mystart" - choose last start as yours
 - mutate clearstart or say "clearstart" - remove the mystart set
 *In sake of compatibility, old commands should still be working.


##########
## CHANGELOG:
#
v0.991 by Cruque; bugreporting and -tracking by luluthefirst, Fulcrum and Niko *BIG THANKS*
 - fix: mystart messages
 - fix: wrong rotation when using a mystart
 - fix: recognize playerstarts placed too close to walls/floors... -> for mystart choosing
 - option: bCarcasses
 - BTCP & BT++ compatible 
	[ServerActors=BTPlusPlusv0991.BTPlusPlus *BEFORE* ServerActors=BTCheckPoints.BTCheckPoints]
	
v0.99 by Cruque; contribution by luluthefirst
 - new: myStart (= choose one start per side of a map you want to spawn at)
 - new: mappername & clock on the scoreboard
 - new: teamcolored insta (credit goes to luluthefirst)
 - new: no carcasses
 - new: restore run-count, cap-count and best cap (+deaths/+score from PRI) IF playername is unchanged
 - new: focus best capper
 - new: shoot through players with AB on -> no lockdown on dodges
 - new: ghost config
 - fix: sort by captime
 - fix: checkpoint times
 - maybe fixed ancient accessed none in scoreboard code
 - optimized: collecting spectators

v0.98 by Cruque; input and testing by luluthefirst
 - new: adopting time introduced by the i4G BT mod
 - new: separate client-setup & record package -> less editing on updates of BT++
 - new: checkpoint times
 - new: show captimes on scoreboard as long as the player does not respawn/empty time if idle after death
 - new: deciseconds for the HUD-timer (on caps: runs on and jumps back a bit due to network delay)
 - new: compare captime with personal record/show improvement of maprecord
 - new: admin command for editing/deleting server-records
 - new: browsing own records too
 - new: player command deleting record/checkpoint-times on current map
 - temp feature: transform BT-time records to new time for server and players
 - fix: sort players by captime (now also with gametype=CTFGame) + fix: without messing up fragcount
 - fix: on scoreboard: server-record-text overlapping with rules/data around playername messing up(?)
 - removed: bSaveRecords -> always TRUE now
 - removed: bBTScoreboard -> always TRUE now
 - changed: accepting records up to 99:59.99 (capping beyond that is possible but no records/also checkpoint-times don't go with that)
 - changed: if players are not allowed to rec due to boosting, now they not allowed to even cap
 
v0.97r7 by Cruque	
 - fix: bug addressed in v0.97r6_fixed2 detected and fixed inside BT++
 - fix: 50 % chance that timers show a 1 second lower time than the correct BunnyTrack-Time / Timer jumping towards captime ("WTF it was X:YZ @#;*+%!..." - no it wasn't)
 - small changes

v0.97r6_fixed2 by Cruque
 - fix: capping before game started, or after game ended; most likely not caused by BTPP

v0.97r6_fixed by Cruque
 - fix: Accessed Nones with self-boosting exception; 
		fix by Azura/TheDane
		report by luluthefirst http://www.unrealadmin.org/forums/showpost.php?p=158683&postcount=141

v0.97r6 by Cruque; based on BTPlusPlusv097r2.zip
 - adding Rush's Crashfix from BTPlusPlus_crashfixtest2.zip (SuperShockRifleBT.uc)
 - adding Bloeb's self-boosting exception (http://www.unrealadmin.org/forums/showpost.php?p=157293&postcount=109)
 - fix: polycap / 0:01 recs (except polycaps with singleflag)
 - fix: bug with personal records
 - fix: ForceMoversKill, AllowKillingOn and AllowBoostOn processing all elements
 - fix: handling malplaced flags
 - fix: BTPlusPlus not seeing single-flag caps
 - change: AntiBoost on by default
 - only one timestamp per cap generated and used
 - add: guide for users to keep their records
 - small changes

v0.97r5 and v0.97r4 by Cruque
 bugged

v0.97r3
 ?
 
v0.97r2
 - Changed IpToCountry detection to allow Matthew's updated IpToCountry
   to be detectable.

v0.97(through all the pre versions)
 - Added a full blown new sexy Scoreboard with IpToCountry support!
 - Added option AllowBoostOn as requested by someone, see the SETTINGS section
   in the README for further details.
 - Changed bRecordsWithoutBoost to RecordsWithoutBoost in order to add a third
   setting which allows boost records with boosting only on teamwork maps.
 - Removed possibility to enable/disable BTPlusPlus ingame.(due to many
   complications)
 - Added more preeliminary checks whether BT++ can start.
 - Added bRespawnAfterCap which does a respawn instead of killing a player,
   with BunnyTrack mod it has to be used in conjunction with bRespawnAfterCap.
 - bMultiFlags=False is working and nothing is dependant on it now.
 - Changed the net/replication code again, should be more reliable now.
 - Timer on the HUD should be more exact now!
 - Added timestamp to newly saved records.(not used yet though),
 - Format of BTRecords.ini had to be changed because it didn't allow for some
   characters being used in nicknames.
 - Autoloaded instagib is now improved, it has a blue ray when shooting
   opponents or players with antiboost on. Also ray shouldn't cause the
   lockdown effect now.
 - Records are also saved clientside now, they are independant of
   the server ones though.
 - Added some clientside settings allowing to hide the hud or make BT++
   silent, AntiBoost status should also be saved between games.
 - Improved the quality of the sourcecode, anybody cares to read it ? :D
 - Changed searching for records by map behaviour, now it displays multiple
   records.
 - Fixed a lot of small bugs and done a lot of small tweaks.
 - I probably missed something, sorry. ;)

v0.96c
 - Fixed and reorganized replication code.
 - bRecordsWithoutBoost should really work

v0.96b (Internal version)
 - A secret :)

v0.96
 - Optimized a LOT of functions, record searching, timer updates and a few more.
 - Added option to not save records achieved with boosting.
 - Added option to totally block boost.
 - Added option to autoload instagib during map start, it also disabled all
   zeroping mods currently running. (tested with ZPPure)
 - Added option to make all players ghosts.

v0.95
 - Added feature to save map records and commands for doing database searches.
 - Fixed spectator's custom flags and BT++ logo not being showed.

v0.94:
 - Fixed bug which caused weird behaviour of antiboost status and best times
   on the hud ...

v0.93b:
 - Fixed best times on the HUD.

v0.93:
 - Hopefully fixed the bug with logo and flag icons not being shown sometimes
   ... or better to say most of the time.
 - Added some HUD goodies.

v0.92:
 - Added cap times incorporating. Will show the current time and best time
   after scoring the flag.
 - Cleaned up the code, made anticamper function more simple.
 - Improved player initializing functions. Previous version handled only
   32 player joins for one map.
 - Added nice logo and custom flag icons.

v0.91:
 - Fixed the bug with displaying Flag Icon on the HUD.
 - Fixed the bug(hope so) with flags being invisible sometimes.

v0.9:
 - First version. :)
Note: While BTPlusPlus is a direct successor of AntiBoost mutator, you can
check its changelog to get further back.


##########
## COMPILATION:
#
1) Well, firstly I have to say that while compiling this package, you MUST
change the name of source directories to something unique, otherwise you can
get into serious problem called 'Package mismatch' after publicing it!!!

2) BTPlusPlusvXXXX and BTPlusPlusvXXXX_C have to be in the main UT directory,
the same directory where System/, Textures/ etc. are located.

3) Do version name BTPPUser (but try to avoid updates there), but only if the package changed,
not if BTPlusPlus changed. Announce to players using the scheme in BTPlusPlus.Timer.

4) Edit your UnrealTournament.ini and find a section [Editor.EditorEngine],
add the following lines to the bottom of this section:
EditPackages=BTPlusPlusvXXXX_C
EditPackages=BTPlusPlus <- no renaming any longer
Note: The order IS NOT random, _C must be first, because the serverside part
relies on it.

5) Enter System/ subdirectory and execute a command 'ucc make', it should
compile the code now. To recompile, delete the old files and execute the
command again.
Note: It may be crucial to change some version references in source code.
Note2: XXXX is of course some random string of your own compilation.


##########
## EVENT SYSTEM:
#
BTPlusPlus can send out events to actors which are interested in them,
to request events by your actor, you have to the following things:

foreach AllActors(class'Actor', 'BTPlusPlus', A)
   A.Touch;

From this moment your actor will recieve various events through an overriden
GetItemName() function, here's a sample which you could include in your own
actor.

function string GetItemName(string S)
{
   local int index;
   local string EventName;

   index = InStr(S, chr(9));
   if(index != -1)
      EventName = Left(S, index);
   else
      EventName = S;

   switch(EventName)
   {
      case "btpp_started":
         log("BTPlusPlus has just started.");
           /* You can use this event to check whether BTPlusPlus is active
              or not, note that you have to Touch BEFORE PostBeginPlay. */
         break;
      case "cap":
         log("A cap has occured!");
         break;
      case "server_record":
         log("There's a new server record!");
         break;
      case "boost":
         log("A player has been boosted!");
         break;
      case "boost_record_prevent":
         log("A boost has prevented a player from beating a record!");
   }
   if(index != -1)
      log("This is further information about an event: "@log(Mid(S, index+1)));
}

For getting player IDs and cap times you have to parse the string on your
own. Look into  class'BTPlusPlus' in the source code and SendEvent() function
for more information.

BTPlusPlus also does event logging into the LocalLog, it uses the same names
and parameters as for the event notification. It can be used by statistics
collecting software such as UTStats.


##########
## RANDOM FUTURE IDEAS (for someone else to implement):
#
 - Make the ray fly through Ghost players if they have antiboost on.
 - Add some UWindow tool for setting clientside options and for browsing
   clientside records.
 - Add a tournament mode, to make BTPlusPlus more pr0. :)


##########
### THX TO:
#
War and bunnytracks.com community - for initial ideas and support
teleport[pl]*bR - (BIG THANKS) for testing, support, ideas
[es]muhomor - for a nice logo
AnthraX - for overall help over the whole time
ffs-Darkside - for help in the beginning of development
Cratos - for help with replication code
Everybody - for patience since I didn't have time to finish this release for a long time. ^^

##########
### CONTACT & FEEDBACK:
#
Email: rushpl@gmail.com
GG: 1930553
I'm also a member of unrealadmin.org site, username Rush.
Development-Thread: http://www.unrealadmin.org/forums/showthread.php?t=18991