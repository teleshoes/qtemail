import QtQuick 2.3

ToolBarPanelAbstract {
  buttonContainer: toolBarColumn
  btnHeight: 60
  btnWidth: 240
  direction: "vertical"

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
        Component.onCompleted: {textSize = main.fontLarge}
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
