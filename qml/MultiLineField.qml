import QtQuick 1.1

Rectangle {
  id: fieldContainer

  signal enterPressed

  property int cursorY: 0
  property alias editY: editContainer.y
  property alias labelText: label.text
  property alias value: edit.text

  property int fontSize: 16
  property bool isDark: false

  property string bgColor: isDark ? "#444444" : "#666666"
  color: bgColor

  height: labelContainer.height + editContainer.height
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
    property int margin: 4
    property int border: 2

    width: parent.width
    height: edit.paintedHeight + margin*2 + margin*2 + border*2
    color: bgColor
    Rectangle {
      id: editBorder
      color: "#FFFFFF"
      anchors.fill: parent
      border.color: "#000000"
      border.width: parent.border
      anchors.margins: editContainer.margin

      Rectangle {
        id: editMargin
        anchors.fill: parent
        anchors.margins: editContainer.margin
        TextEdit {
          id: edit
          wrapMode: TextEdit.Wrap
          width: parent.width
          font.pointSize: fontSize
          onCursorRectangleChanged: fieldContainer.cursorY = cursorRectangle.y
        }
      }
    }
  }
}
