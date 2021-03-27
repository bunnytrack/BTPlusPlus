/*
    BTPlusPlus 0.991
    Copyright (C) 2004-2006 Damian "Rush" Kaczmarek
	now based on luluthefirsts edit made 2010

    This program is free software; you can redistribute and/or modify
    it under the terms of the Open Unreal Mod License version 1.1.
*/

class SuperShockRifleBT extends SuperShockRifle;

var Pawn P_Owner;

function ProcessTraceHit(Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z)
{
	local string info;
	local vector StartTrace, EndTrace;

	if(P_Owner == None)
		P_Owner = Pawn(Owner);

	if (Other == None)//nothing hit
	{
		HitNormal = -X;
		HitLocation = Owner.Location + X*10000.0;
	}
	
	//BEAM
	SpawnEffect(HitLocation, Owner.Location + CalcDrawOffset() + (FireOffset.X + 20) * X + FireOffset.Y * Y + FireOffset.Z * Z);

	if(P_Owner.PlayerReplicationInfo.Team == 1)
	{
		Spawn(class'BlueRingExplosion',,, HitLocation + HitNormal*4,rotator(HitNormal));
		Spawn(class'BTBlueShockExplo',,, HitLocation + HitNormal*4,rotator(HitNormal)); 
	}
	else 
	{
		Spawn(class'UT_SuperRing',,, HitLocation + HitNormal*4,rotator(HitNormal));
		Spawn(class'BTRedShockExplo',,, HitLocation + HitNormal*4,rotator(HitNormal)); 
	}

	if ( (Other != self) && (Other != Owner) && (Other != None) ) 
		Other.TakeDamage(HitDamage, P_Owner, HitLocation, 60000.0*X, MyDamageType);
}

function actor PawnTraceShot(Pawn P, out vector HitLocation, out vector HitNormal, vector EndTrace, vector StartTrace, optional int limit)
{
	local vector realHit;
	local actor Other;
	local Pawn target;
	
	if(limit < -50) // prevent infinite recursion
	  return None;
	Other = P.Trace(HitLocation,HitNormal,EndTrace,StartTrace,True);

	target = Pawn(Other);
	if (target != None )
	{
		realHit = HitLocation;
		if ( !target.AdjustHitLocation(HitLocation, EndTrace - StartTrace) || target.bFromWall)
		  Other = PawnTraceShot(target, HitLocation,HitNormal,EndTrace,realHit, limit - 1);
	}
	return Other;

}


function TraceFire( float Accuracy )
{
	local vector HitLocation, HitNormal, StartTrace, EndTrace, X,Y,Z;
	local actor Other;
	
	if(P_Owner == None)
		P_Owner = Pawn(Owner);

	Owner.MakeNoise(P_Owner.SoundDampening);
	GetAxes(P_Owner.ViewRotation,X,Y,Z);
	StartTrace = Owner.Location + CalcDrawOffset() + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z; 
	AdjustedAim = P_Owner.AdjustAim(1000000, StartTrace, 2*AimError, False, False);	
	EndTrace = StartTrace + Accuracy * (FRand() - 0.5 )* Y * 1000
		+ Accuracy * (FRand() - 0.5 ) * Z * 1000;
	X = vector(AdjustedAim);
	EndTrace += (10000 * X);
	Other = PawnTraceShot(P_Owner, HitLocation,HitNormal,EndTrace,StartTrace);
	ProcessTraceHit(Other, HitLocation, HitNormal, X,Y,Z);
}

function SpawnEffect(vector HitLocation, vector SmokeLocation)
{
	local ShockBeam sb;
	local SuperShockBeam ssb;
	local Vector DVector;
	local int NumPoints;
	local rotator SmokeRotation;
	
	if(P_Owner == None)
		P_Owner = Pawn(Owner);
		
	DVector = HitLocation - SmokeLocation;
	NumPoints = VSize(DVector)/135;
	if ( NumPoints < 1 )
		return;
	SmokeRotation = rotator(DVector);
	SmokeRotation.roll = Rand(65535);

	if(P_Owner.PlayerReplicationInfo.Team == 1)//team blue
	{
		sb = Spawn(class'ShockBeam',,,SmokeLocation,SmokeRotation);
		sb.MoveAmount = DVector/NumPoints;
		sb.NumPuffs = NumPoints - 1;
	}
	else
	{
		ssb = Spawn(class'SuperShockBeam',,,SmokeLocation,SmokeRotation);
		ssb.MoveAmount = DVector/NumPoints;
		ssb.NumPuffs = NumPoints - 1;
	}
}

defaultproperties
{
	FireSound=Sound'UnrealShare.Skaarj.Skrjshot'
    AltFireSound=Sound'UnrealShare.Skaarj.Skrjshot'
}

