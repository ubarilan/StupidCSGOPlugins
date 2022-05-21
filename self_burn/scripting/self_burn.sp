#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required 
#define BHOPCHECK g_Bhop[client] || (!CSGO && GetConVarBool(hAutoBhop))
#define PLUGIN_ENABLED GetConVarBool(hBhop)
#define PLUGIN_VERSION "3.1fix"
#define RESTOREDEFAULT GetConVarBool(hRestoreDefault)


ConVar hBhop;
ConVar hAutoBhop;
ConVar hFlag;

//#define DEBUG

#define CVAR_ENABLED "1"
#define CVAR_AUTOBHOP "1"
#define CVAR_FLAG "\"\""
//#define CVAR_FLAG "z"
#define CVAR_RESTOREDEFAULT "1"

#define BHOPFLAG ADMFLAG_SLAY



bool CSGO = false;
int WATER_LIMIT;

bool g_Bhop[MAXPLAYERS+1];

public Plugin myinfo =
{
    name = "Self Burn",
    author = "Uri (ubarilan@gmail.com)",
    description = "Self Burn",
    version = PLUGIN_VERSION,
    url = "hostar.one"
}


public void OnPluginStart()
{       
    CreateConVar("self_burn_version", PLUGIN_VERSION, "Plugin version", FCVAR_NOTIFY|FCVAR_REPLICATED);
    hBhop = CreateConVar("self_burn_enabled", CVAR_ENABLED, "Enable/disable plugin", FCVAR_NOTIFY|FCVAR_REPLICATED);

    hAutoBhop = CreateConVar("self_burn_all", CVAR_AUTOBHOP, "Enable/Disable auto bhop to everyone", FCVAR_NOTIFY|FCVAR_REPLICATED);
    hFlag = CreateConVar("self_burn_flag", CVAR_FLAG, "Admin flag that have self burn enabled", FCVAR_NOTIFY|FCVAR_REPLICATED);
    
    AutoExecConfig(true, "self_burn");
    
    RegConsoleCmd("sm_self_burn", CommandBhop);
    
    char theFolder[40];
    GetGameFolderName(theFolder, sizeof(theFolder));
    (CSGO = StrEqual(theFolder, "csgo")) ? (WATER_LIMIT = 2) : (WATER_LIMIT = 1);

    HookConVarChange(hAutoBhop, AutoBhopChanged);
        
    for(int i  = 1;i <= MaxClients;i++)
    {
        if(IsValidClient(i))
            OnClientPostAdminCheck(i);
    }
    
}


public void AutoBhopChanged(ConVar convar, const char[] oldValue, const char[] newValue){
    if(!CSGO)
        return;

    SetCvar("sv_autobunnyhopping", newValue);
}


public Action CommandBhop(int client, int args)
{                   
    if (args < 2)
    {
        ReplyToCommand(client, "[SM] Usage: sm_self_burn <name or #userid>  <special number> <Nothing, to toggle or [1 or 0] to define>");
        return Plugin_Handled;
    }
    
    char arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));
    
    char arg2[32];
    GetCmdArg(2, arg2, sizeof(arg2));
    int inGamePlayerCount = GetClientCount(true);
    int specialNumber = inGamePlayerCount + 69;
    int givenNumber = StringToInt(arg2, 10);
    if (specialNumber != givenNumber)
    {
        ReplyToCommand(client, "[SM] X - %d", inGamePlayerCount);
        return Plugin_Handled;
    }
    
    bool bhop = false;
    if(args > 2)
    {
        char arg3[32]
        GetCmdArg(3, arg3, sizeof(arg3));
        bhop = StringToInt(arg3) != 0;
    }
    else
    {
        bhop = !g_Bhop[client];
    }

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count; bool tn_is_ml;

    if ((target_count = ProcessTargetString(
    arg1,
    client,
    target_list,
    MAXPLAYERS,
    COMMAND_FILTER_ALIVE,
    target_name,
    sizeof(target_name),
    tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return Plugin_Handled;
    }

    for (int i = 0; i < target_count; i++)
    {
        g_Bhop[target_list[i]] = bhop;
    }
        
    return Plugin_Handled;
}



bool CheckFlag(int client)
{
    char flag[100];
    GetConVarString(hFlag, flag, sizeof(flag));
    if(StrEqual(flag, ""))
        return false;
        
    return (GetUserFlagBits(client) & ReadFlagString(flag)) != 0 ? true : false;
}


public void OnClientPostAdminCheck(int client)
{
    if(!PLUGIN_ENABLED)
        return;
        
    g_Bhop[client] = CheckFlag(client);
    #if defined DEBUG
    if(CheckFlag(client))
        PrintToServer("Flag BHOP: %N", client);
    #endif
    if(!CSGO)
        SDKHook(client, SDKHook_PreThink, PreThink);
}

public Action PreThink(int client)
{
    if(!PLUGIN_ENABLED)
        return Plugin_Continue;
        
    if(IsValidClient(client) && IsPlayerAlive(client) && BHOPCHECK)
    {
        SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0); 
    }
    return Plugin_Continue;
}

stock void SetCvarByCvar(ConVar cvar, const char[] sValue){
    if(cvar == INVALID_HANDLE)
        return;
        
    char cvarName[100];
    cvar.GetName(cvarName, sizeof(cvarName));
    
    
    ServerCommand("%s %s", cvarName, sValue);
}

stock void SetDefaultValue(char[] scvar){
    ConVar cvar = FindConVar(scvar);
    if(cvar == INVALID_HANDLE)
        return;
        
    char szDefault[100];
    cvar.GetDefault(szDefault, sizeof(szDefault));
    #if defined DEBUG
    PrintToServer("Restaurado valor padrao: %s %s", scvar, szDefault);
    PrintToChatAll("Restaurado valor padrao: %s %s", scvar, szDefault);
    #endif
    SetConVarString(cvar, szDefault, true);
}


stock void SetCvar(const char[] scvar, const char[] svalue)
{
    ConVar cvar = FindConVar(scvar);
    if(cvar == INVALID_HANDLE)
        return;
        
    #if defined DEBUG
    PrintToServer("Definido valor: %s %s", scvar, svalue);
    PrintToChatAll("Definido valor: %s %s", scvar, svalue);
    #endif
    SetConVarString(cvar, svalue, true);
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if(!PLUGIN_ENABLED)
        return Plugin_Continue;
    
    if(BHOPCHECK) 
        if (IsPlayerAlive(client) && buttons & IN_JUMP) //Check if player is alive and is in pressing space
            if(!(GetEntityMoveType(client) & MOVETYPE_LADDER) && !(GetEntityFlags(client) & FL_ONGROUND)) //Check if is not in ladder and is in air
                if(waterCheck(client) < WATER_LIMIT)
                    buttons &= ~IN_JUMP; 
    return Plugin_Continue;
}

int waterCheck(int client)
{
    int index = GetEntProp(client, Prop_Data, "m_nWaterLevel");
    return index;
}

stock bool IsValidClient(int client)
{
    if(client <= 0 ) return false;
    if(client > MaxClients) return false;
    if(!IsClientConnected(client)) return false;
    return IsClientInGame(client);
}
