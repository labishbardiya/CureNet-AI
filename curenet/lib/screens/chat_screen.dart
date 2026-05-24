import 'package:flutter/material.dart';
import 'dart:async';
import '../core/theme.dart';
import '../core/voice_helper.dart';
import '../core/translated_text.dart';
import '../core/app_language.dart';
import '../services/ai_service.dart';
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curenet/core/navigation_helper.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/auth_provider.dart';
import '../core/data_mode.dart';
import '../core/persona.dart';
import 'profile_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  bool _isTyping = false;
  bool _isListening = false;
  bool _isTemporary = false;
  bool _isDarkMode = false;
  bool _autoSpeak = false;
  bool _useMedicalContext = true;

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _sessions = [];
  String _currentSessionId = "";

  @override
  void initState() {
    super.initState();
    AiService.init();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionsJson = prefs.getString('chat_sessions');
    
    if (sessionsJson != null && sessionsJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(sessionsJson);
      _sessions = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    
    if (_sessions.isEmpty) {
      _createNewSession();
    } else {
      _currentSessionId = _sessions.last['id'] as String;
      _messages = List<Map<String, dynamic>>.from(_sessions.last['messages']);
      setState(() {});
      _scrollToBottom();
    }
  }

  void _createNewSession({bool temporary = false}) {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _isTemporary = temporary;
      _currentSessionId = newId;
      _messages = [
        {
          "role": "bot",
          "text": temporary 
            ? "Temporary Chat Active: Your messages won't be saved to history once you leave." 
            : "Namaste! I'm Abhya, your health assistant. How can I help you today?"
        },
      ];
      
      if (!temporary) {
        _sessions.add({
          "id": newId,
          "title": "New Chat",
          "messages": _messages,
        });
      }
    });
    if (!temporary) _saveHistory();
  }

  void _deleteSession(String id) async {
    setState(() {
      _sessions.removeWhere((s) => s['id'] == id);
      if (_currentSessionId == id) {
        if (_sessions.isNotEmpty) {
          _switchSession(_sessions.last['id'] as String);
        } else {
          _createNewSession();
        }
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_sessions', jsonEncode(_sessions));
  }

  void _toggleTemporary(bool value) {
    Navigator.pop(context); // Close drawer
    if (value) {
      _createNewSession(temporary: true);
    } else {
      _loadHistory();
    }
  }

  void _switchSession(String id) {
    final session = _sessions.firstWhere((s) => s['id'] == id);
    setState(() {
      _isTemporary = false;
      _currentSessionId = id;
      _messages = List<Map<String, dynamic>>.from(session['messages']);
    });
    _scrollToBottom();
    Navigator.pop(context); // Close drawer
  }

  Future<void> _saveHistory() async {
    if (_isTemporary) return;

    final sessionIndex = _sessions.indexWhere((s) => s['id'] == _currentSessionId);
    if (sessionIndex != -1) {
      _sessions[sessionIndex]['messages'] = _messages;
      
      // Update title if it's still "New Chat" and we have user messages
      if (_sessions[sessionIndex]['title'] == "New Chat" && _messages.length > 1) {
        final firstUserMsg = _messages.firstWhere((m) => m['role'] == 'user')['text'] as String;
        // Generate title in background to not block UI
        _updateTitleAsync(sessionIndex, firstUserMsg);
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_sessions', jsonEncode(_sessions));
  }

  Future<void> _updateTitleAsync(int index, String message) async {
    final title = await AiService.generateTitle(message);
    if (mounted) {
      setState(() {
        _sessions[index]['title'] = title;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_sessions', jsonEncode(_sessions));
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);

        String currentLang = AppLanguage.selectedLanguage.value;
        String localeId = 'en_US';
        if (currentLang == 'Hindi') localeId = 'hi_IN';
        else if (currentLang == 'Bengali') localeId = 'bn_IN';
        else if (currentLang == 'Telugu') localeId = 'te_IN';
        else if (currentLang == 'Marathi') localeId = 'mr_IN';
        else if (currentLang == 'Tamil') localeId = 'ta_IN';
        else if (currentLang == 'Gujarati') localeId = 'gu_IN';
        else if (currentLang == 'Kannada') localeId = 'kn_IN';
        else if (currentLang == 'Malayalam') localeId = 'ml_IN';

        _speech.listen(
          localeId: localeId,
          onResult: (val) => setState(() {
            _controller.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_controller.text.isNotEmpty) {
        _sendMessage();
      }
    }
  }

  Future<String> _getPatientContext() async {
    if (!_useMedicalContext) return "[MEDICAL_RECORDS]\nAccess Disabled by User\n[/MEDICAL_RECORDS]";

    final prefs = await SharedPreferences.getInstance();
    final String? recordsJson = prefs.getString(DataMode.storageKey('health_records'));
    final String? abhaAddress = prefs.getString('abha_address') ?? 'Not provided';
    final String? userName = prefs.getString('user_name') ?? 'Priya Sharma';

    String context = "[PATIENT_PROFILE]\nName: $userName\nABHA: $abhaAddress\n\n[MEDICAL_RECORDS]\n";
    
    if (recordsJson != null && recordsJson.isNotEmpty) {
      final List<dynamic> records = jsonDecode(recordsJson);
      for (var r in records) {
        context += "- ${r['date']}: ${r['title']} (Doctor: ${r['doctor']}, Category: ${r['category']})\n";
      }
    } else {
      context += "No local records found.";
    }
    
    context += "\n[/MEDICAL_RECORDS]";
    return context;
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isTyping = true;
    });
    _saveHistory();
    _controller.clear();
    _scrollToBottom();

    final languageCode = AppLanguage.selectedLanguage.value;
    final patientContext = await _getPatientContext();
    
    // Add an empty bot message that we'll fill as chunks arrive
    if (!mounted) return;
    setState(() {
      _messages.add({"role": "bot", "text": ""});
    });
    
    final botMsgIndex = _messages.length - 1;
    String fullReply = "";

    try {
      final stream = AiService.sendMessageStream(
        text, 
        language: languageCode, 
        patientContext: patientContext,
      );
      
      await for (final chunk in stream) {
        if (!mounted) break;
        fullReply += chunk;
        setState(() {
          _messages[botMsgIndex]["text"] = fullReply;
          // Hide thinking dots once first chunk arrives
          if (_isTyping) _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages[botMsgIndex]["text"] = "I'm having trouble connecting to Abhya AI. Please check your internet.";
          _isTyping = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
        _saveHistory();
        _scrollToBottom();

        if (_autoSpeak && fullReply.isNotEmpty) {
          final plainText = fullReply.replaceAll(RegExp(r'\*|#'), '');
          VoiceHelper.speak(plainText);
        }
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, {bool animate = false}) {
    final isUser = msg["role"] == "user";
    final text = msg["text"] as String;
    final botBubbleColor = _isDarkMode ? const Color(0xFF2F2F2F) : const Color(0xFFF3F4F6);
    final botTextColor = _isDarkMode ? Colors.white : const Color(0xFF1F2937);

    // Don't render empty bot bubbles (streaming placeholder)
    if (!isUser && text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isUser) ...[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10A37F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.smart_toy, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF00A3A3) : botBubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 20),
                      ),
                      boxShadow: [
                        if (!_isDarkMode) BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser)
                          MarkdownBody(
                            data: text,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(fontSize: 15, height: 1.5, color: botTextColor),
                              strong: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A3A3)),
                            ),
                          )
                        else
                          Text(
                            text,
                            style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                ),
                if (isUser) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _isDarkMode ? const Color(0xFF2F2F2F) : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person, size: 14, color: _isDarkMode ? Colors.white70 : const Color(0xFF6B7280)),
                  ),
                ],
              ],
            ),
            // Only show action icons when response is complete (not during streaming)
            if (!isUser && text.length > 2 && !_isTyping)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 36),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _actionIcon(Icons.volume_up, () async {
                      final plainText = text.replaceAll(RegExp(r'\*|#'), '');
                      await VoiceHelper.speak(plainText);
                    }),
                    const SizedBox(width: 8),
                    _actionIcon(Icons.content_copy, () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Copied to clipboard"), duration: Duration(seconds: 1)),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
      ),
    );
  }

  void _showSettings() {
    Navigator.pop(context); // Close drawer
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Make this transparent to handle it inside
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final sheetBg = _isDarkMode ? const Color(0xFF171717) : Colors.white;
          final sheetText = _isDarkMode ? Colors.white : const Color(0xFF374151);
          final sheetSubText = _isDarkMode ? Colors.white60 : Colors.black54;

          return Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Settings", 
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        color: sheetText
                      )
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context), 
                      icon: Icon(Icons.close, color: _isDarkMode ? Colors.white54 : Colors.black45)
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _settingsTile(
                  icon: _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  title: "Dark Mode",
                  subtitle: "Switch between light and dark themes",
                  value: _isDarkMode,
                  onChanged: (val) {
                    setState(() => _isDarkMode = val);
                    setModalState(() {});
                  },
                ),
                _settingsTile(
                  icon: Icons.volume_up,
                  title: "Auto Voice Response",
                  subtitle: "Speak AI responses automatically",
                  value: _autoSpeak,
                  onChanged: (val) {
                    setState(() => _autoSpeak = val);
                    setModalState(() {});
                  },
                ),
                _settingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: "Medical Data Context",
                  subtitle: "Allow AI to see your health records",
                  value: _useMedicalContext,
                  onChanged: (val) {
                    setState(() => _useMedicalContext = val);
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      _deleteSession(_currentSessionId);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.redAccent, width: 1),
                      ),
                    ),
                    child: const Text("Clear Current Chat History", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon, 
    required String title, 
    required String subtitle, 
    required bool value, 
    required ValueChanged<bool> onChanged
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: _isDarkMode ? const Color(0xFF10A37F) : const Color(0xFF00A3A3), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: _isDarkMode ? Colors.white : Colors.black87)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: _isDarkMode ? Colors.white60 : Colors.black54)),
              ],
            ),
          ),
          Switch(
            value: value, 
            onChanged: onChanged,
            activeColor: const Color(0xFF10A37F),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? const Color(0xFF212121) : Colors.white;
    final headerColor = _isDarkMode ? const Color(0xFF171717) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF374151);
    final borderColor = _isDarkMode ? const Color(0xFF2F2F2F) : const Color(0xFFE5E7EB);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      drawer: _buildDrawer(),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 12),
            decoration: BoxDecoration(
              color: headerColor,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.menu, color: textColor),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const Spacer(),
                Column(
                  children: [
                    TranslatedText("Abhya AI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                    Text(
                      _isTemporary ? "Temporary Chat" : "Llama 3.3 · Medical RAG", 
                      style: TextStyle(fontSize: 10, color: _isTemporary ? Colors.orange : const Color(0xFF10A37F)),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.add_box_outlined, color: textColor),
                  onPressed: () => _createNewSession(),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10A37F),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.smart_toy, size: 14, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _isDarkMode ? const Color(0xFF2F2F2F) : const Color(0xFFF3F4F6),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                                bottomLeft: Radius.circular(4),
                                bottomRight: Radius.circular(20),
                              ),
                            ),
                            child: const ThinkingDots(),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                final msg = _messages[index];
                // ONLY animate the FINAL completed message (not during streaming)
                // During streaming, _isTyping is false but text is still being appended.
                // We detect "streaming in progress" by checking if this is the last bot message 
                // and fullReply is still growing (empty text = still loading).
                final bool isLastBotMsg = index == _messages.length - 1 && msg["role"] == "bot";
                final bool isStreaming = isLastBotMsg && _isTyping;
                final bool shouldAnimate = false; // Disable TypingText — streaming IS the animation
                
                return _buildMessageBubble(msg, animate: shouldAnimate);
              },
            ),
          ),

          if (_messages.length == 1 && !_isTyping) _buildStarterChips(),

          // Input Area
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            decoration: BoxDecoration(
              color: headerColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF2F2F2F) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
                boxShadow: [
                  if (!_isDarkMode) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 5,
                      minLines: 1,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: "Send a message",
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: _isDarkMode ? Colors.white38 : const Color(0xFF9CA3AF)),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _listen,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_isListening)
                          const VoicePulseAnimation(),
                        Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.red : (_isDarkMode ? Colors.white70 : const Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A3A3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarterChips() {
    final chips = [
      {"text": "Summary of my health", "icon": Icons.summarize_outlined},
      {"text": "Latest HbA1c result", "icon": Icons.bloodtype_outlined},
      {"text": "My active medications", "icon": Icons.medication_outlined},
      {"text": "Emergency Snapshot", "icon": Icons.emergency_outlined},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              onPressed: () {
                _controller.text = chips[index]['text'] as String;
                _sendMessage();
              },
              backgroundColor: _isDarkMode ? const Color(0xFF2F2F2F) : const Color(0xFFF3F4F6),
              avatar: Icon(chips[index]['icon'] as IconData, size: 14, color: const Color(0xFF10A37F)),
              label: Text(
                chips[index]['text'] as String,
                style: TextStyle(fontSize: 13, color: _isDarkMode ? Colors.white70 : const Color(0xFF374151)),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawer() {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.userProfile;
    final String userName = (user != null && user['name'] != null && user['name'].toString().trim().isNotEmpty)
        ? user['name'].toString()
        : (DataMode.activeUserId == DataMode.arjunId ? Persona.name : 'User');

    return Drawer(
      backgroundColor: const Color(0xFF202123),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 60, 12, 12),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    _createNewSession();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF4D4D4F)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 16),
                        SizedBox(width: 12),
                        Text("New Chat", style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _isTemporary ? const Color(0xFF343541) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.visibility_off_outlined, color: Colors.white, size: 16),
                          SizedBox(width: 12),
                          Text("Temporary Chat", style: TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                      Switch(
                        value: _isTemporary,
                        onChanged: _toggleTemporary,
                        activeColor: const Color(0xFF10A37F),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final session = _sessions.reversed.toList()[index];
                final isSelected = session['id'] == _currentSessionId;
                
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _switchSession(session['id'] as String),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF343541) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline, color: Color(0xFFECECF1), size: 16),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              session['title'] as String,
                              style: const TextStyle(color: Color(0xFFECECF1), fontSize: 14, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          if (isSelected)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_horiz, color: Color(0xFFECECF1), size: 16),
                              padding: EdgeInsets.zero,
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _deleteSession(session['id'] as String);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                      SizedBox(width: 8),
                                      Text("Delete", style: TextStyle(color: Colors.redAccent)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(color: Color(0xFF4D4D4F)),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Colors.white),
            title: const Text("Settings", style: TextStyle(color: Colors.white)),
            onTap: _showSettings,
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, color: Colors.white),
            title: Text(userName, style: const TextStyle(color: Colors.white)),
            subtitle: const Text("View Profile", style: TextStyle(color: Color(0xFF9BA8BB), fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
            },
          ),
        ],
      ),
    );
  }
}

class ThinkingDots extends StatefulWidget {
  const ThinkingDots({super.key});

  @override
  State<ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<ThinkingDots> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      )..repeat(reverse: true);
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: -8).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                transform: Matrix4.translationValues(0, _animations[index].value, 0),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF9CA3AF),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class TypingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final VoidCallback onComplete;

  const TypingText({
    super.key,
    required this.text,
    required this.style,
    required this.onComplete,
  });

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _displayedText = "";
  int _currentIndex = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    const duration = Duration(milliseconds: 15);
    _timer = Timer.periodic(duration, (timer) {
      if (_currentIndex < widget.text.length) {
        if (mounted) {
          setState(() {
            _displayedText += widget.text[_currentIndex];
            _currentIndex++;
          });
          widget.onComplete();
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: _displayedText,
      styleSheet: MarkdownStyleSheet(
        p: widget.style,
        strong: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00A3A3)),
      ),
    );
  }
}

class VoicePulseAnimation extends StatefulWidget {
  const VoicePulseAnimation({super.key});

  @override
  State<VoicePulseAnimation> createState() => _VoicePulseAnimationState();
}

class _VoicePulseAnimationState extends State<VoicePulseAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 24 + (16 * _controller.value),
          height: 24 + (16 * _controller.value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(0.5 * (1 - _controller.value)),
          ),
        );
      },
    );
  }
}