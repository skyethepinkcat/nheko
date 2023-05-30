// SPDX-FileCopyrightText: Nheko Contributors
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Qt.labs.platform 1.1 as Platform
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.2
import QtQuick.Window 2.15
import im.nheko 1.0

import "./delegates"

Pane {
    id: topBar

    property bool showBackButton: false
    property string roomName: room ? room.roomName : qsTr("No room selected")
    property string roomId: room ? room.roomId : ""
    property string avatarUrl: room ? room.roomAvatarUrl : ""
    property string roomTopic: room ? room.roomTopic : ""
    property bool isEncrypted: room ? room.isEncrypted : false
    property int trustlevel: room ? room.trustlevel : Crypto.Unverified
    property bool isDirect: room ? room.isDirect : false
    property string directChatOtherUserId: room ? room.directChatOtherUserId : ""

    property bool searchHasFocus: searchField.focus && searchField.enabled

    property string searchString: ""

    // HACK: https://bugreports.qt.io/browse/QTBUG-83972, qtwayland cannot auto hide menu
    Connections {
        function onHideMenu() {
            roomOptionsMenu.close()
        }
        target: MainWindow
    }

    onRoomIdChanged: {
        searchString = "";
        searchButton.searchActive = false;
        searchField.text = ""
    }

    Shortcut {
        sequence: StandardKey.Find
        onActivated: searchButton.searchActive = !searchButton.searchActive
    }

    Layout.fillWidth: true
    implicitHeight: topLayout.height + Nheko.paddingMedium * 2
    z: 3

    padding: 0
    background: Rectangle {
        color: Nheko.colors.window
    }

    TapHandler {
        onSingleTapped: {
            if (eventPoint.position.y > topBar.height - (pinnedMessages.visible ? pinnedMessages.height : 0) - (widgets.visible ? widgets.height : 0)) {
                eventPoint.accepted = true
                return;
            }
            if (showBackButton && eventPoint.position.x < Nheko.paddingMedium + backToRoomsButton.width) {
                eventPoint.accepted = true
                return;
            }
            if (eventPoint.position.x > topBar.width - Nheko.paddingMedium - roomOptionsButton.width) {
                eventPoint.accepted = true
                return;
            }

            if (communityLabel.visible && eventPoint.position.y < communityAvatar.height + Nheko.paddingMedium + Nheko.paddingSmall/2) {
                if (!Communities.trySwitchToSpace(room.parentSpace.roomid))
                    room.parentSpace.promptJoin();
                eventPoint.accepted = true
                return;
            }

            if (room) {
                let p = topBar.mapToItem(roomTopicC, eventPoint.position.x, eventPoint.position.y);
                let link = roomTopicC.linkAt(p.x, p.y);

                if (link) {
                    Nheko.openLink(link);
                } else {
                    TimelineManager.openRoomSettings(room.roomId);
                }
            }

            eventPoint.accepted = true;
        }
        gesturePolicy: TapHandler.ReleaseWithinBounds
    }

    HoverHandler {
        grabPermissions: PointerHandler.TakeOverForbidden | PointerHandler.CanTakeOverFromAnything
    }

    contentItem: Item {
        GridLayout {
            id: topLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Nheko.paddingMedium
            anchors.verticalCenter: parent.verticalCenter
            columnSpacing: Nheko.paddingSmall
            rowSpacing: Nheko.paddingSmall


            Avatar {
                id: communityAvatar

                visible: roomid && room.parentSpace.isLoaded && ("space:"+room.parentSpace.roomid != Communities.currentTagId)

                property string avatarUrl: (Settings.groupView && room && room.parentSpace && room.parentSpace.roomAvatarUrl) || ""
                property string communityId: (Settings.groupView && room && room.parentSpace && room.parentSpace.roomid) || ""
                property string communityName: (Settings.groupView && room && room.parentSpace && room.parentSpace.roomName) || ""

                Layout.column: 1
                Layout.row: 0
                Layout.alignment: Qt.AlignRight
                width: fontMetrics.lineSpacing
                height: fontMetrics.lineSpacing
                url: avatarUrl.replace("mxc://", "image://MxcImage/")
                roomid: communityId
                displayName: communityName
                enabled: false
            }

            Label {
                id: communityLabel
                visible: communityAvatar.visible

                Layout.column: 2
                Layout.row: 0
                Layout.fillWidth: true
                color: Nheko.colors.text
                text: qsTr("In %1").arg(communityAvatar.displayName)
                maximumLineCount: 1
                elide: Text.ElideRight
                textFormat: Text.RichText
            }

            ImageButton {
                id: backToRoomsButton

                Layout.column: 0
                Layout.row: 1
                Layout.rowSpan: 2
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: Nheko.avatarSize - Nheko.paddingMedium
                Layout.preferredWidth: Nheko.avatarSize - Nheko.paddingMedium
                visible: showBackButton
                image: ":/icons/icons/ui/angle-arrow-left.svg"
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Back to room list")
                onClicked: Rooms.resetCurrentRoom()
            }

            Avatar {
                Layout.column: 1
                Layout.row: 1
                Layout.rowSpan: 2
                Layout.alignment: Qt.AlignVCenter
                width: Nheko.avatarSize
                height: Nheko.avatarSize
                url: avatarUrl.replace("mxc://", "image://MxcImage/")
                roomid: roomId
                userid: isDirect ? directChatOtherUserId : ""
                displayName: roomName
                enabled: false
            }

            Label {
                Layout.fillWidth: true
                Layout.column: 2
                Layout.row: 1
                color: Nheko.colors.text
                font.pointSize: fontMetrics.font.pointSize * 1.1
                font.bold: true
                text: roomName
                maximumLineCount: 1
                elide: Text.ElideRight
                textFormat: Text.RichText
            }

            MatrixText {
                id: roomTopicC
                Layout.fillWidth: true
                Layout.column: 2
                Layout.row: 2
                Layout.maximumHeight: fontMetrics.lineSpacing * 2 // show 2 lines
                selectByMouse: false
                enabled: false
                clip: true
                text: roomTopic
            }

            ImageButton {
                id: pinButton

                property bool pinsShown: !Settings.hiddenPins.includes(roomId)

                visible: !!room && room.pinnedMessages.length > 0
                Layout.column: 3
                Layout.row: 1
                Layout.rowSpan: 2
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: Nheko.avatarSize - Nheko.paddingMedium
                Layout.preferredWidth: Nheko.avatarSize - Nheko.paddingMedium
                image: pinsShown ? ":/icons/icons/ui/pin.svg" : ":/icons/icons/ui/pin-off.svg"
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Show or hide pinned messages")
                onClicked: {
                    var ps = Settings.hiddenPins;
                    if (pinsShown) {
                        ps.push(roomId);
                    } else {
                        const index = ps.indexOf(roomId);
                        if (index > -1) {
                            ps.splice(index, 1);
                        }
                    }
                    Settings.hiddenPins = ps;
                }

            }

            AbstractButton {
                Layout.column: 4
                Layout.row: 1
                Layout.rowSpan: 2
                Layout.preferredHeight: Nheko.avatarSize - Nheko.paddingMedium
                Layout.preferredWidth: Nheko.avatarSize - Nheko.paddingMedium

                contentItem: EncryptionIndicator {
                    encrypted: isEncrypted
                    trust: trustlevel
                    enabled: false
                    unencryptedIcon: ":/icons/icons/ui/people.svg"
                    unencryptedColor: Nheko.colors.buttonText
                    unencryptedHoverColor: Nheko.colors.highlight
                    hovered: parent.hovered

                    ToolTip.delay: Nheko.tooltipDelay
                    ToolTip.text: {
                        if (!isEncrypted)
                        return qsTr("Show room members.");

                        switch (trustlevel) {
                            case Crypto.Verified:
                            return qsTr("This room contains only verified devices.");
                            case Crypto.TOFU:
                            return qsTr("This room contains verified devices and devices which have never changed their master key.");
                            default:
                            return qsTr("This room contains unverified devices!");
                        }
                    }
                }

                background: null
                onClicked: TimelineManager.openRoomMembers(room)
            }

            ImageButton {
                id: searchButton

                property bool searchActive: false

                visible: !!room
                Layout.column: 5
                Layout.row: 1
                Layout.rowSpan: 2
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: Nheko.avatarSize - Nheko.paddingMedium
                Layout.preferredWidth: Nheko.avatarSize - Nheko.paddingMedium
                image: ":/icons/icons/ui/search.svg"
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Search this room")
                onClicked: searchActive = !searchActive

                onSearchActiveChanged: {
                    if (searchActive) {
                        searchField.forceActiveFocus();
                    }
                    else {
                        searchField.clear();
                        topBar.searchString = "";
                    }
                }
            }

            ImageButton {
                id: roomOptionsButton

                visible: !!room
                Layout.column: 6
                Layout.row: 1
                Layout.rowSpan: 2
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: Nheko.avatarSize - Nheko.paddingMedium
                Layout.preferredWidth: Nheko.avatarSize - Nheko.paddingMedium
                image: ":/icons/icons/ui/options.svg"
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Room options")
                onClicked: roomOptionsMenu.open(roomOptionsButton)

                Platform.Menu {
                    id: roomOptionsMenu

                    Platform.MenuItem {
                        visible: room ? room.permissions.canInvite() : false
                        text: qsTr("Invite users")
                        onTriggered: TimelineManager.openInviteUsers(roomId)
                    }

                    Platform.MenuItem {
                        text: qsTr("Members")
                        onTriggered: TimelineManager.openRoomMembers(room)
                    }

                    Platform.MenuItem {
                        text: qsTr("Leave room")
                        onTriggered: TimelineManager.openLeaveRoomDialog(roomId)
                    }

                    Platform.MenuItem {
                        text: qsTr("Settings")
                        onTriggered: TimelineManager.openRoomSettings(roomId)
                    }

                }

            }

            ScrollView {
                id: pinnedMessages

                Layout.row: 3
                Layout.column: 2
                Layout.columnSpan: 4

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, Nheko.avatarSize * 4)

                visible: !!room && room.pinnedMessages.length > 0 && !Settings.hiddenPins.includes(roomId)
                clip: true

                palette: Nheko.colors
                ScrollBar.horizontal.visible: false

                ListView {

                    spacing: Nheko.paddingSmall
                    model: room ? room.pinnedMessages : undefined
                    delegate: RowLayout {
                        required property string modelData

                        width: ListView.view.width
                        height: implicitHeight

                        Reply {
                            id: reply
                            property var e: room ? room.getDump(modelData, "pins") : {}
                            Connections {
                                function onPinnedMessagesChanged() { reply.e = room.getDump(modelData, "pins") }
                                target: room
                            }
                            Layout.fillWidth: true
                            Layout.preferredHeight: height

                            userColor: TimelineManager.userColor(e.userId, Nheko.colors.window)
                            blurhash: e.blurhash ?? ""
                            body: e.body ?? ""
                            formattedBody: e.formattedBody ?? ""
                            eventId: e.eventId ?? ""
                            filename: e.filename ?? ""
                            filesize: e.filesize ?? ""
                            proportionalHeight: e.proportionalHeight ?? 1
                            type: e.type ?? MtxEvent.UnknownMessage
                            typeString: e.typeString ?? ""
                            url: e.url ?? ""
                            originalWidth: e.originalWidth ?? 0
                            isOnlyEmoji: e.isOnlyEmoji ?? false
                            userId: e.userId ?? ""
                            userName: e.userName ?? ""
                            encryptionError: e.encryptionError ?? ""
                            keepFullText: true
                        }

                        ImageButton {
                            id: deletePinButton

                            Layout.preferredHeight: 16
                            Layout.preferredWidth: 16
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                            visible: room.permissions.canChange(MtxEvent.PinnedEvents)

                            hoverEnabled: true
                            image: ":/icons/icons/ui/dismiss.svg"
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Unpin")

                            onClicked: room.unpin(modelData)
                        }
                    }


                    ScrollHelper {
                        flickable: parent
                        anchors.fill: parent
                        enabled: !Settings.mobileMode
                    }
                }
            }

            ScrollView {
                id: widgets

                Layout.row: 4
                Layout.column: 2
                Layout.columnSpan: 4

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, Nheko.avatarSize * 1.5)

                visible: !!room && room.widgetLinks.length > 0 && !Settings.hiddenWidgets.includes(roomId)
                clip: true

                palette: Nheko.colors
                ScrollBar.horizontal.visible: false

                ListView {

                    spacing: Nheko.paddingSmall
                    model: room ? room.widgetLinks : undefined
                    delegate: MatrixText {
                        required property var modelData

                        color: Nheko.colors.text
                        text: modelData
                    }


                    ScrollHelper {
                        flickable: parent
                        anchors.fill: parent
                        enabled: !Settings.mobileMode
                    }
                }
            }

            MatrixTextField {
                id: searchField
                visible: searchButton.searchActive
                enabled: visible
                hasClear: true

                Layout.row: 5
                Layout.column: 2
                Layout.columnSpan: 4

                Layout.fillWidth: true

                placeholderText: qsTr("Enter search query")
                onAccepted: topBar.searchString = text
            }
        }

        CursorShape {
            anchors.fill: parent
            anchors.bottomMargin: (pinnedMessages.visible ? pinnedMessages.height : 0) + (widgets.visible ? widgets.height : 0)
            cursorShape: Qt.PointingHandCursor
        }
    }
}
