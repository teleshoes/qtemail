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
      controller.clearAccount()
      controller.setupAccounts()
    }else if(curPage == headerPage){
      controller.setupHeaders()
    }else if(curPage == folderPage){
      controller.setupFolders()
    }else if(curPage == bodyPage){
      bodyView.setBody(controller.getCurrentBodyText())
    }else if(curPage == configPage){
      controller.setupConfig()
    }
  }

  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: toolBar.top
    clip: true

    // ACCOUNT PAGE
    Rectangle {
      id: accountPage
      property variant buttons: [configButton, updateButton]
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
      property variant buttons: [backButton, moreButton, configButton, folderButton]
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
  }

  // TOOLBAR
  Row {
    id: toolBar
    anchors.bottom: parent.bottom
    height: backButton.height
    width: parent.width

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
      id: updateButton
      text: "update"
      onClicked: accountView.updateAllAccounts()
      visible: false
    }
    Btn {
      id: submitButton
      text: "save"
      onClicked: controller.saveConfig()
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
