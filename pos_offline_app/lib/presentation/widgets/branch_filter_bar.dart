import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/branch_model.dart';
import '../../services/auth/auth_service.dart';

/// Widget bar filter cabang — hanya tampil untuk role owner.
/// Menampilkan chip "Semua Cabang" + chip per cabang.
/// Saat dipilih, memanggil [onChanged] dan memperbarui [AuthService.viewBranchId].
class BranchFilterBar extends StatelessWidget {
  /// Dipanggil saat filter berubah, untuk reload data di parent.
  final VoidCallback onChanged;
  const BranchFilterBar({Key? key, required this.onChanged}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    if (auth.currentUser?.isOwner != true) return const SizedBox.shrink();

    final branches = auth.branches;
    if (branches.isEmpty) return const SizedBox.shrink();

    return Obx(() {
      final selectedId = auth.viewBranchId.value;
      return Container(
        height: 36,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // Chip "Semua Cabang"
            _BranchChip(
              label: 'Semua Cabang',
              icon: Icons.store_rounded,
              selected: selectedId == null,
              onTap: () {
                auth.setViewBranch(null);
                onChanged();
              },
            ),
            ...branches.map((b) => _BranchChip(
              label: b.name,
              icon: Icons.storefront_rounded,
              selected: selectedId == b.id,
              onTap: () {
                auth.setViewBranch(b.id);
                onChanged();
              },
            )),
          ],
        ),
      );
    });
  }
}

class _BranchChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _BranchChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF6B35) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFFF6B35) : const Color(0xFFE0E0E0),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: selected ? Colors.white : Colors.grey[500]),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
