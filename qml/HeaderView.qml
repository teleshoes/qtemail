import QtQuick 1.1

Rectangle {
  anchors.fill: parent

  function getFlickable(){
    return headerListView
  }

  function setCounterText(text){
    counterTextArea.text = text
  }

  Rectangle {
    id: counterBox
    anchors.left: parent.left
    anchors.right: parent.right
    width: parent.width
    height: 30
    y: 0 - 30
    z: 10

    Text {
      id: counterTextArea
      anchors.margins: 5
      anchors.right: parent.right
      font.pointSize: 12
    }
  }

  Rectangle {
    id: searchBox
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: headerListView.top
    width: parent.width
    height: 30
    border.width: 2
    z: 10

    TextInput {
      anchors.margins: 2
      id: searchTextBox
      anchors.fill: parent
      font.pointSize: 18
      onTextChanged: {
        controller.onSearchTextChanged(searchTextBox.text)
      }
    }
  }

  ListView {
    id: headerListView
    anchors.bottom: parent.bottom
    anchors.top: searchBox.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    width: parent.width
    height: parent.height - searchBox.height

    spacing: 10
    model: headerModel
    delegate: Component  {
      Rectangle {
        color: "#AAAAAA"
        height: 125
        width: parent.width
        MouseArea {
          anchors.fill: parent
          onClicked: {
            controller.headerSelected(model.header)
            navToPage(bodyPage)
          }
        }
        Rectangle {
          id: readIndicator
          height: parent.height
          width: parent.width * 0.15
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          color: getColor()
          function getColor(){
            if(model.header.IsLoading){
              return "#FF0000";
            }else{
              return model.header.Read ? "#E1D6A1" : "#666666"
            }
          }
          function updateColor(){
            this.color = getColor()
          }
          MouseArea {
            anchors.fill: parent
            onClicked: {
              controller.toggleRead(readIndicator, model.header)
            }
          }
        }
        Column {
          id: col
          anchors.fill: parent
          Text {
            text: model.header.IsSent ? "=>" + model.header.To : model.header.From
            font.pointSize: 24
          }
          Text {
            text: model.header.Date
            font.pointSize: 20
          }
          Text {
            text: model.header.Subject
            font.pointSize: 16
          }
        }
      }
    }
    clip: true
  }
}
