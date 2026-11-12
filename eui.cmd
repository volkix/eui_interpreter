@echo off
rem Legacy launcher alias -> Euphorix
java -Dfile.encoding=UTF-8 -Dawt.useSystemAAFontSettings=lcd -Dswing.aatext=true -jar "%~dp0euphorix.jar" %*
