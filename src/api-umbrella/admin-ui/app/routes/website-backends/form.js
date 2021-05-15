// eslint-disable-next-line ember/no-mixins
import Confirmation from 'api-umbrella-admin-ui/mixins/confirmation';
// eslint-disable-next-line ember/no-mixins
import UncachedModel from 'api-umbrella-admin-ui/mixins/uncached-model';
import classic from 'ember-classic-decorator';

import Base from './base';

@classic
export default class FormRoute extends Base.extend(Confirmation, UncachedModel) {}
