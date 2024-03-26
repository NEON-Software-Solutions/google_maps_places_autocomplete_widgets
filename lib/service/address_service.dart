import '/api/place_api_provider.dart';
import '/model/place.dart';
import '/model/suggestion.dart';

class AddressService {
  AddressService(
    this.sessionToken,
    this.mapsApiKey,
    this.componentCountry,
    this.language, {
    required PlaceApiProvider? customApiClient,
  }) {
    apiClient = customApiClient ?? PlaceApiProvider();
  }

  final String sessionToken;
  final String mapsApiKey;
  final String? componentCountry;
  final String? language;
  late PlaceApiProvider apiClient;

  Future<List<Suggestion>> search(String query,
      {bool includeFullSuggestionDetails = false,
      bool postalCodeLookup = false}) async {
    return await apiClient.fetchSuggestions(
      query,
      includeFullSuggestionDetails: includeFullSuggestionDetails,
      postalCodeLookup: postalCodeLookup,
      params: PlacesApiParams(
        sessionToken: sessionToken,
        mapsApiKey: mapsApiKey,
        componentCountry: componentCountry,
        language: language,
      ),
    );
  }

  Future<Place> getPlaceDetail(String placeId) async {
    Place placeDetails = await apiClient.getPlaceDetailFromId(
      params: PlacesApiParams(
        sessionToken: sessionToken,
        mapsApiKey: mapsApiKey,
        componentCountry: componentCountry,
        language: language,
      ),
      placeId: placeId,
    );
    return placeDetails;
  }
}
