import QtQuick 2.3

QtObject {
  // order is determined by 'buttonDefs', not 'pages'
  property variant pages: {
    "accountPage": {
      "buttons": ["newAccount", "options", "update"],
      "buttonsExtra": [],
    },
    "folderPage": {
      "buttons": ["back"],
      "buttonsExtra": [],
    },
    "headerPage": {
      "buttons": ["back", "more", "markAllRead", "hideKb", "showExtra"],
      "buttonsExtra": ["config", "send", "wayMore", "all", "folder"],
    },
    "bodyPage": {
      "buttons": ["back", "toggleHtml", "toggleSelectable", "copy", "showExtra"],
      "buttonsExtra": ["reply", "forward", "zoomIn", "zoomOut", "cmd", "attachments"],
    },
    "configPage": {
      "buttons": ["back", "hideKb", "submit"],
      "buttonsExtra": [],
    },
    "sendPage": {
      "buttons": ["back", "hideKb", "sendEmail"],
      "buttonsExtra": [],
    },
  }

  function getButtonDefs(){
    return buttonDefs
  }
  function getButtonDefByName(name){
    for (var i = 0; i < buttonDefs.length; ++i){
      var buttonDef = buttonDefs[i]
      var btnName = buttonDef.name
      if(name == btnName){
        return buttonDef
      }
    }
    return null
  }

  property list<ToolBarButtonDef> buttonDefs: [
    ToolBarButtonDef {
      name: "back"
      text: "back"
      onClicked: main.backPage()
    },
    ToolBarButtonDef {
      name: "config"
      text: "config"
      onClicked: {
        controller.setConfigMode("account")
        navToPage(configPage)
      }
    },
    ToolBarButtonDef {
      name: "newAccount"
      text: "new acc"
      onClicked: {
        controller.setConfigMode("account")
        navToPage(configPage)
      }
    },
    ToolBarButtonDef {
      name: "options"
      text: "options"
      onClicked: {
        controller.setConfigMode("options")
        navToPage(configPage)
      }
    },
    ToolBarButtonDef {
      name: "send"
      text: "write"
      onClicked: navToPage(sendPage)
    },
    ToolBarButtonDef {
      name: "reply"
      text: "reply"
      onClicked: {
        controller.initSend("reply", sendView.getForm())
        navToPage(sendPage)
      }
    },
    ToolBarButtonDef {
      name: "forward"
      text: "forward"
      onClicked: {
        controller.initSend("forward", sendView.getForm())
        navToPage(sendPage)
      }
    },
    ToolBarButtonDef {
      name: "update"
      text: "update"
      onClicked: accountView.updateAllAccounts()
    },
    ToolBarButtonDef {
      name: "submit"
      text: "submit"
      onClicked: {
        if(controller.saveConfig()){
          main.backPage()
        }
      }
    },
    ToolBarButtonDef {
      name: "more"
      text: "more"
      onClicked: {
        controller.moreHeaders(0)
        controller.updateCounterBox(headerView.getCounterBox())
      }
    },
    ToolBarButtonDef {
      name: "wayMore"
      text: "+30%"
      onClicked: {
        controller.moreHeaders(30)
        controller.updateCounterBox(headerView.getCounterBox())
      }
    },
    ToolBarButtonDef {
      name: "all"
      text: "all"
      onClicked: {
        controller.moreHeaders(100)
        controller.updateCounterBox(headerView.getCounterBox())
      }
    },
    ToolBarButtonDef {
      name: "markAllRead"
      text: "all=>read"
      onClicked: {
        controller.markAllRead()
      }
    },
    ToolBarButtonDef {
      name: "folder"
      text: "folders"
      onClicked: navToPage(folderPage)
    },
    ToolBarButtonDef {
      name: "toggleHtml"
      text: "html"
      onClicked: {
        var wasHtml = controller.getHtmlMode()
        controller.setHtmlMode(!wasHtml)
        setIsHtml(!wasHtml)
        controller.fetchCurrentBodyText(bodyView, bodyView)
      }
      function setIsHtml(isHtml){
        text = isHtml ? "text" : "html"
      }
    },
    ToolBarButtonDef {
      name: "toggleSelectable"
      text: "select on"
      onClicked: {
        setIsSelectable(!getIsSelectable())
      }
      function getIsSelectable(){
        return bodyView.selectable
      }
      function setIsSelectable(isSelectable){
        text = isSelectable ? "select off" : "select on"
        bodyView.selectable = isSelectable
      }
    },
    ToolBarButtonDef {
      name: "copy"
      text: "copy"
      onClicked: controller.copyBodyToClipboard(bodyView)
    },
    ToolBarButtonDef {
      name: "zoomIn"
      text: "zoom in"
      onClicked: bodyView.zoomIn()
    },
    ToolBarButtonDef {
      name: "zoomOut"
      text: "zoom out"
      onClicked: bodyView.zoomOut()
    },
    ToolBarButtonDef {
      name: "cmd"
      text: "cmd"
      onClicked: controller.runCustomCommand()
    },
    ToolBarButtonDef {
      name: "attachments"
      text: "attach"
      onClicked: controller.saveCurrentAttachments()
    },
    ToolBarButtonDef {
      name: "hideKb"
      text: "hide KB"
      onClicked: main.hideKb()
    },
    ToolBarButtonDef {
      name: "sendEmail"
      text: "send"
      onClicked: controller.sendEmail(sendView.getForm())
    },
    ToolBarButtonDef {
      name: "showExtra"
      text: "menu"
      onClicked: toolBarManager.toggleExtraToolBarVisible()
    }
  ]
}

