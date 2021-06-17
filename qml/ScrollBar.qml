import QtQuick 2.3

// written by Thomas BOUTROUE
// https://stackoverflow.com/users/1195141/thebootroo
// https://stackoverflow.com/questions/17833103/how-to-create-scrollbar-in-qtquick-2-0#17876641

Item {
    id: scrollbar;
    width: (handleSize + 2 * (backScrollbar.border.width +1));
    visible: (flickable.visibleArea.heightRatio < 1.0);
    anchors {
        top: flickable.top;
        right: flickable.right;
        bottom: flickable.bottom;
        margins: 1;
    }

    property Flickable flickable               : null;
    property int       handleSize              : 20;

    function getFlickableY(){
      return flickable.contentY - flickable.originY
    }
    function setFlickableY(flickableY){
      flickable.contentY = flickableY + flickable.originY
    }

    function scrollDown () {
        setFlickableY(Math.min (getFlickableY() + (flickable.height / 4), flickable.contentHeight - flickable.height));
    }
    function scrollUp () {
        setFlickableY(Math.max (getFlickableY() - (flickable.height / 4), 0));
    }

    Component.onCompleted: {
      try {
        bindingHandle.restoreMode = 0    //should be Binding.RestoreNonde
        bindingFlickable.restoreMode = 0 //should be Binding.RestoreNonde
      } catch(error) {
        //ignore possibly unimplemented restoreMode
      }
    }

    Binding {
        id: bindingHandle
        target: handle;
        property: "y";
        value: (getFlickableY() * clicker.drag.maximumY / (flickable.contentHeight - flickable.height));
        when: (!clicker.drag.active && !clicker.pressed);
    }
    Binding {
        id: bindingFlickable
        target: flickable;
        property: "contentY";
        value: flickable.originY + (handle.y * (flickable.contentHeight - flickable.height) / clicker.drag.maximumY);
        when: (clicker.drag.active || clicker.pressed);
    }
    Rectangle {
        id: backScrollbar;
        radius: 2;
        color: Qt.rgba(0.5, 0.5, 0.5, 0.85);
        border {
            width: 1;
            color: "darkgray";
        }
        anchors { fill: parent; }

        MouseArea {
            anchors.fill: parent;
            onClicked: { }
        }
    }
    MouseArea {
        id: btnUp;
        height: width;
        anchors {
            top: parent.top;
            left: parent.left;
            right: parent.right;
            margins: (backScrollbar.border.width +1);
        }
        onClicked: { scrollUp (); }

        Text {
            text: "V";
            color: (btnUp.pressed ? "blue" : "black");
            rotation: -180;
            anchors.centerIn: parent;
        }
    }
    MouseArea {
        id: btnDown;
        height: width;
        anchors {
            left: parent.left;
            right: parent.right;
            bottom: parent.bottom;
            margins: (backScrollbar.border.width +1);
        }
        onClicked: { scrollDown (); }

        Text {
            text: "V";
            color: (btnDown.pressed ? "blue" : "black");
            anchors.centerIn: parent;
        }
    }
    Item {
        id: groove;
        clip: true;
        anchors {
            fill: parent;
            topMargin: (backScrollbar.border.width +1 + btnUp.height +1);
            leftMargin: (backScrollbar.border.width +1);
            rightMargin: (backScrollbar.border.width +1);
            bottomMargin: (backScrollbar.border.width +1 + btnDown.height +1);
        }

        MouseArea {
            id: clicker;
            drag {
                target: handle;
                minimumY: 0;
                maximumY: (groove.height - handle.height);
                axis: Drag.YAxis;
            }
            anchors { fill: parent; }
            onClicked: { setFlickableY(mouse.y / groove.height * (flickable.contentHeight - flickable.height)); }
        }
        Item {
            id: handle;
            height: Math.max (20, (flickable.visibleArea.heightRatio * groove.height));
            anchors {
                left: parent.left;
                right: parent.right;
            }

            Rectangle {
                id: backHandle;
                color: (clicker.pressed ? "blue" : "black");
                opacity: (flickable.moving ? 0.65 : 0.35);
                anchors { fill: parent; }

                Behavior on opacity { NumberAnimation { duration: 150; } }
            }
        }
    }
}
