import QtQuick 1.1

Rectangle {
  id: main
  width: 1; height: 1 //retarded hack to get resizing to work

  property int fontHuge: 20
  property int fontLarge: 18
  property int fontMedium: 16
  property int fontSmall: 14
  property int fontTiny: 12

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
    if(curPage == accountPage){
      controller.setupAccounts()
    }else if(curPage == headerPage){
      controller.setCounterBox(headerView.getCounterBox())
      controller.setupHeaders()
    }else if(curPage == folderPage){
      controller.setupFolders()
    }else if(curPage == bodyPage){
      controller.fetchCurrentBodyText(bodyView, bodyView, null)
    }else if(curPage == configPage){
      controller.setupConfig()
    }else if(curPage == sendPage){
    }

    initToolBar()
  }

  function initToolBar() {
    for (var i = 0; i < toolBar.children.length; ++i){
      toolBar.children[i].visible = false
    }
    var pageName = curPage.objectName
    var buttonNames = toolButtons.pages[pageName]
    for (var i = 0; i < buttonNames.length; ++i){
      var objectName = "toolbarButton-" + buttonNames[i]
      var btn = controller.findChild(main, objectName)
      btn.visible = true
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
        width: 80
        height: 80
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
