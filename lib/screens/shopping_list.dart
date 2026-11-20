import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../hindi.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Maids request what the house needs (groceries, cleaning materials);
/// admin ticks items as they are bought. Unbought items stay on the list.
class ShoppingListView extends StatefulWidget {
  const ShoppingListView({super.key, required this.day, required this.canRequest});

  final DateTime day;

  /// A maid adding requests, rather than admin who buys.
  final bool canRequest;

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
    final items = state.shoppingItems(widget.day);
    final maid = widget.canRequest;
    final open = items.where((i) => !i.bought).length;

    final children = <Widget>[
      Text(longDate(widget.day).toUpperCase(), style: sectionLabel),
      const SizedBox(height: 6),
      Text(
        maid ? tr('What does the house need?') : (open == 0 ? 'Nothing to buy' : '$open to buy'),
        style: const TextStyle(fontFamily: 'DMSerifDisplay', fontSize: 26, height: 1.15),
      ),
      const SizedBox(height: 4),
      Text(
        maid
            ? tr('Add groceries, cleaning materials or anything else needed. Admin sees it at once.')
            : 'Tick items as they are bought. Items not bought stay on the list.',
        style: const TextStyle(color: Palette.muted, fontSize: 14, height: 1.4),
      ),
      if (maid && !state.online) ...[
        const SizedBox(height: 10),
        Text(
          tr('No internet: changes are saved on this phone and sent when the internet is back.'),
          style: const TextStyle(color: Palette.amber, fontSize: 13, fontWeight: FontWeight.w700, height: 1.35),
        ),
      ],
      const SizedBox(height: 18),
      if (maid) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _name,
                focusNode: _focus,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: tr1('Item'), hintText: 'For example: Floor cleaner'),
                onSubmitted: (_) => _add(state),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _qty,
                decoration: InputDecoration(labelText: tr1('Quantity')),
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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(tr('No items yet.'), style: const TextStyle(color: Palette.muted, fontSize: 15)),
        ),
      for (final item in items) Stagger(key: ValueKey(item.id), index: 0, child: _ItemRow(item: item, maid: maid)),
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 32), children: children);
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.maid});

  final ShopItem item;
  final bool maid;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final mine = item.byId == state.user?.id;
    final asked = [
      mine ? tr1('You asked') : bi1('Asked by ${state.person(item.byId).name}', '${state.person(item.byId).name} ने माँगा'),
      if (item.day != state.today) shortDate(item.day),
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.fromLTRB(maid ? 16 : 4, 6, 4, 6),
      decoration: BoxDecoration(color: Palette.white, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          if (!maid) Checkbox(value: item.bought, onChanged: (_) => state.toggleBought(item)),
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
                Text(item.bought ? '$asked · ${tr1('Bought')}' : asked, style: bodyMuted),
                if (!item.sent && mine) const PendingNote(),
              ],
            ),
          ),
          Text(item.qty, style: const TextStyle(color: Palette.muted, fontSize: 15)),
          if (maid && mine && !item.bought)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Remove ${item.name}',
              onPressed: () => state.removeShopItem(item),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}
