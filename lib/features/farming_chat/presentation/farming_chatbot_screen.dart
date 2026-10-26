import 'package:flutter/material.dart';
import '../../../../core/config/iot_simulation_mode.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/aqua_button.dart';
import '../../../../core/widgets/arva_logo.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../data/repositories/farming_chat_repository.dart';
import '../domain/models/farming_chat_models.dart';
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

  List<String> _getAdaptiveActionPrompts() {
    final step = _latestState?.currentStep ?? 'CROP_SELECTION';
    if (step == 'CROP_SELECTION') {
      return [
        '🌾 Plan rice season',
        'Assess field readiness',
        'Check soil & water depth',
        'PAGASA rain forecast impact',
        'PhilRice INM fertilizer guide',
      ];
    } else if (step == 'FIELD_AND_METHOD') {
      return [
        'Direct Wet Seeding (40-60 kg/ha)',
        'Wet Bed Transplanting (20-40 kg/ha)',
        'Dapog method',
        'Terrace 1 schedule next week',
      ];
    } else if (step == 'CONFIRMATION_PENDING') {
      return [
        'Yes, proceed with preparation',
        'What about fertilizer splits?',
        'What if it rains tomorrow?',
        'No, keep on hold',
      ];
    } else {
      // PREPARATION_ACTIVE or CROP_MANAGEMENT
      return [
        'AWD water level & depth',
        'Urea & LCC topdressing',
        'Golden Apple Snail (Kuhol) control',
        'Plowing & harrowing schedule',
        'Harvest maturity indicators',
      ];
    }
  }

  void _showReferencesModal(BuildContext context) {
    final theme = Theme.of(context);
    final activeRefs = _latestState?.agronomicReferences ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Agricultural References & Data Sources',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Verified Philippine agronomic knowledge & live telemetry feeds',
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildReferenceCard(
                        theme: theme,
                        category: 'Philippine Rice Farming Manual',
                        title: 'Philippine Rice Production Training Manual (230 pp.)',
                        institution: 'Philippine Rice Research Institute (PhilRice, 2003)',
                        type: 'Indexed Document / Exact Page-Level PDF Extraction',
                        status: 'Synchronized & Verified (224 chunks cached)',
                        statusColor: Colors.green,
                        location: '/documentation/philippine-rice-production-training-manual.pdf',
                        citationHint: 'PhilRice Training Manual (2003), Modules 4, 5, 6, 7, 8, 19',
                        icon: Icons.auto_stories,
                      ),
                      const SizedBox(height: 12),
                      _buildReferenceCard(
                        theme: theme,
                        category: 'Agro-Meteorological Forecast',
                        title: 'PAGASA 3-Day & Seasonal Agro-Meteorological Forecast',
                        institution: 'DOST - PAGASA (Daet / Lopez Radar Grounding)',
                        type: 'External Weather Service / MCP Adapter',
                        status: 'Active (Automated Rain Shutoff Threshold: 30 mm/24h)',
                        statusColor: Colors.blue,
                        location: 'PAGASA Agro-Met Station Lopez / Daet (Radar Grounded)',
                        citationHint: 'PAGASA Daily Forecast & Severe Weather Advisory',
                        icon: Icons.cloud_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildReferenceCard(
                        theme: theme,
                        category: 'Municipal Agronomic Data',
                        title: 'Lopez, Quezon Municipal Agricultural Profile',
                        institution: 'DA-RFO IV-A / Municipal Agriculture Office (MAO Lopez)',
                        type: 'Soil & Climate Profile Database / MCP Adapter',
                        status: 'Active (Soil: Calumpang Clay Series, Climate: Type IV)',
                        statusColor: Colors.teal,
                        location: 'Lopez, Quezon MAO Agricultural Benchmark Records',
                        citationHint: 'Lopez, Quezon Municipal Soil Survey & Varietal Suitability',
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildReferenceCard(
                        theme: theme,
                        category: 'Field Telemetry & Monitoring Nodes',
                        title: 'ArvaNode Authentic Sensor Telemetry (ARVANODE-001)',
                        institution: 'ArvaCore IoT Sensor Fabric',
                        type: 'Rootzone Soil Moisture & Ultrasonic Water Tube Gauge',
                        status: 'Online & Polled (Staleness Guard: 60 min limit)',
                        statusColor: Colors.orange,
                        location: 'Hardware Sensor Bus / Zero Direct Actuation Invariant',
                        citationHint: 'ArvaNode Field Water Table (-15 cm AWD threshold) & Soil %',
                        icon: Icons.sensors,
                      ),
                      const SizedBox(height: 12),
                      _buildReferenceCard(
                        theme: theme,
                        category: 'Farm & Field Database',
                        title: 'ArvaNet Farm, Field Topology & User Access Policy',
                        institution: 'ArvaCore Backend PostgreSQL Database',
                        type: 'RBAC Authorization & Audit Trail Engine',
                        status: 'Verified Safe (Zero privilege elevation via AI)',
                        statusColor: Colors.indigo,
                        location: 'PostgreSQL Relational Storage / Audit Logs',
                        citationHint: 'Role-Based Access Control & Physical E-Stop Interlock',
                        icon: Icons.security_rounded,
                      ),
                      if (activeRefs.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Citations Active in Current Chat Session:',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        ...activeRefs.map((r) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      r,
                                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReferenceCard({
    required ThemeData theme,
    required String category,
    required String title,
    required String institution,
    required String type,
    required String status,
    required Color statusColor,
    required String location,
    required String citationHint,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: statusColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.contains('Active') || status.contains('Synchronized') || status.contains('Online')
                      ? 'VERIFIED'
                      : 'AVAILABLE',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            'Institution: $institution',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.hintColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Type: $type',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.link, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Format: $citationHint',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? FarmingChatRepository();
    // Start every new planting conversation with the canonical initial prompt
    _messages.add(
      ChatMessageItem(
        sender: 'ASSISTANT',
        text: AppStrings.arvaAiGreeting,
        state: const FarmingChatState(
          sessionId: '',
          currentStep: 'CROP_SELECTION',
          replyText: AppStrings.arvaAiGreeting,
          promptQuestion: AppStrings.arvaAiGreeting,
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
    final isSimulation = globalIotTestModeNotifier.value;
    try {
      await _repo.confirmPlan(planId);
      if (isSimulation) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Workflow Test Passed — Automated planting irrigation tasks confirmed in simulation mode. No physical device was activated.',
              ),
              backgroundColor: Colors.purple,
            ),
          );
        }
      }
      await _sendMessage(isSimulation
          ? 'Yes, proceed with preparation (Simulation Mode Active)'
          : 'Yes, proceed with preparation');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Safety/Authorization Error: $e'),
          backgroundColor: AppColors.alertError,
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
          backgroundColor: AppColors.alertError,
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
            const ArvaLogo(size: 32),
            const SizedBox(width: AppDimensions.spaceSm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(AppStrings.arvaAiName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  'Agricultural AI • PhilRice & IRRI Guidelines',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: 'View Agronomic References & Data Sources',
            onPressed: () => _showReferencesModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Start New Conversation with Arva',
            onPressed: () {
              setState(() {
                _sessionId = null;
                _latestState = null;
                _messages.clear();
                _messages.add(
                  ChatMessageItem(
                    sender: 'ASSISTANT',
                    text: AppStrings.arvaAiGreeting,
                    state: const FarmingChatState(
                      sessionId: '',
                      currentStep: 'CROP_SELECTION',
                      replyText: AppStrings.arvaAiGreeting,
                      promptQuestion: AppStrings.arvaAiGreeting,
                    ),
                  ),
                );
              });
            },
          ),
        ],
      ),
      body: ResponsiveContainer(
        child: Column(
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
            // Quick Action Suggestions always available and adaptive
            _buildActionPromptBar(theme),
            const SizedBox(height: 4),
            // Crop Quick Select Pills if on CROP_SELECTION step
            if (_latestState == null || _latestState?.currentStep == 'CROP_SELECTION') ...[
              _buildCropPillBar(theme),
            ],
            _buildInputBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPromptBar(ThemeData theme) {
    final prompts = _getAdaptiveActionPrompts();
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = prompts[index];
          final isRice = prompt.contains('🌾') || prompt.toLowerCase().contains('rice');
          return ActionChip(
            avatar: Icon(
              isRice ? Icons.grass : Icons.bolt,
              size: 16,
              color: isRice ? Colors.green : AppColors.primary,
            ),
            label: Text(
              prompt,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            backgroundColor: isRice
                ? Colors.green.withValues(alpha: 0.12)
                : AppColors.primary.withValues(alpha: 0.1),
            side: BorderSide(
              color: isRice
                  ? Colors.green.withValues(alpha: 0.35)
                  : AppColors.primary.withValues(alpha: 0.3),
            ),
            onPressed: () => _sendMessage(prompt.replaceAll('🌾 ', '')),
          );
        },
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
          ? AppColors.alertError.withValues(alpha: 0.15)
          : AppColors.primary.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(
            isBlocked ? Icons.warning_amber_rounded : Icons.eco_outlined,
            size: 20,
            color: isBlocked ? AppColors.alertError : AppColors.primary,
          ),
          const SizedBox(width: AppDimensions.spaceSm),
          Text(
            'Planting Readiness: $score%',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isBlocked ? AppColors.alertError : AppColors.primary,
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
              color: isBlocked ? AppColors.alertError : AppColors.primary,
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
          final isRice = crop.toLowerCase().contains('rice') || crop.toLowerCase().contains('palay');
          return ActionChip(
            avatar: isRice
                ? const Icon(Icons.grass, size: 16, color: Colors.green)
                : null,
            label: Text(
              crop,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isRice ? FontWeight.bold : FontWeight.normal,
                color: isRice ? Colors.green.shade800 : null,
              ),
            ),
            backgroundColor: isRice
                ? Colors.green.withValues(alpha: 0.15)
                : theme.chipTheme.backgroundColor,
            side: isRice
                ? BorderSide(color: Colors.green.withValues(alpha: 0.4), width: 1.2)
                : null,
            onPressed: () => _sendMessage(crop, selectedCrop: crop),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageItem msg, ThemeData theme) {
    final isUser = msg.isUser;
    final state = msg.state;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bubbleMaxWidth = screenWidth >= AppDimensions.breakpointMobile
        ? 520.0
        : screenWidth * 0.85;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: bubbleMaxWidth,
        ),
        padding: const EdgeInsets.all(AppDimensions.spaceSm),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary
              : AppColors.surfaceLightOf(context),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppDimensions.radiusMd),
            topRight: const Radius.circular(AppDimensions.radiusMd),
            bottomLeft: Radius.circular(isUser ? AppDimensions.radiusMd : 2),
            bottomRight: Radius.circular(isUser ? 2 : AppDimensions.radiusMd),
          ),
          border: isUser
              ? null
              : Border.all(color: AppColors.borderOf(context), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ArvaLogo(size: 18),
                  const SizedBox(width: 6),
                  Text(
                    AppStrings.arvaAiName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              msg.text,
              style: TextStyle(
                color: isUser ? Colors.white : AppColors.textPrimaryOf(context),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (!isUser && state != null && state.tasks.isNotEmpty && state.planId != null) ...[
              const SizedBox(height: AppDimensions.spaceSm),
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
                  variant: AquaButtonVariant.secondary,
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

