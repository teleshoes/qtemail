import QtQuick 1.1

Rectangle {
  id: button

  signal clicked()

  property string imgSource: ""
  property string text: ""
  property int textSize: main.fontSmall

  property variant hover: false
  property variant buttonColorDefault: "gray"
  property variant buttonColorGradient: "white"
  property variant buttonColor: buttonColorDefault

  width: 100
  height: 120

  border.color: "black"
  border.width: 5

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
}
