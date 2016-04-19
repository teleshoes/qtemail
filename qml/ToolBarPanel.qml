import QtQuick 1.1

Rectangle {
  id: toolBar
  anchors.left: parent.left
  anchors.right: parent.right
  anchors.bottom: parent.bottom

  anchors.leftMargin: 10
  anchors.rightMargin: 10

  height: toolBar.btnHeight

  property variant toolBarButtons

  property int btnHeight: 48
  property int btnWidth: 48

  function resetButtons(activePageNames){
    var okButtonNames = []
    for (var p = 0; p < activePageNames.length; ++p){
      var pageName = activePageNames[p]
      var buttonNames = toolBarButtons.pages[pageName]["buttons"]
      for (var b = 0; b < buttonNames.length; ++b){
        var objectName = "toolbarButton-" + buttonNames[b]
        okButtonNames.push(objectName)
      }
    }

    for (var i = 0; i < toolBarButtonsPanel.children.length; ++i){
      var btn = toolBarButtonsPanel.children[i]
      var isVisible = okButtonNames.indexOf(btn.objectName) >= 0
      btn.visible = isVisible
    }

    toolBarButtonsPanel.resetSpacing()
  }

  Row {
    id: toolBarButtonsPanel
    anchors.fill: parent

    onWidthChanged: resetSpacing()

    function resetSpacing() {
      var btnCount = 0
      for (var i = 0; i < toolBarButtonsPanel.children.length; ++i){
        if(toolBarButtonsPanel.children[i].visible) {
          btnCount++;
        }
      }
      var totalSpace = toolBar.width
      var usedSpace = toolBar.btnWidth*btnCount
      var emptySpace = totalSpace - usedSpace

      var spaceCount = btnCount - 1

      var spacing = 0
      if(spaceCount > 0){
        spacing = Math.floor(emptySpace/spaceCount + 0.5)
      }
      if(spacing < 2){
        spacing = 2
      }
      toolBarButtonsPanel.spacing = spacing
    }

    Repeater {
      id: buttonRepeater
      model: toolBarButtons.getButtonDefs()
      Btn {
        width: toolBar.btnWidth
        height: toolBar.btnHeight
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
