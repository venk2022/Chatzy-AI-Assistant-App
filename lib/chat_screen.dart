import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'chat_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  TextEditingController messageController = TextEditingController();
  late stt.SpeechToText speech;
  bool isListening = false;
  AnimationController? _animationController;
  Animation<double>? _pulseAnimation;
  bool _isTyping = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    speech = stt.SpeechToText();
    requestMicrophonePermission();

    // Initialize animation controller for dynamic effects
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));

    _animationController!.repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(context, listen: false).loadMessages();
    });

    // Listen to text changes to detect typing
    messageController.addListener(() {
      final isTyping = messageController.text.isNotEmpty;
      if (isTyping != _isTyping) {
        setState(() {
          _isTyping = isTyping;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  void startListening() async {
    bool available = await speech.initialize();
    if (available) {
      setState(() => isListening = true);
      speech.listen(
        onResult: (result) {
          setState(() {
            messageController.text = result.recognizedWords;
            messageController.selection = TextSelection.fromPosition(
              TextPosition(offset: messageController.text.length),
            );
          });
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
      );
    }
  }

  void stopListening() {
    speech.stop();
    setState(() => isListening = false);
  }

  String formatDateHeader(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date).inDays;

      if (difference == 0) return 'Today';
      if (difference == 1) return 'Yesterday';
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _getStatusText(ChatProvider chatProvider) {
    if (isListening) return "Listening...";
    if (_isTyping) return "You're typing...";
    if (chatProvider.isLoading) return "AI is thinking...";

    final messageCount = chatProvider.messages.length;
    if (messageCount == 0) return "Start a conversation";

    return "Online • ${messageCount ~/ 2} conversations";
  }

  Color _getStatusIndicatorColor(ChatProvider chatProvider) {
    if (isListening) return Colors.red;
    if (chatProvider.isLoading) return Colors.orange;
    if (_isTyping) return Colors.blue;
    return Colors.green;
  }

  Widget _buildSidebar() {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Sidebar Header - Reduced height
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade600,
                      Colors.blue.shade800,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.smart_toy,
                              color: Colors.blue.shade600,
                              size: 25,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Chatzy AI",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Your AI Assistant",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Chat Statistics - More compact
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Chat Statistics",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem(
                          "Messages",
                          chatProvider.messages.length.toString(),
                          Icons.message,
                          Colors.blue,
                        ),
                        _buildStatItem(
                          "Conversations",
                          (chatProvider.messages.length ~/ 2).toString(),
                          Icons.chat_bubble_outline,
                          Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Menu Items - Scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: Icons.history,
                        title: "Chat History",
                        onTap: () {
                          Navigator.pop(context);
                          _showChatHistory(context);
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.download,
                        title: "Export Chat",
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Export feature coming soon!')),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.palette,
                        title: "Themes",
                        onTap: () {
                          Navigator.pop(context);
                          _showThemeOptions(context);
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.mic,
                        title: "Voice Settings",
                        trailing: Switch(
                          value: true,
                          onChanged: (value) {
                            // Handle voice settings toggle
                          },
                          activeColor: Colors.blue.shade600,
                        ),
                        onTap: () {},
                      ),
                      _buildMenuItem(
                        icon: Icons.settings,
                        title: "Settings",
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Settings coming soon!')),
                          );
                        },
                      ),
                      const Divider(height: 24),
                      _buildMenuItem(
                        icon: Icons.delete_forever,
                        title: "Clear All Chats",
                        titleColor: Colors.red,
                        iconColor: Colors.red,
                        onTap: () {
                          Navigator.pop(context);
                          _showClearConfirmDialog(context);
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.info_outline,
                        title: "About",
                        onTap: () {
                          Navigator.pop(context);
                          _showAboutDialog(context);
                        },
                      ),
                      // Add some bottom padding for the version text
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(12),
                child: Text(
                  "Version 1.0.0",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? Colors.grey.shade700,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? Colors.black87,
          fontSize: 16,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _showChatHistory(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Chat History"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: chatProvider.messages.isEmpty
              ? const Center(child: Text("No chat history available"))
              : ListView.builder(
            itemCount: chatProvider.messages.length,
            itemBuilder: (context, index) {
              final message = chatProvider.messages[index];
              return ListTile(
                leading: Icon(
                  message.isUser ? Icons.person : Icons.smart_toy,
                  color: message.isUser ? Colors.blue : Colors.grey,
                ),
                title: Text(
                  message.text.length > 50
                      ? "${message.text.substring(0, 50)}..."
                      : message.text,
                ),
                subtitle: Text(
                  DateFormat('MMM dd, hh:mm a').format(message.timestamp),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showThemeOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Choose Theme"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.light_mode, color: Colors.orange),
              title: const Text("Light Theme"),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Theme changed to Light')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode, color: Colors.grey),
              title: const Text("Dark Theme"),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dark theme coming soon!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_mode, color: Colors.blue),
              title: const Text("Auto Theme"),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Auto theme coming soon!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear All Chats"),
        content: const Text("Are you sure you want to delete all chat messages? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<ChatProvider>(context, listen: false).deleteAllMessages();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All chats cleared successfully')),
              );
            },
            child: const Text("Clear All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("About Chatzy"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Chatzy AI Assistant"),
            SizedBox(height: 8),
            Text("Version: 1.0.0"),
            SizedBox(height: 8),
            Text("A modern AI chat application with voice recognition and smart features."),
            SizedBox(height: 16),
            Text("Features:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("• Voice-to-text input"),
            Text("• Message editing & deletion"),
            Text("• Chat history"),
            Text("• Export functionality"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final groupedMessages = chatProvider.groupedMessages;
    final currentTime = DateFormat('HH:mm').format(DateTime.now());

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildSidebar(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade600,
                Colors.blue.shade800,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            title: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.smart_toy, color: Colors.blue.shade600),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _animationController != null && _pulseAnimation != null
                          ? AnimatedBuilder(
                        animation: _pulseAnimation!,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: isListening || chatProvider.isLoading
                                ? _pulseAnimation!.value
                                : 1.0,
                            child: Container(
                              height: 12,
                              width: 12,
                              decoration: BoxDecoration(
                                color: _getStatusIndicatorColor(chatProvider),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          );
                        },
                      )
                          : Container(
                        height: 12,
                        width: 12,
                        decoration: BoxDecoration(
                          color: _getStatusIndicatorColor(chatProvider),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Chatzy",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (chatProvider.isLoading)
                            const SizedBox(
                              height: 12,
                              width: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                        ],
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _getStatusText(chatProvider),
                          key: ValueKey(_getStatusText(chatProvider)),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Current time display
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Center(
                  child: Text(
                    currentTime,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              // Voice recognition status
              if (isListening && _animationController != null && _pulseAnimation != null)
                AnimatedBuilder(
                  animation: _animationController!,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation!.value,
                      child: const Icon(
                        Icons.graphic_eq,
                        color: Colors.red,
                        size: 20,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: groupedMessages.isEmpty
                ? const Center(child: Text("No messages yet", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              itemCount: groupedMessages.length,
              itemBuilder: (context, index) {
                final entry = groupedMessages.entries.elementAt(index);
                final dateString = entry.key;
                final messages = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Text(
                        formatDateHeader(dateString),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                    ),
                    ...messages.map((message) => GestureDetector(
                      onLongPress: message.isUser
                          ? () => _showOptionsDialog(context, message.id ?? '', message.text)
                          : null,
                      child: Align(
                        alignment: message.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: message.isUser ? Colors.blue[100] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: message.isUser
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(message.text, style: const TextStyle(color: Colors.black)),
                              const SizedBox(height: 5),
                              Text(
                                DateFormat('hh:mm a').format(message.timestamp),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(isListening ? Icons.mic_off : Icons.mic, color: Colors.red),
                  onPressed: isListening ? stopListening : startListening,
                ),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      filled: true,
                      fillColor: Colors.white24,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: () {
                    final msg = messageController.text.trim();
                    if (msg.isNotEmpty) {
                      chatProvider.sendMessage(msg);
                      messageController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsDialog(BuildContext context, String messageId, String currentText) {
    final TextEditingController editController = TextEditingController(text: currentText);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit or Delete'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(hintText: "Edit your message"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<ChatProvider>(context, listen: false).deleteMessageById(messageId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              final updatedText = editController.text.trim();
              if (updatedText.isNotEmpty) {
                Provider.of<ChatProvider>(context, listen: false)
                    .updateMessageById(messageId, updatedText);
              }
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}