import 'package:PiliPlus/pages/canvas/view.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
    Get.put(MainController());
  }

  @override
  Widget build(BuildContext context) => const BiliCanvasPage();
}
