import QtQuick 2.3

Item {
    id: component
    property alias model: filterModel

    property bool prefixOnly: true
    property QtObject sourceModel: undefined
    property string filter: ""
    property string property: ""

    Connections {
        function onFilterChanged(){
          invalidateFilter()
        }
        function onPropertyChanged(){
          invalidateFilter()
        }
        function onSourceModelChanged(){
          invalidateFilter()
        }
    }

    Component.onCompleted: invalidateFilter()

    ListModel {
        id: filterModel
    }


    // filters out all items of source model that does not match filter
    function invalidateFilter() {
        if (sourceModel === undefined)
            return;

        filterModel.clear();

        if (!isFilteringPropertyOk())
            return

        var length = sourceModel.count
        for (var i = 0; i < length; ++i) {
            var item = sourceModel.get(i);
            if (isAcceptedItem(item)) {
                filterModel.append(item)
            }
        }
    }


    // returns true if item is accepted by filter
    function isAcceptedItem(item) {
        if (item[this.property] === undefined)
            return false

        var suggFilter = this.filter
        if(prefixOnly){
          suggFilter = "^" + suggFilter
        }

        if (item[this.property].match(suggFilter) === null) {
            return false
        }

        return true
    }

    // checks if it has any sence to process invalidating based on property
    function isFilteringPropertyOk() {
        if(this.property === undefined || this.property === "") {
            return false
        }
        return true
    }
}

