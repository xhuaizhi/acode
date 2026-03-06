#include "file_node.h"
#include <stdlib.h>

FileNode *file_node_create(const wchar_t *path, bool isDir) {
    FileNode *node = (FileNode *)calloc(1, sizeof(FileNode));
    if (node) {
        wcsncpy(node->path, path, MAX_PATH - 1);
        node->isDir = isDir;
        node->loaded = false;
    }
    return node;
}

void file_node_free(FileNode *node) {
    free(node);
}
