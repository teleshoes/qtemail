import QtQuick 1.1

Rectangle {
    id: suggBox
    property alias text: inputField.text

    property variant suggModel
    property bool showPreview: false

    signal keyPressed

    Item {
        id: contents
        anchors.fill: parent

        LineEdit {
            id: inputField
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 18

            hint.text: "Enter text. It will be completed with lines below"
            borderColor: "white"

            function activateSuggestionAt(offset) {
                var max = suggestionsBox.count
                if(max == 0)
                    return

                var newIndex = ((suggestionsBox.currentIndex + 1 + offset) % (max + 1)) - 1
                suggestionsBox.currentIndex = newIndex
            }
            onUpPressed: activateSuggestionAt(-1)
            onDownPressed: activateSuggestionAt(+1)
            onEnterPressed: processEnter()
            onAccepted: processEnter()
            onKeyPressed: suggBox.keyPressed()

            Component.onCompleted: {
                inputField.forceActiveFocus()
            }

            function processEnter() {
                if (suggestionsBox.currentIndex === -1) {
                    console.log("Enter pressed in input field")
                } else {
                    suggestionsBox.complete(suggestionsBox.currentItem)
                }
            }
        }

        SuggestionsPreview {
            // just to show you what you can type in
            model: suggModel
            visible: suggBox.showPreview
        }

        SuggestionBox {
            id: suggestionsBox
            model: suggModel
            width: parent.width
            anchors.top: inputField.bottom
            anchors.left: inputField.left
            filter: inputField.textInput.text
            property: "name"
            onItemSelected: complete(item)

            function complete(item) {
                suggestionsBox.currentIndex = -1
                if (item !== undefined)
                    inputField.textInput.text = item.name
            }
        }

    }

}
