import QtQuick 1.1

Rectangle {
  signal enterPressed

  property alias labelText: label.text
  property alias value: edit.text

  property real labelWidth: 0.30
  property int fontSize: 16
  property bool isDark: false

  property string bgColor: isDark ? "#444444" : "#666666"
  color: bgColor

  height: fontSize * 2
  width: parent.width

  function getValue(){
    return value
  }
  function setValue(value){
    this.value = value
  }

  Rectangle {
    id: labelContainer
    width: parent.width * labelWidth
    height: parent.height
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
    anchors.left: labelContainer.right
    width: parent.width * (1 - labelWidth)
    height: parent.height
    color: bgColor
    Rectangle {
      anchors.centerIn: parent
      width: parent.width - 4
      height: parent.height - 4
      color: "#FFFFFF"
      border.color: "#000000"
      border.width: 2

      TextInput {
        anchors.margins: 3
        id: edit
        anchors.fill: parent
        font.pointSize: fontSize
        Keys.onReturnPressed: {
          enterPressed()
        }
      }
    }
  }
}
