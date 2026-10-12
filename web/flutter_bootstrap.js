{{flutter_js}}
{{flutter_build_config}}

// No serviceWorkerSettings: Flutter's own service worker is deprecated, and
// it would take the place of sw.js (see index.html).
_flutter.loader.load({
  config: {
    // GitHub Pages cannot send the COOP and COEP headers: skwasm runs on one
    // thread, which is fine for these games.
    suppressMultithreadingWarning: true,
  },
});
