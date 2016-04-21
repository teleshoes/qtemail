import QtQuick 1.1

Rectangle {
  id: toolBarManager

  property ToolBarButtonDefList toolBarButtonDefList
  property ToolBarPanelAbstract mainToolBar
  property ToolBarPanelAbstract extraToolBar

  function isExtraToolBarVisible(){
    return extraToolBar != null && extraToolBar.visible
  }
  function toggleExtraToolBarVisible(){
    setExtraToolBarVisible(!isExtraToolBarVisible())
  }
  function setExtraToolBarVisible(isVisible){
    if(extraToolBar != null){
      extraToolBar.visible = isVisible
      extraToolBar.resetSpacing()
    }
  }

  function resetButtons(activePageNames){
    var okMainButtonNames = []
    var okExtraButtonNames = []
    for (var p = 0; p < activePageNames.length; ++p){
      var pageName = activePageNames[p]
      var pageMainButtonNames = toolBarButtonDefList.pages[pageName]["buttons"]
      var pageExtraButtonNames = toolBarButtonDefList.pages[pageName]["buttonsExtra"]

      okMainButtonNames = okMainButtonNames.concat(pageMainButtonNames)
      okExtraButtonNames = okExtraButtonNames.concat(pageExtraButtonNames)
    }

    if(extraToolBar == null){
      mainToolBar.setVisibleButtonNames(okMainButtonNames.concat(okExtraButtonNames))
    }else{
      mainToolBar.setVisibleButtonNames(okMainButtonNames)
      extraToolBar.setVisibleButtonNames(okExtraButtonNames)
      extraToolBar.visible = false
    }
  }
}
