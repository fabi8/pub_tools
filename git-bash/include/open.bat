:loop

if "%~1"=="" goto exit
start "" "%~1"
shift
goto loop

:exit
exit
