@echo off
rem Legacy launcher alias -> Euphorix
java --enable-native-access=ALL-UNNAMED -Dfile.encoding=UTF-8 -Dawt.useSystemAAFontSettings=lcd -Dswing.aatext=true -jar "%~dp0euphorix.jar" %*
