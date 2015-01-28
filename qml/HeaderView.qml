import QtQuick 1.1

ListView {
  spacing: 10
  anchors.fill: parent
  model: headerModel
  delegate: Component  {
    Rectangle {
      color: "#AAAAAA"
      height: 125
      width: parent.width
      MouseArea {
        anchors.fill: parent
        onClicked: {
          bodyView.setBody(controller.getBodyText(model.header))
          navToPage(bodyPage)
        }
      }
      Rectangle {
        id: readIndicator
        height: parent.height
        width: parent.width * 0.15
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: getReadColor()
        function getReadColor(){
          return model.header.Read ? "#E1D6A1" : "#666666"
        }
        MouseArea {
          anchors.fill: parent
          onPressed: parent.color = "#FF0000"
          onExited: parent.color = parent.getReadColor()
          onClicked: {
            controller.toggleRead(readIndicator, model.header)
          }
        }
      }
      Column {
        id: col
        anchors.fill: parent
        Text {
          text: model.header.From
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
}
