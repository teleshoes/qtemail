import QtQuick 2.3

Rectangle {
  anchors.fill: parent

  ListView {
    id: folderFlickable
    spacing: 40
    anchors.fill: parent
    model: folderModel
    delegate: Component  {
      Rectangle {
        height: 80
        width: parent ? parent.width : 0
        color: "gray"
        MouseArea{
          anchors.fill: parent
          onClicked: {
            controller.folderSelected(model.folder)
            controller.setupHeaders()
            navToPage(headerPage)
          }
        }
        Text {
          anchors.centerIn: parent
          text: model.folder.Name + ": " + model.folder.Unread + "/" + model.folder.Total
          font.pointSize: scaling.fontHuge
        }
      }
    }
  }

  ScrollBar{
    flickable: folderFlickable
    anchors.rightMargin: 0 - 30
  }
}
