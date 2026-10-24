import 'package:flutter/material.dart';

class UnitSelector extends StatelessWidget {
  final String? value;
  final Function(String?) onChanged;
  final String? labelText;
  final bool enabled;

  const UnitSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText,
    this.enabled = true,
  });

  static const Map<String, UnitInfo> units = {
    'dona': UnitInfo(
      icon: Icons.circle_outlined,
      label: 'Dona',
      description: 'Sanoqli mahsulotlar',
      color: Colors.blue,
    ),
    'pachka': UnitInfo(
        icon: Icons.inventory_2_outlined,
        label: 'Pachka',
        description: 'Pachkada sotiladi',
        color: Colors.deepPurple),
    'butilka': UnitInfo(
        icon: Icons.local_drink_outlined,
        label: 'Butilka',
        description: 'Butilkadagi ichimlik',
        color: Colors.cyan),
    'gramm': UnitInfo(
        icon: Icons.scale,
        label: 'Gramm',
        description: 'Og‘irlik',
        color: Colors.green),
    'ml': UnitInfo(
        icon: Icons.water_drop,
        label: 'Millilitr',
        description: 'Hajm',
        color: Colors.cyan),
    'kg': UnitInfo(
      icon: Icons.scale_rounded,
      label: 'Kilogram (kg)',
      description: 'Og\'irlik',
      color: Colors.green,
    ),
    'litr': UnitInfo(
      icon: Icons.water_drop_outlined,
      label: 'Litr (l)',
      description: 'Hajm',
      color: Colors.cyan,
    ),
    'metr': UnitInfo(
      icon: Icons.straighten_rounded,
      label: 'Metr (m)',
      description: 'Uzunlik',
      color: Colors.orange,
    ),
    'quti': UnitInfo(
      icon: Icons.inventory_2_outlined,
      label: 'Quti',
      description: 'Qadoqlangan',
      color: Colors.purple,
    ),
    'paket': UnitInfo(
      icon: Icons.shopping_bag_outlined,
      label: 'Paket',
      description: 'Paketlangan',
      color: Colors.brown,
    ),
    'm²': UnitInfo(
      icon: Icons.crop_square_rounded,
      label: 'Kvadrat metr (m²)',
      description: 'Yuza',
      color: Colors.indigo,
    ),
    'm³': UnitInfo(
      icon: Icons.view_in_ar_rounded,
      label: 'Kub metr (m³)',
      description: 'Hajm',
      color: Colors.teal,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final selectedUnit = value != null ? units[value!] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (labelText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              labelText!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
        InkWell(
          onTap: enabled ? () => _showUnitPicker(context) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled ? Colors.grey[300]! : Colors.grey[200]!,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        (selectedUnit?.color ?? Colors.grey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    selectedUnit?.icon ?? Icons.straighten_rounded,
                    color: selectedUnit?.color ?? Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedUnit?.label ?? 'O\'lchov birligi tanlang',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (selectedUnit != null)
                        Text(
                          selectedUnit.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: enabled ? Colors.grey[600] : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showUnitPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.straighten_rounded,
                            color: Colors.blue[700]),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'O\'lchov birligi tanlang',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Units list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: units.length,
                    itemBuilder: (context, index) {
                      final entry = units.entries.elementAt(index);
                      final unitKey = entry.key;
                      final unitInfo = entry.value;
                      final isSelected = value == unitKey;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Material(
                          color: isSelected
                              ? unitInfo.color.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () {
                              onChanged(unitKey);
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected
                                      ? unitInfo.color
                                      : Colors.grey[200]!,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: unitInfo.color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      unitInfo.icon,
                                      color: unitInfo.color,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          unitInfo.label,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? unitInfo.color
                                                : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          unitInfo.description,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: unitInfo.color,
                                      size: 28,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class UnitInfo {
  final IconData icon;
  final String label;
  final String description;
  final Color color;

  const UnitInfo({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
  });
}
