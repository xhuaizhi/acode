#ifndef ACODE_USAGE_TRACKER_H
#define ACODE_USAGE_TRACKER_H

#include <windows.h>
#include <stdbool.h>

typedef struct {
    long long inputTokens;
    long long outputTokens;
    long long cacheReadTokens;
    long long cacheCreationTokens;
    int       requestCount;
    double    estimatedCost;
} UsageStats;

void usage_tracker_add(long long input, long long output, long long cacheRead, long long cacheCreation);
void usage_tracker_get(UsageStats *stats);
void usage_tracker_reset(void);

#endif /* ACODE_USAGE_TRACKER_H */
