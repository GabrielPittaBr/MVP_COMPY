import '../../../../core/constants/app_flags.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/mock_profile.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote);
  // ignore: unused_field
  final ProfileRemoteDataSource _remote;

  @override
  Future<UserProfile> getCurrentProfile() async {
    if (!kUseFirebaseRepos) return MockProfile.current;
    // TODO(integração): mapear DocumentSnapshot -> UserProfile.
    return MockProfile.current;
  }
}
