import QtQuick 1.1

Item {
  property variant pages: {
    "accountPage": ["config", "update"],
    "folderPage": ["back"],
    "headerPage": ["back", "more", "wayMore", "all", "config", "folder"],
    "bodyPage": ["back", "attachments", "toggleHtml"],
    "configPage": ["back", "submit"]
  }

  function getButtons(){
    return buttons.children
  }

  Item {
    id: buttons
    Item {
      signal clicked
      property variant name: "back"
      property variant text: "back"
      property variant iconName: "tab-previous"
      onClicked: main.backPage()
    }
    Item {
      signal clicked
      property variant name: "config"
      property variant text: "config"
      property variant iconName: "settings"
      onClicked: navToPage(configPage)
    }
    Item {
      signal clicked
      property variant name: "update"
      property variant text: "update"
      property variant iconName: "refresh"
      onClicked: accountView.updateAllAccounts()
    }
    Item {
      signal clicked
      property variant name: "submit"
      property variant text: "submit"
      property variant iconName: "done"
      onClicked: controller.saveConfig()
    }
    Item {
      signal clicked
      property variant name: "more"
      property variant text: "more"
      property variant iconName: "down"
      onClicked: controller.moreHeaders(headerView, 0)
    }
    Item {
      signal clicked
      property variant name: "wayMore"
      property variant text: "+30%"
      property variant iconName: "down"
      onClicked: controller.moreHeaders(headerView, 30)
    }
    Item {
      signal clicked
      property variant name: "all"
      property variant text: "all"
      property variant iconName: "down"
      onClicked: controller.moreHeaders(headerView, 100)
    }
    Item {
      signal clicked
      property variant name: "folder"
      property variant text: "folders"
      property variant iconName: "directory"
      onClicked: navToPage(folderPage)
    }
    Item {
      signal clicked
      property variant name: "toggleHtml"
      property variant text: "html"
      property variant iconName: "jump-to-dimmed-white"
      function setIsHtml(isHtml){
        var btn = controller.findChild(toolBar, "toolbarButton-" + name)
        btn.setText(isHtml ? "text" : "html")
      }
      onClicked: {
        controller.toggleIsHtml()
        setIsHtml(controller.isHtml())
        controller.fetchCurrentBodyText(notifier, bodyView)
      }
    }
    Item {
      signal clicked
      property variant name: "attachments"
      property variant text: "attach"
      property variant iconName: "attachment"
      onClicked: controller.saveCurrentAttachments(notifier)
    }
  }
}

