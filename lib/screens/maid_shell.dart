import 'package:flutter/material.dart';

import '../app_state.dart';
import '../hindi.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/top_actions.dart';
import 'checklist.dart';
import 'meal_plan.dart';
import 'shopping_list.dart';

/// A maid's own screen: today's checklist, and the shopping list where she
/// requests what the house needs.
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
    // Meal plan only for a maid who has one (Nisha).
    final hasMeals = state.hasMealPlan(widget.user.id);
    final pages = ['today', if (hasMeals) 'meals', 'shopping'];
    if (tab >= pages.length) tab = 0;
    final page = pages[tab];
    final onShopping = page == 'shopping';
    return Scaffold(
      appBar: AppBar(
        title: Text(page == 'meals' ? tr1('Meal plan') : onShopping ? tr1('Shopping list') : (state.hindi ? 'नमस्ते, ${widget.user.name}' : 'Hi, ${widget.user.name}')),
        actions: [
          // English only, or English with Hindi.
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: state.hindi ? Palette.ink : null,
              foregroundColor: state.hindi ? Palette.white : Palette.ink,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: () => state.setHindi(!state.hindi),
            child: const Text('हिन्दी'),
          ),
          ...topActions(context),
        ],
      ),
      body: Swap(
        swapKey: page,
        child: switch (page) {
          'shopping' => ShoppingListView(day: today, canRequest: true),
          'meals' => MaidMealPlan(personId: widget.user.id),
          _ => Checklist(
            personId: widget.user.id,
            day: today,
            adminView: false,
            onOpenShopping: keepsList ? () => setState(() => tab = pages.indexOf('shopping')) : null,
          ),
        },
      ),
      // Every maid can request groceries or cleaning materials.
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.checklist), label: tr1('Today')),
          if (hasMeals) NavigationDestination(icon: const Icon(Icons.restaurant_menu_outlined), label: tr1('Meal plan')),
          NavigationDestination(icon: const Icon(Icons.shopping_basket_outlined), label: tr1('Shopping list')),
        ],
      ),
    );
  }
}
