#ifndef ACODE_DATABASE_H
#define ACODE_DATABASE_H

#include <windows.h>
#include <stdbool.h>
#include "sqlite3.h"

bool db_open(const wchar_t *path);
void db_close(void);
sqlite3 *db_get(void);
bool db_exec(const char *sql);
bool db_setup_tables(void);
bool db_seed_model_pricing(void);

#endif /* ACODE_DATABASE_H */
