part of 'stock_screen.dart';

class _StockCameraPage extends StatefulWidget {
  final String title;
  final String subtitle;

  const _StockCameraPage({required this.title, required this.subtitle});

  @override
  State<_StockCameraPage> createState() => _StockCameraPageState();
}

class _StockCameraPageState extends State<_StockCameraPage> {
  CameraController? controller;
  bool capturing = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    initialiseCamera();
  }

  Future<void> initialiseCamera() async {
    final oldController = controller;
    controller = null;
    await oldController?.dispose();
    if (mounted) setState(() => errorMessage = null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera is available on this device.');
      final camera = cameras.firstWhere((item) => item.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final value = CameraController(camera, ResolutionPreset.medium, enableAudio: false);
      await value.initialize();
      if (!mounted) {
        await value.dispose();
        return;
      }
      AppDiagnostics.instance.setCameraInfo(
        'Stock camera · title=${widget.title}, cameraCount=${cameras.length}, selected=${camera.name}, lens=${camera.lensDirection.name}, sensorOrientation=${camera.sensorOrientation}, preset=medium',
      );
      setState(() => controller = value);
    } catch (error, stackTrace) {
      AppDiagnostics.instance.recordError(error, stackTrace);
      if (mounted) setState(() => errorMessage = error.toString());
    }
  }

  Future<void> capturePhoto() async {
    final value = controller;
    if (value == null || !value.value.isInitialized || capturing) return;
    setState(() => capturing = true);
    try {
      final photo = await value.takePicture();
      if (mounted) Navigator.of(context).pop(photo.path);
    } catch (error, stackTrace) {
      AppDiagnostics.instance.recordError(error, stackTrace);
      if (mounted) setState(() { capturing = false; errorMessage = error.toString(); });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppTextScope.of(context);
    final value = controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(text.t(widget.title))),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Center(
              child: errorMessage != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 54),
                        const SizedBox(height: 14),
                        Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(onPressed: initialiseCamera, icon: const Icon(Icons.refresh_rounded), label: Text(text.t('Retry Camera'))),
                      ]),
                    )
                  : value == null || !value.value.isInitialized
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Stack(fit: StackFit.expand, children: [
                          LayoutBuilder(builder: (context, constraints) {
                            final previewSize = value.value.previewSize;
                            if (previewSize == null) return CameraPreview(value);
                            return ClipRect(child: FittedBox(fit: BoxFit.contain, child: SizedBox(width: previewSize.height, height: previewSize.width, child: CameraPreview(value))));
                          }),
                          Positioned(
                            left: 16,
                            right: 16,
                            top: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.58), borderRadius: BorderRadius.circular(14)),
                              child: Text(text.t(widget.subtitle), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: AppTextSize.s14, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: SizedBox(
              width: 76,
              height: 76,
              child: FloatingActionButton(
                heroTag: 'sku-thumbnail-capture',
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                onPressed: value == null || !value.value.isInitialized || capturing ? null : capturePhoto,
                child: capturing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt_rounded, size: 32),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
