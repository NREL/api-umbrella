// eslint-disable-next-line ember/no-mixins
import Route from '@ember/routing/route';
import classic from 'ember-classic-decorator';
import AuthenticatedRouteMixin from 'ember-simple-auth/mixins/authenticated-route-mixin';

// eslint-disable-next-line ember/no-classic-classes
@classic
export default class IndexRoute extends Route.extend(AuthenticatedRouteMixin) {}
