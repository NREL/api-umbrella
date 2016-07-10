import Users from './users';

export default Users.extend({
  renderTemplate() {
    this.render('stats/users', { controller: 'statsUsersDefault' });
  },
});
