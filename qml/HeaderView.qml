import QtQuick 1.1

Rectangle {
  anchors.fill: parent

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
  }
}
