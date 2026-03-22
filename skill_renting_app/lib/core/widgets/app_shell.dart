import 'package:flutter/material.dart';

import 'app_scaffold.dart';

/// Shared “app chrome” wrapper.
///
/// Use this on top-level pages while we refactor each screen toward a
/// consistent Scaffold/background and AppBar style.
class AppShell extends StatelessWidget {
  final String? title;
  final List<Widget>? actions;
  final Widget child;
  final bool showDefaultAppBar;
  final bool centerTitle;

  const AppShell({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.showDefaultAppBar = true,
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final appBar = showDefaultAppBar
        ? AppBar(
            title: title == null ? null : Text(title!),
            actions: actions,
            centerTitle: centerTitle,
          )
        : null;

    return AppScaffold(
      appBar: appBar,
      body: child,
    );
  }
}

