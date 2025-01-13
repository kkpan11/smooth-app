import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:provider/provider.dart';
import 'package:smooth_app/data_models/preferences/user_preferences.dart';
import 'package:smooth_app/database/dao_osm_location.dart';
import 'package:smooth_app/database/local_database.dart';
import 'package:smooth_app/generic_lib/design_constants.dart';
import 'package:smooth_app/generic_lib/dialogs/smooth_alert_dialog.dart';
import 'package:smooth_app/generic_lib/widgets/smooth_back_button.dart';
import 'package:smooth_app/pages/locations/osm_location.dart';
import 'package:smooth_app/pages/onboarding/currency_selector_helper.dart';
import 'package:smooth_app/pages/prices/price_add_product_card.dart';
import 'package:smooth_app/pages/prices/price_amount_card.dart';
import 'package:smooth_app/pages/prices/price_currency_card.dart';
import 'package:smooth_app/pages/prices/price_date_card.dart';
import 'package:smooth_app/pages/prices/price_location_card.dart';
import 'package:smooth_app/pages/prices/price_meta_product.dart';
import 'package:smooth_app/pages/prices/price_model.dart';
import 'package:smooth_app/pages/prices/price_proof_card.dart';
import 'package:smooth_app/pages/product/common/product_refresher.dart';
import 'package:smooth_app/pages/product/may_exit_page_helper.dart';
import 'package:smooth_app/themes/smooth_theme.dart';
import 'package:smooth_app/themes/smooth_theme_colors.dart';
import 'package:smooth_app/themes/theme_provider.dart';
import 'package:smooth_app/widgets/smooth_app_bar.dart';
import 'package:smooth_app/widgets/smooth_expandable_floating_action_button.dart';
import 'package:smooth_app/widgets/smooth_scaffold.dart';
import 'package:smooth_app/widgets/will_pop_scope.dart';

/// Single page that displays all the elements of price adding.
class ProductPriceAddPage extends StatefulWidget {
  const ProductPriceAddPage(
    this.model,
  );

  final PriceModel model;

  static Future<void> showProductPage({
    required final BuildContext context,
    final PriceMetaProduct? product,
    required final ProofType proofType,
  }) async {
    if (!await ProductRefresher().checkIfLoggedIn(
      context,
      isLoggedInMandatory: true,
    )) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final LocalDatabase localDatabase = context.read<LocalDatabase>();
    final List<OsmLocation> osmLocations =
        await DaoOsmLocation(localDatabase).getAll();
    if (!context.mounted) {
      return;
    }

    final UserPreferences userPreferences = context.read<UserPreferences>();
    final Currency currency = CurrencySelectorHelper().getSelected(
      userPreferences.userCurrencyCode,
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ProductPriceAddPage(
          PriceModel(
            proofType: proofType,
            locations: osmLocations,
            initialProduct: product,
            currency: currency,
          ),
        ),
      ),
    );
  }

  @override
  State<ProductPriceAddPage> createState() => _ProductPriceAddPageState();
}

class _ProductPriceAddPageState extends State<ProductPriceAddPage>
    with TraceableClientMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PriceModel>.value(
      value: widget.model,
      builder: (
        final BuildContext context,
        final Widget? child,
      ) {
        final AppLocalizations appLocalizations = AppLocalizations.of(context);
        final PriceModel model = Provider.of<PriceModel>(context);
        return WillPopScope2(
          onWillPop: () async => (
            await _mayExitPage(
              saving: false,
              model: model,
            ),
            null
          ),
          child: Form(
            key: _formKey,
            child: SmoothScaffold(
              appBar: SmoothAppBar(
                centerTitle: false,
                leading: const SmoothBackButton(),
                title: Text(
                  appLocalizations.prices_add_n_prices(
                    model.length,
                  ),
                ),
                actions: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.info),
                    onPressed: () async => _doesAcceptWarning(justInfo: true),
                  ),
                ],
              ),
              backgroundColor: context.lightTheme()
                  ? context.extension<SmoothColorsThemeExtension>().primaryLight
                  : null,
              body: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(LARGE_SPACE),
                child: Column(
                  children: <Widget>[
                    const PriceProofCard(),
                    const SizedBox(height: LARGE_SPACE),
                    const PriceDateCard(),
                    const SizedBox(height: LARGE_SPACE),
                    const PriceLocationCard(),
                    const SizedBox(height: LARGE_SPACE),
                    const PriceCurrencyCard(),
                    const SizedBox(height: LARGE_SPACE),
                    for (int i = 0; i < model.length; i++)
                      PriceAmountCard(
                        key: Key(model.elementAt(i).product.barcode),
                        index: i,
                      ),
                    const SizedBox(height: LARGE_SPACE),
                    const PriceAddProductCard(),
                    // so that the last items don't get hidden by the FAB
                    const SizedBox(height: MINIMUM_TOUCH_SIZE * 2),
                  ],
                ),
              ),
              floatingActionButton: SmoothExpandableFloatingActionButton(
                scrollController: _scrollController,
                onPressed: () async => _exitPage(
                  await _mayExitPage(
                    saving: true,
                    model: model,
                  ),
                ),
                icon: const Icon(Icons.send),
                label: Text(
                  appLocalizations.prices_send_n_prices(
                    model.length,
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15.0,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _doesAcceptWarning({required final bool justInfo}) async {
    final AppLocalizations appLocalizations = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (final BuildContext context) => SmoothAlertDialog(
        title: appLocalizations.prices_privacy_warning_title,
        actionsAxis: Axis.vertical,
        body: Text(appLocalizations.prices_privacy_warning_message),
        positiveAction: SmoothActionButton(
          text: appLocalizations.okay,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        negativeAction: justInfo
            ? null
            : SmoothActionButton(
                text: appLocalizations.cancel,
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
    );
  }

  /// Returns true if the basic checks passed.
  Future<bool> _check(
    final BuildContext context,
    final PriceModel model,
  ) async {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    String? error;
    try {
      error = model.checkParameters(context);
    } catch (e) {
      error = e.toString();
    }
    if (error != null) {
      if (!context.mounted) {
        return false;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => SmoothSimpleErrorAlertDialog(
          title: AppLocalizations.of(context).prices_add_validation_error,
          message: error!,
        ),
      );
      return false;
    }
    return true;
  }

  @override
  String get actionName =>
      'Opened price_page with ${widget.model.proofType.offTag}';

  /// Exits the page if the [flag] is `true`.
  void _exitPage(final bool flag) {
    if (flag) {
      Navigator.of(context).pop();
    }
  }

  /// Returns `true` if we should really exit the page.
  ///
  /// Parameter [saving] tells about the context: are we leaving the page,
  /// or have we clicked on the "save" button?
  Future<bool> _mayExitPage({
    required final bool saving,
    required PriceModel model,
  }) async {
    if (!model.hasChanged) {
      return true;
    }

    if (!saving) {
      final bool? pleaseSave =
          await MayExitPageHelper().openSaveBeforeLeavingDialog(
        context,
        title: AppLocalizations.of(context).prices_add_n_prices(
          model.length,
        ),
      );
      if (pleaseSave == null) {
        return false;
      }
      if (pleaseSave == false) {
        return true;
      }
      if (!mounted) {
        return false;
      }
    }

    if (!await _check(context, model)) {
      return false;
    }
    if (!mounted) {
      return false;
    }

    final UserPreferences userPreferences = context.read<UserPreferences>();
    const String flagTag = UserPreferences.TAG_PRICE_PRIVACY_WARNING;
    final bool? already = userPreferences.getFlag(flagTag);
    if (already != true) {
      final bool? accepts = await _doesAcceptWarning(justInfo: false);
      if (accepts != true) {
        return false;
      }
      await userPreferences.setFlag(flagTag, true);
    }
    if (!mounted) {
      return true;
    }

    await model.addTask(context);

    return true;
  }
}
