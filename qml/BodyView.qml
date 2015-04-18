import QtQuick 1.1

Rectangle {
  anchors.fill: parent
  id: bodyView
  function setHeader(header){
    headerText.text = header
  }
  function setBody(body){
    bodyText.text = body
  }

  property variant scales: [0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 5.0, 10.0]
  property real curScale: 1.0
  property real minScale: 0.1
  property real maxScale: 10.0

  function zoomIn(){
    setZoom(getNextScale("in"))
  }
  function zoomOut(){
    setZoom(getNextScale("out"))
  }
  function getNextScale(dir){
    for(var i=0; i<scales.length; ++i){
      var scale
      if(dir == "in"){
        scale = scales[i]
      }else if(dir == "out"){
        scale = scales[scales.length - i]
      }
      if(dir == "in" && curScale < scale){
        return scale
      }else if(dir == "out" && curScale > scale){
        return scale
      }
    }
    if(dir == "in"){
      return scales[scales.length - 1]
    }else if(dir == "out"){
      return scales[0]
    }
  }

  function setZoom(scale){
    if(scale < minScale){
      scale = minScale
    }
    if(scale > maxScale){
      scale = maxScale
    }
    curScale = scale
  }

  onCurScaleChanged: {
    bodyFlickable.scale = curScale
    zoomDisplay.text = parseInt(curScale*100) + "%"

    var isZoomed = curScale != 1
    zoomDisplay.visible = isZoomed
  }

  PinchArea{
    anchors.fill: parent
    property real pinchStart: 1.0
    onPinchStarted: {
      pinchStart = curScale
    }
    onPinchUpdated: {
      if (pinch.pointCount < 2){
        return
      }
      setZoom(pinchStart * pinch.scale)
    }
  }

  Flickable {
    id: bodyFlickable
    clip: true
    width: parent.width - 30
    contentWidth: parent.width - 30
    contentHeight: headerText.paintedHeight + bodyText.paintedHeight
    anchors.fill: parent
    flickableDirection: Flickable.HorizontalAndVerticalFlick
    boundsBehavior: Flickable.DragOverBounds

    function updateContentSize(forceWidth){
      contentWidth = forceWidth ? width : Math.max(
        headerText.paintedWidth, bodyText.paintedWidth)
    }

    Rectangle{
      width: parent.width
      height: parent.height
      color: "#FFFFFF"
      Text {
        id: headerText
        color: "#0000FF"
        width: parent.width
        wrapMode: Text.Wrap
        font.pointSize: 18
      }
      Text {
        id: bodyText
        anchors.top: headerText.bottom
        height: parent.height
        width: parent.width
        wrapMode: Text.Wrap
        font.pointSize: 24
        onLinkActivated: main.onLinkActivated(link)
      }
    }
  }

  Text {
    id: zoomDisplay
    visible: false
    anchors.top: parent.top
    anchors.right: parent.right
  }

  ScrollBar{
    flickable: bodyFlickable
    anchors.rightMargin: 0 - 30
  }
}
