@echo off
rem Euphorix: High-Performance Java 25 VM for OpenEuphoria Syntax
java --enable-native-access=ALL-UNNAMED -Dfile.encoding=UTF-8 -Dawt.useSystemAAFontSettings=lcd -Dswing.aatext=true -jar "%~dp0euphorix.jar" %*
