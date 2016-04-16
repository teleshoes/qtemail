import QtQuick 1.1

Rectangle {
  id: fileListField
  signal enterPressed
  signal keyPressed
  signal complete

  property alias value: suggField.value

  width: parent.width
  height: parent.height

  function getValue() {
    return suggField.getValue();
  }
  function setValue(value) {
    suggField.setValue(value)
  }

  SuggField {
    id: suggField
    width: parent.width
    height: parent.height
    fontSize: main.fontMedium
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
        if(controller.updateFileList(suggField.value)){
          suggField.refreshSuggestions()
        }
      }
    }
    suggModel: fileListModel
  }
}
