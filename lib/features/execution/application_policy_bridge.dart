import '../../../data/models/application_access_policy.dart';
import 'execution_api.g.dart';

extension ApplicationPolicyBridge on ApplicationAccessPolicy {
  ApplicationPolicy toBridge() => ApplicationPolicy(
    mode: ApplicationListMode.values.byName(mode.name),
    blacklist: blacklist.toList(),
    whitelist: whitelist.toList(),
    allowedSystemApps: allowedSystemApps.toList(),
  );
}
