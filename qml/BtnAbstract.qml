import QtQuick 2.3

Rectangle {
  id: button

  signal clicked(var mouse)
  signal pressAndHold(var mouse)

  property string imgSource: ""
  property string text: ""
  property int textSize: scaling.fontSmall

  property variant hover: false
  property variant buttonColorDefault: "gray"
  property variant buttonColorGradient: "white"
  property variant buttonColor: buttonColorDefault

  width: scaling.scalePixelDensity * 100
  height: scaling.scalePixelDensity * 120

  property double borderMin: 2
  property double borderMax: 5
  property double borderWidth: scaling.scalePixelDensity * 5

  border.color: "black"
  border.width: Math.round(Math.min(borderMax, Math.max(borderMin, borderWidth)))
  radius: 8

  MouseArea {
    id: mouseArea
    hoverEnabled: true
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: button.clicked(mouse)
    onPressAndHold: button.pressAndHold(mouse)
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

