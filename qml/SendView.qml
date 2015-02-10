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
    function getCC(){
      return cc.getEmails()
    }
    function getBCC(){
      return bcc.getEmails()
    }
    function getSubject(){
      return subject.value
    }
    function getBody(){
      return body.value
    }
  }

  Flickable {
    id: sendFlickable
    contentWidth: parent.width
    contentHeight: to.height + cc.height + bcc.height + subject.height + body.height
    anchors.fill: parent
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.DragOverBounds

    function followBodyCursor(cursorY){
      console.log([cursorY, body.y, body.editY])
      var cY = cursorY + body.y + body.editY
      var offset = body.fontSize*2
      if (contentY >= cY){
        contentY = cY - offset
      }else if (contentY+height <= cY){
        contentY = cY-height
      }
    }
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
      onCursorYChanged: sendFlickable.followBodyCursor(cursorY)
    }
  }

  ScrollBar{
    flickable: sendFlickable
    anchors.rightMargin: 0 - 30
  }
}
