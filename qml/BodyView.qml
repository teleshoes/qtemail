import QtQuick 1.1

Rectangle {
  anchors.fill: parent
  id: bodyView
  function setBody(body){
    bodyText.text = body
  }

  PinchFlick{
    anchors.fill: parent
    pinch.minimumScale: 0.1
    pinch.maximumScale: 10
    pinch.target: bodyFlickable
  }

  Flickable {
    id: bodyFlickable
    contentWidth: parent.width
    contentHeight: bodyText.paintedHeight
    anchors.fill: parent
    flickableDirection: Flickable.HorizontalAndVerticalFlick
    boundsBehavior: Flickable.DragOverBounds
    Rectangle{
      anchors.fill: parent
      color: "#FFFFFF"
      Text {
        id: bodyText
        height: parent.height
        width: parent.width
        wrapMode: Text.Wrap
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
