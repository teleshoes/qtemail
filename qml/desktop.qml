import QtQuick 1.1

Rectangle {
  id: main
  width: 1; height: 1 //retarded hack to get resizing to work

  function navToPage(page){
    accountPage.visible = false
    headerPage.visible = false
    bodyPage.visible = false
    if(page == accountPage){
      controller.setupAccounts()
      backButton.visible = false
      moreButton.visible = false
    }else if(page == headerPage){
      backButton.visible = true
      moreButton.visible = true
    }else if(page == bodyPage){
      backButton.visible = true
      moreButton.visible = false
    }
    page.visible = true
  }
  function backPage(){
    if(headerPage.visible){
      navToPage(accountPage);
    }else if(bodyPage.visible){
      navToPage(headerPage);
    }
  }

  Rectangle {
    anchors.top: parent.top
    anchors.bottom: toolBar.top
    width: parent.width
    Rectangle {
      id: accountPage
      anchors.fill: parent
      anchors.margins: 30

      AccountView{ id: accountView }
    }

    Rectangle {
      id: headerPage
      anchors.fill: parent
      visible: false
      anchors.margins: 30
      HeaderView{ id: headerView }
    }

    Rectangle {
      id: bodyPage
      visible: false
      anchors.fill: parent
      anchors.margins: 30

      BodyView{ id: bodyView }
    }
  }

  Rectangle {
    id: toolBar
    anchors.bottom: parent.bottom
    height: backButton.height
    width: parent.width
    Row {
      spacing: 10
      Btn {
        id: backButton
        text: "back"
        onClicked: backPage()
        visible: false
      }
      Btn {
        id: moreButton
        text: "more"
        onClicked: controller.moreHeaders()
        visible: false
      }
    }
  }
}