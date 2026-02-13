import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'balloon_model.dart';
import '../../core/weather_service.dart';
import 'dart:async';

class CreateBalloonSheet extends StatefulWidget {
  final double latitude;
  final double longitude;
  final Function(BalloonModel) onRelease;

  const CreateBalloonSheet({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onRelease,
  });

  @override
  State<CreateBalloonSheet> createState() => _CreateBalloonSheetState();
}

class _CreateBalloonSheetState extends State<CreateBalloonSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isRecording = false;
  String? _recordedFilePath;
  int _recordDuration = 0;
  Timer? _recordTimer;
  bool _isReleasing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _audioRecorder.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (await Permission.microphone.request().isGranted) {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String filePath = '${appDir.path}/${Uuid().v4()}.m4a';

      await _audioRecorder.start(const RecordConfig(), path: filePath);

      setState(() {
        _isRecording = true;
        _recordedFilePath = null;
        _recordDuration = 0;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordDuration++;
        });
        if (_recordDuration >= 15) {
          _stopRecording();
        }
      });
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordedFilePath = path;
    });
  }

  Future<void> _handleRelease() async {
    final bool isText = _tabController.index == 0;
    String content = "";
    BalloonType type;

    if (isText) {
      content = _textController.text.trim();
      type = BalloonType.text;
      if (content.isEmpty) return;
    } else {
      content = _recordedFilePath ?? "";
      type = BalloonType.audio;
      if (content.isEmpty) return;
    }

    setState(() => _isReleasing = true);

    final wind = await WeatherService.getWindAt(widget.latitude, widget.longitude);

    final balloon = BalloonModel(
      id: Uuid().v4(),
      latitude: widget.latitude,
      longitude: widget.longitude,
      content: content,
      type: type,
      timestamp: DateTime.now(),
      windSpeed: wind.windSpeed,
      windDirection: wind.windDirection,
    );

    widget.onRelease(balloon);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '放飞气球',
                style: CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: Icon(CupertinoIcons.xmark_circle_fill, color: CupertinoColors.systemGrey),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CupertinoSlidingSegmentedControl<int>(
            groupValue: _tabController.index,
            children: {
              0: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('文字', style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle),
              ),
              1: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('语音', style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle),
              ),
            },
            onValueChanged: (v) {
              if (v != null) _tabController.animateTo(v);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: TabBarView(
              controller: _tabController,
              children: [
                CupertinoTextField(
                  controller: _textController,
                  maxLines: 4,
                  placeholder: '写下你想说的话...',
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_recordedFilePath != null)
                      Text('已录制', style: TextStyle(color: CupertinoColors.activeGreen, fontSize: 16)),
                    if (_isRecording)
                      Text('录制中 $_recordDuration/15 秒', style: TextStyle(color: CupertinoColors.systemRed, fontSize: 16)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onLongPress: _startRecording,
                      onLongPressUp: _stopRecording,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _isRecording ? CupertinoColors.systemRed : CupertinoColors.activeBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isRecording ? CupertinoIcons.stop_fill : CupertinoIcons.mic_fill,
                          color: CupertinoColors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('长按录音（最多 15 秒）', style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: _isReleasing ? null : _handleRelease,
              child: _isReleasing
                  ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                  : const Text('放飞'),
            ),
          ),
        ],
      ),
    );
  }
}
