import QtQuick 2.3

ToolBarPanelAbstract {
  buttonContainer: toolBarColumn
  direction: "vertical"

  desiredBtnHeight: scaling.scalePixelDensity * 80
  desiredBtnWidth: scaling.scalePixelDensity * 300
  minBtnHeight: 40
  minBtnWidth: 80
  maxBtnHeight: (height / maxBtnCount) - (2*maxBtnCount)
  maxBtnWidth: parent.width

  width: btnWidth

  anchors.topMargin: 50
  anchors.bottomMargin: 30

  Column {
    id: toolBarColumn
    anchors.fill: parent

    onHeightChanged: resetSpacing()

    Repeater {
      id: buttonRepeater
      model: toolBarButtonDefList.getButtonDefs()
      BtnWide {
        width: btnWidth
        height: btnHeight
        Component.onCompleted: {textSize = scaling.fontLarge}
        function setText(text){
          this.text = text
        }
        objectName: toolBarName + "-" + modelData.name
        text: modelData.text
        imgSource: "/opt/qtemail/icons/buttons/" + modelData.name + ".png"
        onClicked: modelData.clicked()
        visible: false
      }
    }
  }
}
