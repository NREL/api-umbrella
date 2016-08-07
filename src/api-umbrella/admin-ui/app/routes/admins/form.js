import Base from './base';
import Confirmation from 'api-umbrella-admin/mixins/confirmation';
import UncachedModel from 'api-umbrella-admin/mixins/uncached-model';

export default Base.extend(Confirmation, UncachedModel, {
});
