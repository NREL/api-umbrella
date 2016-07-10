import Logs from './logs';

export default Logs.extend({
  renderTemplate() {
    this.render('stats/logs', { controller: 'statsLogsDefault' });
  },
});
