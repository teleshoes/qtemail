import QtQuick 1.1

BtnAbstract {
  id: button
  Row {
    anchors.fill: parent
    spacing: Math.max(5, button.height / 5)

    Image {
      id: buttonImage
      source: button.imgSource
      height: button.height
      width: button.height
    }

    Text {
      id: buttonText
      text: button.text
      width: parent.width - buttonImage.width

      font.pointSize: button.textSize
      anchors.verticalCenter: buttonImage.verticalCenter
    }
  }
}
