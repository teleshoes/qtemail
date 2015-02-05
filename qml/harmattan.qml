import QtQuick 1.1
import com.nokia.meego 1.1

PageStackWindow {
  id: main

  Component.onCompleted: navToPage(accountPage)

  function navToPage(page){
    pageStack.push(page)
    if(page == accountPage){
      controller.setupAccounts()
    }else if(page == folderPage){
      controller.setupFolders()
    }
  }
  function backPage(){
    pageStack.pop()
  }

  Page {
    id: accountPage
    anchors.margins: 30
    anchors.fill: parent
    ScrollDecorator {
      flickableItem: accountView
    }
    AccountView{ id: accountView }
  }

  Page {
    id: folderPage
    anchors.margins: 30
    tools: ToolBarLayout {
      ToolButton {
        text: "back"
        onClicked: {
          backPage()
        }
      }
    }
    ScrollDecorator {
      flickableItem: headerView
    }

    FolderView{ id: folderView }
  }

  Page {
    id: headerPage
    anchors.margins: 30
    tools: ToolBarLayout {
      ToolButton {
        text: "back"
        onClicked: {
          backPage()
          controller.setupAccounts()
        }
      }
      ToolButton {
        text: "more"
        onClicked: {
          controller.moreHeaders()
        }
      }
      ToolButton {
        text: "folders"
        onClicked: {
          navToPage(folderPage)
        }
      }
    }
    ScrollDecorator {
      flickableItem: headerView
    }

    HeaderView{ id: headerView }
  }

  Page {
    id: bodyPage
    anchors.margins: 30

    tools: ToolBarLayout {
      ToolButton {
        text: "back"
        onClicked: backPage()
      }
    }
    ScrollDecorator {
      flickableItem: bodyView
    }
    PinchFlick{
      anchors.fill: parent
      pinch.minimumScale: 0.1
      pinch.maximumScale: 10
      pinch.target: bodyView
    }
    BodyView{ id: bodyView }
  }
}
