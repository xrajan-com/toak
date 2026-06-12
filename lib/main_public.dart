import 'package:ten_of_a_kind_poker/app/bootstrap.dart';
import 'package:ten_of_a_kind_poker/config/app_build.dart';

Future<void> main() async {
  AppBuild.use(AppBuild.publicRelease);
  await bootstrapApp();
}
