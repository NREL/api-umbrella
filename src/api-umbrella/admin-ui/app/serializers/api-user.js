import ApplicationSerializer from 'api-umbrella-admin-ui/serializers/application';
import EmbeddedRecordsMixin from 'ember-data/serializers/embedded-records-mixin';

export default ApplicationSerializer.extend(EmbeddedRecordsMixin, {
  attrs: {
    settings: { embedded: 'always' },
  },
});
