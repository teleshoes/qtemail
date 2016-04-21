import QtQuick 1.1

BtnAbstract {
  id: button

  Text {
    text: button.text
    font.pointSize: button.textSize
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
  }
  Image {
    source: button.imgSource
    anchors.fill: parent
    anchors.topMargin: button.height / 12
    anchors.bottomMargin: button.height / 4
    anchors.leftMargin: button.width / 10
    anchors.rightMargin: button.width / 10
  }
}

