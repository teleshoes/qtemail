import QtQuick 2.3

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
  function getFilesModel(){
    return fileListView.model
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


  Rectangle {
    color: parent.color
    width: parent.width
    height: 40
    id: labelContainer
    Text {
      id: label
      height: parent.height
      font.pointSize: scaling.fontMedium
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
          setValueHome()
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
            height: filePathPanel.height + errorMsgPanel.height + detailsPanel.height
            width: parent.width * 0.90
            Rectangle {
              id: filePathPanel
              color: "#E1D6A1"
              height: filePathLabel.text.length > 0 ? filePathLabel.height : 0
              width: parent.width
              Text {
                id: filePathLabel
                width: parent.width
                text: model.fileInfo.FilePath
                font.pointSize: scaling.fontSmall
                wrapMode: Text.Wrap
              }
            }
            Rectangle {
              id: errorMsgPanel
              color: "#FF0000"
              height: errorLabel.text.length > 0 ? errorLabel.height : 0
              width: parent.width
              Text {
                id: errorLabel
                width: parent.width
                text: model.fileInfo.ErrorMsg
                font.pointSize: scaling.fontSmall
                wrapMode: Text.Wrap
              }
            }
            Rectangle {
              id: detailsPanel
              color: "#CCCCCC"
              height: detailsLabel.text.length > 0 ? detailsLabel.height : 0
              width: parent.width
              function formatDetails() {
                var msg = ""
                if(model.fileInfo.SizeFmt){
                  msg += model.fileInfo.SizeFmt
                }
                if(model.fileInfo.MtimeFmt){
                  msg += " | " + model.fileInfo.MtimeFmt
                }
                return msg
              }

              Text {
                id: detailsLabel
                width: parent.width
                text: detailsPanel.formatDetails()
                font.pointSize: scaling.fontSmall
                wrapMode: Text.Wrap
              }
            }
          }
          Btn {
            anchors {left: fileInfoCol.right}
            height: fileInfoCol.height
            width: parent.width * 0.10
            text: "X"
            textSize: scaling.fontLarge
            onClicked: {
              controller.removeFileInfo(model.fileInfo.FilePath)
            }
          }
        }
      }
    }
  }
}
