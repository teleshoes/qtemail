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
