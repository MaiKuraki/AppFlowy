import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/workspace/application/settings/appflowy_cloud_setting_bloc.dart';
import 'package:appflowy/workspace/application/settings/appflowy_cloud_urls_bloc.dart';
import 'package:appflowy/workspace/presentation/widgets/dialogs.dart';
import 'package:appflowy_backend/dispatch/dispatch.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/user_setting.pb.dart';
import 'package:dartz/dartz.dart' show Either;
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/size.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/widget/error_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingAppFlowyCloudView extends StatelessWidget {
  final VoidCallback didResetServerUrl;
  const SettingAppFlowyCloudView({required this.didResetServerUrl, super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Either<CloudSettingPB, FlowyError>>(
      future: UserEventGetCloudConfig().send(),
      builder: (context, snapshot) {
        if (snapshot.data != null &&
            snapshot.connectionState == ConnectionState.done) {
          return snapshot.data!.fold(
            (setting) => _renderContent(setting),
            (err) => FlowyErrorPage.message(err.toString(), howToFix: ""),
          );
        } else {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }

  BlocProvider<AppFlowyCloudSettingBloc> _renderContent(
    CloudSettingPB setting,
  ) {
    return BlocProvider(
      create: (context) => AppFlowyCloudSettingBloc(setting)
        ..add(const AppFlowyCloudSettingEvent.initial()),
      child: Column(
        children: [
          const AppFlowyCloudEnableSync(),
          const VSpace(40),
          AppFlowyCloudURLs(didUpdateUrls: () => didResetServerUrl()),
        ],
      ),
    );
  }
}

class AppFlowyCloudURLs extends StatelessWidget {
  final VoidCallback didUpdateUrls;
  const AppFlowyCloudURLs({
    required this.didUpdateUrls,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          AppFlowyCloudURLsBloc()..add(const AppFlowyCloudURLsEvent.initial()),
      child: BlocListener<AppFlowyCloudURLsBloc, AppFlowyCloudURLsState>(
        listener: (context, state) {
          if (state.restartApp) {
            didUpdateUrls();
          }
        },
        child: BlocBuilder<AppFlowyCloudURLsBloc, AppFlowyCloudURLsState>(
          builder: (context, state) {
            return Column(
              children: [
                const AppFlowySelfhostTip(),
                CloudURLInput(
                  title: LocaleKeys.settings_menu_cloudURL.tr(),
                  url: state.config.base_url,
                  hint: LocaleKeys.settings_menu_cloudURLHint.tr(),
                  onChanged: (text) {
                    context.read<AppFlowyCloudURLsBloc>().add(
                          AppFlowyCloudURLsEvent.updateServerUrl(
                            text,
                          ),
                        );
                  },
                ),
                const VSpace(20),
                FlowyButton(
                  isSelected: true,
                  useIntrinsicWidth: true,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 10,
                  ),
                  text: FlowyText(
                    LocaleKeys.settings_menu_restartApp.tr(),
                  ),
                  onTap: () {
                    NavigatorAlertDialog(
                      title: LocaleKeys.settings_menu_restartAppTip.tr(),
                      confirm: () => context.read<AppFlowyCloudURLsBloc>().add(
                            const AppFlowyCloudURLsEvent.confirmUpdate(),
                          ),
                    ).show(context);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AppFlowySelfhostTip extends StatelessWidget {
  final url =
      "https://docs.appflowy.io/docs/guides/appflowy/self-hosting-appflowy#build-appflowy-with-a-self-hosted-server";
  const AppFlowySelfhostTip({super.key});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: RichText(
        text: TextSpan(
          children: <TextSpan>[
            TextSpan(
              text: LocaleKeys.settings_menu_selfHostStart.tr(),
              style: Theme.of(context).textTheme.bodySmall!,
            ),
            TextSpan(
              text: " ${LocaleKeys.settings_menu_selfHostContent.tr()} ",
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: FontSizes.s14,
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
              recognizer: TapGestureRecognizer()..onTap = () => _launchURL(),
            ),
            TextSpan(
              text: LocaleKeys.settings_menu_selfHostEnd.tr(),
              style: Theme.of(context).textTheme.bodySmall!,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Log.error("Could not launch $url");
    }
  }
}

@visibleForTesting
class CloudURLInput extends StatefulWidget {
  final String title;
  final String url;
  final String hint;

  final Function(String) onChanged;

  const CloudURLInput({
    required this.title,
    required this.url,
    required this.hint,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  CloudURLInputState createState() => CloudURLInputState();
}

class CloudURLInputState extends State<CloudURLInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(fontSize: 12.0),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        labelText: widget.title,
        labelStyle: Theme.of(context)
            .textTheme
            .titleMedium!
            .copyWith(fontWeight: FontWeight.w400, fontSize: 16),
        enabledBorder: UnderlineInputBorder(
          borderSide:
              BorderSide(color: Theme.of(context).colorScheme.onBackground),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
        hintText: widget.hint,
        errorText: context
            .read<AppFlowyCloudURLsBloc>()
            .state
            .urlError
            .fold(() => null, (error) => error),
      ),
      onChanged: widget.onChanged,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class AppFlowyCloudEnableSync extends StatelessWidget {
  const AppFlowyCloudEnableSync({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppFlowyCloudSettingBloc, AppFlowyCloudSettingState>(
      builder: (context, state) {
        return Row(
          children: [
            FlowyText.medium(LocaleKeys.settings_menu_enableSync.tr()),
            const Spacer(),
            Switch(
              onChanged: (bool value) {
                context.read<AppFlowyCloudSettingBloc>().add(
                      AppFlowyCloudSettingEvent.enableSync(value),
                    );
              },
              value: state.setting.enableSync,
            ),
          ],
        );
      },
    );
  }
}