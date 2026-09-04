{{flutter_js}}
{{flutter_build_config}}

(async () => {
  const reloadKey = 'bite-the-way-cache-refresh';
  const hadController = 'serviceWorker' in navigator &&
      navigator.serviceWorker.controller != null;

  if ('serviceWorker' in navigator) {
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(registrations
      .filter((registration) =>
        registration.active?.scriptURL.endsWith('/flutter_service_worker.js'))
      .map((registration) => registration.unregister()));
  }

  if ('caches' in window) {
    const cacheNames = await caches.keys();
    await Promise.all(
      cacheNames
          .filter((name) => name.startsWith('flutter-'))
          .map((name) => caches.delete(name)),
    );
  }

  if (hadController && sessionStorage.getItem(reloadKey) !== 'done') {
    sessionStorage.setItem(reloadKey, 'done');
    window.location.reload();
    return;
  }

  sessionStorage.removeItem(reloadKey);
  await _flutter.loader.load();
})();
