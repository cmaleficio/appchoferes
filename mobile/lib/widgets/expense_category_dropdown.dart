import 'package:flutter/material.dart';

class ExpenseCategoryDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const ExpenseCategoryDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Categoría',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.category),
      ),
      items: const [
        DropdownMenuItem(value: 'gasolina', child: Text('⛽ Gasolina')),
        DropdownMenuItem(value: 'peaje', child: Text('🛣️ Peajes')),
        DropdownMenuItem(value: 'hotel', child: Text('🏨 Hoteles')),
        DropdownMenuItem(value: 'otros', child: Text('📌 Otros')),
      ],
      onChanged: onChanged,
      validator: (v) => v == null || v.isEmpty ? 'Selecciona una categoría' : null,
    );
  }
}
