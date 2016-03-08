import Logs from './logs';

export default Logs.extend({
  renderTemplate: function() {
    this.render('stats/logs', { controller: 'statsLogsDefault' });
  }
});
