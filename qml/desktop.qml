import QtQuick 1.1

Rectangle {
  id: main
  width: 1; height: 1 //retarded hack to get resizing to work

  // NAVIGATION
  Component.onCompleted: navToPage(accountPage)
  property variant curPage: null

  function navToPage(page){
    accountPage.visible = false
    folderPage.visible = false
    headerPage.visible = false
    bodyPage.visible = false
    configPage.visible = false

    page.visible = true
    curPage = page
    initPage()
  }
  function backPage(){
    if(headerPage.visible){
      navToPage(accountPage);
    }else if(bodyPage.visible){
      navToPage(headerPage);
    }else if(folderPage.visible){
      navToPage(headerPage);
    }else if(configPage.visible){
      navToPage(accountPage);
    }
  }
  function initPage(){
    for (var i = 0; i < toolBar.children.length; ++i){
      toolBar.children[i].visible = false
    }
    for (var i = 0; i < curPage.buttons.length; ++i){
      curPage.buttons[i].visible = true
    }

    if(curPage == accountPage){
      controller.setupAccounts()
    }else if(curPage == folderPage){
      controller.setupFolders()
    }else if(curPage == configPage){
      controller.setupConfig(null)
    }
  }

  // ACCOUNT PAGE
  Rectangle {
    id: accountPage
    property variant buttons: [configButton]
    anchors.fill: parent
    visible: false
    anchors.margins: 30

    AccountView{ id: accountView }
  }

  // FOLDER PAGE
  Rectangle {
    id: folderPage
    property variant buttons: [backButton]
    anchors.fill: parent
    visible: false
    anchors.margins: 30

    FolderView{ id: folderView }
  }

  // HEADER PAGE
  Rectangle {
    id: headerPage
    property variant buttons: [backButton, moreButton, folderButton]
    anchors.fill: parent
    visible: false
    anchors.margins: 30
    HeaderView{ id: headerView }
  }

  // BODY PAGE
  Rectangle {
    id: bodyPage
    property variant buttons: [backButton]
    visible: false
    anchors.fill: parent
    anchors.margins: 30

    BodyView{ id: bodyView }
  }

  // CONFIG PAGE
  Rectangle {
    id: configPage
    property variant buttons: [backButton, submitButton]
    anchors.fill: parent
    visible: false
    anchors.margins: 30

    ConfigView{ id: configView }
  }

  // TOOLBAR
  Rectangle {
    anchors.bottom: parent.bottom
    height: backButton.height
    width: parent.width
    Row {
      id: toolBar
      spacing: 10
      Btn {
        id: backButton
        text: "back"
        onClicked: backPage()
        visible: false
      }
      Btn {
        id: configButton
        text: "config"
        onClicked: navToPage(configPage)
        visible: false
      }
      Btn {
        id: submitButton
        text: "submit"
        onClicked: submitForm()
        visible: false
      }
      Btn {
        id: moreButton
        text: "more"
        onClicked: controller.moreHeaders()
        visible: false
      }
      Btn {
        id: folderButton
        text: "folders"
        onClicked: navToPage(folderPage)
        visible: false
      }
    }
  }
}
