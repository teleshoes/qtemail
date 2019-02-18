import QtQuick 2.3

ToolBarPanelAbstract {
  buttonContainer: toolBarRow
  direction: "horizontal"

  desiredBtnHeight: main.scalePixelDensity * 70
  desiredBtnWidth: main.scalePixelDensity * 70
  minBtnHeight: 40
  minBtnWidth: 40
  maxBtnHeight: (width / maxBtnCount) - (2*maxBtnCount)
  maxBtnWidth: (width / maxBtnCount) - (2*maxBtnCount)

  height: btnHeight

  anchors.leftMargin: 10
  anchors.rightMargin: 10

  Row {
    id: toolBarRow
    anchors.fill: parent

    onWidthChanged: resetSpacing()

    Repeater {
      id: buttonRepeater
      model: toolBarButtonDefList.getButtonDefs()
      Btn {
        width: btnWidth
        height: btnHeight
        Component.onCompleted: {textSize = main.fontTiny}
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
