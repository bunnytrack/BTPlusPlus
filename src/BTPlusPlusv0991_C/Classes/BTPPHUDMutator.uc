/*
    BTPlusPlus 0.991
    Copyright (C) 2004-2006 Damian "Rush" Kaczmarek

    This program is free software; you can redistribute and/or modify
    it under the terms of the Open Unreal Mod License version 1.1.
*/

class BTPPHUDMutator expands Mutator;
/* this class shows the timer, antiboost status, best cap times and also BT++ logo in the beginning */

#exec texture IMPORT NAME=Bunny FILE=TEXTURES\bunny.PCX GROUP="Icons" FLAGS=2 MIPS=OFF
#exec texture IMPORT NAME=btpplogo FILE=TEXTURES\btpplogo.PCX FLAGS=3 MIPS=OFF

var PlayerPawn PlayerOwner;
var float 	DrawTime;
var float 	DrawTick;
var bool 	lastUpdate;//update hud timer a last time - take the captime from RI.LastCap

var float cStamp;
var int oldUpdate;

var enum EDrawState
	{
	DRAW_BLANK,
	DRAW_FADE_IN,
	DRAW_DISPLAY,
	DRAW_FADE_OUT,
	DRAW_DONE

	} DrawState;

var texture Logo;
var bool bDrawSplash;
var float scale;
var BTPPReplicationInfo RI;
var BTPPGameReplicationInfo GRI;
var ClientData Config;
var Color BlackColor;
var int LastTime;

simulated event PostNetBeginPlay()
{
	if(ROLE < ROLE_Authority)
		log("BTPP: HUD PostNetBeginPlay()");

}


simulated function BindReplications()
{
	local Info temp;
	// Spectators doesn't have Replicationinfo spawned in BTPlusPlus.InitNewSpec(), if we don't check against the spectator, the function would run every tick cause RI would be always None
	if((RI == None && (!PlayerOwner.PlayerReplicationInfo.bIsSpectator || PlayerOwner.PlayerReplicationInfo.bWaitingPlayer)) || Config == None || GRI == None )
	{
		foreach AllActors(class'Info', temp)
		{
			if(PlayerPawn(temp.Owner) == PlayerOwner)
			{
				if(temp.IsA('BTPPReplicationInfo'))
					RI=BTPPReplicationInfo(temp);
				else if(temp.IsA('ClientData'))
					Config=ClientData(temp);
			}
			else if(temp.IsA('BTPPGameReplicationInfo'))
				GRI=BTPPGameReplicationInfo(temp);
		}
	}
}


simulated function PostRender( canvas Canvas )
{
	local int X, Y, i;
	local CTFFlag Flag;
	local float W, H;
	local int Time;

	if (PlayerOwner != None && PlayerOwner.PlayerReplicationInfo != None)
	{
		BindReplications();
		if (DrawState != DRAW_DONE)
		{
			if (!bDrawSplash)
			{
				Logo = texture'btpplogo';
				bDrawSplash = True;
				DrawState = EDrawState.DRAW_BLANK;
				DrawTick = 0.0625;
				SetTimer(DrawTick, True);
			}
			else if (DrawState != DRAW_DONE)
				DrawSplash(Canvas);
		}

		// the below code is a copy of CTF's small flags display function
		Scale = ChallengeHUD(PlayerOwner.myHUD).Scale;
		Canvas.Style = Style;
		if( !ChallengeHUD(PlayerOwner.myHUD).bHideHUD && !ChallengeHUD(PlayerOwner.myHUD).bHideTeamInfo )
		{
			X = Canvas.ClipX - 70 * Scale;
			Y = Canvas.ClipY - 350 * Scale;

			Canvas.DrawColor = ChallengeTeamHUD(PlayerOwner.myHUD).TeamColor[0];
			Canvas.SetPos(X,Y);
			Canvas.Style = ERenderStyle.STY_Translucent;
			Canvas.DrawIcon(texture'Bunny', Scale * 2);
			Y -= 150 * Scale;
			Canvas.DrawColor = ChallengeTeamHUD(PlayerOwner.myHUD).TeamColor[1];
			Canvas.SetPos(X,Y);
			Canvas.Style = ERenderStyle.STY_Translucent;
			Canvas.DrawIcon(texture'Bunny', Scale * 2);
			Canvas.Reset();

			if(!PlayerOwner.PlayerReplicationInfo.bIsSpectator && !PlayerOwner.PlayerReplicationInfo.bWaitingPlayer)
			{
				if(RI != None && Config != None)
				{
					//see if server sent a new runtime
					if(oldUpdate != RI.runTime)
					{
						oldUpdate = RI.runTime;
						cStamp = Level.TimeSeconds;
					}
			
					if(Config.bBTHud)
					{
						//update HUD-Timer if the Game is not ended and the player is on a run
						if(!PlayerOwner.IsInState('GameEnded') && !RI.bNeedsRespawn)
						{
							//round down
							//Time = RI.runTime/10;
							//this is about the current time: runs on until server saw a cap; this may cause the timer to jump back a bit
							Time = (oldUpdate + int((Level.TimeSeconds - cStamp) * 90.9090909))/10;//move on from last update until server sends a new one
							LastTime = Time;
							lastUpdate = False;
						}
						else
						{
							oldUpdate = 0;//either dead or game over -> reset
							if(!lastUpdate && !RI.bBoosted)//get the captime replicated, but only show deciseconds
							{
								Time = RI.LastCap / 10;
								LastTime = Time;
								lastUpdate = True;
							}
							Time = LastTime;
						}
						
						////////////////////////////////////
						DrawHUDTimes(Canvas, Time/600, Time % 600);
						////////////////////////////////////
						if(GRI.bShowAntiBoostStatus)
						 	DrawAntiBoostStatus(Canvas);
						////////////////////////////////////
						DrawCP_TimesStatus(Canvas, GRI.bShowAntiBoostStatus);
						
					}
				}
			}
		}
		Canvas.Reset();
	}

	if (NextHUDMutator != None) NextHUDMutator.PostRender(Canvas);
}

simulated function DrawSplash(canvas Canvas)
{
	local float W, H;

	if (DrawState != EDrawState.DRAW_BLANK)
		{
		Canvas.Reset();
		//right corner
		Canvas.SetPos( Canvas.ClipX-2*Logo.USize-40*Scale, Canvas.ClipY-1.75*Logo.VSize-30*Scale);


		Switch (DrawState)
			{
			case EDrawState.DRAW_FADE_IN :
				Canvas.Style = ERenderStyle.STY_Translucent;
				Canvas.DrawColor.R = 225 * DrawTime;
				Canvas.DrawColor.G = 225 * DrawTime;
				Canvas.DrawColor.B = 225 * DrawTime;
				break;

			case EDrawState.DRAW_DISPLAY :
				Canvas.Style = ERenderStyle.STY_Translucent;
				Canvas.DrawColor.R = 225;
				Canvas.DrawColor.G = 225;
				Canvas.DrawColor.B = 225;
				break;

			case EDrawState.DRAW_FADE_OUT :
				Canvas.Style = ERenderStyle.STY_Translucent;
				Canvas.DrawColor.R = 225 - (225 * DrawTime);
				Canvas.DrawColor.G = 225 - (225 * DrawTime);
				Canvas.DrawColor.B = 225 - (225 * DrawTime);
				break;
			}

		Canvas.DrawIcon(Logo, 1.0);

		Canvas.Reset();
		Canvas.bCenter = False;

		Switch (DrawState)
			{
			case EDrawState.DRAW_FADE_IN :
			        Canvas.Style = ERenderStyle.STY_Translucent;
				Canvas.DrawColor.R = 225 * DrawTime;
				Canvas.DrawColor.G = 225 * DrawTime;
				Canvas.DrawColor.B = 225 * DrawTime;
				break;

			case EDrawState.DRAW_DISPLAY :
				Canvas.Style = ERenderStyle.STY_Normal;
				Canvas.DrawColor.R = 225;
				Canvas.DrawColor.G = 225;
				Canvas.DrawColor.B = 225;
				break;

			case EDrawState.DRAW_FADE_OUT :
				Canvas.Style = ERenderStyle.STY_Translucent;
				Canvas.DrawColor.R = 225 - (225 * DrawTime);
				Canvas.DrawColor.G = 225 - (225 * DrawTime);
				Canvas.DrawColor.B = 225 - (225 * DrawTime);
				break;
			}

			Canvas.Font = Canvas.MedFont;
			Canvas.TextSize("BTPlusPlus v0.991",W,H);

			Canvas.SetPos( Canvas.ClipX-1.5*Logo.USize-40*Scale-W/2, Canvas.ClipY-0.75*Logo.VSize-20*Scale);
			Canvas.DrawText("BTPLusPlus v0.991");
		}
}

simulated function Timer()
{
	DrawTime = DrawTime + DrawTick;

	Switch (DrawState)
		{
		case EDrawState.DRAW_BLANK :
			if (DrawTime >= 1.0)
			{
				DrawState = EDrawState.DRAW_FADE_IN;
				DrawTime = 0.0;
			}
			break;

		case EDrawState.DRAW_FADE_IN :
			if (DrawTime >= 1.0)
			{
				DrawState = EDrawState.DRAW_DISPLAY;
				DrawTime = 0.0;
			}
			break;

		case EDrawState.DRAW_DISPLAY :
			if ( PlayerOwner.PlayerReplicationInfo.bWaitingPlayer )
			{
				DrawState = EDrawState.DRAW_DISPLAY;
				DrawTime = 0.0;
			}
			else if (DrawTime >= 15.0)
			{
				DrawState = EDrawState.DRAW_FADE_OUT;
				DrawTime = 0.0;
			}
			break;

		case EDrawState.DRAW_FADE_OUT :
			if (DrawTime >= 1.0)
			{
				DrawState = EDrawState.DRAW_DONE;
				DrawTime = 0.0;
			}
			break;

		case EDrawState.DRAW_DONE :
			Disable('Timer');
			Logo = None;
			break;
		}

	Super.Timer();
}

simulated function DrawHUDTimes(Canvas Canvas, int Minutes, int Seconds)
{
	local int d;
	local float W, H, SW;

	
	//only move 72*Scale to the right; currently 172*Scale wide
	
	Canvas.CurY = 4;
	Canvas.Style=ERenderStyle.STY_Normal;
	
	if(Minutes > 99)//too long run time: show -:-- in red
	{
		Canvas.DrawColor.R = 255;
		Canvas.DrawColor.G = 0;
		Canvas.DrawColor.B = 0;
		
		Canvas.CurX = Canvas.ClipX/2-57*Scale;
		
		// -:
		DrawShadowTile(Canvas, Texture'BotPack.HudElements1', Scale*50, 35*Scale, 0, 64, 50.0, 35.0);
		Canvas.CurX += 7*Scale;
		
		//-
		DrawShadowTile(Canvas, Texture'BotPack.HudElements1', Scale*25, 35*Scale, 0, 64, 25.0, 35.0);
		Canvas.CurX += 7*Scale;
		
		//-
		DrawShadowTile(Canvas, Texture'BotPack.HudElements1', Scale*25, 35*Scale, 0, 64, 25.0, 35.0);
	}
	else//show actual timer
	{
		//a bit to the left
		Canvas.CurX = Canvas.ClipX/2-102*Scale;
		
		if(RI != None && RI.bNeedsRespawn)//Captime/reset on death in grey
		{
			Canvas.DrawColor.R = 170;
			Canvas.DrawColor.G = 170;
			Canvas.DrawColor.B = 170;
		}
		else if(Minutes < 100)//yellow for default timer
		{
			Canvas.DrawColor.R = 255;
			Canvas.DrawColor.G = 255;
			Canvas.DrawColor.B = 0;
		}
		
		
		if ( Minutes >= 10 )
		{
			d = Minutes/10;
			DrawShadowTile(Canvas, Texture'BotPack.HudElements1', Scale*25, 35*Scale, d*25, 0, 25.0, 35.0);
			Canvas.CurX += 7*Scale;
			Minutes= Minutes - 10 * d;
		}
		else
		{
			//leading 0
			DrawShadowTile(Canvas, Texture'BotPack.HudElements1', Scale*25, 35*Scale, 0, 0, 25.0, 35.0);
			Canvas.CurX += 7*Scale;
		}

		//single digit minutes
		DrawShadowTile(Canvas, Texture'BotPack.HudElements1', Scale*25, 35*Scale, Minutes*25, 0, 25.0, 35.0);
		Canvas.CurX += 3*Scale;

		// ":" 
		DrawShadowTile(Canvas, Texture'BotPack.HudElements1', Scale*12, 35*Scale, 32, 64, 12.0, 35.0);
		Canvas.CurX += 5 * Scale;

		//Seconds 1
		d = Seconds/100;
		DrawShadowTile(Canvas, Texture'BotPack.HudElements1', Scale*25, 35*Scale, 25*d, 0, 25.0, 35.0);
		Canvas.CurX += 7*Scale;

		//Seconds 2
		Seconds -=  100*d;
		d = Seconds / 10;
		DrawShadowTile(Canvas, Texture'BotPack.HudElements1', Scale*25, 35*Scale, 25*d, 0, 25.0, 35.0);
		Canvas.CurX += 7*Scale;

		// "."
		DrawShadowTile(Canvas, Texture'BotPack.HudElements1', Scale*12, 32*Scale, 32, 46, 12.0, 32.0);//32, 78???
		Canvas.CurX += 3 * Scale;

		//Deciseconds
		Seconds -= 10*d;
		DrawShadowTile(Canvas, Texture'BotPack.HudElements1', Scale*16, 42*Scale, 25*Seconds, 0, 25.0, 64.0);
	}

	Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).GoldColor;
	Canvas.Style = ERenderStyle.STY_Normal;
//	Canvas.CurX += 7*Scale;
	Canvas.Font = Canvas.SmallFont;

	if(RI.bBoosted)
	{
		Canvas.TextSize("YOU WERE BOOSTED, RECORD WILL NOT COUNT", W, H);
		Canvas.SetPos(Canvas.ClipX/2 - W/2, 50*Scale+2);
		Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).RedColor;
		DrawShadowText(Canvas, "YOU WERE BOOSTED, RECORD WILL NOT COUNT");
	}
	
	Canvas.Reset();
	Canvas.SetPos(5, Canvas.ClipY/2);
	Canvas.Font = Canvas.SmallFont;
	Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).WhiteColor;
	DrawShadowText(Canvas, "SERVER RECORD:");
	Canvas.TextSize("SERVER RECORD:", W, H);
	Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).GoldColor;
	Canvas.SetPos(5, Canvas.ClipY/2 + H+1);
	DrawShadowText(Canvas, GRI.MapBestPlayer);
	Canvas.TextSize(GRI.MapBestPlayer, W, H);
	Canvas.SetPos(5+W, Canvas.ClipY/2 + H+1);
	Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).WhiteColor;
	DrawShadowText(Canvas, " - ");
	Canvas.TextSize(" - ", SW, H);
	Canvas.SetPos(5+W+SW, Canvas.ClipY/2 + H+1);
	Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).GreenColor;
	DrawShadowText(Canvas, GRI.MapBestTime);
	Canvas.SetPos(5, Canvas.ClipY/2 + 2*H+2);
	Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).WhiteColor;
	DrawShadowText(Canvas, "YOUR RECORD:");
	Canvas.SetPos(5, Canvas.ClipY/2 + 3*H+3);
	Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).GreenColor;
	DrawShadowText(Canvas, Config.BestTimeStr);
}

simulated function DrawAntiBoostStatus(Canvas Canvas)
{
	local float W, H;

	Canvas.Reset();
	Canvas.Font = Canvas.SmallFont;
	Canvas.TextSize("ANTIBOOST: ", W, H);
	Canvas.SetPos(5, Canvas.ClipY/2-1.5*H-1);
	Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).WhiteColor;
	DrawShadowText(Canvas, "ANTIBOOST: ");
	Canvas.SetPos(5+W, Canvas.ClipY/2-1.5*H-1);
	if(Config.bAntiBoost)
	{
		Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).GreenColor;
		DrawShadowText(Canvas, "ON");
	}
	else
	{
		Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).RedColor;
		DrawShadowText(Canvas, "OFF");
	}
}


simulated function DrawCP_TimesStatus(Canvas Canvas, bool antiBoostThere)
{
	local float W, H;

	Canvas.Reset();
	Canvas.Font = Canvas.SmallFont;
	Canvas.TextSize("CP-TIMES: ", W, H);
	if(antiBoostThere)
		Canvas.SetPos(5, Canvas.ClipY/2-3.0*H-1);
	else
		Canvas.SetPos(5, Canvas.ClipY/2-1.5*H-1);
	Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).WhiteColor;
	DrawShadowText(Canvas, "CP-TIMES: ");
	if(antiBoostThere)
		Canvas.SetPos(5+W, Canvas.ClipY/2-3.0*H-1);
	else
		Canvas.SetPos(5+W, Canvas.ClipY/2-1.5*H-1);
	if(Config.bCheckpoints)
	{
		Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).GreenColor;
		DrawShadowText(Canvas, "ON");
	}
	else
	{
		Canvas.DrawColor = ChallengeHUD(PlayerOwner.myHUD).RedColor;
		DrawShadowText(Canvas, "OFF");
	}
}
simulated function Destroyed()
{
	local Mutator M;
	local HUD H;
	
	if ( Level.Game != None ) {
		if ( Level.Game.BaseMutator == Self )
			Level.Game.BaseMutator = NextMutator;
    }
    ForEach AllActors(Class'Engine.HUD', H)
        if ( H.HUDMutator == Self )
            H.HUDMutator = NextHUDMutator;
    ForEach AllActors(Class'Engine.Mutator', M) {
        if ( M.NextMutator == Self )
            M.NextMutator = NextMutator;
        if ( M.NextHUDMutator == Self )
            M.NextHUDMutator = NextHUDMutator;
    }
}

function DrawShadowText (Canvas Canvas, coerce string Text, optional bool Param)
{
    local Color OldColor;
    local int XL,YL;
    local float X, Y;

	if(Text == "")
		Text = " ";
	
    OldColor = Canvas.DrawColor;

    Canvas.DrawColor = BlackColor;
    XL = 1;
	YL = 1;
	X = Canvas.CurX;
	Y = Canvas.CurY;
	Canvas.SetPos(X+XL,Y+YL);
	Canvas.DrawText(Text, Param);
	Canvas.DrawColor = OldColor;
	Canvas.SetPos(X,Y);
	Canvas.DrawText(Text, Param);
}

function DrawShadowTile( Canvas Canvas, Texture Tex, float XL, float YL, float U, float V, float UL, float VL)
{
	local float X, Y;
	local color OldColor;

	X = Canvas.CurX;
	Y = Canvas.CurY;
	Canvas.CurX += 1;
	Canvas.CurY += 1;
	OldColor = Canvas.DrawColor;
	Canvas.DrawColor = BlackColor;
	Canvas.DrawTile(Tex, XL, YL, U, V, UL, VL);
	Canvas.SetPos(X, Y);
	Canvas.DrawColor = OldColor;
	Canvas.DrawTile(Tex, XL, YL, U, V, UL, VL);
}

defaultproperties
{
	BlackColor=(R=0,G=0,B=0)
}
