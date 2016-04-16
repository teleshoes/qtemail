import QtQuick 1.1

Rectangle {
  id: button
  width: 100
  height: 120
  signal clicked()
  property string imgSource: ""
  property string text: ""
  property int textSize: main.fontSmall

  border.color: "black"
  border.width: 5
  property variant hover: false
  property variant buttonColorDefault: "gray"
  property variant buttonColorGradient: "white"
  property variant buttonColor: buttonColorDefault
  MouseArea {
    id: mouseArea
    hoverEnabled: true
    anchors.fill: parent
    onClicked: button.clicked()
    function setColor(){
      if(this.pressed){
        parent.buttonColor = Qt.lighter(parent.buttonColorDefault)
      }else if(this.containsMouse){
        parent.buttonColor = Qt.darker(parent.buttonColorDefault)
      }else{
        parent.buttonColor = parent.buttonColorDefault
      }
    }
    Timer {
      id: colorTimer
      interval: 50;
      onTriggered: mouseArea.setColor()
    }
    onEntered: colorTimer.restart()
    onExited: colorTimer.restart()
    onPressed: colorTimer.restart()
    onReleased: colorTimer.restart()
  }
  gradient: Gradient {
    GradientStop { position: 0.0; color: buttonColor }
    GradientStop { position: 1.0; color: buttonColorGradient }
  }

  Text {
    text: button.text
    font.pointSize: button.textSize
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
  }
  Image {
    source: button.imgSource
    anchors.fill: parent
    anchors.topMargin: button.height / 12
    anchors.bottomMargin: button.height / 4
    anchors.leftMargin: button.width / 10
    anchors.rightMargin: button.width / 10
  }
}

