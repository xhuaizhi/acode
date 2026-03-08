#ifndef ACODE_MCP_H
#define ACODE_MCP_H

#include <windows.h>
#include <stdbool.h>

#define MCP_MAX_SERVERS    64
#define MCP_MAX_ID_LEN     128
#define MCP_MAX_CMD_LEN    512
#define MCP_MAX_URL_LEN    1024
#define MCP_MAX_ARGS       32
#define MCP_MAX_ARG_LEN    256
#define MCP_MAX_SOURCES    4

/* Transport types */
typedef enum {
    MCP_TRANSPORT_STDIO,
    MCP_TRANSPORT_HTTP,
    MCP_TRANSPORT_SSE,
    MCP_TRANSPORT_UNKNOWN
} MCPTransport;

/* MCP Server (merged from all config sources) */
typedef struct {
    char        id[MCP_MAX_ID_LEN];
    MCPTransport transport;
    char        summary[MCP_MAX_CMD_LEN];     /* command or URL */
    char        sources[MCP_MAX_SOURCES][16];  /* "codex","claude","gemini" */
    int         sourceCount;

    /* Raw spec fields */
    char        command[MCP_MAX_CMD_LEN];
    char        args[MCP_MAX_ARGS][MCP_MAX_ARG_LEN];
    int         argCount;
    char        url[MCP_MAX_URL_LEN];
} MCPServer;

/* Form data for add/edit */
typedef struct {
    char        id[MCP_MAX_ID_LEN];
    MCPTransport transport;
    char        command[MCP_MAX_CMD_LEN];
    char        args[MCP_MAX_ARGS][MCP_MAX_ARG_LEN];
    int         argCount;
    char        url[MCP_MAX_URL_LEN];
} MCPFormData;

/* Preset */
typedef struct {
    const char *id;
    const char *name;
    const char *description;
    const char *transport;   /* "stdio" */
    const char *command;
    const char *args[8];
    int         argCount;
} MCPPreset;

/* Service API */
int  mcp_list_servers(MCPServer *out, int maxCount);
bool mcp_upsert_server(const MCPFormData *data);
bool mcp_delete_server(const char *id);
bool mcp_toggle_app(const char *app, const char *id, bool enabled);

/* Presets */
const MCPPreset *mcp_get_presets(int *count);

#endif /* ACODE_MCP_H */
