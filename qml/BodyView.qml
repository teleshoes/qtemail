import QtQuick 2.3

Rectangle {
  anchors.fill: parent
  id: bodyView
  function setHeader(header){
    setZoom(1.0)
    headerText.text = header
  }
  function setBody(body){
    setZoom(1.0)
    bodyText.text = body
  }
  function setSelectable(isSelectable){
    selectable = isSelectable
  }
  function getSelectedText(){
    return bodyText.selectedText
  }

  property bool selectable: false
  property variant scales: [0.1, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 5.0, 10.0]
  property real curScale: 1.0
  property real minScale: 0.1
  property real maxScale: 10.0

  function scrollUp(){
    bodyScrollBar.scrollUp();
  }
  function scrollDown(){
    bodyScrollBar.scrollDown();
  }

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
    bodyFlickable.updateContentSize(!isZoomed)
    bodyFlickable.clip = !isZoomed
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

      transformOrigin = Item.TopLeft
      resizeContent(contentWidth * scale, contentHeight * scale, Qt.point(0,0))
    }

    Rectangle{
      width: parent.width
      height: parent.height
      color: "#FFFFFF"
      TextEdit {
        id: headerText
        readOnly: true
        selectByMouse: true
        color: "#0000FF"
        width: parent.width
        wrapMode: Text.Wrap
        font.pointSize: scaling.fontSmall
      }
      TextEdit {
        id: bodyText
        textFormat: TextEdit.AutoText
        anchors.top: headerText.bottom
        height: parent.height
        width: parent.width
        wrapMode: TextEdit.Wrap
        selectByMouse: bodyView.selectable
        font.pointSize: scaling.fontLarge
        onLinkActivated: main.onLinkActivated(link)
        onFocusChanged: cursorVisible = false
        activeFocusOnPress: false
        MouseArea {
          onClicked: {
            bodyText.clicked(mouse)
            bodyText.cursorVisible = false
          }
          onPressed: {
            if(bodyView.selectable){
              bodyText.pressed(mouse)
            }
          }
          onReleased: {
            if(bodyView.selectable){
              bodyText.released(mouse)
            }
          }
          onPositionChanged: {
            if(bodyView.selectable){
              bodyText.positionChanged(mouse)
            }
          }
          onPressAndHold: {
            if(bodyView.selectable){
              bodyText.pressAndHold(mouse)
            }
          }
        }
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
    id: bodyScrollBar
    flickable: bodyFlickable
    anchors.rightMargin: 0 - 30
  }
}
