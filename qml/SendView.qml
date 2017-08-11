import QtQuick 1.1

Rectangle {
  id: sendView
  anchors.fill: parent
  width: 1; height: 1 //retarded hack to get resizing to work

  property bool sendButtonEnabled: true
  property alias accountLabelText: accountLabel.text

  // NOTIFIER
  Notifier {
    id: sendNotifier
    enabled: false
  }

  function setNotifierEnabled(enabled){
    sendNotifier.enabled = enabled
  }

  function getForm(){
    return form
  }
  Item {
    id: form

    function getTo(){
      return to.getEmails()
    }
    function setTo(emails){
      return to.setEmails(emails)
    }

    function getCC(){
      return cc.getEmails()
    }
    function setCC(emails){
      return cc.setEmails(emails)
    }

    function getBCC(){
      return bcc.getEmails()
    }
    function setBCC(emails){
      return bcc.setEmails(emails)
    }

    function getAttachments(){
      return attachments.getFiles()
    }
    function setAttachments(files){
      return attachments.setFiles(files)
    }

    function getSubject(){
      return subject.getValue()
    }
    function setSubject(value){
      return subject.setValue(value)
    }

    function getBody(){
      return body.getValue()
    }
    function setBody(value){
      return body.setValue(value)
    }
  }

  Flickable {
    id: sendFlickable
    height: parent.height - sendBtn.height
    width: parent.width
    anchors {left: parent.left; top: parent.top}
    clip: true

    contentWidth: parent.width
    contentHeight: to.height + cc.height + bcc.height + subject.height + attachments.height + body.height

    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.DragOverBounds

    Rectangle {
      id: accountLabelContainer
      anchors {left: parent.left; right: parent.right; top: parent.top}
      height: main.fontLarge * 2
      width: parent.width
      color: "#444444"

      Text {
        id: accountLabel
        text: "NO ACCOUNT SELECTED"
        anchors.fill: parent
        color: "#ff0000"
        font.pointSize: main.fontLarge
        font.capitalization: Font.AllUppercase
        font.weight: Font.DemiBold
      }
    }
    EmailListField {
      anchors {left: parent.left; right: parent.right; top: accountLabelContainer.bottom}
      id: to
      labelText: "TO"
      isDark: false
      height: 100
      width: parent.width
    }
    EmailListField {
      anchors {left: parent.left; right: parent.right; top: to.bottom}
      id: cc
      labelText: "CC"
      isDark: true
      height: 100
      width: parent.width
    }
    EmailListField {
      anchors {left: parent.left; right: parent.right; top: cc.bottom}
      id: bcc
      labelText: "BCC"
      isDark: false
      height: 100
      width: parent.width
    }
    FileSelectorField {
      id: attachments
      labelText: "ATTACHMENTS"
      anchors {left: parent.left; right: parent.right; top: bcc.bottom}
      isDark: true
    }
    LongField {
      anchors {left: parent.left; right: parent.right; top: attachments.bottom}
      id: subject
      labelText: "SUBJECT"
      isDark: false
      fontSize: main.fontMedium
    }
    MultiLineField {
      anchors {left: parent.left; right: parent.right; top: subject.bottom}
      id: body
      labelText: "BODY"
      isDark: true
      cursorFollow: sendFlickable
      fontSize: main.fontMedium
    }
  }
  Btn{
    text: "Send"
    id: sendBtn
    anchors {left: parent.left; top: sendFlickable.bottom}
    visible: sendButtonEnabled
    height: sendButtonEnabled ? 50 : 0
    width: 100

    onClicked: controller.sendEmail(sendView.getForm())
  }

  ScrollBar{
    flickable: sendFlickable
    anchors.rightMargin: 0 - 30
  }
}
