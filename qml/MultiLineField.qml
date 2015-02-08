import QtQuick 1.1

Rectangle {
  signal enterPressed

  property alias labelText: label.text
  property alias value: edit.text

  property int fontSize: 16
  property bool isDark: false

  property string bgColor: isDark ? "#444444" : "#666666"
  color: bgColor

  height: 500
  width: parent.width

  Rectangle {
    id: labelContainer
    width: parent.width
    height: fontSize * 2
    color: bgColor
    anchors.margins: 2

    Text {
      id: label
      anchors.fill: parent
      font.pointSize: fontSize
    }
  }

  Rectangle {
    id: editContainer
    anchors.top: labelContainer.bottom
    width: parent.width
    height: parent.height - labelContainer.height
    color: bgColor
    Rectangle {
      anchors.centerIn: parent
      width: parent.width - 4
      height: parent.height - 4
      color: "#FFFFFF"
      border.color: "#000000"
      border.width: 2

      TextEdit {
        anchors.margins: 3
        id: edit
        anchors.fill: parent
        font.pointSize: fontSize
      }
    }
  }
}
