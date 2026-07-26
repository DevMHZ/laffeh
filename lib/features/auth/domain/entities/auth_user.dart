import 'package:equatable/equatable.dart';

/// The signed-in account, as the app cares about it. Deliberately thin — no
/// Supabase types leak past the repository.
class AuthUser extends Equatable {
  final String id;
  final String? phone;

  const AuthUser({required this.id, this.phone});

  @override
  List<Object?> get props => [id, phone];
}
