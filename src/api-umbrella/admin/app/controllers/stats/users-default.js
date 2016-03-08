import Users from './users';

export default Users.extend({
  renderTemplate: function() {
    this.render('stats/users');
  }
});
