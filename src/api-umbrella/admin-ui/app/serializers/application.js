import JSONSerializer from 'ember-data/serializers/json';
import { underscore } from '@ember/string';

export default JSONSerializer.extend({
  // Use camel-cased attribute names in the JS models, but underscore the
  // attribute names for any server-side communication.
  keyForAttribute(attr) {
    return underscore(attr);
  },

  // For single records, look for the data under the customizable
  // "singlePayloadKey" attribute name on the response.
  normalizeSingleResponse(store, primaryModelClass, payload, id, requestType) {
    let key = primaryModelClass.singlePayloadKey;
    if(key) {
      payload = payload[key];
    }

    return this._super(store, primaryModelClass, payload, id, requestType);
  },

  // For multiple records, look for the data under the customizable
  // "arrayPayloadKey" attribute name on the response.
  normalizeArrayResponse(store, primaryModelClass, payload, id, requestType) {
    let key = primaryModelClass.arrayPayloadKey;
    if(key) {
      payload = payload[key];
    }

    return this._super(store, primaryModelClass, payload, id, requestType);
  },

  // When serializing a record, use the customizable "singlePayloadKey"
  // attribute name for the root key.
  serializeIntoHash(hash, typeClass, snapshot, options) {
    let key = typeClass.singlePayloadKey;
    if(key) {
      hash[key] = this.serialize(snapshot, options);
    } else {
      this._super(...arguments);
    }
  },
});
