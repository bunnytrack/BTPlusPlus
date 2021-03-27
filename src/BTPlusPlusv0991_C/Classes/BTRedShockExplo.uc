/*
    BTPlusPlus 0.991
    Copyright (C) 2010 Cruque & luluthefirst
	
    This program is free software; you can redistribute and/or modify
    it under the terms of the Open Unreal Mod License version 1.1.
*/

class BTRedShockExplo extends Effects;

simulated function PostBeginPlay()
{
    if ( Level.NetMode != NM_Client )
        PlaySound(EffectSound1,,12.0,,2000);
    Super.PostBeginPlay();      
}

defaultproperties
{
   	EffectSound1=Sound'Botpack.Vapour'
    RemoteRole=ROLE_SimulatedProxy
    LifeSpan=0.700000
    Style=STY_Translucent
    Texture=Texture'UnrealShare.Effect1.FireEffect1P'
	DrawType=DT_Sprite
	DrawScale=0.300000
	//LightType=LT_Steady
	LightType=LT_TexturePaletteOnce
	LightEffect=LE_NonIncidence
    LightBrightness=192
    LightHue=27
    LightSaturation=71
    LightRadius=9
    bCorona=False 
}