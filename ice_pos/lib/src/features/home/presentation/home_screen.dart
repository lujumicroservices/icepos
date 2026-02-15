import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ice_pos/src/features/admin/presentation/bundle_management_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/product_management_screen.dart';
import 'package:ice_pos/src/features/admin/presentation/supply_management_screen.dart';
import 'package:ice_pos/src/features/inventory/presentation/inventory_screen.dart';
import 'package:ice_pos/src/features/pos/presentation/close_shift_screen.dart';
import 'package:ice_pos/src/features/pos/presentation/pos_screen.dart';
import 'package:ice_pos/src/features/reports/presentation/sales_history_screen.dart';

final selectedTabIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _screens = [
    PosScreen(),
    InventoryScreen(),
    SalesHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForIndex(selectedIndex)),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF1E88E5)),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Supply Management'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SupplyManagementScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('Product Management'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ProductManagementScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('Bundle Management'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const BundleManagementScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('Close Shift'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const CloseShiftScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          ref.read(selectedTabIndexProvider.notifier).state = index;
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_outlined),
            activeIcon: Icon(Icons.point_of_sale),
            label: 'POS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  static String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Point of Sale';
      case 1:
        return 'Inventory';
      case 2:
        return 'Sales History';
      default:
        return 'ICE POS';
    }
  }
}
