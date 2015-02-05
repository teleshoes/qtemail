import QtQuick 1.1

ListView {
  spacing: 3
  anchors.fill: parent

  property real labelWidth: 0.30
  property int fontSize: 16

  model: configModel

  delegate: Rectangle {
    property alias label: label.text
    property alias value: edit.text
    property string rowColor: index % 2 == 0 ? "#444444" : "#666666"
    color: rowColor

    height: fontSize * 2
    width: parent.width

    Rectangle {
      id: labelContainer
      width: parent.width * labelWidth
      height: parent.height
      color: rowColor
      anchors.margins: 2

      Text {
        id: label
        anchors.fill: parent
        text: model.config.Name
        font.pointSize: fontSize
      }
    }

    Rectangle {
      id: editContainer
      anchors.left: labelContainer.right
      width: parent.width * (1 - labelWidth)
      height: parent.height
      color: rowColor
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
}
