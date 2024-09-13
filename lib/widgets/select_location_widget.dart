import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SelectLocationWebView extends StatefulWidget {
  final Function(String) onSelectLocation;

  SelectLocationWebView({required this.onSelectLocation});

  @override
  _SelectLocationWebViewState createState() => _SelectLocationWebViewState();
}

class _SelectLocationWebViewState extends State<SelectLocationWebView> {
  late WebViewController _webViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Location'),
        backgroundColor: Colors.blueAccent,
      ),
      body: WebView(
        initialUrl: 'https://www.google.com/maps',
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (WebViewController webViewController) {
          _webViewController = webViewController;
        },
        navigationDelegate: (NavigationRequest request) {
          if (request.url.startsWith('https://www.google.com/maps')) {
            // Extract the location from the URL or use JavaScript to communicate with the page
            // For simplicity, assume URL will have the coordinates in query parameters
            // Example: https://www.google.com/maps/@37.7749,-122.4194,15z
            Uri uri = Uri.parse(request.url);
            if (uri.queryParameters.containsKey('lat') && uri.queryParameters.containsKey('lng')) {
              final lat = uri.queryParameters['lat'];
              final lng = uri.queryParameters['lng'];
              widget.onSelectLocation('$lat,$lng');
              Navigator.pop(context);
            }
          }
          return NavigationDecision.navigate;
        },
      ),
    );
  }
}
