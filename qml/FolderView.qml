import QtQuick 1.1

Rectangle {
  anchors.fill: parent

  ListView {
    id: folderFlickable
    spacing: 50
    anchors.fill: parent
    model: folderModel
    delegate: Component  {
      Rectangle {
        height: 100
        width: parent.width
        color: "gray"
        MouseArea{
          anchors.fill: parent
          onClicked: {
            controller.folderSelected(model.folder)
            controller.setupHeaders()
            controller.updateCounterBox(headerView.getCounterBox())
            navToPage(headerPage)
          }
        }
        Text {
          anchors.centerIn: parent
          text: model.folder.Name + ": " + model.folder.Unread + "/" + model.folder.Total
          font.pointSize: main.fontHuge
        }
      }
    }
  }

  ScrollBar{
    flickable: folderFlickable
    anchors.rightMargin: 0 - 30
  }
}
