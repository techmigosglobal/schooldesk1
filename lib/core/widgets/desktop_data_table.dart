import 'package:flutter/material.dart';

import 'package:schooldesk1/core/desktop/desktop_hover_effects.dart';
import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

typedef DesktopDataRowBuilder =
    List<Widget> Function(
      BuildContext context,
      int index,
    );

/// Full-width data table with sorting and desktop-optimized density.
class DesktopDataTable<T> extends StatefulWidget {
  final List<T> items;
  final List<DesktopDataColumn> columns;
  final DesktopDataRowBuilder rowBuilder;
  final void Function(T item, int index)? onRowTap;
  final void Function(int columnIndex, bool ascending)? onSort;
  final int? sortColumnIndex;
  final bool sortAscending;
  final Widget? emptyState;
  final double rowHeight;

  const DesktopDataTable({
    super.key,
    required this.items,
    required this.columns,
    required this.rowBuilder,
    this.onRowTap,
    this.onSort,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.emptyState,
    this.rowHeight = 52,
  });

  @override
  State<DesktopDataTable<T>> createState() => _DesktopDataTableState<T>();
}

class _DesktopDataTableState<T> extends State<DesktopDataTable<T>> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = DesktopBreakpoints.isDesktopWidth(
          constraints.maxWidth,
        );
        final theme = Theme.of(context);
        final tokens = theme.schoolDesk;

        if (widget.items.isEmpty) {
          return widget.emptyState ??
              Center(
                child: Text(
                  'No records to display',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
              );
        }

        if (!isDesktop) {
          return ListView.separated(
            itemCount: widget.items.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: tokens.panelBorder),
            itemBuilder: (context, index) {
              final cells = widget.rowBuilder(context, index);
              return ListTile(
                title: cells.isNotEmpty ? cells.first : null,
                subtitle: cells.length > 1
                    ? Wrap(spacing: 8, children: cells.skip(1).toList())
                    : null,
                onTap: widget.onRowTap != null
                    ? () => widget.onRowTap!(widget.items[index], index)
                    : null,
              );
            },
          );
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: BorderRadius.circular(tokens.radius.card),
            border: Border.all(color: tokens.panelBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radius.card),
            child: Column(
              children: [
                _HeaderRow(
                  columns: widget.columns,
                  sortColumnIndex: widget.sortColumnIndex,
                  sortAscending: widget.sortAscending,
                  onSort: widget.onSort,
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final cells = widget.rowBuilder(context, index);
                      return DesktopHoverInkWell(
                        onTap: widget.onRowTap != null
                            ? () => widget.onRowTap!(widget.items[index], index)
                            : null,
                        child: Container(
                          height: widget.rowHeight,
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacing.md,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: tokens.panelBorder),
                            ),
                            color: index.isOdd
                                ? tokens.panelMuted.withAlpha(60)
                                : null,
                          ),
                          child: Row(
                            children: [
                              for (var i = 0; i < widget.columns.length; i++)
                                Expanded(
                                  flex: widget.columns[i].flex,
                                  child: i < cells.length
                                      ? cells[i]
                                      : const SizedBox.shrink(),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DesktopDataColumn {
  final String label;
  final int flex;
  final bool sortable;

  const DesktopDataColumn({
    required this.label,
    this.flex = 1,
    this.sortable = false,
  });
}

class _HeaderRow extends StatelessWidget {
  final List<DesktopDataColumn> columns;
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int columnIndex, bool ascending)? onSort;

  const _HeaderRow({
    required this.columns,
    this.sortColumnIndex,
    required this.sortAscending,
    this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.schoolDesk;

    return Container(
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.md),
      decoration: BoxDecoration(
        color: tokens.panelMuted,
        border: Border(bottom: BorderSide(color: tokens.panelBorder)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: columns[i].flex,
              child: columns[i].sortable && onSort != null
                  ? InkWell(
                      onTap: () {
                        final ascending = sortColumnIndex == i
                            ? !sortAscending
                            : true;
                        onSort!(i, ascending);
                      },
                      child: Row(
                        children: [
                          Text(
                            columns[i].label.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: tokens.textMuted,
                              letterSpacing: 0.6,
                            ),
                          ),
                          if (sortColumnIndex == i)
                            Icon(
                              sortAscending
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    )
                  : Text(
                      columns[i].label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: tokens.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
