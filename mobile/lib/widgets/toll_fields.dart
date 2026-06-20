import 'package:flutter/material.dart';

class TollFields extends StatelessWidget {
  final bool? isMultipleTolls;
  final int? tollCount;
  final ValueChanged<bool?> onMultipleTollsChanged;
  final ValueChanged<int?> onTollCountChanged;

  const TollFields({
    super.key,
    required this.isMultipleTolls,
    required this.tollCount,
    required this.onMultipleTollsChanged,
    required this.onTollCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('¿Pago de múltiples peajes?'),
          value: isMultipleTolls ?? false,
          onChanged: onMultipleTollsChanged,
          contentPadding: EdgeInsets.zero,
        ),
        if (isMultipleTolls == true)
          TextFormField(
            initialValue: tollCount?.toString() ?? '',
            decoration: const InputDecoration(
              labelText: 'Cantidad de peajes',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
              helperText: 'Ingresa el número de peajes recorridos',
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => onTollCountChanged(int.tryParse(v)),
            validator: (v) {
              if (isMultipleTolls == true && (v == null || v.isEmpty)) {
                return 'Indica la cantidad de peajes';
              }
              return null;
            },
          ),
      ],
    );
  }
}
