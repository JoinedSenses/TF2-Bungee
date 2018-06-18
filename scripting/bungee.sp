#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <smlib>
#pragma newdecls required
#define PLUGIN_VERSION "1.0.1"

float ropePoint[MAXPLAYERS][2][3], ropeDistance[MAXPLAYERS][2], hookedEntLastLoc[MAXPLAYERS][2][3];
int ropeHookedEnt[MAXPLAYERS][2], beamSprite, haloSprite;
bool dohook = false, canRope[MAXPLAYERS][2], waitCheck[2] = { false, false }, waitPeriodOver = false, roping[MAXPLAYERS][2];
Handle cvRopeLength = INVALID_HANDLE, cvHeightOffset = INVALID_HANDLE, cvRopeExtend = INVALID_HANDLE, cvRopePower = INVALID_HANDLE, cvClassReq = INVALID_HANDLE;
Handle cvRopeDisOffset = INVALID_HANDLE, cvContractBoost = INVALID_HANDLE, cvGroundRes = INVALID_HANDLE, cvAdminReq = INVALID_HANDLE;

public Plugin myinfo = {
	name = "Spy-derman",
	author = "CrancK",
	description = "Be the one and only spy-derman",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart() {
	HookEvent("teamplay_round_start", RoundStart);
	//HookEvent("teamplay_restart_round", RoundEnd);
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
	/*
	RegAdminCmd("+bungee", Command_Bungee, ADMFLAG_KICK);
	RegAdminCmd("-bungee", Command_UnBungee, ADMFLAG_KICK);
	RegAdminCmd("+bungee2", Command_Bungee2, ADMFLAG_KICK);
	RegAdminCmd("-bungee2", Command_UnBungee2, ADMFLAG_KICK);
	*/
	HookEntityOutput("trigger_teleport", "OnStartTouch", EntityOutput_OnTrigger);

	for (int i = 1; i < MaxClients; i++){
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
	//dohook = false;
	CheckHook();
}

public void OnMapStart(){
	for (int i=1;i<MaxClients;i++){
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
	//dohook = false;
	CheckHook();
}

public void TF2_OnWaitingForPlayersEnd(){
	waitCheck[0] = true;
	if (waitCheck[0] && waitCheck[1]) waitPeriodOver = true;
	LogMessage("TF2_OnWaitingForPlayersEnd; waitCheck=[%d %d]", waitCheck[0], waitCheck[1]);
}

public Action RoundStart(Event event, const char[] name, bool dontBroadcast){
	waitCheck[1] = false;
	waitPeriodOver = false;
}


public Action RoundEnd(Event event, const char[] name, bool dontBroadcast){
	waitCheck[1] = false;
	waitPeriodOver = false;
}

public Action Event_RoundActive(Event event, const char[] name, bool dontBroadcast){
	//When the round is active and players can move
	//If no setup time is found then game continues as usual
	int m_nSetupTimeLength = FindSendPropInfo("CTeamRoundTimer", "m_nSetupTimeLength");
	int i = -1;
	int team_round_timer = FindEntityByClassname(i, "team_round_timer");
	if (IsValidEntity(team_round_timer)){
		int setupTime = GetEntData(team_round_timer,m_nSetupTimeLength);
		if (setupTime > 0){
			//Yup this stage is in setup
			waitCheck[1] = false;
		}
		else {
			waitCheck[1] = true;
			LogMessage("Event_RoundActive; waitCheck=[%d %d]", waitCheck[0], waitCheck[1]);
			if (waitCheck[0] && waitCheck[1]) waitPeriodOver = true;
		}
	}
}

public Action Event_Setup(Event event, const char[] name, bool dontBroadcast){
	//Setup finished
	LogMessage("Event_Setup; waitCheck=[%d %d]", waitCheck[0], waitCheck[1]);
	waitCheck[1] = true;
	if (waitCheck[0] && waitCheck[1]) waitPeriodOver = true;
}


public void OnMapEnd(){
	waitCheck[0] = false;
	waitCheck[1] = false;
	waitPeriodOver = false;
}

public void EntityOutput_OnTrigger(const char[] output, int caller, int activator, float delay){
	//PrintToChatAll("activator = %i, caller = %i", activator, caller);
	//ShowActivity2(0, "\x04[DEBUG]", "\x01 Bungee teleport trigger, activator=%i, caller=%i", activator, caller);

	if (activator > 0 && activator <= MaxClients){
		char activatorClassName[128];
		GetEdictClassname(caller, activatorClassName, sizeof(activatorClassName));
			//ShowActivity2(0, "\x04[DEBUG]", "\x01 Bungee teleport trigger, caller is: %s", activatorClassName);
		if (CheckClass(activator) && StrEqual(activatorClassName, "trigger_teleport")){
			//PrintToServer("activator = client");
			//ShowActivity2(0, "\x04[DEBUG]", "\x01 Bungee teleport trigger, activator=client");

			if (roping[activator][0]){
				roping[activator][0] = false;
				ropeHookedEnt[activator][0] = -1;
				CreateTimer(0.1, CanRope1, activator);
				canRope[activator][0] = false;
			}
			if (roping[activator][1]){
				roping[activator][1] = false;
				ropeHookedEnt[activator][1] = -1;
				CreateTimer(0.1, CanRope2, activator);
				canRope[activator][1] = false;
			}
		}
	}
}

public Action CanRope1(Handle timer, Handle client){
	canRope[client][0] = true;
	return Plugin_Handled;
}

public Action CanRope2(Handle timer, Handle client){
	canRope[client][1] = true;
	return Plugin_Handled;
}

public Action Command_ForceStart(int client, int args){
	waitCheck[0] = true;
	waitCheck[1] = true;
	waitPeriodOver = true;
	return Plugin_Handled;
}

public Action Command_Bungee(int client, int args){
	//spy
	if (CheckClass(client) && canRope[client][0] && waitPeriodOver){
		int adminreq = GetConVarInt(cvAdminReq);
		if (adminreq==-1 || IsUserAdmin(client, adminreq)){
			float ori[3], eyeOri[3], ang[3], eyeAng[3];
			GetClientAbsOrigin(client, ori); ori[2] += GetConVarFloat(cvHeightOffset); GetClientEyePosition(client, eyeOri);
			GetClientAbsAngles(client, ang); GetClientEyeAngles(client, eyeAng);
			//new Handle:tr; tr = TR_TraceRayFilterEx(eyeOri, eyeAng, MASK_SOLID, RayType_Infinite, TraceRayHitAnyThing, client);
			Handle tr;
			tr = TR_TraceRayFilterEx(eyeOri, eyeAng, MASK_SHOT_HULL, RayType_Infinite, TraceRayHitAnyThing, client);
			if (TR_DidHit(tr)){
				ropeHookedEnt[client][0] = TR_GetEntityIndex(tr);
				bool go = true;
				if (IsValidEntity(ropeHookedEnt[client][0])){
					//ShowActivity2(client, "\x04[DEBUG]", "\x01 Bungee hooking begin");
					//new String:cName[128]; Entity_GetClassname(ropeHookedEnt[client][0], cName, sizeof(cName));
					char entName[128];
					GetEntPropString(ropeHookedEnt[client][0], Prop_Data, "m_iName", entName, sizeof(entName));
					if (!dohook){
						if (StrContains(entName, "nohook")!=-1) go = false;
						//ShowActivity2(client, "\x04[DEBUG]", "\x01 Bungee dohook=false");
					}
					else {
						if (StrContains(entName, "dohook")!=-1)
							go = true;
						else
							go = false;
						//ShowActivity2(client, "\x04[DEBUG]", "\x01 Bungee dohook=true");
					}
				}
				if (go){
					//ShowActivity2(client, "\x04[DEBUG]", "\x01 Bungee go=true");
					if (ropeHookedEnt[client][0] > 0)
						Entity_GetAbsOrigin(ropeHookedEnt[client][0], hookedEntLastLoc[client][0]);
					else
						ropeHookedEnt[client][0] = -1;
					TR_GetEndPosition(ropePoint[client][0], tr);

					ropeDistance[client][0] = GetVectorDistance(ori, ropePoint[client][0]);
					if (ropeDistance[client][0] > GetConVarFloat(cvRopeLength)){
						roping[client][0] = false;
						//ShowActivity2(client, "\x04[DEBUG]", "\x01 Bungee too long (%f); snapped", ropeDistance[client][0]);
					}
					else {
						ropeDistance[client][0] += GetConVarFloat(cvRopeDisOffset);
						roping[client][0] = true;
					}
				}
				CloseHandle(tr);
			}
		}
	}
	return Plugin_Handled;
}

public Action Command_UnBungee(int client, int args){
	if (CheckClass(client) && waitPeriodOver){
		int adminreq = GetConVarInt(cvAdminReq);
		if (adminreq==-1 || IsUserAdmin(client, adminreq)){
			ropeHookedEnt[client][0] = -1;
			roping[client][0] = false;
			//ShowActivity2(client, "\x04[DEBUG]", "\x01 Bungee unhooked");
		}
	}
	return Plugin_Handled;
}

public Action Command_Bungee2(int client, int args){
	//spy
	if (CheckClass(client) && canRope[client][1] && waitPeriodOver){
		int adminreq = GetConVarInt(cvAdminReq);
		if (adminreq==-1 || IsUserAdmin(client, adminreq)){
			float ori[3], eyeOri[3], ang[3], eyeAng[3];
			GetClientAbsOrigin(client, ori); ori[2] += GetConVarFloat(cvHeightOffset); GetClientEyePosition(client, eyeOri);
			GetClientAbsAngles(client, ang); GetClientEyeAngles(client, eyeAng);
			//new Handle:tr; tr = TR_TraceRayFilterEx(eyeOri, eyeAng, MASK_SOLID, RayType_Infinite, TraceRayHitAnyThing, client);
			Handle tr;
			tr = TR_TraceRayFilterEx(eyeOri, eyeAng, MASK_SHOT_HULL, RayType_Infinite, TraceRayHitAnyThing, client);
			if (TR_DidHit(tr) && IsValidEntity(TR_GetEntityIndex(tr))){
				ropeHookedEnt[client][1] = TR_GetEntityIndex(tr);
				bool go = true;
				if (IsValidEntity(ropeHookedEnt[client][1])){
					//ShowActivity2(client, "\x04[DEBUG]", "\x01 Bungee hooking begin");
					//new String:cName[128]; Entity_GetClassname(ropeHookedEnt[client][0], cName, sizeof(cName));
					char entName[128];
					GetEntPropString(ropeHookedEnt[client][1], Prop_Data, "m_iName", entName, sizeof(entName));
					if (!dohook){
						//ShowActivity2(client, "\x04[DEBUG]", "\x01 Bungee dohook=false");
						if (StrContains(entName, "nohook")!=-1)
							go = false;
					}
					else {
						//ShowActivity2(client, "\x04[DEBUG]", "\x01 Bungee dohook=true");
						if (StrContains(entName, "dohook")!=-1)
							go = true;
						else
							go = false;
					}
				}
				if (go){
					//ShowActivity2(client, "\x04[DEBUG]", "\x01 Bungee go=true");
					if (ropeHookedEnt[client][1] > 0)
						Entity_GetAbsOrigin(ropeHookedEnt[client][1], hookedEntLastLoc[client][1]);
					else
						ropeHookedEnt[client][1] = -1;
					TR_GetEndPosition(ropePoint[client][1], tr);
					ropeDistance[client][1] = GetVectorDistance(ori, ropePoint[client][1]);
					if (ropeDistance[client][1] > GetConVarFloat(cvRopeLength)){
						roping[client][1] = false;
						//ShowActivity2(client, "\x04[DEBUG]", "\x01 Bungee too long (%f); snapped", ropeDistance[client][1]);
					}
					else {
						ropeDistance[client][1] += GetConVarFloat(cvRopeDisOffset);
						roping[client][1] = true;
					}
				}
				CloseHandle(tr);
			}
		}
	}
	return Plugin_Handled;
}

public Action Command_UnBungee2(int client, int args){
	if (CheckClass(client) && waitPeriodOver){
		int adminreq = GetConVarInt(cvAdminReq);
		if (adminreq==-1 || IsUserAdmin(client, adminreq)){
			//ShowActivity2(client, "\x04[DEBUG]", "\x01 Bungee unhooked");
			ropeHookedEnt[client][1] = -1;
			roping[client][1] = false;
		}
	}
	return Plugin_Handled;
}

public void OnGameFrame(){
	if (waitPeriodOver){
		float extend = GetConVarFloat(cvRopeExtend), power = GetConVarFloat(cvRopePower), height = GetConVarFloat(cvHeightOffset);
		float boost = GetConVarFloat(cvContractBoost), groundRes = GetConVarFloat(cvGroundRes);

		for (int i = 1; i < MaxClients; i++){
			if (IsClientInGame(i) && !IsFakeClient(i) && IsPlayerAlive(i) && (roping[i][0] || roping[i][1])){
				if (roping[i][0] || roping[i][1]){
					float ori[3], vel[3], dis[2] = { -1.0, -1.0 };
					GetClientAbsOrigin(i, ori); ori[2] += height;
					bool go[2] = { false, false };
					float tempVec[2][3];
					Entity_GetAbsVelocity(i, vel); //Entity_GetAbsVelocity(i, vel[1]);

					if (roping[i][0]){
						//ShowActivity2(0, "\x04[DEBUG]", "\x01 Bungee OnGameFrame, orig [%.2f %.2f %.2f], ropePoint [%.2f %.2f %.2f]", ori[0], ori[1], ori[2], ropePoint[i][0][0], ropePoint[i][0][1], ropePoint[i][0][2]);
						if (ropeHookedEnt[i][0] != -1){
							float tempLoc[3];
							Entity_GetAbsOrigin(ropeHookedEnt[i][0], tempLoc);
							if (!Math_VectorsEqual(hookedEntLastLoc[i][0], tempLoc)){
								float tempDiff[3];
								SubtractVectors(tempLoc, hookedEntLastLoc[i][0], tempDiff);
								AddVectors(ropePoint[i][0], tempDiff, ropePoint[i][0]);
								hookedEntLastLoc[i][0][0] = tempLoc[0];
								hookedEntLastLoc[i][0][1] = tempLoc[1];
								hookedEntLastLoc[i][0][2] = tempLoc[2];
							}
						}
						dis[0] = GetVectorDistance(ori, ropePoint[i][0]);
						//ShowActivity2(0, "\x04[DEBUG]", "\x01 Bungee OnGameFrame, dist=%.2f", dis[0]);
					}
					if (roping[i][1]) {
						if (ropeHookedEnt[i][1] != -1){
							float tempLoc[3]; Entity_GetAbsOrigin(ropeHookedEnt[i][1], tempLoc);
							if (!Math_VectorsEqual(hookedEntLastLoc[i][1], tempLoc)){
								float tempDiff[3];
								SubtractVectors(tempLoc, hookedEntLastLoc[i][1], tempDiff);
								AddVectors(ropePoint[i][1], tempDiff, ropePoint[i][1]);
								hookedEntLastLoc[i][1][0] = tempLoc[0];
								hookedEntLastLoc[i][1][1] = tempLoc[1];
								hookedEntLastLoc[i][1][2] = tempLoc[2];
							}
						}
						dis[1] = GetVectorDistance(ori, ropePoint[i][1]);
					}
					for (int j = 0; j < 2; j++){
						if ((extend == -1.0 || dis[j] < ropeDistance[i][j]*extend) && roping[i][j] && dis[j] != -1.0){
							if (dis[j] > ropeDistance[i][j]){
								SubtractVectors(ropePoint[i][j], ori, tempVec[j]); //SubtractVectors(ori, ropePoint[i], tempVec);
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

								//TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, vel);
								go[j] = true;
								//PrintToChat(i, "roping");
							}
							BeamIt(i, ori, j);
						}
						else {
							roping[i][j] = false;
							//if (dis[j] != -1.0)
							//  ShowActivity2(0, "\x04[DEBUG]", "\x01 Bungee OnGameFrame snap: dist[%d]=%.2f < %.2f=ropeDistance[%d][%d]*%.2f, roping=%d", j, dis[j], ropeDistance[i][j]*extend, i, j, extend, roping[i][j]);
							//else
							//  ShowActivity2(0, "\x04[DEBUG]", "\x01 Bungee OnGameFrame dist[%d]=%f", j, dis[j]);
						}
					}
					if (go[0] && go[1]) {
						AddVectors(tempVec[0], tempVec[1], tempVec[0]);
						if (boost != 1.0) ScaleVector(vel, boost);
						AddVectors(tempVec[0], vel, vel);
						//ShowActivity2(0, "\x04[DEBUG]", "\x01 Bungee OnGameFrame, setting velocity of client %d to [%.2f %.2f %.2f]", i, vel[0], vel[1], vel[2]);
						//TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, vel);
						Entity_SetAbsVelocity(i, vel);
						//ShowActivity2(0, "\x04[DEBUG]", "\x01 Bungee OnGameFrame, velocity set successfully");
					}
					else if (go[0] && !go[1]){
						if (boost != 1.0)
							ScaleVector(vel, boost);
						AddVectors(tempVec[0], vel, vel);
						//ShowActivity2(0, "\x04[DEBUG]", "\x01 Bungee OnGameFrame, setting velocity of client %d to [%.2f %.2f %.2f]", i, vel[0], vel[1], vel[2]);
						//TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, vel);
						Entity_SetAbsVelocity(i, vel);
						//ShowActivity2(0, "\x04[DEBUG]", "\x01 Bungee OnGameFrame, velocity set successfully");
					}
					else if (!go[0] && go[1]){
						if (boost != 1.0)
							ScaleVector(vel, boost);
						AddVectors(tempVec[1], vel, vel);
						//ShowActivity2(0, "\x04[DEBUG]", "\x01 Bungee OnGameFrame, setting velocity of client %d to [%.2f %.2f %.2f]", i, vel[0], vel[1], vel[2]);
						//TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, vel);
						Entity_SetAbsVelocity(i, vel);
						//ShowActivity2(0, "\x04[DEBUG]", "\x01 Bungee OnGameFrame, velocity set successfully");
					}
				}
			}
		}
	}
}


public bool TraceRayHitAnyThing(int entity, int mask, any startent){
	if (entity == startent)
		return false;
	return true;
}

void CheckHook(){
	dohook = false;
	int iTarget = -1;
	char entName[128];
	while ((iTarget = FindEntityByClassname(iTarget, "info_target")) != -1){
		GetEntPropString(iTarget, Prop_Data, "m_iName", entName, sizeof(entName));
		if (StrContains(entName, "dohook")!=-1)
			dohook = true;
		else
			dohook = false;
		//PrintToServer("found info_target, with name %s", entName);
	}
	//if (iTarget == -1) dohook = false;
	if (dohook)
		PrintToServer("Spy-derman: Map is in dohook mode");
	else
		PrintToServer("Spy-derman: Map is in nohook mode");
}

void BeamIt(int client, float ori[3], int nr){
	TE_SetupBeamPoints(ori, ropePoint[client][nr], beamSprite, haloSprite, 0, 0, 0.1, 8.0, 4.0, 1, 0.0, GetClientTeam(client)==2?{255, 19, 19, 255}:{19, 19, 255, 255}, 30);
	TE_SendToAll();
}

bool IsUserAdmin(int client, int type = 0){
	bool IsAdmin;
	if (type==0)
		IsAdmin = GetAdminFlag(GetUserAdmin(client), Admin_Generic);
	else if (type==1)
		IsAdmin = GetAdminFlag(GetUserAdmin(client), Admin_Custom3);
	if (IsAdmin)
		return true;
	return false;
}

bool CheckClass(int client){
	if (!IsValidEntity(client))
		return false;
	int  iClass = view_as<int>(TF2_GetPlayerClass(client));
	char sClass[32];
	GetConVarString(cvClassReq, sClass, sizeof(sClass));
	int cvarClass = 0;
	if (StrEqual(sClass, "scout", false)) cvarClass = 1;
	else if (StrEqual(sClass, "sniper", false)) cvarClass = 2;
	else if (StrEqual(sClass, "soldier", false)) cvarClass = 3;
	else if (StrEqual(sClass, "demoman", false)) cvarClass = 4;
	else if (StrEqual(sClass, "medic", false)) cvarClass = 5;
	else if (StrEqual(sClass, "heavy", false)) cvarClass = 6;
	else if (StrEqual(sClass, "pyro", false)) cvarClass = 7;
	else if (StrEqual(sClass, "spy", false)) cvarClass = 8;
	else if (StrEqual(sClass, "engineer", false)) cvarClass = 9;

	if (iClass == cvarClass || cvarClass == 0) return true;

	return false;
}