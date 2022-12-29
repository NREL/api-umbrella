import { EmbeddedRecordsMixin } from '@ember-data/serializer/rest';
import ApplicationSerializer from 'api-umbrella-admin-ui/serializers/application';

export default class Settings extends ApplicationSerializer.extend(EmbeddedRecordsMixin) {
  attrs = {
    rateLimits: { embedded: 'always' },
  }
}
