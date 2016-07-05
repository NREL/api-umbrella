import Base from './base';

export default Base.extend({
  model() {
    return Admin.Api.create({
      frontendHost: location.hostname,
    });
  },
});
