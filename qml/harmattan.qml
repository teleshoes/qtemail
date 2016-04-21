import QtQuick 1.1
import com.nokia.meego 1.1

PageStackWindow {
  id: main

  property int fontHuge: 32
  property int fontLarge: 24
  property int fontMedium: 20
  property int fontSmall: 16
  property int fontTiny: 12

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
    hideKb()
    hideKbBtn.visible = false

    if(curPage == accountPage){
      controller.clearAccount()
      controller.setupAccounts()
    }else if(curPage == headerPage){
      controller.setCounterBox(headerView.getCounterBox())
      controller.setupHeaders()
      hideKbBtn.visible = true
    }else if(curPage == folderPage){
      controller.setupFolders()
    }else if(curPage == bodyPage){
      controller.fetchCurrentBodyText(bodyView, bodyView, null)
    }else if(curPage == configPage){
      controller.setupConfig()
      hideKbBtn.visible = true
    }else if(curPage == sendPage){
      hideKbBtn.visible = true
    }

    initToolBarTimer.restart()
  }

  Timer {
    id: initToolBarTimer
    interval: 1; //0.001s
    onTriggered: initToolBar()
  }

  function initToolBar() {
    toolBarManager.resetButtons([curPage.objectName])
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
    anchors.topMargin: 30
    anchors.bottomMargin: 30 + mainToolBar.height
    anchors.leftMargin: 30
    anchors.rightMargin: 30

    AccountView{ id: accountView }
  }

  // FOLDER PAGE
  Page {
    id: folderPage
    objectName: "folderPage"
    anchors.topMargin: 30
    anchors.bottomMargin: 30 + mainToolBar.height
    anchors.leftMargin: 30
    anchors.rightMargin: 30

    FolderView{ id: folderView }
  }

  // HEADER PAGE
  Page {
    id: headerPage
    objectName: "headerPage"
    anchors.topMargin: 30
    anchors.bottomMargin: 30 + mainToolBar.height
    anchors.leftMargin: 30
    anchors.rightMargin: 30

    HeaderView{ id: headerView }
  }

  // BODY PAGE
  Page {
    id: bodyPage
    objectName: "bodyPage"
    anchors.topMargin: 30
    anchors.bottomMargin: 30 + mainToolBar.height
    anchors.leftMargin: 30
    anchors.rightMargin: 30

    BodyView{ id: bodyView }
  }

  // CONFIG PAGE
  Page {
    id: configPage
    objectName: "configPage"
    anchors.topMargin: 30
    anchors.bottomMargin: 30 + mainToolBar.height
    anchors.leftMargin: 30
    anchors.rightMargin: 30

    ConfigView{ id: configView }
  }

  // SEND PAGE
  Page {
    id: sendPage
    objectName: "sendPage"
    anchors.topMargin: 30
    anchors.bottomMargin: 30 + mainToolBar.height
    anchors.leftMargin: 30
    anchors.rightMargin: 30

    SendView{ id: sendView }
  }

  // HACK TO HIDE KEYBOARD
  function hideKb(){
    hideKbDummyEdit.focus = true
    hideKbDummyEdit.closeSoftwareInputPanel()
    hideKbDummyEdit.focus = false
  }
  TextInput {
    id: hideKbDummyEdit
    activeFocusOnPress: false
    width: 0
    height: 0
  }
  Btn {
    id: hideKbBtn
    text: "push to hide keyboard"
    anchors.bottom: mainToolBar.top
    height: 30
    width: parent.width
    onClicked: hideKb()
  }
  // HACK TO HIDE KEYBOARD

  ToolBarButtonDefList {
    id: toolBarButtonDefList
  }

  ToolBarManager {
    id: toolBarManager
    toolBarButtonDefList: toolBarButtonDefList
    mainToolBar: mainToolBar
    extraToolBar: extraToolBar
    excludeButtonNames: []
  }

  ToolBarPanelRow {
    id: mainToolBar
    toolBarName: "toolbar-main"
    toolBarButtonDefList: toolBarButtonDefList
    btnHeight: 48
    btnWidth: 48

    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
  }
  ToolBarPanelColumn {
    id: extraToolBar
    toolBarName: "toolbar-extra"
    toolBarButtonDefList: toolBarButtonDefList
    btnHeight: 60
    btnWidth: 240

    anchors.top: parent.top
    anchors.bottom: mainToolBar.top
    anchors.right: parent.right
  }
}
