import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

const String _appTitle = 'OpenTik';
const String _appUrl = 'https://exclude-certificates-semi-dollar.trycloudflare.com/opentik';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  runApp(const OpenChatShell());
}

class OpenChatShell extends StatelessWidget {
  const OpenChatShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5865F2),
          brightness: Brightness.dark,
        ),
      ),
      home: const _WebPage(),
    );
  }
}

class _WebPage extends StatefulWidget {
  const _WebPage();

  @override
  State<_WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<_WebPage> {
  late final WebViewController _controller;
  double _progress = 0;

  @override
  void initState() {
    super.initState();

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      // Sound is a first-class feature here:
      //  * no media type needs a user gesture before it may play;
      //  * video plays inline instead of opening the full-screen player.
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F0F0F))
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (int progress) {
          if (mounted) setState(() => _progress = progress / 100.0);
        },
        onPageFinished: (String url) async {
          await _controller.runJavaScript(_audioUnlockScript);
        },
        onNavigationRequest: (NavigationRequest request) {
          final Uri? uri = Uri.tryParse(request.url);
          if (uri == null) return NavigationDecision.prevent;
          if (uri.scheme == 'http' || uri.scheme == 'https') {
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
      ));

    if (_controller.platform is WebKitWebViewController) {
      final WebKitWebViewController webKit =
          _controller.platform as WebKitWebViewController;
      // Camera, microphone and photo-library requests made by the web page
      // (calls, voice messages, uploads) are granted inside this app.  iOS
      // still shows its own system prompt because Info.plist contains the
      // matching usage descriptions.
      webKit.setOnPlatformPermissionRequest((request) => request.grant());
      webKit.setAllowsBackForwardNavigationGestures(true);
    }

    _controller.loadRequest(Uri.parse(_appUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            WebViewWidget(controller: _controller),
            // Loading indicator: the OpenChat iOS loading GIF
            // (bundled from assets/build/loading_ios.gif in this repo).
            if (_progress < 1.0)
              Container(
                color: const Color(0xFF0F0F0F),
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/loading_ios.gif',
                  gaplessPlayback: true,
                  fit: BoxFit.contain,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Runs after every page load.  iOS/WKWebView allows media playback without a
// gesture when mediaTypesRequiringUserAction is empty, but the Web Audio API
// (used by OpenChat's notification beep) still starts suspended.  This installs
// a one-time gesture listener that resumes it.  It also tags the page so the web
// UI can tell that it is running inside the native app and starts OpenTik with
// sound on (the web page starts muted because browsers require a tap).
const String _audioUnlockScript = r'''
(function () {
  window.__OC_NATIVE_APP__ = true;

  // OpenTik shows a "Tap for sound" badge and starts its feed muted.  Native
  // autoplay is allowed here, so press that badge for the user.
  try {
    if (location.pathname.replace(/\/+$/, '') === '/opentik') {
      var soundBadge = document.getElementById('sound');
      if (soundBadge) soundBadge.click();
    }
  } catch (e) { /* not OpenTik */ }

  // Track every AudioContext the page creates.  OpenChat's notification beep
  // creates its context lazily, so it must be resumed on the first gesture.
  try {
    var NativeCtx = window.AudioContext || window.webkitAudioContext;
    if (NativeCtx && !window.__ocAudioCtxTracked) {
      window.__ocAudioCtxTracked = true;
      window.__ocAudioContexts = window.__ocAudioContexts || [];
      var TrackedCtx = function (options) {
        var ctx = new NativeCtx(options);
        try { window.__ocAudioContexts.push(ctx); } catch (e) { /* ignore */ }
        return ctx;
      };
      TrackedCtx.prototype = NativeCtx.prototype;
      window.AudioContext = TrackedCtx;
      if (window.webkitAudioContext) window.webkitAudioContext = TrackedCtx;
    }
  } catch (e) { /* older WebKit: the gesture listener below still runs */ }

  if (window.__ocAudioUnlockInstalled) return;
  window.__ocAudioUnlockInstalled = true;
  function unlock() {
    try {
      var Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx) return;
      if (!window.__ocAudioCtx) window.__ocAudioCtx = new Ctx();
      if (window.__ocAudioCtx.state === 'suspended') window.__ocAudioCtx.resume();
      var list = window.__ocAudioContexts || [];
      for (var i = 0; i < list.length; i++) {
        if (list[i].state === 'suspended') list[i].resume();
      }
    } catch (e) { /* the next gesture will try again */ }
  }
  ['touchstart', 'touchend', 'pointerdown', 'click', 'keydown'].forEach(function (ev) {
    document.addEventListener(ev, unlock, true);
  });
  document.addEventListener('visibilitychange', function () {
    if (!document.hidden) unlock();
  });
  unlock();
})();
''';
