import QtQuick 1.1
import com.nokia.meego 1.1

PageStackWindow {
  id: main
  initialPage: accountPage
  function navToPage(page){
    pageStack.push(page)
    if(page == accountPage){
      controller.setupAccounts()
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
