import 'package:flutter/material.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../data/profile_repository.dart';
import 'equipment_illustration.dart';

class EquipmentPicker extends StatefulWidget {
  const EquipmentPicker({super.key, required this.items, required this.selected, required this.home});
  final List<Equipment> items;
  final Set<String> selected;
  final bool home;
  @override
  State<EquipmentPicker> createState() => _EquipmentPickerState();
}
class _EquipmentPickerState extends State<EquipmentPicker> {
  late final chosen = Set<String>.of(widget.selected);
  String query = '';
  @override
  Widget build(BuildContext context) {
    final visible = widget.items.where((e) => (!widget.home || !e.requiresGym) && '${e.name} ${e.code}'.toLowerCase().contains(query.toLowerCase())).toList();
    return SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.viewInsetsOf(context).bottom), child: Column(children: [
      Row(children: [const Expanded(child: Text('Tu equipamiento', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: 'Cancelar')]),
      Text(widget.home ? 'Solo opciones para casa. Sin selección = peso corporal.' : 'Sin selección entrenarás con peso corporal.', style: const TextStyle(color: Kora.muted)),
      const SizedBox(height: 16), TextField(decoration: const InputDecoration(hintText: 'Buscar equipamiento', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => query = v)),
      const SizedBox(height: 12), Expanded(child: visible.isEmpty ? const Center(child: Text('No hay resultados')) : ListView.builder(itemCount: visible.length, itemBuilder: (_, i) { final item = visible[i]; return CheckboxListTile(secondary: EquipmentIllustration(code: item.code), contentPadding: const EdgeInsets.symmetric(vertical: 8), value: chosen.contains(item.code), title: Text(item.name), subtitle: item.requiresGym ? const Text('Gimnasio') : null, onChanged: (v) => setState(() { v == true ? chosen.add(item.code) : chosen.remove(item.code); })); })),
      KoraButton(label: 'LISTO · ${chosen.length} SELECCIONADOS', onPressed: () => Navigator.pop(context, chosen)),
    ])));
  }
}
