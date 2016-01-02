import Map from './map';

export default Map.extend({
  renderTemplate: function() {
    this.render('stats/map', { controller: 'statsMapDefault' });
  }
});
