#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <steamtools>

#pragma semicolon 1

public Plugin:myinfo = 
{
	name = "Capture the Flag",
	author = "Spirrwell",
	description = "Capture the Flag Game Mode",
	version = "1.0",
	url = "<- URL ->"
}

enum
{
	Skirmisher = 0,
	Captain,
	Sharpshooter,
	Berserker,
	Huscarl,
	Gestir,
	HeavyKnight,
	Archer,
	ManAtArms,
	ClassMax
}

#define iPirates 0
#define iVikings 1
#define iKnights 2
#define iTeamMax 3

#define SPECTATORS 1
#define PIRATES 2
#define VIKINGS 3
#define KNIGHTS 4

#define GAMEMODE_BOOTY 1
#define GAMEMODE_OBJPUSH 6
#define GAMEMODE_CAPTURETHEFLAG 7

#define PIRATECARRIER "Flag_Carrier_Pirate"
#define VIKINGCARRIER "Flag_Carrier_Viking"
#define KNIGHTCARRIER "Flag_Carrier_Knight"

#define FLAG_PIRATES_SPAWN "info_flag_pirates"
#define FLAG_VIKINGS_SPAWN "info_flag_vikings"
#define FLAG_KNIGHTS_SPAWN "info_flag_knights"

#define FLAGPOLE_PIRATES "item_flag_pirates"
#define FLAGPOLE_VIKINGS "item_flag_vikings"
#define FLAGPOLE_KNIGHTS "item_flag_knights"

#define FLAG_PIRATES_TRIGGER "flag_trigger_pirates"
#define FLAG_VIKINGS_TRIGGER "flag_trigger_vikings"
#define FLAG_KNIGHTS_TRIGGER "flag_trigger_knights"

#define PHYSBOX_PIRATES "info_box_pirates"
#define PHYSBOX_VIKINGS "info_box_vikings"
#define PHYSBOX_KNIGHTS "info_box_knights"

#define CAPZONE_PIRATES "func_capzone_pirates"
#define CAPZONE_VIKINGS "func_capzone_vikings"
#define CAPZONE_KNIGHTS "func_capzone_knights"

#define VOC_YOU_FLAG "ctf/voc_you_flag.wav"
#define VOC_TEAM_FLAG "ctf/voc_team_flag.wav"
#define VOC_ENEMY_FLAG "ctf/voc_enemy_flag.wav"

#define FLAGCAP_OPP		"ctf/flagcapture_opponent.wav"
#define FLAGCAP_TEAM	"ctf/flagcapture_yourteam.wav"
#define FLAGRET_OPP		"ctf/flagreturn_opponent.wav"
#define FLAGRET_TEAM	"ctf/flagreturn_yourteam.wav"
#define FLAGTAK_OPP		"ctf/flagtaken_opponent.wav"
#define FLAGTAK_TEAM	"ctf/flagtaken_yourteam.wav"

new numSoundsClasses[ClassMax] = 
{
	6, //Skirmisher
	6, //Captain
	9, //Sharpshooter
	4, //Berserker
	6, //Huscarl
	5, //Gestir
	4, //Heavy Knight
	5, //Archer
	4  //Man-At-Arms
};

new String:gameDescCTF[17] = "Capture the Flag";
new String:gameDescDefault[15] = "PVKII Beta 3.0";
new const String:RoundStartSounds[ClassMax][] = 
{
	"player/pirates/skirm/p_skirm-roundstartcheerup",	//Skirmisher
	"player/pirates/captain/p_captain-roundstart",		//Captain
	"player/pirates/sharp/p_sharp-roundstartcheerup",	//Sharpshooter
	"player/vikings/berserker/v_zerk-roundstartcheer",	//Berserker
	"player/vikings/huscarl/v_husc_roundstartcheer",	//Huscarl
	"player/vikings/gestir/v_gesti_roundstartcheer",	//Gestir
	"player/knights/heavyknight/k_hk-roundstartcheer",	//Heavy Knight
	"player/knights/archer/k_arche-roundstartcheer",	//Archer
	"player/knights/manatarms/k_manat-roundstartcheer"	//Man-At-Arms
};

new bool:isCTFRunning = false;
new bool:bTeamHasWon = false;
new bool:bWaitingForPlayers = true;
new bool:bRoundEnd = false;
new bool:bGameEnd = false;
new bool:bGameStart = false;

new iMaxCaptures, iCurrentMaxCaptures = 10;
new iPoints_Pirates;
new iPoints_Vikings;
new iPoints_Knights;

new iGameMode, iDisabledTeam;

new iFlagModel[3];
new iFlagTarget[3];
new iFlagTrigger[3];
new iFlagBox[3];
new iCapZone[3];

new Float:VectorZero[3] = { 0.0, 0.0, 0.0 };
new Float:iFlagSpawnPos[3][3];
new Float:iFlagAngles[3][3];
new Float:iFlagPoleAngles[3][3];

new Float:flagDropZOffset = 40.0;
new Float:flagOffset[3] = { -30.0, 0.0, -30.0 };
new Float:flagAngOffset[3] = { 0.0, 90.0, 0.0 };

new Handle:cvarCapVoteLimit = INVALID_HANDLE;
new Handle:cvarMaxCaptures = INVALID_HANDLE;
new Handle:cvarAllowCaptureVote = INVALID_HANDLE;
new Handle:cvarEnabledOnBT = INVALID_HANDLE;
new Handle:cvarRestartRound = INVALID_HANDLE;

new Handle:FlagActiveTimer[iTeamMax];
new Handle:FlagRespawnTimer[iTeamMax];
new Handle:hWaitingForPlayers = INVALID_HANDLE;
new Handle:hGameConfig = INVALID_HANDLE;
new Handle:hSpawn = INVALID_HANDLE;

new entInfPVK = INVALID_ENT_REFERENCE;

SetDefaults()
{
	bTeamHasWon = false;
	
	iPoints_Pirates = 0;
	iPoints_Vikings = 0;
	iPoints_Knights = 0;
	
	iMaxCaptures = iCurrentMaxCaptures;
}

public OnConfigsExecuted()
{
	decl String:mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	if (StrContains(mapName, "ctf_", false) == 0)
		Steam_SetGameDescription(gameDescCTF);
	else
		Steam_SetGameDescription(gameDescDefault);
}

CTF_Setup()
{
	isCTFRunning = false;
	bTeamHasWon = false;
	bWaitingForPlayers = true;
	
	if (hWaitingForPlayers != INVALID_HANDLE)
	{
		CloseHandle(hWaitingForPlayers);
		hWaitingForPlayers = INVALID_HANDLE;
	}
	for (new i = 0; i < iTeamMax; i++)
	{
		iFlagTarget[i] = INVALID_ENT_REFERENCE;
		iFlagTrigger[i] = INVALID_ENT_REFERENCE;
		iFlagBox[i] = INVALID_ENT_REFERENCE;
		iCapZone[i] = INVALID_ENT_REFERENCE;
		FlagActiveTimer[i] = INVALID_HANDLE;
		FlagRespawnTimer[i] = INVALID_HANDLE;
	}
	
	if (iGameMode == GAMEMODE_CAPTURETHEFLAG)
	{
		new iMaxEntities = GetMaxEntities();
		new String:iName[128];
		new String:iClassName[32];
		
		for (new i = 0; i < iMaxEntities; i++)
		{
			if (IsValidEntity(i))
			{
				GetEntityClassname(i, iClassName, sizeof(iClassName));
				if (StrEqual("info_target", iClassName, false))
				{
					GetEntPropString(i, Prop_Data, "m_iName", iName, sizeof(iName));
					if (StrEqual(FLAG_PIRATES_SPAWN, iName, false))
						iFlagTarget[iPirates] = i;
					if (StrEqual(FLAG_VIKINGS_SPAWN, iName, false))
						iFlagTarget[iVikings] = i;
					if (StrEqual(FLAG_KNIGHTS_SPAWN, iName, false))
						iFlagTarget[iKnights] = i;
				}
				if (StrEqual("trigger_multiple", iClassName, false))
				{
					GetEntPropString(i, Prop_Data, "m_iName", iName, sizeof(iName));
					if (StrEqual(FLAG_PIRATES_TRIGGER, iName, false))
						iFlagTrigger[iPirates] = i;
					if (StrEqual(FLAG_VIKINGS_TRIGGER, iName, false))
						iFlagTrigger[iVikings] = i;
					if (StrEqual(FLAG_KNIGHTS_TRIGGER, iName, false))
						iFlagTrigger[iKnights] = i;
					
					if (StrEqual(CAPZONE_PIRATES, iName, false))
						iCapZone[iPirates] = i;
					if (StrEqual(CAPZONE_VIKINGS, iName, false))
						iCapZone[iVikings] = i;
					if (StrEqual(CAPZONE_KNIGHTS, iName, false))
						iCapZone[iKnights] = i;
				}
				if (StrEqual("prop_dynamic", iClassName, false))
				{
					GetEntPropString(i, Prop_Data, "m_iName", iName, sizeof(iName));
					if (StrEqual(FLAGPOLE_PIRATES, iName, false))
						iFlagModel[iPirates] = i;
					if (StrEqual(FLAGPOLE_VIKINGS, iName, false))
						iFlagModel[iVikings] = i;
					if (StrEqual(FLAGPOLE_KNIGHTS, iName, false))
						iFlagModel[iKnights] = i;
				}
				if (StrEqual("func_physbox", iClassName, false))
				{
					GetEntPropString(i, Prop_Data, "m_iName", iName, sizeof(iName));
					if (StrEqual(PHYSBOX_PIRATES, iName, false))
						iFlagBox[iPirates] = i;
					if (StrEqual(PHYSBOX_VIKINGS, iName, false))
						iFlagBox[iVikings] = i;
					if (StrEqual(PHYSBOX_KNIGHTS, iName, false))
						iFlagBox[iKnights] = i;
				}
			}
		}
		for (new i = 0; i < iTeamMax; i++)
		{
			if (iDisabledTeam != i+2)
			{
				GetEntPropVector(iFlagTarget[i], Prop_Send, "m_vecOrigin", iFlagSpawnPos[i]);
				GetEntPropVector(iFlagTarget[i], Prop_Send, "m_angRotation", iFlagAngles[i]);
				GetEntPropVector(iFlagModel[i], Prop_Send, "m_angRotation", iFlagPoleAngles[i]);
			}
		}
		if (iDisabledTeam != PIRATES)
		{
			SDKHook(iFlagTrigger[iPirates], SDKHook_StartTouch, OnStartTouch_Pirates);
			SDKHook(iCapZone[iPirates], SDKHook_StartTouch, OnStartTouchCapZone_Pirates);
		}

		if (iDisabledTeam != VIKINGS)
		{
			SDKHook(iFlagTrigger[iVikings], SDKHook_StartTouch, OnStartTouch_Vikings);
			SDKHook(iCapZone[iVikings], SDKHook_StartTouch, OnStartTouchCapZone_Vikings);
		}
		
		if (iDisabledTeam != KNIGHTS)
		{
			SDKHook(iFlagTrigger[iKnights], SDKHook_StartTouch, OnStartTouch_Knights);
			SDKHook(iCapZone[iKnights], SDKHook_StartTouch, OnStartTouchCapZone_Knights);
		}
		
		HookEvent("player_death", Event_PlayerDeath);
		HookEvent("player_changeteam", Event_ChangeTeam);
		HookEvent("player_spawn",Event_PlayerSpawn);
		HookEvent("game_end", Event_GameEnd, EventHookMode_Pre);
		
		HookConVarChange(cvarMaxCaptures, ConVar_MaxCaptures);
		HookConVarChange(cvarRestartRound, ConVar_RestartRound);
		
		isCTFRunning = true;
		
		for (new i = 1; i <= MaxClients; i++)
			CreateTimer(0.1, HUD_Timer, i, TIMER_REPEAT);
	}
}

public OnMapStart()
{	
	entInfPVK = INVALID_ENT_REFERENCE;
	entInfPVK = FindEntityByClassname(entInfPVK, "info_pvk");
	
	if (entInfPVK == INVALID_ENT_REFERENCE)
		PrintToServer("info_pvk unable to be found");
	else
	{
		iGameMode = GetEntProp(entInfPVK, Prop_Data, "m_iGameMode");
		iDisabledTeam = GetEntProp(entInfPVK, Prop_Data, "m_iDisabledTeam");
		SetDefaults();
		CTF_Setup();
	}
	
	if (isCTFRunning)
	{
		PrecacheSound(VOC_YOU_FLAG);
		PrecacheSound(VOC_TEAM_FLAG);
		PrecacheSound(VOC_ENEMY_FLAG);
		
		PrecacheSound(FLAGCAP_OPP);
		PrecacheSound(FLAGCAP_TEAM);
		PrecacheSound(FLAGRET_OPP);
		PrecacheSound(FLAGRET_TEAM);
		PrecacheSound(FLAGTAK_OPP);
		PrecacheSound(FLAGTAK_TEAM);
		
		PrecacheSound("music/pirateswin.mp3");
		PrecacheSound("music/vikingswin.mp3");
		PrecacheSound("music/knightswin.mp3");
		
		for (new i = 0; i < ClassMax; i++)
		{
			for (new x = 1; x <= numSoundsClasses[i]; x++)
			{
				decl String:sample[64];
				Format(sample, sizeof(sample), "%s%d%s", RoundStartSounds[i], x, ".wav");
				PrecacheSound(sample);
			}
		}
	}
}

public OnMapEnd()
{
	entInfPVK = INVALID_ENT_REFERENCE;
	bTeamHasWon = false;
	bWaitingForPlayers = true;
	
	for (new i = 0; i < iTeamMax; i++)
	{
		iFlagTarget[i] = INVALID_ENT_REFERENCE;
		iFlagTrigger[i] = INVALID_ENT_REFERENCE;
		iFlagBox[i] = INVALID_ENT_REFERENCE;
		iCapZone[i] = INVALID_ENT_REFERENCE;
		if (FlagActiveTimer[i] != INVALID_HANDLE)
		{
			CloseHandle(FlagActiveTimer[i]);
			FlagActiveTimer[i] = INVALID_HANDLE;
		}
		if (FlagRespawnTimer[i] != INVALID_HANDLE)
		{
			CloseHandle(FlagRespawnTimer[i]);
			FlagRespawnTimer[i] = INVALID_HANDLE;
		}
	}
	
	for (new i = 1; i <= MaxClients; i++)
		ClearPlayer(i);
	
	isCTFRunning = false;
	ServerCommand("sv_lan 0");
}

ClearPlayer(client)
{
	if (!IsValidClient(client))
		return;
	
	if (isCTFRunning)
	{
		decl String:iName[32];
		decl String:iTargetName[32];
		GetEntPropString(client, Prop_Data, "m_iName", iName, sizeof(iName));
		new iFlagTeam = GetCarrier(iName);
		if (iFlagTeam == iPirates)
		{
			iTargetName = PHYSBOX_PIRATES;
			FlagActiveTimer[iFlagTeam] = CreateTimer(2.0, SetPirateFlagActive_Timer);
		}
		if (iFlagTeam == iVikings)
		{
			iTargetName = PHYSBOX_VIKINGS;
			FlagActiveTimer[iFlagTeam] = CreateTimer(2.0, SetVikingFlagActive_Timer);
		}
		if (iFlagTeam == iKnights)
		{
			iTargetName = PHYSBOX_KNIGHTS;
			FlagActiveTimer[iFlagTeam] = CreateTimer(2.0, SetKnightFlagActive_Timer);
		}
		
		if (iFlagTeam > -1)
		{
			decl String:victimName[16];
			GetFlagVictim(client, victimName, sizeof(victimName));
			PrintCenterTextAll("%s' flag dropped.", victimName);
			new Float:fplayerPos[3];
			new Float:fFlagAng[3];
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", fplayerPos);
			GetEntPropVector(iFlagTarget[iFlagTeam], Prop_Send, "m_angRotation", fFlagAng);
			
			fFlagAng[0] = 0.0;
			fFlagAng[1] = 0.0;
			fplayerPos[2] += flagDropZOffset;
			AcceptEntityInput(iFlagTarget[iFlagTeam], "ClearParent");

			TeleportEntity(iFlagTarget[iFlagTeam], fplayerPos, fFlagAng, NULL_VECTOR);
			TeleportEntity(iFlagBox[iFlagTeam], fplayerPos, NULL_VECTOR, NULL_VECTOR);
			SetVariantString(iTargetName);
			AcceptEntityInput(iFlagTarget[iFlagTeam], "SetParent");
			AcceptEntityInput(iFlagBox[iFlagTeam], "Wake");
			AcceptEntityInput(iFlagBox[iFlagTeam], "EnableMotion");
		}
		DispatchKeyValue(client, "targetname", "NormalPlayer");
	}
}

public IsValidClient (client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || IsFakeClient(client) || IsClientReplay(client) || IsClientSourceTV(client))
		return false;

	return IsClientInGame(client);
}

public Action:HUD_Timer(Handle:Timer, any:client)
{
	if (IsValidClient(client) && isCTFRunning)
	{
		if (!bWaitingForPlayers)
		{
			SetHudTextParams(-1.0, 1.0, 0.2, 255, 255, 255, 255, 0, 6.0, 0.0, 0.0);
			ShowHudText(client, -1, "Pirates: %d Vikings: %d Knights: %d", iPoints_Pirates, iPoints_Vikings, iPoints_Knights);
		}
		else
		{			
			new TeamsWithPlayers = 0;
			new bool:TeamHasPlayers[iTeamMax];
			for (new c = 1; c <= MaxClients; c++)
				if (IsClientInGame(c))
				{
					new iTeam = GetEntProp(c, Prop_Data, "m_iTeamNum");
					if (iTeam > SPECTATORS && iTeam <= KNIGHTS)
						TeamHasPlayers[iTeam - 2] = true;
				}
			
			for (new i = 0; i <iTeamMax; i++)
				if (TeamHasPlayers[i])
					TeamsWithPlayers++;
			if (TeamsWithPlayers > 1)
			{
				SetHudTextParams(-1.0, 0.02, 0.2, 255, 255, 255, 255, 0, 6.0, 0.0, 0.0);
				ShowHudText(client, -1, "Waiting For Players");
			}
		}
	}
	return Plugin_Handled;
}

public String:GetFlagVictim(client, String:buffer[], maxlen)
{
	decl String:iName[32];
	decl String:iTargetName[32] = "None";
	
	GetEntPropString(client,Prop_Data, "m_iName", iName, sizeof(iName));
	
	if (StrEqual(iName, PIRATECARRIER, false))
		iTargetName = "Pirates";
	if (StrEqual(iName, VIKINGCARRIER, false))
		iTargetName = "Vikings";
	if (StrEqual(iName, KNIGHTCARRIER, false))
		iTargetName = "Knights";
	FormatEx(buffer, maxlen, iTargetName);
}

SetFlagActive(iTeam)
{
	new Float:fFlagPos[3];
	new Float:fFlagAng[3];
	//GetEntPropVector(iFlagTarget[iTeam], Prop_Send, "m_vecOrigin", fFlagPos);
	GetEntPropVector(iFlagTarget[iTeam], Prop_Data, "m_vecAbsOrigin", fFlagPos);
	GetEntPropVector(iFlagTarget[iTeam], Prop_Send, "m_angRotation", fFlagAng);
	TeleportEntity(iFlagTrigger[iTeam], fFlagPos, fFlagAng, NULL_VECTOR);
	AcceptEntityInput(iFlagTrigger[iTeam], "Enable");
}

RespawnFlag(iTeam)
{
	if (iDisabledTeam == iTeam + 2)
		return;
	AcceptEntityInput(iFlagTarget[iTeam], "ClearParent");
	AcceptEntityInput(iFlagBox[iTeam], "Sleep");
	TeleportEntity(iFlagTarget[iTeam], iFlagSpawnPos[iTeam], iFlagAngles[iTeam], NULL_VECTOR);		
	TeleportEntity(iFlagTrigger[iTeam], iFlagSpawnPos[iTeam], iFlagAngles[iTeam], NULL_VECTOR);
	TeleportEntity(iFlagModel[iTeam], NULL_VECTOR, iFlagPoleAngles[iTeam], NULL_VECTOR);
	AcceptEntityInput(iFlagTrigger[iTeam], "Enable");
}

public Action:RoundStartCheer_Timer(Handle:Timer, Handle:datapack)
{
	ResetPack(datapack);
	new client = ReadPackCell(datapack);
	
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Handled;
	
	new iTeam = ReadPackCell(datapack);
	new iClass = ReadPackCell(datapack);
	
	if (iTeam == VIKINGS)
		iClass += 3;
	if (iTeam == KNIGHTS)
		iClass += 6;
	
	//Need to rewrite to play from player voice channel.
	if (iTeam >= PIRATES && iTeam <= KNIGHTS)
	{
		new Float:vOrigin[3];
		new Float:vPos[3];
		new Float:vViewOffset[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", vOrigin);
		GetEntPropVector(client, Prop_Data, "m_vecViewOffset", vViewOffset);
		AddVectors(vOrigin, vViewOffset, vPos);
		decl String:sample[64];
		Format(sample, sizeof(sample), "%s%d%s", RoundStartSounds[iClass], GetRandomInt(1, numSoundsClasses[iClass]), ".wav");
		EmitAmbientSound(sample, vPos, client);
	}
	return Plugin_Handled;
}

public Action:SetPirateFlagActive_Timer(Handle:Timer)
{
	FlagRespawnTimer[iPirates] = CreateTimer(20.0, RespawnPirateFlag_Timer);
	SetFlagActive(iPirates);
	return Plugin_Handled;
}

public Action:SetVikingFlagActive_Timer(Handle:Timer)
{
	FlagRespawnTimer[iVikings] = CreateTimer(20.0, RespawnVikingFlag_Timer);
	SetFlagActive(iVikings);
	return Plugin_Handled;
}

public Action:SetKnightFlagActive_Timer(Handle:Timer)
{
	FlagRespawnTimer[iKnights] = CreateTimer(20.0, RespawnKnightFlag_Timer);
	SetFlagActive(iKnights);
	return Plugin_Handled;
}

public Action:RespawnPirateFlag_Timer(Handle:Timer)
{
	FlagRespawnTimer[iPirates] = INVALID_HANDLE;
	RespawnFlag(iPirates);
	PrintCenterTextAll("Pirate flag returned!");
	PlaySoundToTeam(PIRATES, FLAGRET_TEAM);
	PlaySoundToTeam(VIKINGS, FLAGRET_OPP);
	PlaySoundToTeam(KNIGHTS, FLAGRET_OPP);
	return Plugin_Handled;
}

public Action:RespawnVikingFlag_Timer(Handle:Timer)
{
	FlagRespawnTimer[iVikings] = INVALID_HANDLE;
	RespawnFlag(iVikings);
	PrintCenterTextAll("Viking flag returned!");
	PlaySoundToTeam(PIRATES, FLAGRET_OPP);
	PlaySoundToTeam(VIKINGS, FLAGRET_TEAM);
	PlaySoundToTeam(KNIGHTS, FLAGRET_OPP);
	return Plugin_Handled;
}

public Action:RespawnKnightFlag_Timer(Handle:Timer)
{
	FlagRespawnTimer[iKnights] = INVALID_HANDLE;
	RespawnFlag(iKnights);
	PrintCenterTextAll("Knight flag returned!");
	PlaySoundToTeam(PIRATES, FLAGRET_OPP);
	PlaySoundToTeam(VIKINGS, FLAGRET_OPP);
	PlaySoundToTeam(KNIGHTS, FLAGRET_TEAM);
	return Plugin_Handled;
}

public Action:RoundRestart_Timer(Handle:Timer)
{
	bGameStart = true;
	
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
		{			
			ClearPlayer(i);
			SDKCall(hSpawn, i);
			ClientCommand(i, "-showscores");
			new TeamNum = GetEntProp(i, Prop_Data, "m_iTeamNum");
			if (TeamNum >= PIRATES && TeamNum <= KNIGHTS)
				SetEntityMoveType(i, MOVETYPE_WALK);
		}
	bRoundEnd = false;
	SetDefaults();
	return Plugin_Handled;
}

public Action:CMDListener(client, const String:command[], argc)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
	if (StrEqual(command, "dropitem", false))
		ClearPlayer(client);
	
	return Plugin_Continue;
}

public GetCarrier(const String:iName[])
{
	new iFlagTeam = -1;
	if (StrEqual(PIRATECARRIER, iName, false))
		iFlagTeam = iPirates;
	if (StrEqual(VIKINGCARRIER, iName, false))
		iFlagTeam = iVikings;
	if (StrEqual(KNIGHTCARRIER, iName, false))
		iFlagTeam = iKnights;
	return iFlagTeam;
}

RespawnFlagStr(const String:iName[], iClient)
{
	new iFlagTeam = GetCarrier(iName);
	
	if (iFlagTeam > -1)
	{
		AcceptEntityInput(iFlagTrigger[iFlagTeam], "Enable");
		AcceptEntityInput(iFlagTarget[iFlagTeam], "ClearParent");
		
		TeleportEntity(iFlagTarget[iFlagTeam], iFlagSpawnPos[iFlagTeam], iFlagAngles[iFlagTeam], NULL_VECTOR);		
		TeleportEntity(iFlagTrigger[iFlagTeam], iFlagSpawnPos[iFlagTeam], iFlagAngles[iFlagTeam], NULL_VECTOR);
		TeleportEntity(iFlagModel[iFlagTeam], NULL_VECTOR, iFlagPoleAngles[iFlagTeam], NULL_VECTOR);
		DispatchKeyValue(iClient, "targetname", "NormalPlayer");
	}
}

OnGameWon()
{
	new timeleft;
	GetMapTimeLeft(timeleft);
	if (timeleft == 0)
	{
		bGameEnd = true;
		new Handle:GameEnd = CreateEvent("game_end");
		FireEvent(GameEnd);
	}
	else
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if (!IsPlayerAlive(i))
					SDKCall(hSpawn, i);
				SetEntityMoveType(i, MOVETYPE_NONE);
				ClientCommand(i, "+showscores");
				bRoundEnd = true;
			}
		}
	}
}

public Action:OnStartTouchCapZone_Pirates(entity, client)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	new String:iName[32];
	
	GetEntPropString(client, Prop_Data, "m_iName", iName, sizeof(iName));
	new iTeam = GetEntProp(client, Prop_Data, "m_iTeamNum");
	
	if (StrContains(iName, "Flag_Carrier", false) == 0 && iTeam == PIRATES && !bTeamHasWon)
	{
		if (!bWaitingForPlayers)
			iPoints_Pirates++;
		if (iPoints_Pirates == iMaxCaptures)
		{
			bTeamHasWon = true;
			PrintCenterTextAll("Pirates win!");
			OnGameWon();
			EmitSoundToAll("music/pirateswin.mp3");
			CreateTimer(13.0, RoundRestart_Timer);
		}
		else
		{
			decl String:iTeamName[32];
			GetFlagVictim(client, iTeamName, sizeof(iTeamName));
			PrintCenterTextAll("Pirates captured the %s' flag!", iTeamName);
		}
		PlaySoundToTeam(PIRATES, FLAGCAP_TEAM);
		PlaySoundToTeam(VIKINGS, FLAGCAP_OPP);
		PlaySoundToTeam(KNIGHTS, FLAGCAP_OPP);
		RespawnFlagStr(iName, client);
	}
	return Plugin_Handled;
}
public Action:OnStartTouchCapZone_Vikings(entity, client)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	new String:iName[32];
	
	GetEntPropString(client, Prop_Data, "m_iName", iName, sizeof(iName));
	new iTeam = GetEntProp(client, Prop_Data, "m_iTeamNum");
	
	if (StrContains(iName, "Flag_Carrier", false) == 0 && iTeam == VIKINGS && !bTeamHasWon)
	{
		if (!bWaitingForPlayers)
			iPoints_Vikings++;
		if (iPoints_Vikings == iMaxCaptures)
		{
			bTeamHasWon = true;
			PrintCenterTextAll("Vikings win!");
			OnGameWon();
			EmitSoundToAll("music/vikingswin.mp3");
			CreateTimer(18.0, RoundRestart_Timer);
		}
		else
		{
			decl String:iTeamName[32];
			GetFlagVictim(client, iTeamName, sizeof(iTeamName));
			PrintCenterTextAll("Vikings captured the %s' flag!", iTeamName);
		}
		PlaySoundToTeam(PIRATES, FLAGCAP_OPP);
		PlaySoundToTeam(VIKINGS, FLAGCAP_TEAM);
		PlaySoundToTeam(KNIGHTS, FLAGCAP_OPP);
		RespawnFlagStr(iName, client);
	}
	return Plugin_Handled;
}
public Action:OnStartTouchCapZone_Knights(entity, client)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	new String:iName[32];
	
	GetEntPropString(client, Prop_Data, "m_iName", iName, sizeof(iName));
	new iTeam = GetEntProp(client, Prop_Data, "m_iTeamNum");
	
	if (StrContains(iName, "Flag_Carrier", false) == 0 && iTeam == KNIGHTS && !bTeamHasWon)
	{
		if (!bWaitingForPlayers)
			iPoints_Knights++;
		if (iPoints_Knights == iMaxCaptures)
		{
			bTeamHasWon = true;
			PrintCenterTextAll ("Knights win!");
			OnGameWon();
			EmitSoundToAll("music/knightswin.mp3");
			CreateTimer(13.0, RoundRestart_Timer);
		}
		else
		{
			decl String:iTeamName[32];
			GetFlagVictim(client, iTeamName, sizeof(iTeamName));
			PrintCenterTextAll("Knights captured the %s' flag!", iTeamName);
		}
		PlaySoundToTeam(PIRATES, FLAGCAP_OPP);
		PlaySoundToTeam(VIKINGS, FLAGCAP_OPP);
		PlaySoundToTeam(KNIGHTS, FLAGCAP_TEAM);
		RespawnFlagStr(iName, client);
	}
	return Plugin_Handled;
}

FlagPickup(client, iTeamNum, iFlagTeam)
{
	if (!IsValidClient(client))
		return;
	decl String:TargetName[32];
	new unaffectedTeam;
	for (new i = PIRATES; i <= KNIGHTS; i++)
		if (i != iFlagTeam + 2 && i != iTeamNum)
			unaffectedTeam = i;
	
	switch (iFlagTeam)
	{
		case iPirates:
			TargetName = PIRATECARRIER;
		case iVikings:
			TargetName = VIKINGCARRIER;
		case iKnights:
			TargetName = KNIGHTCARRIER;
	}
	if (FlagRespawnTimer[iFlagTeam] != INVALID_HANDLE)
	{
		CloseHandle(FlagRespawnTimer[iFlagTeam]);
		FlagRespawnTimer[iFlagTeam] = INVALID_HANDLE;
	}
	
	DispatchKeyValue(client, "targetname", TargetName);
	SetVariantString(TargetName);
	AcceptEntityInput(iFlagTarget[iFlagTeam], "SetParent");
	SetVariantString("eyes");
	AcceptEntityInput(iFlagTarget[iFlagTeam], "SetParentAttachment");
	TeleportEntity(iFlagTarget[iFlagTeam], flagOffset, flagAngOffset, NULL_VECTOR);
	TeleportEntity(iFlagModel[iFlagTeam], NULL_VECTOR, VectorZero, NULL_VECTOR);
	AcceptEntityInput(iFlagTrigger[iFlagTeam], "Disable");
	EmitSoundToClient(client, "ctf/voc_you_flag.wav");
	PlaySoundToTeam(iTeamNum, VOC_TEAM_FLAG, client);
	PlaySoundToTeam(iFlagTeam + 2, VOC_ENEMY_FLAG);
	PlaySoundToTeam(iFlagTeam + 2, FLAGTAK_TEAM);
	PlaySoundToTeam(unaffectedTeam, FLAGTAK_OPP);
	
	decl String:iTeamName[16];
	GetFlagVictim(client, iTeamName, sizeof(iTeamName));
	PrintCenterTextOmit(client, "%s' flag taken!", iTeamName);
	PrintCenterText(client, "You have the %s' flag!", iTeamName);
}

public Action:OnStartTouch_Pirates(entity, client)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
	
	new iTeam = GetEntProp(client, Prop_Data, "m_iTeamNum");
	new String:iName[32];
	GetEntPropString(client, Prop_Data, "m_iName", iName, sizeof(iName));
	new bool:hasFlag = false;
	if (StrContains(iName, "Flag_Carrier", false) == 0)
		hasFlag = true;	
	if (iTeam != PIRATES && IsPlayerAlive(client) && !hasFlag)
		FlagPickup(client, iTeam, iPirates);
	else if (iTeam != PIRATES)
		PrintCenterText(client, "You're already carrying a flag!");

	return Plugin_Handled;
}

public Action:OnStartTouch_Vikings(entity, client)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
	
	new iTeam = GetEntProp(client, Prop_Data, "m_iTeamNum");
	new String:iName[32];
	GetEntPropString(client, Prop_Data, "m_iName", iName, sizeof(iName));
	new bool:hasFlag = false;
	if (StrContains(iName, "Flag_Carrier", false) == 0)
		hasFlag = true;
	if (iTeam != VIKINGS && IsPlayerAlive(client) && !hasFlag)
		FlagPickup(client, iTeam, iVikings);
	else if (iTeam != VIKINGS)
		PrintCenterText(client, "You're already carrying a flag!");

	return Plugin_Handled;
}

public Action:OnStartTouch_Knights(entity, client)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
	
	new iTeam = GetEntProp(client, Prop_Data, "m_iTeamNum");
	new String:iName[32];
	GetEntPropString(client, Prop_Data, "m_iName", iName, sizeof(iName));
	new bool:hasFlag = false;
	if (StrContains(iName, "Flag_Carrier", false) == 0)
		hasFlag = true;
	if (iTeam != KNIGHTS && IsPlayerAlive(client) &&!hasFlag)
		FlagPickup(client, iTeam, iKnights);
	else if (iTeam != KNIGHTS)
		PrintCenterText(client, "You're already carrying a flag!");

	return Plugin_Handled;
}

PrintCenterTextOmit(omitClient, const String:format[], any:...)
{
	new length = strlen(format) + 255;
	decl String:formattedString[length];
	VFormat(formattedString, length, format, 3);  
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && i != omitClient)
			PrintCenterText(i, formattedString);
	}
}

PlaySoundToTeam(iTeam, String:sample[], omitClient=0)
{
	for (new i = 1; i <= MaxClients; i++)
		if (IsValidClient(i) && i != omitClient && GetEntProp(i, Prop_Data, "m_iTeamNum") == iTeam)
			EmitSoundToClient(i, sample);
}

public Action:WaitForPlayers_Timer(Handle:Timer)
{
	hWaitingForPlayers = INVALID_HANDLE;
	
	PrintCenterTextAll("Round restarting");
	
	SetDefaults();
	bWaitingForPlayers = false;
	bGameStart = true;
	
	for (new i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
		{
			ClearPlayer(i);
			SDKCall(hSpawn, i);
		}
	
	for (new i = 0; i < iTeamMax; i++)
	{
		if (FlagActiveTimer[i] != INVALID_HANDLE)
		{
			CloseHandle(FlagActiveTimer[i]);
			FlagActiveTimer[i] = INVALID_HANDLE;
		}
		if (FlagRespawnTimer[i] != INVALID_HANDLE)
		{
			CloseHandle(FlagRespawnTimer[i]);
			FlagRespawnTimer[i] = INVALID_HANDLE;
		}
		RespawnFlag(i);
	}
	
	return Plugin_Handled;
}

public OnClientPutInServer(client)
{
	if (isCTFRunning)
		CreateTimer(0.1, HUD_Timer, client, TIMER_REPEAT);
}
public OnClientDisconnect(client) 
{
	ClearPlayer(client);
	UpdateWaitState(-1, client);
}
public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) { ClearPlayer(GetClientOfUserId(GetEventInt(event, "userid"))); }

UpdateWaitState(newTeam=-1, client=0)
{
	if (isCTFRunning)
	{
		new TeamsWithPlayers = 0;
		new bool:TeamHasPlayers[iTeamMax];
		
		for (new c = 1; c <= MaxClients; c++)
		{
			if (IsClientInGame(c))
			{
				new iTeam;
				if (c == client)
					iTeam = newTeam;
				else
					iTeam = GetEntProp(c, Prop_Data, "m_iTeamNum");
				if (iTeam > SPECTATORS && iTeam <= KNIGHTS)
					TeamHasPlayers[iTeam - 2] = true;
			}
		}
		for (new i = 0; i < iTeamMax; i++)
		{
			if (TeamHasPlayers[i])
				TeamsWithPlayers++;
		}
		if (TeamsWithPlayers <= 1)
		{
			bWaitingForPlayers = true;
			if (hWaitingForPlayers != INVALID_HANDLE)
				CloseHandle(hWaitingForPlayers);
			hWaitingForPlayers = INVALID_HANDLE;
		}
		if (bWaitingForPlayers && hWaitingForPlayers == INVALID_HANDLE && TeamsWithPlayers > 1)
			hWaitingForPlayers = CreateTimer(20.0, WaitForPlayers_Timer);
	}
}

public Action:Event_ChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new newTeam = GetEventInt(event, "newteam");
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	UpdateWaitState(newTeam, client);
	
	return Plugin_Handled;
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (isCTFRunning)
	{
		new TeamsWithPlayers = 0;
		new bool:TeamHasPlayers[iTeamMax];
			
		for (new c = 1; c <= MaxClients; c++)
		{
			if (IsClientInGame(c))
			{				
				new iTeam = GetEntProp(c, Prop_Data, "m_iTeamNum");
				if (iTeam > SPECTATORS && iTeam <= KNIGHTS)
					TeamHasPlayers[iTeam - 2] = true;
				if (bGameStart)
				{
					new iClass = GetEntProp(c, Prop_Data, "m_iClassRespawningAs");
					new Handle:datapack;
					CreateDataTimer(GetRandomFloat(1.0, 4.0), RoundStartCheer_Timer, datapack);
					WritePackCell(datapack, c);
					WritePackCell(datapack, iTeam);
					WritePackCell(datapack, iClass);
				}
			}
		}
		for (new i = 0; i < iTeamMax; i++)
		{
			if (TeamHasPlayers[i])
				TeamsWithPlayers++;
		}
		if (TeamsWithPlayers <= 1)
			PrintCenterText(client, "Waiting for players to board the server");
		
		bGameStart = false;
	}
	
	if (bRoundEnd && isCTFRunning)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client))
			SetEntityMoveType(client, MOVETYPE_NONE);
	}
}

//Doesn't seem to work. Look for other possible methods.
public Action:Event_GameEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!bGameEnd)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public ConVar_MaxCaptures(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	if (StringToInt(newVal) > 0)
	{
		iCurrentMaxCaptures = StringToInt(newVal);
		
		PrintToServer("[CTF]Changes will take effect on round restart.");
		PrintToChatAll("[CTF]Capture Limit has been updated to %d.\n[CTF]Changes will take effect on round restart.", iCurrentMaxCaptures);
	}
}

public ConVar_RestartRound(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	new Float:fVal = StringToFloat(newVal);
	if (fVal > 0.0)
	{
		PrintCenterTextAll("Round restarting in %d seconds.", StringToInt(newVal));
		CreateTimer(fVal, RoundRestart_Timer);
		SetConVarFloat(cvar, 0.0);
	}
}

public OnPluginStart()
{
	AddCommandListener(CMDListener, "dropitem");
	
	//cvarEnabledOnBT = CreateConVar("ctf_runonbooty", "0", "Enables or disables Capture the Flag on booty maps. (Default 0)");
	cvarEnabledOnBT = CreateConVar("ctf_runonbooty", "0", "Not yet implemented.");
	cvarCapVoteLimit = CreateConVar("ctf_vote_capturelimit", "0.60", "percent required for capture limit vote.", 0, true, 0.05, true, 1.0);
	cvarMaxCaptures = CreateConVar("ctf_capturelimit", "10", "The number of captures required to win.", 0, true, 1.0);
	cvarAllowCaptureVote = CreateConVar("ctf_runonbooty", "1", "Not yet implemented.");
	cvarRestartRound = FindConVar("mp_restartround");
	
	hGameConfig = LoadGameConfigFile("capturetheflag.gamedata");
	
	if (hGameConfig == INVALID_HANDLE)
		SetFailState("Failed to load capturetheflag.gamedata.txt!");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConfig, SDKConf_Virtual, "Spawn");
	hSpawn = EndPrepSDKCall();
	
	if (hSpawn == INVALID_HANDLE)
		SetFailState("Failed to load virtual offset... Spirrwell, what did you do?");
	
	AddFileToDownloadsTable("sound/ctf/voc_you_flag.wav");
	AddFileToDownloadsTable("sound/ctf/voc_team_flag.wav");
	AddFileToDownloadsTable("sound/ctf/voc_enemy_flag.wav");
	
	AddFileToDownloadsTable("sound/ctf/flagcapture_opponent.wav");
	AddFileToDownloadsTable("sound/ctf/flagcapture_yourteam.wav");
	AddFileToDownloadsTable("sound/ctf/flagreturn_opponent.wav");
	AddFileToDownloadsTable("sound/ctf/flagreturn_yourteam.wav");
	AddFileToDownloadsTable("sound/ctf/flagtaken_opponent.wav");
	AddFileToDownloadsTable("sound/ctf/flagtaken_yourteam.wav");
}