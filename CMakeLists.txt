cmake_minimum_required(VERSION 3.10)

project(qtemail)

FILE(GLOB programs
  src/email.pl
  src/email-search.pl
  src/email-gui.py
  src/smtp-cli
  src/smtp-oauth
  src/bash-complete.pl
)
INSTALL(PROGRAMS ${programs}
  DESTINATION /opt/qtemail/bin)

FILE(GLOB lib src/QtEmail/*)
INSTALL(FILES ${lib}
  DESTINATION /opt/qtemail/lib/QtEmail)

FILE(GLOB qml qml/*.qml)
INSTALL(FILES ${qml}
  DESTINATION /opt/qtemail/qml)

FILE(GLOB qmlcb qmlcompletionbox/*.qml)
INSTALL(FILES ${qmlcb}
  DESTINATION /opt/qtemail/qml)

FILE(GLOB icons icons/*.png)
INSTALL(FILES ${icons}
  DESTINATION /opt/qtemail/icons)

FILE(GLOB buttonIcons icons/buttons/*.png)
INSTALL(FILES ${buttonIcons}
  DESTINATION /opt/qtemail/icons/buttons)

INSTALL(FILES data/qtemail.desktop
  DESTINATION /usr/share/applications)

INSTALL(FILES bashcompletion/qtemail
  DESTINATION /etc/bash_completion.d)
