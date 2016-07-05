import ApplicationSerializer from 'api-umbrella-admin/serializers/application';
import EmbeddedRecordsMixin from 'ember-data/serializers/embedded-records-mixin';

export default ApplicationSerializer.extend(EmbeddedRecordsMixin, {
  attrs: {
    rateLimits: { embedded: 'always' },
  },
});
