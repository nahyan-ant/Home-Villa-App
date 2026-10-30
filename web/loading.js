// Fades the loading screen out once the app has drawn its first frame.
(function () {
  var el = document.getElementById('loading');
  if (!el) return;
  var hidden = false;

  function hide() {
    if (hidden) return;
    hidden = true;
    el.classList.add('done');
    setTimeout(function () { el.remove(); }, 600);
  }

  window.addEventListener('flutter-first-frame', hide);

  // Safety net: never leave the loader covering a running app, even if the
  // first-frame event is missed.
  new MutationObserver(function (_, observer) {
    if (document.querySelector('flutter-view')) {
      observer.disconnect();
      setTimeout(hide, 3000);
    }
  }).observe(document.body, { childList: true });

  setTimeout(function () {
    if (!hidden && !document.querySelector('flutter-view')) {
      el.querySelector('.msg').textContent =
        'This is taking longer than usual. Check the internet connection, or reload the page.';
    }
  }, 20000);
})();
