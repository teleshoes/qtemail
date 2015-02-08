import QtQuick 1.1

Rectangle {
  anchors.fill: parent

  function getValues(){
    return {
      "to": to.getEmails(),
      "cc": cc.getEmails(),
      "bcc": bcc.getEmails(),
      "subject": subject.value,
      "body": body.value,
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
    Field {
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
    }
  }

  ScrollBar{
    flickable: sendFlickable
    anchors.rightMargin: 0 - 30
  }
}
