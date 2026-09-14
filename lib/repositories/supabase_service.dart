import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'groups_repository.dart';
import 'players_repository.dart';
import 'group_members_repository.dart';
import 'matches_repository.dart';
import 'ratings_repository.dart';
import 'sessions_repository.dart';
import 'seasons_repository.dart';

/// Central service for Supabase integration.
class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();

  factory SupabaseService() => instance;

  SupabaseService._internal() {
    client = SupabaseConfig.client;
    
    // Initialize repositories
    _membrosRepository = GroupMembersRepository(client: client);
    jogadores = PlayersRepository(client: client);
    _groupsRepository = GroupsRepository(client: client, membrosRepo: _membrosRepository);
    _seasonsRepository = SeasonsRepository(client: client, membrosRepo: _membrosRepository);
    sessoes = SessionsRepository(client: client);
    matches = MatchesRepository(client: client);
    ratings = RatingsRepository(client: client);
  }

  late final SupabaseClient client;
  
  late final GroupMembersRepository _membrosRepository;
  late final GroupsRepository _groupsRepository;
  late final SeasonsRepository _seasonsRepository;

  // Backwards compat properties if needed by UI
  late final PlayersRepository jogadores;
  late final SessionsRepository sessoes;
  late final MatchesRepository matches;
  late final RatingsRepository ratings;

  GroupsRepository get groups => _groupsRepository;
  GroupMembersRepository get groupMembers => _membrosRepository;
  SeasonsRepository get seasons => _seasonsRepository;
  PlayersRepository get players => jogadores;
  SessionsRepository get sessions => sessoes;

  // Aliases for legacy code
  GroupsRepository get grupos => _groupsRepository;
  GroupMembersRepository get membros => _membrosRepository;
  SeasonsRepository get temporadas => _seasonsRepository;
  MatchesRepository get partidas => matches;
}
