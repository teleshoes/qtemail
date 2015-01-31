import QtQuick 1.1

ListView {
  spacing: 50
  anchors.fill: parent
  model: accountModel
  delegate: Component  {
    Rectangle {
      height: 150
      width: parent.width
      color: "gray"
      MouseArea{
        anchors.fill: parent
        onClicked: {
          controller.accountSelected(model.account)
          controller.setupHeaders()
          navToPage(headerPage)
        }
      }
      Text {
        anchors.centerIn: parent
        text: model.account.Name + ": " + model.account.Unread
        font.pointSize: 36
      }
      Text {
        anchors.right: parent.right
        text: model.account.LastUpdatedRel
        font.pointSize: 24
      }
    }
  }
}
