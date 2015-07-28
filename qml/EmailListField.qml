import QtQuick 1.1

Rectangle {
  property alias labelText: textField.labelText
  property alias isDark: textField.isDark
  color: textField.color

  function getEmails(){
    var emails = []
    for(var i=0; i<emailListView.model.count; i++){
      emails.push(emailListView.model.get(i)['email'])
    }
    return emails
  }
  function setEmails(emails){
    clearEmails()
    for(var i=0; i<emails.length; i++){
      addEmail(emails[i])
    }
  }

  function addEmail(email){
    emailListView.model.append({'email': email})
  }
  function clearEmails(){
    emailListView.model.clear()
  }

  SuggField {
    id: textField
    fontSize: main.fontMedium
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    onEnterPressed: {
      add.clicked()
    }
    suggModel: addressBookModel
  }

  Btn {
    id: add
    anchors.left: parent.left
    anchors.top: textField.bottom
    width: parent.width * textField.labelWidth - 20
    height: emailListContainer.height
    text: "Add Email\n" + emailListView.model.count + " email(s)"
    onClicked: {
      if(textField.value){
        addEmail(textField.value)
        textField.value = ""
      }
    }
  }
  Rectangle {
    id: emailListContainer
    anchors.top: textField.bottom
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    width: parent.width * (1 - textField.labelWidth) - 4
    clip: true
    anchors.margins: 2
    border.width: 1
    border.color: "white"
    color: textField.color

    ListView {
      id: emailListView
      anchors.fill: parent
      anchors.margins: 5
      model: ListModel {}
      clip: true

      spacing: 8
      delegate: Rectangle {
        height: emailListLabel.height
        width: parent.width
        color: "#E1D6A1"
        border.width: 2
        Text {
          id: emailListLabel
          width: parent.width * 0.90
          text: model['email']
          font.pointSize: main.fontSmall
        }
        Btn {
          anchors {left: emailListLabel.right}
          height: emailListLabel.height
          width: parent.width * 0.10
          text: "x"
          onClicked: {
            emailListView.model.remove(index)
          }
        }
      }
    }
  }
}
