# SQLite Amalgamation

Download from https://www.sqlite.org/download.html

Place `sqlite3.c` and `sqlite3.h` in this directory.

Quick download (Windows PowerShell):
```powershell
Invoke-WebRequest -Uri "https://www.sqlite.org/2024/sqlite-amalgamation-3450100.zip" -OutFile sqlite.zip
Expand-Archive sqlite.zip -DestinationPath .
Move-Item sqlite-amalgamation-*\sqlite3.c .
Move-Item sqlite-amalgamation-*\sqlite3.h .
Remove-Item -Recurse sqlite-amalgamation-*, sqlite.zip
```
