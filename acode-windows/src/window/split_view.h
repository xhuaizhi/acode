#ifndef ACODE_SPLIT_VIEW_H
#define ACODE_SPLIT_VIEW_H

#include <windows.h>
#include <stdbool.h>

typedef enum { SPLIT_HORIZONTAL, SPLIT_VERTICAL } SplitDirection;
typedef enum { SNODE_LEAF, SNODE_SPLIT } SplitNodeType;

#define SPLITTER_WIDTH 4

typedef struct SplitNode {
    SplitNodeType type;

    /* Leaf data */
    HWND hwndTerminal;
    int  terminalId;

    /* Split data */
    SplitDirection dir;
    float ratio;
    struct SplitNode *first;
    struct SplitNode *second;

    /* Layout cache (set by split_node_layout) */
    RECT bounds;
} SplitNode;

SplitNode *split_node_new_leaf(HWND hwndTerm, int termId);
SplitNode *split_node_new_split(SplitDirection dir, SplitNode *first, SplitNode *second);
void       split_node_free(SplitNode *node);

void split_node_layout(SplitNode *node, RECT rc, HWND parent);

SplitNode *split_node_find_leaf(SplitNode *node, HWND hwndTerm);
SplitNode *split_node_find_parent(SplitNode *root, SplitNode *child);

int  split_node_count_leaves(SplitNode *node);
void split_node_collect_terminals(SplitNode *node, HWND *out, int *count, int max);

typedef enum { SPLIT_HIT_NONE, SPLIT_HIT_SPLITTER } SplitHitType;
typedef struct {
    SplitHitType type;
    SplitNode   *splitNode;
    SplitDirection dir;
} SplitHitResult;

SplitHitResult split_node_hit_test(SplitNode *node, int x, int y);

#endif /* ACODE_SPLIT_VIEW_H */
