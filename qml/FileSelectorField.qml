import QtQuick 1.1

Rectangle {
  height: isExpanded ? 500 : labelContainer.height
  width: parent.width

  property alias labelText: label.text
  property bool isDark: false

  property bool isExpanded: false

  color: isDark ? "#444444" : "#666666"

  function getFiles(){
    var filePaths = []
    for(var i=0; i<fileListView.model.count; i++){
      var filePath = fileListView.model.get(i).FilePath
      filePaths.push(filePath)
    }
    return filePaths
  }
  function setFiles(filePaths){
    clearFiles()
    for(var i=0; i<filePaths.length; i++){
      addFile(filePaths[i])
    }
  }

  function addFile(filePath){
    controller.addFileInfo(filePath)
  }
  function clearFiles(){
    controller.clearFileInfo()
  }


  Row {
    width: parent.width
    height: 40
    id: labelContainer
    Text {
      id: label
      height: parent.height
      font.pointSize: main.fontMedium
      font.weight: Font.DemiBold
    }
    Btn {
      height: parent.height
      anchors.right: parent.right
      anchors.rightMargin: 20
      width: 100
      text: isExpanded ? "hide" : "show"
      onClicked: {
        isExpanded = !isExpanded
        if (isExpanded){
          fileListField.setValueHome()
        }
      }
    }
  }

  Column {
    id: leftColumn
    visible: isExpanded
    width: parent.width * 0.5
    height: parent.height - labelContainer.height
    anchors.top: labelContainer.bottom
    anchors.left: parent.left

    FileListField {
      id: fileListField
      height: parent.height
      width: parent.width
      onEnterPressed: {
        if(value){
          addFile(value)
          setValue("")
        }
      }
    }
  }
  Column {
    id: rightColumn
    visible: isExpanded
    width: parent.width * 0.5
    height: parent.height - labelContainer.height
    anchors.left: leftColumn.right
    anchors.top: labelContainer.bottom

    Rectangle {
      width: parent.width
      height: 30
      Text {
        id: countDisplay
        text: fileListView.model.count + " file(s) attached"
        font.italic: true
      }
    }
    Rectangle {
      id: fileListContainer
      width: parent.width
      height: parent.height - countDisplay.height

      clip: true
      anchors.margins: 2
      border.width: 1
      border.color: "white"

      ListView {
        id: fileListView
        anchors.fill: parent
        anchors.margins: 5
        model: fileInfoModel
        clip: true

        spacing: 8
        delegate: Rectangle {
          height: fileInfoCol.height
          width: parent.width
          border.width: 2
          Column {
            id: fileInfoCol
            height: filePathPanel.height
            width: parent.width * 0.90
            Rectangle {
              id: filePathPanel
              color: "#E1D6A1"
              height: filePathLabel.text.length > 0 ? filePathLabel.height : 0
              width: parent.width
              Text {
                id: filePathLabel
                text: model.fileInfo.FilePath
                font.pointSize: main.fontSmall
                wrapMode: Text.Wrap
              }
            }
          }
          Btn {
            anchors {left: fileInfoCol.right}
            height: fileInfoCol.height
            width: parent.width * 0.10
            text: "x"
            onClicked: {
              controller.removeFileInfo(model.fileInfo.FilePath)
            }
          }
        }
      }
    }
  }
}
