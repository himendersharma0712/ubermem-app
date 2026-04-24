import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Window {
    id: root
    width: 1280
    height: 720
    visible: true
    title: qsTr("UberMem")
    color: "#1c1c1c"
    visibility: Window.Maximized

    // --- TOP NAVIGATION PILL ---
    Rectangle {
        id: navBar
        width: 340; height: 50
        color: "#252525"
        radius: height / 2
        anchors.top: parent.top
        anchors.topMargin: 30
        anchors.horizontalCenter: parent.horizontalCenter
        border.color: "#333"
        border.width: 1
        z: 10

        property int activeIndex: 0

        Row {
            anchors.fill: parent
            Repeater {
                model: ["SYSTEM", "PROCESSES"]
                delegate: Item {
                    width: navBar.width / 2; height: navBar.height
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 4
                        color: navBar.activeIndex === index ? "#3d3d3d" : "transparent"
                        radius: 25
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: navBar.activeIndex === index ? "#76b9ed" : "#888"
                        font.pixelSize: 13; font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            navBar.activeIndex = index
                            pageStack.currentIndex = index
                        }
                    }
                }
            }
        }
    }


    Connections {
        target: systemStats
        function onPressureVelocityChanged() {
            // Pushes the sensor data into the ML model
            processModel.setVelocity(systemStats.pressureVelocity)
        }
    }

    // --- MAIN CONTENT AREA ---
    StackLayout {
        id: pageStack
        anchors.fill: parent
        currentIndex: 0

        // PAGE 1: THE NEXUS
        Item {
            id: systemPage
            ColumnLayout {

                anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 120
                    spacing: 60


                RowLayout {
                    spacing: 10
                    Layout.alignment: Qt.AlignHCenter

                    GaugeComponent {
                        label: "RAM USAGE"
                        value: typeof systemStats !== "undefined" ? systemStats.ramUsage : 42.0
                        ringColor: "#76b9ed"
                    }

                    GaugeComponent {
                        label: "CPU LOAD"
                        value: typeof systemStats !== "undefined" ? systemStats.cpuUsage : 0.0
                        ringColor: "#bb86fc"
                    }
                }

                ColumnLayout {
                    spacing: 20
                    Layout.alignment: Qt.AlignHCenter

                    Rectangle {
                        id: purgeButton
                        width: 260
                        height: 50
                        radius: 10
                        Layout.alignment: Qt.AlignCenter

                        color: mouseArea.pressed ? "#2d7dd2"
                             : mouseArea.containsMouse ? "#3c8ce7"
                             : "#4da3ff"

                        border.color: "#5fb0ff"
                        border.width: 1

                        layer.enabled: true


                        Text {
                            anchors.centerIn: parent
                            text: "CLEAN MEMORY"
                            color: "white"
                            font.bold: true
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                if (typeof processModel !== "undefined") {
                                                               processModel.purgeRiskProcesses();
                                                           }
                            }
                        }
                    }


                    RowLayout {
                        spacing: 40
                        Layout.alignment: Qt.AlignHCenter

                        // --- Profile Switch (Balanced vs Performance) ---
                        RowLayout {
                            spacing: 12
                            Switch {
                                id: performanceModeSwitch
                                checked: processModel.isGamingMode
                                onCheckedChanged: processModel.setGamingMode(checked)
                            }
                            Column {
                                Text {
                                    text: performanceModeSwitch.checked ? "PERFORMANCE MODE" : "BALANCED MODE"
                                    color: performanceModeSwitch.checked ? "orange" : "white"
                                    font.bold: true; font.pixelSize: 12
                                }
                                Text {
                                    text: "ACTIVE"
                                    color: "#888"; font.pixelSize: 10
                                }
                            }
                        }

                        // --- Cleaning Method Switch (Manual vs Automatic) ---
                        RowLayout {
                            spacing: 12
                            Switch {
                                id: autoModeSwitch
                                onCheckedChanged: {
                                    processModel.setAutoMode(checked)
                                }
                            }
                            Column {
                                Text {
                                    text: autoModeSwitch.checked ? "AUTO CLEANUP" : "AUTO CLEANUP"
                                    color: autoModeSwitch.checked ? "#00ffcc" : "white"
                                    font.bold: true; font.pixelSize: 12
                                }
                                Text {
                                    text: autoModeSwitch.checked ? "Monitoring system" : "Runs when memory usage spikes"
                                    color: "#888"; font.pixelSize: 10
                                }
                            }
                        }
                    }


                                        RowLayout {
                                            spacing: 20
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.topMargin: 20


                                            Rectangle {
                                                width: 500
                                                height: 180
                                                color: "#121212"
                                                border.color: "#333"
                                                radius: 8
                                                clip: true

                                                Text {
                                                    text: "TEMPORAL MEMORY PRESSURE (60S)"
                                                    color: "#888"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 12
                                                }

                                                Canvas {
                                                    id: pressureCanvas
                                                    anchors.fill: parent
                                                    anchors.topMargin: 30

                                                    Connections {
                                                        target: systemStats
                                                        function onRamHistoryChanged() { pressureCanvas.requestPaint() }
                                                    }

                                                    onPaint: {
                                                        var ctx = getContext("2d");
                                                        ctx.clearRect(0, 0, width, height);

                                                        var history = systemStats.ramHistory;
                                                        if (!history || history.length < 2) return;


                                                        var isGaming = performanceModeSwitch.checked;
                                                        var gradient = ctx.createLinearGradient(0, 0, 0, height);
                                                        gradient.addColorStop(0, isGaming ? "rgba(255, 51, 51, 0.3)" : "rgba(61, 204, 255, 0.3)");
                                                        gradient.addColorStop(1, "rgba(0, 0, 0, 0.0)");

                                                        ctx.beginPath();
                                                        ctx.lineWidth = 2;
                                                        ctx.strokeStyle = isGaming ? "#ff3333" : "#3dccff";

                                                        for (var i = 0; i < history.length; i++) {
                                                            var x = (i / 59) * width;
                                                            var y = height - (history[i] / 100) * height;

                                                            if (i === 0) ctx.moveTo(x, y);
                                                            else ctx.lineTo(x, y);
                                                        }

                                                        ctx.stroke();
                                                        ctx.lineTo(width, height);
                                                        ctx.lineTo(0, height);
                                                        ctx.fillStyle = gradient;
                                                        ctx.fill();
                                                    }
                                                }
                                            }


                                            Rectangle {
                                                width: 300
                                                height: 180
                                                color: "#121212"
                                                border.color: "#333"
                                                radius: 8

                                                Text {
                                                    text: "ML DIAGNOSTICS"
                                                    color: "#888"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 12
                                                }

                                                Column {
                                                    anchors.top: parent.top
                                                    anchors.topMargin: 40
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 12
                                                    spacing: 8

                                                    Text {
                                                        text: "> ACTIVE PROFILE: " + (performanceModeSwitch.checked ? "PERFORMANCE" : "BALANCED")
                                                        color: performanceModeSwitch.checked ? "#ff3333" : "#3dccff"
                                                        font.pixelSize: 11
                                                        font.family: "Consolas"
                                                    }
                                                    Text {
                                                        text: "> RAM FLOOR: " + (performanceModeSwitch.checked ? "400.0 MB" : "77.15 MB")
                                                        color: "#aaa"
                                                        font.pixelSize: 11
                                                        font.family: "Consolas"
                                                    }
                                                    Text {
                                                        text: "> DISK TOLERANCE: " + (performanceModeSwitch.checked ? "STRICT" : "MODERATE")
                                                        color: "#aaa"
                                                        font.pixelSize: 11
                                                        font.family: "Consolas"
                                                    }
                                                    Text {
                                                        text: "> SYSTEM STATE: STABILIZING"
                                                        color: "#44ff44"
                                                        font.pixelSize: 11
                                                        font.family: "Consolas"
                                                    }

                                                    Text {
                                                        text: "> PRESSURE VELOCITY: " + systemStats.pressureVelocity.toFixed(2) + " %/s"
                                                        color: systemStats.pressureVelocity > 1.5 ? "#ff3333" : "#888"
                                                        font.pixelSize: 11; font.family: "Consolas"
                                                    }

                                                    Text {
                                                        property real pred: systemStats.ramUsage + (systemStats.pressureVelocity * 5)
                                                        text: "> T+5s FORECAST: " + pred.toFixed(1) + "%"
                                                        color: pred > 90 ? "#ff3333" : "#44ff44"
                                                        font.pixelSize: 11; font.family: "Consolas"
                                                    }
                                                }
                                            }
                                        }
                }
            }
        }


        Item {
            id: processesPage
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 40
                anchors.topMargin: 110
                spacing: 15


                Rectangle {
                    Layout.fillWidth: true; height: 40
                    color: "#252525"; radius: 5
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20
                        Repeater {
                            model: [
                                {t: "NAME", w: 220}, {t: "PID", w: 80}, {t: "STATUS", w: 160},
                                {t: "CPU", w: 80}, {t: "MEMORY", w: 120}, {t: "DISK", w: 100},
                                {t: "PAGEFILE", w: 100}, {t: "ML PREDICTION", w: 150}
                            ]
                            delegate: Text {
                                text: modelData.t; width: modelData.w
                                color: "#666"; font.bold: true; font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter; height: 40
                            }
                        }
                    }
                }

                ListView {
                    id: processListView
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    model: typeof processModel !== "undefined" ? processModel : 0
                    spacing: 2
                    // Inside ListView { id: processListView ... }
                    ScrollBar.vertical: ScrollBar {
                        id: control
                        width: 12
                        policy: ScrollBar.AsNeeded


                        background: Rectangle {
                            color: "transparent"
                            border.width: 0
                        }

                        contentItem: Rectangle {
                            implicitWidth: 6
                            radius: 3
                            // Make it glow slightly when you hover over the list
                            color: control.pressed ? "#76b9ed" : (control.hovered ? "#555" : "#333")
                            opacity: control.active ? 1.0 : 0.0 // Hide completely when not scrolling

                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            // Ensure it sits in the center of the 12px width
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                    delegate: ItemDelegate {
                        width: processListView.width; height: 45
                        background: Rectangle { color: hovered ? "#2d2d2d" : "#1e1e1e"; radius: 4 }
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20

                            // 1. NAME
                            Text {
                                text: model.name; width: 220; color: "white"
                                font.bold: true; anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                            }

                            // 2. PID
                            Text {
                                text: model.pid; width: 80; color: "#888"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // 3. STATUS (Pill Nuked)
                            Text {
                                text: model.status
                                width: 160 // Matches header width
                                color: model.status === "Foreground" ? "#76b9ed" : "#666"
                                font.pixelSize: 11; font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // 4. CPU
                            Text {
                                text: model.cpu; width: 80; color: "#bb86fc"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // 5. MEMORY (Keep the Heatmap Bar)
                            Rectangle {
                                width: 120; height: 35; color: "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    width: Math.min(parent.width * (model.rawMem / 2048), parent.width)
                                    height: parent.height; color: "#76b9ed"; opacity: 0.15; radius: 4
                                }
                                Text {
                                    text: model.mem; anchors.centerIn: parent
                                    color: "#76b9ed"; font.bold: true
                                }
                            }

                            // 6. DISK
                            Text {
                                text: model.disk; width: 100; color: "#888"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // 7. PAGEFILE
                            Text {
                                text: model.pagefile; width: 100; color: "#888"
                                anchors.verticalCenter: parent.verticalCenter
                            }


                            Text {
                                text: model.prediction === "" ? "WAITING..." : model.prediction
                                width: 150 // Matches header width
                                color: model.prediction === "STABLE" ? "#4caf50" :
                                       model.prediction === "RISK" ? "#f44336" : "#444"
                                font.pixelSize: 11; font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }

                        }
                    }
                }
            }
        }
    }


    component GaugeComponent : Column {
        id: gaugeRoot
        property string label: ""
        property real value: 0
        property color ringColor: "white"
        spacing: 25

        Canvas {
            id: canvas
            width: 350; height: 350
            Connections {
                target: gaugeRoot
                function onValueChanged() { canvas.requestPaint() }
            }
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var centerX = width / 2; var centerY = height / 2;
                var radius = 150; var ringWidth = 24;

                ctx.beginPath();
                ctx.strokeStyle = "#252525"; ctx.lineWidth = ringWidth;
                ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
                ctx.stroke();

                ctx.beginPath();
                ctx.strokeStyle = ringColor; ctx.lineWidth = ringWidth; ctx.lineCap = "round";
                var startAngle = -Math.PI / 2;
                var endAngle = startAngle + (Math.PI * 2 * (Math.min(Math.max(gaugeRoot.value, 0), 100) / 100));
                ctx.arc(centerX, centerY, radius, startAngle, endAngle);
                ctx.stroke();
            }
            Column {
                anchors.centerIn: parent; spacing: 5
                Text {
                    text: Math.round(gaugeRoot.value) + "%"
                    color: "white"; font.pixelSize: 72; font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: label; color: "#888"; font.pixelSize: 16; font.bold: true;
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}

