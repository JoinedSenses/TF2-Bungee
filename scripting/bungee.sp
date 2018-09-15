#pragma semicolon 1
#include <sourcemod>
#include <tf2_stocks>
#include <smlib/entities>
#include <smlib/math>
#pragma newdecls required
#define PLUGIN_VERSION "1.0.3"

float
	  g_fRopePoint[MAXPLAYERS+1][2][3]
	, g_fRopeDistance[MAXPLAYERS+1][2]
	, g_fHookedEntLastLoc[MAXPLAYERS+1][2][3];
int
	  g_iRopeHookedEnt[MAXPLAYERS+1][2]
	, g_iBeamSprite
	, g_iHaloSprite
	, g_iBeamRed[] = {255, 19, 19, 255}
	, g_iBeamBlue[] = {19, 19, 255, 255}
	, g_iBeamCustom[MAXPLAYERS+1][4];
bool
	  g_bDoHook
	, g_bCanRope[MAXPLAYERS+1][2]
	, g_bWaitCheck[2]
	, g_bWaitPeriodOver
	, g_bRoping[MAXPLAYERS+1][2]
	, g_bCustomColor[MAXPLAYERS+1]
	, g_bLateLoad;
ConVar
	  cvarRopeLength
	, cvarHeightOffset
	, cvarRopeExtend
	, cvarRopePower
	, cvarClassReq
	, cvarRopeDisOffset
	, cvarContractBoost
	, cvarGroundRes
	, cvarAdminReq;

public Plugin myinfo = {
	name = "Spy-derman",
	author = "CrancK",
	description = "Be the one and only spy-derman",
	version = PLUGIN_VERSION,
	url = "https://github.com/JoinedSenses"
};

public void OnPluginStart() {
	RegConsoleCmd("+bungee", Command_Bungee);
	RegConsoleCmd("-bungee", Command_UnBungee);
	RegConsoleCmd("+bungee2", Command_Bungee2);
	RegConsoleCmd("-bungee2", Command_UnBungee2);
	RegConsoleCmd("sm_forcebungeestart", Command_ForceStart);
	RegConsoleCmd("sm_bcolor", Command_BColor);

	HookEvent("teamplay_round_start", RoundStart);
	HookEvent("teamplay_round_active", Event_RoundActive);
	HookEvent("teamplay_setup_finished",Event_Setup);
	HookEvent("teamplay_round_stalemate", RoundEnd);
	HookEvent("teamplay_round_win", RoundEnd);
	HookEvent("teamplay_game_over", RoundEnd);

	CreateConVar("sm_bungee_version", PLUGIN_VERSION, "Bungee Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	cvarRopeLength = CreateConVar("sm_bungee_length", "768.0", "maximum length per bungee", 0);
	cvarHeightOffset = CreateConVar("sm_bungee_heightoffset", "36.0", "...");
	cvarRopeExtend = CreateConVar("sm_bungee_extendfactor", "3.5", "...");
	cvarRopePower = CreateConVar("sm_bungee_power", "1.0", "...");
	cvarRopeDisOffset = CreateConVar("sm_bungee_disoffset", "0.0", "...");
	cvarContractBoost = CreateConVar("sm_bungee_contractboost", "1.01", "...");
	cvarGroundRes = CreateConVar("sm_bungee_groundresistance", "0.85", "...");
	cvarAdminReq = CreateConVar("sm_bungee_adminreq", "-1	", "0=generic, 1=custom3, -1=off");
	cvarClassReq = CreateConVar("sm_bungee_classreq", "spy", "name of class allowed to bungee");

	HookEntityOutput("trigger_teleport", "OnStartTouch", EntityOutput_OnTrigger);

	initialize();

	if (g_bLateLoad) {
		CreateTimer(3.0, timerLateLoad);
	}
}

Action timerLateLoad(Handle timer) {
		g_bWaitCheck[0] = true;
		g_bWaitCheck[1] = true;
		g_bWaitPeriodOver = true;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnMapStart() {
	initialize();
}

public void TF2_OnWaitingForPlayersEnd() {
	g_bWaitCheck[0] = true;
	if (g_bWaitCheck[0] && g_bWaitCheck[1]) {
		g_bWaitPeriodOver = true;
	}
	LogMessage("TF2_OnWaitingForPlayersEnd; waitCheck=[%d %d]", g_bWaitCheck[0], g_bWaitCheck[1]);
}

public Action RoundStart(Event event, const char[] name, bool dontBroadcast) {
	g_bWaitCheck[1] = false;
	g_bWaitPeriodOver = false;
}

public Action RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	g_bWaitCheck[1] = false;
	g_bWaitPeriodOver = false;
}

public Action Event_RoundActive(Event event, const char[] name, bool dontBroadcast) {
	int m_nSetupTimeLength = FindSendPropInfo("CTeamRoundTimer", "m_nSetupTimeLength");
	int i = -1;
	int team_round_timer = FindEntityByClassname(i, "team_round_timer");
	if (IsValidEntity(team_round_timer)) {
		if (GetEntData(team_round_timer, m_nSetupTimeLength) > 0) {
			g_bWaitCheck[1] = false;
		}
		else {
			g_bWaitCheck[1] = true;
			LogMessage("Event_RoundActive; waitCheck=[%d %d]", g_bWaitCheck[0], g_bWaitCheck[1]);
			if (g_bWaitCheck[0] && g_bWaitCheck[1]) {
				g_bWaitPeriodOver = true;
			}
		}
	}
}

public Action Event_Setup(Event event, const char[] name, bool dontBroadcast) {
	LogMessage("Event_Setup; waitCheck=[%d %d]", g_bWaitCheck[0], g_bWaitCheck[1]);
	g_bWaitCheck[1] = true;
	if (g_bWaitCheck[0] && g_bWaitCheck[1]) {
		g_bWaitPeriodOver = true;
	}
}

public void OnMapEnd() {
	g_bWaitCheck[0] = g_bWaitCheck[1] =  false;
	g_bWaitPeriodOver = false;
}

public Action Command_BColor(int client, int args) {
	if (client == 0) {
		ReplyToCommand(client, "[Bungee] Cannot use this command as console");
		return Plugin_Handled;
	}
	if (args == 0) {
		ReplyToCommand(client, "\x01[\x03Bungee\x01] Usage: sm_bcolor <hex>");
		return Plugin_Handled;
	}
	char hex[16];
	GetCmdArg(1, hex, sizeof(hex));
	if (strlen(hex) != 6) {
		ReplyToCommand(client, "\x01[\x03Bungee\x01] Error: expected hex string with 6 characters.");
		return Plugin_Handled;
	}
	
	int hexInt = StringToInt(hex, 16);
	int r,g,b;
	r = ((hexInt >> 16) & 0xFF);
	g = ((hexInt >> 8) & 0xFF);
	b = ((hexInt >> 0) & 0xFF);
	
	g_iBeamCustom[client][0] = r;
	g_iBeamCustom[client][1] = g;
	g_iBeamCustom[client][2] = b;
	g_iBeamCustom[client][3] = 255;

	ReplyToCommand(client, "\x01[\x03Bungee\x01]    \x07%s%s\x01    | \x07%02X0000R: %i\x01 | \x0700%02X00G: %i\x01 | \x070000%02XB: %i", hex, hex, r, r, g, g, b, b);

	if (r < 10 && g < 10 && b < 10) {
		g_bCustomColor[client] = false;
		ReplyToCommand(client, "\x01[\x03Bungee\x01] Unable to use this value. At least one RGB value must be greater than 10");
		return Plugin_Handled;
	}

	g_bCustomColor[client] = true;

	return Plugin_Handled;
}

public void EntityOutput_OnTrigger(const char[] output, int caller, int activator, float delay) {
	if (!(0 < activator <= MaxClients)) {
		return;
	}
	char activatorClassName[128];
	GetEdictClassname(caller, activatorClassName, sizeof(activatorClassName));
	if (CheckClass(activator) && StrEqual(activatorClassName, "trigger_teleport")) {
		for (int i = 0; i < 2; i++) {
			if (g_bRoping[activator][i]) {
				g_bRoping[activator][i] = false;
				g_iRopeHookedEnt[activator][i] = -1;
				CreateTimer(0.1, i ? CanRope2 : CanRope1, activator);
				g_bCanRope[activator][i] = false;
			}
		}
	}
}

public Action CanRope1(Handle timer, Handle client) {
	g_bCanRope[client][0] = true;
	return Plugin_Handled;
}

public Action CanRope2(Handle timer, Handle client) {
	g_bCanRope[client][1] = true;
	return Plugin_Handled;
}

public Action Command_ForceStart(int client, int args) {
	g_bWaitCheck[0] = g_bWaitCheck[1] = true;
	g_bWaitPeriodOver = true;
	return Plugin_Handled;
}

public Action Command_Bungee(int client, int args) {
	if (CheckClass(client) && g_bCanRope[client][0] && g_bWaitPeriodOver) {
		int adminreq = GetConVarInt(cvarAdminReq);
		if (adminreq == -1 || IsUserAdmin(client, adminreq)) {
			float ori[3];
			float eyeOri[3];
			float ang[3];
			float eyeAng[3];

			GetClientAbsOrigin(client, ori);
			ori[2] += GetConVarFloat(cvarHeightOffset);
			GetClientEyePosition(client, eyeOri);
			GetClientAbsAngles(client, ang);
			GetClientEyeAngles(client, eyeAng);

			Handle tr = TR_TraceRayFilterEx(eyeOri, eyeAng, MASK_SHOT_HULL, RayType_Infinite, TraceRayHitAnyThing, client);
			if (TR_DidHit(tr)) {
				g_iRopeHookedEnt[client][0] = TR_GetEntityIndex(tr);
				bool go = true;
				if (IsValidEntity(g_iRopeHookedEnt[client][0])) {
					char entName[128];
					GetEntPropString(g_iRopeHookedEnt[client][0], Prop_Data, "m_iName", entName, sizeof(entName));
					if (!g_bDoHook) {
						if (StrContains(entName, "nohook") != -1) {
							go = false;
						}
					}
					else {
						go = (StrContains(entName, "dohook") != -1);
					}
				}
				if (go) {
					if (g_iRopeHookedEnt[client][0] > 0) {
						Entity_GetAbsOrigin(g_iRopeHookedEnt[client][0], g_fHookedEntLastLoc[client][0]);
					}
					else {
						g_iRopeHookedEnt[client][0] = -1;
					}
					TR_GetEndPosition(g_fRopePoint[client][0], tr);

					g_fRopeDistance[client][0] = GetVectorDistance(ori, g_fRopePoint[client][0]);

					if (g_fRopeDistance[client][0] > GetConVarFloat(cvarRopeLength)) {
						g_bRoping[client][0] = false;
					}
					else {
						g_fRopeDistance[client][0] += GetConVarFloat(cvarRopeDisOffset);
						g_bRoping[client][0] = true;
					}
				}
				delete tr;
			}
		}
	}
	return Plugin_Handled;
}

public Action Command_UnBungee(int client, int args) {
	if (CheckClass(client) && g_bWaitPeriodOver) {
		int adminreq = GetConVarInt(cvarAdminReq);
		if (adminreq == -1 || IsUserAdmin(client, adminreq)) {
			g_iRopeHookedEnt[client][0] = -1;
			g_bRoping[client][0] = false;
		}
	}
	return Plugin_Handled;
}

public Action Command_Bungee2(int client, int args) {
	if (CheckClass(client) && g_bCanRope[client][1] && g_bWaitPeriodOver) {
		int adminreq = GetConVarInt(cvarAdminReq);
		if (adminreq == -1 || IsUserAdmin(client, adminreq)) {
			float ori[3];
			float eyeOri[3];
			float ang[3];
			float eyeAng[3];

			GetClientAbsOrigin(client, ori);
			ori[2] += GetConVarFloat(cvarHeightOffset);
			GetClientEyePosition(client, eyeOri);
			GetClientAbsAngles(client, ang);
			GetClientEyeAngles(client, eyeAng);

			Handle tr = TR_TraceRayFilterEx(eyeOri, eyeAng, MASK_SHOT_HULL, RayType_Infinite, TraceRayHitAnyThing, client);

			if (TR_DidHit(tr)) {
				g_iRopeHookedEnt[client][1] = TR_GetEntityIndex(tr);
				bool go = true;
				if (IsValidEntity(g_iRopeHookedEnt[client][1])) {
					char entName[128];
					GetEntPropString(g_iRopeHookedEnt[client][1], Prop_Data, "m_iName", entName, sizeof(entName));

					if (!g_bDoHook) {
						if (StrContains(entName, "nohook") != -1) {
							go = false;
						}
					}
					else {
						go = (StrContains(entName, "dohook") != -1);
					}
				}
				if (go) {
					if (g_iRopeHookedEnt[client][1] > 0) {
						Entity_GetAbsOrigin(g_iRopeHookedEnt[client][1], g_fHookedEntLastLoc[client][1]);
					}
					else {
						g_iRopeHookedEnt[client][1] = -1;
					}

					TR_GetEndPosition(g_fRopePoint[client][1], tr);
					g_fRopeDistance[client][1] = GetVectorDistance(ori, g_fRopePoint[client][1]);

					if (g_fRopeDistance[client][1] > GetConVarFloat(cvarRopeLength)) {
						g_bRoping[client][1] = false;
					}
					else {
						g_fRopeDistance[client][1] += GetConVarFloat(cvarRopeDisOffset);
						g_bRoping[client][1] = true;
					}
				}
				delete tr;
			}
		}
	}
	return Plugin_Handled;
}

public Action Command_UnBungee2(int client, int args) {
	if (CheckClass(client) && g_bWaitPeriodOver) {
		int adminreq = GetConVarInt(cvarAdminReq);
		if (adminreq == -1 || IsUserAdmin(client, adminreq)) {
			g_iRopeHookedEnt[client][1] = -1;
			g_bRoping[client][1] = false;
		}
	}
	return Plugin_Handled;
}

public void OnGameFrame() {
	if (g_bWaitPeriodOver) {
		float extend = cvarRopeExtend.FloatValue;
		float power = cvarRopePower.FloatValue;
		float height = cvarHeightOffset.FloatValue;
		float boost = cvarContractBoost.FloatValue;
		float groundRes = cvarGroundRes.FloatValue;

		for (int i = 1; i < MaxClients; i++) {
			if (IsClientInGame(i) && !IsFakeClient(i) && IsPlayerAlive(i) && (g_bRoping[i][0] || g_bRoping[i][1])) {
				if (g_bRoping[i][0] || g_bRoping[i][1]) {
					float ori[3];
					float vel[3];
					float dis[2] = { -1.0, -1.0 };
					float tempVec[2][3];
					bool go[2];
					
					GetClientAbsOrigin(i, ori);
					ori[2] += height;

					Entity_GetAbsVelocity(i, vel);

					for (int j = 0; j < 2; j++) {
						if (g_bRoping[i][j] && IsValidEntity(g_iRopeHookedEnt[i][j])) {
							float tempLoc[3];
							Entity_GetAbsOrigin(g_iRopeHookedEnt[i][j], tempLoc);
							if (!Math_VectorsEqual(g_fHookedEntLastLoc[i][j], tempLoc)) {
								float tempDiff[3];
								SubtractVectors(tempLoc, g_fHookedEntLastLoc[i][j], tempDiff);
								AddVectors(g_fRopePoint[i][j], tempDiff, g_fRopePoint[i][j]);
								for (int k = 0; k < 3; k++) {
									g_fHookedEntLastLoc[i][j][k] = tempLoc[k];
								}
							}
						}
						dis[j] = GetVectorDistance(ori, g_fRopePoint[i][j]);
					}
					for (int j = 0; j < 2; j++) {
						if ((extend == -1.0 || dis[j] < g_fRopeDistance[i][j]*extend) && g_bRoping[i][j] && dis[j] != -1.0) {
							if (dis[j] > g_fRopeDistance[i][j]) {
								SubtractVectors(g_fRopePoint[i][j], ori, tempVec[j]);
								NormalizeVector(tempVec[j], tempVec[j]);

								float tempDis = dis[j]-g_fRopeDistance[i][j];
								ScaleVector(tempVec[j], tempDis);

								if (power != 1.0) {
									ScaleVector(tempVec[j], power);
								}
								if (GetEntityFlags(i) & FL_ONGROUND) {
									ScaleVector(tempVec[j], groundRes);
								}
								go[j] = true;
							}
							BeamIt(i, ori, j);
						}
						else {
							g_bRoping[i][j] = false;
						}
					}
					if (go[0] && go[1]) {
						AddVectors(tempVec[0], tempVec[1], tempVec[0]);
						if (boost != 1.0) {
							ScaleVector(vel, boost);
						}
						AddVectors(tempVec[0], vel, vel);
						Entity_SetAbsVelocity(i, vel);
					}
					else if (go[0] && !go[1]) {
						if (boost != 1.0) {
							ScaleVector(vel, boost);
						}
						AddVectors(tempVec[0], vel, vel);
						Entity_SetAbsVelocity(i, vel);
					}
					else if (!go[0] && go[1]) {
						if (boost != 1.0) {
							ScaleVector(vel, boost);
						}
						AddVectors(tempVec[1], vel, vel);
						Entity_SetAbsVelocity(i, vel);
					}
				}
			}
		}
	}
}

bool TraceRayHitAnyThing(int entity, int mask, any startent) {
	return (entity != startent);
}

void initialize() {
	for (int i = 1; i < MaxClients; i++) {
		for (int j = 0; j < 2; j++) {
			g_bCanRope[i][j] = true;
			g_fRopeDistance[i][j] = 0.0;
			g_bRoping[i][j] = false;
			g_iRopeHookedEnt[i][j] = -1;

			for (int k = 0; k < 3; k++) {
				g_fRopePoint[i][j][k] = 0.0;
				g_fHookedEntLastLoc[i][j][k] = -1.0;
			}
		}
	}
	g_iBeamSprite = PrecacheModel("materials/sprites/laser.vmt");
	g_iHaloSprite = PrecacheModel("materials/sprites/halo01.vmt");
	g_bWaitCheck[0] = g_bWaitCheck[1] = false;
	g_bWaitPeriodOver = false;
	CheckHook();
}

void CheckHook() {
	g_bDoHook = false;
	int iTarget = -1;
	char entName[128];
	while ((iTarget = FindEntityByClassname(iTarget, "info_target")) != -1) {
		GetEntPropString(iTarget, Prop_Data, "m_iName", entName, sizeof(entName));
		g_bDoHook = (StrContains(entName, "dohook")!=-1);
	}
	PrintToServer("Spy-derman: Map is in %s mode", g_bDoHook ? "dohook" : "nohook");
}

void BeamIt(int client, float ori[3], int nr) {
	int beamColor[4];
	beamColor = g_bCustomColor[client] ? g_iBeamCustom[client] : (GetClientTeam(client) == 2) ? g_iBeamRed : g_iBeamBlue;
	TE_SetupBeamPoints(ori, g_fRopePoint[client][nr], g_iBeamSprite, g_iHaloSprite, 0, 0, 0.1, 8.0, 4.0, 1, 0.0, beamColor, 30);
	TE_SendToAll();
}

bool IsUserAdmin(int client, int type = 0) {
	return GetAdminFlag(GetUserAdmin(client), type ? Admin_Custom3 : Admin_Generic);
}

bool CheckClass(int client) {
	if (!IsValidEntity(client)) {
		return false;
	}
	char sClass[32];
	cvarClassReq.GetString(sClass, sizeof(sClass));
	return (TF2_GetPlayerClass(client) == TF2_GetClass(sClass) || TF2_GetClass(sClass) == TFClass_Unknown);
}