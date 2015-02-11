import QtQuick 1.1

Rectangle {
  id: sendView
  anchors.fill: parent

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

    function getSubject(){
      return subject.value
    }
    function setSubject(value){
      return subject.value = value
    }

    function getBody(){
      return body.value
    }
    function setBody(value){
      return body.value = value
    }
  }

  Flickable {
    id: sendFlickable
    contentWidth: parent.width
    contentHeight: to.height + cc.height + bcc.height + subject.height + body.height
    anchors.fill: parent
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.DragOverBounds

    EmailListField {
      anchors {left: parent.left; right: parent.right; top: parent.top}
      id: to
      labelText: "TO"
      isDark: false
      height: 150
      width: parent.width
    }
    EmailListField {
      anchors {left: parent.left; right: parent.right; top: to.bottom}
      id: cc
      labelText: "CC"
      isDark: true
      height: 150
      width: parent.width
    }
    EmailListField {
      anchors {left: parent.left; right: parent.right; top: cc.bottom}
      id: bcc
      labelText: "BCC"
      isDark: false
      height: 150
      width: parent.width
    }
    LongField {
      anchors {left: parent.left; right: parent.right; top: bcc.bottom}
      id: subject
      labelText: "SUBJECT"
      isDark: true
    }
    MultiLineField {
      anchors {left: parent.left; right: parent.right; top: subject.bottom}
      id: body
      labelText: "BODY"
      isDark: false
      cursorFollow: sendFlickable
    }
  }

  ScrollBar{
    flickable: sendFlickable
    anchors.rightMargin: 0 - 30
  }
}
