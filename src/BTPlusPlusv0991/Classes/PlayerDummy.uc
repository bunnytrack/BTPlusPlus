/*
    BTPlusPlus 0.991
    Copyright (C) 2011 Cruque

    This program is free software; you can redistribute and/or modify
    it under the terms of the Open Unreal Mod License version 1.1.
*/
//this class is used to test playerstarts - if needed they get moved so players can spawn there without being moved by the engine; implemented for mystart-detection
class PlayerDummy extends Actor;

defaultproperties
{
	CollisionRadius=17.000000
    CollisionHeight=39.000000
	bCollideActors=True
	bCollideWorld=True
}