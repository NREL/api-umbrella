import Base from './base';

export default Base.extend({
  model: function() {
    return Admin.Api.create({
      frontendHost: location.hostname,
    });
  },
});
