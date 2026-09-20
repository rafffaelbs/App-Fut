import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'groups_repository.dart';
import 'players_repository.dart';
import 'group_members_repository.dart';
import 'matches_repository.dart';
import 'ratings_repository.dart';
import 'sessions_repository.dart';
import 'seasons_repository.dart';
import 'session_arrivals_repository.dart';

/// Central service for Supabase integration.
class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();

  factory SupabaseService() => instance;

  SupabaseService._internal() {
    client = SupabaseConfig.client;

    // Initialize repositories
    groupMembers = GroupMembersRepository(client: client);
    players = PlayersRepository(client: client);
    groups = GroupsRepository(client: client, membersRepo: groupMembers);
    seasons = SeasonsRepository(client: client, membersRepo: groupMembers);
    sessions = SessionsRepository(client: client);
    matches = MatchesRepository(client: client);
    ratings = RatingsRepository(client: client);
    sessionArrivals = SessionArrivalsRepository(client: client);
  }

  late final SupabaseClient client;

  late final GroupMembersRepository groupMembers;
  late final GroupsRepository groups;
  late final SeasonsRepository seasons;
  late final PlayersRepository players;
  late final SessionsRepository sessions;
  late final MatchesRepository matches;
  late final RatingsRepository ratings;
  late final SessionArrivalsRepository sessionArrivals;
}
