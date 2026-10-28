import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'app_button.dart';

/// A pushed page that lists something loaded from the network: a spinner
/// while it loads, the reason and a retry when it fails, an explanation when
/// it is empty, and pull-to-refresh throughout.
class AsyncListPage<T> extends StatelessWidget {
  const AsyncListPage({
    super.key,
    required this.title,
    required this.value,
    required this.onRefresh,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.builder,
  });

  final String title;
  final AsyncValue<List<T>> value;
  final Future<void> Function() onRefresh;
  final String emptyTitle;
  final String emptyMessage;

  /// Builds the page body from a non-empty list.
  final Widget Function(BuildContext context, List<T> items) builder;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final Widget body = switch (value) {
      AsyncData(:final value) when value.isEmpty => _Message(
        title: emptyTitle,
        message: emptyMessage,
      ),
      AsyncData(:final value) => builder(context, value),
      AsyncError(:final error) => _Message(
        title: 'Gagal memuat',
        message: error.toString(),
        onRetry: onRefresh,
      ),
      _ => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xxl * 2),
        child: CupertinoActivityIndicator(radius: 13),
      ),
    };

    return CupertinoPageScaffold(
      backgroundColor: palette.groupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        backgroundColor: palette.groupedBackground,
        border: null,
        previousPageTitle: '',
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: onRefresh),
            SliverPadding(
              padding: AppSpacing.page,
              sliver: SliverToBoxAdapter(child: body),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.message, this.onRetry});

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxl * 2,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.headline.copyWith(color: palette.label),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.footnote.copyWith(color: palette.secondaryLabel),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Coba lagi',
              style: AppButtonStyle.tinted,
              expand: false,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
