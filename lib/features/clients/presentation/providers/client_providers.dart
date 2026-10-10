import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/client_repository_impl.dart';
import '../../data/project_repository_impl.dart';
import '../../domain/client.dart';
import '../../domain/client_repository.dart';
import '../../domain/project.dart';
import '../../domain/project_repository.dart';

final clientRepositoryProvider = Provider<ClientRepository>((ref) => ClientRepositoryImpl());

final projectRepositoryProvider = Provider<ProjectRepository>((ref) => ProjectRepositoryImpl());

final clientsListProvider = StreamProvider<List<Client>>((ref) {
  return ref.watch(clientRepositoryProvider).watchClients();
});

final clientProvider = StreamProvider.family<Client?, String>((ref, clientId) {
  return ref.watch(clientRepositoryProvider).watchClient(clientId);
});

final projectsForClientProvider =
    StreamProvider.family<List<Project>, String>((ref, clientId) {
  return ref.watch(projectRepositoryProvider).watchProjectsForClient(clientId);
});

final projectProvider = StreamProvider.family<Project?, String>((ref, projectId) {
  return ref.watch(projectRepositoryProvider).watchProject(projectId);
});
