import 'package:PiliPlus/common/dial_prefix.dart';
import 'package:PiliPlus/common/widgets/canvas_dialog.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final ctr = Get.put(LoginPageController());
  bool visible = false;
  int lastTab = 0;
  @override
  void initState() {
    super.initState();
    ctr.tabController.addListener(tabChanged);
    ctr.passwordTextController.addListener(passwordChanged);
  }

  void passwordChanged() {
    if (visible && ctr.passwordTextController.text.isEmpty)
      setState(() => visible = false);
  }

  void tabChanged() {
    if (lastTab == ctr.tabController.index) return;
    lastTab = ctr.tabController.index;
    FocusScope.of(context).unfocus();
    setState(() => visible = false);
  }

  @override
  void dispose() {
    ctr.tabController.removeListener(tabChanged);
    ctr.passwordTextController.removeListener(passwordChanged);
    ctr.passwordTextController.clear();
    Get.delete<LoginPageController>();
    super.dispose();
  }

  Widget field(
    TextEditingController controller,
    String hint, {
    bool password = false,
    bool digits = false,
    Widget? prefix,
    Widget? trailing,
    TextInputAction action = TextInputAction.next,
  }) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (_, value, _) => TextField(
      controller: controller,
      obscureText: password && !visible,
      enableSuggestions: !password,
      autocorrect: false,
      keyboardType: digits
          ? TextInputType.number
          : password
          ? TextInputType.visiblePassword
          : TextInputType.text,
      textInputAction: action,
      onSubmitted: action == TextInputAction.done
          ? (_) {
              if (password) {
                ctr.loginByPassword();
              } else {
                ctr.loginBySmsCode();
              }
            }
          : null,
      inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefix,
        suffixIcon: value.text.isEmpty && trailing == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value.text.isNotEmpty)
                    IconButton(
                      tooltip: '清空$hint',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        controller.clear();
                        if (password) setState(() => visible = false);
                      },
                    ),
                  if (password && value.text.isNotEmpty)
                    IconButton(
                      tooltip: visible ? '隐藏密码' : '显示密码',
                      icon: Icon(
                        visible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => visible = !visible),
                    ),
                  ?trailing,
                ],
              ),
      ),
    ),
  );

  Future<void> chooseCountry() async {
    await canvasDialog<void>(
      context,
      (context) => AlertDialog(
        title: const Text('区号'),
        content: SizedBox(
          width: 320,
          height: 360,
          child: ListView.builder(
            itemCount: Login.dialPrefix.length,
            itemBuilder: (_, index) {
              final country = Login.dialPrefix[index];
              return ListTile(
                title: Text(country.cname),
                trailing: Text('+${country.countryId}'),
                onTap: () {
                  setState(() => ctr.selectedCountryCodeId = country);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget password() => AutofillGroup(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        field(ctr.usernameTextController, '账户'),
        const SizedBox(height: 16),
        field(
          ctr.passwordTextController,
          '密码',
          password: true,
          action: TextInputAction.done,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton(
            onPressed: ctr.loginByPassword,
            child: const Text('登录'),
          ),
        ),
      ],
    ),
  );
  Widget sms() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      field(
        ctr.telTextController,
        '手机号',
        digits: true,
        prefix: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: TextButton(
            onPressed: chooseCountry,
            child: Text('+${ctr.selectedCountryCodeId.countryId}'),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Obx(
        () => field(
          ctr.smsCodeTextController,
          '验证码',
          digits: true,
          action: TextInputAction.done,
          trailing: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: TextButton(
              onPressed: ctr.smsSendCooldown.value > 0 ? null : ctr.sendSmsCode,
              child: Text(
                ctr.smsSendCooldown.value > 0
                    ? '${ctr.smsSendCooldown.value}秒'
                    : '获取验证码',
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 44,
        child: FilledButton(
          onPressed: ctr.loginBySmsCode,
          child: const Text('登录'),
        ),
      ),
    ],
  );
  Widget qr() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Obx(
        () => Text(
          '${ctr.qrCodeLeftTime.value}秒',
          style: const TextStyle(
            fontSize: 16,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
      const SizedBox(height: 18),
      Obx(
        () => SizedBox(
          width: 220,
          height: 220,
          child: switch (ctr.codeInfo.value) {
            Loading() => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            Success(:final response) => Semantics(
              label: '登录二维码',
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: PrettyQrView.data(
                  data: response.url,
                  decoration: const PrettyQrDecoration(
                    shape: PrettyQrSquaresSymbol(color: Colors.black),
                  ),
                ),
              ),
            ),
            Error() => IconButton(
              tooltip: '重试',
              icon: const Icon(Icons.refresh, size: 42),
              onPressed: ctr.refreshQRCode,
            ),
          },
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: '关闭',
        icon: const Icon(Icons.close),
        onPressed: Get.back,
      ),
      title: SizedBox(
        width: 300,
        child: TabBar(
          controller: ctr.tabController,
          dividerHeight: 0,
          tabs: const [
            Tab(text: '密码'),
            Tab(text: '短信'),
            Tab(text: '扫码'),
          ],
        ),
      ),
    ),
    body: LayoutBuilder(
      builder: (_, size) => TabBarView(
        controller: ctr.tabController,
        children: [password(), sms(), qr()]
            .map(
              (child) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (size.maxHeight - 48 - kToolbarHeight).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: child,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ),
  );
}
