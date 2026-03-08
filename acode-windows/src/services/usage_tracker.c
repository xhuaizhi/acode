#include "usage_tracker.h"
#include <string.h>

static UsageStats s_stats = {0};

void usage_tracker_add(long long input, long long output, long long cacheRead, long long cacheCreation) {
    s_stats.inputTokens += input;
    s_stats.outputTokens += output;
    s_stats.cacheReadTokens += cacheRead;
    s_stats.cacheCreationTokens += cacheCreation;
    s_stats.requestCount++;

    /* Rough cost estimate (using average pricing) */
    s_stats.estimatedCost =
        (double)s_stats.inputTokens / 1000000.0 * 3.0 +
        (double)s_stats.outputTokens / 1000000.0 * 15.0 +
        (double)s_stats.cacheReadTokens / 1000000.0 * 0.3;
}

void usage_tracker_get(UsageStats *stats) {
    *stats = s_stats;
}

void usage_tracker_reset(void) {
    memset(&s_stats, 0, sizeof(s_stats));
}
