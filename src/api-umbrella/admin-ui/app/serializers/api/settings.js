import ApplicationSerializer from 'api-umbrella-admin-ui/serializers/application';
import { EmbeddedRecordsMixin } from '@ember-data/serializer/rest';

export default ApplicationSerializer.extend(EmbeddedRecordsMixin, {
  attrs: {
    rateLimits: { embedded: 'always' },
  },
});
