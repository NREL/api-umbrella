import Ember from 'ember';
import config from './config/environment';

const Router = Ember.Router.extend({
  location: config.locationType,
});

Router.map(function() {
  this.route('apis', { path: '/apis' }, function() {
    this.route('new');
    this.route('edit', { path: '/:apiId/edit' });
  });

  this.route('api_users', { path: '/api_users' }, function() {
    this.route('new');
    this.route('edit', { path: '/:apiUserId/edit' });
  });

  this.route('admins', { path: '/admins' }, function() {
    this.route('new');
    this.route('edit', { path: '/:adminId/edit' });
  });

  this.route('api_scopes', { path: '/api_scopes' }, function() {
    this.route('new');
    this.route('edit', { path: '/:apiScopeId/edit' });
  });

  this.route('admin_groups', { path: '/admin_groups' }, function() {
    this.route('new');
    this.route('edit', { path: '/:adminGroupId/edit' });
  });

  this.route('config', { path: '/config' }, function() {
    this.route('publish');
  });

  this.route('stats', { path: '/stats' }, function() {
    this.route('drilldown', { path: '/drilldown' });
    this.route('logs', { path: '/logs' });
    this.route('users', { path: '/users' });
    this.route('map', { path: '/map' });
  });

  this.route('website_backends', { path: '/website_backends' }, function() {
    this.route('new');
    this.route('edit', { path: '/:websiteBackendId/edit' });
  });
  this.route('login');
});

export default Router;
