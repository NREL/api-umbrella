// Disable Google Charts loading when running tests.
//
// While this isn't ideal, we continue to get weird and sporadic Google Charts
// loading failures like this from Capybara:
//
// ReferenceError: Can't find variable: gvjs_Wa
// at https://www.gstatic.com/charts/45/js/jsapi_compiled_default_module.js:8 in global code
//
// We should try to resolve this at some point, although moving to an offline
// charting library might be a better option regardless
// (https://github.com/NREL/api-umbrella/issues/124#issuecomment-84169398).
window.DISABLE_GOOGLE_CHARTS = true;
window.google = {
  charts: {
    // Mock the Google Charts ready function, but never actually trigger the
    // callback (since we haven't loaded Google Charts).
    setOnLoadCallback: function() {
    },
  },
};
