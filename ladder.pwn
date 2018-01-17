// SAMP-IL Ladder Mode v2.0 - SA-MP.co.il
// by Amit `Amit_B` Barami
// Camera fly mode based on h02's idea & code
#include "a_samp.inc"
#include "a_http.inc"
#define strtok strtok2
#define string __string
#include "dini.inc"
#undef string
#undef strtok
// Defines:
#define version "2.0"
#define webactivefile "www.sa-mp.co.il/ladder/active.txt"
#define versionfile "www.sa-mp.co.il/ladder/version.txt"
#define MAX_LOBJECTS 200
#undef MAX_PLAYERS
#define MAX_PLAYERS 32
#define report_reason_of_22 2
#define MAX_PINGTESTS 60
#define FORBIDDEN_FS "SIAM"
#define MAX_AVERAGE_PING 65.0
#define MIN_IDLE_TIME 15
#define DEBUG
// Files / Folders:
#define ladderdir "/Ladder/"
#define laddertempdir ladderdir "Temp/"
#define laddermapsdir ladderdir "Maps/"
#define ladderfile ladderdir "Ladder.txt"
#define ladderlog ladderdir "LadderLog.txt"
#define laddergame ladderdir "LadderGame.txt"
// Teams:
#define INVALID_TEAM -1
#define TEAM_A 0
#define TEAM_B 1
#define TEAM_M 2
#define TEAM_V 3
#define MAX_TEAMS 4
#define FIGHT_TEAMS 2
// Funcs:
#define F_FIGHTER 1
#define F_ASSISTANT 2
#define F_SNIPER 3
#define FW_FIGHTER 26,28
#define FW_ASSISTANT 27,32
#define FW_SNIPER 31,34,29,24
// Colors:
#define white 0xFFFFFFFF
#define grey 0xAFAFAFFF
#define green 0x33AA33FF
#define red 0xAA3333FF
#define lightred 0xFF0000FF
#define yellow 0xFFFF00FF
#define blue 0x0000FFFF
#define lightblue 0x00FFFFFF
#define orange 0xFF9900FF
#define black 0x000000FF
#define C_white FFFFFF
#define C_grey AFAFAF
#define C_green 33AA33
#define C_red AA3333
#define C_lightred FF0000
#define C_yellow FFFF00
#define C_blue 0000FF
#define C_lblue 00FFFF
#define C_orange FF9900
#define C_black 000000
// Dialog:
#define DIALOG_NI 0
#define DIALOG_FUNCS 1
#define DIALOG_TCOLORS 2
// Score Status:
#define SCORE_KILLS 0
#define SCORE_DAMAGES 1
// Signboards:
#define SIGNBOARD_ADV 0
#define SIGNBOARD_FULL 1
#define SIGNBOARD_SCORE1 2
#define SIGNBOARD_SCORE2 3
// Camera Modes:
#define CAMERA_NONE 0
#define CAMERA_FLY 1
#define CAMERA_SPEC 2
// Directive Functions:
#define @c(%1) "{"#C_%1"}"
#define @header(%1) @c(blue) "- " @c(lblue) %1 @c(blue) " -"
#define @cmd(%1,%2) " * " @c(yellow) %1 @c(orange) " - " %2
new bool:F = false;
#define SendFormat(%1,%2,%3) SendClientMessage(%1,%2,(format(formatStr,sizeof(formatStr),%3), formatStr))
#define SendFormatToAll(%1,%2) SendClientMessageToAll(%1,(format(formatStr,sizeof(formatStr),%2), formatStr))
#define AddLog(%1,%2) do { new File:fh, d[3], t[3]; getdate(d[2],d[1],d[0]); gettime(t[2],t[1],t[0]); fh = fopen(ladderlog,io_append); fwrite(fh,(format(formatStr,sizeof(formatStr),"%02d/%02d/%d|%02d:%02d|" %1 "\r\n",d[0],d[1],d[2],t[2],t[1],%2), formatStr)); fclose(fh); } while(F)
#define UpdateLadderGameForTeam(%1,%2) if(%2 == 1) UpdateLadderGame(Team1%1); else UpdateLadderGame(Team2%1)
#pragma unused F
enum GameUpdateTypes { Active, Team1Name, Team2Name, Team1Color, Team2Color, Team1Score, Team2Score, Admins, Viewers, Players, TimeLeft };
enum TeamInfoEnum { tName[32], tColor, tScore, tAdmin, Text:tText }
new tinfo[MAX_TEAMS][TeamInfoEnum];
enum PlayerInfoEnum {
	pTeam, pFunc, pThisTeam, pThisFunc, pKills, pDeaths, pAdmin, pParam, pSpawned, pWeapon, pAmmo[2], p22Warns, pGW, pSpec, pPing[MAX_PINGTESTS],
	pPings, pSkin, pAskedPause, pJoypad, Float:pDamaged, Float:pAttacked, PlayerText:pHPStatus, pHPTimer, pKillingSpree[3], Text:pKSText, pIdle,
	pCBugCheck, pAFK, pFrozen, pV, pCamera[5], pFlyObject, Float:pMS }
new pinfo[MAX_PLAYERS][PlayerInfoEnum];
enum ClassInfoEnum { cText[32], cSkin, cDefSkin, cColor }
new classes[][ClassInfoEnum] =
{
	{"~g~Team A",271,271,2},
	{"~r~Team B",268,268,4},
	{"~w~Admin",163,163,0},
	{"~y~Viewer",165,165,7}
};
enum MapInfoEnum { mID, mName[32], mAuthor[32], mObject[MAX_LOBJECTS], mObjects, Float:mSpawnA[4], Float:mSpawnB[4], Float:mSpawnM[4], Float:mCSCP[3], Float:mCSPP[4], Float:mBounds[6] }
new map[MapInfoEnum];
enum EveryonesPositionData { Float:epX, Float:epY, Float:epZ, epID }
new bool:gameStarted = false;
new bool:pause = false;
new onlinePlayers = 0;
new cd[2] = {-1,0};
new timeLeft = 0;
new Text:timetd;
new currentGame = -1;
new bool:antiTK = false;
new bool:sawn22 = false;
new bool:cbug = true;
new bool:exited = false;
new bool:monitor = true;
new monitorFilter[32];
new timerDiving = 0;
new bool:loaded = false;
new skinKeys[][16] = {"TeamASkin","TeamBSkin","AdminSkin","ViewerSkin"};
new scoreStatus = SCORE_DAMAGES;
new formatStr[256];
new params[7][16];
new advText[64] = @c(blue) "SA-MP.co.il\n" @c(white) "Ladder v" version;
new currentBestKiller[2] = {INVALID_PLAYER_ID,0};
new fastStopReason[64];
new fastStop = 0;
new string[128];
new reportReasons[][32] =
{
	"����� ��'���� �� �����",
	"�����",
	"����� �2-2",
	"����� ��� ���������"
};
enum TeamColorsEnum { tcColor, tcHexStr[16], tcName[16] }
new teamColors[][TeamColorsEnum] =
{
	{blue,#C_blue,"����"},
	{lightblue,#C_lblue,"����"},
	{green,#C_green,"����"},
	{0x00FF00FF,#00FF00,"���� ����"},
	{red,#C_red,"����"},
	{lightred,#C_lightred,"���� ����"},
	{0xFF9B00FF,#FF9B00,"����"},
	{yellow,#C_yellow,"����"},
	{0x800080FF,#800080,"����"},
	{0xFF66FFFF,#FF66FF,"����"},
	{white,#C_white,"���"},
	{black,#C_black,"����"}
};
new FW[][4] = {{},{FW_FIGHTER},{FW_ASSISTANT},{FW_SNIPER}};
enum SignboardsEnum { sbModel, sbObject };
enum SignboardOptions { SB_Update, SB_Remove, SB_Create, SB_CheckIfValid };
new Signboards[][SignboardsEnum] = {{8332,INVALID_OBJECT_ID},{8331,INVALID_OBJECT_ID},{8331,INVALID_OBJECT_ID},{8331,INVALID_OBJECT_ID}};
main()
{
	print("\n----------------------------------");
	printf(" SAMP-IL (SA-MP.co.il) Ladder Mode by Amit_B - loaded%s",loaded ? (" successfully") : (", with errors"));
	print("----------------------------------\n");
}
public OnGameModeInit()
{
	#if defined DEBUG
		print("Load: 1");
	#endif
	new require[][32] = {ladderfile,laddergame,ladderdir,laddertempdir,laddermapsdir};
	#define Error(%1) (printf("ERROR: " %1), GameModeExit())
	for(new i = 0; i < sizeof(require); i++) if(!fexist(require[i])) return Error("Ladder %s (\"%s\") doesn't exist. Restarting...",require[i][0] == '/' ? ("directory") : ("file"),require[i]);
	if(!fexist(ladderlog)) fclose(fopen(ladderlog,io_write));
	if(!Map_Count()) return Error("There are no maps.");
	if(!Map_Exists(1)) return Error("First map (map ID 1, %s) doesn't exist.",laddermapsdir "1.ini");
	#if defined DEBUG
		print("Load: 2");
	#endif
	#undef Error
	print("Starting SAMP-IL Ladder Mode v" version);
	SetGameModeText("Ladder Mode " version " (SAMP-IL)");
	CheckForbiddenFS();
	SetTimer("Contents",1000,1);
	SetTimer("BackgroundWorker",666,1);
	ShowNameTags(1);
	ShowPlayerMarkers(0);
	SetWorldTime(8);
	SetWeather(3);
	SetTeamCount(MAX_TEAMS);
	DisableInteriorEnterExits();
	UsePlayerPedAnims();
	gameStarted = false;
	#if defined DEBUG
		print("Load: 3");
	#endif
	for(new i = 0, tdstr[64]; i < MAX_TEAMS; i++)
	{
		if(i == TEAM_M) format(tinfo[i][tName],32,"Admins");
		else if(i == TEAM_V) format(tinfo[i][tName],32,"Viewers");
		else format(tinfo[i][tName],32,"Team %d",i+1);
		tinfo[i][tColor] = teamColors[classes[i][cColor]][tcColor],
		tinfo[i][tScore] = 0,
		tinfo[i][tAdmin] = (i == TEAM_M);
		if(IsFightTeam(i))
		{
			format(tdstr,sizeof(tdstr),"%s ~l~- ~w~%d",tinfo[i][tName],tinfo[i][tScore]);
			tinfo[i][tText] = TextDrawCreate(146.000000,!i ? 387.000000 : 402.000000,tdstr);
			TextDrawBackgroundColor(tinfo[i][tText],255);
			TextDrawFont(tinfo[i][tText],1);
			TextDrawLetterSize(tinfo[i][tText],0.480000,1.400000);
			TextDrawColor(tinfo[i][tText],tinfo[i][tColor]);
			TextDrawSetOutline(tinfo[i][tText],1);
			TextDrawSetProportional(tinfo[i][tText],1);
		}
	}
	#if defined DEBUG
		print("Load: 4");
	#endif
	UpdateLadderGame(Active,Team1Name,Team2Name,Team1Color,Team2Color,Team1Score,Team2Score,Admins,Viewers,Players,TimeLeft);
	#if defined DEBUG
		print("Load: 5");
	#endif
	for(new i = 0; i < sizeof(classes); i++)
	{
		classes[i][cSkin] = dini_Int(ladderfile,skinKeys[i]);
		AddPlayerClassEx(IsFightTeam(i) ? i : NO_TEAM,classes[i][cSkin],1958.3782,1343.1572,15.3746,269.1424,0,0,0,0,0,0);
	}
	#if defined DEBUG
		print("Load: 6");
	#endif
	currentGame = dini_Int(ladderfile,"Games") + 1;
	dini_IntSet(ladderfile,"Games",currentGame);
	scoreStatus = dini_Int(ladderfile,"ScoreStatus");
	timetd = TextDrawCreate(578.0,8.0,"~n~---");
	TextDrawAlignment(timetd,2);
	TextDrawBackgroundColor(timetd,255);
	TextDrawFont(timetd,1);
	TextDrawLetterSize(timetd,0.400000,1.399999);
	TextDrawColor(timetd,-1);
	TextDrawSetOutline(timetd,1);
	TextDrawSetProportional(timetd,0);
	#if defined DEBUG
		print("Load: 7");
	#endif
	Map_Load(1);
	loaded = true;
	return 1;
}
public OnGameModeExit()
{
	TextDrawDestroy(timetd);
	TextDrawDestroy(tinfo[TEAM_A][tText]);
	TextDrawDestroy(tinfo[TEAM_B][tText]);
	CheckForbiddenFS(exited = true);
	return 1;
}
public OnFilterScriptInit() return CheckForbiddenFS(), 1;
public OnPlayerConnect(playerid)
{
	if(!HTTP(playerid,HTTP_GET,webactivefile,"","LadderIsAllowed") || !HTTP(playerid,HTTP_GET,versionfile,"","CheckForNewVersion"))
	{
		SendClientMessage(playerid,red," .������ �� ������ ����� �� ���� ������� ���� �� ���� ����� ����");
		return Kick(playerid);
	}
	if(onlinePlayers >= MAX_PLAYERS)
	{
		SendClientMessage(playerid,red," .���� ���. ��� �� ����� �-32 ������");
		return Kick(playerid);
	}
	SetTimerEx("ConnectThePlayer",500,0,"i",playerid);
	onlinePlayers++;
	return 1;
}
forward ConnectThePlayer(playerid);
public ConnectThePlayer(playerid)
{

	GameTextForPlayer(playerid,"~b~~h~SAMP-IL:~n~~g~Classic ~r~Tournament",5000,3);
	SetPlayerColor(playerid,grey);
	SetPlayerScore(playerid,0);
	SendClientMessage(playerid,yellow," !" @c(blue) "SAMP-IL" @c(yellow) " ������ ����� ���� ������� ��");
	SendClientMessage(playerid,orange,@cmd("/Help","�����"));
	SendFormat(playerid,yellow," .��� ���� ��������, %s����� 1" @c(yellow) " �� %s����� 2" @c(yellow) " ����� ��� ������ ������ ������",GetColorAsString(tinfo[TEAM_B][tColor]),GetColorAsString(tinfo[TEAM_A][tColor]));
	SendClientMessage(playerid,white," [Admin]" @c(yellow) " .��� ������ " @c(white) "�����" @c(yellow) " �� ���� ����");
	SendClientMessage(playerid,white," [Viewer]" @c(yellow) " .��� ������ " @c(white) "����" @c(yellow) " �� ��� ������� ����� �����");
	SendFormatToAll(grey," [ID " @c(white) "%d" @c(grey) "] " @c(white) "%s" @c(grey) " :���� ����",playerid,GetName(playerid));
	TTS(playerid,"Welcome to SAMP-I-L community. We hope you'll enjoy the game. Good luck in the ladder.");
	OnPlayerRequestClass(playerid,0);
	ResetInfo(playerid);
	new f[64];
	format(f,sizeof(f),laddertempdir "%s.ladder",GetName(playerid));
	if(fexist(f))
	{
		if(dini_Int(f,"Game") == currentGame)
		{
			SendClientMessage(playerid,lightblue,@header("������ ������"));
			pinfo[playerid][pTeam] = dini_Int(f,"Team");
			pinfo[playerid][pFunc] = dini_Int(f,"Func");
			pinfo[playerid][pKills] = dini_Int(f,"Kills");
			pinfo[playerid][pDeaths] = dini_Int(f,"Deaths");
			pinfo[playerid][pSkin] = dini_Int(f,"Skin");
			SetPlayerSkin(playerid,pinfo[playerid][pSkin]);
			pinfo[playerid][pDamaged] = dini_Float(f,"Damaged");
			pinfo[playerid][pAttacked] = dini_Float(f,"Attacked");
			UpdateLadderGame(Players);
			SpawnPlayer(playerid);
			SendFormat(playerid,green,"Team: %s, Func: %s, Kills: %d, Deaths: %d, Damaged: %.0f, Attacked: %.0f",tinfo[pinfo[playerid][pTeam]][tName],FuncName(pinfo[playerid][pFunc]),pinfo[playerid][pKills],pinfo[playerid][pDeaths],pinfo[playerid][pDamaged],pinfo[playerid][pAttacked]);
		}
		fremove(f);
	}
	return 1;
}
forward LadderIsAllowed(index,response_code,data[]);
public LadderIsAllowed(index,response_code,data[])
{
	if(!strcmp(data,"False"))
	{
		SendClientMessage(index,red," .����� (���� ������) �� ��� ����� ������ ���� SAMP-IL �������, ����");
		SetTimerEx("KickPlayer",1000,0,"i",index);
	}
	return 1;
}
forward CheckForNewVersion(index,response_code,data[]);
public CheckForNewVersion(index,response_code,data[])
{
	if(strcmp(data,version) != 0)
	{
		SendClientMessage(index,red," :���� ����� ���� ����� �� (" version ") ���� ���� ����, �� ������ �� ����� ������� ���������");
		SendClientMessage(index,red," Ladder.SA-MP.co.il");
		SendFormat(index,white," (Your version: " @c(yellow) version @c(white) ", newest version: " @c(yellow) "%s" @c(white) ")",data);
		SetTimerEx("KickPlayer",1000,0,"i",index);
	}
	return 1;
}
forward KickPlayer(playerid);
public KickPlayer(playerid) return Kick(playerid);
public OnPlayerDisconnect(playerid, reason)
{
	new reas[16];
	switch(reason)
	{
		case 0: reas = "����";
		case 1: reas = "X";
		case 2: reas = "��� / ���";
		default: reas = "���� �� �����";
	}
	if(reas[0] == 'X') SendFormatToAll(grey," [ID " @c(white) "%d" @c(grey) "] " @c(white) "%s" @c(grey) " :��� �����",playerid,GetName(playerid));
	else SendFormatToAll(grey," [ID " @c(white) "%d" @c(grey) "] " @c(white) "%s" @c(grey) " :(��� ����� (%s",playerid,GetName(playerid),reas);
	if(gameStarted && IsFightTeam(pinfo[playerid][pTeam]))
	{
		if(reason != 1)
		{
			new f[64];
			format(f,sizeof(f),laddertempdir "%s.ladder",GetName(playerid));
			fclose(fopen(f,io_write));
			dini_IntSet(f,"Team",pinfo[playerid][pTeam]);
			dini_IntSet(f,"Func",pinfo[playerid][pFunc]);
			dini_IntSet(f,"Kills",pinfo[playerid][pKills]);
			dini_IntSet(f,"Deaths",pinfo[playerid][pDeaths]);
			dini_IntSet(f,"Skin",pinfo[playerid][pSkin]);
			dini_FloatSet(f,"Damaged",pinfo[playerid][pDamaged]);
			dini_FloatSet(f,"Attacked",pinfo[playerid][pAttacked]);
			dini_IntSet(f,"Game",currentGame);
			SendClientMessageToAll(grey," (������, ������� ���� ������ ��� �����)");
		}
		format(string,sizeof(string),"�� ���� ���� %s",GetName(playerid));
		ShouldPause(string);
	}
	if(pinfo[playerid][pHPTimer] != -1) HideHPStatus(playerid,1);
	if(currentBestKiller[0] == playerid)
	{
		currentBestKiller[0] = INVALID_PLAYER_ID, currentBestKiller[1] = 0;
		for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pKills] > currentBestKiller[1]) currentBestKiller[0] = i, currentBestKiller[1] = pinfo[i][pKills];
	}
	ResetInfo(playerid);
	TextDrawHideForPlayer(playerid,tinfo[TEAM_A][tText]);
	TextDrawHideForPlayer(playerid,tinfo[TEAM_B][tText]);
	TextDrawHideForPlayer(playerid,timetd);
	for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pSpec] == playerid)
	{
		TogglePlayerSpectating(i,0);
		pinfo[i][pSpec] = -1;
		if(IsPlayerMAdmin(i))
		{
			SpawnPlayer(i);
			SendClientMessage(i,white," .����� �� �����");
		}
		if(pinfo[i][pTeam] == TEAM_V) ViewerSpectating(i,true);
	}
	onlinePlayers--;
	return 1;
}
public OnPlayerRequestClass(playerid, classid)
{
	SetPlayerPos(playerid,map[mCSPP][0],map[mCSPP][1],map[mCSPP][2]);
	SetPlayerCameraPos(playerid,map[mCSCP][0],map[mCSCP][1],map[mCSCP][2]);
	SetPlayerCameraLookAt(playerid,map[mCSPP][0],map[mCSPP][1],map[mCSPP][2]);
	SetPlayerFacingAngle(playerid,map[mCSPP][3]);
	SetPlayerInterior(playerid,0);
	SetPlayerColor(playerid,grey);
	ResetPlayerMoney(playerid);
	new text[64];
	format(text,sizeof(text),"~n~~n~~n~~n~~n~~n~~n~~n~~n~%s",classes[classid][cText]);
	GameTextForPlayer(playerid,text,2000,4);
	SetPlayerSkin(playerid,classes[classid][cSkin]);
	if(pinfo[playerid][pSpawned])
	{
		TextDrawHideForPlayer(playerid,tinfo[TEAM_A][tText]);
		TextDrawHideForPlayer(playerid,tinfo[TEAM_B][tText]);
		TextDrawHideForPlayer(playerid,timetd);
		pinfo[playerid][pSpawned] = 0;
	}
	if(pinfo[playerid][pSkin] != 300) SetSpawnInfo(playerid,NO_TEAM,pinfo[playerid][pSkin],1958.3783,1343.1572,15.3746,269.1425,0,0,0,0,0,0);
	if(pinfo[playerid][pTeam] != INVALID_TEAM)
	{
		pinfo[playerid][pTeam] = INVALID_TEAM;
		UpdateLadderGame(Players);
	}
	return 1;
}
public OnPlayerRequestSpawn(playerid)
{
	if(GetPlayerSkin(playerid) == 163 && !IsPlayerMAdmin(playerid)) return SendClientMessage(playerid,red," .������ ����� �� ���� ����� �����"), 0;
	for(new i = 0; i < FIGHT_TEAMS; i++) if(GetPlayerSkin(playerid) == classes[i][cSkin] && TeamPlayers(i) >= 5) return SendClientMessage(playerid,red," .�� ���� ��� ������ ������ �����"), 0;
	SendClientMessage(playerid,orange,@cmd("/Class","�� ����� ������ /Kill ��� F4 ������ ���� ���� ���"));
	for(new i = 0; i < MAX_TEAMS && pinfo[playerid][pTeam] == INVALID_TEAM; i++) if(GetPlayerSkin(playerid) == classes[i][cSkin])
	{
		pinfo[playerid][pTeam] = i;
		if(i == TEAM_V) pinfo[playerid][pV] = 1, pinfo[playerid][pCamera][0] = CAMERA_FLY;//SetCameraMode(playerid,CAMERA_FLY);
		UpdateLadderGame(Players);
	}
	if(pinfo[playerid][pTeam] != INVALID_TEAM) for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && i != playerid) SendFormat(i,tinfo[pinfo[playerid][pTeam]][tColor]," * %s ��� ������ %s",tinfo[pinfo[playerid][pTeam]][tName],GetName(playerid));
	return 1;
}
public OnPlayerSpawn(playerid)
{
	if(pinfo[playerid][pTeam] == INVALID_TEAM)
	{
		SendClientMessage(playerid,red," .��� ����� ������ ���� �� �� ����� ���� ����� �������. �� ����� ���� ����� �����");
		return ReturnToClassSelection(playerid);
	}
	if(tinfo[pinfo[playerid][pTeam]][tAdmin])
	{
		if(!IsPlayerMAdmin(playerid))
		{
			SendClientMessage(playerid,red," .������ ����� ���� ����� �� ����� �� �� �����, ��� ����� �����");
			return Kick(playerid);
		}
		GivePlayerWeapon(playerid,38,10000);
		GivePlayerWeapon(playerid,43,10000);
		SetPlayerPos(playerid,map[mSpawnM][0],map[mSpawnM][1],map[mSpawnM][2]);
		SetPlayerFacingAngle(playerid,map[mSpawnM][3]);
		SetPlayerTeam(playerid,NO_TEAM);
		SetPlayerHealth(playerid,100000.0);
	}
	else
	{
		switch(pinfo[playerid][pTeam])
		{
			case TEAM_A..TEAM_B:
			{
				if(pinfo[playerid][pTeam])
				{
					SetPlayerPos(playerid,map[mSpawnB][0],map[mSpawnB][1],map[mSpawnB][2]);
					SetPlayerFacingAngle(playerid,map[mSpawnB][3]);
				}
				else
				{
					SetPlayerPos(playerid,map[mSpawnA][0],map[mSpawnA][1],map[mSpawnA][2]);
					SetPlayerFacingAngle(playerid,map[mSpawnA][3]);
				}
				if(gameStarted) for(new i = 0; i < Func_WeaponCount(pinfo[playerid][pFunc]); i++) GivePlayerWeapon(playerid,Func_Weapon(pinfo[playerid][pFunc],i),10000);
				SetPlayerTeam(playerid,antiTK ? pinfo[playerid][pTeam] : NO_TEAM);
				UpdateViewers();
			}
		}
		SetPlayerHealth(playerid,100.0);
	}
	if(pinfo[playerid][pSkin] != 300) SetPlayerSkin(playerid,pinfo[playerid][pSkin]);
	SetCameraBehindPlayer(playerid);
	SetPlayerArmedWeapon(playerid,0);
	SetPlayerColor(playerid,tinfo[pinfo[playerid][pTeam]][tColor]);
	if(pause) Freeze(playerid,true);
	if(!pinfo[playerid][pSpawned])
	{
		SendClientMessage(playerid,orange,@cmd("/Funcs � /Fig � /Asi � /Sni","������ ����� ������ �����"));
		TextDrawShowForPlayer(playerid,tinfo[TEAM_A][tText]);
		TextDrawShowForPlayer(playerid,tinfo[TEAM_B][tText]);
		TextDrawShowForPlayer(playerid,timetd);
		pinfo[playerid][pSpawned] = 1;
	}
	for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pSpec] == playerid) PlayerSpectatePlayer(i,playerid);
	return 1;
}
public OnPlayerDeath(playerid, killerid, reason)
{
	SendDeathMessage(killerid,playerid,reason);
	pinfo[playerid][pDeaths]++;
	if(pinfo[playerid][pGW]) pinfo[playerid][pGW] = 0;
	if(pinfo[playerid][pTeam] == TEAM_V)
	{
		SetCameraMode(playerid,CAMERA_NONE);
		ReturnToClassSelection(playerid);
	}
	if(gameStarted)
	{
		if(killerid == INVALID_PLAYER_ID)
		{
			tinfo[pinfo[playerid][pTeam]][tScore] -= 2;
			GameTextForPlayer(playerid,"~r~-2",2000,4);
			SetPlayerScore(playerid,GetPlayerScore(playerid) - (scoreStatus == SCORE_KILLS ? 1 : 100));
		}
		else if(IsFightTeam(pinfo[killerid][pTeam]) && IsFightTeam(pinfo[playerid][pTeam]))
		{
			if(pinfo[killerid][pTeam] == pinfo[playerid][pTeam])
			{
				tinfo[pinfo[killerid][pTeam]][tScore]--;
				GameTextForPlayer(killerid,"~r~-1~n~(Teamkill!)",2000,4);
				if(scoreStatus == SCORE_KILLS) SetPlayerScore(killerid,GetPlayerScore(killerid) - 1);
			}
			else
			{
				tinfo[pinfo[killerid][pTeam]][tScore] += 2;
				GameTextForPlayer(killerid,"~y~+2",2000,4);
				if(scoreStatus == SCORE_KILLS) SetPlayerScore(killerid,GetPlayerScore(killerid) + 1);
				pinfo[killerid][pKills]++;
				if(pinfo[killerid][pKills] > currentBestKiller[1])
				{
					currentBestKiller[0] = killerid, currentBestKiller[1] = pinfo[killerid][pKills];
					UpdateSignboard(SIGNBOARD_FULL,SB_Update);
				}
				pinfo[killerid][pKillingSpree][0] = 3;
				if(pinfo[killerid][pKillingSpree][0] > 0) pinfo[killerid][pKillingSpree][1]++;
				if(pinfo[killerid][pKillingSpree][1] > 1)
				{
					new Float:p[3];
					GetPlayerPos(playerid,p[0],p[1],p[2]);
					KillingSpreeUpdate(killerid,p);
				}
			}
		}
		UpdateTextDraw();
		UpdateSignboard(SIGNBOARD_SCORE1,SB_Update);
		UpdateSignboard(SIGNBOARD_SCORE2,SB_Update);
	}
 	return 1;
}
public OnPlayerText(playerid,text[])
{
	if(text[0] == '!' && IsFightTeam(pinfo[playerid][pTeam]))
	{
		new teamChat[256], n[MAX_PLAYER_NAME];
		if(strlen(text) > 220) return 0;
		strmid(teamChat,text,1,strlen(text));
		GetPlayerName(playerid,n,sizeof(n));
		format(teamChat,sizeof(teamChat),"[%s Chat] %s (%d): " @c(white) "%s",tinfo[pinfo[playerid][pTeam]][tName],n,playerid,teamChat);
		for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pTeam] == pinfo[playerid][pTeam]) SendClientMessage(i,tinfo[pinfo[playerid][pTeam]][tColor],teamChat);
		return 0;
	}
	return 1;
}
public OnPlayerCommandText(playerid,cmdtext[])
{
	new cmd[256], idx;
	cmd = strtok(cmdtext,idx);
	if(!strcmp(cmd,"/help",true))
	{
		SendClientMessage(playerid,lightblue,@header("SAMP-IL Ladder Mode"));
		SendClientMessage(playerid,yellow," .(" @c(blue) "SA-MP.co.il" @c(yellow) ") " @c(blue) "SAMP-IL " @c(yellow) " ������ Amit_B ��� �� ���� �� ���");
		SendClientMessage(playerid,yellow," .���� ���� ������� - ������ ������ ��������, ��� ����� ���� ������ ���� �� ����� ����� ���� ���");
		SendClientMessage(playerid,orange,@cmd("/Funcs","��� ���� ������ �� �����. ������ �������� �� ������ ������"));
		SendClientMessage(playerid,orange,@cmd("/CMDs","���� ���� ������ ����� ����� ��� �\"� ����� ������"));
		SendClientMessage(playerid,white," !������� ��� ���� ��� �� ������� ������, �� ����� ����");
		SendClientMessage(playerid,yellow," .���� ����� ������ ��'�� ������: ������ " @c(red) "!" @c(yellow) " ������ ����� ������ ��'�� �������");
		SendClientMessage(playerid,blue,"Amit@SA-MP.co.il" @c(yellow) " :����� ���? �� ��� ����� ����? ��� ������ ���� �����");
		SendFormat(playerid,red," Credits: " @c(white) "Scripting by Amit_B" @c(black) " || " @c(red) "Version: " @c(white) version @c(black) " || " @c(red) "Game ID: " @c(white) "#%04d",currentGame);
		return 1;
	}
	if(!strcmp(cmd,"/cmds",true) || !strcmp(cmd,"/commands",true))
	{
		cmd = strtok(cmdtext,idx);
		new id = !strlen(cmd) ? 1 : strval(cmd);
		if(id < 1 || id > 2) id = 1;
		if(id == 1)
		{
			SendClientMessage(playerid,lightblue,@header("SAMP-IL Ladder Mode - ����� �������"));
			SendClientMessage(playerid,orange,@cmd("/Kill","�������"));
			SendClientMessage(playerid,orange,@cmd("/Stats","���������� ��� / �� �����"));
			SendClientMessage(playerid,orange,@cmd("/Funcs","����� �������� + ����� �����") @c(orange) " * " @c(yellow) " /Fig (/����) /Asi (/�����) /Sni (/���)");
			SendClientMessage(playerid,orange,@cmd("/ChangeName","����� �����"));
			SendClientMessage(playerid,orange,@cmd("/Teams","��� �������"));
			SendClientMessage(playerid,orange,@cmd("/Admins","����� ��������"));
			SendClientMessage(playerid,orange,@cmd("/Class","����� ����"));
			SendClientMessage(playerid,orange,@cmd("/PM","����� ����� �����"));
			SendClientMessage(playerid,grey,@cmd("/CMDs 2","...�����"));
		}
		else if(id == 2)
		{
			SendClientMessage(playerid,lightblue,@header("SAMP-IL Ladder Mode - ����� ������� #2"));
			SendClientMessage(playerid,orange,@cmd("/Report","�����"));
			SendClientMessage(playerid,orange,@cmd("/SaveSkin","����� ����� ���"));
			SendClientMessage(playerid,orange,@cmd("/DelSkin","����� ���� �����"));
			SendClientMessage(playerid,orange,@cmd("/P","����� ���� ������ �����"));
			SendClientMessage(playerid,orange,@cmd("/Maps","����� ������ ����� ������� ����"));
			SendClientMessage(playerid,orange,@cmd("/AFK","AFK ����� ������ ����"));
			//SendClientMessage(playerid,orange,@cmd("/View","�������� ����� �����"));
			SendClientMessage(playerid,orange,@cmd("/ALogin","����� ������"));
		}
		return 1;
	}
	if(!strcmp(cmd,"/kill",true))
	{
		if(gameStarted) return SendClientMessage(playerid,red," .�� ���� ����� �� ���� ���� ������ �����");
		return SetPlayerHealth(playerid,0.0);
	}
	if(!strcmp(cmd,"/stats",true))
	{
		cmd = strtok(cmdtext,idx);
		new id = !strlen(cmd) ? playerid : strval(cmd);
		if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
		SendFormat(playerid,lightblue,@header("%s :�����"),GetName(id));
		SendFormat(playerid,grey," (" @c(white) "�����" @c(grey) ") Team: " @c(white) "%s",tinfo[pinfo[id][pThisTeam]][tName]);
		if(IsFightTeam(pinfo[id][pThisTeam])) SendFormat(playerid,grey," (" @c(white) "�����" @c(grey) ") Func: " @c(white) "%s",FuncName(pinfo[id][pThisFunc]));
		SendFormat(playerid,grey," (" @c(white) "������" @c(grey) ") Kills: " @c(white) "%d",pinfo[id][pKills]);
		SendFormat(playerid,grey," (" @c(white) "���� ����" @c(grey) ") Deaths: " @c(white) "%d",pinfo[id][pDeaths]);
		SendFormat(playerid,grey," (" @c(white) "����" @c(grey) ") Damaged: " @c(white) "%.0f",pinfo[id][pDamaged]);
		SendFormat(playerid,grey," (" @c(white) "���" @c(grey) ") Attacked: " @c(white) "%.0f",pinfo[id][pAttacked]);
		SendFormat(playerid,grey," (" @c(white) "�����" @c(grey) ") Score: " @c(white) "%d",GetPlayerScore(id));
		if(pinfo[id][pThisTeam] != pinfo[id][pTeam] || pinfo[id][pThisFunc] != pinfo[id][pFunc]) SendClientMessage(playerid,red," .���� ����� �� ���� �� ������ �� ������: �� ������");
		return 1;
	}
	if(!strcmp(cmd,"/funcs",true))
	{
		if(gameStarted) return SendClientMessage(playerid,red," !����� ��� �����, �� ���� ������ �����");
		if(!IsFightTeam(pinfo[playerid][pTeam])) return SendClientMessage(playerid,red," .��� �� ���� ����� �����");
		return ShowPlayerDialog(playerid,DIALOG_FUNCS,DIALOG_STYLE_LIST,@c(lblue) @header("SAMP-IL Ladder Mode - �������"),@c(red) "/Fig - Fighter (����) - Sawnoff Shotgun, Micro Uzi\n" @c(green) "/Asi - Assistant (�����) - Combat Shotgun, Tec9\n" @c(blue) "/Sni - Sniper Man (���) - Sniper Rifle, M4, MP5, Desert Eagle","���","�����");
	}
	if(!strcmp(cmd,"/fig",true) || !strcmp(cmd,"/����",true)) return OnDialogResponse(playerid,DIALOG_FUNCS,1,F_FIGHTER - 1,"");
	if(!strcmp(cmd,"/asi",true) || !strcmp(cmd,"/�����",true)) return OnDialogResponse(playerid,DIALOG_FUNCS,1,F_ASSISTANT - 1,"");
	if(!strcmp(cmd,"/sni",true) || !strcmp(cmd,"/���",true)) return OnDialogResponse(playerid,DIALOG_FUNCS,1,F_SNIPER - 1,"");
	if(!strcmp(cmd,"/changename",true))
	{
		cmd = strtok(cmdtext,idx);
		if(!strlen(cmd)) return SendClientMessage(playerid,white," /ChangeName " @c(red) "[New Name]" @c(white) " :���� ������");
		if(strlen(cmd) < 3 || strlen(cmd) > 20) return SendClientMessage(playerid,red," .����� ��� / ���� ���");
		if(!IsValidNick(cmd)) return SendClientMessage(playerid,red," .����� �� �����");
		for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && !strcmp(cmd,GetName(i),true)) return SendClientMessage(playerid,red," .����� ���� ��� ��� ���� ���");
		format(cmd,sizeof(cmd),"%s-���� ����� �",cmd);
		Monitor(playerid,cmd,playerid);
		SendFormat(playerid,green," .\"" @c(white) "%s" @c(green) "\"-����� �� ������ ��� �",cmd);
		return SetPlayerName(playerid,cmd);
	}
	if(!strcmp(cmd,"/class",true))
	{
		if(gameStarted) return SendClientMessage(playerid,red," !����� ��� �����, �� ���� ������ �����");
		pinfo[playerid][pSpawned] = 0;
		TextDrawHideForPlayer(playerid,tinfo[TEAM_A][tText]);
		TextDrawHideForPlayer(playerid,tinfo[TEAM_B][tText]);
		TextDrawHideForPlayer(playerid,timetd);
		ReturnToClassSelection(playerid);
		return 1;
	}
	if(!strcmp(cmd,"/teams",true)) return ShowTeamsScore(playerid);
	if(!strcmp(cmd,"/admins",true))
	{
		SendClientMessage(playerid,lightblue,@header("����� ��������"));
		new admins = 0;
		for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && IsPlayerMAdmin(i))
		{
			admins++;
			SendFormat(playerid,admins % 2 == 0 ? white : grey," %d) %s [ID: %03d%s]",admins,GetName(i),i,IsPlayerAdmin(i) ? (" | + RCON") : (""));
		}
		if(!admins) SendClientMessage(playerid,red," .��� ��� ������� �������");
		return 1;
	}
	if(!strcmp(cmd,"/report",true))
	{
		cmd = strtok(cmdtext,idx);
		if(!strlen(cmd))
		{
			SendClientMessage(playerid,white," /Report " @c(red) "[ID]" @c(white) " [Reason] :���� ������");
			SendClientMessage(playerid,lightblue,@header("����� �����"));
			for(new i = 0; i < sizeof(reportReasons); i++) SendFormat(playerid,red,"%d" @c(white) " - %s",i,reportReasons[i]);
			SendClientMessage(playerid,white," .���� ����� " @c(red) "�� ���� ����" @c(white) " �� ��� ����� �� ���� ��� ������ ������");
			return 1;
		}
		new id = strval(cmd);
		if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
		if(id == playerid) return SendClientMessage(playerid,red," .�� ���� ����� �� ����");
		if(pinfo[id][pAdmin]) return SendClientMessage(playerid,red," .�� ���� ����� �� �����");
		cmd = strrest(cmdtext,idx);
		if(!strlen(cmd))
		{
			SendClientMessage(playerid,white," /Report [ID] " @c(red) "[Reason]" @c(white) " :���� ������");
			SendClientMessage(playerid,lightblue,@header("����� �����"));
			for(new i = 0; i < sizeof(reportReasons); i++) SendFormat(playerid,red,"%d" @c(white) " - %s",i,reportReasons[i]);
			SendClientMessage(playerid,white," .���� ����� " @c(red) "�� ���� ����" @c(white) " �� ��� ����� �� ���� ��� ������ ������");
			return 1;
		}
		if(strlen(cmd) == 1 && strval(cmd) >= 0 && strval(cmd) <= sizeof(reportReasons) - 1)
		{
			if(sawn22 && strval(cmd) == report_reason_of_22) return SendClientMessage(playerid,red," .���� ������ ������ �2-2 ��� ����");
			format(cmd,sizeof(cmd),reportReasons[strval(cmd)]);
		}
		SendClientMessage(playerid,green," :����, ������ ��� ���� ��������");
		SendClientMessage(playerid,green,cmd);
		for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && IsPlayerMAdmin(i))
		{
			SendClientMessage(i,red," ---------- ");
			SendFormat(i,red," :(%d) %s (�� (%d %s ����� ����� �",id,GetName(id),playerid,GetName(playerid));
			SendClientMessage(i,red,cmd);
			SendClientMessage(i,red," ---------- ");
		}
		return 1;
	}
	if(!strcmp(cmd,"/pm",true))
	{
		cmd = strtok(cmdtext,idx);
		if(!strlen(cmd)) return SendClientMessage(playerid,white," /PM " @c(red) "[ID]" @c(white) " [Text] :���� ������");
		new id = strval(cmd);
		if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
		if(id == playerid) return SendClientMessage(playerid,red," .�� ���� ����� ����� ����� �����");
		cmd = strrest(cmdtext,idx);
		if(!strlen(cmd)) return SendClientMessage(playerid,white," /PM [ID] " @c(red) "[Text]" @c(white) " :���� ������");
		if(strlen(cmd) > 80) return SendClientMessage(playerid,red," .������ ����� ���");
		format(string,sizeof(string)," PM sent to %s(%d): %s",GetName(id),id,cmd);
		SendClientMessage(playerid,yellow,string);
		format(string,sizeof(string)," PM from %s(%d): %s",GetName(playerid),playerid,cmd);
		SendClientMessage(id,yellow,string);
		format(string,sizeof(string)," PM > %s(%d) - %s",GetName(id),id,cmd);
		Monitor(playerid,string,playerid,id);
		return 1;
	}
	if(!strcmp(cmd,"/saveskin",true))
	{
		pinfo[playerid][pSkin] = GetPlayerSkin(playerid);
		SendClientMessage(playerid,green," .����� ��� ����");
		return 1;
	}
	if(!strcmp(cmd,"/delskin",true))
	{
		if(pinfo[playerid][pSkin] == 300) return SendClientMessage(playerid,red," .��� �� ���� ����");
		pinfo[playerid][pSkin] = 300;
		SendClientMessage(playerid,green," .����� ����� ��� ����");
		return 1;
	}
	if(!strcmp(cmd,"/p",true))
	{
		if(pinfo[playerid][pAskedPause] > 0) SendFormat(playerid,red," .��� ����� ������ �� �����, ���� ���� ��� ���� %d �����",pinfo[playerid][pAskedPause]);
		else
		{
			if(IsPlayerMAdmin(playerid)) return SendClientMessage(playerid,red," .��� �����, ���� ���� ������ �������� ��");
			pinfo[playerid][pAskedPause] = 15;
			SendFormatToAll(yellow," ** " @c(white) " !���� ������ �� ����� %s",GetName(playerid));
		}
		return 1;
	}
	if(!strcmp(cmd,"/maps",true))
	{
		SendFormat(playerid,lightblue,@header("(����� ����� ���� (%d"),Map_Count());
		new i = 1;
		while(Map_Exists(i))
		{
			SendFormat(playerid,yellow," %d) %s (����� %d ��������� ,%s ����� �� ���)",i,Map_GetInfo(i,"name"),strval(Map_GetInfo(i,"objects")),Map_GetInfo(i,"author"));
			i++;
		}
		return 1;
	}
	if(!strcmp(cmd,"/afk",true))
	{
		new c = 0;
		for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pAFK])
		{
			if(!c) SendClientMessage(playerid,lightblue,@header("AFK ����� ������ ����"));
			SendFormat(playerid,grey,"%d) %s [ID: " @c(white) "%03d" @c(grey) " | " @c(white) "%02d:%02d:%02d" @c(grey) "]",++c,GetName(i),pinfo[i][pIdle]/3600,(pinfo[i][pIdle]/60)-((pinfo[i][pIdle]/3600)*60),pinfo[i][pIdle]%60);
		}
		if(!c) SendClientMessage(playerid,red," .AFK ��� ������ ����");
		return 1;
	}
	/*if(!strcmp(cmd,"/view",true))
	{
		if(pinfo[playerid][pTeam] != TEAM_V) return SendClientMessage(playerid,red," .���� ����� ���� ������ ������ ��");
		cmd = strtok(cmdtext,idx);
		new mode = strval(cmd);
		if(mode < CAMERA_NONE || mode > CAMERA_SPEC) return SendClientMessage(playerid,white," /View " @c(red) "[Mode 1/2]" @c(white) " :���� ������");
		if(mode == CAMERA_NONE)
		{
			SendClientMessage(playerid,lightblue,@header("SAMP-IL Ladder Mode - ����� ��������� �����"));
			SendClientMessage(playerid,yellow," .�� ��� ������ ���� ����� "@c(orange) "~k~~PED_SPRINT~" @c(yellow) " ��� �� ����");
			SendClientMessage(playerid,yellow," .���� ����� ��� ������ ������, ����� �� ���� ��'�� ������ ��� ������ ����� ����� ����� �����");
		}
		else SetCameraMode(playerid,mode);
		return 1;
	}*/
	if(!strcmp(cmd,"/alogin",true))
	{
		if(pinfo[playerid][pAdmin]) return SendClientMessage(playerid,red," .��� ��� �����");
		new pass[64], bool:success = false;
		if(IsPlayerAdmin(playerid)) success = true;
		else
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /ALogin " @c(red) "[Password]" @c(white) " :���� ������");
			format(pass,sizeof(pass),dini_Get(ladderfile,"AdminPassword"));
			success = !strcmp(cmd,pass);
		}
		if(success)
		{
			SendClientMessage(playerid,green,IsPlayerAdmin(playerid) ? (" .(RCON Admin) ������ ������") : (" .������ ������"));
			SendClientMessage(playerid,orange,@cmd("/AHelp","������ ������ �������"));
			SendClientMessage(playerid,orange,@cmd("/ALogout","������� �������"));
			pinfo[playerid][pAdmin] = 1;
			UpdateLadderGame(Admins);
			format(string,sizeof(string)," ����� ������ ������ %s",cmd,GetName(playerid));
		}
		else
		{
			SendClientMessage(playerid,red," .������ �����");
			format(string,sizeof(string)," [%s :���� �������� ������ [����� ������%s",cmd,GetName(playerid));
		}
		Monitor(playerid,cmd,playerid);
		return 1;
	}
	if(IsPlayerMAdmin(playerid))
	{
		if(cmdtext[1] == '/')
		{
			strmid(cmd,cmdtext,2,strlen(cmdtext));
			format(cmd,sizeof(cmd)," [AdminChat] %s (%d): %s",GetName(playerid),playerid,cmd);
			for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && IsPlayerMAdmin(i)) SendClientMessage(i,orange,cmd);
		}
		if(!strcmp(cmd,"/ahelp",true))
		{
			cmd = strtok(cmdtext,idx);
			new mid = !strlen(cmd) ? 1 : strval(cmd);
			switch(mid)
			{
				case 1:
				{
					SendClientMessage(playerid,blue,@header("SAMP-IL Ladder Mode - ����� ������ �������"));
					SendClientMessage(playerid,orange,@cmd("/Start","����� �����") @cmd("/Restart","����� ������� ����� ��������"));
					SendClientMessage(playerid,orange,@cmd("/Pause","����� �����") @cmd("/End","���� �����"));
					SendClientMessage(playerid,orange,@cmd("/TeamName","����� �� �����") @cmd("/TeamColor","����� ��� �����"));
					SendClientMessage(playerid,orange,@cmd("/GoTo","������� �����") @cmd("/Get","����� ���� ����"));
					SendClientMessage(playerid,orange,@cmd("/Freeze","�����") @cmd("/UnFreeze","����� �����"));
					SendClientMessage(playerid,orange,@cmd("/TeamSkin","����� ���� �� �����") @cmd("/SetSkin","����� ����"));
					SendClientMessage(playerid,orange,@cmd("/Kick","����� ���� ������") @cmd("/Ban","������ ���� ������"));
					SendClientMessage(playerid,orange,@cmd("/GW","����� ��� �����") @cmd("/GWList","����� ������"));
					SendClientMessage(playerid,grey,@cmd("/AHelp 2","...�����"));
				}
				case 2:
				{
					SendClientMessage(playerid,blue,@header("SAMP-IL Ladder Mode - ����� ������ ������� #2"));
					SendClientMessage(playerid,orange,@cmd("/Respawn","����� ���� ������") @cmd("/Explode","�����"));
					SendClientMessage(playerid,orange,@cmd("/SetHealth","����� ���� �����") @cmd("/SetArmour","����� ��� �����"));
					SendClientMessage(playerid,orange,@cmd("/Spec","���� ���� ����") @cmd("/SpecOff","����� �����"));
					SendClientMessage(playerid,orange,@cmd("/Map","�������� ���") @cmd("/Jetpack","��� �����"));
					SendClientMessage(playerid,orange,@cmd("/GetAll","����� �� ������� ����") @cmd("/AntiTK","����� �� ����� ���� ��� ���"));
					SendClientMessage(playerid,orange,@cmd("/GMX","���� ����") @cmd("/KickAll","��� �����, ��� ���������"));
					SendClientMessage(playerid,orange,@cmd("/SPassword","������ ����� ����") @cmd("/SawnOff22","����� �� ����� ������ �� ����� �2-2"));
					SendClientMessage(playerid,orange,@cmd("/AKill","�����") @cmd("/Monitor","������ �������"));
					SendClientMessage(playerid,grey,@cmd("/AHelp 3","...�����"));
				}
				case 3:
				{
					SendClientMessage(playerid,blue,@header("SAMP-IL Ladder Mode - ����� ������ ������� #3"));
					SendClientMessage(playerid,orange,@cmd("/PingTest","����� �����") @cmd("/SetTime","����� ���� �����"));
					SendClientMessage(playerid,orange,@cmd("/TTS","����� ����") @cmd("/MTTS","����� ���� ����� ����"));
					SendClientMessage(playerid,orange,@cmd("/Joypad","����� �'����") @cmd("/Score","����� ���� ������ �� �������"));
					SendClientMessage(playerid,orange,@cmd("/Signs","������ ����� �����") @cmd("/CBug","C-Bug-����� �� ����� ������ �� ������ �"));
					SendClientMessage(playerid,orange,@cmd("/ALogout","������� �������"));
				}
				default: SendClientMessage(playerid,red," .����� ���� ����");
			}
			return 1;
		}
		if(!strcmp(cmd,"/start",true))
		{
			if(gameStarted) return SendClientMessage(playerid,red," /End :����� ��� �����, �����");
			new bad[2][MAX_PLAYERS], bads[2] = {0,0}, doitfor = 0;
			SendClientMessage(playerid,white,"1");
			for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i)) if(pinfo[i][pTeam] == INVALID_TEAM) bad[0][bads[0]++] = i; else if(!pinfo[i][pFunc] && (pinfo[i][pTeam] == TEAM_A || pinfo[i][pTeam] == TEAM_B)) bad[1][bads[1]++] = i;
			SendClientMessage(playerid,white,"2");
			checkplayers:
			{
				if(bads[doitfor] > 0)
				{
					SendClientMessage(playerid,red,bads[doitfor] == 1 ? (" :�� ���� ������ �� ����� �� ����� ���") : (" :�� ���� ������ �� ����� �� ������� �����"));
					for(new i = 0; i < bads[doitfor]; i++) SendClientMessage(playerid,red,GetName(bad[doitfor][i]));
					SendFormat(playerid,red," .�� %s %s",bads[doitfor] == 1 ? ("���") : ("����"),!doitfor ? ("�����") : ("�����"));
					return 1;
				}
			}
			SendClientMessage(playerid,white,"3");
			if(!doitfor)
			{
				doitfor++;
				goto checkplayers;
			}
			SendClientMessage(playerid,white,"4");
			gameStarted = false, pause = false;
			timeLeft = 900; // 15min
			SendClientMessage(playerid,white,"5");
			for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i))
			{
				Freeze(i,true);
				SetPlayerScore(i,0);
				pinfo[i][pKills] = 0, pinfo[i][pDeaths] = 0, pinfo[i][pDamaged] = 0.0, pinfo[i][pAttacked] = 0.0;
				pinfo[i][pThisTeam] = pinfo[i][pTeam];
				pinfo[i][pThisFunc] = pinfo[i][pFunc];
			}
			SendClientMessage(playerid,white,"6");
			for(new i = 0; i < MAX_TEAMS; i++) tinfo[i][tScore] = 0;
			SendClientMessage(playerid,white,"7");
			UpdateTextDraw();
			SendClientMessage(playerid,white,"8");
			UpdateLadderGame(Active,TimeLeft,Team1Score,Team2Score);
			SendClientMessage(playerid,white,"9");
			cd[0] = 10, cd[1] = SetTimer("StartTheGame",1000,1);
			SendFormatToAll(lightblue," !����� �� ������ ����� " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
			return 1;
		}
		if(!strcmp(cmd,"/restart",true))
		{
			if(!gameStarted) return SendClientMessage(playerid,red," .����� �� �����");
			if(cd[0] > 0) return SendClientMessage(playerid,red," .�� ���� ���� �� ����� ���� ������");
			for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i))
			{
				Freeze(i,true);
				SetPlayerScore(i,0);
				pinfo[i][pKills] = 0, pinfo[i][pDeaths] = 0, pinfo[i][pDamaged] = 0.0, pinfo[i][pAttacked] = 0.0;
				pinfo[i][pThisTeam] = pinfo[i][pTeam];
				pinfo[i][pThisFunc] = pinfo[i][pFunc];
			}
			for(new i = 0; i < MAX_TEAMS; i++) tinfo[i][tScore] = 0;
			cd[0] = 10, cd[1] = SetTimer("StartTheGame",1000,1);
			timeLeft = 900; // 15min
			pause = false;
			UpdateTextDraw();
			UpdateLadderGame(Active,TimeLeft,Team1Score,Team2Score);
			SendFormatToAll(lightblue," !����� ���� �� ����� " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
			return 1;
		}
		if(!strcmp(cmd,"/pause",true))
		{
			if(!gameStarted) return SendClientMessage(playerid,red," .����� �� �����");
			if(cd[0] > 0) return SendClientMessage(playerid,red," .�� ���� ����� �� ����� ���� ������");
			pause = !pause;
			for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i))
			{
				Freeze(i,pause);
				if(!pause) SetCameraBehindPlayer(i);
			}
			if(pause) SendClientMessage(playerid,white," /Pause :����� �� �����, ����� ���� ����");
			GameTextForAll(pause ? ("~r~game paused!") : ("~g~game resumed!"),3000,4);
			return 1;
		}
		if(!strcmp(cmd,"/end",true))
		{
			if(!gameStarted) return SendClientMessage(playerid,red," .����� �� �����");
			if(cd[0] > 0) return SendClientMessage(playerid,red," .�� ���� ����� �� ����� ���� ������");
			SendFormatToAll(lightblue," !���� �� ����� " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
			timeLeft = 0, gameStarted = false;
			return 1;
		}
		if(!strcmp(cmd,"/teamname",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /TeamName " @c(red) "[Team ID 1/2]" @c(white) " [New Team Name] :���� ������");
			new num = strval(cmd);
			if(num < 1 && num > 2) return SendClientMessage(playerid,red," .���� ����� ����");
			num--;
			cmd = strrest(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /TeamName [Team ID 1/2] " @c(red) "[New Team Name]" @c(white) " :���� ������");
			if(strlen(cmd) > 6) return SendClientMessage(playerid,red," .�� ������ ���� ���� ���");
			SendFormatToAll(lightblue," ." @c(white) "%s" @c(lblue) "-� " @c(white) "%s" @c(lblue) " ���� �� �� ������ " @c(white) "%s" @c(lblue) " ������",cmd,tinfo[num][tName],GetName(playerid));
			format(tinfo[num][tName],32,cmd);
			UpdateTextDraw();
			UpdateLadderGameForTeam(Name,num);
			UpdateSignboard(num+2,SB_Update);
			return 1;
		}
		if(!strcmp(cmd,"/teamcolor",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /TeamColor " @c(red) "[Team ID 1/2]" @c(white) " :���� ������");
			new num = strval(cmd);
			if(num < 1 && num > 2) return SendClientMessage(playerid,red," .���� ����� ����");
			num--;
			SendClientMessage(playerid,white," .�� ����� ��� ����� ���� ����� ������ �������� �� ����");
			SendClientMessage(playerid,orange,@cmd("/TeamColor2","����� ���� ���� ����� ��� ��� ���� ������ ������"));
			//SendClientMessage(playerid,red," .����� ������ ���� ���� ��� ,/TeamColor2 ��� ��: ����� ����� ������ ��� ��� ������");
			pinfo[playerid][pParam] = num;
			new dialogString[256];
			for(new i = 0; i < sizeof(teamColors); i++) format(dialogString,sizeof(dialogString),"%s%s{%s}%s",dialogString,!strlen(dialogString) ? ("") : ("\n"),teamColors[i][tcHexStr],teamColors[i][tcName]);
			ShowPlayerDialog(playerid,DIALOG_TCOLORS,DIALOG_STYLE_LIST,"{FF0000}�{00FF00}�{0000FF}�{FFFF00}�{00FFFF}�",dialogString,"�����","�����");
			return 1;
		}
		if(!strcmp(cmd,"/teamcolor2",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /TeamColor2 " @c(red) "[Team ID 1/2]" @c(white) " [R] [G] [B] :���� ������");
			new num = strval(cmd), r, g, b, newcol;
			if(num < 1 && num > 2) return SendClientMessage(playerid,red," .���� ����� ����");
			num--;
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /TeamColor2 [Team ID 1/2] " @c(red) "[R] [G] [B]" @c(white) " :���� ������");
			r = strval(cmd), cmd = strtok(cmdtext,idx), g = !strlen(cmd) ? r : strval(cmd), cmd = strtok(cmdtext,idx), b = !strlen(cmd) ? g : strval(cmd), newcol = (r * 16777216) + (g * 65536) + (b * 256) + 255;
			SendFormatToAll(lightblue," .%s����� ����� %s���� ��� " @c(white) "%s" @c(lblue) " ���� �� ��� ������ " @c(white) "%s" @c(lblue) " ������",GetColorAsString(tinfo[num][tColor]),GetColorAsString(newcol),tinfo[num][tName],GetName(playerid));
			tinfo[num][tColor] = newcol;
			for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pTeam] == num) SetPlayerColor(i,newcol);
			UpdateTextDraw(1);
			UpdateLadderGameForTeam(Color,num);
			UpdateSignboard(num+2,SB_Update);
			return 1;
		}
		if(!strcmp(cmd,"/goto",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /GoTo " @c(red) "[ID]" @c(white) " :���� ������");
			new id = strval(cmd), Float:p[3];
			if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
			if(pinfo[id][pTeam] == TEAM_V) return SendClientMessage(playerid,red," .�� ���� ������ �� ����");
			GetPlayerPos(id,p[0],p[1],p[2]);
			SetPlayerPos(playerid,p[0],p[1],p[2] + 2.0);
			return 1;
		}
		if(!strcmp(cmd,"/get",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /Get " @c(red) "[ID]" @c(white) " :���� ������");
			new id = strval(cmd), Float:p[3];
			if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
			if(pinfo[id][pTeam] == TEAM_V) return SendClientMessage(playerid,red," .�� ���� ���� ����");
			GetPlayerPos(playerid,p[0],p[1],p[2]);
			SetPlayerPos(id,p[0],p[1],p[2] + 2.0);
			return 1;
		}
		if(!strcmp(cmd,"/freeze",true) || !strcmp(cmd,"/unfreeze",true))
		{
			new unf = !strcmp(cmd,"/unfreeze",true);
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) if(unf) return SendClientMessage(playerid,white," /UnFreeze " @c(red) "[ID]" @c(white) " :���� ������"); else return SendClientMessage(playerid,white," /Freeze " @c(red) "[ID]" @c(white) " :���� ������");
			new id = strval(cmd);
			if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
			Freeze(id,!(bool:unf));
			SendFormat(playerid,white,unf ? (" .%s-����� �� ������ �") : (" .%s ����� ��"),GetName(id));
			SendClientMessage(id,white,unf ? (" .������ ����� �� ������ ���") : (" .������ ����� ����"));
			return 1;
		}
		if(!strcmp(cmd,"/teamskin",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd))
			{
				SendClientMessage(playerid,white," /TeamSkin " @c(red) "[Team ID 1/2/3]" @c(white) " [Skin ID / Def] :���� ������");
				SendClientMessage(playerid,white," /TeamSkin [Team ID 1/2/3] [Skin ID] - ����� ����� ������ ������� ����� ��� ����");
				return SendClientMessage(playerid,white," /TeamSkin [Team ID 1/2/3] Def - ����� ����� ������ ������� ����� �������");
			}
			new num = strval(cmd), skinid = 0;
			if(num < 1 && num > 3) return SendClientMessage(playerid,red," .���� ����� ����");
			num--, cmd = strrest(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /TeamSkin [Team ID 1/2/3] " @c(red) "[Skin ID / Def]" @c(white) " :���� ������");
			if(IsNumeric(cmd))
			{
				skinid = strval(cmd);
				if(!IsValidSkin(skinid)) return SendClientMessage(playerid,red," .���� ���� ����");
			}
			else skinid = (num == TEAM_A ? 271 : (num == TEAM_B ? 268 : 163));
			SendFormatToAll(lightblue," ." @c(lblue) "����� ���� " @c(white) "%d" @c(white) " %s" @c(lblue) " ���� �� ����� ������ �� ������ " @c(white) "%s" @c(lblue) " ������",skinid,tinfo[num][tName],GetName(playerid));
			SendClientMessageToAll(lightblue," (������� ��, ����� ���� ������� �������� ������ ���� �����, �� ��� ����� ������)");
			classes[num][cSkin] = skinid;
			dini_IntSet(ladderfile,skinKeys[num],skinid);
			for(new i = 0, c = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pTeam] == num) SetTimerEx("SetPlayerSkinByTimer",500 * (++c),0,"ii",i,skinid);
			return 1;
		}
		if(!strcmp(cmd,"/setskin",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /SetSkin " @c(red) "[ID]" @c(white) " [Skin ID] :���� ������");
			new id = strval(cmd), skinid = 0;
			if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /SetSkin [ID] " @c(red) "[Skin ID]" @c(white) " :���� ������");
			skinid = strval(cmd);
			if(!IsValidSkin(skinid)) return SendClientMessage(playerid,red," .���� ���� ����");
			SetPlayerSkin(id,skinid);
			SendFormat(playerid,white," .����� ���� %d %s ����� �� ����� ��",skinid,GetName(id));
			SendFormat(id,white," .������ ���� �� ����� ��� ����� ���� %d",skinid);
			return 1;
		}
		if(!strcmp(cmd,"/kick",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /Kick " @c(red) "[ID]" @c(white) " [Reason] :���� ������");
			new id = strval(cmd);
			if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
			if(IsPlayerMAdmin(id) && id != playerid) return SendClientMessage(playerid,red," .�� ���� ���� �� ������ �� ����� ���");
			cmd = strrest(cmdtext,idx);
			if(!strlen(cmd)) cmd = "������ �� ����� ����";
			SendFormatToAll(0xFF0000FF," *** " @c(red) "%s" @c(lightred) " has been kicked by " @c(red) "%s" @c(lightred) " [Reason: " @c(red) "%s" @c(lightred) "]",GetName(id),GetName(playerid),cmd);
			Kick(id);
			return 1;
		}
		if(!strcmp(cmd,"/ban",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /Ban " @c(red) "[ID]" @c(white) " [Reason] :���� ������");
			new id = strval(cmd);
			if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
			if(IsPlayerMAdmin(id) && id != playerid) return SendClientMessage(playerid,red," .�� ���� ���� �� ������ �� ����� ���");
			cmd = strrest(cmdtext,idx);
			if(!strlen(cmd)) cmd = "������ �� ����� ����";
			SendFormatToAll(0xFF0000FF," *** " @c(red) "%s" @c(lightred) " has been banned by " @c(red) "%s" @c(lightred) " [Reason: " @c(red) "%s" @c(lightred) "]",GetName(id),GetName(playerid),cmd);
			format(cmd,sizeof(cmd),"Ban from ladder mode [Admin: %s, Reason: %s]",GetName(playerid),cmd);
			BanEx(id,cmd);
			return 1;
		}
		if(!strcmp(cmd,"/gw",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /GW " @c(red) "[ID]" @c(white) " [Weapon ID] :���� ������");
			new id = strval(cmd), wid = 0, wname[32];
			if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /GW [ID] " @c(red) "[Weapon ID]" @c(white) " :���� ������");
			wid = strval(cmd);
			if(wid < 0 || wid > 46 || (wid >= 19 && wid <= 21)) return SendClientMessage(playerid,red," .���� ��� ����");
			pinfo[id][pGW] = 1;
			GetWeaponName(wid,wname,sizeof(wname));
			GivePlayerWeapon(id,wid,10000);
			SendFormat(playerid,white," .%s �� ���� %s-���� �",wname,GetName(id));
			SendFormat(id,white," .%s ������ ���� �� �� ����",wname);
			return 1;
		}
		if(!strcmp(cmd,"/gwlist",true))
		{
			new dialogString[1024], wname[32];
			for(new i = 0; i <= 46; i++)
			{
				if(i >= 19 && i <= 21) continue;
				GetWeaponName(i,wname,sizeof(wname));
				format(dialogString,sizeof(dialogString),"%s%d - %s%s",dialogString,i,wname,i == 46 ? ("") : ("\n"));
			}
			ShowPlayerDialog(playerid,DIALOG_NI,DIALOG_STYLE_MSGBOX,"����� ������",dialogString,"����","");
			return 1;
		}
		if(!strcmp(cmd,"/respawn",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /Respawn " @c(red) "[ID]" @c(white) " :���� ������");
			new id = strval(cmd);
			if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
			SendFormatToAll(0xFF0000FF," *** " @c(red) "%s" @c(lightred) " has been respawned by " @c(red) "%s",GetName(id),GetName(playerid));
			if(GetPlayerState(id) == PLAYER_STATE_SPECTATING) TogglePlayerSpectating(id,0);
			SpawnPlayer(id);
			return 1;
		}
		if(!strcmp(cmd,"/explode",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /Explode " @c(red) "[ID]" @c(white) " :���� ������");
			new id = strval(cmd), Float:p[3];
			if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
			GetPlayerPos(id,p[0],p[1],p[2]);
			CreateExplosion(p[0],p[1],p[2],6,0.0);
			SendFormatToAll(0xFF0000FF," *** " @c(red) "%s" @c(lightred) " has been exploded by " @c(red) "%s",GetName(id),GetName(playerid));
			return 1;
		}
		if(!strcmp(cmd,"/sethealth",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /SetHealth " @c(red) "[ID]" @c(white) " [Health] :���� ������");
			new id = strval(cmd), p;
			if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /SetHealth [ID] " @c(red) "[Health]" @c(white) " :���� ������");
			p = strval(cmd);
			if(p < 0 || p > 100) return SendClientMessage(playerid,red," .���� ����");
			SetPlayerHealth(id,float(p));
			SendFormat(playerid,white," .�� ����� �-%d %s-����� �",p,GetName(id));
			SendFormat(id,white," .������ ���� �� ����� ��� �-%d",p);
			return 1;
		}
		if(!strcmp(cmd,"/setarmour",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /SetArmour " @c(red) "[ID]" @c(white) " [Armour] :���� ������");
			new id = strval(cmd), p;
			if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /SetArmour [ID] " @c(red) "[Armour]" @c(white) " :���� ������");
			p = strval(cmd);
			if(p < 0 || p > 100) return SendClientMessage(playerid,red," .���� ����");
			SetPlayerArmour(id,float(p));
			SendFormat(playerid,white," .�� ���� �-%d %s-����� �",p,GetName(id));
			SendFormat(id,white," .������ ���� �� ���� ��� �-%d",p);
			return 1;
		}
		if(!strcmp(cmd,"/spec",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /Spec " @c(red) "[ID]" @c(white) " :���� ������"), SendClientMessage(playerid,white," /Spec Off - ������ �����");
			new id = strval(cmd);
			if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
			if(id == playerid) return SendClientMessage(playerid,red," .�� ���� ���� �� ������ ��� �� ����");
			TogglePlayerSpectating(playerid,1);
			PlayerSpectatePlayer(playerid,id);
			pinfo[playerid][pSpec] = id;
			SendFormat(playerid,white," .%s ����� ���� ��",GetName(id));
			return 1;
		}
		if(!strcmp(cmd,"/specoff",true))
		{
			if(GetPlayerState(playerid) != PLAYER_STATE_SPECTATING) return SendClientMessage(playerid,red," .��� �� �����");
			TogglePlayerSpectating(playerid,0);
			SpawnPlayer(playerid);
			pinfo[playerid][pSpec] = INVALID_PLAYER_ID;
			SendClientMessage(playerid,white," .����� �� �����");
			return 1;
		}
		if(!strcmp(cmd,"/map",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd))
			{
				SendClientMessage(playerid,white," /Map " @c(red) "[Change/Update]" @c(white) " :���� ������");
				SendClientMessage(playerid,white," /Map Change [Map ID] - ����� ��� ��� �����");
				SendClientMessage(playerid,white," /Map Update - ����� ���� �� ���� �������");
				return SendClientMessage(playerid,white," (Map ID = ���� ���� | /Maps - ����� ����� ����� ��������)");
			}
			if(!strcmp(cmd,"change"))
			{
				cmd = strtok(cmdtext,idx);
				if(!strlen(cmd)) return SendClientMessage(playerid,white," /Map Change " @c(red) "[Map ID]" @c(white) " :���� ������");
				new id = strval(cmd);
				if(!Map_Exists(id) || id < 1) return SendClientMessage(playerid,red," .���� ���� ������ ��� ��� �� �����");
				if(map[mID] == id) return SendClientMessage(playerid,red," .���� ��� ��� ����� �� ����");
				SendFormatToAll(lightblue," ...\"" @c(white) "%s" @c(lblue) "\" ����� ��� ���� " @c(white) "%s" @c(lblue) " ������",Map_GetInfo(id,"name"),GetName(playerid));
				if(map[mID] > 0)
				{
					new old = map[mID];
					Map_Unload();
					SendFormatToAll(lightblue," (����� ����� \"" @c(white) "%s" @c(lblue) "\" ����)",Map_GetInfo(old,"name"));
				}
				Map_Load(id);
				for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i))
				{
					if(pinfo[i][pSpawned]) SpawnPlayer(i);
					else ReturnToClassSelection(i);
				}
				SendFormatToAll(lightblue," !\"" @c(white) "%s" @c(lblue) "\" ����� ������ �� ���� ���� ���� " @c(white) "%s" @c(lblue) " ������",map[mName],GetName(playerid));
			}
			else if(!strcmp(cmd,"update"))
			{
				new old = map[mID];
				SendFormatToAll(lightblue," ...(��� ���� ����) \"" @c(white) "%s" @c(lblue) "\" ���� ���� ���� �� ���� " @c(white) "%s" @c(lblue) " ������",map[mName],GetName(playerid));
				Map_Unload();
				Map_Load(old);
				SendFormatToAll(lightblue," !\"" @c(white) "%s" @c(lblue) "\" ��� ���� ������ �� ���� " @c(white) "%s" @c(lblue) " ������",map[mName],GetName(playerid));
			}
			else SendClientMessage(playerid,red," .������ ��� �����");
			return 1;
		}
		if(!strcmp(cmd,"/jetpack",true))
		{
			if(GetPlayerSpecialAction(playerid) == SPECIAL_ACTION_USEJETPACK) return SendClientMessage(playerid,red," .��� ��� ����� ��'����");
			SetPlayerSpecialAction(playerid,SPECIAL_ACTION_USEJETPACK);
			return 1;
		}
		if(!strcmp(cmd,"/getall",true))
		{
			new Float:p[3];
			GetPlayerPos(playerid,p[0],p[1],p[2]);
			for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i)) SetPlayerPos(i,p[0] + float(random(2)-1),p[1] + float(random(2)-1),p[2] + 2.0);
			return 1;
		}
		if(!strcmp(cmd,"/antitk",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd))
			{
				SendClientMessage(playerid,white," /AntiTK " @c(red) "[On/Off/Refresh]" @c(white) " :���� ������");
				SendClientMessage(playerid,white," /AntiTK On - ����� ���� ��� ���");
				SendClientMessage(playerid,white," /AntiTK Off - ����� ���� ��� ���");
				return SendClientMessage(playerid,white," /AntiTK Refresh - ����� ���� ��� ��� (����� ���� ����) ���� �� �������");
			}
			if(!strcmp(cmd,"on"))
			{
				if(antiTK) return SendClientMessage(playerid,red," .������ ����� ��� ��� ��� �����");
				antiTK = true;
				for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i)) SetPlayerTeam(i,(pinfo[i][pTeam] == TEAM_A || pinfo[i][pTeam] == TEAM_B) ? pinfo[i][pTeam] : NO_TEAM);
				SendFormatToAll(lightblue," .����� �� ������ ����� ��� ��� " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
			}
			else if(!strcmp(cmd,"off"))
			{
				if(!antiTK) return SendClientMessage(playerid,red," .������ ����� ��� ��� �� �����");
				antiTK = false;
				for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i)) SetPlayerTeam(i,NO_TEAM);
				SendFormatToAll(lightblue," .���� �� ������ ����� ��� ��� " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
			}
			else if(!strcmp(cmd,"refresh"))
			{
				if(!antiTK) return SendClientMessage(playerid,red," .������ ����� ��� ��� �� �����");
				for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i)) SetPlayerTeam(i,(pinfo[i][pTeam] == TEAM_A || pinfo[i][pTeam] == TEAM_B) ? pinfo[i][pTeam] : NO_TEAM);
				SendFormatToAll(lightblue," .���� �� ����� ����� ��� ��� ���� �� ������� ����� ����� " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
			}
			else SendClientMessage(playerid,red," .������ ���� ��� ��� �����");
			return 1;
		}
		if(!strcmp(cmd,"/gmx",true))
		{
			SendFormatToAll(lightblue," .���� ���� ���� " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
			SendRconCommand("changemode ladder");
			SetTimer("GMX",200,0);
			return 1;
		}
		if(!strcmp(cmd,"/kickall",true))
		{
			SendFormatToAll(lightblue," .����� �� ���� ����� " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
			for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && !IsPlayerMAdmin(i)) Kick(i);
			return 1;
		}
		if(!strcmp(cmd,"/spassword",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd))
			{
				SendClientMessage(playerid,white," /SPassword " @c(red) "[Get/Set/Open]" @c(white) " :���� ������");
				SendClientMessage(playerid,white," /SPassword Get - ����� ������ ���� �������");
				SendClientMessage(playerid,white," /SPassword Set [New Password] - ����� ����� ����");
				return SendClientMessage(playerid,white," /SPassword Open - ����� ����");
			}
			new pass[64];
			if(!strcmp(cmd,"get",true))
			{
				GetServerVarAsString("password",pass,sizeof(pass));
				if(!strlen(pass) || (strlen(pass) == 1 && pass[0] == '0')) SendClientMessage(playerid,yellow," .���� ����");
				else SendFormat(playerid,yellow," ." @c(white) "%s" @c(yellow) " :����� ���� ���",pass);
			}
			else if(!strcmp(cmd,"set",true))
			{
				cmd = strtok(cmdtext,idx);
				if(!strlen(cmd)) return SendClientMessage(playerid,white," /SPassword Set [New Password] - ����� ����� ����");
				if(strlen(cmd) == 1 && cmd[0] == '0') return SendClientMessage(playerid,red," /SPassword Open :������ 0 ���� ����� ������ ����, ����� ����� �");
				SendFormat(playerid,yellow," ." @c(white) "%s" @c(yellow) " :����� �� ������ ���� �",cmd);
				format(pass,sizeof(pass),"password %s",cmd);
				SendRconCommand(pass);
			}
			else if(!strcmp(cmd,"open",true))
			{
				GetServerVarAsString("password",pass,sizeof(pass));
				if(!strlen(pass) || (strlen(pass) == 1 && pass[0] == '0')) SendClientMessage(playerid,red," .���� ��� ����");
				SendRconCommand("password 0");
				SendClientMessage(playerid,yellow," .���� �� ����");
			}
			else SendClientMessage(playerid,red," .������ ����� ��� �����");
			return 1;
		}
		if(!strcmp(cmd,"/sawnoff22",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd))
			{
				SendClientMessage(playerid,white," /SawnOff22 " @c(red) "[On/Off]" @c(white) " :���� ������");
				SendClientMessage(playerid,white," /SawnOff22 On - ����� ������ ������ ����� �2-2");
				return SendClientMessage(playerid,white," /SawnOff22 Off - ����� ������ ����� �2-2");
			}
			if(!strcmp(cmd,"on"))
			{
				if(sawn22) return SendClientMessage(playerid,red," .������ ������ �2-2 ��� �����");
				sawn22 = true;
				SendFormatToAll(lightblue," .����� �� ������ ������ ����� �2-2 " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
			}
			else if(!strcmp(cmd,"off"))
			{
				if(!sawn22) return SendClientMessage(playerid,red," .������ ������ �2-2 �� �����");
				sawn22 = false;
				SendFormatToAll(lightblue," .���� �� ������� ������ ����� �2-2 " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
			}
			else SendClientMessage(playerid,red," .������ 2-2 �����");
			return 1;
		}
		if(!strcmp(cmd,"/akill",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /AKill " @c(red) "[ID]" @c(white) " :���� ������");
			new id = strval(cmd);
			if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
			SendFormatToAll(0xFF0000FF," *** " @c(red) "%s" @c(lightred) " has been killed by " @c(red) "%s",GetName(id),GetName(playerid));
			SetPlayerHealth(id,0.0);
			return 1;
		}
		if(!strcmp(cmd,"/monitor",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd))
			{
				SendClientMessage(playerid,white," /Monitor " @c(red) "[On/Off/Filter/Help]" @c(white) " :���� ������");
				SendClientMessage(playerid,white," /Monitor On - ����� ��������");
				SendClientMessage(playerid,white," /Monitor Off - ����� ��������");
				SendClientMessage(playerid,white," /Monitor Filter [Text] - ����� ��������");
				return SendClientMessage(playerid,white," /Monitor Help - ����");
			}
			if(!strcmp(cmd,"on"))
			{
				if(monitor) return SendClientMessage(playerid,red," .�������� ��� ����");
				monitor = true;
				Monitor(playerid,"�������� �����");
			}
			else if(!strcmp(cmd,"off"))
			{
				if(!monitor) return SendClientMessage(playerid,red," .�������� �� ����");
				Monitor(playerid,"�������� �����");
				monitor = false, monitorFilter[0] = EOS;
			}
			else if(!strcmp(cmd,"filter"))
			{
				if(!monitor) return SendClientMessage(playerid,red," .�������� �� ����");
				cmd = strrest(cmdtext,idx);
				if(!strlen(cmd)) return SendClientMessage(playerid,white," /Monitor Filter " @c(red) "[Text]" @c(white) " :���� ������");
				if(strlen(cmd) > 30) return SendClientMessage(playerid,red," .���� ����� ���� ����� �� 30 ����");
				format(monitorFilter,sizeof(monitorFilter),cmd);
				Monitor(playerid,":������ ����� ����� ����, ��� ����� �������� ����");
			}
			else if(!strcmp(cmd,"help"))
			{
				SendClientMessage(playerid,blue,@header("SAMP-IL Ladder Mode - Monitor"));
				SendClientMessage(playerid,yellow," .�������� ���� ������ �������� �� ������ ����");
				SendClientMessage(playerid,orange,@cmd("/Monitor [On/Off]","���� ����� �� ������ ���� �� ����� ������"));
				SendClientMessage(playerid,red," :������ ���� ����� ����� ��������� ���� ���� (�� ����� ���) ������. �������� ����� ��");
				SendClientMessage(playerid,green," > ����� ������ ������ ������� �����");
				SendClientMessage(playerid,green," > Desert Eagle ���� C-Bug �� ����� Sawnoff ����� �2-2 ����");
				SendClientMessage(playerid,green," > ...����� ��'���� ����");
				SendClientMessage(playerid,grey," .���� ���� ��� ��������. ���� ������ ���� ������ ���� ���� �� ����� ���� Filter ������� ��������");
				SendClientMessage(playerid,grey," \"Joypad\" ���� �� �� ������� ������� �� ����� - /Monitor Filter Joypad :������");
			}
			else SendClientMessage(playerid,red," .������ ���� ��� ��� �����");
			return 1;
		}
		if(!strcmp(cmd,"/pingtest",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd))
			{
				SendClientMessage(playerid,white," /PingTest " @c(red) "[Client/Server/ID]" @c(white) " :���� ������");
				SendClientMessage(playerid,white," /PingTest Client - ����� ����� �� �������");
				SendClientMessage(playerid,white," /PingTest Server - ����� ����� �� ����");
				return SendClientMessage(playerid,white," /PingTest [ID] - ����� ����� �� ���� ������");
			}
			if(IsNumeric(cmd))
			{
				new id = strval(cmd);
				if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
				SendFormat(playerid,white," .���� �%s %s �����",GetPlayerAveragePing(id) > MAX_AVERAGE_PING ? ("����") : ("�� ����"),GetName(id));
			}
			else if(!strcmp(cmd,"client")) if(!GoClientPingTest()) SendClientMessage(playerid,red," .�� ���� ����� ��� �������");
			else if(!strcmp(cmd,"server")) if(!GoServerPingTest()) SendClientMessage(playerid,red," .�� ���� ����� ����");
			else SendClientMessage(playerid,red," .������ ����� ����� �����");
			return 1;
		}
		if(!strcmp(cmd,"/settime",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /SetTime " @c(red) "[Time 0-23]" @c(white) " :���� ������");
			new h = strval(cmd);
			if(h < 0 && h > 23) return SendClientMessage(playerid,red," .��� �����");
			SetWorldTime(h);
			SendFormatToAll(blue," .���� �� ���� �%02d:00 %s ������",h,GetName(playerid));
			return 1;
		}
		if(!strcmp(cmd,"/tts",true))
		{
			cmd = strrest(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /TTS " @c(red) "[Text]" @c(white) " :���� ������");
			if(strlen(cmd) > 75) return SendClientMessage(playerid,red," .���� ����� ���� ����� �� 75 ����");
			for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i)) TTS(i,cmd);
			return 1;
		}
		if(!strcmp(cmd,"/mtts",true))
		{
			for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i)) StopAudioStreamForPlayer(i);
			return 1;
		}
		if(!strcmp(cmd,"/joypad",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd)) return SendClientMessage(playerid,white," /Joypad " @c(red) "[ID]" @c(white) " :���� ������");
			new id = strval(cmd);
			if(!IsPlayerConnected(id)) return SendClientMessage(playerid,red," .����� ����");
			SendFormat(playerid,green," ��� �'����: %s",pinfo[playerid][pJoypad] ? ("��") : ("���"));
			return 1;
		}
		if(!strcmp(cmd,"/score",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd))
			{
				SendClientMessage(playerid,white," /Score " @c(red) "[Kills/Damage]" @c(white) " :���� ������");
				SendClientMessage(playerid,white," /Score Kills - ������ ����� ��� ������");
				SendClientMessage(playerid,white," /Score Damage - ������ ����� ��� �����");
				return SendClientMessage(playerid,red," (!��� ��: ����� �� ����� ��� ����� �� ������� �� ����)");
			}
			new itsName[32];
			if(!strcmp(cmd,"kills"))
			{
				if(scoreStatus == SCORE_KILLS) return SendClientMessage(playerid,red," .����� ������� ��� ������ �� ������ ��");
				scoreStatus = SCORE_KILLS, itsName = "������";
			}
			else if(!strcmp(cmd,"damage"))
			{
				if(scoreStatus == SCORE_DAMAGES) return SendClientMessage(playerid,red," .����� ������� ��� ������ �� ������ ��");
				scoreStatus = SCORE_DAMAGES, itsName = "������";
			}
			else return SendClientMessage(playerid,red," .������ ����� ������ �����");
			for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i)) SetPlayerScore(i,0);
			SendFormatToAll(lightblue," .��� �� ����� ������� ���� ��� %s ������ " @c(white) "%s" @c(lblue) " ������",itsName,GetName(playerid));
			return 1;
		}
		if(!strcmp(cmd,"/signs",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd))
			{
				SendClientMessage(playerid,white," /Signs " @c(red) "[Create/Remove/RemoveAll/Refresh/Adv]" @c(white) " :���� ������");
				SendClientMessage(playerid,white," /Signs Create [Sign ID] - ����� ���");
				SendClientMessage(playerid,white," /Signs Remove [Sign ID] - ���� ���");
				SendClientMessage(playerid,white," /Signs RemoveAll - ���� �� ������");
				SendClientMessage(playerid,white," /Signs Refresh - ����� �� ������ ����");
				return SendClientMessage(playerid,white," /Signs Adv [Text] - ����� ���� ���� ������ ������");
			}
			if(!strcmp(cmd,"create"))
			{
				cmd = strtok(cmdtext,idx);
				if(!strlen(cmd)) return SendFormat(playerid,white," /Signs Create " @c(red) "[Signboard ID: 1 - %d]" @c(white) " :���� ������",sizeof(Signboards));
				new id = strval(cmd), k[32];
				if(id < 1 || id > sizeof(Signboards)) return SendClientMessage(playerid,red," .���� ��� ����");
				id--;
				if(UpdateSignboard(id,SB_CheckIfValid)) return SendFormat(playerid,red," .���� �� ��� ���� ��� ���� %d",id+1);
				format(string,sizeof(string),laddermapsdir "%d.ini",map[mID]);
				format(k,sizeof(k),"Signboard%d",id);
				if(!dini_Isset(string,k)) return SendFormat(playerid,red," .���� �� �� ����� ��� ���� %d",id+1);
				UpdateSignboard(id,SB_Create);
				SendFormatToAll(lightblue," .���� ���� �� ��� ���� #%d " @c(white) "%s" @c(lblue) " ������",id+1,GetName(playerid));
			}
			else if(!strcmp(cmd,"remove"))
			{
				cmd = strtok(cmdtext,idx);
				if(!strlen(cmd)) return SendFormat(playerid,white," /Signs Remove " @c(red) "[Signboard ID: 1 - %d]" @c(white) " :���� ������",sizeof(Signboards));
				new id = strval(cmd);
				if(id < 1 || id > sizeof(Signboards)) return SendClientMessage(playerid,red," .���� ��� ����");
				id--;
				if(!UpdateSignboard(id,SB_CheckIfValid)) return SendFormat(playerid,red," .���� �� �� ���� ���� ��� ���� %d",id+1);
				UpdateSignboard(id,SB_Remove);
				SendFormatToAll(lightblue," .��� ����� �� ��� ���� #%d " @c(white) "%s" @c(lblue) " ������",id+1,GetName(playerid));
			}
			else if(!strcmp(cmd,"removeall"))
			{
				new c = 0;
				for(new i = 0; i < sizeof(Signboards); i++) if(UpdateSignboard(i,SB_CheckIfValid))
				{
					UpdateSignboard(i,SB_Remove);
					c++;
				}
				if(!c) return SendClientMessage(playerid,red," .��� ����� ���� ����");
				SendFormatToAll(lightblue," .��� ����� �� �� ������ " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
			}
			else if(!strcmp(cmd,"refresh"))
			{
				new c = 0;
				for(new i = 0; i < sizeof(Signboards); i++) if(UpdateSignboard(i,SB_CheckIfValid))
				{
					UpdateSignboard(i,SB_Remove);
					UpdateSignboard(i,SB_Create);
					c++;
				}
				if(!c) return SendClientMessage(playerid,red," .��� ����� ���� ����");
				SendFormatToAll(lightblue," .����� �� �� ������ ���� " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
			}
			else if(!strcmp(cmd,"adv"))
			{
				cmd = strrest(cmdtext,idx);
				if(!strlen(cmd)) return SendClientMessage(playerid,white," /Signs Adv " @c(red) "[Text]" @c(white) " :���� ������");
				if(strlen(cmd) > 50) return SendClientMessage(playerid,red," .���� ����� ���� ����� �� 50 ����");
				format(advText,sizeof(advText),cmd);
				UpdateSignboard(SIGNBOARD_ADV,SB_Update);
				SendFormatToAll(lightblue," .���� �� ����� ���� ������ " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
			}
			else SendClientMessage(playerid,red," .������ ��� �����");
			return 1;
		}
		if(!strcmp(cmd,"/cbug",true))
		{
			cmd = strtok(cmdtext,idx);
			if(!strlen(cmd))
			{
				SendClientMessage(playerid,white," /CBug " @c(red) "[On/Off]" @c(white) " :���� ������");
				SendClientMessage(playerid,white," /CBug On - CBug-����� ������ ������ �");
				return SendClientMessage(playerid,white," /CBug Off - ����� ������ �����");
			}
			if(!strcmp(cmd,"on"))
			{
				if(cbug) return SendClientMessage(playerid,red," .��� ����� CBug-������� ������ �");
				cbug = true;
				SendFormatToAll(lightblue," .CBug-����� �� ������ ������ ����� � " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
			}
			else if(!strcmp(cmd,"off"))
			{
				if(!cbug) return SendClientMessage(playerid,red," .�� ����� CBug-������� ������ �");
				cbug = false;
				SendFormatToAll(lightblue," .CBug-���� �� ������� ������ ����� � " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
			}
			else SendClientMessage(playerid,red," .����� CBug ������");
			return 1;
		}
		if(!strcmp(cmd,"/alogout",true))
		{
			SendClientMessage(playerid,green," .������ ������");
			pinfo[playerid][pAdmin] = 0;
			UpdateLadderGame(Admins);
			if(pinfo[playerid][pTeam] == TEAM_M)
			{
				pinfo[playerid][pTeam] = INVALID_TEAM;
				ReturnToClassSelection(playerid);
				SetPlayerHealth(playerid,0.0);
			}
			return 1;
		}
	}
	return 0;
}
public OnDialogResponse(playerid,dialogid,response,listitem,inputtext[])
{
	switch(dialogid)
	{
		case DIALOG_FUNCS: if(response)
		{
			listitem++;
			pinfo[playerid][pFunc] = listitem;
			SendFormat(playerid,yellow," ." @c(red) "%s" @c(yellow) " ���� ������",FuncName(listitem));
			TTS(playerid,FuncName(listitem));
		}
		case DIALOG_TCOLORS: if(response)
		{
			SendFormatToAll(lightblue," .%s����� ����� %s���� ��� " @c(white) "%s" @c(lblue) " ���� �� ��� ������ " @c(white) "%s" @c(lblue) " ������",GetColorAsString(tinfo[pinfo[playerid][pParam]][tColor]),GetColorAsString(teamColors[listitem][tcColor]),tinfo[pinfo[playerid][pParam]][tName],GetName(playerid));
			tinfo[pinfo[playerid][pParam]][tColor] = teamColors[listitem][tcColor];
			TextDrawColor(tinfo[pinfo[playerid][pParam]][tText],tinfo[pinfo[playerid][pParam]][tColor]);
			for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pTeam] == pinfo[playerid][pParam]) SetPlayerColor(i,teamColors[listitem][tcColor]);
			UpdateTextDraw(1);
			UpdateLadderGameForTeam(Color,pinfo[playerid][pParam]);
			UpdateSignboard(pinfo[playerid][pParam]+2,SB_Update);
		}
	}
	return 1;
}
public OnPlayerUpdate(playerid)
{
	pinfo[playerid][pIdle] = 0;
	if(!sawn22 || !cbug)
	{
		new tmp = GetPlayerWeapon(playerid);
		if(tmp == pinfo[playerid][pWeapon])
		{
			if(!cbug)
			{
				tmp = GetDeagleAmmo(playerid);
				if(tmp < pinfo[playerid][pAmmo][1]) pinfo[playerid][pCBugCheck]++;
				pinfo[playerid][pAmmo][1] = tmp;
			}
		}
		else
		{
			if((pinfo[playerid][pWeapon] == 26 || tmp == 26) && !sawn22)
			{
				new loss = pinfo[playerid][pAmmo][0] - GetSawnoffAmmo(playerid);
				if(loss == 2)
				{
					pinfo[playerid][p22Warns]++;
					if(pinfo[playerid][p22Warns] >= 2) Monitor(playerid,"����� �2-2");
				}
				pinfo[playerid][pAmmo][0] = GetSawnoffAmmo(playerid);
			}
			pinfo[playerid][pWeapon] = tmp;
		}
	}
	if(pinfo[playerid][pJoypad] == 0)
	{
		new keys, updown, leftright;
		GetPlayerKeys(playerid,keys,updown,leftright);
		if((updown != 128 && updown != 0 && updown != -128) || (leftright != 128 && leftright != 0 && leftright != -128)) pinfo[playerid][pJoypad] = 1;
	}
	if(pinfo[playerid][pTeam] == TEAM_V && pinfo[playerid][pCamera][0] != CAMERA_NONE)
	{
		new k[3];
		GetPlayerKeys(playerid,k[0],k[1],k[2]);
		switch(pinfo[playerid][pCamera][0])
		{
			case CAMERA_FLY:
			{
				if(pinfo[playerid][pCamera][1] > 0 && (GetTickCount() - pinfo[playerid][pCamera][2]) > 100) MoveCamera(playerid);
				if(pinfo[playerid][pCamera][3] != k[1] || pinfo[playerid][pCamera][4] != k[2])
				{
					if((pinfo[playerid][pCamera][3] != 0 || pinfo[playerid][pCamera][4] != 0) && k[1] == 0 && k[2] == 0)
					{
						StopPlayerObject(playerid,pinfo[playerid][pFlyObject]);
						pinfo[playerid][pCamera][1] = 0;
						pinfo[playerid][pMS] = 0.0;
					}
					else
					{
						if(k[2] < 0)
						{
							if(k[1] < 0) pinfo[playerid][pCamera][1] = 5; // Forward Left
							else if(k[1] > 0) pinfo[playerid][pCamera][1] = 7; // Back Left
							else pinfo[playerid][pCamera][1] = 3; // Left
						}
						else if(k[2] > 0)
						{
							if(k[1] < 0) pinfo[playerid][pCamera][1] = 6; // Forward Right
							else if(k[1] > 0) pinfo[playerid][pCamera][1] = 8; // Back Right
							else pinfo[playerid][pCamera][1] = 4; // Right
						}
						else if(k[1] < 0) pinfo[playerid][pCamera][1] = 1; // Forward
						else if(k[1] > 0) pinfo[playerid][pCamera][1] = 2; // Back
						MoveCamera(playerid);
					}
				}
				pinfo[playerid][pCamera][3] = k[1], pinfo[playerid][pCamera][4] = k[2];
			}
			case CAMERA_SPEC: if((k[1] < 0 || k[1] > 0) || (k[2] < 0 || k[2] > 0)) ViewerSpectating(playerid,k[1] > 0 || k[2] > 0);
		}
		return 0;
	}
	return 1;
}
public OnPlayerStateChange(playerid,newstate,oldstate)
{
	if(newstate == PLAYER_STATE_ONFOOT || newstate == PLAYER_STATE_SPAWNED) for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pSpec] == playerid)
	{
		TogglePlayerSpectating(i,1);
		PlayerSpectatePlayer(i,playerid);
	}
	return 1;
}
public OnPlayerStreamOut(playerid,forplayerid)
{
	if(GetPlayerState(forplayerid) == PLAYER_STATE_SPECTATING && pinfo[forplayerid][pSpec] == playerid)
	{
		TogglePlayerSpectating(forplayerid,1);
		PlayerSpectatePlayer(forplayerid,playerid);
	}
	return 1;
}
public OnPlayerTakeDamage(playerid, issuerid, Float:amount, weaponid)
{
	UpdateHPStatus(playerid,0-amount);
	if(issuerid != INVALID_PLAYER_ID)
	{
		UpdateHPStatus(issuerid,amount);
		if(scoreStatus == SCORE_DAMAGES) SetPlayerScore(issuerid,GetPlayerScore(issuerid) + floatround(amount));
	}
	//SendFormatToAll(grey,"%s damaged by %s (%.4f)",GetName(playerid),GetName(issuerid),amount);
	return 1;
}
public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if(fastStop > 0 && gameStarted && !pause && newkeys == KEY_NO && IsPlayerMAdmin(playerid))
	{
		pause = true;
		for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i))
		{
			Freeze(i,true);
			SetCameraBehindPlayer(i);
		}
		GameTextForAll("~r~game paused!",3000,4);
		SendFormatToAll(lightblue," :��� �� ����� ������ ���� " @c(white) "%s" @c(lblue) " ������",GetName(playerid));
		SendClientMessageToAll(white,fastStopReason);
		fastStop = 0, fastStopReason[0] = EOS;
	}
	return 1;
}
forward Contents();
public Contents()
{
	timerDiving++;
	if(timerDiving % 20 == 0) for(new i = TEAM_A; i <= TEAM_B; i++) UpdateLadderGameForTeam(Score,i);
	if(!pause && gameStarted)
	{
		if(!timeLeft)
		{
			SendClientMessageToAll(white," !����� ������");
			ShowTeamsScore(MAX_PLAYERS,1,1);
			new admins[128];
			for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pTeam] == TEAM_M) format(admins,sizeof(admins),"%s%s%s",admins,!strlen(admins) ? ("") : (","),GetName(i));
			if(tinfo[TEAM_A][tScore] == tinfo[TEAM_B][tScore])
			{
				if(!tinfo[TEAM_A][tScore]) SendClientMessageToAll(white," !�� ����� �� ������ ����");
				else SendFormatToAll(white," !%s%s" @c(white) " & " @c(white) "%s%s" @c(white) " �� ������� ��� �������",GetColorAsString(tinfo[TEAM_A][tColor]),tinfo[TEAM_A][tName],GetColorAsString(tinfo[TEAM_B][tColor]),tinfo[TEAM_B][tName]);
				AddLog("no winner|%s|%s|%s|%d",tinfo[TEAM_A][tName],tinfo[TEAM_B][tName],admins,tinfo[TEAM_A][tScore]);
			}
			else
			{
				if(tinfo[tinfo[TEAM_B][tScore] > tinfo[TEAM_A][tScore]][tScore] > dini_Int(ladderfile,"BestClanScore"))
				{
					dini_IntSet(ladderfile,"BestClanScore",tinfo[tinfo[TEAM_B][tScore] > tinfo[TEAM_A][tScore]][tScore]);
					dini_Set(ladderfile,"BestClan",tinfo[tinfo[TEAM_B][tScore] > tinfo[TEAM_A][tScore]][tName]);
				}
				SendFormatToAll(white," !��� ������ ������ %s%s" @c(white) " ������",GetColorAsString(tinfo[tinfo[TEAM_B][tScore] > tinfo[TEAM_A][tScore]][tColor]),tinfo[tinfo[TEAM_B][tScore] > tinfo[TEAM_A][tScore]][tName]);
				new gtstr[64];
				format(gtstr,sizeof(gtstr),"~r~the ~y~win ~r~clan ~y~is...~n~~r~clan ~y~%s~r~!~y~!~r~!",tinfo[tinfo[TEAM_B][tScore] > tinfo[TEAM_A][tScore]][tName]);
				GameTextForAll(gtstr,7500,4);
				AddLog("%s|%s|%s|%s|%d|%d",tinfo[TEAM_A][tName],tinfo[TEAM_B][tName],admins,tinfo[tinfo[TEAM_B][tScore] > tinfo[TEAM_A][tScore]][tName],tinfo[TEAM_A][tScore],tinfo[TEAM_B][tScore]);
			}
			for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i))
			{
				ResetPlayerWeapons(i);
				SetPlayerHealth(i,100.0);
				SetPlayerArmour(i,100.0);
				pinfo[i][pFunc] = 0, pinfo[i][pKills] = 0, pinfo[i][pDeaths] = 0, pinfo[i][pDamaged] = 0.0, pinfo[i][pAttacked] = 0.0;
			}
			gameStarted = false;
			UpdateLadderGame(Active);
		}
		else if(timeLeft > 0)
		{
			if(timeLeft % 60 == 0)
			{
				if(timeLeft == 60) SendClientMessageToAll(yellow," .����� ������ ���� ���"); else SendFormatToAll(yellow," .����� ������ ���� " @c(white) "%d" @c(yellow) " ����",timeLeft/60);
				UpdateLadderGame(TimeLeft);
			}
			if(timeLeft % 150 == 0) if((timeLeft / 150) % 2 == 0) GoClientPingTest(); else GoServerPingTest();
		}
		timeLeft--;
		UpdateTimeTextDraw();
	}
	new position[MAX_PLAYERS][EveryonesPositionData], positions = 0, pi = 0;
	GetEveryonesPositions(position,positions);
	for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i))
	{
		if(timerDiving % 2 == 0)
		{
			pi = GetPlayerPing(i);
			if(pi > 1 && pi < 10000)
			{
				if(pinfo[i][pPings] < MAX_PINGTESTS) pinfo[i][pPings] = 0;
				pinfo[i][pPing][pinfo[i][pPings]++] = pi;
			}
		}
		if(timerDiving % 3 == 0 && pinfo[i][pJoypad] > 0) pinfo[i][pJoypad]--;
		if(timerDiving % 6 == 0) if(pinfo[i][p22Warns] > 0) pinfo[i][p22Warns] = 0;
		if(pinfo[i][pAskedPause] > 0) pinfo[i][pAskedPause]--;
		if(pinfo[i][pTeam] == TEAM_V && pinfo[i][pV] > 0)
		{
			pinfo[i][pV]--;
			if(!pinfo[i][pV]) SetCameraMode(i,pinfo[i][pCamera][0]);
		}
		if(pinfo[i][pSpawned]) for(new j = 0; j < positions; j++) if(position[j][epID] != i && IsPlayerAimingAt(i,position[j][epX],position[j][epY],position[j][epZ]+0.298,0.08))
		{
			pinfo[i][pJoypad]++;
			if(pinfo[i][pJoypad] >= 5) Monitor(i,"Joypad");
		}
		if(pinfo[i][pKillingSpree][0] > 0) pinfo[i][pKillingSpree][0]--;
		if(pinfo[i][pKillingSpree][1] > 0 && !pinfo[i][pKillingSpree][0]) pinfo[i][pKillingSpree][1] = 0;
		if(fastStop > 0) if(!(--fastStop)) fastStopReason[0] = EOS;
		if(pinfo[i][pIdle] > MIN_IDLE_TIME)
		{
			format(string,sizeof(string),"AFK: %02d:%02d:%02d",pinfo[i][pIdle]/3600,(pinfo[i][pIdle]/60)-((pinfo[i][pIdle]/3600)*60),pinfo[i][pIdle]%60);
			SetPlayerChatBubble(i,string,0xFF6A6AFF,50.0,1200);
			if(!pinfo[i][pAFK])
			{
				pinfo[i][pAFK] = 1;
				SendFormatToAll(blue," *** AFK-���� � " @c(white) "%s",GetName(i));
				if(gameStarted)
				{
					format(string,sizeof(string),"���� �� ��� �� ����� ��� %s",GetName(i));
					ShouldPause(string);
				}
			}
		}
		else if(!pinfo[i][pIdle] && pinfo[i][pAFK])
		{
			SendFormatToAll(blue," *** ��� ����� " @c(white) "%s",GetName(i));
			pinfo[i][pAFK] = 0;
		}
		if(!pinfo[i][pFrozen] && pinfo[i][pSpawned]) pinfo[i][pIdle]++;
	}
	return 1;
}
forward BackgroundWorker();
public BackgroundWorker()
{
	for(new i = 0; i < MAX_PLAYERS; i++)
	{
		if(pinfo[i][pCBugCheck] > 0 && !cbug)
		{
			if(pinfo[i][pCBugCheck] >= 2)
			{
				pinfo[i][pCBugCheck] = 0;
				Monitor(i,"Desert Eagle C-Bug");
			}
			else pinfo[i][pCBugCheck]--;
		}
	}
	return 1;
}
forward StartTheGame();
public StartTheGame()
{
	new cdtext[64];
	if(cd[0] > 0)
	{
		/*new cols[] = {'g','b','w','y','p','l'};
		format(cdtext,sizeof(cdtext),"~r~The war will~n~start in ~%c~%s%d",cols[random(sizeof(cols))],!random(2) ? ("~h~") : (""),cd[0]);*/
		format(cdtext,sizeof(cdtext),"~r~The war will~n~start in ~%c~%d",!(cd[0] % 2) ? 'g' : 'b',cd[0]);
		GameTextForAll(cdtext,1000,4);
		cd[0]--;
	}
	else
	{
		GameTextForAll("~r~go!",2500,4);
		KillTimer(cd[1]);
		for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i))
		{
			Freeze(i,false);
			SpawnPlayer(i);
			SetPlayerArmour(i,100.0);
		}
		UpdateSignboard(SIGNBOARD_FULL,SB_Update);
		SendClientMessageToAll(lightblue," !!!����� ���, ������ �����");
		gameStarted = true;
		UpdateLadderGame(Active);
	}
}
forward GMX();
public GMX()
{
	if(!exited) GameModeExit();
	return 1;
}
forward SetPlayerSkinByTimer(playerid,skinid);
public SetPlayerSkinByTimer(playerid,skinid) return SetPlayerSkin(playerid,skinid);
forward HideHPStatus(playerid,k);
public HideHPStatus(playerid,k)
{
	if(k) KillTimer(pinfo[playerid][pHPTimer]);
	PlayerTextDrawHide(playerid,pinfo[playerid][pHPStatus]);
	PlayerTextDrawDestroy(playerid,pinfo[playerid][pHPStatus]);
	pinfo[playerid][pHPTimer] = -1;
	return 1;
}
forward HideKSText(playerid);
public HideKSText(playerid)
{
	TextDrawHideForPlayer(playerid,pinfo[playerid][pKSText]);
	TextDrawDestroy(pinfo[playerid][pKSText]);
	pinfo[playerid][pKillingSpree][2] = -1;
	return 1;
}
stock strtok(const __string[], &index)
{   // by CompuPhase, improved by me
	new length = strlen(__string);
	while((index < length) && (__string[index] <= ' ')) index++;
	new offset = index, result[20];
	while((index < length) && (__string[index] > ' ') && ((index - offset) < (sizeof(result) - 1))) result[index - offset] = __string[index], index++;
	result[index - offset] = EOS;
	return result;
}
stock strrest(const __string[], index)
{   // by CompuPhase, improved by me
	new length = strlen(__string), offset = index, result[128];
	while((index < length) && ((index - offset) < (sizeof(result) - 1)) && (__string[index] > '\r')) result[index - offset] = __string[index], index++;
	result[index - offset] = EOS;
	if(result[0] == ' ' && __string[0] != ' ') strdel(result,0,1);
	return result;
}
stock GetName(playerid)
{
	new n[MAX_PLAYER_NAME];
	GetPlayerName(playerid,n,sizeof(n));
	return n;
}
stock ResetInfo(playerid)
{
	pinfo[playerid][pTeam] = INVALID_TEAM;
	pinfo[playerid][pFunc] = 0;
	pinfo[playerid][pKills] = 0;
	pinfo[playerid][pDeaths] = 0;
	UpdateLadderGame(Players);
	if(pinfo[playerid][pAdmin]) UpdateLadderGame(Admins);
	pinfo[playerid][pAdmin] = 0;
	pinfo[playerid][pParam] = 0;
	pinfo[playerid][pSpawned] = 0;
	pinfo[playerid][pWeapon] = 0;
	pinfo[playerid][pAmmo] = {0,0};
	pinfo[playerid][p22Warns] = 0;
	pinfo[playerid][pGW] = 0;
	pinfo[playerid][pSpec] = INVALID_PLAYER_ID;
	pinfo[playerid][pPings] = 0;
	pinfo[playerid][pSkin] = 300;
	pinfo[playerid][pAskedPause] = 0;
	pinfo[playerid][pJoypad] = 0;
	pinfo[playerid][pDamaged] = 0.0;
	pinfo[playerid][pAttacked] = 0.0;
	pinfo[playerid][pHPStatus] = PlayerText:INVALID_TEXT_DRAW;
	pinfo[playerid][pHPTimer] = -1;
	pinfo[playerid][pKillingSpree] = {0,0,-1};
	pinfo[playerid][pKSText] = Text:INVALID_TEXT_DRAW;
	pinfo[playerid][pIdle] = 0;
	pinfo[playerid][pCBugCheck] = 0;
	pinfo[playerid][pAFK] = 0;
	pinfo[playerid][pFrozen] = 0;
	pinfo[playerid][pV] = 0;
	pinfo[playerid][pCamera] = {CAMERA_NONE,0,0,0,0};
	pinfo[playerid][pFlyObject] = INVALID_OBJECT_ID;
	pinfo[playerid][pMS] = 0.0;
	return 1;
}
stock IsPlayerMAdmin(playerid) return pinfo[playerid][pAdmin] || IsPlayerAdmin(playerid);
stock UpdateTextDraw(cc = 0)
{
	new tdstr[64];
	for(new i = 0; i < FIGHT_TEAMS; i++)
	{
		format(tdstr,sizeof(tdstr),"%s ~l~- ~w~%d",tinfo[i][tName],tinfo[i][tScore]);
		if(cc)
		{
			TextDrawHideForAll(tinfo[i][tText]);
			TextDrawDestroy(tinfo[i][tText]);
			tinfo[i][tText] = TextDrawCreate(146.000000,i == TEAM_A ? 387.000000 : 402.000000,tdstr);
			TextDrawBackgroundColor(tinfo[i][tText],255);
			TextDrawFont(tinfo[i][tText],1);
			TextDrawLetterSize(tinfo[i][tText],0.480000,1.400000);
			TextDrawColor(tinfo[i][tText],tinfo[i][tColor]);
			TextDrawSetOutline(tinfo[i][tText],1);
			TextDrawSetProportional(tinfo[i][tText],1);
			TextDrawShowForAll(tinfo[i][tText]);
		}
		else TextDrawSetString(tinfo[i][tText],tdstr);
	}
}
stock UpdateTimeTextDraw()
{
	new tdstr[128];
	if(timeLeft <= 0 || !gameStarted) format(tdstr,sizeof(tdstr),"~n~---");
	else format(tdstr,sizeof(tdstr),"~n~~%c~%02d:%02d",!(timeLeft/60) ? 'r' : 'w',timeLeft/60,timeLeft%60);
	if(!(timeLeft%60)) UpdateSignboard(SIGNBOARD_FULL,SB_Update);
	TextDrawSetString(timetd,tdstr);
}
stock GetColorAsString(color)
{
	new ret[16];
	format(ret,sizeof(ret),"{%s%s%s}",IntToHex_((color >> 24) & 0x000000FF),IntToHex_((color >> 16) & 0x000000FF),IntToHex_((color >> 8) & 0x000000FF));
	return ret;
}
stock IntToHex_(num)
{
	new ret[3];
	switch(num)
	{
		case 0: ret = "00";
		case 1: ret = "01";
		case 2: ret = "02";
		case 3: ret = "03";
		case 4: ret = "04";
		case 5: ret = "05";
		case 6: ret = "06";
		case 7: ret = "07";
		case 8: ret = "08";
		case 9: ret = "09";
		case 10: ret = "0A";
		case 11: ret = "0B";
		case 12: ret = "0C";
		case 13: ret = "0D";
		case 14: ret = "0E";
		case 15: ret = "0F";
		case 16: ret = "10";
		case 17: ret = "11";
		case 18: ret = "12";
		case 19: ret = "13";
		case 20: ret = "14";
		case 21: ret = "15";
		case 22: ret = "16";
		case 23: ret = "17";
		case 24: ret = "18";
		case 25: ret = "19";
		case 26: ret = "1A";
		case 27: ret = "1B";
		case 28: ret = "1C";
		case 29: ret = "1D";
		case 30: ret = "1E";
		case 31: ret = "1F";
		case 32: ret = "20";
		case 33: ret = "21";
		case 34: ret = "22";
		case 35: ret = "23";
		case 36: ret = "24";
		case 37: ret = "25";
		case 38: ret = "26";
		case 39: ret = "27";
		case 40: ret = "28";
		case 41: ret = "29";
		case 42: ret = "2A";
		case 43: ret = "2B";
		case 44: ret = "2C";
		case 45: ret = "2D";
		case 46: ret = "2E";
		case 47: ret = "2F";
		case 48: ret = "30";
		case 49: ret = "31";
		case 50: ret = "32";
		case 51: ret = "33";
		case 52: ret = "34";
		case 53: ret = "35";
		case 54: ret = "36";
		case 55: ret = "37";
		case 56: ret = "38";
		case 57: ret = "39";
		case 58: ret = "3A";
		case 59: ret = "3B";
		case 60: ret = "3C";
		case 61: ret = "3D";
		case 62: ret = "3E";
		case 63: ret = "3F";
		case 64: ret = "40";
		case 65: ret = "41";
		case 66: ret = "42";
		case 67: ret = "43";
		case 68: ret = "44";
		case 69: ret = "45";
		case 70: ret = "46";
		case 71: ret = "47";
		case 72: ret = "48";
		case 73: ret = "49";
		case 74: ret = "4A";
		case 75: ret = "4B";
		case 76: ret = "4C";
		case 77: ret = "4D";
		case 78: ret = "4E";
		case 79: ret = "4F";
		case 80: ret = "50";
		case 81: ret = "51";
		case 82: ret = "52";
		case 83: ret = "53";
		case 84: ret = "54";
		case 85: ret = "55";
		case 86: ret = "56";
		case 87: ret = "57";
		case 88: ret = "58";
		case 89: ret = "59";
		case 90: ret = "5A";
		case 91: ret = "5B";
		case 92: ret = "5C";
		case 93: ret = "5D";
		case 94: ret = "5E";
		case 95: ret = "5F";
		case 96: ret = "60";
		case 97: ret = "61";
		case 98: ret = "62";
		case 99: ret = "63";
		case 100: ret = "64";
		case 101: ret = "65";
		case 102: ret = "66";
		case 103: ret = "67";
		case 104: ret = "68";
		case 105: ret = "69";
		case 106: ret = "6A";
		case 107: ret = "6B";
		case 108: ret = "6C";
		case 109: ret = "6D";
		case 110: ret = "6E";
		case 111: ret = "6F";
		case 112: ret = "70";
		case 113: ret = "71";
		case 114: ret = "72";
		case 115: ret = "73";
		case 116: ret = "74";
		case 117: ret = "75";
		case 118: ret = "76";
		case 119: ret = "77";
		case 120: ret = "78";
		case 121: ret = "79";
		case 122: ret = "7A";
		case 123: ret = "7B";
		case 124: ret = "7C";
		case 125: ret = "7D";
		case 126: ret = "7E";
		case 127: ret = "7F";
		case 128: ret = "80";
		case 129: ret = "81";
		case 130: ret = "82";
		case 131: ret = "83";
		case 132: ret = "84";
		case 133: ret = "85";
		case 134: ret = "86";
		case 135: ret = "87";
		case 136: ret = "88";
		case 137: ret = "89";
		case 138: ret = "8A";
		case 139: ret = "8B";
		case 140: ret = "8C";
		case 141: ret = "8D";
		case 142: ret = "8E";
		case 143: ret = "8F";
		case 144: ret = "90";
		case 145: ret = "91";
		case 146: ret = "92";
		case 147: ret = "93";
		case 148: ret = "94";
		case 149: ret = "95";
		case 150: ret = "96";
		case 151: ret = "97";
		case 152: ret = "98";
		case 153: ret = "99";
		case 154: ret = "9A";
		case 155: ret = "9B";
		case 156: ret = "9C";
		case 157: ret = "9D";
		case 158: ret = "9E";
		case 159: ret = "9F";
		case 160: ret = "A0";
		case 161: ret = "A1";
		case 162: ret = "A2";
		case 163: ret = "A3";
		case 164: ret = "A4";
		case 165: ret = "A5";
		case 166: ret = "A6";
		case 167: ret = "A7";
		case 168: ret = "A8";
		case 169: ret = "A9";
		case 170: ret = "AA";
		case 171: ret = "AB";
		case 172: ret = "AC";
		case 173: ret = "AD";
		case 174: ret = "AE";
		case 175: ret = "AF";
		case 176: ret = "B0";
		case 177: ret = "B1";
		case 178: ret = "B2";
		case 179: ret = "B3";
		case 180: ret = "B4";
		case 181: ret = "B5";
		case 182: ret = "B6";
		case 183: ret = "B7";
		case 184: ret = "B8";
		case 185: ret = "B9";
		case 186: ret = "BA";
		case 187: ret = "BB";
		case 188: ret = "BC";
		case 189: ret = "BD";
		case 190: ret = "BE";
		case 191: ret = "BF";
		case 192: ret = "C0";
		case 193: ret = "C1";
		case 194: ret = "C2";
		case 195: ret = "C3";
		case 196: ret = "C4";
		case 197: ret = "C5";
		case 198: ret = "C6";
		case 199: ret = "C7";
		case 200: ret = "C8";
		case 201: ret = "C9";
		case 202: ret = "CA";
		case 203: ret = "CB";
		case 204: ret = "CC";
		case 205: ret = "CD";
		case 206: ret = "CE";
		case 207: ret = "CF";
		case 208: ret = "D0";
		case 209: ret = "D1";
		case 210: ret = "D2";
		case 211: ret = "D3";
		case 212: ret = "D4";
		case 213: ret = "D5";
		case 214: ret = "D6";
		case 215: ret = "D7";
		case 216: ret = "D8";
		case 217: ret = "D9";
		case 218: ret = "DA";
		case 219: ret = "DB";
		case 220: ret = "DC";
		case 221: ret = "DD";
		case 222: ret = "DE";
		case 223: ret = "DF";
		case 224: ret = "E0";
		case 225: ret = "E1";
		case 226: ret = "E2";
		case 227: ret = "E3";
		case 228: ret = "E4";
		case 229: ret = "E5";
		case 230: ret = "E6";
		case 231: ret = "E7";
		case 232: ret = "E8";
		case 233: ret = "E9";
		case 234: ret = "EA";
		case 235: ret = "EB";
		case 236: ret = "EC";
		case 237: ret = "ED";
		case 238: ret = "EE";
		case 239: ret = "EF";
		case 240: ret = "F0";
		case 241: ret = "F1";
		case 242: ret = "F2";
		case 243: ret = "F3";
		case 244: ret = "F4";
		case 245: ret = "F5";
		case 246: ret = "F6";
		case 247: ret = "F7";
		case 248: ret = "F8";
		case 249: ret = "F9";
		case 250: ret = "FA";
		case 251: ret = "FB";
		case 252: ret = "FC";
		case 253: ret = "FD";
		case 254: ret = "FE";
		case 255: ret = "FF";
		default: ret = "FF";
	}
	return ret;
}
stock ShowTeamsScore(playerid,showbestkiller=0,showbestattacker=0)
{
	new bestkiller[MAX_PLAYERS], bestkillers = 0, bestattacker[MAX_PLAYERS], bestattackers = 0, str[128], duty[128], duties = 0;
	if(showbestkiller)
	{
		new maxi = 0, highest = dini_Int(ladderfile,"BestKillerScore"), len = 0, farr[3] = {0,0,0};
		for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pKills] > maxi) maxi = GetPlayerScore(i);
		for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pKills] == maxi) bestkiller[bestkillers++] = i;
		if(maxi > highest)
		{
			dini_IntSet(ladderfile,"BestKillerScore",maxi);
			dini_Set(ladderfile,"BestKiller",GetName(bestkiller[0]));
		}
		for(new j = 1; j <= 3; j++)
		{
			format(str,sizeof(str),"Best%sScore",FuncName(j));
			farr[j-1] = dini_Int(ladderfile,str);
		}
		for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i)) for(new j = 1; j <= 3; j++) if(pinfo[i][pFunc] == j) if(pinfo[i][pKills] > farr[j-1])
		{
			format(str,sizeof(str),"Best%sScore",FuncName(j));
			dini_IntSet(ladderfile,str,pinfo[i][pKills]);
			len = strlen(str);
			strdel(str,strfind(str,"Score"),len);
			dini_Set(ladderfile,str,GetName(i));
			SendFormatToAll(yellow," [%d] !���� ����� ��� ������ " @c(red) "%s" @c(yellow) "-��� � " @c(red) "%s",pinfo[i][pKills],FuncName(j),GetName(i));
		}
	}
	if(showbestattacker)
	{
		new Float:maxi = 0, Float:highest = dini_Float(ladderfile,"BestAttackerScore");
		for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pAttacked] > maxi) maxi = pinfo[i][pAttacked];
		for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pAttacked] == maxi) bestattacker[bestattackers++] = i;
		if(maxi > highest)
		{
			dini_FloatSet(ladderfile,"BestAttackerScore",maxi);
			dini_Set(ladderfile,"BestAttacker",GetName(bestattacker[0]));
		}
	}
	for(new i = (playerid == MAX_PLAYERS ? 0 : playerid); i < (playerid == MAX_PLAYERS ? (playerid + 1) : MAX_PLAYERS); i++) if(IsPlayerConnected(i))
	{
		SendClientMessage(i,lightblue,@header("��� �������"));
		for(new t = 0; t <= MAX_TEAMS - FIGHT_TEAMS; t++)
		{
			SendFormat(i,grey," %d) %s%s - " @c(grey) "Score: " @c(white) "%d" @c(grey) ", Players: " @c(white) "%d",t+1,GetColorAsString(tinfo[t][tColor]),tinfo[t][tName],tinfo[t][tScore],TeamPlayers(t));
			for(new f = 1; f <= 3; f++)
			{
				duties = 0, duty = "";
				for(new j = 0; j < MAX_PLAYERS; j++) if(IsPlayerConnected(j) && pinfo[j][pFunc] == f && pinfo[j][pTeam] == t)
				{
					duties++;
					format(duty,sizeof(duty),!strlen(duty) ? ("%s%s") : ("%s, %s"),duty,GetName(j));
				}
				if(duties > 0) SendFormat(i,grey," %s%s (" @c(white) "%d" @c(grey) ") - " @c(white) "%s",FuncName(f),f > 1 ? ("s") : (""),duties,duty);
			}
		}
		if(showbestattacker)
		{
			SendClientMessage(i,lightblue,bestattackers == 1 ? (@header("Best Attacker:")) : (@header("Best Attackers:")));
			str = "";
			for(new b = 0; b < bestattackers; b++) format(str,sizeof(str),"%s � %s",str,bestattacker[i]);
			SendClientMessage(i,grey,str);
		}
		if(showbestkiller)
		{
			SendClientMessage(i,lightblue,bestkillers == 1 ? (@header("Best Killer:")) : (@header("Best Killers:")));
			str = "";
			for(new b = 0; b < bestkillers; b++) format(str,sizeof(str),"%s � %s",str,bestkiller[i]);
			SendClientMessage(i,grey,str);
		}
	}
	return 1;
}
stock IsValidSkin(skinid)
{
	if(skinid < 0 || skinid > 299) return 0;
	new BadSkins[] = {3,4,5,6,8,42,65,74,86,119,149,208,273,289};
	for(new i = 0; i < sizeof(BadSkins); i++) if(skinid == BadSkins[i]) return 0;
	return 1;
}
stock split(const strsrc[],strdest[][],delimiter)
{
	new i, li, aNum, len, len2 = strlen(strsrc);
	while(i <= len2)
	{
		if(strsrc[i] == delimiter || i == len2)
		{
			len = strmid(strdest[aNum],strsrc,li,i,128);
			strdest[aNum][len] = 0;
			li = i + 1;
			aNum++;
		}
		i++;
	}
	return 1;
}
stock Map_Load(mapid)
{
	assert !map[mID];
	new f[64], k[16], tmp[256], floatKeys[][16] = {"SpawnA","SpawnB","SpawnM","CSCPos","CSPPos"}, got = 0;
	format(f,sizeof(f),laddermapsdir "%d.ini",mapid);
	assert fexist(f);
	map[mID] = mapid;
	format(map[mName],32,dini_Get(f,"MapName"));
	format(map[mAuthor],32,dini_Get(f,"MapAuthor"));
	for(new i = 0; i < MAX_LOBJECTS; i++)
	{
		format(k,sizeof(k),"Object%03d",i);
		if(dini_Isset(f,k))
		{
			format(tmp,sizeof(tmp),dini_Get(f,k));
			split(tmp,params,',');
			map[mObject][map[mObjects]++] = CreateObject(strval(params[0]),floatstr(params[1]),floatstr(params[2]),floatstr(params[3]),floatstr(params[4]),floatstr(params[5]),floatstr(params[6]));
		}
		else break;
	}
	got = 0;
	goto gettingFloats;
	gettingFloats:
	{
		format(tmp,sizeof(tmp),dini_Get(f,floatKeys[got]));
		split(tmp,params,',');
		for(new i = 0; i < (got == 3 ? 3 : 4); i++) switch(got)
		{
			case 0: map[mSpawnA][i] = floatstr(params[i]);
			case 1: map[mSpawnB][i] = floatstr(params[i]);
			case 2: map[mSpawnM][i] = floatstr(params[i]);
			case 3: map[mCSCP][i] = floatstr(params[i]);
			case 4: map[mCSPP][i] = floatstr(params[i]);
		}
	}
	//floatdiv(map[mSpawnA][0] + map[mSpawnB][0],2)
	//floatdiv(map[mSpawnA][1] + map[mSpawnB][1],2)
	//floatdiv(map[mSpawnA][2] + map[mSpawnB][2],2)
	//map[mBounds]
	if(got < sizeof(floatKeys)-1)
	{
		got++;
		goto gettingFloats;
	}
	for(new i = 0; i < sizeof(Signboards); i++)
	{
		format(k,sizeof(k),"Signboard%d",i);
		if(dini_Isset(f,k))
		{
			format(tmp,sizeof(tmp),dini_Get(f,k));
			split(tmp,params,',');
			Signboards[i][sbObject] = CreateObject(Signboards[i][sbModel],floatstr(params[0]),floatstr(params[1]),floatstr(params[2]),floatstr(params[3]),floatstr(params[4]),floatstr(params[5]));
			UpdateSignboard(i,SB_Update);
		}
	}
	printf("Loaded map: %d.ini",mapid);
	return 1;
}
stock Map_Unload()
{
	for(new i = 0, m = min(MAX_OBJECTS,MAX_LOBJECTS); i < map[mObjects] && i < m; i++) if(IsValidObject(map[mObject][i]))
	{
		DestroyObject(map[mObject][i]);
		map[mObject][i] = 0;
	}
	map[mID] = 0, map[mName] = 0, map[mAuthor] = 0, map[mObjects] = 0;
	for(new i = 0; i < 4; i++)
	{
		map[mSpawnA][i] = 0.0;
		map[mSpawnB][i] = 0.0;
		map[mSpawnM][i] = 0.0;
		if(i < 3) map[mCSCP][i] = 0.0;
		map[mCSPP][i] = 0.0;
	}
	for(new i = 0; i < sizeof(Signboards); i++) if(UpdateSignboard(i,SB_CheckIfValid)) UpdateSignboard(i,SB_Remove);
}
stock Map_Count()
{
	new f[64], c = 1;
	format(f,sizeof(f),laddermapsdir "%d.ini",c);
	while(fexist(f)) format(f,sizeof(f),laddermapsdir "%d.ini",++c);
	return c - 1;
}
stock Map_Exists(id)
{
	new f[64];
	format(f,sizeof(f),laddermapsdir "%d.ini",id);
	return fexist(f);
}
stock Map_GetInfo(id,info[])
{
	new f[64], ret[64];
	format(f,sizeof(f),laddermapsdir "%d.ini",id);
	assert fexist(f);
	if(!strcmp(info,"name")) format(ret,sizeof(ret),dini_Get(f,"MapName"));
	else if(!strcmp(info,"author")) format(ret,sizeof(ret),dini_Get(f,"MapAuthor"));
	else if(!strcmp(info,"objects"))
	{
	    new c = 0, k[16];
		for(new i = 0; i < MAX_LOBJECTS; i++)
		{
			format(k,sizeof(k),"Object%03d",i);
			if(dini_Isset(f,k)) c++;
			else break;
		}
		valstr(ret,c);
	}
	return ret;
}
stock FuncName(id)
{
	new funcname[16];
	switch(id)
	{
		case F_FIGHTER: funcname = "Fighter";
		case F_ASSISTANT: funcname = "Assistant";
		case F_SNIPER: funcname = "Sniper";
	}
	return funcname;
}
stock TeamPlayers(teamid)
{
	new c = 0;
	for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pTeam] == teamid) c++;
	return c;
}
stock Func_WeaponCount(func)
{
	new c = 0;
	for(new i = 0; i < 4; i++) if(FW[func][i] >= 1 && FW[func][i] <= 46) c++;
	return c;
}
stock Func_Weapon(func,arraypos) return FW[func][arraypos];
stock GetSawnoffAmmo(playerid)
{
	new d[2];
	GetPlayerWeaponData(playerid,3,d[0],d[1]);
	return d[0] == 26 ? d[1] : -1;
}
stock GetDeagleAmmo(playerid)
{
	new d[2];
	GetPlayerWeaponData(playerid,2,d[0],d[1]);
	return d[0] == 24 ? d[1] : -1;
}
stock Monitor(playerid,text[],...)
{
	if(monitor)
	{
		if(strfind(text,monitorFilter,true) != -1 && strlen(monitorFilter) > 0) return 1;
		new dontsend[5], ds = 0, bool:tocon = false;
		for(new i = 2, m = numargs(); i < m; i++) dontsend[ds++] = getarg(i);
		format(string,sizeof(string)," [/Monitor - %s] " @c(white) "%s",GetName(playerid),text);
		for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && IsPlayerMAdmin(i))
		{
			tocon = false;
			for(new j = 0; j < ds && !tocon; j++) if(dontsend[j] == i) tocon = true;
			if(tocon) continue;
			else SendClientMessage(i,0xFFFFE0FF,string);
		}
	}
	return 1;
}
stock PlayerHasWeapon(playerid,weaponid)
{
	new wd[2], slotToTest = GetWeaponSlot(weaponid);
	if(slotToTest != -1) GetPlayerWeaponData(playerid,slotToTest,wd[0],wd[1]);
	return slotToTest == -1 ? false : wd[0] == weaponid;
}
stock GetWeaponSlot(wid)
{
	switch(wid)
	{
		case 0, 1: return 0;
		case 2..9: return 1;
		case 22..24: return 2;
		case 25..27: return 3;
		case 28, 29, 32: return 4;
		case 30, 31: return 5;
		case 33, 34: return 6;
		case 35..38: return 7;
		case 16..19, 39: return 8;
		case 41..43: return 9;
		case 10..15: return 10;
		case 44..46: return 11;
		case 40: return 12;
		default: return -1;
	}
	return -1;
}
stock IsValidNick(name[])
{
	if(strlen(name) < 3 || strlen(name) > 20) return 0;
	for(new i=0,j=strlen(name);i<j;i++)
	{
		if(!(name[i] >= '0' && name[i] <= '9')
		&& !(name[i] >= 'A' && name[i] <= 'Z')
		&& !(name[i] >= 'a' && name[i] <= 'z')
		&& name[i] != '_' && name[i] != '[' && name[i] != ']'
		&& name[i] != '.' && name[i] != '(' && name[i] != ')'
		&& name[i] != '@' && name[i] != '$') return 0;
	}
	return 1;
}
forward Float:GetPlayerAveragePing(playerid);
stock Float:GetPlayerAveragePing(playerid)
{
	new ret = 0;
	for(new i = 0; i < pinfo[playerid][pPings]; i++) ret += pinfo[playerid][pPing][i];
	return floatdiv(float(ret),float(pinfo[playerid][pPings]));
}
stock GoClientPingTest()
{
	new lagger[MAX_PLAYERS], laggers = 0, Float:avg[MAX_PLAYERS];
	for(new i = 0; i < MAX_PLAYERS; i++) if((avg[i] = GetPlayerAveragePing(i)) > MAX_AVERAGE_PING) lagger[laggers++] = i;
	if(laggers > 0) for(new i = 0; i < laggers; i++)
	{
		if(!i) SendClientMessageToAll(lightblue," ~~~ :���� ������ �� ����� ~~~");
		SendFormatToAll(grey," � %d) %s (%.2f :���� �����)",i,GetName(lagger[i]),avg[lagger[i]]);
	}
	return laggers > 0;
}
stock GoServerPingTest()
{
	new tc = GetTickCount();
	fclose(fopen("ServerPingTest.txt",io_write));
	new a = GetTickCount()-tc;
	return a > 2 ? (SendClientMessageToAll(red," .���� ����� ����"), true) : false;
}
stock UpdateLadderGame({GameUpdateTypes}:...)
{
	for(new a = 0, n = numargs(); a < n; a++) switch(getarg(a))
	{
		case Active: dini_Set(laddergame,"Active",gameStarted ? ("True") : ("False"));
		case Team1Name: dini_Set(laddergame,"Team1",tinfo[TEAM_A][tName]);
		case Team2Name: dini_Set(laddergame,"Team2",tinfo[TEAM_B][tName]);
		case Team1Color: dini_IntSet(laddergame,"Color1",tinfo[TEAM_A][tColor]);
		case Team2Color: dini_IntSet(laddergame,"Color2",tinfo[TEAM_B][tColor]);
		case Team1Score: dini_IntSet(laddergame,"Score1",tinfo[TEAM_A][tScore]);
		case Team2Score: dini_IntSet(laddergame,"Score2",tinfo[TEAM_B][tScore]);
		case Admins:
		{
			new admins[MAX_PLAYER_NAME*10];
			for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pTeam] == TEAM_M) format(admins,sizeof(admins),"%s%c%s",admins,!strlen(admins) ? '\0' : ',',GetName(i));
			dini_Set(laddergame,"Admins",admins);
		}
		case Players:
		{
			new team[2][MAX_PLAYER_NAME*10], key[16];
			for(new t = 0; t < (MAX_TEAMS - FIGHT_TEAMS); t++)
			{
				for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pTeam] == t) format(team[t],sizeof team[],"%s%c%s-%d",team[t],!strlen(team[t]) ? '\0' : ',',GetName(i),GetPlayerScore(i));
				format(key,sizeof(key),"Team%dPlayers",t+1);
				dini_Set(laddergame,key,!strlen(team[t]) ? ("-None-") : (team[t]));
			}
		}
		case TimeLeft: dini_IntSet(laddergame,"TimeLeft",timeLeft / 60);
	}
	return 1;
}
stock IsNumeric(const __string[])
{
	if(__string[0] == '-' && __string[1] == EOS) return 0;
	for(new i = __string[0] == '-' ? 1 : 0, j = strlen(__string); i < j; i++) if(__string[i] < '0' || __string[i] > '9') return 0;
	return 1;
}
stock CheckForbiddenFS(bool:load = false) return strlen(FORBIDDEN_FS) > 0 ? (load ? SendRconCommand("loadfs " FORBIDDEN_FS) : SendRconCommand("unloadfs " FORBIDDEN_FS)) : 1;
stock DistanceToPoint(Float:x1,Float:y1,Float:z1,Float:x,Float:y,Float:z) return float(floatsqroot(floatpower(floatabs(floatsub(x,x1)),2)+floatpower(floatabs(floatsub(y,y1)),2)+floatpower(floatabs(floatsub(z,z1)),2)));
forward Float:GetDistanceBetweenPlayers(fromplayerid,toplayerid);
stock Float:GetDistanceBetweenPlayers(fromplayerid,toplayerid)
{
	new Float:p[2][3];
	GetPlayerPos(fromplayerid,p[0][0],p[0][1],p[0][2]);
	GetPlayerPos(toplayerid,p[1][0],p[1][1],p[1][2]);
	return DistanceToPoint(p[0][0],p[0][1],p[0][2],p[1][0],p[1][1],p[1][2]);
}
stock Float:DistanceCameraTargetToLocation(Float:CamX, Float:CamY, Float:CamZ, Float:ObjX, Float:ObjY, Float:ObjZ, Float:FrX, Float:FrY, Float:FrZ)
{   // by RedShirt, improved by me
	new Float:TGTDistance = floatsqroot((CamX - ObjX) * (CamX - ObjX) + (CamY - ObjY) * (CamY - ObjY) + (CamZ - ObjZ) * (CamZ - ObjZ)),
	Float:tmpX = FrX * TGTDistance + CamX, Float:tmpY = FrY * TGTDistance + CamY, Float:tmpZ = FrZ * TGTDistance + CamZ;
	return floatsqroot((tmpX - ObjX) * (tmpX - ObjX) + (tmpY - ObjY) * (tmpY - ObjY) + (tmpZ - ObjZ) * (tmpZ - ObjZ));
}
stock Float:GetPointAngleToPoint(Float:x2, Float:y2, Float:X, Float:Y)
{   // by niCe, improved by me
	new Float:DX = floatabs(floatsub(x2,X)), Float:DY = floatabs(floatsub(y2,Y)), Float:angle;
	if (DY == 0.0 || DX == 0.0)
	{
		if(DY == 0 && DX > 0) angle = 0.0;
		else if(DY == 0 && DX < 0) angle = 180.0;
		else if(DY > 0 && DX == 0) angle = 90.0;
		else if(DY < 0 && DX == 0) angle = 270.0;
		else if(DY == 0 && DX == 0) angle = 0.0;
	}
	else
	{
		angle = atan(DX/DY);
		if(X > x2 && Y <= y2) angle += 90.0;
		else if(X <= x2 && Y < y2) angle = floatsub(90.0, angle);
		else if(X < x2 && Y >= y2) angle -= 90.0;
		else if(X >= x2 && Y > y2) angle = floatsub(270.0, angle);
	}
	return floatadd(angle,90.0);
}
stock GetXYInFrontOfPoint(&Float:x, &Float:y, Float:angle, Float:distance) x += (distance * floatsin(-angle, degrees)), y += (distance * floatcos(-angle, degrees)); // by niCe, improved by me
stock IsPlayerAimingAt(playerid, Float:x, Float:y, Float:z, Float:radius)
{   // by niCe, improved by me
	new Float:camera_x, Float:camera_y, Float:camera_z, Float:vector_x, Float:vector_y, Float:vector_z, Float:vertical, Float:horizontal, k[2];
	GetPlayerKeys(playerid,k[0],k[1],k[1]);
	if(k[0] & 16)
	{
		GetPlayerCameraPos(playerid,camera_x,camera_y,camera_z);
		GetPlayerCameraFrontVector(playerid,vector_x,vector_y,vector_z);
		switch(GetPlayerWeapon(playerid))
		{
			case 34, 35, 36: return DistanceCameraTargetToLocation(camera_x, camera_y, camera_z, x, y, z, vector_x, vector_y, vector_z) < radius;
			case 30, 31: vertical = 4.0, horizontal = -1.6;
			case 33: vertical = 2.7, horizontal = -1.0;
			default: vertical = 6.0, horizontal = -2.2;
		}
		new Float:angle = GetPointAngleToPoint(0,0,floatsqroot(vector_x*vector_x+vector_y*vector_y),vector_z) - 270.0;
		new Float:resize_x, Float:resize_y, Float:resize_z = floatsin(angle+vertical, degrees);
		GetXYInFrontOfPoint(resize_x,resize_y,GetPointAngleToPoint(0,0,vector_x,vector_y)+horizontal,floatcos(angle+vertical,degrees));
		return DistanceCameraTargetToLocation(camera_x,camera_y,camera_z,x,y,z,resize_x,resize_y,resize_z) < radius;
	}
	else return false;
}
stock GetEveryonesPositions(position[MAX_PLAYERS][EveryonesPositionData],&positions)
{
	new Float:p[3];
	for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pSpawned])
	{
		GetPlayerPos(i,p[0],p[1],p[2]);
	    position[positions][epX] = p[0],
		position[positions][epY] = p[1],
		position[positions][epZ] = p[2],
		position[positions][epID] = i;
	    positions++;
	}
}
stock UpdateHPStatus(playerid,Float:hp)
{
	assert GetPlayerState(playerid) == PLAYER_STATE_ONFOOT && pinfo[playerid][pSpawned];
	new str[32];
	format(str,sizeof(str),"~%c~%.0f",hp > 0.0 ? 'g' : 'r',hp);
	if(pinfo[playerid][pHPTimer] != -1)
	{
		KillTimer(pinfo[playerid][pHPTimer]);
		PlayerTextDrawSetString(playerid,pinfo[playerid][pHPStatus],str);
	}
	else
	{
		pinfo[playerid][pHPStatus] = CreatePlayerTextDraw(playerid,146.000000,372.000000,str);
		PlayerTextDrawBackgroundColor(playerid,pinfo[playerid][pHPStatus],255);
		PlayerTextDrawFont(playerid,pinfo[playerid][pHPStatus],1);
		PlayerTextDrawLetterSize(playerid,pinfo[playerid][pHPStatus],0.480000,1.400000);
		PlayerTextDrawColor(playerid,pinfo[playerid][pHPStatus],hp > 0.0 ? green : red);
		PlayerTextDrawSetOutline(playerid,pinfo[playerid][pHPStatus],1);
		PlayerTextDrawSetProportional(playerid,pinfo[playerid][pHPStatus],1);
		PlayerTextDrawShow(playerid,pinfo[playerid][pHPStatus]);
	}
	pinfo[playerid][pHPTimer] = SetTimerEx("HideHPStatus",2000,0,"ii",playerid,0);
	return 1;
}
stock TTS(playerid,text[])
{
	new addr[256];
	format(addr,sizeof(addr),"http://translate.google.com/translate_tts?tl=en&q=%s",text);
	SendFormat(playerid,0x2587CEAA," � TTS: %s",text);
	return PlayAudioStreamForPlayer(playerid,addr);
}
stock ReturnToClassSelection(playerid)
{
	ForceClassSelection(playerid);
	TogglePlayerSpectating(playerid,1);
	return TogglePlayerSpectating(playerid,0);
}
stock KillingSpreeUpdate(playerid,Float:p[3])
{
	new text[128], tdcolor = white;
	switch(pinfo[playerid][pKillingSpree][1])
	{
		case 2: text = "Double", tdcolor = 0x00FF00FF;
		case 3: text = "Triple", tdcolor = 0xFF0000FF;
		case 4: text = "Mega", tdcolor = 0x0000FFFF;
	}
	SetPlayerChatBubble(playerid,text,tdcolor,20.0,3000);
	format(text,sizeof(text),"%s~n~~r~Kill!",text);
	if(pinfo[playerid][pKillingSpree][2] != -1)
	{
		TextDrawHideForPlayer(playerid,pinfo[playerid][pKSText]);
		TextDrawDestroy(pinfo[playerid][pKSText]);
		KillTimer(pinfo[playerid][pKillingSpree][2]);
		pinfo[playerid][pKillingSpree][2] = -1;
	}
	pinfo[playerid][pKSText] = TextDrawCreate(565.000000,374.000000,text);
	TextDrawAlignment(pinfo[playerid][pKSText],2);
	TextDrawBackgroundColor(pinfo[playerid][pKSText],255);
	TextDrawFont(pinfo[playerid][pKSText],3);
	TextDrawLetterSize(pinfo[playerid][pKSText],0.739999,2.000000);
	TextDrawColor(pinfo[playerid][pKSText],tdcolor);
	TextDrawSetOutline(pinfo[playerid][pKSText],0);
	TextDrawSetProportional(pinfo[playerid][pKSText],1);
	TextDrawSetShadow(pinfo[playerid][pKSText],2);
	TextDrawShowForPlayer(playerid,pinfo[playerid][pKSText]);
	pinfo[playerid][pKillingSpree][2] = SetTimerEx("HideKSText",3000,0,"i",playerid);
	format(text,sizeof(text),"http://sa-mp.co.il/ladder/game_music/%d.wav",pinfo[playerid][pKillingSpree][1]);
	if(playerid == -1) PlayAudioStreamForPlayer(playerid,text,p[0],p[1],p[2],30.0,1);
	else PlayAudioStreamForPlayer(playerid,text);
	return 1;
}
stock IsFightTeam(teamid) return (teamid < FIGHT_TEAMS && teamid != INVALID_TEAM);
stock UpdateSignboard(signid,SignboardOptions:option)
{
	switch(option)
	{
		case SB_Update:
		{
			switch(signid)
			{
				case SIGNBOARD_ADV: format(string,sizeof(string),advText);
				case SIGNBOARD_FULL:
				{
					format(string,sizeof(string),"{00FF00}���� �����: {FF0000}%d",timeLeft/60);
					if(IsPlayerConnected(currentBestKiller[0])) format(string,sizeof(string),"%s\n{00FF00}Best Killer:\n{FF0000}%s (%d)",string,GetName(currentBestKiller[0]),currentBestKiller[1]);
				}
				case SIGNBOARD_SCORE1, SIGNBOARD_SCORE2: format(string,sizeof(string),"%s%s\n%d",GetColorAsString(tinfo[signid-2][tColor]),tinfo[signid-2][tName],tinfo[signid-2][tScore]);
			}
			SetObjectMaterialText(Signboards[signid][sbObject],string,0,.fontsize = 28,.fontcolor = 0xFF00FF00,.backcolor = 0xFF000000,.textalignment = 1);
		}
		case SB_Remove: DestroyObject(Signboards[signid][sbObject]);
		case SB_Create:
		{
			format(string,sizeof(string),laddermapsdir "%d.ini",map[mID]);
			new k[32];
			format(k,sizeof(k),"Signboard%d",signid);
			if(dini_Isset(string,k))
			{
				format(string,sizeof(string),dini_Get(string,k));
				split(string,params,',');
				Signboards[signid][sbObject] = CreateObject(Signboards[signid][sbModel],floatstr(params[0]),floatstr(params[1]),floatstr(params[2]),floatstr(params[3]),floatstr(params[4]),floatstr(params[5]));
				UpdateSignboard(signid,SB_Update);
			}
		}
		case SB_CheckIfValid: return signid >= 0 && signid < sizeof(Signboards) ? (_:(Signboards[signid][sbObject] != INVALID_OBJECT_ID)) : 0;
	}
	return 1;
}
stock ShouldPause(reason[])
{
	assert !pause;
	fastStop = 10;
	format(fastStopReason,sizeof(fastStopReason),reason);
	for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && IsPlayerMAdmin(i))
	{
		SendClientMessage(i,red,":�-10 ����� ������� ��� ����� �� ����� ������ ~k~~CONVERSATION_NO~ ������ ����� ����� ���� ����� �� �����. ���");
		SendClientMessage(i,red,reason);
	}
	return 1;
}
stock Freeze(playerid,bool:fstatus)
{
	assert GetPlayerState(playerid) != PLAYER_STATE_SPECTATING && pinfo[playerid][pTeam] != TEAM_V;
	TogglePlayerControllable(playerid,_:(!fstatus));
	pinfo[playerid][pFrozen] = _:fstatus;
}
stock MoveCamera(playerid)
{
	if(pinfo[playerid][pMS] <= 1.0) pinfo[playerid][pMS] += 0.03;
	new Float:FV[3], Float:CP[3], Float:p[3], Float:s = 75.0 * pinfo[playerid][pMS];
	GetPlayerCameraPos(playerid,CP[0],CP[1],CP[2]);
    GetPlayerCameraFrontVector(playerid,FV[0],FV[1],FV[2]);
	GetNextCameraPosition(pinfo[playerid][pCamera][1],CP,FV,p[0],p[1],p[2]);
	MovePlayerObject(playerid,pinfo[playerid][pFlyObject],p[0],p[1],p[2],s);
	pinfo[playerid][pCamera][2] = GetTickCount();
	return 1;
}
stock GetNextCameraPosition(move_mode,Float:CP[3],Float:FV[3],&Float:X,&Float:Y,&Float:Z)
{	// an improved version of h02's calculations of next position
    #define OFFSET_X (FV[0]*6000.0)
	#define OFFSET_Y (FV[1]*6000.0)
	#define OFFSET_Z (FV[2]*6000.0)
	switch(move_mode)
	{
		case 1: X = CP[0]+OFFSET_X, Y = CP[1]+OFFSET_Y, Z = CP[2]+OFFSET_Z;
		case 2: X = CP[0]-OFFSET_X, Y = CP[1]-OFFSET_Y, Z = CP[2]-OFFSET_Z;
		case 3: X = CP[0]-OFFSET_Y, Y = CP[1]+OFFSET_X, Z = CP[2];
		case 4: X = CP[0]+OFFSET_Y, Y = CP[1]-OFFSET_X, Z = CP[2];
		case 5: X = CP[0]+(OFFSET_X  - OFFSET_Y), Y = CP[1]+(OFFSET_Y  + OFFSET_X), Z = CP[2]+OFFSET_Z;
		case 6: X = CP[0]+(OFFSET_X  + OFFSET_Y), Y = CP[1]+(OFFSET_Y  - OFFSET_X), Z = CP[2]+OFFSET_Z;
		case 7: X = CP[0]+(-OFFSET_X - OFFSET_Y), Y = CP[1]+(-OFFSET_Y + OFFSET_X), Z = CP[2]-OFFSET_Z;
		case 8: X = CP[0]+(-OFFSET_X + OFFSET_Y), Y = CP[1]+(-OFFSET_Y - OFFSET_X), Z = CP[2]-OFFSET_Z;
	}
	//if(X < map[mBounds][0] || X > map[mBounds][3]) X = map[mBounds][0];
	//if(Y < map[mBounds][1] || Y > map[mBounds][4]) Y = map[mBounds][1];
	//if(Z < map[mBounds][2] || Z > map[mBounds][5]) Z = map[mBounds][2];
	#undef OFFSET_X
	#undef OFFSET_Y
	#undef OFFSET_Z
}
stock SetCameraMode(playerid,newmode)
{
	TogglePlayerSpectating(playerid,0);
	if(IsValidPlayerObject(playerid,pinfo[playerid][pFlyObject]) && pinfo[playerid][pCamera][0] == CAMERA_FLY) DestroyPlayerObject(playerid,pinfo[playerid][pFlyObject]);
	switch(newmode)
	{
		case CAMERA_NONE: SetCameraBehindPlayer(playerid);
		case CAMERA_FLY:
		{
			TogglePlayerSpectating(playerid,1);
			pinfo[playerid][pFlyObject] = CreatePlayerObject(playerid,19300,map[mSpawnM][0],map[mSpawnM][1],map[mSpawnM][2],0.0,0.0,0.0);
			AttachCameraToPlayerObject(playerid,pinfo[playerid][pFlyObject]);
			SendClientMessage(playerid,yellow," .��� ��: ���� ������ ������� ��� " @c(orange) "�����" @c(yellow) ", ��� ���� ���� ����� ���� ������ �����");
			SendClientMessage(playerid,yellow," ,����� ����� ����� " @c(orange) "����, ����, ����� �����" @c(yellow) " ��� ����");
			SendClientMessage(playerid,yellow," .���� �� " @c(orange) "�����" @c(yellow) " ��� ����� ��� ����");
			TTS(playerid,"Fly mode");
		}
		case CAMERA_SPEC:
		{
			TogglePlayerSpectating(playerid,1);
			pinfo[playerid][pSpec] = INVALID_PLAYER_ID;
			ViewerSpectating(playerid,true);
			SendClientMessage(playerid,yellow," .��� ��: ���� ������ ������� ��� " @c(orange) "����" @c(yellow) ", ��� ���� ����� ����� ������ ��� ��� ������� ������ ������ ������");
			SendClientMessage(playerid,yellow," .����� ����� ����� " @c(orange) "���� �����" @c(yellow) " �� " @c(orange) "����� �����" @c(yellow) " ��� ������ ���� ������");
			TTS(playerid,"Spectate mode");
		}
	}
	pinfo[playerid][pCamera][0] = newmode;
}
stock ViewerSpectating(playerid,bool:next,bool:dia=true)
{
	assert pinfo[playerid][pTeam] == TEAM_V;
	new found = INVALID_PLAYER_ID;
	goto finding;
	finding: for(new i = (pinfo[playerid][pSpec] == INVALID_PLAYER_ID ? (next ? 0 : MAX_PLAYERS) : pinfo[playerid][pSpec])-1; found == INVALID_PLAYER_ID && (next ? i < MAX_PLAYERS : i >= 0); i = (next ? ++i : --i)) if(IsPlayerConnected(i) && IsFightTeam(pinfo[i][pTeam])) found = i;
	if(found == INVALID_PLAYER_ID && pinfo[playerid][pSpec] != INVALID_PLAYER_ID)
	{
		pinfo[playerid][pSpec] = INVALID_PLAYER_ID;
		goto finding;
	}
	else if(found != INVALID_PLAYER_ID && IsPlayerConnected(found))
	{
		ShowPlayerDialog(playerid,-1,DIALOG_STYLE_MSGBOX,"","","","");
		PlayerSpectatePlayer(playerid,found);
	}
	else
	{
		assert dia;
		ShowPlayerDialog(playerid,DIALOG_NI,DIALOG_STYLE_MSGBOX,"����",@c(red) ".��� ������ ����� ���. ���� �����, ����� �������� ������ ���","OK","");
	}
	return;
}
stock UpdateViewers() for(new i = 0; i < MAX_PLAYERS; i++) if(IsPlayerConnected(i) && pinfo[i][pTeam] == TEAM_V && pinfo[i][pSpec] == INVALID_PLAYER_ID) ViewerSpectating(i,true,false);
