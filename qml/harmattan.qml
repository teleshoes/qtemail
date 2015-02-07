import QtQuick 1.1
import com.nokia.meego 1.1

PageStackWindow {
  id: main

  // NAVIGATION
  Component.onCompleted: navToPageByName(controller.getInitialPageName())
  property variant curPage: null

  function navToPageByName(pageName){
    navToPage(controller.findChild(main, pageName + "Page"))
  }
  function navToPage(page){
    pageStack.push(page)
    curPage = pageStack.currentPage
    initPage()
  }
  function backPage(){
    if(pageStack.depth == 1){
      pageStack.push(accountPage)
    }else{
      pageStack.pop()
    }
    curPage = pageStack.currentPage
    initPage()
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

  // ACCOUNT PAGE
  Page {
    id: accountPage
    objectName: "accountPage"
    property variant buttons: [configButton, updateButton]
    tools: toolBar
    anchors.margins: 30

    ScrollDecorator {
      flickableItem: accountView
    }
    AccountView{ id: accountView }
  }

  // FOLDER PAGE
  Page {
    id: folderPage
    objectName: "folderPage"
    property variant buttons: [backButton]
    tools: toolBar
    anchors.margins: 30

    ScrollDecorator {
      flickableItem: headerView
    }

    FolderView{ id: folderView }
  }

  // HEADER PAGE
  Page {
    id: headerPage
    objectName: "headerPage"
    property variant buttons: [backButton, moreButton, configButton, folderButton]
    tools: toolBar
    anchors.margins: 30

    ScrollDecorator {
      flickableItem: headerView
    }

    HeaderView{ id: headerView }
    // HACK TO HIDE KEYBOARD
    Btn {
      text: "push to hide keyboard"
      anchors.top: parent.bottom
      height: parent.anchors.bottomMargin
      width: parent.width
      onClicked: hideKb()
    }
    // HACK TO HIDE KEYBOARD
  }

  // BODY PAGE
  Page {
    id: bodyPage
    objectName: "bodyPage"
    property variant buttons: [backButton]
    tools: toolBar
    anchors.margins: 30

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

  // CONFIG PAGE
  Page {
    id: configPage
    objectName: "configPage"
    property variant buttons: [backButton, submitButton]
    tools: toolBar
    anchors.margins: 30

    ConfigView{ id: configView }
    // HACK TO HIDE KEYBOARD
    Btn {
      text: "push to hide keyboard"
      anchors.top: parent.bottom
      height: parent.anchors.bottomMargin
      width: parent.width
      onClicked: hideKb()
    }
    // HACK TO HIDE KEYBOARD
  }

  // HACK TO HIDE KEYBOARD
  function hideKb(){
    hideKbDummyEdit.closeSoftwareInputPanel()
  }
  TextEdit {
    id: hideKbDummyEdit
    width: 0
    height: 0
  }
  // HACK TO HIDE KEYBOARD

  // TOOLBAR
  ToolBarLayout {
    id: toolBar

    ToolIcon {
      id: backButton
      iconId: "toolbar-tab-previous"
      Text{
        text: "back"
        anchors.horizontalCenter: parent.horizontalCenter
      }
      onClicked: backPage()
      visible: false
    }
    ToolIcon {
      id: configButton
      iconId: "toolbar-settings"
      Text{
        text: "config"
        anchors.horizontalCenter: parent.horizontalCenter
      }
      onClicked: navToPage(configPage)
      visible: false
    }
    ToolIcon {
      id: updateButton
      iconId: "toolbar-refresh"
      Text{
        text: "update"
        anchors.horizontalCenter: parent.horizontalCenter
      }
      onClicked: accountView.updateAllAccounts()
      visible: false
    }
    ToolIcon {
      id: submitButton
      iconId: "toolbar-done"
      Text{
        text: "submit"
        anchors.horizontalCenter: parent.horizontalCenter
      }
      onClicked: controller.saveConfig()
      visible: false
    }
    ToolIcon {
      id: moreButton
      iconId: "toolbar-down"
      Text{
        text: "more"
        anchors.horizontalCenter: parent.horizontalCenter
      }
      onClicked: controller.moreHeaders()
      visible: false
    }
    ToolIcon {
      id: folderButton
      Text{
        text: "folders"
        anchors.horizontalCenter: parent.horizontalCenter
      }
      iconId: "toolbar-directory"
      onClicked: navToPage(folderPage)
      visible: false
    }
  }
}
