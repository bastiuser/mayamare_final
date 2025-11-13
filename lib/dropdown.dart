import 'package:flutter/material.dart';

class DropdownOption {
  final String value;
  final String label;
  final IconData icon;
  const DropdownOption(this.value, this.label, this.icon);
}

class NiceDropdown extends StatefulWidget {
  final String label;
  final List<DropdownOption> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final EdgeInsetsGeometry? margin;

  const NiceDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.onChanged,
    this.value,
    this.margin,
  });

  @override
  State<NiceDropdown> createState() => _NiceDropdownState();
}

class _NiceDropdownState extends State<NiceDropdown> {
  late String? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value ?? (widget.options.isNotEmpty ? widget.options.first.value : null);
  }

  @override
  void didUpdateWidget(covariant NiceDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: _value,
        isExpanded: true,
        menuMaxHeight: 320,
        borderRadius: radius,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        style: const TextStyle(fontSize: 16, fontFamily: 'Montserrat', color: Colors.black),
        decoration: InputDecoration(
          labelText: widget.label,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: Color(0xFFDADADA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: Colors.black, width: 1.2),
          ),
        ),
        items: widget.options
            .map(
              (o) => DropdownMenuItem<String>(
                value: o.value,
                child: Row(
                  children: [
                    Icon(o.icon),
                    const SizedBox(width: 10),
                    Flexible(child: Text(o.label, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            )
            .toList(),
        selectedItemBuilder: (ctx) => widget.options
            .map(
              (o) => Row(
                children: [
                  Icon(o.icon),
                  const SizedBox(width: 10),
                  Flexible(child: Text(o.label, overflow: TextOverflow.ellipsis)),
                ],
              ),
            )
            .toList(),
        onChanged: (v) {
          setState(() => _value = v);
          widget.onChanged(v);
        },
      ),
    );
  }
}
