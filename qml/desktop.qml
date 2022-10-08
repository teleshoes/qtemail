import QtQuick 2.3

Rectangle {
  id: main
  width: 1; height: 1 // hack to get resizing to work

  property string env: "desktop"
  property double headerWideViewMinPx: 700

  property bool isFullScreenBody: false

  property var scaling: Scaling{}

  // NAVIGATION
  Component.onCompleted: navToPageByName(controller.getInitialPageName())
  property bool isMain: true

  // SEND PAGE
  // dummy placeholder
  Rectangle {
    id: sendPage
    objectName: "sendPage"
    visible: false
  }

  function navToPageByName(pageName){
    navToPage(controller.findChild(main, pageName + "Page"))
  }
  function navToPage(page){
    setIsMain(page != configPage)

    configPage.visible = page == configPage
    bodyView.visible = page == bodyPage

    if(page == accountPage){
      controller.setupAccounts()
    }else if(page == headerPage){
      controller.setCounterBox(headerView.getCounterBox())
      controller.setupHeaders()
      headerView.resetScroll()
    }else if(page == folderPage){
      controller.setupFolders()
    }else if(page == bodyPage){
      controller.fetchCurrentBodyText(bodyView, bodyView)
    }else if(page == configPage){
      controller.setupConfig()
    }else if(page == sendPage){
      controller.showSendWindow()
    }

    initToolBarTimer.restart()
  }

  function toggleFullScreenBody(){
    main.isFullScreenBody = !main.isFullScreenBody;
  }

  function clearBody(){
    bodyView.setHeader("")
    bodyView.setBody("")
    bodyView.visible = false
  }

  Timer {
    id: initToolBarTimer
    interval: 1; //0.001s
    onTriggered: initToolBar()
  }

  function setIsMain(newIsMain){
    isMain = newIsMain

    if(isMain){
      configPage.visible = false
    }

    leftColumn.visible = isMain
    rightColumn.visible = isMain
  }
  function backPage(){
    setIsMain(true)
    initToolBar()
  }
  function initToolBar(){
    var activePageNames = []
    var allPages = [accountPage, headerPage, folderPage, bodyPage, configPage, sendPage]
    for (var pageIndex = 0; pageIndex < allPages.length; ++pageIndex){
      var p = allPages[pageIndex]
      if(p.visible){
        activePageNames.push(p.objectName)
      }
    }
    toolBarManager.resetButtons(activePageNames)
  }

  function onLinkActivated(link){
    Qt.openUrlExternally(link)
  }

  // NOTIFIER
  Notifier { id: notifier }

  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: mainToolBar.top
    clip: true

    Row {
      id: mainView
      anchors.fill: parent
      anchors.bottomMargin: 5
      height: parent.height
      width: parent.width
      anchors.margins: 30

      Column {
        id: leftColumn
        height: main.isFullScreenBody ? 0 : parent.height
        width: Math.max(parent.width * 0.20, 160 + 15*scaling.fontMedium)

        // ACCOUNT PAGE
        Rectangle {
          id: accountPage
          objectName: "accountPage"
          border.width: 1
          height: parent.height * 0.60
          width: parent.width - 30*2

          AccountView{ id: accountView }
        }

        // FOLDER PAGE
        Rectangle {
          id: folderPage
          objectName: "folderPage"
          border.width: 1
          height: parent.height * 0.40
          width: parent.width - 30*2

          FolderView{ id: folderView }
        }
      }

      Column {
        id: rightColumn
        height: parent.height
        width: main.isFullScreenBody ? parent.width : parent.width - leftColumn.width

        // HEADER PAGE
        Rectangle {
          id: headerPage
          objectName: "headerPage"
          border.width: 1
          height: rightColumn.height - bodyPage.height
          width: rightColumn.width - 30*2
          HeaderView{ id: headerView }
        }

        // BODY PAGE
        Rectangle {
          id: bodyPage
          objectName: "bodyPage"
          border.width: 1
          height: rightColumn.height*(
            !bodyView.visible ? 0 : (main.isFullScreenBody ? 1.0 : 0.7)
          );
          width: rightColumn.width - 30*2

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            BodyView{
              id: bodyView
              onVisibleChanged: {
                if(!visible){
                  main.isFullScreenBody = false;
                }
              }
            }
          }
        }
      }
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
  }

  ToolBarButtonDefList {
    id: toolBarButtonDefList
  }

  ToolBarManager {
    id: toolBarManager
    toolBarButtonDefList: toolBarButtonDefList
    mainToolBar: mainToolBar
    excludeButtonNames: ["showExtra", "hideKb"]
  }

  ToolBarPanelRow {
    id: mainToolBar
    toolBarName: "toolbar-main"
    toolBarButtonDefList: toolBarButtonDefList

    maxBtnCount: toolBarManager.getTotalBtnCount(
                   "main", ["accountPage", "folderPage", "headerPage", "bodyPage"])

    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
  }
}
