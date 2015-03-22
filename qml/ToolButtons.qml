import QtQuick 1.1

QtObject {
  property variant pages: {
    "accountPage": ["newAccount", "update", "options"],
    "folderPage": ["back"],
    "headerPage": ["back", "more", "wayMore", "all", "config", "send", "folder"],
    "bodyPage": ["back", "attachments", "toggleHtml", "reply", "forward", "copy", "zoom-in", "zoom-out"],
    "configPage": ["back", "submit"],
    "sendPage": ["back", "sendEmail"],
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
  function getButtonElemByName(name){
    return controller.findChild(toolBar, "toolbarButton-" + name)
  }

  property list<QtObject> buttonDefs: [
    QtObject {
      signal clicked
      property variant name: "back"
      property variant text: "back"
      property variant iconName: "tab-previous"
      onClicked: main.backPage()
    },
    QtObject {
      signal clicked
      property variant name: "config"
      property variant text: "config"
      property variant iconName: "settings"
      onClicked: {
        controller.setConfigMode("account")
        navToPage(configPage)
      }
    },
    QtObject {
      signal clicked
      property variant name: "newAccount"
      property variant text: "new acc"
      property variant iconName: "add"
      onClicked: {
        controller.setConfigMode("account")
        navToPage(configPage)
      }
    },
    QtObject {
      signal clicked
      property variant name: "options"
      property variant text: "options"
      property variant iconName: "settings"
      onClicked: {
        controller.setConfigMode("options")
        navToPage(configPage)
      }
    },
    QtObject {
      signal clicked
      property variant name: "send"
      property variant text: "write"
      property variant iconName: "new-email"
      onClicked: navToPage(sendPage)
    },
    QtObject {
      signal clicked
      property variant name: "reply"
      property variant text: "reply"
      property variant iconName: "reply"
      onClicked: {
        controller.initSend("reply", sendView.getForm(), notifier)
        navToPage(sendPage)
      }
    },
    QtObject {
      signal clicked
      property variant name: "forward"
      property variant text: "forward"
      property variant iconName: "forward"
      onClicked: {
        controller.initSend("forward", sendView.getForm(), notifier)
        navToPage(sendPage)
      }
    },
    QtObject {
      signal clicked
      property variant name: "sendEmail"
      property variant text: "send"
      property variant iconName: "done"
      onClicked: controller.sendEmail(sendView.getForm(), notifier)
    },
    QtObject {
      signal clicked
      property variant name: "update"
      property variant text: "update"
      property variant iconName: "refresh"
      onClicked: accountView.updateAllAccounts()
    },
    QtObject {
      signal clicked
      property variant name: "submit"
      property variant text: "submit"
      property variant iconName: "done"
      onClicked: {
        if(controller.saveConfig(notifier)){
          main.backPage()
        }
      }
    },
    QtObject {
      signal clicked
      property variant name: "more"
      property variant text: "more"
      property variant iconName: "down"
      onClicked: controller.moreHeaders(headerView, 0)
    },
    QtObject {
      signal clicked
      property variant name: "wayMore"
      property variant text: "+30%"
      property variant iconName: "down"
      onClicked: controller.moreHeaders(headerView, 30)
    },
    QtObject {
      signal clicked
      property variant name: "all"
      property variant text: "all"
      property variant iconName: "down"
      onClicked: controller.moreHeaders(headerView, 100)
    },
    QtObject {
      signal clicked
      property variant name: "folder"
      property variant text: "folders"
      property variant iconName: "directory"
      onClicked: navToPage(folderPage)
    },
    QtObject {
      signal clicked
      property variant name: "toggleHtml"
      property variant text: "html"
      property variant iconName: "jump-to-dimmed-white"
      function setIsHtml(isHtml){
        var btnElem = getButtonElemByName(name)
        btnElem.setText(isHtml ? "text" : "html")
      }
      onClicked: {
        var wasHtml = controller.getHtmlMode()
        controller.setHtmlMode(!wasHtml)
        setIsHtml(!wasHtml)
        controller.fetchCurrentBodyText(notifier, bodyView, null)
      }
    },
    QtObject {
      signal clicked
      property variant name: "copy"
      property variant text: "copy"
      property variant iconName: "share"
      onClicked: controller.copyBodyToClipboard(notifier)
    },
    QtObject {
      signal clicked
      property variant name: "zoom-in"
      property variant text: "zoom in"
      property variant iconName: "next"
      onClicked: bodyView.zoomIn()
    },
    QtObject {
      signal clicked
      property variant name: "zoom-out"
      property variant text: "zoom out"
      property variant iconName: "previous"
      onClicked: bodyView.zoomOut()
    },
    QtObject {
      signal clicked
      property variant name: "attachments"
      property variant text: "attach"
      property variant iconName: "attachment"
      onClicked: controller.saveCurrentAttachments(notifier)
    }
  ]
}

