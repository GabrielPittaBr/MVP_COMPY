import '../entities/user_profile.dart';
import '../repositories/profile_repository.dart';

class GetPublicProfile {
  const GetPublicProfile(this._repository);
  final ProfileRepository _repository;

  Future<UserProfile?> call(String uid) => _repository.getPublicProfile(uid);
}
