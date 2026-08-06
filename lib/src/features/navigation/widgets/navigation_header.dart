import 'package:astro_nav/src/design/tokens.dart';
import 'package:astro_nav/src/features/navigation/navigator_controller.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class NavigationHeader extends StatefulWidget {
  const NavigationHeader({
    required this.state,
    required this.onSearch,
    required this.onOpenSearch,
    required this.onReturnToRealTime,
    this.showBrand = true,
    super.key,
  });

  final NavigationState state;
  final ValueChanged<String> onSearch;
  final VoidCallback onOpenSearch;
  final VoidCallback onReturnToRealTime;
  final bool showBrand;

  @override
  State<NavigationHeader> createState() => _NavigationHeaderState();
}

class _NavigationHeaderState extends State<NavigationHeader> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.query);
  }

  @override
  void didUpdateWidget(covariant NavigationHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.query != _controller.text && widget.state.query.isEmpty) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (widget.showBrand) ...[
          const _BrandMark(),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: TextField(
            key: const Key('destination-search-field'),
            controller: _controller,
            onTap: widget.onOpenSearch,
            onChanged: widget.onSearch,
            onSubmitted: widget.onSearch,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: '搜索星球、空间站、基地',
              prefixIcon: const Icon(LucideIcons.search, size: 19),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空搜索',
                      onPressed: () {
                        _controller.clear();
                        widget.onSearch('');
                      },
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton(
          tooltip: widget.state.isRealTime ? '当前为现实时间' : '返回现实时间',
          onPressed: widget.onReturnToRealTime,
          icon: Icon(
            widget.state.isRealTime ? LucideIcons.radio : LucideIcons.clock3,
            size: 19,
            color: widget.state.isRealTime ? AppColors.green : AppColors.amber,
          ),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: '天枢导航 AstroNav',
      excludeSemantics: true,
      child: SizedBox(
        width: 72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '天枢',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.text,
                fontSize: 20,
              ),
            ),
            Text(
              'ASTRONAV',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.cyan,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DesktopBrand extends StatelessWidget {
  const DesktopBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.cyan),
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: const Icon(
              LucideIcons.orbit,
              color: AppColors.cyan,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('天枢导航', style: Theme.of(context).textTheme.titleLarge),
              Text(
                'ASTRONAV // SOL SYSTEM',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.cyan,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
