import QtQuick 1.1

Rectangle {
  id: main
  width: 1; height: 1 //retarded hack to get resizing to work

  Component.onCompleted: navToPage(accountPage)

  function navToPage(page){
    accountPage.visible = false
    folderPage.visible = false
    headerPage.visible = false
    bodyPage.visible = false
    configPage.visible = false
    if(page == accountPage){
      controller.setupAccounts()
      configButton.visible = true
      submitButton.visible = false
      backButton.visible = false
      moreButton.visible = false
      folderButton.visible = false
    }else if(page == folderPage){
      controller.setupFolders()
      configButton.visible = false
      submitButton.visible = false
      backButton.visible = true
      moreButton.visible = false
      folderButton.visible = false
    }else if(page == headerPage){
      configButton.visible = false
      submitButton.visible = false
      backButton.visible = true
      moreButton.visible = true
      folderButton.visible = true
    }else if(page == bodyPage){
      configButton.visible = false
      submitButton.visible = false
      backButton.visible = true
      moreButton.visible = false
      folderButton.visible = false
    }else if(page == configPage){
      controller.setupConfig(null)
      configButton.visible = false
      submitButton.visible = true
      backButton.visible = true
      moreButton.visible = false
      folderButton.visible = false
    }
    page.visible = true
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

  Rectangle {
    anchors.top: parent.top
    anchors.bottom: toolBar.top
    width: parent.width
    Rectangle {
      id: accountPage
      anchors.fill: parent
      visible: false
      anchors.margins: 30

      AccountView{ id: accountView }
    }

    Rectangle {
      id: folderPage
      anchors.fill: parent
      visible: false
      anchors.margins: 30

      FolderView{ id: folderView }
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

    Rectangle {
      id: configPage
      anchors.fill: parent
      visible: false
      anchors.margins: 30

      ConfigView{ id: configView }
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
      Btn {
        id: folderButton
        text: "folders"
        onClicked: navToPage(folderPage)
        visible: false
      }
    }
  }
}
