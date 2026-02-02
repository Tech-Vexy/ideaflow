import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../providers.dart';

class ConversationalScreen extends ConsumerStatefulWidget {
  const ConversationalScreen({super.key});

  @override
  ConsumerState<ConversationalScreen> createState() =>
      _ConversationalScreenState();
}

class _ConversationalScreenState extends ConsumerState<ConversationalScreen> {
  final List<ChatMessage> _messages = [];
  bool _isInit = false;
  bool _isRecording = false;
  String _liveTranscript = "";
  final ScrollController _scrollController = ScrollController();

  bool _isProcessing = false;
  bool _isAborted = false;

  bool _isTextMode = false;
  final TextEditingController _textController = TextEditingController();

  void _toggleInputMode() {
    setState(() {
      _isTextMode = !_isTextMode;
    });
  }

  void _submitText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    // Simulate processing delay for UX smoothness
    setState(() => _isProcessing = true);

    // Hide keyboard
    FocusScope.of(context).unfocus();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _processInput(text);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _greetUser();
      // Sync from cloud on init
      ref.read(syncServiceProvider).syncFromCloud();
      _isInit = true;
    }
  }

  void _greetUser() {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.split(' ').first ?? "there";
    final greeting = "Hello $name, what ideas do you have today?";

    setState(() {
      _messages.add(ChatMessage(text: greeting, isUser: false));
    });

    // Speak the greeting
    ref.read(ttsServiceProvider).speak(greeting);
  }

  Future<void> _startRecording() async {
    final voiceService = ref.read(voiceServiceProvider);
    await voiceService.init();

    setState(() {
      _isRecording = true;
      _isAborted = false;
      _liveTranscript = "";
    });

    await voiceService.startRecording(
      onTextUpdate: (text) {
        setState(() {
          _liveTranscript = text;
        });
      },
    );
  }

  Future<void> _cancelRecording() async {
    final voiceService = ref.read(voiceServiceProvider);
    await voiceService.cancelRecording();
    setState(() {
      _isRecording = false;
      _isAborted = true;
      _liveTranscript = "";
    });
  }

  Future<void> _stopAndProcess() async {
    if (_isAborted) return;

    final voiceService = ref.read(voiceServiceProvider);
    await voiceService.stopRecording();
    final transcript = voiceService.currentTranscript;

    setState(() {
      _isRecording = false;
    });

    await _processInput(transcript);
  }

  Future<void> _processInput(String transcript) async {
    if (transcript.isEmpty) {
      debugPrint("Empty transcript, skipping Watson.");
      return;
    }

    // 1. Record (Add user message to UI)
    setState(() {
      _messages.add(ChatMessage(text: transcript, isUser: true));
      _scrollToBottom();
      _isProcessing = true;
      _isAborted = false;
    });

    // 2. Send to Watson (Stream)
    final watson = ref.read(watsonServiceProvider);

    // Build context from previous messages (last 6 messages)
    final historyBuffer = StringBuffer();
    final recentMessages = _messages.length > 6
        ? _messages.sublist(_messages.length - 6)
        : _messages;

    for (var msg in recentMessages) {
      if (msg.isThinking) continue;
      historyBuffer.writeln("${msg.isUser ? 'User' : 'AI'}: ${msg.text}");
    }

    // Add placeholder for AI response
    setState(() {
      _messages.add(ChatMessage(text: "...", isUser: false, isThinking: true));
      _scrollToBottom();
    });

    String fullResponse = "";
    bool firstChunkReceived = false;

    // Check Connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);

    if (isOffline) {
      // OFFLINE MODE
      try {
        final offlineAi = ref.read(offlineAiServiceProvider);

        // Show "Offline Mode" indicator briefly (optional, or just handle via UI)
        if (kDebugMode) print("Using Offline AI Service");

        var response = "";
        final stream = await offlineAi.startBrainstorming(transcript);

        await for (final chunk in stream) {
          if (_isAborted) break;
          response += chunk;
          setState(() {
            if (!firstChunkReceived) {
              if (_messages.isNotEmpty && _messages.last.isThinking) {
                _messages.removeLast();
              }
              _messages.add(ChatMessage(text: response, isUser: false));
              firstChunkReceived = true;
            } else {
              if (_messages.isNotEmpty && !_messages.last.isUser) {
                _messages.removeLast();
                _messages.add(ChatMessage(text: response, isUser: false));
              }
            }
            _scrollToBottom();
          });
        }
        fullResponse = response;
      } catch (e) {
        debugPrint("Offline AI Error: $e");
        fullResponse = "I'm offline and encountered an error processing that.";
      }
    } else {
      // ONLINE MODE (Watson)
      try {
        final stream = watson.analyzeIdeaStream(
          transcript,
          previousContext: historyBuffer.toString(),
        );

        await for (final chunk in stream) {
          if (_isAborted) break;

          fullResponse += chunk;

          // Update UI
          setState(() {
            if (!firstChunkReceived) {
              // Remove thinking indicator, start actual message
              if (_messages.isNotEmpty && _messages.last.isThinking) {
                _messages.removeLast();
              }
              _messages.add(ChatMessage(text: fullResponse, isUser: false));
              firstChunkReceived = true;
            } else {
              // Update last message
              if (_messages.isNotEmpty && !_messages.last.isUser) {
                _messages.removeLast();
                _messages.add(ChatMessage(text: fullResponse, isUser: false));
              }
            }
            _scrollToBottom();
          });
        }
      } catch (e) {
        debugPrint("Streaming error: $e");
        fullResponse = "Sorry, I encountered an error processing that.";
      }
    }

    if (_isAborted) {
      debugPrint("Processing aborted, ignoring result.");
      setState(() {
        // Cleanup if needed
        _isProcessing = false;
      });
      return;
    }

    setState(() {
      _isProcessing = false;
    });

    final aiInsight = fullResponse.isNotEmpty
        ? fullResponse
        : "No response generated.";

    if (!firstChunkReceived) {
      // If we never got a chunk (e.g. error or empty), show the final string
      setState(() {
        if (_messages.isNotEmpty && _messages.last.isThinking) {
          _messages.removeLast();
        }
        _messages.add(ChatMessage(text: aiInsight, isUser: false));
        _scrollToBottom();
      });
    }

    // 3. Speak and Save
    ref.read(ttsServiceProvider).speak(aiInsight);

    // 4. Save the idea (Persist to Hive & Firebase)
    final hiveService = ref.read(hiveServiceProvider);
    final firebaseService = ref.read(firebaseServiceProvider);

    final title = transcript.length > 30
        ? "${transcript.substring(0, 30)}..."
        : transcript;

    final idea = await hiveService.createIdea(title);
    final session = await hiveService.addSession(
      idea.id,
      transcript,
      aiInsight: aiInsight,
    );

    // Sync to Firebase Cloud
    await firebaseService.saveIdea(idea);
    await firebaseService.saveSession(session);
  }

  void _abortProcessing() {
    setState(() {
      _isAborted = true;
      _isProcessing = false;
      if (_messages.isNotEmpty && _messages.last.isThinking) {
        _messages.removeLast();
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text("Idea Flow"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          // Debug Button for Testing
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: "Test Full Flow",
              onPressed: () {
                _liveTranscript =
                    "I want to build a sustainable energy monitoring app using Flutter and IoT sensors.";
                _stopAndProcess();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 10,
                    bottom: 20,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _FadeInUp(
                      key: ValueKey(msg.text.hashCode),
                      child: _ChatBubble(message: msg),
                    );
                  },
                ),
              ),
            ),
          ),

          // Bottom Input Area
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isRecording)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.9,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.error.withValues(
                                  alpha: 0.1,
                                ),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _WaveformVisualizer(),
                              const SizedBox(width: 16),
                              Text(
                                _liveTranscript.isEmpty
                                    ? "Listening..."
                                    : _liveTranscript.length > 20
                                    ? "${_liveTranscript.substring(0, 20)}..."
                                    : _liveTranscript,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Bottom-aligned Input
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Visibility(
                    visible: !_isProcessing,
                    maintainSize: false,
                    child: _isTextMode
                        ? _TextInputArea(
                            controller: _textController,
                            onSubmit: _submitText,
                            isProcessing: _isProcessing,
                            onSwitchMode: _toggleInputMode,
                          )
                        : _VoiceInputArea(
                            isRecording: _isRecording,
                            isProcessing: _isProcessing,
                            onStart: _startRecording,
                            onStop: _stopAndProcess,
                            onCancel: _cancelRecording,
                            onAbort: _abortProcessing,
                            onSwitchMode: _toggleInputMode,
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Text(
                _isRecording
                    ? "Release to process • Slide to cancel"
                    : _isProcessing
                    ? "AI is thinking..."
                    : "Hold to speak your idea",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isThinking;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isThinking = false,
  });
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAI = !message.isUser;
    final user = FirebaseAuth.instance.currentUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isAI
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAI) _Avatar(isAI: true, label: "AI"),
          const SizedBox(width: 8),
          Flexible(
            child: ClipRRect(
              // Clip for blur effect
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isAI ? 0 : 20),
                bottomRight: Radius.circular(isAI ? 20 : 0),
              ),
              child: BackdropFilter(
                filter: isAI
                    ? ImageFilter.blur(sigmaX: 10, sigmaY: 10)
                    : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isAI
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withValues(alpha: 0.8),
                            ],
                          ),
                    border: isAI
                        ? Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.1,
                            ),
                          )
                        : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isAI ? 0 : 20),
                      bottomRight: Radius.circular(isAI ? 20 : 0),
                    ),
                  ),
                  child: message.isThinking
                      ? _ThinkingIndicator()
                      : MarkdownBody(
                          data: message.text,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: isAI
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onPrimary,
                              fontSize: 15,
                              height: 1.4,
                              fontFamily: isAI ? null : 'Inter',
                            ),
                            listBullet: TextStyle(
                              color: isAI
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!isAI)
            _Avatar(
              isAI: false,
              label: user?.displayName?[0].toUpperCase() ?? "U",
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final bool isAI;
  final String label;

  const _Avatar({required this.isAI, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isAI
            ? theme.colorScheme.secondary
            : theme.colorScheme.primaryContainer,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: isAI
            ? const Icon(Icons.auto_awesome, size: 16, color: Colors.white)
            : Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) => _Dot(index: index)),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int index;
  const _Dot({required this.index});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.index * 200), () {
      if (mounted) _controller.repeat(reverse: true);
    });
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
        return Opacity(
          opacity: 0.3 + (_controller.value * 0.7),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey,
            ),
          ),
        );
      },
    );
  }
}

class _VoiceInputArea extends StatefulWidget {
  final bool isRecording;
  final bool isProcessing;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final VoidCallback onAbort;
  final VoidCallback onSwitchMode;

  const _VoiceInputArea({
    required this.isRecording,
    required this.isProcessing,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    required this.onAbort,
    required this.onSwitchMode,
  });

  @override
  State<_VoiceInputArea> createState() => _VoiceInputAreaState();
}

class _VoiceInputAreaState extends State<_VoiceInputArea>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left Action Button (Cancel or Keyboard)
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: (widget.isRecording || widget.isProcessing)
              ? IconButton.filledTonal(
                  icon: const Icon(Icons.close_rounded, color: Colors.red),
                  onPressed: widget.isRecording
                      ? widget.onCancel
                      : widget.onAbort,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer
                        .withValues(alpha: 0.5),
                    padding: const EdgeInsets.all(12),
                  ),
                )
              : IconButton.filledTonal(
                  icon: const Icon(Icons.keyboard_alt_rounded),
                  onPressed: widget.onSwitchMode,
                  tooltip: "Switch to Text",
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
        ),

        GestureDetector(
          onLongPress: widget.onStart,
          onLongPressUp: widget.onStop,
          onHorizontalDragEnd: (details) {
            if (widget.isRecording &&
                details.primaryVelocity != null &&
                details.primaryVelocity!.abs() > 100) {
              widget.onCancel();
            }
          },
          onTap: () {
            if (widget.isRecording) {
              widget.onStop();
            } else if (!widget.isProcessing) {
              widget.onStart();
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Hero(
              tag: 'mic_button',
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final scale = widget.isRecording
                      ? 1.0 + (_controller.value * 0.15)
                      : 1.0;
                  return Transform.scale(scale: scale, child: child);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(widget.isRecording ? 35 : 25),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.isRecording
                          ? [Colors.redAccent, Colors.red[700]!]
                          : widget.isProcessing
                          ? [Colors.grey, Colors.blueGrey]
                          : [Colors.deepPurple, Colors.deepPurpleAccent],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (widget.isRecording
                                    ? Colors.redAccent
                                    : Colors.deepPurple)
                                .withValues(alpha: 0.4),
                        blurRadius: widget.isRecording ? 50 : 25,
                        spreadRadius: widget.isRecording ? 12 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.isRecording
                        ? Icons.stop_rounded
                        : widget.isProcessing
                        ? Icons.hourglass_empty_rounded
                        : Icons.mic_rounded,
                    color: Colors.white,
                    size: 45,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Right Spacer (to balance Left Action Button)
        const SizedBox(width: 68),
      ],
    );
  }
}

class _FadeInUp extends StatefulWidget {
  final Widget child;

  const _FadeInUp({super.key, required this.child});

  @override
  State<_FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<_FadeInUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _translate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _opacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _translate = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (mounted) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _translate, child: widget.child),
    );
  }
}

class _WaveformVisualizer extends StatefulWidget {
  @override
  State<_WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<_WaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              final h =
                  10 +
                  15 *
                      (0.5 +
                          0.5 *
                              (index % 2 == 0 ? 1 : -1) *
                              (2 * 3.14159 * (t + index * 0.2))
                                  .abs()); // Simulated wave
              return Container(
                width: 6,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _TextInputArea extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool isProcessing;
  final VoidCallback onSwitchMode;

  const _TextInputArea({
    required this.controller,
    required this.onSubmit,
    required this.isProcessing,
    required this.onSwitchMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton.filledTonal(
            onPressed: onSwitchMode,
            icon: const Icon(Icons.mic_rounded),
            tooltip: "Switch to Voice",
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: controller,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: "Type your idea...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: isProcessing ? null : onSubmit,
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            icon: isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}
