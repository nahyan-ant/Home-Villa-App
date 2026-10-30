{{flutter_js}}
{{flutter_build_config}}

// No Flutter service worker: it is deprecated, and it unregisters itself at
// the site root, which would also remove reminders_sw.js and its push
// reminders.
_flutter.loader.load();
