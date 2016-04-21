import QtQuick 1.1

BtnAbstract {
  id: button

  property int imgSize: Math.round(Math.min(button.width, button.height)*2.0/3.0)

  Text {
    text: button.text
    font.pointSize: button.textSize
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
  }
  Image {
    source: button.imgSource
    height: imgSize
    width: imgSize
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter

    anchors.topMargin: imgSize / 12
  }
}

