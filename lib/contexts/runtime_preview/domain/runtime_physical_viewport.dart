class RuntimePhysicalViewport {
  const RuntimePhysicalViewport({
    required this.width,
    required this.height,
    required this.devicePixelRatio,
  });

  final int width;
  final int height;
  final double devicePixelRatio;

  Map<String, Object> toPayload() {
    return {
      'mode': 'physical',
      'width': width,
      'height': height,
      'devicePixelRatio': devicePixelRatio,
    };
  }
}
