import 'package:flutter/foundation.dart';

/// Licences for artwork bundled in the app that is not ours, registered with
/// Flutter's licence registry at startup. Source files and versions are in
/// docs/licenses/.
///
/// Country flags in assets/images/flags/world/ are rendered from flag-icons
/// 7.6.0 (https://github.com/lipis/flag-icons, commit ac7e0eb).
const String kFlagIconsLicense = '''
The MIT License (MIT)

Copyright (c) 2013 Panayiotis Lipiridis

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''';

/// One line for the About box.
const String kFlagIconsCredit =
    'Country flags: flag-icons by Panayiotis Lipiridis, MIT licence.';

bool _registered = false;

/// Adds the notices above to Flutter's licence registry, once.
void registerThirdPartyNotices() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(<String>['flag-icons'], kFlagIconsLicense);
  });
}
