import EmberRouter from '@ember/routing/router';
import config from './config/environment';

const Router = EmberRouter.extend({
  location: config.locationType,
  rootURL: config.rootURL,
});

Router.map(function() {
  this.route('apis', { path: '/apis' }, function() {
    this.route('new');
    this.route('edit', { path: '/:api_id/edit' });
  });

  this.route('api_users', { path: '/api_users' }, function() {
    this.route('new');
    this.route('edit', { path: '/:api_user_id/edit' });
  });

  this.route('admins', { path: '/admins' }, function() {
    this.route('new');
    this.route('edit', { path: '/:admin_id/edit' });
  });

  this.route('api_scopes', { path: '/api_scopes' }, function() {
    this.route('new');
    this.route('edit', { path: '/:api_scope_id/edit' });
  });

  this.route('admin_groups', { path: '/admin_groups' }, function() {
    this.route('new');
    this.route('edit', { path: '/:admin_group_id/edit' });
  });

  this.route('config', { path: '/config' }, function() {
    this.route('publish');
  });

  this.route('stats', { path: '/stats' }, function() {
    this.route('drilldown', { path: '/drilldown' });
    this.route('drilldown-legacy', { path: '/drilldown/*legacyParams' });
    this.route('logs', { path: '/logs' });
    this.route('logs-legacy', { path: '/logs/*legacyParams' });
    this.route('users', { path: '/users' });
    this.route('users-legacy', { path: '/users/*legacyParams' });
    this.route('map', { path: '/map' });
    this.route('map-legacy', { path: '/map/*legacyParams' });
  });

  this.route('website_backends', { path: '/website_backends' }, function() {
    this.route('new');
    this.route('edit', { path: '/:website_backend_id/edit' });
  });

  this.route('login');
  this.route('error');
  this.route('not-found', { path: '/*wildcard' });
});

export default Router;
