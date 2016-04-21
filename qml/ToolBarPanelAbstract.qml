import QtQuick 1.1

Rectangle {
  id: toolBarPanel

  property ToolBarButtonDefList toolBarButtonDefList
  property variant buttonContainer
  property int btnHeight
  property int btnWidth
  property string toolBarName
  property string direction

  function prefixStrList(prefix, listStr){
    return listStr.map(function(s){ return prefix + s })
  }

  function setVisibleButtonNames(visibleButtonNames){
    var visibleButtonObjectNames = prefixStrList(toolBarName + "-", visibleButtonNames)

    for (var i = 0; i < buttonContainer.children.length; ++i){
      var btn = buttonContainer.children[i]
      var isVisible = visibleButtonObjectNames.indexOf(btn.objectName) >= 0
      btn.visible = isVisible
    }

    resetSpacing()
  }

  function resetSpacing(){
    resetSpacingTimer.restart()
  }
  Timer {
    id: resetSpacingTimer
    interval: 1; //0.001s
    onTriggered: resetSpacingImmediately()
  }
  function resetSpacingImmediately() {
    if(!toolBarPanel.visible || toolBarPanel.width <= 0 || toolBarPanel.height <= 0){
      return
    }
    var btnCount = 0
    for (var i = 0; i < buttonContainer.children.length; ++i){
      if(buttonContainer.children[i].visible) {
        btnCount++;
      }
    }
    var totalSpace
    var usedSpace
    if(direction == "horizontal"){
      totalSpace = toolBarPanel.width
      usedSpace = toolBarPanel.btnWidth*btnCount
    } else if(direction == "vertical"){
      totalSpace = toolBarPanel.height
      usedSpace = toolBarPanel.btnHeight*btnCount
    } else {
      console.log("toolbar direction must be 'horizontal' or 'vertical'")
      return
    }
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
