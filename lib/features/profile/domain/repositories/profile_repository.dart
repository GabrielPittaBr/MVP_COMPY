import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> getCurrentProfile();
}
