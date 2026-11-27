import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Responsive header action button that displays icon + label when space allows,
/// and collapses to an icon-only button with a [Tooltip] on narrow screens.
class KosMateHeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isTextButton;
  final double collapseBreakpoint;

  const KosMateHeaderActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isTextButton = false,
    this.collapseBreakpoint = 380,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < collapseBreakpoint;

    if (compact) {
      if (isTextButton) {
        return Tooltip(
          message: label,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, size: 20, color: AppTheme.accentColor),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(36, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      }

      return Tooltip(
        message: label,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 18, color: Colors.white),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.accentColor,
            padding: const EdgeInsets.all(9),
            minimumSize: const Size(38, 38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    if (isTextButton) {
      return TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.accentColor,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Standardized search bar with clear button.
class KosMateSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final Color fillColor;

  const KosMateSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.fillColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSubtle),
        prefixIcon: const Icon(
          Icons.search,
          color: AppTheme.textMuted,
          size: 20,
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.clear,
                  size: 18,
                  color: AppTheme.destructiveColor,
                ),
                onPressed: () {
                  controller.clear();
                  if (onClear != null) {
                    onClear!();
                  } else {
                    onChanged('');
                  }
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 14,
        ),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.borderMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.borderMedium),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.accentColor, width: 1.5),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

/// Defines a sort option for a list of type [T].
class KosMateSortOption<T> {
  final String id;
  final String label;
  final int Function(T a, T b) comparator;

  const KosMateSortOption({
    required this.id,
    required this.label,
    required this.comparator,
  });
}

/// Combines optional horizontal filter chips with a compact Sort menu and count.
class KosMateFilterSortBar<T> extends StatelessWidget {
  final List<String> filterOptions;
  final String selectedFilter;
  final ValueChanged<String>? onFilterChanged;
  final List<KosMateSortOption<T>> sortOptions;
  final String selectedSortId;
  final ValueChanged<String> onSortChanged;
  final int totalCount;
  final String itemLabel;

  const KosMateFilterSortBar({
    super.key,
    this.filterOptions = const [],
    this.selectedFilter = 'All',
    this.onFilterChanged,
    required this.sortOptions,
    required this.selectedSortId,
    required this.onSortChanged,
    required this.totalCount,
    this.itemLabel = 'items',
  });

  @override
  Widget build(BuildContext context) {
    final currentSort = sortOptions.firstWhere(
      (s) => s.id == selectedSortId,
      orElse: () => sortOptions.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (filterOptions.isNotEmpty && onFilterChanged != null) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filterOptions.map((option) {
                final isSelected = selectedFilter == option;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(option),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: AppTheme.primaryLight,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.accentColor
                          : AppTheme.borderMedium,
                    ),
                    labelStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: isSelected
                          ? AppTheme.accentColor
                          : AppTheme.textDark,
                    ),
                    onSelected: (_) => onFilterChanged!(option),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '$totalCount $itemLabel',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              initialValue: currentSort.id,
              onSelected: onSortChanged,
              itemBuilder: (ctx) => sortOptions
                  .map(
                    (s) => PopupMenuItem<String>(
                      value: s.id,
                      child: Row(
                        children: [
                          Icon(
                            s.id == selectedSortId
                                ? Icons.check_rounded
                                : Icons.sort_rounded,
                            size: 16,
                            color: s.id == selectedSortId
                                ? AppTheme.accentColor
                                : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: s.id == selectedSortId
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: s.id == selectedSortId
                                  ? AppTheme.accentColor
                                  : AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderMedium),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sort_rounded,
                      size: 15,
                      color: AppTheme.accentColor,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        currentSort.label,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppTheme.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Paginates [items] cleanly, clamping [currentPage] within valid bounds.
({
  List<T> pageItems,
  int safePage,
  int totalPages,
  int startIndex,
  int endIndex,
})
paginateList<T>(List<T> items, int currentPage, int pageSize) {
  if (items.isEmpty) {
    return (
      pageItems: <T>[],
      safePage: 1,
      totalPages: 1,
      startIndex: 0,
      endIndex: 0,
    );
  }
  final totalPages = (items.length / pageSize).ceil().clamp(1, 999999);
  final safePage = currentPage.clamp(1, totalPages);
  final start = (safePage - 1) * pageSize;
  final end = (start + pageSize).clamp(0, items.length);
  return (
    pageItems: items.sublist(start, end),
    safePage: safePage,
    totalPages: totalPages,
    startIndex: start + 1,
    endIndex: end,
  );
}

/// Clean mobile-friendly pagination footer.
class KosMatePaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int startIndex;
  final int endIndex;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;

  const KosMatePaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.startIndex,
    required this.endIndex,
    required this.pageSize,
    required this.onPageChanged,
    this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalItems == 0) return const SizedBox.shrink();

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 10,
          children: [
            Text(
              'Showing $startIndex–$endIndex of $totalItems',
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onPageSizeChanged != null) ...[
                  PopupMenuButton<int>(
                    initialValue: pageSize,
                    onSelected: onPageSizeChanged,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 5, child: Text('5 / page')),
                      PopupMenuItem(value: 10, child: Text('10 / page')),
                      PopupMenuItem(value: 20, child: Text('20 / page')),
                      PopupMenuItem(value: 50, child: Text('50 / page')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.borderMedium),
                      ),
                      child: Text(
                        '$pageSize/pg',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                _pageBtn(
                  icon: Icons.chevron_left_rounded,
                  enabled: currentPage > 1,
                  onTap: () => onPageChanged(currentPage - 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '$currentPage / $totalPages',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.foregroundColor,
                    ),
                  ),
                ),
                _pageBtn(
                  icon: Icons.chevron_right_rounded,
                  enabled: currentPage < totalPages,
                  onTap: () => onPageChanged(currentPage + 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? AppTheme.borderMedium : AppTheme.borderLight,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppTheme.accentColor : AppTheme.textSubtle,
        ),
      ),
    );
  }
}
