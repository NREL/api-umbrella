import Route from '@ember/routing/route';
import classic from 'ember-classic-decorator';
// eslint-disable-next-line ember/no-mixins
import AuthenticatedRouteMixin from 'ember-simple-auth/mixins/authenticated-route-mixin';

@classic
export default class IndexRoute extends Route.extend(AuthenticatedRouteMixin) {}
