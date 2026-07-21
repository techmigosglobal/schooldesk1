# Architecture decisions

## State management

Provider is the single application state-management system. Theme, settings,
and authentication are `ChangeNotifier`s provided from the application root.
Riverpod was removed because its provider definitions were not consumed by any
screen; retaining an unused second container made ownership unclear.

## Network API boundary

`BackendApiClient` remains the stable, testable HTTP facade. Its domain methods
live in `lib/core/network/api_modules/`; repositories are the domain-facing
adapters. New endpoints belong in the relevant existing module rather than in
the facade file.

## Navigation

Named routes remain the production navigation contract. The route boundary now
throws a diagnostic error when a route has neither a widget nor a builder,
instead of silently rendering a blank screen. A `go_router` migration is a
separate compatibility project: it must first replace the existing dynamic
argument maps with typed route argument objects and include deep-link and
role-guard regression tests.

## Native build dependencies

iOS uses Flutter's generated Swift Package integration. Do not add a Podfile:
the project has no CocoaPods plugins, and adding CocoaPods would reintroduce a
second native dependency manager. Android release builds enable R8 and resource
shrinking; every signed release must complete the device smoke checks below.
Release build scripts and Codemagic also use Flutter's `--obfuscate` and
`--split-debug-info` flags. The generated symbol directory is a required
release artifact, not disposable build output.
