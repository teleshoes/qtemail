import QtQuick 1.1

Rectangle {
  id: toolBarManager

  property ToolBarButtonDefList toolBarButtonDefList
  property ToolBarPanel mainToolBar

  function resetButtons(activePageNames){
    var okButtonNames = []
    for (var p = 0; p < activePageNames.length; ++p){
      var pageName = activePageNames[p]
      var buttonNames = []
      buttonNames = buttonNames.concat(toolBarButtonDefList.pages[pageName]["buttons"])
      buttonNames = buttonNames.concat(toolBarButtonDefList.pages[pageName]["buttonsExtra"])
      for (var b = 0; b < buttonNames.length; ++b){
        var objectName = "toolbarButton-" + buttonNames[b]
        okButtonNames.push(objectName)
      }
    }

    mainToolBar.setVisibleButtonNames(okButtonNames)
  }
}
