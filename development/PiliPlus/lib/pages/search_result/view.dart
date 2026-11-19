import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';
import 'package:PiliPlus/pages/search_result/controller.dart';
import 'package:PiliPlus/pages/search_panel/video/view.dart';

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({super.key, this.keyword});
  final String? keyword;
  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  final tag = DateTime.now().microsecondsSinceEpoch.toString();
  late final SearchResultController controller;
  @override
  void initState() {
    super.initState();
    controller = Get.put(SearchResultController(widget.keyword), tag: tag);
  }

  @override
  void dispose() {
    Get.delete<SearchResultController>(tag: tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SearchVideoPanel(
    keyword: controller.keyword,
    tag: tag,
    searchType: .video,
  );
}
