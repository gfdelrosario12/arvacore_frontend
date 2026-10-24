import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_button.dart';
import '../../data/repositories/farming_chat_repository.dart';
import '../../domain/models/farming_chat_models.dart';
import 'widgets/planting_task_checklist_widget.dart';

class FarmingChatbotScreen extends StatefulWidget {
  final FarmingChatRepository? repository;
  final int fieldId;

  const FarmingChatbotScreen({
    super.key,
    this.repository,
    this.fieldId = 1,
  });

  @override
  State<FarmingChatbotScreen> createState() => _FarmingChatbotScreenState();
}

class _FarmingChatbotScreenState extends State<FarmingChatbotScreen> {
  late final FarmingChatRepository _repo;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessageItem> _messages = [];
  String? _sessionId;
  FarmingChatState? _latestState;
  bool _isLoading = false;

  final List<String> _quickCropPills = [
    'Lowland Rice (NSIC Rc 222)',
    'Hybrid Yellow Corn',
    'Eggplant',
    'Tomato',
    'Red Onion',
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? FarmingChatRepository();
    // Start every new planting conversation with the canonical initial prompt
    _messages.add(
      ChatMessageItem(
        sender: 'ASSISTANT',
        text: 'What do you want to plant today?',
        state: const FarmingChatState(
          sessionId: '',
          currentStep: 'CROP_SELECTION',
          replyText: 'What do you want to plant today?',
          promptQuestion: 'What do you want to plant today?',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text, {String? selectedCrop}) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || _isLoading) return;

    _textController.clear();
    setState(() {
      _messages.add(ChatMessageItem(sender: 'USER', text: cleanText));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final state = await _repo.sendMessage(
        sessionId: _sessionId,
        message: cleanText,
        fieldId: widget.fieldId,
        selectedCrop: selectedCrop,
      );

      _sessionId = state.sessionId;
      _latestState = state;

      setState(() {
        _messages.add(
          ChatMessageItem(
            sender: 'ASSISTANT',
            text: state.replyText,
            state: state,
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessageItem(
            sender: 'ASSISTANT',
            text: 'Unable to communicate with ArvaCore Farming Assistant: $e',
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _confirmPlan(int planId) async {
    setState(() => _isLoading = true);
    try {
      await _repo.confirmPlan(planId);
      await _sendMessage('Yes, proceed with preparation');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Safety/Authorization Error: $e'),
          backgroundColor: AppColors.alertDanger,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleTask(int planId, int taskId) async {
    try {
      final updatedState = await _repo.toggleTask(planId, taskId);
      setState(() {
        _latestState = updatedState;
        // Update the latest assistant message state
        if (_messages.isNotEmpty && !_messages.last.isUser) {
          _messages[_messages.length - 1] = ChatMessageItem(
            sender: 'ASSISTANT',
            text: _messages.last.text,
            state: updatedState,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating task: $e'),
          backgroundColor: AppColors.alertDanger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.psychology_alt_outlined, color: AppColors.primary),
            const SizedBox(width: AppDimensions.spaceSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Arva Farming Companion', style: TextStyle(fontSize: 16)),
                Text(
                  'Deterministic Safety • AWD Guidelines',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Start New Planting Conversation',
            onPressed: () {
              setState(() {
                _sessionId = null;
                _latestState = null;
                _messages.clear();
                _messages.add(
                  ChatMessageItem(
                    sender: 'ASSISTANT',
                    text: 'What do you want to plant today?',
                    state: const FarmingChatState(
                      sessionId: '',
                      currentStep: 'CROP_SELECTION',
                      replyText: 'What do you want to plant today?',
                      promptQuestion: 'What do you want to plant today?',
                    ),
                  ),
                );
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Readiness Score Ribbon if plan exists
          if (_latestState?.planId != null) _buildReadinessRibbon(theme),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg, theme);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: LinearProgressIndicator(color: AppColors.primary),
            ),
          // Crop Quick Select Pills if on CROP_SELECTION step
          if (_latestState == null || _latestState?.currentStep == 'CROP_SELECTION')
            _buildCropPillBar(theme),
          _buildInputBar(theme),
        ],
      ),
    );
  }

  Widget _buildReadinessRibbon(ThemeData theme) {
    final score = _latestState?.readinessScore ?? 0;
    final status = _latestState?.readinessStatus ?? 'ASSESSING';
    final isBlocked = status == 'BLOCKED';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isBlocked
          ? AppColors.alertDanger.withValues(alpha: 0.15)
          : AppColors.primary.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(
            isBlocked ? Icons.warning_amber_rounded : Icons.eco_outlined,
            size: 20,
            color: isBlocked ? AppColors.alertDanger : AppColors.primary,
          ),
          const SizedBox(width: AppDimensions.spaceSm),
          Text(
            'Planting Readiness: $score%',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isBlocked ? AppColors.alertDanger : AppColors.primary,
            ),
          ),
          const Spacer(),
          if (_latestState?.userRole != null) ...[
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.chipTheme.backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _latestState!.userRole!.replaceAll('ROLE_', ''),
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isBlocked ? AppColors.alertDanger : AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropPillBar(ThemeData theme) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _quickCropPills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final crop = _quickCropPills[index];
          return ActionChip(
            label: Text(crop, style: const TextStyle(fontSize: 12)),
            backgroundColor: theme.chipTheme.backgroundColor,
            onPressed: () => _sendMessage(crop, selectedCrop: crop),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageItem msg, ThemeData theme) {
    final isUser = msg.isUser;
    final state = msg.state;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        padding: const EdgeInsets.all(AppDimensions.spaceSm),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary
              : theme.cardColor,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: isUser ? null : Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: isUser ? Colors.white : theme.textTheme.bodyMedium?.color,
                fontSize: 14,
              ),
            ),
            if (!isUser && state != null && state.tasks.isNotEmpty && state.planId != null) ...[
              PlantingTaskChecklistWidget(
                tasks: state.tasks,
                planId: state.planId!,
                onToggleTask: (taskId) => _toggleTask(state.planId!, taskId),
              ),
            ],
            if (!isUser && state != null && state.requiresConfirmation && state.planId != null) ...[
              const SizedBox(height: AppDimensions.spaceSm),
              _buildConfirmationPrompt(state.planId!, theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationPrompt(int planId, ThemeData theme) {
    final canAuthorize = _latestState?.canControlIrrigation ?? false;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, color: AppColors.secondary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Do you want to proceed with the proposed planting preparation?',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          if (!canAuthorize) ...[
            const SizedBox(height: 6),
            Text(
              'Notice: You are logged in with role ${_latestState?.userRole?.replaceAll("ROLE_", "") ?? "USER"}. Automated pre-soak irrigation requires Operator or Admin authorization.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: AppDimensions.spaceSm),
          Row(
            children: [
              Expanded(
                child: AquaButton(
                  label: canAuthorize ? 'Authorize & Proceed' : 'Request Operator',
                  icon: canAuthorize ? Icons.check : Icons.lock_outline,
                  onPressed: () => _confirmPlan(planId),
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: AquaButton(
                  label: 'Not Now',
                  type: AquaButtonType.secondary,
                  icon: Icons.close,
                  onPressed: () => _sendMessage('No, not right now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'Ask or type your crop/field answer...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onSubmitted: (v) => _sendMessage(v),
              ),
            ),
            const SizedBox(width: AppDimensions.spaceSm),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
              onPressed: () => _sendMessage(_textController.text),
            ),
          ],
        ),
      ),
    );
  }
}

