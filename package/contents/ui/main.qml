/*
    Copyright 2014-2015 Harald Sitter <sitter@kde.org>

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of
    the License or (at your option) version 3 or any later version
    accepted by the membership of KDE e.V. (or its successor approved
    by the membership of KDE e.V.), which shall act as a proxy
    defined in Section 14 of version 3 of the license.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import QtQuick 2.0
import QtQuick.Layouts 1.0

import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.plasmoid 2.0

import org.kde.plasma.private.volume 0.1

import "../code/icon.js" as Icon

Item {
    id: main

    property bool volumeFeedback: Plasmoid.configuration.volumeFeedback
    property int maxVolumePercent: Plasmoid.configuration.maximumVolume
    property int maxVolumeValue: Math.round(maxVolumePercent * PulseAudio.NormalVolume / 100.0)
    property int volumeStep: Math.round(Plasmoid.configuration.volumeStep * PulseAudio.NormalVolume / 100.0)
    property string displayName: i18n("Audio Volume")
    property QtObject draggedStream: null

//    Layout.minimumHeight: units.gridUnit * 12
    Layout.minimumWidth: units.gridUnit * 40
//    Layout.preferredHeight: units.gridUnit * 40
    Layout.preferredWidth: units.gridUnit * 20

    Plasmoid.icon: sinkModel.preferredSink ? Icon.name(sinkModel.preferredSink.volume, sinkModel.preferredSink.muted) : Icon.name(0, true)
    Plasmoid.switchWidth: units.gridUnit * 12
    Plasmoid.switchHeight: units.gridUnit * 12
    Plasmoid.toolTipMainText: {
        var sink = sinkModel.preferredSink;
        if (!sink) {
            return displayName;
        }

        if (sink.muted) {
            return i18n("Audio Muted");
        } else {
            return i18n("Volume at %1%", volumePercent(sink.volume));
        }
    }
    Plasmoid.toolTipSubText: sinkModel.preferredSink ? sinkModel.preferredSink.description : ""

    function boundVolume(volume) {
        return Math.max(PulseAudio.MinimalVolume, Math.min(volume, maxVolumeValue));
    }

    function volumePercent(volume, max) {
        if (!max) {
            max = PulseAudio.NormalVolume;
        }
        return Math.round(volume / max * 100.0);
    }

    function increaseVolume() {
        if (!sinkModel.preferredSink) {
            return;
        }
        var volume = boundVolume(sinkModel.preferredSink.volume + volumeStep);
        var percent = volumePercent(volume, maxVolumeValue);
        sinkModel.preferredSink.muted = percent == 0;
        sinkModel.preferredSink.volume = volume;
        osd.show(percent);
        playFeedback();
    }

    function decreaseVolume() {
        if (!sinkModel.preferredSink) {
            return;
        }
        var volume = boundVolume(sinkModel.preferredSink.volume - volumeStep);
        var percent = volumePercent(volume, maxVolumeValue);
        sinkModel.preferredSink.muted = percent == 0;
        sinkModel.preferredSink.volume = volume;
        osd.show(percent);
        playFeedback();
    }

    function muteVolume() {
        if (!sinkModel.preferredSink) {
            return;
        }
        var toMute = !sinkModel.preferredSink.muted;
        sinkModel.preferredSink.muted = toMute;
        osd.show(toMute ? 0 : volumePercent(sinkModel.preferredSink.volume, maxVolumeValue));
        playFeedback();
    }

    function increaseMicrophoneVolume() {
        if (!sourceModel.defaultSource) {
            return;
        }
        var volume = boundVolume(sourceModel.defaultSource.volume + volumeStep);
        var percent = volumePercent(volume);
        sourceModel.defaultSource.muted = percent == 0;
        sourceModel.defaultSource.volume = volume;
        osd.showMicrophone(percent);
    }

    function decreaseMicrophoneVolume() {
        if (!sourceModel.defaultSource) {
            return;
        }
        var volume = boundVolume(sourceModel.defaultSource.volume - volumeStep);
        var percent = volumePercent(volume);
        sourceModel.defaultSource.muted = percent == 0;
        sourceModel.defaultSource.volume = volume;
        osd.showMicrophone(percent);
    }

    function muteMicrophone() {
        if (!sourceModel.defaultSource) {
            return;
        }
        var toMute = !sourceModel.defaultSource.muted;
        sourceModel.defaultSource.muted = toMute;
        osd.showMicrophone(toMute? 0 : volumePercent(sourceModel.defaultSource.volume));
    }

    function beginMoveStream(type, stream) {
        if (type == "sink") {
            sourceView.visible = false;
            sourceViewHeader.visible = false;
        } else if (type == "source") {
            sinkView.visible = false;
            sinkViewHeader.visible = false;
        }

//        tabBar.currentTab = devicesTab;
    }

    function endMoveStream() {
//        tabBar.currentTab = streamsTab;

        sourceView.visible = true;
        sourceViewHeader.visible = true;
        sinkView.visible = true;
        sinkViewHeader.visible = true;
    }

    function playFeedback(sinkIndex) {
        if (!volumeFeedback) {
            return;
        }
        if (sinkIndex == undefined) {
            sinkIndex = sinkModel.preferredSink.index;
        }
        feedback.play(sinkIndex);
    }

    Plasmoid.compactRepresentation: PlasmaCore.IconItem {
        source: plasmoid.icon
        active: mouseArea.containsMouse
        colorGroup: PlasmaCore.ColorScope.colorGroup

        MouseArea {
            id: mouseArea

            property int wheelDelta: 0
            property bool wasExpanded: false

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onPressed: {
                if (mouse.button == Qt.LeftButton) {
                    wasExpanded = plasmoid.expanded;
                } else if (mouse.button == Qt.MiddleButton) {
                    muteVolume();
                }
            }
            onClicked: {
                if (mouse.button == Qt.LeftButton) {
                    plasmoid.expanded = !wasExpanded;
                }
            }
            onWheel: {
                var delta = wheel.angleDelta.y || wheel.angleDelta.x;
                wheelDelta += delta;
                // Magic number 120 for common "one click"
                // See: http://qt-project.org/doc/qt-5/qml-qtquick-wheelevent.html#angleDelta-prop
                while (wheelDelta >= 120) {
                    wheelDelta -= 120;
                    increaseVolume();
                }
                while (wheelDelta <= -120) {
                    wheelDelta += 120;
                    decreaseVolume();
                }
            }
        }
    }

    GlobalActionCollection {
        // KGlobalAccel cannot transition from kmix to something else, so if
        // the user had a custom shortcut set for kmix those would get lost.
        // To avoid this we hijack kmix name and actions. Entirely mental but
        // best we can do to not cause annoyance for the user.
        // The display name actually is updated to whatever registered last
        // though, so as far as user visible strings go we should be fine.
        // As of 2015-07-21:
        //   componentName: kmix
        //   actions: increase_volume, decrease_volume, mute
        name: "kmix"
        displayName: main.displayName
        GlobalAction {
            objectName: "increase_volume"
            text: i18n("Increase Volume")
            shortcut: Qt.Key_VolumeUp
            onTriggered: increaseVolume()
        }
        GlobalAction {
            objectName: "decrease_volume"
            text: i18n("Decrease Volume")
            shortcut: Qt.Key_VolumeDown
            onTriggered: decreaseVolume()
        }
        GlobalAction {
            objectName: "mute"
            text: i18n("Mute")
            shortcut: Qt.Key_VolumeMute
            onTriggered: muteVolume()
        }
        GlobalAction {
            objectName: "increase_microphone_volume"
            text: i18n("Increase Microphone Volume")
            shortcut: Qt.Key_MicVolumeUp
            onTriggered: increaseMicrophoneVolume()
        }
        GlobalAction {
            objectName: "decrease_microphone_volume"
            text: i18n("Decrease Microphone Volume")
            shortcut: Qt.Key_MicVolumeDown
            onTriggered: decreaseMicrophoneVolume()
        }
        GlobalAction {
            objectName: "mic_mute"
            text: i18n("Mute Microphone")
            shortcut: Qt.Key_MicMute
            onTriggered: muteMicrophone()
        }
    }

    VolumeOSD {
        id: osd
    }

    VolumeFeedback {
        id: feedback
    }

//    PlasmaComponents.ToolButton {
//        Layout.alignment: Qt.AlignBottom
//        tooltip: plasmoid.action("configure").text
//        iconName: "configure"
//        Accessible.name: tooltip
//        onClicked: {
//            plasmoid.action("configure").trigger();
//        }
//    }

    PlasmaExtras.ScrollArea {
        id: scrollView;

        anchors {
            top: parent.top
            topMargin: units.smallSpacing
            left: parent.left
            right: parent.right
            bottom: mediaController.top
        }

        horizontalScrollBarPolicy: Qt.ScrollBarAlwaysOff
        flickableItem.boundsBehavior: Flickable.StopAtBounds;

        ColumnLayout {
            width: streamsView.visible ? streamsView.width : devicesView.width
//            height: streamsView.visible ? streamsView.height : devicesView.height

            ColumnLayout {
                id: streamsView
//                visible: tabBar.currentTab == streamsTab
                property int maximumWidth: scrollView.width - 8
                width: maximumWidth
                Layout.maximumWidth: maximumWidth

                Header {
                    Layout.fillWidth: true
                    visible: sinkInputView.count > 0
                    text: i18n("Playback Streams")
                }
                ListView {
                    id: sinkInputView

                    Layout.fillWidth: true
                    Layout.minimumHeight: contentHeight
                    Layout.maximumHeight: contentHeight

                    model: PulseObjectFilterModel {
                        filters: [ { role: "VirtualStream", value: false } ]
                        sourceModel: SinkInputModel {}
                    }
                    boundsBehavior: Flickable.StopAtBounds;
                    delegate: StreamListItem {
                        type: "sink-input"
                        draggable: sinkView.count > 1
                    }
                }

                Header {
                    Layout.fillWidth: true
                    visible: sourceOutputView.count > 0
                    text: i18n("Capture Streams")
                }
                ListView {
                    id: sourceOutputView

                    Layout.fillWidth: true
                    Layout.minimumHeight: contentHeight
                    Layout.maximumHeight: contentHeight

                    model: PulseObjectFilterModel {
                        filters: [ { role: "VirtualStream", value: false } ]
                        sourceModel: SourceOutputModel {}
                    }
                    boundsBehavior: Flickable.StopAtBounds;
                    delegate: StreamListItem {
                        type: "source-input"
                        draggable: sourceView.count > 1
                    }
                }
            }

            ColumnLayout {
                id: devicesView
//                visible: tabBar.currentTab == devicesTab
                property int maximumWidth: scrollView.viewport.width
                width: maximumWidth
                Layout.maximumWidth: maximumWidth

                Header {
                    id: sinkViewHeader
                    Layout.fillWidth: true
                    visible: sinkView.count > 0
                    text: i18n("Playback Devices")
                }
                ListView {
                    id: sinkView

                    Layout.fillWidth: true
                    Layout.minimumHeight: contentHeight
                    Layout.maximumHeight: contentHeight

                    model: PulseObjectFilterModel {
                        sortRole: "SortByDefault"
                        sortOrder: Qt.DescendingOrder
                        sourceModel: SinkModel {
                            id: sinkModel
                        }
                    }
                    boundsBehavior: Flickable.StopAtBounds;
                    delegate: DeviceListItem {
                        type: "sink"
                    }
                }

                Header {
                    id: sourceViewHeader
                    Layout.fillWidth: true
                    visible: sourceView.count > 0
                    text: i18n("Capture Devices")
                }
                ListView {
                    id: sourceView

                    Layout.fillWidth: true
                    Layout.minimumHeight: contentHeight
                    Layout.maximumHeight: contentHeight

                    model: PulseObjectFilterModel {
                        sortRole: "SortByDefault"
                        sortOrder: Qt.DescendingOrder
                        sourceModel: SourceModel {
                            id: sourceModel
                        }
                    }
                    boundsBehavior: Flickable.StopAtBounds;
                    delegate: DeviceListItem {
                        type: "source"
                    }
                }
            }

//            PlasmaExtras.Heading {
//                level: 4
//                opacity: 0.8
//                width: parent.width
//                height: scrollView.height
//                visible: streamsView.visible && !sinkInputView.count && !sourceOutputView.count
//                text: i18n("No applications playing or recording audio")
//                wrapMode: Text.WordWrap
//                verticalAlignment: Text.AlignVCenter
//                horizontalAlignment: Text.AlignHCenter
//            }

            PlasmaExtras.Heading {
                level: 4
                opacity: 0.8
                width: parent.width
                height: scrollView.height
                visible: devicesView.visible && !sinkView.count && !sourceView.count
                text: i18n("No output or input devices found")
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    MediaControler {
        id : mediaController

        height: 180
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            bottomMargin: 12
        }
    }
}
