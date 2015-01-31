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
      Rectangle {
        id: updateIndicator
        height: parent.height
        width: parent.width * 0.15
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: getColor()
        function getColor(){
          if(model.account.IsLoading){
            return "#FF0000";
          }else{
            return "#666666"
          }
        }
        function updateColor(){
          this.color = getColor()
        }
        MouseArea {
          anchors.fill: parent
          onClicked: {
            controller.updateAccount(updateIndicator, model.account)
          }
        }
      }
      Text {
        anchors.centerIn: parent
        text: model.account.Name + ": " + model.account.Unread
        font.pointSize: 36
      }
      Text {
        anchors.right: parent.right
        anchors.rightMargin: parent.width * 0.15
        text: model.account.LastUpdatedRel
        font.pointSize: 24
      }
      Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        text: model.account.Error
        font.pointSize: 24
      }
    }
  }
}
