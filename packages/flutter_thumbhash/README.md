[![pub package](https://img.shields.io/pub/v/flutter_thumbhash.svg)](https://pub.dev/packages/flutter_thumbhash)

Flutter implementation of [ThumbHash](https://evanw.github.io/thumbhash/) algorithm.

## Usage

```dart
final hash = ThumbHash.fromBase64('3OcRJYB4d3h/iIeHeEh3eIhw+j3A');
```

```dart
Image(
  image: hash.toImage(),
)
```

![resulting preview image](example/screenshots/example.webp)
