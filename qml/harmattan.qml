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
    ListView {
      id: accountView
      spacing: 50
      anchors.fill: parent
      model: accountModel
      delegate: Component  {
        Rectangle {
          height: 150
          width: parent.width
          color: "gray"
          MouseArea{
            anchors.fill: parent
            onClicked: {
              controller.accountSelected(model.account)
              navToPage(headerPage)
            }
          }
          Text {
            anchors.centerIn: parent
            text: model.account.Name + ": " + model.account.Unread
            font.pointSize: 36
          }
        }
      }
    }
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
    ListView {
      id: headerView
      spacing: 10
      anchors.fill: parent
      model: headerModel
      delegate: Component  {
        Rectangle {
          color: "#AAAAAA"
          height: 125
          width: parent.width
          MouseArea {
            anchors.fill: parent
            onClicked: {
              bodyText.text = controller.getBodyText(model.header)
              navToPage(bodyPage)
            }
          }
          Column {
            id: col
            anchors.fill: parent
            Text {
              text: model.header.From
              font.pointSize: 24
            }
            Text {
              text: model.header.Date
              font.pointSize: 20
            }
            Text {
              text: model.header.Subject
              font.pointSize: 16
            }
          }
        }
      }
    }
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
    Flickable {
      id: bodyView
      contentWidth: bodyText.paintedWidth
      contentHeight: bodyText.paintedHeight
      anchors.fill: parent
      flickableDirection: Flickable.HorizontalAndVerticalFlick
      boundsBehavior: Flickable.DragOverBounds
      Rectangle{
        anchors.fill: parent
        color: white
        Text {
          id: bodyText
          anchors.fill: parent
          font.pointSize: 24
        }
      }
    }
  }
}
