#ifndef ACODE_FILE_NODE_H
#define ACODE_FILE_NODE_H

#include <windows.h>
#include <stdbool.h>

typedef struct FileNode {
    wchar_t path[MAX_PATH];
    bool    isDir;
    bool    loaded;
} FileNode;

FileNode *file_node_create(const wchar_t *path, bool isDir);
void file_node_free(FileNode *node);

#endif /* ACODE_FILE_NODE_H */
