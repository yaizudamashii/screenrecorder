import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'dart:ui' as ui show Image, ImageByteFormat;
import 'package:image/image.dart' as image;

class ScreenRecorderController {
  ScreenRecorderController({
    this.pixelRatio = 1,
    this.skipFramesBetweenCaptures = 2,
    SchedulerBinding? binding,
  })  : _containerKey = GlobalKey(),
        _binding = binding ?? SchedulerBinding.instance!;

  final GlobalKey _containerKey;
  final SchedulerBinding _binding;
  final List<Frame> _frames = [];
  Function(ui.Image) onImageAvailable = (image) {};
  Directory? tempDir;

  /// The pixelRatio describes the scale between the logical pixels and the size
  /// of the output image. Specifying 1.0 will give you a 1:1 mapping between
  /// logical pixels and the output pixels in the image. The default is a pixel
  /// ration of 3 and a value below 1 is not recommended.
  ///
  /// See [RenderRepaintBoundary](https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html)
  /// for the underlying implementation.
  final double pixelRatio;

  /// Describes how many frames are skipped between caputerd frames.
  /// For example if it's `skipFramesBetweenCaptures = 2` screen_recorder
  /// captures a frame, skips the next two frames and then captures the next
  /// frame again.
  final int skipFramesBetweenCaptures;

  int skipped = 0;

  bool _record = false;

  void start() {
    // only start a video, if no recording is in progress
    if (_record == true) {
      return;
    }
    _record = true;
    _binding.addPostFrameCallback(postFrameCallback);
  }

  void stop() {
    _record = false;
  }

  void postFrameCallback(Duration timestamp) async {
    if (_record == false) {
      return;
    }
    if (skipped > 0) {
      // count down frames which should be skipped
      skipped = skipped - 1;
      // add a new PostFrameCallback to know about the next frame
      _binding.addPostFrameCallback(postFrameCallback);
      // but we do nothing, because we skip this frame
      return;
    }
    if (skipped == 0) {
      // reset skipped frame counter
      skipped = skipped + skipFramesBetweenCaptures;
    }
    try {
      final image = await capture();
      if (image == null) {
        print('capture returned null');
        return;
      }
      _frames.add(Frame(timestamp, image));
      onImageAvailable(image);
    } catch (e) {
      print(e.toString());
    }
    _binding.addPostFrameCallback(postFrameCallback);
  }

  Future<ui.Image?> capture() async {
    final renderObject = _containerKey.currentContext?.findRenderObject();

    if (renderObject is RenderRepaintBoundary) {
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      return image;
    } else {
      FlutterError.reportError(_noRenderObject());
    }
    return null;
  }

  FlutterErrorDetails _noRenderObject() {
    return FlutterErrorDetails(
      exception: Exception(
        '_containerKey.currentContext is null. '
        'Thus we can\'t create a screenshot',
      ),
      library: 'feedback',
      context: ErrorDescription(
        'Tried to find a context to use it to create a screenshot',
      ),
    );
  }

  Future<List<int>?> export() async {
    List<RawFrame> bytes = [];
    for (final frame in _frames) {
      final i = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (i != null) {
        bytes.add(RawFrame(16 * 10, i)); // to account for image's encodeGIF which divides the frame duration by 10
      } else {
        print('Skipped frame while enconding');
      }
    }
    final result = compute(_export, { 'frames': bytes, 'tempDir': tempDir });
    _frames.clear();
    return result;
  }

  static Future<List<int>?> _export(Map<String, dynamic> map) async {
    List<RawFrame> frames = map['frames'];
    Directory tempDir = map['tempDir'];
    final animation = image.Animation();
    animation.backgroundColor = Colors.transparent.value;
    for (int i=0; i<frames.length; i++) {
      RawFrame frame = frames[i];
      int byteOffset = frame.image.offsetInBytes;
      int byteLength = frame.image.lengthInBytes;
      Uint8List iAsBytes = frame.image.buffer.asUint8List(byteOffset, byteLength);


      final decodedImage = image.decodePng(iAsBytes);
      if (decodedImage != null) {
        decodedImage?.duration = frame.durationInMillis;
        animation.addFrame(decodedImage);
      }

    }
    List<int>? gif = image.encodeGifAnimation(animation, samplingFactor: 100);
    // if (gif != null) {
    //   String path = '${tempDir.path}/test_image.gif';
    //   print(path);
    //   final file = File(path);
    //   file.writeAsBytesSync(gif!);
    // }
    return gif;
  }
}

class ScreenRecorder extends StatelessWidget {
  ScreenRecorder({
    Key? key,
    required this.child,
    required this.controller,
    required this.width,
    required this.height,
    this.background = Colors.white,
  })  : assert(background.alpha == 255,
            'background color is not allowed to be transparent'),
        super(key: key);

  /// The child which should be recorded.
  final Widget child;

  /// This controller starts and stops the recording.
  final ScreenRecorderController controller;

  /// Width of the recording.
  /// This should not change during recording as it could lead to
  /// undefined behavior.
  final double width;

  /// Height of the recording
  /// This should not change during recording as it could lead to
  /// undefined behavior.
  final double height;

  /// The background color of the recording.
  /// Transparency is currently not supported.
  final Color background;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: controller._containerKey,
      child: Container(
        width: width,
        height: height,
        child: child,
      ),
    );
  }
}

class Frame {
  Frame(this.timeStamp, this.image);

  final Duration timeStamp;
  final ui.Image image;
}

class RawFrame {
  RawFrame(this.durationInMillis, this.image);

  final int durationInMillis;
  final ByteData image;
}
