import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Nisha writes the day's shopping list and hands it over; admin ticks items
/// as they are bought.
class ShoppingListView extends StatefulWidget {
  const ShoppingListView({super.key, required this.day, required this.keepsList});

  final DateTime day;

  /// The maid who writes the list, rather than admin who buys.
  final bool keepsList;

  @override
  State<ShoppingListView> createState() => _ShoppingListViewState();
}

class _ShoppingListViewState extends State<ShoppingListView> {
  final _name = TextEditingController();
  final _qty = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add(AppState state) {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    state.addShopItem(widget.day, name, _qty.text.trim());
    _name.clear();
    _qty.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final list = state.shoppingList(widget.day);
    final items = state.shoppingItems(widget.day);
    final handedOver = state.viewerIsAdmin ? list.handedOverSent : list.handedOver;
    final nisha = widget.keepsList;
    final editable = nisha && handedOver == null;

    final title = handedOver == null
        ? (nisha ? 'Add items during the day' : 'Still being filled in')
        : 'Handed over at ${clockOf(handedOver)}';
    final subtitle = handedOver == null
        ? (nisha
              ? 'Hand the list over at the end of the day so items can be bought in time.'
              : 'You will see "Handed over" when the list is finished.')
        : (nisha ? 'Admin can now see the full list.' : 'Tick items as they are bought.');

    final children = <Widget>[
      Text(longDate(widget.day).toUpperCase(), style: sectionLabel),
      const SizedBox(height: 6),
      Text(title, style: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 26, height: 1.15)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: Palette.muted, fontSize: 14, height: 1.4)),
      if (nisha && list.handedOver != list.handedOverSent) const PendingNote(),
      if (nisha && !state.online) ...[
        const SizedBox(height: 10),
        const Text(
          'No internet: changes are saved on this phone and sent when the internet is back.',
          style: TextStyle(color: Palette.amber, fontSize: 13, fontWeight: FontWeight.w700, height: 1.35),
        ),
      ],
      const SizedBox(height: 18),
      if (editable) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _name,
                focusNode: _focus,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Item'),
                onSubmitted: (_) => _add(state),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _qty,
                decoration: const InputDecoration(labelText: 'Quantity'),
                onSubmitted: (_) => _add(state),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.add, color: Palette.white),
              tooltip: 'Add item',
              style: IconButton.styleFrom(backgroundColor: Palette.ink, fixedSize: const Size(48, 48)),
              onPressed: () => _add(state),
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
      if (items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('No items yet.', style: TextStyle(color: Palette.muted, fontSize: 15)),
        ),
      for (final item in items)
        Stagger(
          key: ValueKey(item.id),
          index: 0,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: Palette.white,
              border: Border.all(color: Colors.transparent),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                if (!nisha)
                  Checkbox(
                    value: item.bought,
                    onChanged: handedOver == null ? null : (_) => state.toggleBought(widget.day, item),
                  )
                else
                  const SizedBox(width: 4, height: 52),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          color: item.bought ? Palette.faint : Palette.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          decoration: item.bought ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (!item.sent && nisha) const PendingNote(),
                    ],
                  ),
                ),
                Text(item.qty, style: const TextStyle(color: Palette.muted, fontSize: 15)),
                if (editable)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Remove ${item.name}',
                    onPressed: () => state.removeShopItem(widget.day, item),
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      if (nisha) ...[
        const SizedBox(height: 24),
        if (handedOver == null)
          FilledButton(
            onPressed: items.isEmpty ? null : () => state.handOver(widget.day, true),
            child: const Text('Hand over list'),
          )
        else
          OutlinedButton(
            onPressed: () => state.handOver(widget.day, false),
            child: const Text('Reopen to add more'),
          ),
      ],
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 32), children: children);
  }
}
