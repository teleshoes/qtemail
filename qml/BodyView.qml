import QtQuick 1.1

Flickable {
  function setBody(body){
    bodyText.text = body
  }
  contentWidth: bodyText.paintedWidth
  contentHeight: bodyText.paintedHeight
  anchors.fill: parent
  flickableDirection: Flickable.HorizontalAndVerticalFlick
  boundsBehavior: Flickable.DragOverBounds
  Rectangle{
    anchors.fill: parent
    color: white
    Text {
      id: bodyText
      anchors.fill: parent
      font.pointSize: 24
    }
  }
}
