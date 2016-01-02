import Base from './base';

export default Base.extend({
  model: function() {
    return Admin.ApiUser.create();
  },
});
