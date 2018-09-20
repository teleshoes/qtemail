import QtQuick 2.3
import QtQuick.Window 2.2

Rectangle {
  id: main
  anchors.centerIn: parent
  width: Screen.desktopAvailableWidth
  height: Screen.desktopAvailableHeight

  property double defaultPixelDensity: 6.2

  property int fontHuge:   scaleFontSize(20)
  property int fontLarge:  scaleFontSize(18)
  property int fontMedium: scaleFontSize(16)
  property int fontSmall:  scaleFontSize(14)
  property int fontTiny:   scaleFontSize(12)

  function scaleFontSize(fontSize){
    return Math.round(fontSize * Screen.pixelDensity / defaultPixelDensity)
  }

  // NAVIGATION
  Component.onCompleted: navToPageByName(controller.getInitialPageName())
  property variant curPage: null

  function navToPageByName(pageName){
    navToPage(controller.findChild(main, pageName + "Page"))
  }
  function navToPage(page){
    accountPage.visible = false
    folderPage.visible = false
    headerPage.visible = false
    bodyPage.visible = false
    configPage.visible = false
    sendPage.visible = false

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
    }else if(sendPage.visible){
      navToPage(headerPage);
    }
  }
  function initPage(){
    hideKb()

    if(curPage == accountPage){
      controller.setupAccounts()
    }else if(curPage == headerPage){
      controller.setCounterBox(headerView.getCounterBox())
      controller.setupHeaders()
    }else if(curPage == folderPage){
      controller.setupFolders()
    }else if(curPage == bodyPage){
      controller.fetchCurrentBodyText(bodyView, bodyView)
    }else if(curPage == configPage){
      controller.setupConfig()
    }else if(curPage == sendPage){
    }

    initToolBarTimer.restart()
  }

  function clearBody(){
    bodyView.setHeader("")
    bodyView.setBody("")
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
    Qt.openUrlExternally(link)
  }

  // NOTIFIER
  Notifier { id: notifier }

  Rectangle {
    id: topBar
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 50
  }

  Rectangle {
    anchors.top: topBar.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: mainToolBar.top
    clip: true

    // ACCOUNT PAGE
    Rectangle {
      id: accountPage
      objectName: "accountPage"
      anchors.fill: parent
      visible: false
      anchors.margins: 30

      AccountView{ id: accountView }
    }

    // FOLDER PAGE
    Rectangle {
      id: folderPage
      objectName: "folderPage"
      anchors.fill: parent
      visible: false
      anchors.margins: 30

      FolderView{ id: folderView }
    }

    // HEADER PAGE
    Rectangle {
      id: headerPage
      objectName: "headerPage"
      anchors.fill: parent
      visible: false
      anchors.margins: 30
      HeaderView{ id: headerView }
    }

    // BODY PAGE
    Rectangle {
      id: bodyPage
      objectName: "bodyPage"
      visible: false
      anchors.fill: parent
      anchors.margins: 30

      BodyView{ id: bodyView }
    }

    // CONFIG PAGE
    Rectangle {
      id: configPage
      objectName: "configPage"
      anchors.fill: parent
      visible: false
      anchors.margins: 30

      ConfigView{ id: configView }
    }

    // SEND PAGE
    Rectangle {
      id: sendPage
      objectName: "sendPage"
      anchors.fill: parent
      visible: false
      anchors.margins: 30

      SendView{ id: sendView }
    }
  }

  // HACK TO HIDE KEYBOARD
  function hideKb(){
    hideKbTimer.start()
  }
  function hideKbNow(){
    hideKbDummyEdit.focus = true
    hideKbDummyEdit.focus = false
  }
  Timer {
    id: hideKbTimer
    interval: 50
    repeat: false
    onTriggered: hideKbNow()
  }
  TextInput {
    id: hideKbDummyEdit
    activeFocusOnPress: false
    width: 0
    height: 0
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
    excludeButtonNames: ["hideKb"]
  }

  ToolBarPanelRow {
    id: mainToolBar
    toolBarName: "toolbar-main"
    toolBarButtonDefList: toolBarButtonDefList
    btnHeight: 80
    btnWidth: 80

    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
  }
  ToolBarPanelColumn {
    id: extraToolBar
    toolBarName: "toolbar-extra"
    toolBarButtonDefList: toolBarButtonDefList
    btnHeight: 80
    btnWidth: 300

    anchors.top: parent.top
    anchors.bottom: mainToolBar.top
    anchors.right: parent.right
  }
}
