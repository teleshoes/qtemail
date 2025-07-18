import QtQuick 2.3

Rectangle {
  anchors.fill: parent

  function getCounterBox(){
    return counterBox
  }

  function resetScroll(){
    headerFlickable.positionViewAtBeginning()
  }

  Rectangle {
    id: counterBox
    anchors.left: parent.left
    anchors.right: parent.right
    width: parent.width
    height: counterTextArea.height
    y: 0 - 30
    z: 10

    function setCounterText(text){
      counterTextArea.text = text
    }

    Text {
      id: counterTextArea
      anchors.margins: 5
      anchors.right: parent.right
      font.pointSize: scaling.fontTiny
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
        height: filterFontSize * 2.14

        property int filterFontSize: scaling.fontSmall

        ListView {
          id: filterButtonList
          model: filterButtonModel
          orientation: ListView.Horizontal
          width: parent.width
          height: parent.height
          spacing: 10
          delegate: Btn {
            height: filterToggleBox.height
            width: (model.filterButton.Name.length + 1) * 1.14 * textSize

            property bool checked: model.filterButton.IsChecked
            property bool negated: model.filterButton.IsNegated

            text: negated ? "!" + model.filterButton.Name : model.filterButton.Name
            textSize: filterToggleBox.filterFontSize
            buttonColorDefault: checked ? (negated ? "red" : "blue") : "gray"


            onCheckedChanged: {
              if(checked){
                var filterStr = model.filterButton.FilterString
                controller.replaceHeaderFilterStr(model.filterButton.Name, filterStr, negated)
              }else{
                controller.removeHeaderFilter(model.filterButton.Name)
              }
              controller.refreshHeaderFilters()
            }

            onClicked: {
              var isChecked = !model.filterButton.IsChecked
              var isNegated = isChecked && mouse.button === Qt.RightButton
              model.filterButton.setChecked(isChecked, isNegated)
            }
            onPressAndHold: {
              var isChecked = !model.filterButton.IsChecked
              var isNegated = isChecked
              model.filterButton.setChecked(isChecked, isNegated)
            }
          }
        }
      }
      Rectangle {
        id: searchBox
        width: parent.width
        height: searchTextBox.height
        border.width: 2

        TextInput {
          anchors.margins: 2
          id: searchTextBox
          width: parent.width
          height: font.pointSize * 2
          font.pointSize: scaling.fontSmall
          Keys.onReturnPressed: {
            controller.onSearchTextChanged(searchTextBox.text)
          }
        }
      }
    }
  }

  ListView {
    id: headerFlickable
    model: headerModel
    spacing: isWideView ? 1 : 10
    anchors.bottom: parent.bottom
    anchors.top: filterBox.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    width: parent.width
    height: parent.height - filterBox.height
    clip: true

    property bool isWideView: width >= main.headerWideViewMinPx

    Keys.onPressed:{
      if (event.key == Qt.Key_Up){
        decrementCurrentIndex()
        selectHeader(curHeader())
        event.accepted = true
      } else if (event.key == Qt.Key_Down){
        incrementCurrentIndex()
        selectHeader(curHeader())
        event.accepted = true
      } else if (event.key == Qt.Key_Space){
        toggleRead(curHeader())
        event.accepted = true
      } else if (event.key == Qt.Key_Escape){
        clearBody()
        event.accepted = true
      } else if (event.key == Qt.Key_Home){
        positionViewAtBeginning()
        event.accepted = true
      } else if (event.key == Qt.Key_End){
        positionViewAtEnd()
        event.accepted = true
      } else if (event.key == Qt.Key_PageUp){
        bodyView.scrollUp()
      } else if (event.key == Qt.Key_PageDown){
        bodyView.scrollDown()
      } else if (event.key == Qt.Key_F){
        main.toggleFullScreenBody()
      }
    }

    function curHeader(){
      return currentItem.modelHeader
    }

    function toggleRead(header){
      controller.toggleRead(header)
    }
    function selectHeader(header){
      controller.headerSelected(header)
      navToPage(bodyPage)
    }

    delegate: Rectangle {
      property variant modelHeader: model.header
      color: model.header.Selected ? "#FF6666" : "#AAAAAA"

      height: headerFlickable.isWideView ? wideView.height : narrowView.height
      width: parent ? parent.width : 0


      MouseArea {
        anchors.fill: parent
        onClicked: {
          headerFlickable.focus = true
          headerFlickable.currentIndex = index
          headerFlickable.selectHeader(model.header)
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
            headerFlickable.toggleRead(model.header)
          }
        }
      }
      Row {
        id: wideView
        visible: headerFlickable.isWideView
        width: parent.width
        height: Math.max(wideSubjectLabel.paintedHeight, wideDateLabel.paintedHeight, wideAddressLabel.paintedHeight)
        spacing: 10
        Text {
          id: wideSubjectLabel
          text: model.header.Subject
          font.pointSize: scaling.fontSmall
          width: parent.width * 0.5
          clip: true
        }
        Text {
          id: wideDateLabel
          text: model.header.Date
          font.pointSize: scaling.fontSmall
          width: font.pointSize * 14.3
        }
        Text {
          id: wideAddressLabel
          text: model.header.IsSent ? "=>" + model.header.To : model.header.From
          font.pointSize: scaling.fontSmall
          width: parent.width - wideSubjectLabel.width - wideDateLabel.width
        }
      }
      Column {
        id: narrowView
        visible: !headerFlickable.isWideView
        width: parent.width
        height: narrowAddressLabel.paintedHeight + narrowDateLabel.paintedHeight + narrowSubjectLabel.paintedHeight
        Text {
          id: narrowAddressLabel
          text: model.header.IsSent ? "=>" + model.header.To : model.header.From
          font.pointSize: scaling.fontLarge
        }
        Text {
          id: narrowDateLabel
          text: model.header.Date
          font.pointSize: scaling.fontMedium
        }
        Text {
          id: narrowSubjectLabel
          text: model.header.Subject
          font.pointSize: scaling.fontSmall
        }
      }
    }
  }

  ScrollBar{
    flickable: headerFlickable
    anchors.rightMargin: -30
  }
}
