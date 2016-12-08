import Base from './base';

export default Base.extend({
  redirect(params) {
    this.transitionTo('/stats/map?' + params.legacyParams);
  },
});
