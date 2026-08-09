# fontify_plus example

Flutter web demo that shows icons generated from `svg/` by fontify_plus.

```sh
cd example
dart run tool/generate.dart   # reads fontify_plus.yaml → fonts/ + lib/my_icons.dart
flutter run -d chrome
```

`fontify_plus` is a path **dev_dependency** — used only by `tool/generate.dart`.
Config lives in [`fontify_plus.yaml`](fontify_plus.yaml). The app loads the
generated font and `MyIcons` class.
