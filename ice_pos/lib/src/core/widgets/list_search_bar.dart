import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Barra de búsqueda ligada a un [StateProvider<String>].
class ListSearchBar extends ConsumerStatefulWidget {
  const ListSearchBar({
    super.key,
    required this.queryProvider,
    required this.hintText,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  });

  final StateProvider<String> queryProvider;
  final String hintText;
  final EdgeInsetsGeometry padding;

  @override
  ConsumerState<ListSearchBar> createState() => _ListSearchBarState();
}

class _ListSearchBarState extends ConsumerState<ListSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(widget.queryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(widget.queryProvider, (prev, next) {
      if (next.isEmpty && _controller.text.isNotEmpty) {
        _controller.clear();
      }
    });

    final scheme = Theme.of(context).colorScheme;
    final q = ref.watch(widget.queryProvider);

    return Padding(
      padding: widget.padding,
      child: TextField(
        controller: _controller,
        onChanged: (v) => ref.read(widget.queryProvider.notifier).state = v,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search, size: 22),
          suffixIcon: q.trim().isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    ref.read(widget.queryProvider.notifier).state = '';
                  },
                ),
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}
