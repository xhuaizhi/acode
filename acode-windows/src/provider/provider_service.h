#ifndef ACODE_PROVIDER_SERVICE_H
#define ACODE_PROVIDER_SERVICE_H

#include <windows.h>
#include <stdbool.h>
#include "provider.h"

bool provider_service_get_active(const char *tool, Provider *out);
void provider_service_generate_env(wchar_t *envBlock, int envBlockChars);
bool provider_service_write_config(const Provider *p);

#endif /* ACODE_PROVIDER_SERVICE_H */
