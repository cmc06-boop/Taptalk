import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../data/models/category_model.dart';
import '../providers/app_state.dart';
import '../widgets/add_category_dialog.dart';
import '../widgets/category_grid_card.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/panel_card.dart';
import '../widgets/taptalk_logo.dart';

class ChooseCategoryScreen extends StatefulWidget {
  const ChooseCategoryScreen({super.key});

  @override
  State<ChooseCategoryScreen> createState() => _ChooseCategoryScreenState();
}

class _ChooseCategoryScreenState extends State<ChooseCategoryScreen> {
  bool _selecting = false;
  bool _showFloatingSelect = false;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _selectedKeys = {};
  final Set<String> _pendingDeletedKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.offset > 118;
      if (show != _showFloatingSelect && mounted) {
        setState(() => _showFloatingSelect = show);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleSelectionMode() {
    setState(() {
      _selecting = !_selecting;
      _selectedKeys.clear();
    });
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    await AddCategoryDialog.show(context);
  }

  Future<void> _deleteCategories(AppState app, Iterable<String> keys) async {
    final deleting = keys.toSet();
    if (deleting.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Text(
          deleting.length == 1
              ? 'This custom category and its phrases will be deleted.'
              : 'These ${deleting.length} custom categories and their phrases will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.cancel(app.language)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppStrings.delete(app.language)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _selectedKeys.clear();
      _selecting = false;
      _pendingDeletedKeys.addAll(deleting);
    });
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    var undone = false;
    final snackBar = messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(deleting.length == 1 ? 'Deleting category in 5 seconds' : 'Deleting ${deleting.length} categories in 5 seconds'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                undone = true;
                if (mounted) {
                  setState(() => _pendingDeletedKeys.removeAll(deleting));
                }
              },
            ),
          ),
        );
    await Future<void>.delayed(const Duration(seconds: 5));
    snackBar.close();
    if (undone) {
      return;
    }
    await app.deleteCustomCategories(deleting);
    if (mounted) setState(() => _pendingDeletedKeys.removeAll(deleting));
  }

  Future<void> _editCategory(AppState app, CategoryModel category) async {
    var editedName = category.name;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit category'),
        content: TextFormField(
          initialValue: category.name,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Category name'),
          onChanged: (value) => editedName = value,
          onFieldSubmitted: (value) =>
              Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppStrings.cancel(app.language)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, editedName.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await app.renameCustomCategory(category, name);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;
    final theme = app.theme;
    final name = app.welcomeFirstName(lang);

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      titleWidget: const TapTalkHeaderWordmark(),
      currentRoute: AppRoute.chooseCategory,
      headerBottomSpacing: 0,
      bodyTopOffset: -4,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => app.refreshLearnerCollections(),
            color: theme.bgAccent,
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                PanelCard(
                  borderRadius: 14,
                  margin: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.welcomeUser(name, lang),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.textMain,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        AppStrings.chooseCategorySub(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: theme.textMain.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppStrings.chooseCategoryTitle(lang),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: theme.textMain,
                                height: 1.1,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _toggleSelectionMode,
                            style: TextButton.styleFrom(
                              backgroundColor: _selecting
                                  ? Colors.transparent
                                  : theme.bgAccent.withValues(alpha: 0.10),
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _selecting ? AppStrings.cancel(lang) : 'Select',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      GridView.builder(
                        key: ValueKey(
                          'cats_${lang.name}_${app.languageRevision}_${app.topLevelCategories.length}',
                        ),
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: AppSpacing.categoryGridDelegate(context),
                        itemCount: app.topLevelCategories
                            .where((category) => !_pendingDeletedKeys.contains(category.key))
                            .length,
                        itemBuilder: (context, i) {
                          final visibleCategories = app.topLevelCategories
                              .where((category) => !_pendingDeletedKeys.contains(category.key))
                              .toList();
                          final cat = visibleCategories[i];
                          final isCustom = app.isCustomCategory(cat);
                          return CategoryGridCard(
                            category: cat,
                            label: app.localizedCategoryName(cat),
                            selected: cat.key == app.selectedCategoryKey,
                            onTap: () => app.completeCategorySelection(cat.key),
                            onDelete: isCustom
                                ? () => _deleteCategories(app, [cat.key])
                                : null,
                            onEdit: isCustom ? () => _editCategory(app, cat) : null,
                            selectionMode: _selecting && isCustom,
                            multiSelected: _selectedKeys.contains(cat.key),
                            onSelectionToggle: isCustom
                                ? () => setState(() {
                                    if (!_selectedKeys.add(cat.key)) {
                                      _selectedKeys.remove(cat.key);
                                    }
                                  })
                                : null,
                            customStyle: isCustom,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.md,
            child: FloatingActionButton(
                  onPressed: _selecting
                      ? () {
                          if (_selectedKeys.isNotEmpty) {
                            _deleteCategories(app, _selectedKeys);
                          }
                        }
                      : () => _showAddCategoryDialog(context),
                  backgroundColor: theme.bgAccent,
                  foregroundColor: Colors.white,
                  tooltip: _selecting
                      ? AppStrings.delete(lang)
                      : AppStrings.addCategoryShort(lang),
                  child: Icon(
                    _selecting
                        ? Icons.delete_outline_rounded
                        : Icons.add_rounded,
                  ),
                ),
          ),
          if (_selecting && _showFloatingSelect)
            Positioned(
              right: AppSpacing.lg,
              top: AppSpacing.sm,
              child: Material(
                color: Colors.white,
                elevation: 4,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _toggleSelectionMode,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    child: Text(
                      AppStrings.cancel(lang),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.textMain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
