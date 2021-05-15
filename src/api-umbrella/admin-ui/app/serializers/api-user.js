import classic from 'ember-classic-decorator';
import { EmbeddedRecordsMixin } from '@ember-data/serializer/rest';
import ApplicationSerializer from 'api-umbrella-admin-ui/serializers/application';

@classic
export default class ApiUser extends ApplicationSerializer.extend(EmbeddedRecordsMixin) {
  attrs = {
    settings: { embedded: 'always' },
  }
}
