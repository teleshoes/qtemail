import QtQuick 1.1

Rectangle {
  id: main
  width: 1; height: 1 //retarded hack to get resizing to work

  // NAVIGATION
  Component.onCompleted: navToPageByName(controller.getInitialPageName())
  property bool isMain: true

  function navToPageByName(pageName){
    navToPage(controller.findChild(main, pageName + "Page"))
  }
  function navToPage(page){
    setIsMain(page != configPage && page != sendPage)

    configPage.visible = page == configPage
    sendPage.visible = page == sendPage

    if(page == accountPage){
      controller.setupAccounts()
    }else if(page == headerPage){
      controller.setupHeaders()
      controller.updateCounterBox(headerView.getCounterBox())
    }else if(page == folderPage){
      controller.setupFolders()
    }else if(page == bodyPage){
      controller.fetchCurrentBodyText(bodyView, bodyView, null)
    }else if(page == configPage){
      controller.setupConfig()
    }else if(page == sendPage){
    }

    initToolBar()
  }

  function setIsMain(newIsMain){
    isMain = newIsMain

    if(isMain){
      configPage.visible = false
      sendPage.visible = false
    }

    leftColumn.visible = isMain
    rightColumn.visible = isMain
  }
  function backPage(){
    setIsMain(true)
    initToolBar()
  }
  function initToolBar(){
    for (var i = 0; i < toolBar.children.length; ++i){
      toolBar.children[i].visible = false
    }
    var pages = [accountPage, headerPage, folderPage, bodyPage, configPage, sendPage]
    for (var pageIndex = 0; pageIndex < pages.length; ++pageIndex){
      var p = pages[pageIndex]
      if(p.visible){
        var pageName = p.objectName
        var buttonNames = toolButtons.pages[pageName]
        for (var i = 0; i < buttonNames.length; ++i){
          var objectName = "toolbarButton-" + buttonNames[i]
          var btn = controller.findChild(main, objectName)
          btn.visible = true
        }
      }
    }
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
    anchors.bottom: toolBar.top
    clip: true

    Row {
      id: mainView
      anchors.fill: parent
      anchors.bottomMargin: 5
      height: parent.height
      width: parent.width

      Column {
        id: leftColumn
        height: parent.height
        width: Math.max(parent.width * 0.3, 450)

        // ACCOUNT PAGE
        Rectangle {
          id: accountPage
          objectName: "accountPage"
          border.width: 1
          height: parent.height * 0.5
          width: parent.width - 30*2
          anchors.margins: 30

          AccountView{ id: accountView }
        }

        // FOLDER PAGE
        Rectangle {
          id: folderPage
          objectName: "folderPage"
          border.width: 1
          height: parent.height * 0.5
          width: parent.width - 30*2
          anchors.margins: 30

          FolderView{ id: folderView }
        }
      }

      Column {
        id: rightColumn
        height: parent.height
        width: parent.width - leftColumn.width

        // HEADER PAGE
        Rectangle {
          id: headerPage
          objectName: "headerPage"
          border.width: 1
          height: parent.height * 0.5
          width: parent.width - 30*2
          anchors.margins: 30
          HeaderView{ id: headerView }
        }

        // BODY PAGE
        Rectangle {
          id: bodyPage
          objectName: "bodyPage"
          border.width: 1
          height: parent.height * 0.5
          width: parent.width - 30*2
          anchors.margins: 30

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            BodyView{ id: bodyView }
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

  // TOOLBAR
  ToolButtons {
    id: toolButtons
  }

  Row {
    id: toolBar
    objectName: "toolBar"
    anchors.bottom: parent.bottom
    width: parent.width

    spacing: 10
    Repeater {
      model: toolButtons.getButtonDefs()
      Btn {
        function setText(text){
          this.text = text
        }
        objectName: "toolbarButton-" + modelData.name
        text: modelData.text
        imgSource: "/opt/qtemail/icons/buttons/" + modelData.name + ".png"
        onClicked: modelData.clicked()
        visible: false
      }
    }
  }
}
