import QtQuick 1.1

Rectangle {
  anchors.fill: parent
  id: bodyView
  function setBody(body){
    bodyText.text = body
  }

  Flickable {
    id: bodyFlickable
    contentWidth: bodyText.paintedWidth
    contentHeight: bodyText.paintedHeight
    anchors.fill: parent
    flickableDirection: Flickable.HorizontalAndVerticalFlick
    boundsBehavior: Flickable.DragOverBounds
    Rectangle{
      anchors.fill: parent
      color: "#FFFFFF"
      Text {
        id: bodyText
        anchors.fill: parent
        font.pointSize: 24
        onLinkActivated: main.onLinkActivated(link)
      }
    }
  }

  ScrollBar{
    flickable: bodyFlickable
    anchors.rightMargin: 0 - 30
  }
}
