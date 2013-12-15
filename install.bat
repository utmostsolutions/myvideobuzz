
set CURDIR=%~dp0

del /F /Q %CURDIR%\myvideobuzz.zip

"C:\Program Files\7-Zip\7z.exe" a -r -tzip -xr@exclude.txt %CURDIR%\myvideobuzz.zip %CURDIR%\*

Roku.Deploy.exe "%CURDIR%\myvideobuzz.zip" "http://192.168.1.9/plugin_install" "rokudev" "abcd"


