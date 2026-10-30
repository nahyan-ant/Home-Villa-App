import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/common.dart';
import '../widgets/top_actions.dart';
import 'checklist.dart';
import 'shopping_list.dart';

/// A maid's own screen: today's checklist, and the shopping list for
/// whoever keeps it.
class MaidShell extends StatefulWidget {
  const MaidShell({super.key, required this.user});

  final Person user;

  @override
  State<MaidShell> createState() => _MaidShellState();
}

class _MaidShellState extends State<MaidShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final today = state.today;
    final keepsList = state.keepsShopping(widget.user.id);
    final onShopping = keepsList && tab == 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(onShopping ? 'Shopping list' : 'Hi, ${widget.user.name}'),
        actions: topActions(context),
      ),
      body: Swap(
        swapKey: '$onShopping',
        child: onShopping
            ? ShoppingListView(day: today, keepsList: true)
            : Checklist(
                personId: widget.user.id,
                day: today,
                adminView: false,
                onOpenShopping: keepsList ? () => setState(() => tab = 1) : null,
              ),
      ),
      bottomNavigationBar: keepsList
          ? NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.checklist), label: 'Today'),
                NavigationDestination(icon: Icon(Icons.shopping_basket_outlined), label: 'Shopping list'),
              ],
            )
          : null,
    );
  }
}
