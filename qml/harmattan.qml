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

    if(curPage == accountPage){
      controller.clearAccount()
      controller.setupAccounts()
    }else if(curPage == headerPage){
      controller.setupHeaders()
      controller.updateCounterBox(headerView.getCounterBox())
    }else if(curPage == folderPage){
      controller.setupFolders()
    }else if(curPage == bodyPage){
      controller.fetchCurrentBodyText(bodyView, bodyView, null)
    }else if(curPage == configPage){
      controller.setupConfig()
    }else if(curPage == sendPage){
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
    tools: toolBar
    anchors.margins: 30

    AccountView{ id: accountView }
  }

  // FOLDER PAGE
  Page {
    id: folderPage
    objectName: "folderPage"
    tools: toolBar
    anchors.margins: 30

    FolderView{ id: folderView }
  }

  // HEADER PAGE
  Page {
    id: headerPage
    objectName: "headerPage"
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
    tools: toolBar
    anchors.margins: 30

    BodyView{ id: bodyView }
  }

  // CONFIG PAGE
  Page {
    id: configPage
    objectName: "configPage"
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

  // CONFIG PAGE
  Page {
    id: sendPage
    objectName: "sendPage"
    tools: toolBar
    anchors.margins: 30

    SendView{ id: sendView }
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
  // HACK TO HIDE KEYBOARD

  // TOOLBAR
  ToolButtons {
    id: toolButtons
  }

  ToolBarLayout {
    id: toolBar

    Repeater {
      model: toolButtons.getButtonDefs()
      ToolIcon {
        function setText(text){
          buttonTextArea.text = text
        }
        objectName: "toolbarButton-" + modelData.name
        Text{
          id: buttonTextArea
          text: modelData.text
          anchors.horizontalCenter: parent.horizontalCenter
        }
        Image {
          source: "/opt/qtemail/icons/buttons/" + modelData.name + ".png"
          anchors.centerIn: parent
          height: 48
          width: 48
        }
        onClicked: modelData.clicked()
        visible: false
      }
    }
  }
}
