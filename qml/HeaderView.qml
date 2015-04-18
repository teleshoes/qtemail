import QtQuick 1.1

Rectangle {
  anchors.fill: parent

  function getCounterBox(){
    return counterBox
  }

  Rectangle {
    id: counterBox
    anchors.left: parent.left
    anchors.right: parent.right
    width: parent.width
    height: 30
    y: 0 - 30
    z: 10

    function setCounterText(text){
      counterTextArea.text = text
    }

    Text {
      id: counterTextArea
      anchors.margins: 5
      anchors.right: parent.right
      font.pointSize: 12
    }
  }

  Rectangle {
    id: filterBox
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: headerFlickable.top
    width: parent.width
    height: searchBox.height + filterToggleBox.height
    z: 10

    Column {
      anchors.fill: parent
      Row {
        id: filterToggleBox
        width: parent.width
        height: 30
        ListView {
          id: filterButtonList
          model: filterButtonModel
          orientation: ListView.Horizontal
          width: parent.width
          height: parent.height
          spacing: 10
          delegate: Btn {
            height: filterToggleBox.height
            width: model.filterButton.Name.length * 16

            property bool checked: model.filterButton.IsChecked
            text: model.filterButton.Name
            buttonColorDefault: checked ? "blue" : "gray"


            onCheckedChanged: {
              if(checked){
                controller.replaceHeaderFilterStr(model.filterButton.Name,
                  model.filterButton.FilterString)
              }else{
                controller.removeHeaderFilter(model.filterButton.Name)
              }
              controller.refreshHeaderFilters()
              controller.updateCounterBox(headerView.getCounterBox())
            }

            onClicked: {
              model.filterButton.setChecked(!model.filterButton.IsChecked)
            }
          }
        }
      }
      Rectangle {
        id: searchBox
        width: parent.width
        height: 30
        border.width: 2

        TextInput {
          anchors.margins: 2
          id: searchTextBox
          anchors.fill: parent
          font.pointSize: 18
          onTextChanged: {
            controller.onSearchTextChanged(searchTextBox.text)
            controller.updateCounterBox(headerView.getCounterBox())
          }
        }
      }
    }
  }

  ListView {
    id: headerFlickable
    anchors.bottom: parent.bottom
    anchors.top: filterBox.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    width: parent.width
    height: parent.height - filterBox.height

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

  ScrollBar{
    flickable: headerFlickable
    anchors.rightMargin: -30
  }
}
