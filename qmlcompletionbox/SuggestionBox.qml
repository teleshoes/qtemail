/*
    Copyright (C) 2011 Jocelyn Turcotte <turcotte.j@gmail.com>

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public License
    along with this program; see the file COPYING.LIB.  If not, write to
    the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1301, USA.
*/

import QtQuick 1.1

Rectangle {
    id: container

    // --- properties
    property QtObject model: undefined
    property int count: filterItem.model.count
    property alias currentIndex: popup.selectedIndex
    property alias currentItem: popup.selectedItem
    property alias suggestionsModel: filterItem.model
    property alias filter: filterItem.filter
    property alias property: filterItem.property
    signal itemSelected(variant item)

    // --- behaviours
    z: parent.z + 100
    visible: filter.length > 0 && suggestionsModel.count > 0 && !filterMatchesLastSuggestion()
    height: visible ? childrenRect.height : 0
    Behavior on height {
        NumberAnimation{}
    }
    function filterMatchesLastSuggestion() {
        return suggestionsModel.count == 1 && suggestionsModel.get(0).name === filter
    }


    // --- defaults
    color: "gray"
    radius: 5
    border {
        width: 1
        color: "white"
    }


    Filter {
        id: filterItem
        sourceModel: container.model
    }


    // --- UI
    Column {
        id: popup
        clip: true
        height: childrenRect.height
        width: parent.width - 6
        anchors.centerIn: parent


        property int selectedIndex: -1
        property variant selectedItem: selectedIndex === -1 ? undefined : filterItem.model.get(selectedIndex)
        signal suggestionClicked(variant suggestion)

        opacity: container.visible ? 1.0 : 0
        Behavior on opacity {
            NumberAnimation { }
        }


        Repeater {
            id: repeater
            model: container.suggestionsModel
            delegate: Item {
                id: delegateItem
                property bool keyboardSelected: popup.selectedIndex === suggestion.index
                property bool selected: itemMouseArea.containsMouse
                property variant suggestion: model

                height: textComponent.height
                width: container.width

                Rectangle {
                    border.width: delegateItem.keyboardSelected ? 1 : 0
                    border.color: "white"
                    radius: 3
                    height: textComponent.height
                    color: "transparent"
                    width: parent.width - 7
                    Text {
                        id: textComponent
                        color: delegateItem.selected ? "yellow" : "white"
                        text: suggestion.name
                        width: parent.width - 4
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    id: itemMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: container.itemSelected(delegateItem.suggestion)
                }
            }
        }
    }

}

