import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/nim_service.dart';
import '../../core/services/stopout_calculator.dart';
import '../../core/theme/app_theme.dart';

class _ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final bool isStreaming;

  const _ChatMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
  });

  _ChatMessage copyWith({String? content, bool? isStreaming}) {
    return _ChatMessage(
      role: role,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    final nim = ref.read(nimServiceProvider);
    if (nim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure your NIM API key in Settings first.'),
        ),
      );
      return;
    }

    final settings = ref.read(settingsProvider).valueOrNull;
    final balance =
        ref.read(confirmedBalanceProvider).valueOrNull ?? 0.0;
    final openTrades =
        ref.read(openTradesProvider).valueOrNull ?? [];
    final calculator = ref.read(stopoutCalculatorProvider);

    final marginLevel = calculator?.marginLevelPct(
          equity: balance,
          openTrades: openTrades
              .map((t) => TradeSummary(
                    pair: t.symbol,
                    lots: t.lots,
                    entryPrice: t.entryPrice,
                  ))
              .toList(),
        ) ??
        double.infinity;

    final tradesJson = openTrades.isEmpty
        ? 'None'
        : openTrades
            .map((t) =>
                '${t.direction.toUpperCase()} ${t.symbol} ${t.lots} lots @ ${t.entryPrice}')
            .join(', ');

    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _sending = true;
    });
    _messageCtrl.clear();
    _scrollToBottom();

    // Placeholder for streaming assistant message
    setState(() {
      _messages.add(const _ChatMessage(
          role: 'assistant', content: '', isStreaming: true));
    });

    // Build full message history for context
    final systemMsg = NimService.buildSystemPrompt(
      accountType: settings?.accountType ?? 'usd',
      balance: balance,
      openTradesJson: tradesJson,
      marginLevelPct: marginLevel,
    );

    final history = [
      systemMsg,
      ..._messages
          .take(_messages.length - 1) // exclude the empty streaming placeholder
          .map((m) => NimMessage(role: m.role, content: m.content)),
    ];

    try {
      final buffer = StringBuffer();
      await for (final token in nim.stream(history)) {
        buffer.write(token);
        setState(() {
          _messages[_messages.length - 1] = _messages.last.copyWith(
            content: buffer.toString(),
            isStreaming: true,
          );
        });
        _scrollToBottom();
      }
      // Mark streaming complete
      setState(() {
        _messages[_messages.length - 1] = _messages.last.copyWith(
          content: buffer.toString(),
          isStreaming: false,
        );
      });
    } catch (e) {
      setState(() {
        _messages[_messages.length - 1] = _messages.last.copyWith(
          content: 'Error: $e',
          isStreaming: false,
        );
      });
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => setState(() => _messages.clear()),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _WelcomePanel()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) => _BubbleTile(
                      message: _messages[i],
                    ),
                  ),
          ),
          _InputBar(
            controller: _messageCtrl,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome,
                size: 48, color: AppTheme.primaryGreen),
            const SizedBox(height: 16),
            Text(
              'AI Trading Assistant',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask me anything about your open trades, margin levels, '
              'or risk management. Your live account context is injected automatically.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: const [
                _SuggestionChip('Is my gold position too large?'),
                _SuggestionChip('What happens if XAU drops 50 pips?'),
                _SuggestionChip('Summarise my risk exposure'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: AppTheme.cardDark,
      side: const BorderSide(color: Color(0xFF2A2A4A)),
      onPressed: () {
        // We can't easily wire to parent state here, so just a visual hint
      },
    );
  }
}

class _BubbleTile extends StatelessWidget {
  const _BubbleTile({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primaryGreen,
              child: Icon(Icons.auto_awesome, size: 14, color: Colors.black),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.accentBlue : AppTheme.cardDark,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isUser ? 12 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 12),
                ),
              ),
              child: message.isStreaming && message.content.isEmpty
                  ? const _TypingIndicator()
                  : Text(
                      message.content,
                      style: const TextStyle(fontSize: 14),
                    ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.accentBlue,
              child: Icon(Icons.person, size: 14),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 16,
      width: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Dot(delay: 0),
          _Dot(delay: 200),
          _Dot(delay: 400),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});
  final int delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: const CircleAvatar(
          radius: 4, backgroundColor: AppTheme.primaryGreen),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + insets.bottom),
      color: AppTheme.surfaceDark,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Ask about your trades…',
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send, color: AppTheme.primaryGreen),
          ),
        ],
      ),
    );
  }
}

