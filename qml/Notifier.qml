import QtQuick 2.3

Rectangle {
  property int hideTimeout: 5000

  id: notificationArea
  x: parent.width * 0.10
  y: parent.height * 0.10
  width: parent.width * 0.80
  height: notificationBox.height
  clip: true
  opacity: 0.9
  visible: false
  z: 100
  color: "#dddddd"

  property bool enabled: true
  property string text: notifierModel.Text
  property bool showing: notifierModel.Showing

  onShowingChanged: showing ? show() : hide()

  function show(){
    if(!enabled){
      return
    }
    notificationArea.visible = true

    if(notifierModel.HideDelay){
      hideTimer.start()
    }else{
      hideTimer.stop()
    }
  }
  function hide(){
    notificationArea.visible = false
  }

  MouseArea {
    anchors.fill: parent
    onClicked: notificationArea.visible = false
  }

  Timer {
    id: hideTimer
    interval: hideTimeout
    repeat: false
    onTriggered: {
      notifierModel.setShowing(false)
    }
  }

  Text {
    id: notificationBox
    width: parent.width
    wrapMode: Text.Wrap
    font.pointSize: scaling.fontHuge
    text: notificationArea.text
  }
}

