import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/models/mission.dart';
import '../../../providers/repository_providers.dart';

/// Buscador de lugares (Google Places vía Cloud Functions) con espera de
/// 500 ms entre teclas para no llamar al servidor en cada letra.
class PlaceSearchField extends ConsumerStatefulWidget {
  const PlaceSearchField({super.key, required this.onSelected, this.debounce = const Duration(milliseconds: 500)});

  final void Function(GeoLocation location, String placeId) onSelected;
  final Duration debounce;

  @override
  ConsumerState<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends ConsumerState<PlaceSearchField> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PlaceSuggestion> _results = const [];
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final query = text.trim();
    if (query.length < 3) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(widget.debounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(placesRepositoryProvider).search(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results;
        _error = results.isEmpty ? 'No encontramos lugares con ese nombre.' : null;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _select(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    final requestId = ++_requestId;
    setState(() {
      _controller.text = suggestion.description;
      _results = const [];
      _loading = true;
    });
    try {
      final location = await ref.read(placesRepositoryProvider).locationOf(suggestion.placeId);
      if (mounted && requestId == _requestId) widget.onSelected(location, suggestion.placeId);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Buscar un lugar',
            hintText: 'Ej: iglesia, monumento, ciudad…',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.navy),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3)),
                  )
                : null,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 16)),
          ),
        if (_results.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              children: [
                for (final suggestion in _results)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(suggestion.description),
                    onTap: () => _select(suggestion),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
