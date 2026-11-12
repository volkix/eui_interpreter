@echo off
rem Launcher for OpenEuphoria Java 25 Interpreter on Windows
java -Dawt.useSystemAAFontSettings=lcd -Dswing.aatext=true -jar "%~dp0eui.jar" %*
