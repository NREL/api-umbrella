import { EmbeddedRecordsMixin } from '@ember-data/serializer/rest';
import ApplicationSerializer from 'api-umbrella-admin-ui/serializers/application';

export default class Api extends ApplicationSerializer.extend(EmbeddedRecordsMixin) {
  attrs = {
    servers: { embedded: 'always' },
    urlMatches: { embedded: 'always' },
    settings: { embedded: 'always' },
    subSettings: { embedded: 'always' },
    rewrites: { embedded: 'always' },
  }
}
