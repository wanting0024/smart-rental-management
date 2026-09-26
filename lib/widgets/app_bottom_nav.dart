// lib/widgets/app_bottom_nav.dart
// Reusable bottom navigation bar.
// Uses a fixed 4-tab layout with a "rail" design â€” Material 3 NavigationBar.

import 'package:flutter/material.dart';

class NavTab {
  const NavTab({required this.id, required this.icon, required this.label});
  final String id;
  final IconData icon;
  final String label;
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.onChange,
  });

  final List<NavTab> tabs;
  final String activeId;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    final activeIndex = tabs.indexWhere((t) => t.id == activeId);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: tabs.asMap().entries.map((e) {
              final tab = e.value;
              final isActive = e.key == activeIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onChange(tab.id),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.icon,
                        size: 22,
                        color: isActive ? const Color(0xFF2E7D32) : const Color(0xFF6B7280),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                          color: isActive ? const Color(0xFF2E7D32) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
