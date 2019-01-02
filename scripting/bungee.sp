#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <smlib/entities>
#include <smlib/math>
#include <clientprefs>
#include <regex>
#include "color_literals.inc"

#pragma newdecls required

#define PLUGIN_VERSION "1.1.0"
#define PLUGIN_DESCRIPTION "Be the one and only spy-derman"

enum {
	BUNGEE1 = 0,
	BUNGEE2,
	MAXBUNGEECOUNT
}

float
	  g_fRopePoint[MAXPLAYERS+1][MAXBUNGEECOUNT][3]
	, g_fRopeDistance[MAXPLAYERS+1][MAXBUNGEECOUNT]
	, g_fHookedEntLastLoc[MAXPLAYERS+1][MAXBUNGEECOUNT][3];
int
	  g_iRopeHookedEnt[MAXPLAYERS+1][MAXBUNGEECOUNT]
	, g_iBeamSprite
	, g_iHaloSprite
	, g_iBeamRed[] = {255, 19, 19, 255}
	, g_iBeamBlue[] = {19, 19, 255, 255}
	, g_iBeamCustom[MAXPLAYERS+1][4];
bool
	  g_bDoHook
	, g_bCanRope[MAXPLAYERS+1][MAXBUNGEECOUNT]
	, g_bRoping[MAXPLAYERS+1][MAXBUNGEECOUNT]
	, g_bCustomColor[MAXPLAYERS+1];
ConVar
	  g_cvarRopeLength
	, g_cvarHeightOffset
	, g_cvarRopeExtend
	, g_cvarRopePower
	, g_cvarClassReq
	, g_cvarRopeDisOffset
	, g_cvarContractBoost
	, g_cvarGroundRes
	, g_cvarAdminReq;
Handle
	  g_hCookieBungee;
Regex
	  g_hRegexHex;

public Plugin myinfo = {
	name = "Spy-derman",
	author = "CrancK",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "https://github.com/JoinedSenses"
};

// ----------------- SM API

public void OnPluginStart() {
	RegConsoleCmd("+bungee", cmdBungee1);
	RegConsoleCmd("-bungee", cmdUnbungee1);
	RegConsoleCmd("+bungee2", cmdBungee2);
	RegConsoleCmd("-bungee2", cmdUnbungee2);
	RegConsoleCmd("sm_bcolor", cmdColor);

	CreateConVar("sm_bungee_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY).SetString(PLUGIN_VERSION);

	g_cvarRopeLength = CreateConVar("sm_bungee_length", "768.0", "maximum length per bungee", 0);
	g_cvarHeightOffset = CreateConVar("sm_bungee_heightoffset", "36.0", "...");
	g_cvarRopeExtend = CreateConVar("sm_bungee_extendfactor", "3.5", "...");
	g_cvarRopePower = CreateConVar("sm_bungee_power", "1.0", "...");
	g_cvarRopeDisOffset = CreateConVar("sm_bungee_disoffset", "0.0", "...");
	g_cvarContractBoost = CreateConVar("sm_bungee_contractboost", "1.01", "...");
	g_cvarGroundRes = CreateConVar("sm_bungee_groundresistance", "0.85", "...");
	g_cvarAdminReq = CreateConVar("sm_bungee_adminreq", "-1", "0=generic, 1=custom3, -1=off");
	g_cvarClassReq = CreateConVar("sm_bungee_classreq", "spy", "name of class allowed to bungee");

	g_hCookieBungee = RegClientCookie("Bungee_Color", "Bungee_Color", CookieAccess_Private);

	g_hRegexHex = new Regex("([A-Fa-f0-9]{6})");

	HookEntityOutput("trigger_teleport", "OnStartTouch", EntityOutput_OnTrigger);

	Initialize();

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && AreClientCookiesCached(i)) {
			OnClientCookiesCached(i);
		}
	}
}

public void OnClientConnected(int client) {
	g_bCustomColor[client] = false;
}

public void OnClientCookiesCached(int client) {
	GetCookieColor(client, g_iBeamCustom[client]);
}

public void OnMapStart() {
	Initialize();
}

public void OnGameFrame() {
	float extend = g_cvarRopeExtend.FloatValue;
	float power = g_cvarRopePower.FloatValue;
	float height = g_cvarHeightOffset.FloatValue;
	float boost = g_cvarContractBoost.FloatValue;
	float groundRes = g_cvarGroundRes.FloatValue;

	for (int i = 1; i < MaxClients; i++) {
		if (IsValidClient(i)) {
			bool active;
			for (int j = 0; j < MAXBUNGEECOUNT; j++) {
				if (g_bRoping[i][j]) {
					active = true;
					break;
				}
			}

			if (!active) {
				return;
			}

			float ori[3];
			float vel[3];
			float dis[MAXBUNGEECOUNT] = {-1.0, -1.0};
			float tempVec[MAXBUNGEECOUNT][3];
			bool go[MAXBUNGEECOUNT];

			GetClientAbsOrigin(i, ori);
			ori[2] += height;

			Entity_GetAbsVelocity(i, vel);

			for (int j = 0; j < MAXBUNGEECOUNT; j++) {
				if (g_bRoping[i][j] && IsValidEntity(g_iRopeHookedEnt[i][j])) {
					float tempLoc[3];
					Entity_GetAbsOrigin(g_iRopeHookedEnt[i][j], tempLoc);

					if (!Math_VectorsEqual(g_fHookedEntLastLoc[i][j], tempLoc)) {
						float tempDiff[3];
						SubtractVectors(tempLoc, g_fHookedEntLastLoc[i][j], tempDiff);
						AddVectors(g_fRopePoint[i][j], tempDiff, g_fRopePoint[i][j]);
						g_fHookedEntLastLoc[i][j] = tempLoc;
					}
				}

				dis[j] = GetVectorDistance(ori, g_fRopePoint[i][j]);

				if ((extend == -1.0 || dis[j] < g_fRopeDistance[i][j]*extend) && g_bRoping[i][j] && dis[j] != -1.0) {
					if (dis[j] > g_fRopeDistance[i][j]) {
						SubtractVectors(g_fRopePoint[i][j], ori, tempVec[j]);
						NormalizeVector(tempVec[j], tempVec[j]);

						float tempDis = dis[j] - g_fRopeDistance[i][j];
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

			if (go[BUNGEE1] && go[BUNGEE2]) {
				AddVectors(tempVec[BUNGEE1], tempVec[BUNGEE2], tempVec[BUNGEE1]);
				if (boost != 1.0) {
					ScaleVector(vel, boost);
				}
				AddVectors(tempVec[BUNGEE1], vel, vel);
				Entity_SetAbsVelocity(i, vel);
			}
			else if (go[BUNGEE1] && !go[BUNGEE2]) {
				if (boost != 1.0) {
					ScaleVector(vel, boost);
				}
				AddVectors(tempVec[BUNGEE1], vel, vel);
				Entity_SetAbsVelocity(i, vel);
			}
			else if (!go[BUNGEE1] && go[BUNGEE2]) {
				if (boost != 1.0) {
					ScaleVector(vel, boost);
				}
				AddVectors(tempVec[BUNGEE2], vel, vel);
				Entity_SetAbsVelocity(i, vel);
			}
		}
	}
}

// ----------------- Commands

public Action cmdBungee1(int client, int args) {
	Bungee(client, BUNGEE1);
	return Plugin_Handled;
}

public Action cmdUnbungee1(int client, int args) {
	Unbungee(client, BUNGEE1);
	return Plugin_Handled;
}

public Action cmdBungee2(int client, int args) {
	Bungee(client, BUNGEE2);
	return Plugin_Handled;
}

public Action cmdUnbungee2(int client, int args) {
	Unbungee(client, BUNGEE2);
	return Plugin_Handled;
}

public Action cmdColor(int client, int args) {
	if (client == 0) {
		PrintColoredChat(client, "[Bungee] Cannot use this command as console");
		return Plugin_Handled;
	}
	if (args == 0) {
		PrintColoredChat(client, "\x01[\x03Bungee\x01] Usage: sm_bcolor <hex>");
		return Plugin_Handled;
	}
	char hex[16];
	GetCmdArg(1, hex, sizeof(hex));

	if (!IsValidHex(hex)) {
		PrintColoredChat(client, "\x01[\x03Speedo\x01] Invalid hex value");
		return Plugin_Handled;
	}

	int rgba[4];
	HexStrToRGB(hex, rgba);

	int r = rgba[0];
	int g = rgba[1];
	int b = rgba[2];

	PrintColoredChat(client, "\x01[\x03Bungee\x01]  \x07%s%s\x01  | \x07%02X0000R: %i\x01 | \x0700%02X00G: %i\x01 | \x070000%02XB: %i", hex, hex, r, r, g, g, b, b);

	if (r < 10 && g < 10 && b < 10) {
		g_bCustomColor[client] = false;
		PrintColoredChat(client, "\x01[\x03Bungee\x01] Unable to use this value. At least one RGB value must be greater than 10");
		return Plugin_Handled;
	}

	g_iBeamCustom[client] = rgba;
	g_bCustomColor[client] = true;
	SetCookieColor(client, hex);
	return Plugin_Handled;
}

// ----------------- Hooks

public void EntityOutput_OnTrigger(const char[] output, int caller, int activator, float delay) {
	if (!(0 < activator <= MaxClients)) {
		return;
	}
	char activatorClassName[128];
	GetEdictClassname(caller, activatorClassName, sizeof(activatorClassName));
	if (CheckClass(activator) && StrEqual(activatorClassName, "trigger_teleport")) {
		for (int i = 0; i < MAXBUNGEECOUNT; i++) {
			if (g_bRoping[activator][i]) {
				g_bRoping[activator][i] = false;
				g_iRopeHookedEnt[activator][i] = -1;
				CreateTimer(0.1, i ? CanRope2 : CanRope1, activator);
				g_bCanRope[activator][i] = false;
			}
		}
	}
}

// ----------------- Timers

Action CanRope1(Handle timer, Handle client) {
	g_bCanRope[client][BUNGEE1] = true;
	return Plugin_Handled;
}

Action CanRope2(Handle timer, Handle client) {
	g_bCanRope[client][BUNGEE2] = true;
	return Plugin_Handled;
}

// ----------------- TraceRay Filter

bool TraceRayHitAnyThing(int entity, int mask, any startent) {
	return (entity != startent);
}

// ----------------- Cookies

void GetCookieColor(int client, int rgba[4]) {
	char hex[7];
	GetClientCookie(client, g_hCookieBungee, hex, sizeof(hex));
	if (hex[0] != '\0') {
		HexStrToRGB(hex, rgba);
		g_bCustomColor[client] = true;
	}
}

void SetCookieColor(int client, const char[] hex) {
	SetClientCookie(client, g_hCookieBungee, hex);
}

// ----------------- Internal Functions/Stocks

void Bungee(int client, int num) {
	if (CheckClass(client) && g_bCanRope[client][num]) {
		int adminreq = g_cvarAdminReq.IntValue;
		if (adminreq == -1 || IsUserAdmin(client, adminreq)) {
			float ori[3];
			float eyeOri[3];
			float ang[3];
			float eyeAng[3];

			GetClientAbsOrigin(client, ori);
			ori[2] += g_cvarHeightOffset.FloatValue;
			GetClientEyePosition(client, eyeOri);
			GetClientAbsAngles(client, ang);
			GetClientEyeAngles(client, eyeAng);

			Handle tr = TR_TraceRayFilterEx(eyeOri, eyeAng, MASK_SHOT_HULL, RayType_Infinite, TraceRayHitAnyThing, client);
			if (TR_DidHit(tr)) {
				g_iRopeHookedEnt[client][num] = TR_GetEntityIndex(tr);
				bool go = true;
				if (IsValidEntity(g_iRopeHookedEnt[client][num])) {
					char entName[128];
					GetEntPropString(g_iRopeHookedEnt[client][num], Prop_Data, "m_iName", entName, sizeof(entName));
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
					if (g_iRopeHookedEnt[client][num] > 0) {
						Entity_GetAbsOrigin(g_iRopeHookedEnt[client][num], g_fHookedEntLastLoc[client][num]);
					}
					else {
						g_iRopeHookedEnt[client][num] = -1;
					}
					TR_GetEndPosition(g_fRopePoint[client][num], tr);

					g_fRopeDistance[client][num] = GetVectorDistance(ori, g_fRopePoint[client][num]);

					if (g_fRopeDistance[client][num] > g_cvarRopeLength.FloatValue) {
						g_bRoping[client][num] = false;
					}
					else {
						g_fRopeDistance[client][num] += g_cvarRopeDisOffset.FloatValue;
						g_bRoping[client][num] = true;
					}
				}
				delete tr;
			}
		}
	}
}

void Unbungee(int client, int num) {
	if (CheckClass(client)) {
		int adminreq = g_cvarAdminReq.IntValue;
		if (adminreq == -1 || IsUserAdmin(client, adminreq)) {
			g_iRopeHookedEnt[client][num] = -1;
			g_bRoping[client][num] = false;
		}
	}	
}

void Initialize() {
	for (int i = 1; i < MaxClients; i++) {
		for (int j = 0; j < MAXBUNGEECOUNT; j++) {
			g_bCanRope[i][j] = true;
			g_fRopeDistance[i][j] = 0.0;
			g_bRoping[i][j] = false;
			g_iRopeHookedEnt[i][j] = -1;
			g_fRopePoint[i][j] = NULL_VECTOR;

			for (int k = 0; k < 3; k++) {
				g_fHookedEntLastLoc[i][j][k] = -1.0;
			}
		}
	}
	g_iBeamSprite = PrecacheModel("materials/sprites/laser.vmt");
	g_iHaloSprite = PrecacheModel("materials/sprites/halo01.vmt");
	CheckHook();
}

bool IsValidClient(int client) {
	return (IsClientInGame(client) && !IsFakeClient(client) && IsPlayerAlive(client));
}

bool IsValidHex(const char[] hex) {
	return (strlen(hex) == 6 && g_hRegexHex.Match(hex));
}

void HexStrToRGB(const char[] hexstr, int rgb[4]) {
	int hex = StringToInt(hexstr, 16);

	rgb[0] = ((hex >> 16) & 0xFF);
	rgb[1] = ((hex >>  8) & 0xFF);
	rgb[2] = ((hex >>  0) & 0xFF);
	rgb[3] = 255;
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
	return GetUserAdmin(client).HasFlag(type ? Admin_Custom3 : Admin_Generic);
}

bool CheckClass(int client) {
	if (!IsValidEntity(client)) {
		return false;
	}
	char sClass[32];
	g_cvarClassReq.GetString(sClass, sizeof(sClass));
	return (TF2_GetPlayerClass(client) == TF2_GetClass(sClass) || TF2_GetClass(sClass) == TFClass_Unknown);
}