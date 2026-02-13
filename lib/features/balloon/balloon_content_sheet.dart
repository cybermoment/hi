import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'balloon_model.dart';
import 'package:intl/intl.dart';

class BalloonContentSheet extends StatefulWidget {
  final BalloonModel balloon;

  const BalloonContentSheet({super.key, required this.balloon});

  @override
  State<BalloonContentSheet> createState() => _BalloonContentSheetState();
}

class _BalloonContentSheetState extends State<BalloonContentSheet> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.balloon.type == BalloonType.audio) {
      _initAudio();
    }
  }

  Future<void> _initAudio() async {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() {
          _duration = d;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) {
        setState(() {
          _position = p;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _toggleAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (widget.balloon.content.startsWith('http')) {
        await _audioPlayer.play(UrlSource(widget.balloon.content));
      } else {
        await _audioPlayer.play(DeviceFileSource(widget.balloon.content));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd('zh_CN').add_jm();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '气球内容',
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
          const SizedBox(height: 8),
          Text(
            '放飞于 ${dateFormat.format(widget.balloon.timestamp)}',
            style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle.copyWith(
                  color: CupertinoColors.systemGrey,
                ),
          ),
          const SizedBox(height: 20),
          if (widget.balloon.type == BalloonType.text)
            Text(
              widget.balloon.content,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontSize: 17),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _toggleAudio,
                    child: Icon(
                      _isPlaying ? CupertinoIcons.pause_circle_fill : CupertinoIcons.play_circle_fill,
                      size: 48,
                      color: CupertinoColors.activeBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CupertinoSlider(
                          value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 15.0),
                          max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 15.0,
                          onChanged: (v) {
                            _audioPlayer.seek(Duration(seconds: v.toInt()));
                          },
                        ),
                        Text(
                          '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                          style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
