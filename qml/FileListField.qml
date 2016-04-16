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
  }

  SuggBox {
    id: suggBox
    width: parent.width
    height: parent.height
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
