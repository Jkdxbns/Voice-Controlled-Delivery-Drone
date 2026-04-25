import 'package:flutter/material.dart';
import '../../models/conversation.dart';
import '../../services/database/database_helper.dart';
import '../helpers/ui_helpers.dart';
import '../helpers/formatters.dart';
import '../../constants/constants.dart';

class ChatHistoryScreen extends StatefulWidget {
  final Function(int conversationId) onChatSelected;
  final VoidCallback? onConversationsChanged;

  const ChatHistoryScreen({
    super.key,
    required this.onChatSelected,
    this.onConversationsChanged,
  });

  @override
  State<ChatHistoryScreen> createState() => ChatHistoryScreenState();
}

class ChatHistoryScreenState extends State<ChatHistoryScreen> {
  List<Conversation> _conversations = [];
  bool _isLoading = false;

  bool get hasConversations => _conversations.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
    });

    // Load from database
    final conversations = await DatabaseHelper.instance.getAllConversations();

    setState(() {
      _conversations = conversations;
      _isLoading = false;
    });
    
    widget.onConversationsChanged?.call();
  }

  void addConversation(String title) {
    // Conversation is already in database, just reload
    _loadConversations();
  }

  void updateConversationTitle(int conversationId, String newTitle) async {
    final conversation = _conversations.firstWhere((c) => c.id == conversationId);
    final updated = conversation.copyWith(
      title: newTitle,
      lastModified: DateTime.now(),
    );
    
    await DatabaseHelper.instance.updateConversation(updated);
    
    setState(() {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        _conversations[index] = updated;
      }
    });
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    final confirmed = await UiHelpers.showConfirmDialog(
      context: context,
      title: AppStrings.historyDeleteTitle,
      message: 'Are you sure you want to delete "${conversation.title}"? This cannot be undone.',
      confirmText: AppStrings.actionDelete,
      confirmColor: AppColors.error,
    );

    if (confirmed == true) {
      // Delete from database
      await DatabaseHelper.instance.deleteConversation(conversation.id!);
      
      setState(() {
        _conversations.removeWhere((c) => c.id == conversation.id);
      });

      widget.onConversationsChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted')),
        );
      }
    }
  }

  Future<void> _renameConversation(Conversation conversation) async {
    final newTitle = await UiHelpers.showRenameDialog(
      context: context,
      currentTitle: conversation.title,
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      updateConversationTitle(conversation.id!, newTitle);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat renamed')),
        );
      }
    }
  }

  Future<void> _clearAllChats() async {
    final confirmed = await UiHelpers.showConfirmDialog(
      context: context,
      title: AppStrings.historyClearAllTitle,
      message: AppStrings.historyClearAllMessage,
      confirmText: 'DELETE ALL',
      confirmColor: AppColors.error,
    );

    if (confirmed != true) return;

    // Delete all from database
    await DatabaseHelper.instance.deleteAllConversations();
    
    setState(() {
      _conversations.clear();
    });
    
    widget.onConversationsChanged?.call();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All chats cleared')),
      );
    }
  }
  
  void clearAllChats() {
    _clearAllChats();
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    final colors = AppColorScheme.of(context);
    final spacing = context.spacing;
    final iconSize = context.iconSize;
    final typography = context.typography;
    final dimensions = context.dimensions;
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.emptyChat, size: iconSize.xxlarge, color: colors.textTertiary),
            SizedBox(height: spacing.large),
            Text(
              AppStrings.historyEmpty,
              style: typography.titleMedium.copyWith(color: colors.textSecondary),
            ),
            SizedBox(height: spacing.small),
            Text(
              AppStrings.historyEmptySubtitle,
              style: typography.bodyMedium.copyWith(color: colors.textTertiary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: Scrollbar(
        thumbVisibility: true,
        thickness: dimensions.scrollbarThickness,
        radius: Radius.circular(AppRadius.small),
        child: ListView.builder(
          primary: false,
          padding: EdgeInsets.symmetric(vertical: spacing.small),
          itemCount: _conversations.length,
          itemBuilder: (context, index) {
            final conversation = _conversations[index];

            return Card(
              margin: EdgeInsets.symmetric(horizontal: spacing.medium, vertical: spacing.xsmall),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    AppIcons.chat,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyLarge.copyWith(fontWeight: FontWeightStyle.medium),
                ),
                subtitle: Text(
                  Formatters.formatMessageTime(conversation.lastModified),
                  style: typography.caption,
                ),
                trailing: PopupMenuButton(
                  icon: Icon(AppIcons.moreVert),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(AppIcons.edit, color: colors.info, size: iconSize.small),
                          SizedBox(width: spacing.small),
                          Text(AppStrings.actionRename),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(AppIcons.delete, color: colors.error, size: iconSize.small),
                          SizedBox(width: spacing.small),
                          Text(AppStrings.actionDelete, style: TextStyle(color: colors.error)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'rename') {
                      _renameConversation(conversation);
                    } else if (value == 'delete') {
                      _deleteConversation(conversation);
                    }
                  },
                ),
                onTap: () {
                  widget.onChatSelected(conversation.id!);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
