import 'package:material_ui/material_ui.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, this.showAppBar = true});
  final bool showAppBar;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: showAppBar ? AppBar(title: const Text('关于')) : null,
    body: const Center(
      child: Text(
        '哔哩哔哩\n基于开源 PiliPlus 构建\nbggRGjQaUbCoE / PiliPlus',
        textAlign: TextAlign.center,
      ),
    ),
  );
}
