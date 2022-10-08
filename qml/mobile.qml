import QtQuick 2.3
import QtQuick.Window 2.2

Rectangle {
  id: main
  anchors.centerIn: parent
  width: Screen.desktopAvailableWidth
  height: Screen.desktopAvailableHeight

  property string env: "mobile"
  property double headerWideViewMinPx: 1100

  Scaling {
    id: scaling
  }

  // NAVIGATION
  Component.onCompleted: navToPageByName(controller.getInitialPageName())
  property variant curPage: null

  function navToPageByName(pageName){
    navToPage(controller.findChild(main, pageName + "Page"))
  }
  function backPage(){
    if(headerPage.visible){
      navToPage(accountPage);
    }else if(bodyPage.visible){
      setCurrentPage(headerPage)
      hideKb()
      initToolBarTimer.restart()
    }else if(folderPage.visible){
      navToPage(headerPage);
    }else if(configPage.visible){
      navToPage(accountPage);
    }else if(sendPage.visible){
      navToPage(headerPage);
    }
  }

  function navToPage(page){
    setCurrentPage(page)

    hideKb()
    initPage()
    initToolBarTimer.restart()
  }

  function setCurrentPage(page){
    accountPage.visible = false
    folderPage.visible = false
    headerPage.visible = false
    bodyPage.visible = false
    configPage.visible = false
    sendPage.visible = false

    page.visible = true
    curPage = page
  }
  function initPage(){
    if(curPage == accountPage){
      controller.setupAccounts()
    }else if(curPage == headerPage){
      controller.setCounterBox(headerView.getCounterBox())
      controller.setupHeaders()
      headerView.resetScroll()
    }else if(curPage == folderPage){
      controller.setupFolders()
    }else if(curPage == bodyPage){
      controller.fetchCurrentBodyText(bodyView, bodyView)
    }else if(curPage == configPage){
      controller.setupConfig()
    }else if(curPage == sendPage){
    }
  }

  function toggleFullScreenBody(){
    //body is always full screen in mobile
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
    height: scaling.scalePixelDensity * 50

    Btn {
      id: hideKbBtn
      text: "hide kb"
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      width: parent.width * 0.50
      onClicked: {
        hideKb()
      }
    }
    Btn {
      id: orientationBtn
      text: "rotate"
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      width: parent.width * 0.50
      onClicked: {
        if(main.rotation == 0){
          main.rotation = 90
          main.width = Screen.desktopAvailableHeight
          main.height = Screen.desktopAvailableWidth
        }else{
          main.rotation = 0
          main.width = Screen.desktopAvailableWidth
          main.height = Screen.desktopAvailableHeight
        }
      }
    }
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

    maxBtnCount: toolBarManager.getMaxBtnCount(
                   "main", toolBarManager.getAllPageNames())

    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
  }
  ToolBarPanelColumn {
    id: extraToolBar
    toolBarName: "toolbar-extra"
    toolBarButtonDefList: toolBarButtonDefList

    maxBtnCount: toolBarManager.getMaxBtnCount(
                   "extra", toolBarManager.getAllPageNames())

    anchors.top: parent.top
    anchors.bottom: mainToolBar.top
    anchors.right: parent.right
  }
}
