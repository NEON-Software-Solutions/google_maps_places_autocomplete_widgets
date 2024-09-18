// ignore_for_file: lines_longer_than_80_chars, avoid_dynamic_calls

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_places_autocomplete_widgets/model/place.dart';
import 'package:google_maps_places_autocomplete_widgets/model/suggestion.dart';
import 'package:http/http.dart';

class PlacesApiParams {
  PlacesApiParams({
    required this.sessionToken,
    required this.mapsApiKey,
    this.componentCountry,
    this.language,
  });

  final String sessionToken;
  final String mapsApiKey;
  final String? componentCountry;
  final String? language;
}

/* FOR DEBUGGING */
void printWrapped(String text) {
  final pattern = RegExp('.{1,800}'); // 800 is the size of each chunk
  pattern.allMatches(text).forEach((match) => debugPrint(match.group(0)));
}

void printJson(dynamic json, {String? title}) {
  const encoder = JsonEncoder.withIndent('  ');

  // encode it to string
  final prettyPrint = encoder.convert(json);

  if (title != null) {
    debugPrint(title);
  }
  printWrapped(prettyPrint);
}

const bool debugJson = false;
/* END FOR DEBUGGING */

class PlaceApiProvider {
  PlaceApiProvider();

  final client = Client();

/* Example JSON returned from Places autocomplete suggestions API request
    (ie.
      host: 'maps.googleapis.com',
        path: '/maps/api/place/autocomplete/json', )
    request below

result["predictions"] =
[
  {
    "description": "678 North Market Street, Redding, CA, USA",
    "matched_substrings": [
      {
        "length": 3,
        "offset": 0
      }
    ],
    "place_id": "ChIJiRzbkjrt0lQRVvD61FBwlmw",
    "reference": "ChIJiRzbkjrt0lQRVvD61FBwlmw",
    "structured_formatting": {
      "main_text": "678 North Market Street",
      "main_text_matched_substrings": [
        {
          "length": 3,
          "offset": 0
        }
      ],
      "secondary_text": "Redding, CA, USA"
    },
    "terms": [
      {
        "offset": 0,
        "value": "678"
      },
      {
        "offset": 4,
        "value": "North Market Street"
      },
      {
        "offset": 25,
        "value": "Redding"
      },
      {
        "offset": 34,
        "value": "CA"
      },
      {
        "offset": 38,
        "value": "USA"
      }
    ],
    "types": [
      "premise",
      "geocode"
    ]
  },

  ... repeating the other suggestions in same format
  
]
*/

  /// [includeFullSuggestionDetails] if we should include ALL details that are
  /// returned in API suggestions.
  /// (This is sent as true when the `onInitialSuggestionClick` is in use)
  /// [postalCodeLookup] if we should request `postal_code` type return information
  /// instead of address type information.
  Future<List<Suggestion>> fetchSuggestions(
    String input, {
    required PlacesApiParams params,
    bool includeFullSuggestionDetails = false,
    bool postalCodeLookup = false,
  }) async {
    final parameters = <String, dynamic>{
      'input': input,
      'types': postalCodeLookup
          ? 'postal_code'
          : 'address', // this is for looking up fully qualified addresses
      // Could be used for ZIP lookups//   'types': 'postal_code',
      'key': params.mapsApiKey,
      'sessiontoken': params.sessionToken,
    };

    if (params.language != null) {
      parameters.addAll(<String, dynamic>{'language': params.language});
    }
    if (params.componentCountry != null) {
      parameters.addAll(<String, dynamic>{
        'components': 'country:${params.componentCountry}',
      });
    }

    final request = Uri(
      scheme: 'https',
      host: 'maps.googleapis.com',
      path: '/maps/api/place/autocomplete/json',
      queryParameters: parameters,
    );

    final response = await client.get(request);

    if (response.statusCode == 200) {
      final result = json.decode(response.body) as Map<String, dynamic>;
      if (result['status'] == 'OK') {
        if (debugJson) {
          printJson(
            result['predictions'],
            title: 'GOOGLE MAP API RETURN VALUE result["predictions"]',
          );
        }

        // compose suggestions in a list
        return (result['predictions'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map<Suggestion>((p) {
          final placeID = p['place_id'] as String;
          final description = p['description'] as String;

          if (includeFullSuggestionDetails) {
            // Package everything useful from API json
            final mainText =
                (p['structured_formatting'] as Map?)?['main_text'] as String?;
            final secondaryText = (p['structured_formatting']
                as Map?)?['secondary_text'] as String?;
            final terms = (p['terms'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .map<String>((term) => term['value'] as String)
                .toList();
            final types = (p['types'] as List<dynamic>? ?? <dynamic>[])
                .map<String>((atype) => atype as String)
                .toList();

            return Suggestion(
              placeID,
              description,
              mainText: mainText,
              secondaryText: secondaryText,
              terms: terms,
              types: types,
            );
          } else {
            // just use the simple Suggestion parts we need
            return Suggestion(placeID, description);
          }
        }).toList();
      }
      if (result['status'] == 'ZERO_RESULTS') {
        return [];
      }
      throw Exception(result['error_message']);
    } else {
      throw Exception('Failed to fetch suggestion');
    }
  }

  /* EXAMPLE JSON returned from Places Detail
     (ie.   host: 'maps.googleapis.com',
        path: '/maps/api/place/details/json',  )
    request below:

result["result"]
{
  "address_components": [
    {
      "long_name": "6781",
      "short_name": "6781",
      "types": [
        "street_number"
      ]
    },
    {
      "long_name": "Eastside Road",
      "short_name": "Eastside Rd",
      "types": [
        "route"
      ]
    },
    {
      "long_name": "Metz Road",
      "short_name": "Metz Road",
      "types": [
        "neighborhood",
        "political"
      ]
    },
    {
      "long_name": "Anderson",
      "short_name": "Anderson",
      "types": [
        "locality",
        "political"
      ]
    },
    {
      "long_name": "Shasta County",
      "short_name": "Shasta County",
      "types": [
        "administrative_area_level_2",
        "political"
      ]
    },
    {
      "long_name": "California",
      "short_name": "CA",
      "types": [
        "administrative_area_level_1",
        "political"
      ]
    },
    {
      "long_name": "United States",
      "short_name": "US",
      "types": [
        "country",
        "political"
      ]
    },
    {
      "long_name": "96007",
      "short_name": "96007",
      "types": [
        "postal_code"
      ]
    },
    {
      "long_name": "9406",
      "short_name": "9406",
      "types": [
        "postal_code_suffix"
      ]
    }
  ],
  "formatted_address": "6781 Eastside Rd, Anderson, CA 96007, USA",
  "geometry": {
    "location": {
      "lat": 40.4839756,
      "lng": -122.34802
    },
    "viewport": {
      "northeast": {
        "lat": 40.48515498029149,
        "lng": -122.3471568197085
      },
      "southwest": {
        "lat": 40.48245701970849,
        "lng": -122.3498547802915
      }
    }
  },
  "name": "6781 Eastside Rd"
}
  */
  ///Requests full address info from Google Places API for the specified
  ///[placeId] and returns a [Place] object returned info.
  Future<Place> getPlaceDetailFromId({
    required PlacesApiParams params,
    required String placeId,
  }) async {
    // if you want to get the details of the selected place by place_id
    final parameters = <String, dynamic>{
      'place_id': placeId,
      'fields': 'name,formatted_address,address_component,geometry',
      'key': params.mapsApiKey,
      'sessiontoken': params.sessionToken,
    };

    final request = Uri(
      scheme: 'https',
      host: 'maps.googleapis.com',
      path: '/maps/api/place/details/json',

      //PlaceApiNew     host: 'places.googleapis.com',
      //PlaceApiNew     path: '/v1/places/$placeId',

      queryParameters: parameters,
    );

    if (debugJson) {
      debugPrint(request.toString());
    }

    final response = await client.get(request);
    /* PlaceApiNew:
        , headers: {
            'X-Goog-Api-Key': mapsApiKey,
            'X-Goog-FieldMask': 'displayName,formattedAddress',
      });
    PlaceApiNew */

    if (response.statusCode == 200) {
      final rawResult = json.decode(response.body) as Map<String, dynamic>;

      if (rawResult['status'] == 'OK') {
        if (debugJson) {
          printJson(
            rawResult['result'],
            title: 'GOOGLE MAP API RETURN VALUE result["result"]',
          );
        }

        final result = rawResult['result'] as Map<String, dynamic>;

        final components = result['address_components'] as List<dynamic>;

        // build result
        final place = Place()
          ..formattedAddress = result['formatted_address'] as String?
          ..name = result['name'] as String?
          ..lat = result['geometry']['location']['lat'] as double
          ..lng = result['geometry']['location']['lng'] as double;

        for (final component in components) {
          component as Map<String, dynamic>;

          final type = component['types'] as List<dynamic>;
          if (type.contains('street_address')) {
            place.streetAddress = component['long_name'] as String?;
          }
          if (type.contains('street_number')) {
            place.streetNumber = component['long_name'] as String?;
          }
          if (type.contains('route')) {
            place
              ..street = component['long_name'] as String?
              ..streetShort = component['short_name'] as String?;
          }
          if (type.contains('sublocality') ||
              type.contains('sublocality_level_1')) {
            place.vicinity = component['long_name'] as String?;
          }
          if (type.contains('locality')) {
            place.city = component['long_name'] as String?;
          }
          if (type.contains('administrative_area_level_2')) {
            place.county = component['long_name'] as String?;
          }
          if (type.contains('administrative_area_level_1')) {
            place
              ..state = component['long_name'] as String?
              ..stateShort = component['short_name'] as String?;
          }
          if (type.contains('country')) {
            place.country = component['long_name'] as String?;
          }
          if (type.contains('postal_code')) {
            place.zipCode = component['long_name'] as String?;
          }
          if (type.contains('postal_code_suffix')) {
            place.zipCodeSuffix = component['long_name'] as String?;
          }
        }

        place.zipCodePlus4 ??=
            '${place.zipCode}${place.zipCodeSuffix != null ? '-${place.zipCodeSuffix}' : ''}';
        if (place.streetNumber != null) {
          place.streetAddress ??= '${place.streetNumber} ${place.streetShort}';
          place.formattedAddress ??=
              '${place.streetNumber} ${place.streetShort}, ${place.city}, ${place.stateShort} ${place.zipCode}';
          place.formattedAddressZipPlus4 ??=
              '${place.streetNumber} ${place.streetShort}, ${place.city}, ${place.stateShort} ${place.zipCodePlus4}';
        }
        return place;
      }
      throw Exception((rawResult as Map)['error_message']);
    } else {
      throw Exception('Failed to fetch suggestion');
    }
  }
}
