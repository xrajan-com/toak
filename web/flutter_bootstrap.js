{{flutter_js}}
{{flutter_build_config}}

(function () {
  const loader = document.getElementById('bootstrap-loader');
  const status = document.getElementById('bootstrap-status');

  const setStatus = (message) => {
    if (status) {
      status.textContent = message;
    }
  };

  const hideLoader = () => {
    if (!loader) return;
    loader.classList.add('bootstrap-loader--hidden');
    window.setTimeout(() => loader.remove(), 240);
  };

  const slowLoadTimer = window.setTimeout(() => {
    setStatus('Still loading game assets. This can take a moment on a cold start.');
  }, 8000);

  const stalledLoadTimer = window.setTimeout(() => {
    setStatus('Still loading. If this keeps spinning, refresh the page once.');
  }, 20000);

  _flutter.loader
      .load({
        config: {
          canvasKitBaseUrl: 'canvaskit/',
        },
        onEntrypointLoaded: async function (engineInitializer) {
          setStatus('Starting game...');
          const appRunner = await engineInitializer.initializeEngine();
          await appRunner.runApp();
          window.clearTimeout(slowLoadTimer);
          window.clearTimeout(stalledLoadTimer);
          hideLoader();
        },
      })
      .catch((error) => {
        console.error('Flutter bootstrap failed', error);
        window.clearTimeout(slowLoadTimer);
        window.clearTimeout(stalledLoadTimer);
        setStatus('The game failed to start. Refresh and try again.');
      });
})();
