import QtQuick 1.1

Rectangle {
  id: accountView
  anchors.fill: parent

  function updateAllAccounts(){
    controller.updateAccount(messageBox, null)
  }

  function initAccountConfig(){
    var isHtml = controller.getHtmlMode()
    toolButtons.getButtonDefByName("toggleHtml").setIsHtml(isHtml)
    controller.resetFilterButtons()
  }

  ListView {
    id: accountFlickable
    spacing: 15
    width: parent.width
    height: parent.height * 0.70
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: messageBox.top
    model: accountModel
    delegate: Component  {
      Rectangle {
        height: 100
        width: parent.width
        color: "gray"
        MouseArea{
          anchors.fill: parent
          onClicked: {
            controller.accountSelected(model.account.Name)
            initAccountConfig()
            navToPage(headerPage)
          }
        }
        Rectangle {
          id: updateIndicator
          height: parent.height
          width: parent.width * 0.15
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          color: model.account.IsLoading ? "#FF0000" : "#666666"

          MouseArea {
            anchors.fill: parent
            onClicked: {
              controller.updateAccount(messageBox, model.account)
            }
          }
        }

        Timer {
          id: updateTimer
          interval: model.account.UpdateInterval * 1000
          running: model.account.UpdateInterval > 0
          repeat: true

          onTriggered: {
            if(model.account.IsLoading){
              console.log("skipping overlapping update")
            }else if(!accountView.visible){
              console.log("skipping update, account view is not visible")
            }else{
              console.log("updating account " + model.account.Name)
              controller.updateAccount(messageBox, model.account)
            }
          }
        }

        Text {
          anchors.left: parent.left
          anchors.margins: 2
          text: model.account.Name + ": " + model.account.Unread
          font.pointSize: 32
        }
        Text {
          anchors.right: parent.right
          anchors.rightMargin: parent.width * 0.15
          text: model.account.LastUpdatedRel
          font.pointSize: 24
        }
        Text {
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          text: model.account.Error
          font.pointSize: 24
        }
      }
    }
  }

  Rectangle{
    id: messageBox
    color: "#FFFFFF"
    border.color: "#000000"
    border.width: 2
    anchors.bottom: parent.bottom
    width: parent.width
    height: parent.height * 0.30
    clip: true

    function append(text) {
      messageBoxTextArea.text = messageBoxTextArea.text + text
    }
    function setText(text) {
       messageBoxTextArea.text = text
    }
    function scrollToBottom() {
      messageBoxFlickable.contentY = messageBoxTextArea.height - messageBoxFlickable.height
    }

    Flickable {
      id: messageBoxFlickable
      anchors.fill: parent
      contentWidth: messageBoxTextArea.paintedWidth
      contentHeight: messageBoxTextArea.paintedHeight
      flickableDirection: Flickable.HorizontalAndVerticalFlick
      boundsBehavior: Flickable.DragOverBounds
      Text {
        anchors.fill: parent
        id: messageBoxTextArea
        text: "CONSOLE OUTPUT\n"
      }
    }
  }

  ScrollBar {
    flickable: accountFlickable
    anchors.rightMargin: -30
  }
}
