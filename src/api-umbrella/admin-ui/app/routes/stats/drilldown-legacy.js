import Base from './base';

export default Base.extend({
  redirect(params) {
    this.transitionTo('/stats/drilldown?' + params.legacyParams);
  },
});
