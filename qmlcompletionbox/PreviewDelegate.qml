import QtQuick 2.3

Item {
    id: delegate
    property string text
    width: parent ? parent.width : 0
    height: itemRect.height + 2

    Rectangle {
        id: itemRect

        height: textComponent.height
        width: parent.width - 2

        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter

        color: "#333333"
        radius: 5
        border {
            width: 2
            color: "gray"
        }

        Text {
            width: parent.width - 10
            anchors.horizontalCenter: parent.horizontalCenter
            id: textComponent
            color: "white"
            text: delegate.text
        }
    }
}
