#pragma semicolon 1
#include <sourcemod>
#include <tf2_stocks>
#include <smlib/entities>
#include <smlib/math>
#pragma newdecls required
#define PLUGIN_VERSION "1.0.2"

float
	ropePoint[MAXPLAYERS][2][3]
	, ropeDistance[MAXPLAYERS][2]
	, hookedEntLastLoc[MAXPLAYERS][2][3];
int
	ropeHookedEnt[MAXPLAYERS][2]
	, beamSprite
	, haloSprite;
bool
	dohook
	, canRope[MAXPLAYERS][2]
	, waitCheck[2] = { false, false }
	, waitPeriodOver
	, roping[MAXPLAYERS][2];
ConVar
	cvRopeLength
	, cvHeightOffset
	, cvRopeExtend
	, cvRopePower
	, cvClassReq
	, cvRopeDisOffset
	, cvContractBoost
	, cvGroundRes
	, cvAdminReq;

public Plugin myinfo = {
	name = "Spy-derman",
	author = "CrancK",
	description = "Be the one and only spy-derman",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart() {
	HookEvent("teamplay_round_start", RoundStart);
	HookEvent("teamplay_round_active", Event_RoundActive);
	HookEvent("teamplay_setup_finished",Event_Setup);
	HookEvent("teamplay_round_stalemate", RoundEnd);
	HookEvent("teamplay_round_win", RoundEnd);
	HookEvent("teamplay_game_over", RoundEnd);

	CreateConVar("sm_bungee_version", PLUGIN_VERSION, "Bungee Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	cvRopeLength = CreateConVar("sm_bungee_length", "768.0", "maximum length per bungee", 0);
	cvHeightOffset = CreateConVar("sm_bungee_heightoffset", "36.0", "...");
	cvRopeExtend = CreateConVar("sm_bungee_extendfactor", "3.5", "...");
	cvRopePower = CreateConVar("sm_bungee_power", "1.0", "...");
	cvRopeDisOffset = CreateConVar("sm_bungee_disoffset", "0.0", "...");
	cvContractBoost = CreateConVar("sm_bungee_contractboost", "1.01", "...");
	cvGroundRes = CreateConVar("sm_bungee_groundresistance", "0.85", "...");
	cvAdminReq = CreateConVar("sm_bungee_adminreq", "-1	", "0=generic, 1=custom3, -1=off");
	cvClassReq = CreateConVar("sm_bungee_classreq", "spy", "name of class allowed to bungee");

	RegConsoleCmd("+bungee", Command_Bungee);
	RegConsoleCmd("-bungee", Command_UnBungee);
	RegConsoleCmd("+bungee2", Command_Bungee2);
	RegConsoleCmd("-bungee2", Command_UnBungee2);
	RegConsoleCmd("sm_forcebungeestart", Command_ForceStart);
	HookEntityOutput("trigger_teleport", "OnStartTouch", EntityOutput_OnTrigger);

	initialize();
}

public void OnMapStart() {
	initialize();
}

public void TF2_OnWaitingForPlayersEnd() {
	waitCheck[0] = true;
	if (waitCheck[0] && waitCheck[1]) waitPeriodOver = true;
	LogMessage("TF2_OnWaitingForPlayersEnd; waitCheck=[%d %d]", waitCheck[0], waitCheck[1]);
}

public Action RoundStart(Event event, const char[] name, bool dontBroadcast) {
	waitCheck[1] = false;
	waitPeriodOver = false;
}

public Action RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	waitCheck[1] = false;
	waitPeriodOver = false;
}

public Action Event_RoundActive(Event event, const char[] name, bool dontBroadcast) {
	int m_nSetupTimeLength = FindSendPropInfo("CTeamRoundTimer", "m_nSetupTimeLength")
		, i = -1
		, team_round_timer = FindEntityByClassname(i, "team_round_timer");
	if (IsValidEntity(team_round_timer)) {
		if (GetEntData(team_round_timer,m_nSetupTimeLength) > 0) {
			waitCheck[1] = false;
		}
		else {
			waitCheck[1] = true;
			LogMessage("Event_RoundActive; waitCheck=[%d %d]", waitCheck[0], waitCheck[1]);
			if (waitCheck[0] && waitCheck[1]) waitPeriodOver = true;
		}
	}
}

public Action Event_Setup(Event event, const char[] name, bool dontBroadcast) {
	LogMessage("Event_Setup; waitCheck=[%d %d]", waitCheck[0], waitCheck[1]);
	waitCheck[1] = true;
	if (waitCheck[0] && waitCheck[1]) waitPeriodOver = true;
}

public void OnMapEnd() {
	waitCheck[0] = false;
	waitCheck[1] = false;
	waitPeriodOver = false;
}

public void EntityOutput_OnTrigger(const char[] output, int caller, int activator, float delay) {
	if (!(0 < activator <= MaxClients)) {
		return;
	}
	char activatorClassName[128];
	GetEdictClassname(caller, activatorClassName, sizeof(activatorClassName));
	if (CheckClass(activator) && StrEqual(activatorClassName, "trigger_teleport")) {
		for (int i = 0; i < 2; i++) {
			if (roping[activator][i]) {
				roping[activator][i] = false;
				ropeHookedEnt[activator][i] = -1;
				CreateTimer(0.1, i ? CanRope2 : CanRope1, activator);
				canRope[activator][i] = false;
			}
		}
	}
}

public Action CanRope1(Handle timer, Handle client) {
	canRope[client][0] = true;
	return Plugin_Handled;
}

public Action CanRope2(Handle timer, Handle client) {
	canRope[client][1] = true;
	return Plugin_Handled;
}

public Action Command_ForceStart(int client, int args) {
	waitCheck[0] = true;
	waitCheck[1] = true;
	waitPeriodOver = true;
	return Plugin_Handled;
}

public Action Command_Bungee(int client, int args) {
	if (CheckClass(client) && canRope[client][0] && waitPeriodOver) {
		int adminreq = GetConVarInt(cvAdminReq);
		if (adminreq==-1 || IsUserAdmin(client, adminreq)) {
			float
				ori[3]
				, eyeOri[3]
				, ang[3]
				, eyeAng[3];
			GetClientAbsOrigin(client, ori); ori[2] += GetConVarFloat(cvHeightOffset); GetClientEyePosition(client, eyeOri);
			GetClientAbsAngles(client, ang); GetClientEyeAngles(client, eyeAng);
			Handle tr;
			tr = TR_TraceRayFilterEx(eyeOri, eyeAng, MASK_SHOT_HULL, RayType_Infinite, TraceRayHitAnyThing, client);
			if (TR_DidHit(tr)) {
				ropeHookedEnt[client][0] = TR_GetEntityIndex(tr);
				bool go = true;
				if (IsValidEntity(ropeHookedEnt[client][0])) {
					char entName[128];
					GetEntPropString(ropeHookedEnt[client][0], Prop_Data, "m_iName", entName, sizeof(entName));
					if (!dohook) {
						if (StrContains(entName, "nohook")!=-1) go = false;
					}
					else {
						go = (StrContains(entName, "dohook")!=-1);
					}
				}
				if (go) {
					if (ropeHookedEnt[client][0] > 0)
						Entity_GetAbsOrigin(ropeHookedEnt[client][0], hookedEntLastLoc[client][0]);
					else
						ropeHookedEnt[client][0] = -1;
					TR_GetEndPosition(ropePoint[client][0], tr);

					ropeDistance[client][0] = GetVectorDistance(ori, ropePoint[client][0]);
					if (ropeDistance[client][0] > GetConVarFloat(cvRopeLength)) {
						roping[client][0] = false;
					}
					else {
						ropeDistance[client][0] += GetConVarFloat(cvRopeDisOffset);
						roping[client][0] = true;
					}
				}
				delete tr;
			}
		}
	}
	return Plugin_Handled;
}

public Action Command_UnBungee(int client, int args) {
	if (CheckClass(client) && waitPeriodOver) {
		int adminreq = GetConVarInt(cvAdminReq);
		if (adminreq==-1 || IsUserAdmin(client, adminreq)) {
			ropeHookedEnt[client][0] = -1;
			roping[client][0] = false;
		}
	}
	return Plugin_Handled;
}

public Action Command_Bungee2(int client, int args) {
	if (CheckClass(client) && canRope[client][1] && waitPeriodOver) {
		int adminreq = GetConVarInt(cvAdminReq);
		if (adminreq == -1 || IsUserAdmin(client, adminreq)) {
			float ori[3], eyeOri[3], ang[3], eyeAng[3];
			GetClientAbsOrigin(client, ori); ori[2] += GetConVarFloat(cvHeightOffset); GetClientEyePosition(client, eyeOri);
			GetClientAbsAngles(client, ang); GetClientEyeAngles(client, eyeAng);
			Handle tr;
			tr = TR_TraceRayFilterEx(eyeOri, eyeAng, MASK_SHOT_HULL, RayType_Infinite, TraceRayHitAnyThing, client);
			if (TR_DidHit(tr)) {
				ropeHookedEnt[client][1] = TR_GetEntityIndex(tr);
				bool go = true;
				if (IsValidEntity(ropeHookedEnt[client][1])) {
					char entName[128];
					GetEntPropString(ropeHookedEnt[client][1], Prop_Data, "m_iName", entName, sizeof(entName));
					if (!dohook) {
						if (StrContains(entName, "nohook")!=-1)
							go = false;
					}
					else {
						go = (StrContains(entName, "dohook")!=-1);
					}
				}
				if (go) {
					if (ropeHookedEnt[client][1] > 0)
						Entity_GetAbsOrigin(ropeHookedEnt[client][1], hookedEntLastLoc[client][1]);
					else
						ropeHookedEnt[client][1] = -1;
					TR_GetEndPosition(ropePoint[client][1], tr);
					ropeDistance[client][1] = GetVectorDistance(ori, ropePoint[client][1]);
					if (ropeDistance[client][1] > GetConVarFloat(cvRopeLength)) {
						roping[client][1] = false;
					}
					else {
						ropeDistance[client][1] += GetConVarFloat(cvRopeDisOffset);
						roping[client][1] = true;
					}
				}
				delete tr;
			}
		}
	}
	return Plugin_Handled;
}

public Action Command_UnBungee2(int client, int args) {
	if (CheckClass(client) && waitPeriodOver) {
		int adminreq = GetConVarInt(cvAdminReq);
		if (adminreq == -1 || IsUserAdmin(client, adminreq)) {
			ropeHookedEnt[client][1] = -1;
			roping[client][1] = false;
		}
	}
	return Plugin_Handled;
}

public void OnGameFrame() {
	if (waitPeriodOver) {
		float
			extend = cvRopeExtend.FloatValue
			, power = cvRopePower.FloatValue
			, height = cvHeightOffset.FloatValue
			, boost = cvContractBoost.FloatValue
			, groundRes = cvGroundRes.FloatValue;

		for (int i = 1; i < MaxClients; i++) {
			if (IsClientInGame(i) && !IsFakeClient(i) && IsPlayerAlive(i) && (roping[i][0] || roping[i][1])) {
				if (roping[i][0] || roping[i][1]) {
					float
						ori[3]
						, vel[3]
						, dis[2] = { -1.0, -1.0 };
					GetClientAbsOrigin(i, ori); ori[2] += height;
					bool go[2] = { false, false };
					float tempVec[2][3];
					Entity_GetAbsVelocity(i, vel);

					for (int j = 0; j < 2; j++) {
						if (roping[i][j] && IsValidEntity(ropeHookedEnt[i][j])) {
							float tempLoc[3];
							Entity_GetAbsOrigin(ropeHookedEnt[i][j], tempLoc);
							if (!Math_VectorsEqual(hookedEntLastLoc[i][j], tempLoc)) {
								float tempDiff[3];
								SubtractVectors(tempLoc, hookedEntLastLoc[i][j], tempDiff);
								AddVectors(ropePoint[i][j], tempDiff, ropePoint[i][j]);
								hookedEntLastLoc[i][j][0] = tempLoc[0];
								hookedEntLastLoc[i][j][1] = tempLoc[1];
								hookedEntLastLoc[i][j][2] = tempLoc[2];
							}
						}
						dis[j] = GetVectorDistance(ori, ropePoint[i][j]);
					}
					for (int j = 0; j < 2; j++) {
						if ((extend == -1.0 || dis[j] < ropeDistance[i][j]*extend) && roping[i][j] && dis[j] != -1.0) {
							if (dis[j] > ropeDistance[i][j]) {
								SubtractVectors(ropePoint[i][j], ori, tempVec[j]);
								NormalizeVector(tempVec[j], tempVec[j]);
								float tempDis = dis[j]-ropeDistance[i][j];
								ScaleVector(tempVec[j], tempDis);
								if (power != 1.0) ScaleVector(tempVec[j], power);
								bool OnGround;
								if (GetEntityFlags(i) & FL_ONGROUND)
									OnGround = true;
								else
									OnGround = false;
								if (OnGround) ScaleVector(tempVec[j], groundRes);
								go[j] = true;
							}
							BeamIt(i, ori, j);
						}
						else {
							roping[i][j] = false;
						}
					}
					if (go[0] && go[1]) {
						AddVectors(tempVec[0], tempVec[1], tempVec[0]);
						if (boost != 1.0) ScaleVector(vel, boost);
						AddVectors(tempVec[0], vel, vel);
						Entity_SetAbsVelocity(i, vel);
					}
					else if (go[0] && !go[1]) {
						if (boost != 1.0)
							ScaleVector(vel, boost);
						AddVectors(tempVec[0], vel, vel);
						Entity_SetAbsVelocity(i, vel);
					}
					else if (!go[0] && go[1]) {
						if (boost != 1.0)
							ScaleVector(vel, boost);
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
		canRope[i][0] = true;
		canRope[i][1] = true;
		ropePoint[i][0][0] = 0.0;
		ropePoint[i][1][0] = 0.0;
		ropePoint[i][0][1] = 0.0;
		ropePoint[i][1][1] = 0.0;
		ropePoint[i][0][2] = 0.0;
		ropePoint[i][1][2] = 0.0;
		ropeDistance[i][0] = 0.0;
		ropeDistance[i][1] = 0.0;
		roping[i][0] = false;
		roping[i][1] = false;
		ropeHookedEnt[i][0] = -1;
		hookedEntLastLoc[i][0][0] = -1.0;
		hookedEntLastLoc[i][0][1] = -1.0;
		hookedEntLastLoc[i][0][2] = -1.0;
		ropeHookedEnt[i][1] = -1;
		hookedEntLastLoc[i][1][0] = -1.0;
		hookedEntLastLoc[i][1][1] = -1.0;
		hookedEntLastLoc[i][1][2] = -1.0;
	}
	beamSprite = PrecacheModel("materials/sprites/laser.vmt");
	haloSprite = PrecacheModel("materials/sprites/halo01.vmt");
	waitCheck[0] = false;
	waitCheck[1] = false;
	waitPeriodOver = false;
	CheckHook();
}

void CheckHook() {
	dohook = false;
	int iTarget = -1;
	char entName[128];
	while ((iTarget = FindEntityByClassname(iTarget, "info_target")) != -1) {
		GetEntPropString(iTarget, Prop_Data, "m_iName", entName, sizeof(entName));
		dohook = (StrContains(entName, "dohook")!=-1);
	}
	if (dohook)
		PrintToServer("Spy-derman: Map is in %s mode", dohook ? "dohook" : "nohook");
}

void BeamIt(int client, float ori[3], int nr) {
	TE_SetupBeamPoints(ori, ropePoint[client][nr], beamSprite, haloSprite, 0, 0, 0.1, 8.0, 4.0, 1, 0.0, (GetClientTeam(client) == 2) ? {255, 19, 19, 255} : {19, 19, 255, 255}, 30);
	TE_SendToAll();
}

bool IsUserAdmin(int client, int type = 0) {
	return GetAdminFlag(GetUserAdmin(client), type ? Admin_Custom3 : Admin_Generic);
}

bool CheckClass(int client) {
	if (!IsValidEntity(client))
		return false;
	char sClass[32];
	cvClassReq.GetString(sClass, sizeof(sClass));
	return (view_as<int>(TF2_GetPlayerClass(client)) == view_as<int>(TF2_GetClass(sClass)) || view_as<int>(TF2_GetClass(sClass)) == 0);
}