import QtQuick
import QtMultimedia
import QtQuick.Layouts


import Quickshell
import Quickshell.Wayland
import Quickshell.Io


import "PrettyPlayer"
import "ActivateWatermark"
import "SwayStatusBar"


ShellRoot {

    NewStatusBar{}
    
	Variants {
		model: Quickshell.screens

		PanelWindow {
			id: mainWindow

			property var modelData
			screen: modelData

			anchors {
				right: true
				bottom: true
			}

			margins {
				right: 20
				bottom: 20
			}

            implicitWidth: content.width
            implicitHeight: content.height
            
			color: "transparent"
			mask: Region {}

            
			// Use the wlroots specific layer property to ensure it displays over
			// fullscreen windows.
			WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore   // don't reserve screen space

            
            ColumnLayout {                
                id: content
                ActivateWatermark{
                    implicitHeight: 130
                    implicitWidth: 320
                }
                //                PrettyPlayer {
                //                    videoSource: "assets/samples/sample.mp4"
                //                    videoPlaySpeed: 1.0
                //                    implicitHeight: 400
                //                    implicitWidth: 300
                //                }
            }
		}
	}
}
