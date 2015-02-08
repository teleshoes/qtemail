import QtQuick 1.1

Flickable {
  anchors.fill: parent
  flickableDirection: Flickable.VerticalFlick

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
