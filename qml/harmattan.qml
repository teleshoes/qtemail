import QtQuick 1.1
import com.nokia.meego 1.1
import com.nokia.extras 1.1

PageStackWindow {
  id: main

  // NAVIGATION
  Component.onCompleted: navToPageByName(controller.getInitialPageName())
  property variant curPage: null

  function navToPageByName(pageName){
    navToPage(controller.findChild(main, pageName + "Page"))
  }
  function navToPage(page){
    hideKb()
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
      controller.setupHeaders(headerView)
    }else if(curPage == folderPage){
      controller.setupFolders()
    }else if(curPage == bodyPage){
      controller.fetchCurrentBodyText(notifier, bodyView)
    }else if(curPage == configPage){
      controller.setupConfig()
    }
  }

  function onLinkActivated(link){
    controller.shellCommand(""
      + " /usr/bin/invoker --type=m "
      + " /usr/bin/grob "
      + " '" + link + "'"
      + " >/dev/null 2>/dev/null"
      )
  }

  // NOTIFIER
  Notifier { id: notifier }

  // ACCOUNT PAGE
  Page {
    id: accountPage
    objectName: "accountPage"
    property variant buttons: [configButton, updateButton]
    tools: toolBar
    anchors.margins: 30

    AccountView{ id: accountView }
  }

  // FOLDER PAGE
  Page {
    id: folderPage
    objectName: "folderPage"
    property variant buttons: [backButton]
    tools: toolBar
    anchors.margins: 30

    FolderView{ id: folderView }
  }

  // HEADER PAGE
  Page {
    id: headerPage
    objectName: "headerPage"
    property variant buttons: [backButton, moreButton, wayMoreButton, allButton, configButton, folderButton]
    tools: toolBar
    anchors.margins: 30

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
    property variant buttons: [backButton, toggleHtmlButton, attachmentsButton]
    tools: toolBar
    anchors.margins: 30

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
      onClicked: controller.moreHeaders(headerView, 0)
      visible: false
    }
    ToolIcon {
      id: wayMoreButton
      iconId: "toolbar-down"
      Text{
        text: "+30%"
        anchors.horizontalCenter: parent.horizontalCenter
      }
      onClicked: controller.moreHeaders(headerView, 30)
      visible: false
    }
    ToolIcon {
      id: allButton
      iconId: "toolbar-down"
      Text{
        text: "all"
        anchors.horizontalCenter: parent.horizontalCenter
      }
      onClicked: controller.moreHeaders(headerView, 100)
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
    ToolIcon {
      id: toggleHtmlButton
      Text{
        id: toggleHtmlButtonTextArea
        anchors.horizontalCenter: parent.horizontalCenter
      }
      iconId: "icon-m-toolbar-jump-to-dimmed-white"
      Component.onCompleted: setIsHtml(controller.isHtml())
      function setIsHtml(isHtml){
        toggleHtmlButtonTextArea.text = isHtml ? "text" : "html"
      }
      onClicked: {
        controller.toggleIsHtml()
        setIsHtml(controller.isHtml())
        controller.fetchCurrentBodyText(notifier, bodyView)
      }
      visible: false
    }
    ToolIcon {
      id: attachmentsButton
      Text{
        text: "attach"
        anchors.horizontalCenter: parent.horizontalCenter
      }
      iconId: "icon-m-toolbar-attachment"
      onClicked: controller.saveCurrentAttachments(notifier)
      visible: false
    }
  }
}
