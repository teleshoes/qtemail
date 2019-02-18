import QtQuick 2.3

Rectangle {
  id: toolBarManager

  property ToolBarButtonDefList toolBarButtonDefList
  property ToolBarPanelAbstract mainToolBar
  property ToolBarPanelAbstract extraToolBar
  property variant excludeButtonNames //list<string>

  function getAllPageNames(){
    return Object.keys(toolBarButtonDefList.pages);
  }

  function getTotalBtnCount(mainOrExtra, pageNames){
    var buttonNamesForPages = getButtonNamesForPages(pageNames);
    if(mainOrExtra == "main" && extraToolBar == null){
      return buttonNamesForPages["main"].length + buttonNamesForPages["extra"].length;
    }else if(mainOrExtra == "main" && extraToolBar != null){
      return buttonNamesForPages["main"].length;
    }else if(mainOrExtra == "extra" && extraToolBar == null){
      return 0;
    }else if(mainOrExtra == "extra" && extraToolBar != null){
      return buttonNamesForPages["extra"].length;
    }
  }

  function getMaxBtnCount(mainOrExtra, pageNames){
    var maxBtnCount = 0;
    for(var i=0; i<pageNames.length; i++){
      var pageName = pageNames[i];
      var buttonNames = getButtonNamesForPages([pageName]);
      var btnCount;
      if(mainOrExtra == "main" && extraToolBar == null){
        btnCount = buttonNames["main"].length + buttonNames["extra"].length;
      }else if(mainOrExtra == "main" && extraToolBar != null){
        btnCount = buttonNames["main"].length;
      }else if(mainOrExtra == "extra" && extraToolBar == null){
        btnCount = 0;
      }else if(mainOrExtra == "extra" && extraToolBar != null){
        btnCount = buttonNames["extra"].length;
      }

      if(btnCount > maxBtnCount){
        maxBtnCount = btnCount;
      }
    }
    return maxBtnCount;
  }

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
