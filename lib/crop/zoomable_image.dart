import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';


class Crop extends StatefulWidget {
  final ImageProvider image;
  final double maxScale;
  final double minScale;
  final GestureTapCallback onTap;
  final Color backgroundColor;
  final Widget placeholder;
  final bool debug;

  Crop(
      this.image, {
        Key key,
        @deprecated double scale,

        /// Maximum ratio to blow up image pixels. A value of 2.0 means that the
        /// a single device pixel will be rendered as up to 4 logical pixels.
        this.maxScale = 2.0,
        this.minScale = 0.0,
        this.onTap,
        this.backgroundColor = Colors.black,

        /// Placeholder widget to be used while [image] is being resolved.
        this.placeholder,

        this.debug,
      }) : super(key: key);

  @override
  CropState createState() => new CropState();
}

// See /flutter/examples/layers/widgets/gestures.dart
class CropState extends State<Crop> {
  ImageStream _imageStream;
  ui.Image _image;
  Size _imageSize;

  Offset _startingFocalPoint;

  Offset _previousOffset;
  Offset _offset; // where the top left corner of the image is drawn

  double _previousScale;
  double _scale; // multiplier applied to scale the full image

  Orientation _previousOrientation;

  Size _canvasSize;
  Size _viewSize;
  double _minScale;
  double _maxScale;
  bool _dragging = false;

  Rect _cropArea = Rect.fromLTRB(0, 0, 0, 0);

  Rect getClampedCropArea(Rect _cropArea) {
    Rect validArea = validOffset;
    double left = _cropArea.left.clamp(validArea.left, double.infinity);
    double top = _cropArea.top.clamp(validArea.top, double.infinity);
    double right = _cropArea.right.clamp(double.negativeInfinity, validArea.right);
    double bottom = _cropArea.bottom.clamp(double.negativeInfinity, validArea.bottom);
    Rect adjusted = Rect.fromLTRB(left, top, right, bottom);
    return adjusted;
  }

  @override
  void initState() {
    super.initState();
    _minScale = widget.minScale;
    _maxScale = widget.maxScale;
  }

  void _centerAndScaleImage() {
    _imageSize = new Size(
      _image.width.toDouble(),
      _image.height.toDouble(),
    );

    _scale = math.min(
      _canvasSize.width / _imageSize.width,
      _canvasSize.height / _imageSize.height,
    );
    Size fitted = new Size(
      _imageSize.width * _scale,
      _imageSize.height * _scale,
    );

    Offset delta = _canvasSize - fitted;
    _offset = delta / 2.0; // Centers the image

    print(_scale);
  }

  // ignore: unused_element
  Function() _handleDoubleTap(BuildContext ctx) {
    // TODO we will make a better handler later
    return () {

    };
  }

  void _handleScaleStart(ScaleStartDetails d) {
//    print("starting scale at ${d.focalPoint} from $_offset $_scale");
    _startingFocalPoint = d.focalPoint;
    _previousOffset = _offset;
    _previousScale = _scale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails d) {
    double newScale = _previousScale * d.scale;
    if (newScale > _maxScale) {
      newScale = _maxScale;
    }
    if (newScale < _minScale) {
      newScale = _minScale;
    }

    // Ensure that item under the focal point stays in the same place despite zooming
    final Offset normalizedOffset =
        (_startingFocalPoint - _previousOffset) / _previousScale;
    Offset newOffset = d.focalPoint - normalizedOffset * newScale;
    double minX = _viewSize.width - _image.width * _scale;
    double minY = _viewSize.height - _image.height * _scale;
    double maxX = 0;
    double maxY = 0;
    if (0 < minX) {
      maxX = minX = minX / 2;
    }
    if (0 < minY) {
      maxY = minY = minY / 2;
    }
    double clampedX = newOffset.dx.clamp(minX, maxX);
    double clampedY = newOffset.dy.clamp(minY, maxY);
    newOffset = Offset(clampedX, clampedY);

    // make sure the crop area is within the bounds
    setState(() {
      _scale = newScale;
      _offset = newOffset;
      _cropArea = getClampedCropArea(_cropArea);
    });
  }

  void _handleScaleEnd(ScaleEndDetails details) {
  }

  void _handleDragStart([_]) {
    setState(() {
      _dragging = true;
    });
  }

  void _handleDragEnd([_]) {
    setState(() {
      _dragging = false;
    });
  }

  @override
  Widget build(BuildContext ctx) {
    if (_image != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          afterImageReady(context));
    }
    Widget paintWidget() {
      String debugString = '';
      if (widget.debug) {
        debugString = 'Crop area = $_cropArea\n'
            'Crop Rect = $cropRect\n'
            'Offset = $_offset\n'
            'Scale = $_scale\n'
            'Dragging = $_dragging';
      }
      return new CustomPaint(
        child: new Container(color: widget.backgroundColor),
        foregroundPainter: new _ZoomableImagePainter(
          image: _image,
          offset: _offset,
          scale: _scale,
          debugString: debugString,
        ),
      );
    }

    if (_image == null) {
      return widget.placeholder ?? Center(child: CircularProgressIndicator());
    }

    return new LayoutBuilder(builder: (ctx, constraints) {
      Orientation orientation = MediaQuery.of(ctx).orientation;
      if (orientation != _previousOrientation) {
        _previousOrientation = orientation;
        _canvasSize = constraints.biggest;
        _centerAndScaleImage();
      }

      return Stack(
        children: <Widget>[
          new GestureDetector(
            child: paintWidget(),
            onTap: widget.onTap,
//          onDoubleTap: _handleDoubleTap(ctx),
            onScaleStart: _handleScaleStart,
            onScaleUpdate: _handleScaleUpdate,
            onScaleEnd: _handleScaleEnd,
          ),
          Positioned( // horizontal grid block
            left: _cropArea.width / 3 + _cropArea.left,
            top: _cropArea.top,
            child: Container(
              height: _cropArea.height,
              width: _cropArea.width / 3,
              decoration: _dragging ? BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: Colors.white70,
                    width: 1,
                  ),
                  right: BorderSide(
                    color: Colors.white70,
                    width: 1,
                  ),
                ),
              ) : null,
            ),
          ),
          Positioned( // horizontal grid block
            top: _cropArea.height / 3 +_cropArea.top,
            left: _cropArea.left,
            child: Container(
              height: _cropArea.height / 3,
              width: _cropArea.width,
              decoration: _dragging ? BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white70,
                    width: 1,
                  ),
                  bottom: BorderSide(
                    color: Colors.white70,
                    width: 1,
                  ),
                ),
              ) : null,
            ),
          ),
          Positioned( // top block
            left: 0,
            top: 0,
            right: 0,
            child: Container(
              height: _cropArea?.top ?? 0,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
              ),
            ),
          ),
          Positioned( // left block
            left: 0,
            top: topMargin,
            child: Container(
              height: _cropArea?.height ?? 0,
              width: leftMargin,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
              ),
            ),
          ),
          Positioned( // right block
            right: 0,
            top: topMargin,
            child: Container(
              height: _cropArea?.height ?? 0,
              width: rightMargin,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
              ),
            ),
          ),
          Positioned( // bottom block
            left: 0,
            bottom: 0,
            right: 0,
            child: Container(
              height: bottomMargin,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
              ),
            ),
          ),
          Positioned( // top bar
            left: leftMargin,
            right: rightMargin,
            top: (topMargin - 16).clamp(0.0, double.infinity),
            child: GestureDetector(
              onVerticalDragUpdate: (DragUpdateDetails details) {
                double dy = details.delta.dy;
                double top = (_cropArea.top + dy).clamp(16.0, _cropArea.bottom - 40);
                setState(() {
                  _cropArea = getClampedCropArea(Rect.fromLTRB(_cropArea.left, top, _cropArea.right, _cropArea.bottom));
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    height: 16,
                    width: _cropArea?.width ?? 0,
                    color: Colors.transparent,
                  ),
                  Container(
                    height: 3,
                    width: _cropArea?.width ?? 0,
                    color: Colors.white70,
                  ),
                  Container(
                    height: 16,
                    width: _cropArea?.width ?? 0,
                    color: Colors.transparent,
                  ),
                ],
              ),
              onVerticalDragStart: _handleDragStart,
              onVerticalDragCancel: _handleDragEnd,
              onVerticalDragEnd: _handleDragEnd,
            ),
          ),
          Positioned( // bottom bar
            left: leftMargin,
            right: rightMargin,
            bottom: (bottomMargin - 16).clamp(0.0, double.infinity),
            child: GestureDetector(
              onVerticalDragUpdate: (DragUpdateDetails details) {
                double dy = details.delta.dy;
                double bottom = (_cropArea.bottom + dy).clamp(_cropArea.top + 40.0, _viewSize.height - 16);
                setState(() {
                  _cropArea = getClampedCropArea(Rect.fromLTRB(_cropArea.left, _cropArea.top, _cropArea.right, bottom));
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    height: 16,
                    width: _cropArea?.width ?? 0,
                    color: Colors.transparent,
                  ),
                  Container(
                    height: 3,
                    width: _cropArea?.width ?? 0,
                    color: Colors.white70,
                  ),
                  Container(
                    height: 16,
                    width: _cropArea?.width ?? 0,
                    color: Colors.transparent,
                  ),
                ],
              ),
              onVerticalDragStart: _handleDragStart,
              onVerticalDragCancel: _handleDragEnd,
              onVerticalDragEnd: _handleDragEnd,
            ),
          ),
          Positioned( // left bar
            left: (leftMargin - 16).clamp(0.0, double.infinity),
            top: topMargin,
            bottom: bottomMargin,
            child: GestureDetector(
              onHorizontalDragUpdate: (DragUpdateDetails details) {
                double dx = details.delta.dx;
                double left = (_cropArea.left + dx).clamp(16.0, _cropArea.right - 40);
                setState(() {
                  _cropArea = getClampedCropArea(Rect.fromLTRB(left, _cropArea.top, _cropArea.right, _cropArea.bottom));
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    height: _cropArea?.height ?? 0,
                    width: 16,
                    color: Colors.transparent,
                  ),
                  Container(
                    height: _cropArea?.height ?? 0,
                    width: 3,
                    color: Colors.white70,
                  ),
                  Container(
                    height: _cropArea?.height ?? 0,
                    width: 16,
                    color: Colors.transparent,
                  ),
                ],
              ),
              onHorizontalDragStart: _handleDragStart,
              onHorizontalDragCancel: _handleDragEnd,
              onHorizontalDragEnd: _handleDragEnd,
            ),
          ),
          Positioned( // right bar
            right: (rightMargin - 16).clamp(0.0, double.infinity),
            top: topMargin,
            bottom: bottomMargin,
            child: GestureDetector(
              onHorizontalDragUpdate: (DragUpdateDetails details) {
                double dx = details.delta.dx;
                double right = (_cropArea.right + dx).clamp(_cropArea.left + 40, _viewSize.width - 16);
                setState(() {
                  _cropArea = getClampedCropArea(Rect.fromLTRB(_cropArea.left, _cropArea.top, right, _cropArea.bottom));
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    height: _cropArea?.height ?? 0,
                    width: 16,
                    color: Colors.transparent,
                  ),
                  Container(
                    height: _cropArea?.height ?? 0,
                    width: 3,
                    color: Colors.white70,
                  ),
                  Container(
                    height: _cropArea?.height ?? 0,
                    width: 16,
                    color: Colors.transparent,
                  ),
                ],
              ),
              onHorizontalDragStart: _handleDragStart,
              onHorizontalDragCancel: _handleDragEnd,
              onHorizontalDragEnd: _handleDragEnd,
            ),
          ),
          Positioned( // top-left piece
            left: _cropArea.left - 1,
            top: _cropArea.top - 1,
            child: Listener(
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
                  child: Container(
                    height: 16,
                    width: 16,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border(
                        top: BorderSide(color: Colors.white, width: 5),
                        left: BorderSide(color: Colors.white, width: 5),
                      ),
                    ),
                  ),
                ),
              ),
              onPointerDown: _handleDragStart,
              onPointerCancel: _handleDragEnd,
              onPointerUp: _handleDragEnd,
              onPointerMove: (PointerMoveEvent details) {
                double dx = details.delta.dx;
                double left = (_cropArea.left + dx).clamp(16.0, _cropArea.right - 40);
                double dy = details.delta.dy;
                double top = (_cropArea.top + dy).clamp(16.0, _cropArea.bottom - 40);
                setState(() {
                  _cropArea = getClampedCropArea(Rect.fromLTRB(left, top, _cropArea.right, _cropArea.bottom));
                });
              },
            ),
          ),
          Positioned( // top-right piece
            left: _cropArea.right + 1 - 24,
            top: _cropArea.top - 1,
            child: Listener(
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
                  child: Container(
                    height: 16,
                    width: 16,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border(
                        top: BorderSide(color: Colors.white, width: 5),
                        right: BorderSide(color: Colors.white, width: 5),
                      ),
                    ),
                  ),
                ),
              ),
              onPointerDown: _handleDragStart,
              onPointerCancel: _handleDragEnd,
              onPointerUp: _handleDragEnd,
              onPointerMove: (PointerMoveEvent details) {
                double dx = details.delta.dx;
                double right = (_cropArea.right + dx).clamp(_cropArea.left + 40, _viewSize.width - 16);
                double dy = details.delta.dy;
                double top = (_cropArea.top + dy).clamp(16.0, _cropArea.bottom - 40);
                setState(() {
                  _cropArea = getClampedCropArea(Rect.fromLTRB(_cropArea.left, top, right, _cropArea.bottom));
                });
              },
            ),
          ),
          Positioned( // bottom-right piece
            left: _cropArea.right + 1 - 24,
            top: _cropArea.bottom + 1 - 24,
            child: Listener(
              child: Container(
                width: 24,
                height: 24,
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 0, 0),
                  child: Container(
                    height: 16,
                    width: 16,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border(
                        bottom: BorderSide(color: Colors.white, width: 5),
                        right: BorderSide(color: Colors.white, width: 5),
                      ),
                    ),
                  ),
                ),
              ),
              onPointerDown: _handleDragStart,
              onPointerCancel: _handleDragEnd,
              onPointerUp: _handleDragEnd,
              onPointerMove: (PointerMoveEvent details) {
                double dx = details.delta.dx;
                double right = (_cropArea.right + dx).clamp(_cropArea.left + 40, _viewSize.width - 16);
                double dy = details.delta.dy;
                double bottom = (_cropArea.bottom + dy).clamp(_cropArea.top + 40, _viewSize.height - 16);
                setState(() {
                  _cropArea = getClampedCropArea(Rect.fromLTRB(_cropArea.left, _cropArea.top, right, bottom));
                });
              },
            ),
          ),
          Positioned( // bottom-left piece
            left: _cropArea.left - 1,
            top: _cropArea.bottom + 1 - 24,
            child: Listener(
              child: Container(
                width: 24,
                height: 24,
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                  child: Container(
                    height: 16,
                    width: 16,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border(
                        bottom: BorderSide(color: Colors.white, width: 5),
                        left: BorderSide(color: Colors.white, width: 5),
                      ),
                    ),
                  ),
                ),
              ),
              onPointerDown: _handleDragStart,
              onPointerCancel: _handleDragEnd,
              onPointerUp: _handleDragEnd,
              onPointerMove: (PointerMoveEvent details) {
                double dx = details.delta.dx;
                double left = (_cropArea.left + dx).clamp(16,  _cropArea.right - 40);
                double dy = details.delta.dy;
                double bottom = (_cropArea.bottom + dy).clamp(_cropArea.top + 40, _viewSize.height - 16);
                setState(() {
                  _cropArea = getClampedCropArea(Rect.fromLTRB(left, _cropArea.top, _cropArea.right, bottom));
                });
              },
            ),
          ),
        ],
      );
    });
  }

  double get topMargin => _cropArea?.top ?? 0;
  double get leftMargin => _cropArea?.left ?? 0;
  double get rightMargin => _viewSize != null && _cropArea != null ? (_viewSize.width - _cropArea?.right) : 0;
  double get bottomMargin => _viewSize != null && _cropArea != null ? (_viewSize.height - _cropArea?.bottom) : 0;

  @override
  void didChangeDependencies() {
    _resolveImage();
    super.didChangeDependencies();
  }

  @override
  void reassemble() {
    _resolveImage(); // in case the image cache was flushed
    super.reassemble();
  }

  void _resolveImage() {
    _imageStream = widget.image.resolve(createLocalImageConfiguration(context));
    _imageStream.addListener(_handleImageLoaded);
  }

  void _handleImageLoaded(ImageInfo info, bool synchronousCall) {
    print("image loaded: $info");
    setState(() {
      _image = info.image;
    });
  }

  void afterImageReady(BuildContext context) {
    if (_viewSize != null) {
      return;
    }
    print('img width=${_image.width}');
    print('img height=${_image.height}');
    print('view size=${context.size}');
    if (context.size.height == 0 || context.size.width == 0) {
      setState(() {
        // draw again
      });
      return;
    }
    _viewSize = context.size;
    double hScale = context.size.height / _image.height;
    double wScale = context.size.width / _image.width;
    double screenScale;
    if (hScale > wScale) {
      screenScale = wScale;
    } else {
      screenScale = hScale;
    }
    screenScale *= 0.8;
    if (screenScale > _minScale) {
      _minScale = screenScale;
    }

    // initial crop area
    double minX = _viewSize.width - _image.width * _scale;
    double minY = _viewSize.height - _image.height * _scale;
    double maxX = 0;
    double maxY = 0;
    if (0 < minX) {
      maxX = minX = minX / 2;
    }
    if (0 < minY) {
      maxY = minY = minY / 2;
    }
    setState(() {
      _cropArea = Rect.fromLTRB(0.1 * _viewSize.width, 0.1 * _viewSize.height, 0.9 * _viewSize.width, 0.9 * _viewSize.height);
    });
  }

  Rect get visibleRect {
    double left = -_offset.dx / _scale;
    double top = -_offset.dy / _scale;
    double right = (_viewSize.width - _offset.dx) / _scale;
    double bottom = (_viewSize.height - _offset.dy) / _scale;
    left = left.clamp(0.0, _image.width.toDouble());
    top = top.clamp(0.0, _image.height.toDouble());
    right = right.clamp(0.0, _image.width.toDouble());
    bottom = bottom.clamp(0.0, _image.height.toDouble());
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Rect get cropRect {
    double left = (_cropArea.left - _offset.dx) / _scale;
    double top = (_cropArea.top - _offset.dy) / _scale;
    double right = (_cropArea.right - _offset.dx) / _scale;
    double bottom = (_cropArea.bottom - _offset.dy) / _scale;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Rect get validOffset {
    double left = 0 * _scale + _offset.dx;
    double top = 0 * _scale + _offset.dy;
    double right = _image.width * _scale + _offset.dx;
    double bottom = _image.height * _scale + _offset.dy;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  void dispose() {
    _imageStream.removeListener(_handleImageLoaded);
    super.dispose();
  }
}

class _ZoomableImagePainter extends CustomPainter {
  const _ZoomableImagePainter({this.image, this.offset, this.scale, this.debugString = ''});

  final ui.Image image;
  final Offset offset;
  final double scale;
  final String debugString;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    Size imageSize = new Size(image.width.toDouble(), image.height.toDouble());
    Size targetSize = imageSize * scale;

    paintImage(
      canvas: canvas,
      rect: offset & targetSize,
      image: image,
      fit: BoxFit.fill,
    );

    if (debugString.isNotEmpty) {
      TextSpan span = TextSpan(
        text: debugString,
        style: TextStyle(
          color: Colors.pinkAccent,
          fontSize: 16,
        ),
      );
      TextPainter painter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      );
      painter.layout(
        minWidth: 0,
        maxWidth: canvasSize.width,
      );
      final offset = Offset(15, 15);
      painter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(_ZoomableImagePainter old) {
    return old.image != image || old.offset != offset || old.scale != scale;
  }
}
