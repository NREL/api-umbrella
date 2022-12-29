import { EmbeddedRecordsMixin } from '@ember-data/serializer/rest';
import ApplicationSerializer from 'api-umbrella-admin-ui/serializers/application';

export default class SubSettings extends ApplicationSerializer.extend(EmbeddedRecordsMixin) {
  attrs = {
    settings: { embedded: 'always' },
  }
}
