/*
    BTPlusPlus 0.991
    Copyright (C) 2004-2006 Damian "Rush" Kaczmarek

    This program is free software; you can redistribute and/or modify
    it under the terms of the Open Unreal Mod License version 1.1.
*/

class BTScoreBoard extends UnrealCTFScoreBoard;

struct PlayerInfo
{
   var PlayerReplicationInfo PRI;
   var BTPPReplicationInfo RI;
   var string captime;
   var int captimeInt;
};

var BTPPGameReplicationInfo GRI;
var PlayerInfo PI[32];
var int Index;
var BTPPReplicationInfo OwnerRI;
var float tempFrags[32];
var PlayerPawn PlayerOwner;

var const int MAX_CAPTIME;


struct FlagData {
	var string Prefix;
	var texture Tex;
};
var FlagData FD[32]; // there can be max 32 (players?) so max 32 different flags
var int saveindex; // new loaded flags will be saved in FD[index]

var string Spectators[32];

//refreshes spectator list
function Timer()
{
	local int i, k;
	local PlayerReplicationInfo PRI;

	if(PlayerOwner == None)
		PlayerOwner = PlayerPawn(Owner);
	
	
	for(k = 0;k < 32;k++)
	{
		PRI = PlayerOwner.GameReplicationInfo.PRIArray[k];
		if(PRI == None)
			break;
		if(PRI.bIsSpectator && !PRI.bWaitingPlayer && PRI.PlayerName != "Player")
			Spectators[i++] = PRI.PlayerName;
	}
	while(i<32)
		Spectators[i++] = "";
}

//DrawTrailer - custom version
function DrawTrailer( canvas Canvas )
{
    local int Hours, Minutes, Seconds;
    local float XL, YL;
    
    Canvas.bCenter = true;
    Canvas.StrLen("Test", XL, YL);
    Canvas.DrawColor = WhiteColor;
	if(PlayerOwner == None)
		PlayerOwner = PlayerPawn(Owner);
    Canvas.SetPos(0, Canvas.ClipY - 2 * YL);
    
	if(Level.Author != "")
		Canvas.DrawText(Level.Title @ Author @ Level.Author, true);
	else
		Canvas.DrawText(Level.Title, true);
		
    Canvas.SetPos(0, Canvas.ClipY - YL);
    if ( bTimeDown || (PlayerOwner.GameReplicationInfo.RemainingTime > 0) )
    {
        bTimeDown = true;
        if ( PlayerOwner.GameReplicationInfo.RemainingTime <= 0 )
            Canvas.DrawText(RemainingTime@"00:00", true);
        else
        {
            Minutes = PlayerOwner.GameReplicationInfo.RemainingTime/60;
            Seconds = PlayerOwner.GameReplicationInfo.RemainingTime % 60;
			if(Level.Minute < 10)
				Canvas.DrawText(RemainingTime@TwoDigitString(Minutes)$":"$TwoDigitString(Seconds) @ " [clock: " $ Level.Hour $ ":0" $ Level.Minute $ "]", true);
			else
				Canvas.DrawText(RemainingTime@TwoDigitString(Minutes)$":"$TwoDigitString(Seconds) @ " [clock: " $ Level.Hour $ ":" $ Level.Minute $ "]", true);
        }
    }
    else
    {
        Seconds = PlayerOwner.GameReplicationInfo.ElapsedTime;
        Minutes = Seconds / 60;
        Hours   = Minutes / 60;
        Seconds = Seconds - (Minutes * 60);
        Minutes = Minutes - (Hours * 60);
		if(Level.Minute < 10)
			Canvas.DrawText(ElapsedTime@TwoDigitString(Hours)$":"$TwoDigitString(Minutes)$":"$TwoDigitString(Seconds) @ " [clock: " $ Level.Hour $ ":0" $ Level.Minute $ "]", true);
		else
			Canvas.DrawText(ElapsedTime@TwoDigitString(Hours)$":"$TwoDigitString(Minutes)$":"$TwoDigitString(Seconds) @ " [clock: " $ Level.Hour $ ":" $ Level.Minute $ "]", true);
    }

    if ( PlayerOwner.GameReplicationInfo.GameEndedComments != "" )
    {
        Canvas.bCenter = true;
        Canvas.StrLen("Test", XL, YL);
        Canvas.SetPos(0, Canvas.ClipY - Min(YL*6, Canvas.ClipY * 0.1));
        Canvas.DrawColor = GreenColor;
		
        Canvas.DrawText(Ended, true);
    }
    else if ( (PlayerOwner != None) && (PlayerOwner.Health <= 0) )
    {
        Canvas.bCenter = true;
        Canvas.StrLen("Test", XL, YL);
        Canvas.SetPos(0, Canvas.ClipY - Min(YL*6, Canvas.ClipY * 0.1));
        Canvas.DrawColor = GreenColor;
        Canvas.DrawText(Restart, true);
    }
    Canvas.bCenter = false;
}


function int GetFlagIndex(string Prefix)
{
	local int i;
	for(i=0;i<32;i++)
		if(FD[i].Prefix == Prefix)
			return i;
	FD[saveindex].Prefix = Prefix;
	FD[saveindex].Tex = texture(DynamicLoadObject(GRI.CountryFlagsPackage$"."$Prefix, class'Texture'));
	i = saveindex;
	saveindex = (saveindex+1) % 256;
	return i;
}

function ShowScores( canvas Canvas )
{
	local PlayerReplicationInfo PRI;
	local BTPPReplicationInfo BT_PRI;
	local int PlayerCount, i;
	local float LoopCountTeam[4];
	local float XL, YL, XOffset, YOffset, XStart;
	local int PlayerCounts[4];
	local int LongLists[4];
	local int BottomSlot[4];
	local font CanvasFont;
	local bool bCompressed;
	local int ident;
	
	if(GRI == None)
		foreach AllActors(class'BTPPGameReplicationInfo', GRI)
		{
			SetTimer(1.0, true); // good place to initialize our timer
			break;
		}
		
	if(PlayerOwner == None)
		PlayerOwner = PlayerPawn(Owner);
		
	OwnerInfo = Pawn(Owner).PlayerReplicationInfo;
	OwnerGame = TournamentGameReplicationInfo(PlayerOwner.GameReplicationInfo);
	Canvas.Style = ERenderStyle.STY_Normal;
	DrawSpectators(Canvas);

	CanvasFont = Canvas.Font;

	// Header -> calls DrawVictoryConditions or draws victory msg
	DrawHeader(Canvas);

	for ( i=0; i<32; i++ )
		Ordered[i] = None;

	for ( i=0; i<32; i++ )
	{
		PRI = PlayerOwner.GameReplicationInfo.PRIArray[i];
		if(PRI != None)
		{
			if(!PRI.bIsSpectator || PRI.bWaitingPlayer)
			{
				Ordered[PlayerCount] = PRI;
				
				PlayerCounts[PRI.Team]++;
				
				/////use own measure to sort////
				BT_PRI = FindInfo(PRI, ident);
				if(BT_PRI == None)
					tempFrags[PlayerCount] = PRI.Score;
				else
				{
					//captime has precedence 
					if(BT_PRI.BestTime != 0)
						tempFrags[PlayerCount] = BT_PRI.BestTime;
					else //on the bottom: without cap sort by frags <= 0 < any valid captime
						tempFrags[PlayerCount] = PRI.Score;
				}
				///////////////////////////////////
				
				PlayerCount++;
			}
		}
	}
	//sort by captime/score 
	SortScores(PlayerCount);
		
	Canvas.Font = MyFonts.GetMediumFont( Canvas.ClipX );
	Canvas.StrLen("TEXT", XL, YL);
	ScoreStart = Canvas.CurY + YL*2;
	if ( ScoreStart + PlayerCount * YL + 2 > Canvas.ClipY )//reduced display due to many players
	{
		bCompressed = true;
		/*CanvasFont = Canvas.Font;
		Canvas.Font = Canvas.SmallFont;
		r = YL;//???
		Canvas.StrLen("TEXT", XL, YL);
		r = YL/r;
		Canvas.Font = CanvasFont;*/
	}
	for ( I=0; I<PlayerCount; I++ )
	{
		if ( Ordered[I].Team < 4 )
		{
			if ( Ordered[I].Team % 2 == 0 )
				XOffset = (Canvas.ClipX / 4) - (Canvas.ClipX / 8);
			else
				XOffset = ((Canvas.ClipX / 4) * 3) - (Canvas.ClipX / 8);

			Canvas.StrLen("TEXT", XL, YL);
			Canvas.DrawColor = AltTeamColor[Ordered[I].Team];
			YOffset = ScoreStart + (LoopCountTeam[Ordered[I].Team] * YL) + 2;
			if (( Ordered[I].Team > 1 ) && ( PlayerCounts[Ordered[I].Team-2] > 0 ))
			{
				BottomSlot[Ordered[I].Team] = 1;
				YOffset = ScoreStart + YL*11 + LoopCountTeam[Ordered[I].Team]*YL;
			}

			// Draw Name and Ping
			if ( (Ordered[I].Team < 2) && (BottomSlot[Ordered[I].Team] == 0) && (PlayerCounts[Ordered[I].Team+2] == 0))
			{
				LongLists[Ordered[I].Team] = 1;

				DrawNameAndPing( Canvas, Ordered[I], XOffset, YOffset, bCompressed);
			}
			else if (LoopCountTeam[Ordered[I].Team] < 8)
				DrawNameAndPing( Canvas, Ordered[I], XOffset, YOffset, bCompressed);
			if ( bCompressed )
				LoopCountTeam[Ordered[I].Team] += 1;
			else
				LoopCountTeam[Ordered[I].Team] += 2;
		}
	}
	for ( i=0; i<4; i++ )//team headers@todo only 2 teams
	{
		Canvas.Font = MyFonts.GetMediumFont( Canvas.ClipX );
		if ( PlayerCounts[i] > 0 )
		{
			if ( i % 2 == 0 )
				XOffset = (Canvas.ClipX / 4) - (Canvas.ClipX / 8);
			else
				XOffset = ((Canvas.ClipX / 4) * 3) - (Canvas.ClipX / 8);
			YOffset = ScoreStart - YL + 2;

			if ( i > 1 )
				if (PlayerCounts[i-2] > 0)
					YOffset = ScoreStart + YL*10;

			Canvas.DrawColor = TeamColor[i];
			Canvas.SetPos(XOffset, YOffset);
			Canvas.StrLen(TeamName[i], XL, YL);
			DrawShadowText(Canvas, TeamName[i], false, true);
			Canvas.StrLen(int(OwnerGame.Teams[i].Score), XL, YL);
			if(Canvas.ClipX <= 800)
				Canvas.SetPos(XOffset + (Canvas.ClipX*0.30) - XL, YOffset);
			else
				Canvas.SetPos(XOffset + (Canvas.ClipX*0.26) - XL, YOffset);
			DrawShadowText(Canvas, int(OwnerGame.Teams[i].Score), false, true);

			if ( PlayerCounts[i] > 4 )
			{
				if ( i < 2 )
					YOffset = ScoreStart + YL*8;
				else
					YOffset = ScoreStart + YL*19;
				Canvas.Font = MyFonts.GetSmallFont( Canvas.ClipX );
				Canvas.SetPos(XOffset, YOffset);
				if (LongLists[i] == 0)
					DrawShadowText(Canvas, PlayerCounts[i] - 4 @ PlayersNotShown, false, true);
			}
		}
	}

	// Trailer
	if ( !Level.bLowRes )
	{
		Canvas.Font = MyFonts.GetSmallFont( Canvas.ClipX );
		DrawTrailer(Canvas);
	}
	Canvas.Font = CanvasFont;
	Canvas.DrawColor = WhiteColor;
}

function DrawSpectators(Canvas Canvas)
{
	local float XL, YL;
	local Color OldColor;
	local int i;

	Canvas.Font = Canvas.SmallFont;
	Canvas.StrLen("SPECTATORS:", XL, YL);
	Canvas.SetPos(Canvas.ClipX-XL-2, Canvas.ClipY/15);
	DrawShadowText(Canvas, "SPECTATORS:", False, true);
	if(Spectators[0] == "")
	{
		Canvas.StrLen("NONE", XL, YL);
		Canvas.SetPos(Canvas.ClipX-XL-2, Canvas.CurY);
		DrawShadowText(Canvas, "NONE", False, true);
	}
	else
	{
		Canvas.DrawColor = GreenColor;
		for(i=0;i<32;i++)
		{
			if(Spectators[i] == "")
				break;
			Canvas.StrLen(Spectators[i], XL, YL);
			Canvas.SetPos(Canvas.ClipX-XL-2, Canvas.CurY);
			DrawShadowText(Canvas, Spectators[i], False, true);
		}
	}
}

function DrawCapsAndTime(Canvas Canvas, int Caps, string Time, float XOffset, float YOffset, bool bCompressed, int height)
{
	local float XL, YL, XL2, YL2;
	local Color OldColor;

	OldColor = Canvas.DrawColor;
	Canvas.DrawColor = GreenColor;
	Canvas.StrLen(Time, XL, YL);
	if(Canvas.ClipX <= 800)
		Canvas.SetPos(XOffset + (Canvas.ClipX*0.30) - XL, YOffset);
	else
		Canvas.SetPos(XOffset + (Canvas.ClipX*0.26) - XL, YOffset);
	DrawShadowText(Canvas, Time, False, true);
	if(Canvas.ClipX < 640 || bCompressed)
		return;
	Canvas.DrawColor=GoldColor;
	Canvas.Font = Canvas.SmallFont;
	Canvas.StrLen("CAPS:"@Caps, XL2, YL2);
	
	if(YL == 0)
		YL = height;//in case player deleted his/her maprecord but capped before -> no game-best-time present
	
	if(Canvas.ClipX <= 800)
		Canvas.SetPos(XOffset + (Canvas.ClipX*0.30)/* - XL/2*/ - XL2, YOffset+YL);
	else
		Canvas.SetPos(XOffset + (Canvas.ClipX*0.26)/* - XL/2*/ - XL2, YOffset+YL);
	DrawShadowText(Canvas, "CAPS:"@Caps, False, true);
}

function DrawNameAndPing(Canvas Canvas, PlayerReplicationInfo PRI, float XOffset, float YOffset, bool bCompressed)
{
	local float XL, YL, XL2, YL2, YB;
	local String S, L, T, tempL;
	local Font CanvasFont;
	local int Time, Eff, i, FlagShift;
	local BTPPReplicationInfo RI;
	local color OldColor;
	local int lenstrip; // used for stripping the ZoneInfo to an appropriate width
	local float stripmod; // a modifier dependant on resolution

	RI = FindInfo(PRI, i);//RI == PI[i].RI
	
	if(RI == None) // this sucks, FindInfo couldn't have found PRI
		return;
		
	if(PlayerOwner == None)
		PlayerOwner = PlayerPawn(Owner);

	if(OwnerRI == None)
	{
		if(PlayerOwner.PlayerReplicationInfo.bIsSpectator && !PlayerOwner.PlayerReplicationInfo.bWaitingPlayer)
		{
			foreach Level.AllActors(class'BTPPReplicationInfo', OwnerRI)
				if(PlayerOwner.PlayerReplicationInfo.PlayerID == OwnerRI.PlayerID)
					break;
				else
					OwnerRI = None;
		}
	}

	//if(OwnerRI == None) prevents sb from being drawn when watching a demo with 3rdperson switch
		//return;

	//highlight active admins and own name
	if ( PRI.bAdmin )
		Canvas.DrawColor = WhiteColor;
	else if(PRI == PlayerOwner.PlayerReplicationInfo)
		Canvas.DrawColor = GoldColor;

	
	Canvas.StrLen(PRI.PlayerName, XL, YB);
	// Draw the country flag
	if(Canvas.ClipX >= 512)
		if(RI.CountryPrefix != "")
		{
			OldColor = Canvas.DrawColor;
			Canvas.SetPos(XOffset-6, YOffset+YB/2-4);
			Canvas.DrawColor = WhiteColor;
			Canvas.bNoSmooth = False;//??? maybe this helps flag-drawing bug
			Canvas.DrawIcon(FD[GetFlagIndex(RI.CountryPrefix)].Tex, 1.0); //@todo ?effective size 16x10 -> sometimes bugged draw
			//Canvas.DrawRect(FD[GetFlagIndex(RI.CountryPrefix)].Tex, 16, 10);
			Canvas.DrawColor = OldColor;
			Canvas.bNoSmooth = True;//???
			FlagShift = 12;
		}
/*		else
			FlagShift=0;*/


	Canvas.SetPos(XOffset + FlagShift, YOffset);
	DrawShadowText(Canvas, PRI.PlayerName, False, true);

	if ( Canvas.ClipX > 512 )
	{
		CanvasFont = Canvas.Font;
		Canvas.Font = Canvas.SmallFont;
		Canvas.DrawColor = WhiteColor;

			if (Canvas.ClipX >= 640)
			{
				if(!bCompressed)
				{
					// Draw Time
					Time = Max(0, (Level.TimeSeconds + OwnerRI.timeDelta + OwnerRI.JoinTime - RI.JoinTime)/66);//realtime
					Canvas.StrLen("T:    ", XL, YL);
					Canvas.SetPos(XOffset - XL - 6, YOffset);
					DrawShadowText(Canvas, "T:"$Time, false, true);
				}

				if(CTFFlag(PRI.HasFlag) != None)
				{
					// Flag icon
					Canvas.SetPos(XOffset - XL - 35, YOffset);
					Canvas.DrawIcon(FlagIcon[CTFFlag(PRI.HasFlag).Team], 1.0);
				}
				else if(RI.bReadyToPlay && PRI.bWaitingPlayer)
				{
					Canvas.DrawColor = WhiteColor;
					Canvas.Style = ERenderStyle.STY_Masked;
					Canvas.SetPos(XOffset -XL - 35, YOffset);
					Canvas.DrawIcon(FlagIcon[2], 1.0); // draw a green flag
				}
			}

		if (Level.NetMode != NM_Standalone)
		{

			if(!bCompressed)
			{
				Canvas.StrLen("P:    ", XL2, YL2);
				if(YL == 0)//?bug; time not printed -> don't mess P L E with YL == 0
					YL = YL2;
				// Draw Ping
				Canvas.SetPos(XOffset - XL2 - 6, YOffset + (YL+1));
				DrawShadowText(Canvas, "P:"$PRI.Ping, false, true);

				Canvas.StrLen("L:    ", XL2, YL2);
				Canvas.SetPos(XOffset - XL2 - 6, YOffset + 2*(YL+1));
				DrawShadowText(Canvas, "L:"$PRI.PacketLoss$"%", false, true);
			
			}
		}
		
		if(Canvas.ClipX > 640)
		{
			// Draw Eff
			Canvas.StrLen("E:    ", XL2, YL2);
			Canvas.SetPos(XOffset - XL2 - 6, YOffset + 3*(YL+1));
			if(RI.Runs > 0)
				Eff=int(float(RI.Caps)/float(RI.Runs)*100.0);
			DrawShadowText(Canvas, "E:"$string(Eff)$"%", false, true);
		}
		
		Canvas.Font = CanvasFont;
	}

	// Draw Score
	if (PRI.PlayerName == PlayerOwner.PlayerReplicationInfo.PlayerName)
		Canvas.DrawColor = GoldColor;
	else
		Canvas.DrawColor = TeamColor[PRI.Team];
		
	if(RI.Caps != 0)
		DrawCapsAndTime(Canvas, RI.Caps, RI.BestTimeStr, XOffset, YOffset, bCompressed, YB);
		
	Canvas.Font = CanvasFont;

	Canvas.DrawColor = GoldColor;
	
	if (Canvas.ClipX < 512)
		return;

	// Draw location
	if (!bCompressed)
	{
		CanvasFont = Canvas.Font;
		Canvas.Font = Canvas.SmallFont;

		Canvas.StrLen("TIMER: ", XL, YL);

		if(PRI.Team == OwnerInfo.Team)
		{
			if ( PRI.PlayerLocation != None )
				L = PRI.PlayerLocation.LocationName;
			else if ( PRI.PlayerZone != None )
				L = PRI.PlayerZone.ZoneName;
			else
				L = "";
				
			if ( L != "" )
			{
				L = InString@L;

				Canvas.SetPos(XOffset, YOffset + YB + YL + 1);

				lenstrip = 0;

				if(Canvas.ClipX <= 800)
					stripmod = 0.3;
				else
					stripmod = 0.26;
				do { //@todo efficient
					tempL = Left(L, len(L)-lenstrip++);
					Canvas.StrLen(tempL, XL2, YL2);
				} until(XL2 <= Canvas.ClipX*stripmod)
				L = tempL;
				DrawShadowText(Canvas, L, False, true);
			}
		}
		Canvas.SetPos(XOffset, YOffset + YB);
		
		OldColor = Canvas.DrawColor;
		
		//not on a run?
		if(RI.bNeedsRespawn || (PlayerOwner != None &&PlayerOwner.IsInState('GameEnded')))
		{
			Canvas.DrawColor = SilverColor;
		
			if(RI.lastCap != 0)//got to show the captime
			{
				if(PI[i].captimeInt != RI.lastCap)//new captime?
				{	
					PI[i].captime = FormatCentiseconds(RI.lastCap, True);
					PI[i].captimeInt = RI.lastCap;
				}
				DrawShadowText(Canvas, PI[i].captime, False, True);
			}
			else //idle/game ended
				DrawShadowText(Canvas, "-:--", False, True);
		}
		else
		{
		
			//regular timer
			DrawShadowText(Canvas, "TIMER: ", False, True);
			Canvas.SetPos(XOffset + XL, YOffset + YB);

			Canvas.DrawColor = GreenColor;

			if(PRI.bIsSpectator && PRI.bWaitingPlayer)
				T = "0:00";
			else
				T = FormatScore(RI.runTime / 100);
			DrawShadowText(Canvas, T, False, true);
		}

			
		Canvas.DrawColor = OldColor;
	
		Canvas.StrLen("DEATHS:"@int(PRI.Deaths), XL, YL);
	
		//new: ~centered relative to timer and caps
		if(Canvas.ClipX <= 800)
			Canvas.SetPos(XOffset + (Canvas.ClipX*0.15) - ((XL*3)>>3), YOffset + YB);
		else
			Canvas.SetPos(XOffset + (Canvas.ClipX*0.13) - ((XL*3)>>3), YOffset + YB);
		
		DrawShadowText(Canvas, "DEATHS:"@int(PRI.Deaths), False, true);

		Canvas.Font = CanvasFont;
	}
}

function DrawVictoryConditions(Canvas Canvas)
{
	local TournamentGameReplicationInfo TGRI;
	local float XL, YL;

	TGRI = TournamentGameReplicationInfo(PlayerOwner.GameReplicationInfo);
	if ( TGRI == None )
		return;

	DrawShadowText(Canvas, GRI.BoardLabel, true);
	Canvas.StrLen("Test", XL, YL);
	Canvas.SetPos(0, Canvas.CurY - YL);

	Canvas.Font = MyFonts.GetMediumFont( Canvas.ClipX );
	Canvas.StrLen("Test", XL, YL);
	if( TGRI.GoalTeamScore > 0 && TGRI.TimeLimit > 0)
	{
		DrawShadowText(Canvas, FragGoal@TGRI.GoalTeamScore$" / "$TimeLimit@TGRI.TimeLimit$":00", true);
		Canvas.SetPos(0, Canvas.CurY - YL);
	}
	else if ( TGRI.GoalTeamScore > 0 )
	{
		DrawShadowText(Canvas, FragGoal@TGRI.GoalTeamScore, true);
		Canvas.SetPos(0, Canvas.CurY - YL);
	}
	else if ( TGRI.TimeLimit > 0 )
	{
		DrawShadowText(Canvas, TimeLimit@TGRI.TimeLimit$":00", true);
		Canvas.SetPos(0, Canvas.CurY - YL);
	}

	//////////////////////////
	if(GRI.MapBestTime != "-:--")//server record
	{
		Canvas.Font = MyFonts.GetSmallFont( Canvas.ClipX );
		Canvas.SetPos(0, Canvas.CurY);
		Canvas.StrLen("Test", XL, YL);
		DrawShadowText(Canvas, "Server record is "$GRI.MapBestTime$" set by "$GRI.MapBestPlayer @ GRI.MapBestAge $ " day(s) ago", true, true);
		Canvas.SetPos(0, Canvas.CurY - YL);
		
		//Cap of the game
		if(GRI.GameBestTime != "")
		{
			Canvas.SetPos(0, Canvas.CurY);
			DrawShadowText(Canvas, "Cap of the game: "$GRI.GameBestTime $" by " $ GRI.GameBestPlayer, true, true);
			Canvas.SetPos(0, Canvas.CurY - YL);
		}
	}

}

// idea and function from UTPro by AnthraX
function DrawShadowText (Canvas Canvas, coerce string Text, optional bool Param,optional bool bSmall, optional bool bGrayShadow)
{
	local Color OldColor;
	local float XL,YL;
	local float X, Y;

	OldColor = Canvas.DrawColor;

	if (bGrayShadow)
	{
		Canvas.DrawColor.R = 127;
		Canvas.DrawColor.G = 127;
		Canvas.DrawColor.B = 127;
	}
	else
	{
		Canvas.DrawColor.R = 0;
		Canvas.DrawColor.G = 0;
		Canvas.DrawColor.B = 0;
	}
	if (bSmall)
	{
		XL = 1;
		YL = 1;
	}
	else
	{
		XL = 2;
		YL = 2;
	}
	X=Canvas.CurX;
	Y=Canvas.CurY;
	Canvas.SetPos(X+XL,Y+YL);
	Canvas.DrawText(Text, Param);
	Canvas.DrawColor = OldColor;
	Canvas.SetPos(X,Y);
	Canvas.DrawText(Text, Param);
}

function SortScores(int N)
{
    local int I, J, Max;
	local float tempF;
    local PlayerReplicationInfo TempPRI;

	for ( I=0; I<N-1; I++ )
    {
        Max = I;
        for ( J=I+1; J<N; J++ )
        {
            if(tempFrags[J] > tempFrags[Max])
                Max = J;
            else if ((tempFrags[J] == tempFrags[Max]) && (Ordered[J].Deaths < Ordered[Max].Deaths))
                Max = J;
            else if ((tempFrags[J] == tempFrags[Max]) && (Ordered[J].Deaths == Ordered[Max].Deaths) &&
                     (Ordered[J].PlayerID < tempFrags[Max]))
                Max = J;
        }
			
		//move PRI
        TempPRI = Ordered[Max];
        Ordered[Max] = Ordered[I];
        Ordered[I] = TempPRI;
		
		//move tempFrags
		tempF = tempFrags[Max];
		tempFrags[Max] = tempFrags[I];
		tempFrags[I] = tempF;
    }
}

//searches for the BTPP RI by the UT PRI given
function BTPPReplicationInfo FindInfo (PlayerReplicationInfo PRI, out int ident)
{
   local int i;
   local BTPPReplicationInfo RI;
   local bool bFound;

	// See if it's already initialized
	for (i=0;i<Index;i++)
	{
		if (PI[i].PRI == PRI)
		{
			ident = i;
			return PI[i].RI;
		}
	}

   // Not initialized, find the RI and init a new slot
   foreach Level.AllActors(class'BTPPReplicationInfo', RI)
   {
      if (RI.PlayerID == PRI.PlayerID)
      {
        bFound = true;
        break;
      }
    }
   // Couldn't find RI, this sucks
	if (!bFound)
		return None;
	
   // Init the slot - on newly found BTPP-RI
   if (Index < 32)//empty elements in array
   {
       InitInfo(Index, PRI, RI);
	   ident = Index;
       Index++;
       return RI;
   }
   else //search dead one
   {
		for (i=0;i<32;i++) //chg from ++i in 098
		{
			if (PI[i].RI == None)
				break;//assign here; else return none/-1
		}
		InitInfo(i, PRI, RI);
		ident = i;
        return RI;
   }
   ident = -1;
   return None;
}

function InitInfo (int i, PlayerReplicationInfo PRI, BTPPReplicationInfo RI)
{
    PI[i].PRI = PRI;
    PI[i].RI = RI;

    if (PRI == PlayerOwner.PlayerReplicationInfo)
      OwnerRI = RI;
}


//====================================
// FormatScore - formats seconds to minutes & seconds
// Triggered in: DrawNameAndPing
//====================================
static final function string FormatScore(int Time)
{
	if(int(Time % 60) < 10)//fill up a leading 0 to single-digit seconds
		return Time/60 $ ":0" $ int(Time%60);
	else
		return Time/60 $ ":" $ int(Time%60);
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


defaultproperties
{
	MAX_CAPTIME=600000
}
