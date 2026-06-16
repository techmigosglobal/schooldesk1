import 'package:flutter/material.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

class SchoolGalleryScreen extends StatelessWidget {
  const SchoolGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'School Gallery',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: context.appTheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'School Gallery',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'View event photos and videos here.',
                style: TextStyle(color: context.appTheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Loading albums...'),
            ],
          ),
        ),
      ),
    );
  }
}
