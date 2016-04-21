import QtQuick 1.1

Rectangle {
  id: toolBarManager

  property ToolBarButtonDefList toolBarButtonDefList
  property ToolBarPanelAbstract mainToolBar
  property ToolBarPanelAbstract extraToolBar

  function isExtraToolBarVisible(){
    return extraToolBar.visible
  }
  function toggleExtraToolBarVisible(){
    setExtraToolBarVisible(!isExtraToolBarVisible())
  }
  function setExtraToolBarVisible(isVisible){
    extraToolBar.visible = isVisible
    extraToolBar.resetSpacing()
  }

  function resetButtons(activePageNames){
    var okButtonNames = []
    for (var p = 0; p < activePageNames.length; ++p){
      var pageName = activePageNames[p]
      var buttonNames = []
      okButtonNames = okButtonNames.concat(toolBarButtonDefList.pages[pageName]["buttons"])
      okButtonNames = okButtonNames.concat(toolBarButtonDefList.pages[pageName]["buttonsExtra"])
    }

    mainToolBar.setVisibleButtonNames(okButtonNames)
  }
}
