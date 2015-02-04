project(qtemail)

cmake_minimum_required(VERSION 2.6.2)

FILE(GLOB programs src/*)
INSTALL(PROGRAMS ${programs}
  DESTINATION /usr/bin)

FILE(GLOB qml qml/*.qml)
INSTALL(FILES ${qml}
  DESTINATION /opt/email-gui)
