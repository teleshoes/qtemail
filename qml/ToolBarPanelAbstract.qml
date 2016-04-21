import QtQuick 1.1

Rectangle {
  id: toolBarPanel

  property variant toolBarButtonDefList
  property variant buttonContainer
  property int btnHeight
  property int btnWidth

  function setVisibleButtonNames(visibleButtonNames){
    for (var i = 0; i < buttonContainer.children.length; ++i){
      var btn = buttonContainer.children[i]
      var isVisible = visibleButtonNames.indexOf(btn.objectName) >= 0
      btn.visible = isVisible
    }

    resetSpacing()
  }

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
    buttonContainer.spacing = spacing
  }
}
