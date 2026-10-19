import QtQuick
import QtQuick.Layouts


import Quickshell
import Quickshell.Wayland
import Quickshell.Io


Item {
    implicitHeight: 150
    implicitWidth: 300
    
    Column {
        spacing:5
	    Text {
		    text: "Activate Linux"
		    color: "#50ffffff"
		    font.pointSize: 22
	    }

	    Text {
		    text: "Go to Settings to activate Linux"
		    color: "#50ffffff"
		    font.pointSize: 14
	    }
    }    
}
