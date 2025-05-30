import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/database/grid/application/row/row_document_bloc.dart';
import 'package:appflowy/plugins/database/tab_bar/tab_bar_view.dart';
import 'package:appflowy/plugins/document/application/document_bloc.dart';
import 'package:appflowy/plugins/document/presentation/editor_drop_handler.dart';
import 'package:appflowy/plugins/document/presentation/editor_drop_manager.dart';
import 'package:appflowy/plugins/document/presentation/editor_page.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/ai/widgets/ai_writer_scroll_wrapper.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/shared_context/shared_context.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/transaction_handler/editor_transaction_service.dart';
import 'package:appflowy/plugins/document/presentation/editor_style.dart';
import 'package:appflowy/shared/flowy_error_page.dart';
import 'package:appflowy/workspace/application/view/view_bloc.dart';
import 'package:appflowy/workspace/application/view_info/view_info_bloc.dart';
import 'package:appflowy_backend/log.dart';
import 'package:appflowy_backend/protobuf/flowy-folder/view.pb.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

class RowDocument extends StatelessWidget {
  const RowDocument({
    super.key,
    required this.viewId,
    required this.rowId,
  });

  final String viewId;
  final String rowId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RowDocumentBloc>(
      create: (context) => RowDocumentBloc(viewId: viewId, rowId: rowId)
        ..add(const RowDocumentEvent.initial()),
      child: BlocConsumer<RowDocumentBloc, RowDocumentState>(
        listener: (_, state) => state.loadingState.maybeWhen(
          error: (error) => Log.error('RowDocument error: $error'),
          orElse: () => null,
        ),
        builder: (context, state) {
          return state.loadingState.when(
            loading: () => const Center(
              child: CircularProgressIndicator.adaptive(),
            ),
            error: (error) => Center(
              child: AppFlowyErrorPage(
                error: error,
              ),
            ),
            finish: () => _RowEditor(
              view: state.viewPB!,
              onIsEmptyChanged: (isEmpty) => context
                  .read<RowDocumentBloc>()
                  .add(RowDocumentEvent.updateIsEmpty(isEmpty)),
            ),
          );
        },
      ),
    );
  }
}

class _RowEditor extends StatelessWidget {
  const _RowEditor({
    required this.view,
    this.onIsEmptyChanged,
  });

  final ViewPB view;
  final void Function(bool)? onIsEmptyChanged;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => DocumentBloc(documentId: view.id)
            ..add(const DocumentEvent.initial()),
        ),
        BlocProvider(
          create: (_) => ViewBloc(view: view)..add(const ViewEvent.initial()),
        ),
      ],
      child: BlocConsumer<DocumentBloc, DocumentState>(
        listenWhen: (previous, current) =>
            previous.isDocumentEmpty != current.isDocumentEmpty,
        listener: (_, state) {
          if (state.isDocumentEmpty != null) {
            onIsEmptyChanged?.call(state.isDocumentEmpty!);
          }
          if (state.error != null) {
            Log.error('RowEditor error: ${state.error}');
          }
          if (state.editorState == null) {
            Log.error('RowEditor unable to get editorState');
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          final editorState = state.editorState;
          final error = state.error;
          if (error != null || editorState == null) {
            return Center(
              child: AppFlowyErrorPage(error: error),
            );
          }

          return BlocProvider<ViewInfoBloc>(
            create: (context) => ViewInfoBloc(view: view),
            child: Container(
              constraints: const BoxConstraints(minHeight: 300),
              child: Provider(
                create: (_) {
                  final context = SharedEditorContext();
                  context.isInDatabaseRowPage = true;
                  return context;
                },
                dispose: (_, editorContext) => editorContext.dispose(),
                child: AiWriterScrollWrapper(
                  viewId: view.id,
                  editorState: editorState,
                  child: EditorDropHandler(
                    viewId: view.id,
                    editorState: editorState,
                    isLocalMode: context.read<DocumentBloc>().isLocalMode,
                    dropManagerState: context.read<EditorDropManagerState>(),
                    child: EditorTransactionService(
                      viewId: view.id,
                      editorState: editorState,
                      child: Provider(
                        create: (context) => DatabasePluginWidgetBuilderSize(
                          horizontalPadding: 0,
                        ),
                        child: AppFlowyEditorPage(
                          shrinkWrap: true,
                          autoFocus: false,
                          editorState: editorState,
                          styleCustomizer: EditorStyleCustomizer(
                            context: context,
                            padding: const EdgeInsets.only(left: 16, right: 54),
                          ),
                          showParagraphPlaceholder: (editorState, _) =>
                              editorState.document.isEmpty,
                          placeholderText: (_) =>
                              LocaleKeys.cardDetails_notesPlaceholder.tr(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
