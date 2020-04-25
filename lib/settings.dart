class Settings {
  String serverAddress = "";
  var fcmAuthData;

  Settings() {
    //this is the default thing that will redirect to the default fcm server
    fcmAuthData = {
      "project_id": "bluebubbles-ef567", //["project_info"]["project_id"]
      "storage_bucket":
          "bluebubbles-ef567.appspot.com", //["project_info"]["storage_bucket"]
      "api_key":
          "AIzaSyAO8XxBpxe3yli9JrXnjZ7tpLQLmQ9G5oU", //["client"]["api_key"]["current_key"]
      "firebase_url":
          "https://bluebubbles-ef567.firebaseio.com", //["project_info"]["firebase_url"]
      "client_id":
          "72201296417", //["client"]["oauth_client"]["client_id"] UNTIL "-""
      "application_id":
          "1:72201296417:android:3030ae4f9ac020e72c6160", //["client"]["mobilesdk_app_id"]
    };
  }

  Settings.fromJson(Map<String, dynamic> json)
      : serverAddress = json['server_address'],
        fcmAuthData = json['fcm_auth_data'];

  Map<String, dynamic> toJson() => {
        'server_address': serverAddress,
        'fcm_auth_data': fcmAuthData,
      };
}
