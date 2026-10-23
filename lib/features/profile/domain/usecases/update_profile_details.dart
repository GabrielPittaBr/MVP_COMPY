import '../repositories/profile_repository.dart';

class UpdateProfileDetails {
  const UpdateProfileDetails(this._repository);
  final ProfileRepository _repository;

  Future<void> call(String uid, {required String name, required String bio}) =>
      _repository.updateDetails(uid, name: name, bio: bio);
}
