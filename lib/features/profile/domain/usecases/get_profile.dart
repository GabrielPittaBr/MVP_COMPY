import '../entities/user_profile.dart';
import '../repositories/profile_repository.dart';

class GetProfile {
  const GetProfile(this._repository);
  final ProfileRepository _repository;

  Future<UserProfile> call(String uid) => _repository.getCurrentProfile(uid);
}
