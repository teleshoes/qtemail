project(qtemail)

cmake_minimum_required(VERSION 2.6.2)

FILE(GLOB programs src/*)
INSTALL(PROGRAMS ${programs}
  DESTINATION /opt/qtemail/bin)

FILE(GLOB qml qml/*.qml)
INSTALL(FILES ${qml}
  DESTINATION /opt/qtemail/qml)

FILE(GLOB images images/*)
INSTALL(FILES ${images}
  DESTINATION /opt/qtemail/images)

INSTALL(FILES data/qtemail.desktop
  DESTINATION /usr/share/applications)
