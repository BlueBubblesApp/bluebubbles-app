import '../abstractions/service.dart';


abstract class ServerService extends Service {
  @override
  bool required = true;

  bool get isMinSierra;

  bool get isMinMojave;

  bool get isMinCatalina;

  bool get isMinBigSur;

  bool get isMinMonterey;

  bool get isMinVentura;

  bool get isMinSonoma;

  bool get canCreateGroupChats;
}