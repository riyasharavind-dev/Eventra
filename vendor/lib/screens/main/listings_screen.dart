import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/service_model.dart';
import '../../repositories/service_repository.dart';

import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_loading.dart';
import '../../widgets/common/app_search_bar.dart';

import '../../widgets/cards/service_card.dart';

// IMPORTANT:
// Your new AddServiceDialog is inside widgets/edit/
import '../../widgets/edit/add_service_dialog.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() =>
      _ListingsScreenState();
}

class _ListingsScreenState
    extends State<ListingsScreen> {

  // ============================================================
  // REPOSITORY
  // ============================================================

  final ServiceRepository _serviceRepository =
      ServiceRepository();

  // ============================================================
  // IMAGE PICKER
  // ============================================================

  final ImagePicker _imagePicker =
      ImagePicker();

  // ============================================================
  // SEARCH
  // ============================================================

  final TextEditingController
      _searchController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  List<ServiceModel> _services = [];

  bool _isLoading = true;

  bool _hasError = false;

  String? _errorMessage;

  String _searchQuery = '';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _onSearchChanged,
    );

    _loadServices();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.removeListener(
      _onSearchChanged,
    );

    _searchController.dispose();

    super.dispose();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged() {
    final String query =
        _searchController.text
            .trim()
            .toLowerCase();

    if (_searchQuery == query) {
      return;
    }

    setState(() {
      _searchQuery = query;
    });
  }

  // ============================================================
  // LOAD SERVICES
  // ============================================================

  Future<void> _loadServices() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final List<ServiceModel>
          services =
          await _serviceRepository
              .getMyServices();

      if (!mounted) {
        return;
      }

      setState(() {
        _services = services;
        _isLoading = false;
        _hasError = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage =
            _cleanError(e);
      });
    }
  }

  // ============================================================
  // FILTERED SERVICES
  // ============================================================

  List<ServiceModel>
      get _filteredServices {

    if (_searchQuery.isEmpty) {
      return _services;
    }

    return _services.where(
      (ServiceModel service) {

        final String name =
            service.name
                .toLowerCase();

        final String description =
            service.description
                    ?.toLowerCase() ??
                '';

        final String slug =
            service.slug
                .toLowerCase();

        final String category =
            service.categoryName
                    ?.toLowerCase() ??
                '';

        return name.contains(
              _searchQuery,
            ) ||
            description.contains(
              _searchQuery,
            ) ||
            slug.contains(
              _searchQuery,
            ) ||
            category.contains(
              _searchQuery,
            );
      },
    ).toList();
  }

  // ============================================================
  // OPEN ADD SERVICE
  // ============================================================

  Future<void>
      _openAddServiceDialog() async {

    final bool? created =
        await showDialog<bool>(
      context: context,

      barrierDismissible:
          false,

      builder:
          (
        BuildContext dialogContext,
      ) {

        return AddServiceDialog(
          supabase:
              Supabase.instance.client,

          imagePicker:
              _imagePicker,

          onServiceCreated:
              () async {
            // We intentionally don't reload here.
            // The dialog returns true first.
          },
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (created == true) {

      await _loadServices();

      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Service created successfully.',
      );
    }
  }

  // ============================================================
  // TOGGLE SERVICE STATUS
  // ============================================================

  Future<void>
      _toggleServiceStatus(
    ServiceModel service,
  ) async {

    try {

      final ServiceModel updated =
          await _serviceRepository
              .toggleServiceStatus(
        service,
      );

      if (!mounted) {
        return;
      }

      setState(() {

        final int index =
            _services.indexWhere(
          (ServiceModel item) =>
              item.id ==
              service.id,
        );

        if (index != -1) {
          _services[index] =
              updated;
        }
      });

      _showSnackBar(
        updated.isActive
            ? 'Service activated.'
            : 'Service deactivated.',
      );

    } catch (e) {

      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Failed to update service: '
        '${_cleanError(e)}',

        isError: true,
      );
    }
  }

  // ============================================================
  // DELETE SERVICE
  // ============================================================

  Future<void> _deleteService(
    ServiceModel service,
  ) async {

    final bool? confirmed =
        await showDialog<bool>(
      context: context,

      builder:
          (
        BuildContext dialogContext,
      ) {

        return AlertDialog(

          title:
              const Text(
            'Delete Service?',

            style:
                TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          content:
              Text(
            'Are you sure you want to '
            'delete "${service.name}"?\n\n'
            'This action cannot be undone.',
          ),

          actions: [

            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              child:
                  const Text(
                'Cancel',
              ),
            ),

            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
              ),

              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              child:
                  const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {

      await _serviceRepository
          .deleteService(
        service,
      );

      if (!mounted) {
        return;
      }

      setState(() {

        _services.removeWhere(
          (ServiceModel item) =>
              item.id ==
              service.id,
        );
      });

      _showSnackBar(
        'Service deleted successfully.',
      );

    } catch (e) {

      if (!mounted) {
        return;
      }

      _showSnackBar(
        'Failed to delete service: '
        '${_cleanError(e)}',

        isError: true,
      );
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(message),

          backgroundColor:
              isError
                  ? Colors.red
                  : null,
        ),
      );
  }

  // ============================================================
  // ERROR CLEANER
  // ============================================================

  String _cleanError(
    Object error,
  ) {

    if (error
        is PostgrestException) {
      return error.message;
    }

    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {

    return Scaffold(

      appBar:
          AppBar(

        title:
            const Text(
          'Listings',

          style:
              TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),

        actions: [

          IconButton(

            tooltip:
                'Refresh',

            onPressed:
                _isLoading
                    ? null
                    : _loadServices,

            icon:
                const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      // ========================================================
      // ADD SERVICE BUTTON
      // ========================================================

      floatingActionButton:
          FloatingActionButton.extended(

        onPressed:
            _isLoading
                ? null
                : _openAddServiceDialog,

        icon:
            const Icon(
          Icons.add,
        ),

        label:
            const Text(
          'Add Service',
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body:
          SafeArea(

        child:
            Column(

          children: [

            // ==================================================
            // SEARCH
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                12,
                16,
                8,
              ),

              child:
                  AppSearchBar(
                controller:
                    _searchController,

                hintText:
                    'Search services...',
              ),
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            Expanded(
              child:
                  _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {

    // ==========================================================
    // LOADING
    // ==========================================================

    if (_isLoading) {
      return const AppLoading();
    }

    // ==========================================================
    // ERROR
    // ==========================================================

    if (_hasError) {

      return AppErrorState(
        message:
            _errorMessage ??
                'Something went wrong.',

        onRetry:
            _loadServices,
      );
    }

    final List<ServiceModel>
        filteredServices =
        _filteredServices;

    // ==========================================================
    // NO SERVICES
    // ==========================================================

    if (_services.isEmpty) {

      return RefreshIndicator(

        onRefresh:
            _loadServices,

        child:
            ListView(

          physics:
              const AlwaysScrollableScrollPhysics(),

          padding:
              const EdgeInsets.symmetric(
            horizontal:
                16,
          ),

          children: [

            SizedBox(
              height:
                  MediaQuery.of(context)
                          .size
                          .height *
                      0.18,
            ),

            const AppEmptyState(

              icon:
                  Icons
                      .inventory_2_outlined,

              title:
                  'No services yet',

              message:
                  'Add your first service '
                  'to start building your listings.',
            ),

            const SizedBox(
              height:
                  16,
            ),

            Center(

              child:
                  FilledButton.icon(

                onPressed:
                    _openAddServiceDialog,

                icon:
                    const Icon(
                  Icons.add,
                ),

                label:
                    const Text(
                  'Add Service',
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ==========================================================
    // SEARCH EMPTY
    // ==========================================================

    if (filteredServices.isEmpty) {

      return RefreshIndicator(

        onRefresh:
            _loadServices,

        child:
            ListView(

          physics:
              const AlwaysScrollableScrollPhysics(),

          padding:
              const EdgeInsets.symmetric(
            horizontal:
                16,
          ),

          children: [

            SizedBox(
              height:
                  MediaQuery.of(context)
                          .size
                          .height *
                      0.18,
            ),

            const AppEmptyState(

              icon:
                  Icons
                      .search_off_outlined,

              title:
                  'No services found',

              message:
                  'Try searching with a '
                  'different keyword.',
            ),

            const SizedBox(
              height:
                  16,
            ),

            Center(

              child:
                  OutlinedButton.icon(

                onPressed: () {

                  _searchController
                      .clear();
                },

                icon:
                    const Icon(
                  Icons.clear,
                ),

                label:
                    const Text(
                  'Clear Search',
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ==========================================================
    // SERVICE GRID
    // ==========================================================

    return RefreshIndicator(

      onRefresh:
          _loadServices,

      child:
          GridView.builder(

        physics:
            const AlwaysScrollableScrollPhysics(),

        padding:
            const EdgeInsets.fromLTRB(
          12,
          8,
          12,
          110,
        ),

        itemCount:
            filteredServices.length,

        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(

          crossAxisCount:
              2,

          crossAxisSpacing:
              10,

          mainAxisSpacing:
              12,

          childAspectRatio:
              0.86,
        ),

        itemBuilder:
            (
          BuildContext context,
          int index,
        ) {

          final ServiceModel
              service =
              filteredServices[index];

          return ServiceCard(

            service:
                service,

            // ==================================================
            // TOGGLE
            // ==================================================

            onToggleStatus:
                () {
              _toggleServiceStatus(
                service,
              );
            },

            // ==================================================
            // DELETE
            // ==================================================

            onDelete:
                () {
              _deleteService(
                service,
              );
            },
          );
        },
      ),
    );
  }
}