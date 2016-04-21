import QtQuick 1.1

Rectangle {
  id: toolBarPanel

  property variant buttonContainer: toolBarRow
  anchors.leftMargin: 10
  anchors.rightMargin: 10

  height: btnHeight

  property variant toolBarButtonDefList

  property int btnHeight: 48
  property int btnWidth: 48

  function setVisibleButtonNames(visibleButtonNames){
    for (var i = 0; i < buttonContainer.children.length; ++i){
      var btn = buttonContainer.children[i]
      var isVisible = visibleButtonNames.indexOf(btn.objectName) >= 0
      btn.visible = isVisible
    }

    toolBarRow.resetSpacing()
  }

  Row {
    id: toolBarRow
    anchors.fill: parent

    onWidthChanged: resetSpacing()

    function resetSpacing() {
      var btnCount = 0
      for (var i = 0; i < buttonContainer.children.length; ++i){
        if(buttonContainer.children[i].visible) {
          btnCount++;
        }
      }
      var totalSpace = toolBarPanel.width
      var usedSpace = toolBarPanel.btnWidth*btnCount
      var emptySpace = totalSpace - usedSpace

      var spaceCount = btnCount - 1

      var spacing = 0
      if(spaceCount > 0){
        spacing = Math.floor(emptySpace/spaceCount + 0.5)
      }
      if(spacing < 2){
        spacing = 2
      }
      toolBarRow.spacing = spacing
    }

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
