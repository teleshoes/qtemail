import QtQuick 1.1

ToolBarPanelAbstract {
  buttonContainer: toolBarRow
  btnHeight: 48
  btnWidth: 48
  direction: "horizontal"

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
        objectName: "toolbarButton-" + modelData.name
        text: modelData.text
        imgSource: "/opt/qtemail/icons/buttons/" + modelData.name + ".png"
        onClicked: modelData.clicked()
        visible: false
      }
    }
  }
}
