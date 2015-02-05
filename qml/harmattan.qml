import QtQuick 1.1
import com.nokia.meego 1.1

PageStackWindow {
  id: main

  // NAVIGATION
  Component.onCompleted: navToPage(accountPage)
  property variant curPage: null

  function navToPage(page){
    pageStack.push(page)
    curPage = pageStack.currentPage
    initPage()
  }
  function backPage(){
    pageStack.pop()
    curPage = pageStack.currentPage
    initPage()
  }
  function initPage(){
    configButton.visible = false
    submitButton.visible = false
    backButton.visible = false
    moreButton.visible = false
    folderButton.visible = false

    if(curPage == accountPage){
      controller.setupAccounts()
      configButton.visible = true
    }else if(curPage == folderPage){
      controller.setupFolders()
      backButton.visible = true
    }else if(curPage == headerPage){
      backButton.visible = true
      moreButton.visible = true
      folderButton.visible = true
    }else if(curPage == bodyPage){
      backButton.visible = true
    }else if(curPage == configPage){
      controller.setupConfig(null)
      submitButton.visible = true
      backButton.visible = true
    }
  }

  // ACCOUNT PAGE
  Page {
    id: accountPage
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
    tools: toolBar
    anchors.margins: 30

    ScrollDecorator {
      flickableItem: headerView
    }

    HeaderView{ id: headerView }
  }

  // BODY PAGE
  Page {
    id: bodyPage
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
    tools: toolBar
    anchors.margins: 30

    ConfigView{ id: configView }
    // HACK TO HIDE KEYBOARD
    Btn {
      id: hideKbBtn
      text: "push to hide keyboard"
      anchors.top: parent.bottom
      height: parent.anchors.bottomMargin
      width: parent.width
      onClicked: hideKbDummyEdit.closeSoftwareInputPanel();
    }
    TextEdit {
      id: hideKbDummyEdit
      width: 0
      height: 0
    }
    // HACK TO HIDE KEYBOARD
  }

  // TOOLBAR
  ToolBarLayout {
    id: toolBar

    ToolButton {
      id: backButton
      text: "back"
      onClicked: backPage()
      visible: false
    }
    ToolButton {
      id: configButton
      text: "config"
      onClicked: navToPage(configPage)
      visible: false
    }
    ToolButton {
      id: submitButton
      text: "submit"
      onClicked: submitForm()
      visible: false
    }
    ToolButton {
      id: moreButton
      text: "more"
      onClicked: controller.moreHeaders()
      visible: false
    }
    ToolButton {
      id: folderButton
      text: "folders"
      onClicked: navToPage(folderPage)
      visible: false
    }
  }
}
