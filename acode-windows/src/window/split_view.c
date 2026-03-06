#include "split_view.h"
#include <stdlib.h>

/* ---------------------------------------------------------------
 * Node construction / destruction
 * --------------------------------------------------------------- */

SplitNode *split_node_new_leaf(HWND hwndTerm, int termId) {
    SplitNode *n = (SplitNode *)calloc(1, sizeof(SplitNode));
    if (!n) return NULL;
    n->type = SNODE_LEAF;
    n->hwndTerminal = hwndTerm;
    n->terminalId = termId;
    n->ratio = 0.5f;
    return n;
}

SplitNode *split_node_new_split(SplitDirection dir, SplitNode *first, SplitNode *second) {
    SplitNode *n = (SplitNode *)calloc(1, sizeof(SplitNode));
    if (!n) return NULL;
    n->type = SNODE_SPLIT;
    n->dir = dir;
    n->ratio = 0.5f;
    n->first = first;
    n->second = second;
    return n;
}

void split_node_free(SplitNode *node) {
    if (!node) return;
    if (node->type == SNODE_SPLIT) {
        split_node_free(node->first);
        split_node_free(node->second);
    }
    free(node);
}

/* ---------------------------------------------------------------
 * Recursive layout
 * --------------------------------------------------------------- */

void split_node_layout(SplitNode *node, RECT rc, HWND parent) {
    if (!node) return;
    node->bounds = rc;

    int w = rc.right - rc.left;
    int h = rc.bottom - rc.top;
    if (w < 1 || h < 1) return;

    if (node->type == SNODE_LEAF) {
        if (node->hwndTerminal) {
            MoveWindow(node->hwndTerminal, rc.left, rc.top, w, h, TRUE);
            ShowWindow(node->hwndTerminal, SW_SHOW);
        }
        return;
    }

    /* SNODE_SPLIT */
    if (node->dir == SPLIT_VERTICAL) {
        int splitX = rc.left + (int)(w * node->ratio);
        if (splitX < rc.left + 20) splitX = rc.left + 20;
        if (splitX > rc.right - 20) splitX = rc.right - 20;

        RECT r1 = { rc.left, rc.top, splitX, rc.bottom };
        RECT r2 = { splitX + SPLITTER_WIDTH, rc.top, rc.right, rc.bottom };
        split_node_layout(node->first, r1, parent);
        split_node_layout(node->second, r2, parent);
    } else {
        int splitY = rc.top + (int)(h * node->ratio);
        if (splitY < rc.top + 20) splitY = rc.top + 20;
        if (splitY > rc.bottom - 20) splitY = rc.bottom - 20;

        RECT r1 = { rc.left, rc.top, rc.right, splitY };
        RECT r2 = { rc.left, splitY + SPLITTER_WIDTH, rc.right, rc.bottom };
        split_node_layout(node->first, r1, parent);
        split_node_layout(node->second, r2, parent);
    }
}

/* ---------------------------------------------------------------
 * Tree search
 * --------------------------------------------------------------- */

SplitNode *split_node_find_leaf(SplitNode *node, HWND hwndTerm) {
    if (!node) return NULL;
    if (node->type == SNODE_LEAF)
        return (node->hwndTerminal == hwndTerm) ? node : NULL;
    SplitNode *found = split_node_find_leaf(node->first, hwndTerm);
    if (found) return found;
    return split_node_find_leaf(node->second, hwndTerm);
}

SplitNode *split_node_find_parent(SplitNode *root, SplitNode *child) {
    if (!root || root->type == SNODE_LEAF) return NULL;
    if (root->first == child || root->second == child) return root;
    SplitNode *found = split_node_find_parent(root->first, child);
    if (found) return found;
    return split_node_find_parent(root->second, child);
}

int split_node_count_leaves(SplitNode *node) {
    if (!node) return 0;
    if (node->type == SNODE_LEAF) return 1;
    return split_node_count_leaves(node->first) + split_node_count_leaves(node->second);
}

void split_node_collect_terminals(SplitNode *node, HWND *out, int *count, int max) {
    if (!node || *count >= max) return;
    if (node->type == SNODE_LEAF) {
        if (node->hwndTerminal)
            out[(*count)++] = node->hwndTerminal;
        return;
    }
    split_node_collect_terminals(node->first, out, count, max);
    split_node_collect_terminals(node->second, out, count, max);
}

/* ---------------------------------------------------------------
 * Hit-test for splitter dragging
 * --------------------------------------------------------------- */

SplitHitResult split_node_hit_test(SplitNode *node, int x, int y) {
    SplitHitResult none = { SPLIT_HIT_NONE, NULL, SPLIT_VERTICAL };
    if (!node || node->type == SNODE_LEAF) return none;

    int w = node->bounds.right - node->bounds.left;
    int h = node->bounds.bottom - node->bounds.top;

    if (node->dir == SPLIT_VERTICAL) {
        int splitX = node->bounds.left + (int)(w * node->ratio);
        if (x >= splitX - 2 && x <= splitX + SPLITTER_WIDTH + 2 &&
            y >= node->bounds.top && y <= node->bounds.bottom) {
            SplitHitResult r = { SPLIT_HIT_SPLITTER, node, SPLIT_VERTICAL };
            return r;
        }
    } else {
        int splitY = node->bounds.top + (int)(h * node->ratio);
        if (y >= splitY - 2 && y <= splitY + SPLITTER_WIDTH + 2 &&
            x >= node->bounds.left && x <= node->bounds.right) {
            SplitHitResult r = { SPLIT_HIT_SPLITTER, node, SPLIT_HORIZONTAL };
            return r;
        }
    }

    /* Recurse into children */
    SplitHitResult found = split_node_hit_test(node->first, x, y);
    if (found.type != SPLIT_HIT_NONE) return found;
    return split_node_hit_test(node->second, x, y);
}
