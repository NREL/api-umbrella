import Drilldown from './drilldown';

export default Drilldown.extend({
  renderTemplate() {
    this.render('stats/drilldown', { controller: 'statsDrilldownDefault' });
  },
});
