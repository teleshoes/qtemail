import QtQuick 1.1

Rectangle {
  id: fileListField
  signal enterPressed
  signal keyPressed
  signal complete

  property alias value: suggBox.text

  width: parent.width
  height: parent.height

  function getValue() {
    return suggBox.text;
  }
  function setValue(value) {
    suggBox.text = value
    suggBox.updateFileList()
  }

  function setValueHome() {
    fileListField.setValue(controller.getHomeDir())
  }

  Row {
    id: buttonPanel
    width: parent.width
    height: 30
    spacing: 20

    property double btnWidth: (width - (spacing*(children.length-1))) * 1/children.length
    property double btnHeight: height

    Btn {
      width: buttonPanel.btnWidth
      height: buttonPanel.btnHeight
      text: "home"
      onClicked: {
        fileListField.setValue(controller.getHomeDir())
      }
    }
    Btn {
      width: buttonPanel.btnWidth
      height: buttonPanel.btnHeight
      text: "root"
      onClicked: {
        fileListField.setValue("/")
      }
    }
    Btn {
      width: buttonPanel.btnWidth
      height: buttonPanel.btnHeight
      text: "clear"
      onClicked: {
        fileListField.setValue("")
      }
    }
  }

  SuggBox {
    id: suggBox
    width: parent.width
    height: parent.height - buttonPanel.height
    anchors.top: buttonPanel.bottom

    onEnterPressed: {
      fileListField.enterPressed()
    }
    onKeyPressed: {
      updateFileListTimer.restart()
      fileListField.keyPressed()
    }
    onComplete: {
      updateFileListTimer.restart()
      fileListField.complete()
    }

    Timer {
      id: updateFileListTimer
      interval: 750;
      onTriggered: {
        suggBox.updateFileList()
      }
    }

    function updateFileList() {
      if(controller.updateFileList(suggBox.text)){
        suggBox.resetFilter()
      }
    }

    suggModel: fileListModel
  }
}
