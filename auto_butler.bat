set pathToSend=C:\Users\Tiamo\Documents\Programming\Games\Sheepe\non_game\deliverables
set butlerName=pandaqi/rolling-in-the-sheepe

butler push "%pathToSend%\windows" %butlerName%:windows
butler push "%pathToSend%\mac" %butlerName%:mac
butler push "%pathToSend%\linux" %butlerName%:linux

butler push "%pathToSend%\windows_demo" %butlerName%:windows_demo
butler push "%pathToSend%\mac_demo" %butlerName%:mac_demo
butler push "%pathToSend%\linux_demo" %butlerName%:linux_demo

pause