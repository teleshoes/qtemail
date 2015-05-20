import QtQuick 1.1

Rectangle {
    width: 640
    height: 480
    color: "black"
    property alias text: inputField.text

    property variant suggModel

    Item {
        id: contents
        width: parent.width - 100
        height: parent.height - 100
        anchors.centerIn: parent

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
        }

        SuggestionBox {
            id: suggestionsBox
            model: suggModel
            width: 200
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
