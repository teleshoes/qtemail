import QtQuick 1.1

SuggField {
  id: textField
  fontSize: main.fontMedium
  anchors.top: parent.top
  anchors.left: parent.left
  anchors.right: parent.right
  onEnterPressed: {
    add.clicked()
  }
  onKeyPressed: {
    updateFileListTimer.restart()
  }
  onComplete: {
    updateFileListTimer.restart()
  }
  Timer {
    id: updateFileListTimer
    interval: 750;
    onTriggered: {
      if(controller.updateFileList(textField.value)){
        textField.refreshSuggestions()
      }
    }
  }
  suggModel: fileListModel
}

