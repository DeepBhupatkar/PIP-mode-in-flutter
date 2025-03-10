import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quick_start/meeting_controls.dart';
import 'package:quick_start/pip_view.dart';
import 'package:videosdk/videosdk.dart';
import './participant_tile.dart';

class MeetingScreen extends StatefulWidget {
  final String meetingId;
  final String token;

  const MeetingScreen(
      {super.key, required this.meetingId, required this.token});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen>
    with WidgetsBindingObserver {
  late Room _room;
  var micEnabled = true;
  var camEnabled = true;
  bool isPiPMode = false;
  final platform = MethodChannel('pip_channel');

  Map<String, Participant> participants = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this); // No need for casting

    // Create room
    _room = VideoSDK.createRoom(
        roomId: "1j2a-uap5-w285",
        token: widget.token,
        displayName: "John Doe",
        micEnabled: micEnabled,
        camEnabled: camEnabled,
        defaultCameraIndex: kIsWeb ? 0 : 1);

    // Set meeting event listener
    setMeetingEventListener();

    // Join room
    _room.join();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      enterPiPMode();
    }
  }

  void setMeetingEventListener() {
    _room.on(Events.roomJoined, () {
      setState(() {
        participants.putIfAbsent(
            _room.localParticipant.id, () => _room.localParticipant);
      });
    });

    _room.on(
      Events.participantJoined,
      (Participant participant) {
        setState(() {
          participants.putIfAbsent(participant.id, () => participant);
          print("Pavan : ${participant}");
        });
        participant.on(Events.streamEnabled, (Stream stream) {
          setState(() {
            print("stream enable: ${stream}");
          });
        });
      },
    );

    _room.on(Events.streamEnabled, (Stream stream) {
      setState(() {
        print("stream enable: $stream");
      });
    });

    _room.on(Events.participantLeft, (String participantId) {
      if (participants.containsKey(participantId)) {
        setState(() {
          participants.remove(participantId);
        });
      }
    });

    _room.on(Events.roomLeft, () {
      participants.clear();
      Navigator.popUntil(context, ModalRoute.withName('/'));
    });
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  Future<bool> _onWillPop() async {
    _room.leave();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onWillPop(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('VideoSDK QuickStart'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              if (!isPiPMode) Text(widget.meetingId),
              Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: isPiPMode
                        ? ParticipantTile(
                            participant: participants.values.first,
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8.0,
                              mainAxisSpacing: 8.0,
                            ),
                            itemCount: participants.length,
                            itemBuilder: (context, index) {
                              return ParticipantTile(
                                participant:
                                    participants.values.elementAt(index),
                              );
                            },
                          )),
              ),
              if (!isPiPMode)
                MeetingControls(
                  onToggleMicButtonPressed: () {
                    micEnabled ? _room.muteMic() : _room.unmuteMic();
                    micEnabled = !micEnabled;
                  },
                  onToggleCameraButtonPressed: () {
                    camEnabled ? _room.disableCam() : _room.enableCam();
                    camEnabled = !camEnabled;
                  },
                  onLeaveButtonPressed: () {
                    _room.leave();
                  },
                  pipButtonPressed: () async {
                    enterPiPMode();
                  },
                  register: () {
                    VideoSDK.applyVideoProcessor(videoProcessorName: "Pavan");
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void enterPiPMode() async {
    try {
      if (Platform.isAndroid) {
        await platform.invokeMethod('enterPiPMode');
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PiPView(room: _room),
            ),
          );
        }
      }
       else if (Platform.isIOS) {
        try {
          await platform.invokeMethod('startPip');
        } on PlatformException catch (e) {
          print("Failed to enter PiP: '${e.message}'.");
        }
      }
    } on PlatformException catch (e) {
      print("Failed to enter PiP mode: ${e.message}");
    }
  }


}
