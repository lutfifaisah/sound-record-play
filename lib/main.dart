import 'dart:math';

import 'package:flutter/material.dart';

import 'dart:async';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';

const bool kIsWeb = identical(0, 0.0);

const theSource = AudioSource.microphone;
enum command { record, stopRecord, play, stopPlay }
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class DataEntries {
  DataEntries(
      {required this.title,
      required this.controller,
      required this.tmlst,
      this.isPlaying = false,
      this.sliderCurrentPosition = 0.0});
  final String title;
  late AnimationController controller;
  double tmlst;
  bool isPlaying;
  double sliderCurrentPosition;
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  List<DataEntries> entries = <DataEntries>[];
  int _counter = 0;
  Codec _codec = Codec.aacMP4;
  String _mPath = '.mp4';
  FlutterSoundPlayer? _mPlayer = FlutterSoundPlayer();
  FlutterSoundRecorder? _mRecorder = FlutterSoundRecorder();
  bool _mPlayerIsInited = false;
  bool _mRecorderIsInited = false;
  bool _mplaybackReady = false;
  bool isOnRecord = false;
  String recordTime = '00:00:00';
  String? tempTosave;
  int indexplaying = 0;

  double tmrec = 0;
  @override
  void initState() {
    _mPlayer!.openAudioSession().then((value) {
      setState(() {
        _mPlayerIsInited = true;
      });
    });

    openTheRecorder().then((value) {
      setState(() {
        _mRecorderIsInited = true;
      });
    });

    super.initState();
  }

  Future<void> openTheRecorder() async {
    if (!kIsWeb) {
      var status = await Permission.microphone.request();
      if (status.isGranted == true) {
        throw RecordingPermissionException('Microphone permission not granted');
      }
    }
    await _mRecorder!.openAudioSession();
    if (!await _mRecorder!.isEncoderSupported(_codec)) {
      _codec = Codec.opusWebM;
      _mPath = '.webm';
      if (!await _mRecorder!.isEncoderSupported(_codec)) {
        _mRecorderIsInited = true;
      }
    }
    _mRecorderIsInited = true;
    await _mRecorder!.setSubscriptionDuration(Duration(milliseconds: 10));
    await _mPlayer!.setSubscriptionDuration(Duration(milliseconds: 10));
    await initializeDateFormatting();
  }

  StreamSubscription? _recorderSubscription;
  void record() async {
    _counter++;
    tempTosave = 'file$_counter$_mPath';
    await _mRecorder!
        .startRecorder(
            toFile: tempTosave,
            codec: _codec,
            audioSource: theSource,
            bitRate: 8000,
            numChannels: 1,
            sampleRate: 8000)
        .then((value) {
      setState(() {
        isOnRecord = true;
      });
    });

    _recorderSubscription = _mRecorder!.onProgress!.listen((e) {
      tmrec = e.duration.inMilliseconds.toDouble();
      var date = DateTime.fromMillisecondsSinceEpoch(e.duration.inMilliseconds,
          isUtc: true);
      var txt = DateFormat('mm:ss:SS', 'en_GB').format(date);

      setState(() {
        recordTime = txt.substring(0, 8);
      });
    });
  }

  void stopRecorder() async {
    await _mRecorder!.stopRecorder().then((value) {
      setState(() {
        //var url = value;
        isOnRecord = false;
        _mplaybackReady = true;
        entries.add(DataEntries(
            title: tempTosave!,
            controller: AnimationController(
                vsync: this,
                duration: Duration(milliseconds: tmrec.toInt())) //TODO
              ..addListener(() {
                setState(() {});
              }),
            tmlst: tmrec)); //TODO
      });
    });
  }

  StreamSubscription? _playerSubscription;
  play(index) async {
    assert(_mPlayerIsInited && _mplaybackReady && _mRecorder!.isStopped);

    indexplaying = index;
    await _mPlayer!
        .startPlayer(
            fromURI: entries.elementAt(index).title,
            //codec: kIsWeb ? Codec.opusWebM : Codec.aacADTS,
            whenFinished: () {
              setState(() {
                entries.elementAt(index).isPlaying = false;
                entries.elementAt(index).sliderCurrentPosition = 0.0;
                _playerSubscription!.cancel();
              });
            })
        .then((value) {
      setState(() {
        entries.elementAt(index).isPlaying = true;
      });
    });

    _playerSubscription = _mPlayer!.onProgress!.listen((e) {
      entries.elementAt(index).sliderCurrentPosition = min(
          e.position.inMilliseconds.toDouble(), entries.elementAt(index).tmlst);
      setState(() {
        if (entries.elementAt(index).sliderCurrentPosition < 0.0) {
          entries.elementAt(index).sliderCurrentPosition = 0.0;
        }
      });
    });
  }

  void pausePlay(index) {
    if (!_mPlayer!.isPlaying) return;
    _mPlayer!.pausePlayer().then((value) {
      entries.elementAt(index).isPlaying = false;
      setState(() {});
    });
  }

  void playResume(index) {
    if (!_mPlayer!.isPaused) return;
    _mPlayer!.resumePlayer().then((value) {
      entries.elementAt(index).isPlaying = true;
      setState(() {});
    });
  }

  void stopPlayer() {
    _mPlayer!.stopPlayer().then((value) {
      setState(() {});
    });
  }

  void resetPlayerWait() async {
    await _mPlayer!.stopPlayer();
    await _playerSubscription!.cancel();
    _playerSubscription = null;
  }

  Future<void> seekToPlayer(int milliSecs) async {
    //playerModule.logger.d('-->seekToPlayer');
    try {
      if (_mPlayer!.isPlaying || _mPlayer!.isPaused) {
        await _mPlayer!.seekToPlayer(Duration(milliseconds: milliSecs));
      }
    } on Exception catch (err) {
      _mPlayer!.logger.e('error: $err');
    }
    setState(() {});
    //playerModule.logger.d('<--seekToPlayer');
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
                child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: entries.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Container(
                        height: 50,
                        color: Colors.white70,
                        child: Center(
                            child: Row(children: [
                          TextButton.icon(
                              icon: Icon(
                                entries[index].isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.blue,
                                size: 24.0,
                                semanticLabel:
                                    'Text to announce in accessibility modes',
                              ),
                              label: Text('Entry ${entries[index].title}'),
                              onPressed: () {
                                if (entries.elementAt(indexplaying).isPlaying) {
                                  if (index == indexplaying) {
                                    entries[index].controller.stop();
                                    pausePlay(index);
                                  } else {
                                    entries
                                        .elementAt(indexplaying)
                                        .sliderCurrentPosition = 0;
                                    entries.elementAt(indexplaying).isPlaying =
                                        false;
                                    resetPlayerWait();
                                    play(index);
                                  }
                                } else {
                                  if (_mPlayer!.isPaused) {
                                    playResume(index);
                                  } else {
                                    entries[index].controller.reset();

                                    play(index);
                                  }

                                  entries[index].controller.forward();
                                }
                              }),
                          Expanded(
                            child: Slider(
                                value: entries
                                    .elementAt(index)
                                    .sliderCurrentPosition,
                                min: 0.0,
                                max: entries[index].tmlst.toDouble(),
                                onChanged: (value) async {
                                  await seekToPlayer(value.toInt());
                                },
                                divisions: entries[index].tmlst.toInt() == 0.0
                                    ? 1
                                    : entries[index].tmlst.toInt()),
                          ),
                        ])),
                      );
                    })),
            const Text(
              'Record Time :',
            ),
            Text(
              recordTime,
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      //floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: isOnRecord ? stopRecorder : record,
        child: isOnRecord
            ? Icon(Icons.stop)
            : Icon(Icons.record_voice_over_outlined),
      ),

      // Padding(
      //   padding: const EdgeInsets.all(8.0),
      //   child: Row(
      //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //     children: <Widget>[
      //       FloatingActionButton(
      //         onPressed: isOnRecord ? stopRecorder : record,
      //         child: isOnRecord
      //             ? Icon(Icons.stop)
      //             : Icon(Icons.record_voice_over_outlined),
      //       ),
      //       FloatingActionButton(
      //         onPressed: play,
      //         child: Icon(Icons.play_arrow),
      //       )
      //     ],
      //   ),
      // )
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
