#include "provider_service.h"
#include "config_writer.h"
#include "env_generator.h"
#include "../database/database.h"
#include <stdio.h>
#include <string.h>

bool provider_service_get_active(const char *tool, Provider *out) {
    Provider *list = NULL;
    int count = 0;

    if (!provider_list(tool, &list, &count)) return false;

    bool found = false;
    for (int i = 0; i < count; i++) {
        if (list[i].isActive) {
            memcpy(out, &list[i], sizeof(Provider));
            found = true;
            break;
        }
    }

    provider_free_list(list);
    return found;
}

void provider_service_generate_env(wchar_t *envBlock, int envBlockChars) {
    env_generator_build(envBlock, envBlockChars);
}

bool provider_service_write_config(const Provider *p) {
    return config_writer_write(p);
}
