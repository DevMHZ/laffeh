import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/di/service_locator.dart';
import '../auth/presentation/pages/sign_in_page.dart';
import 'dispatch_service.dart';
import 'dispatch_strings.dart';

class DispatchInboxPage extends StatefulWidget {
  const DispatchInboxPage({super.key});
  @override
  State<DispatchInboxPage> createState() => _DispatchInboxPageState();
}

class _DispatchInboxPageState extends State<DispatchInboxPage> {
  late final service = sl<DispatchService>();
  String? opening, openError;
  @override
  void initState() {
    super.initState();
    service.refresh();
  }

  Future<void> open(ReceivedTrip trip) async {
    setState(() {
      opening = trip.id;
      openError = null;
    });
    try {
      final full = await service.fetchTrip(trip.id);
      if (mounted) Navigator.of(context).pop(full);
    } catch (_) {
      if (mounted) setState(() => openError = DispatchStrings.failed);
    } finally {
      if (mounted) setState(() => opening = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(DispatchStrings.inbox),
      actions: [
        IconButton(
          tooltip: DispatchStrings.retry,
          onPressed: () => service.refresh(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.signedIn) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DispatchStrings.signIn),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SignInPage(),
                      ),
                    ),
                    child: Text(DispatchStrings.signIn),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => service.refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (service.loading) const LinearProgressIndicator(),
              if (service.error != null || openError != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    openError ?? service.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (!service.loading &&
                  service.trips.isEmpty &&
                  service.error == null)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(DispatchStrings.empty),
                ),
              for (final trip in service.trips)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                trip.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (!trip.opened)
                              Chip(label: Text(DispatchStrings.unread)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('${trip.company} · ${trip.sender}'),
                        Text(
                          DateFormat.yMMMd().add_Hm().format(
                            trip.receivedAt.toLocal(),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: opening == null ? () => open(trip) : null,
                          icon: opening == trip.id
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.route),
                          label: Text(DispatchStrings.open),
                        ),
                      ],
                    ),
                  ),
                ),
              if (service.hasMore)
                TextButton(
                  onPressed: service.loading
                      ? null
                      : () => service.refresh(more: true),
                  child: Text(DispatchStrings.loadMore),
                ),
            ],
          ),
        );
      },
    ),
  );
}
