import Ember from 'ember';
import JSONSerializer from 'ember-data/serializers/json';

export default JSONSerializer.extend({
  keyForAttribute(attr) {
    return Ember.String.underscore(attr);
  },

  normalizeSingleResponse(store, primaryModelClass, payload, id, requestType) {
    let key = primaryModelClass.singlePayloadKey;
    if(key) {
      payload = payload[key];
    }

    return this._super(store, primaryModelClass, payload, id, requestType);
  },


  normalizeArrayResponse(store, primaryModelClass, payload, id, requestType) {
    let key = primaryModelClass.arrayPayloadKey;
    if(key) {
      payload = payload[key];
    }

    return this._super(store, primaryModelClass, payload, id, requestType);
  },

  serializeIntoHash(hash, typeClass, snapshot, options) {
    let key = typeClass.singlePayloadKey;
    if(key) {
      hash[key] = this.serialize(snapshot, options);
    } else {
      this._super(...arguments);
    }
  },
});
