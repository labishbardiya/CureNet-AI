import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../core/theme.dart';
import 'package:curenet/core/navigation_helper.dart';
import '../core/translated_text.dart';
import 'scan_result_screen.dart';
import '../core/app_config.dart';
import '../core/data_mode.dart';

class DocScanScreen extends StatefulWidget {
  const DocScanScreen({super.key});

  @override
  State<DocScanScreen> createState() => _DocScanScreenState();
}

class _DocScanScreenState extends State<DocScanScreen> with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;

  XFile? _pickedFile; 
  final ImagePicker _picker = ImagePicker();
  
  bool _isUploading = false;
  bool _isProcessing = false;
  String _statusText = "Scan prescriptions, reports & documents";

  String get _ocrApiUrl => AppConfig.ocrApiUrl;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(_scanController);
    
    if (!kIsWeb) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    var status = await Permission.camera.request();
    if (status.isGranted) {
      try {
        _cameras = await availableCameras();
        if (_cameras != null && _cameras!.isNotEmpty) {
          _cameraController = CameraController(
            _cameras!.first,
            ResolutionPreset.high,
            enableAudio: false,
          );
          await _cameraController!.initialize();
          if (mounted) setState(() => _isCameraInitialized = true);
        }
      } catch (e) {
        print("Camera initialization error: $e");
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is disabled. Please enable it in Settings.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (e) {
      print("Flash toggle error: $e");
    }
  }

  Future<void> _captureFromCamera() async {
    if (_cameraController == null || !_isCameraInitialized || _isUploading) return;
    try {
      final XFile photo = await _cameraController!.takePicture();
      setState(() => _pickedFile = photo);
      // Turn off flash if it was on
      if (_isFlashOn) _toggleFlash();
      
      _uploadXFile(photo);
    } catch (e) {
      print("Capture error: $e");
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() => _pickedFile = photo);
        // Turn off flash if it was on
        if (_isFlashOn) _toggleFlash();
        _uploadXFile(photo);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open gallery: $e')),
      );
    }
  }

  Future<void> _uploadXFile(XFile file) async {
    setState(() {
      _isUploading = true;
      _statusText = "Uploading Document to ABDM OCR...";
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_ocrApiUrl/scan'));
      // Tag the record with the active user identity
      request.fields['userId'] = DataMode.activeUserId;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: file.name));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 202) {
        var jsonResponse = jsonDecode(response.body);
        String jobId = jsonResponse['data']['jobId'];
        
        setState(() {
          _isUploading = false;
          _isProcessing = true;
          _statusText = "Processing OCR Payload. Please wait...";
        });

        _pollOCRStatus(jobId);
      } else {
        throw Exception('Server rejected upload (${response.statusCode}).');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _pickedFile = null; // Reset to show camera again
        _statusText = "Upload Failed! Try again.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Upload Failed. Please ensure sufficient lighting and that the document is a valid medical record."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _pollOCRStatus(String jobId) {
    Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      try {
        final response = await http.get(Uri.parse('$_ocrApiUrl/status/$jobId'));
        if (response.statusCode == 200) {
          var jsonData = jsonDecode(response.body);
          
          if (jsonData['data']['state'] == 'processing' || jsonData['data']['state'] == 'pending') {
            return; 
          }

          if (jsonData['data']['status'] == 'completed') {
            timer.cancel();
            setState(() {
              _isProcessing = false;
              _statusText = "ABDM FHIR Bundle Ready!";
            });
            
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ScanResultScreen(
                    uiData: jsonData['data']['ui_data'] ?? {},
                    fhirBundle: jsonData['data']['fhir_bundle'] ?? jsonData['data']['fhirBundle'] ?? {},
                    abdmContext: jsonData['data']['abdmContext'] ?? {},
                    imagePath: _pickedFile?.path,
                  ),
                ),
              );
            }
          } else {
            // Failed
            timer.cancel();
            String errorMsg = jsonData['data']['error'] ?? "Job Failed.";
            errorMsg += " Ensure sufficient lighting and that it's a valid medical document (prescription, lab report, etc).";
            
            setState(() {
              _isProcessing = false;
              _pickedFile = null; // Reset to camera
              _statusText = "Processing failed. Please try again.";
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMsg),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      } catch (e) {
        // Ignore single poll failures temporarily
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D2240), Color(0xFF1A3A5C)],
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text("←", style: TextStyle(fontSize: 26, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TranslatedText("Scan & Upload",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      TranslatedText(_statusText,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF00C4C4)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: (_isUploading || _isProcessing)
                ? _buildLoadingState()
                : _buildScannerView(),
          ),
        ],
      ),

      // Bottom Navigation
      bottomNavigationBar: Container(
        height: 78,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFD8DDE6))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home, "Home", false, () => Navigator.pushReplacementNamed(context, '/home')),
            _navItem(Icons.smart_toy, "ABHAy", false, () => Navigator.pushReplacementNamed(context, '/chat')),
            _scanButton(context),
            _navItem(Icons.list_alt, "Records", false, () => Navigator.pushReplacementNamed(context, '/records')),
            _navItem(Icons.share, "Share", false, () => Navigator.pushReplacementNamed(context, '/qr-share')),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_pickedFile != null && !kIsWeb) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(File(_pickedFile!.path), height: 300, fit: BoxFit.cover),
            ),
            const SizedBox(height: 32),
          ],
          const CircularProgressIndicator(color: Color(0xFF00A3A3)),
          const SizedBox(height: 16),
          TranslatedText(
             _isUploading ? "Uploading Document securely..." : "Processing OCR into FHIR Bundle...",
             style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D2240), fontSize: 16),
          )
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        // 1. Live Camera Preview
        if (_isCameraInitialized && _cameraController != null)
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          )
        else
          Container(
            color: Colors.black,
            child: const Center(child: CircularProgressIndicator(color: Color(0xFF00A3A3))),
          ),
          
        // 2. Translucent Overlay with Cutout
        Positioned.fill(
          child: Column(
            children: [
              Container(height: 60, color: Colors.black54),
              Expanded(
                child: Row(
                  children: [
                    Container(width: 30, color: Colors.black54),
                    Expanded(
                      child: Stack(
                        children: [
                          // Transparent Center
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF00A3A3), width: 2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          // Scanning Laser Animation
                          AnimatedBuilder(
                            animation: _scanAnimation,
                            builder: (context, child) {
                              return Align(
                                alignment: FractionalOffset(0.5, _scanAnimation.value),
                                child: Container(
                                  height: 2,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.transparent, Color(0xFF00A3A3), Colors.transparent],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // Corner brackets
                          Positioned(top: 0, left: 0, child: _cornerBracket()),
                          Positioned(top: 0, right: 0, child: _cornerBracket(rotate: true)),
                          Positioned(bottom: 0, left: 0, child: _cornerBracket(rotate: true, bottom: true)),
                          Positioned(bottom: 0, right: 0, child: _cornerBracket(bottom: true)),
                        ],
                      ),
                    ),
                    Container(width: 30, color: Colors.black54),
                  ],
                ),
              ),
              Container(height: 180, color: Colors.black54), // Room for bottom controls
            ],
          ),
        ),

        // 3. User Instructions Overlay
        Positioned(
          top: 80,
          left: 40,
          right: 40,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00A3A3).withOpacity(0.3)),
            ),
            child: const Column(
              children: [
                TranslatedText("Point camera at document",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF00C4C4)),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                TranslatedText("Align prescriptions, lab reports, X-Rays, or QR codes within the frame. Ensure sufficient lighting. Documents are automatically sorted.",
                  style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        // 4. Capture & Tools Overlay (Bottom Area)
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery Button
              GestureDetector(
                onTap: _pickFromGallery,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                ),
              ),
              
              // Capture Button
              GestureDetector(
                onTap: _captureFromCamera,
                child: Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00A3A3), width: 3),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF00A3A3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 36),
                  ),
                ),
              ),

              // Torch/Flash Button
              GestureDetector(
                onTap: _toggleFlash,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isFlashOn ? const Color(0xFF00A3A3) : Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off, 
                    color: Colors.white, 
                    size: 28
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cornerBracket({bool rotate = false, bool bottom = false}) {
    return Transform.rotate(
      angle: rotate ? (bottom ? 1.57 : -1.57) : 0,
      child: const Icon(Icons.square_outlined, size: 28, color: Color(0xFF00A3A3)),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB)),
          TranslatedText(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? const Color(0xFF00A3A3) : const Color(0xFF9BA8BB))),
        ],
      ),
    );
  }

    Widget _scanButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (ModalRoute.of(context)?.settings.name != '/doc-scan') {
          Navigator.pushNamed(context, '/doc-scan');
        }
      },
      child: Transform.translate(
        offset: const Offset(0, -24),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF00A3A3), Color(0xFF00C4C4)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00A3A3).withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.camera_alt, size: 28, color: Colors.white),
          ),
        ),
      ),
    );
  }
}