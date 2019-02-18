import QtQuick 2.3

Rectangle {
  id: toolBarManager

  property ToolBarButtonDefList toolBarButtonDefList
  property ToolBarPanelAbstract mainToolBar
  property ToolBarPanelAbstract extraToolBar
  property variant excludeButtonNames //list<string>

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

  function getButtonNamesForPages(pageNames){
    var okMainButtonNames = []
    var okExtraButtonNames = []
    for (var p=0; p<pageNames.length; p++){
      var pageName = pageNames[p]
      var pageMainButtonNames = toolBarButtonDefList.pages[pageName]["buttons"]
      var pageExtraButtonNames = toolBarButtonDefList.pages[pageName]["buttonsExtra"]

      okMainButtonNames = okMainButtonNames.concat(pageMainButtonNames)
      okExtraButtonNames = okExtraButtonNames.concat(pageExtraButtonNames)
    }

    if(excludeButtonNames != null && excludeButtonNames.length > 0){
      okMainButtonNames = filterButtonNames(okMainButtonNames, excludeButtonNames)
      okExtraButtonNames = filterButtonNames(okExtraButtonNames, excludeButtonNames)
    }
    okMainButtonNames = uniqueList(okMainButtonNames)
    okExtraButtonNames = uniqueList(okExtraButtonNames)

    return {
      "main":  okMainButtonNames,
      "extra": okExtraButtonNames,
    };
  }

  function resetButtons(activePageNames){
    var buttonNamesForPages = getButtonNamesForPages(activePageNames);

    var okMainButtonNames = buttonNamesForPages["main"];
    var okExtraButtonNames = buttonNamesForPages["extra"];

    if(extraToolBar == null){
      mainToolBar.setVisibleButtonNames(okMainButtonNames.concat(okExtraButtonNames));
    }else{
      mainToolBar.setVisibleButtonNames(okMainButtonNames);
      extraToolBar.setVisibleButtonNames(okExtraButtonNames);
      extraToolBar.visible = false;
    }
  }

  function uniqueList(list) {
    var seenKeys = {};
    var newList = [];
    for(var i=0; i<list.length; i++){
      var e = list[i];
      if(seenKeys[e] == null){
        seenKeys[e] = 1;
        newList.push(e);
      }
    }
    return newList;
  }

  function filterButtonNames(buttonNames, buttonNamesToRemove) {
    var filteredButtonNames = []
    for (var i=0; i < buttonNames.length; i++){
      var buttonName = buttonNames[i]
      if(buttonNamesToRemove.indexOf(buttonName) < 0){
        filteredButtonNames.push(buttonName)
      }
    }
    return filteredButtonNames
  }
}
