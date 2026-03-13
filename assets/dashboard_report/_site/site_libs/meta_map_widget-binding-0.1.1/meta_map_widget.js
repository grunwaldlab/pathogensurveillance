(function() {
  if (typeof HTMLWidgets === "undefined") return;
  if (HTMLWidgets.widgets &&
      HTMLWidgets.widgets.meta_map_widget) return;
  HTMLWidgets.widget({
    name: 'meta_map_widget',
    type: 'output',
    factory: function(el, width, height) {
      let widget = null;
      return {
        renderValue: function(x) {
          el.innerHTML = '';
          let tsvData = x.tsv || (typeof x === 'string' ? x : String(x));

          try {
            // Try with just el and data
            widget = PSMapWidget(el.id, tsvData, {}, x.sizeVar, x.colorVar);
          } catch (e) {
            console.error('PSMapWidget error:', e);
            console.error('Stack:', e.stack);
          }

        },
        resize: function(width, height) {}
      };
    }
  });
})();



