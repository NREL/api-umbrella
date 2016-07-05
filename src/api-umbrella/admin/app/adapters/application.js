import RESTAdapter from 'ember-data/adapters/rest';

export default RESTAdapter.extend({
  buildURL(modelName, id, snapshot, requestType, query) {
    if(snapshot && snapshot.type && snapshot.type.urlRoot) {
      let url = snapshot.type.urlRoot;
      if(id) {
        url += '/' + encodeURIComponent(id);
      }

      return url;
    } else {
      return this._super(...arguments);
    }
  },
});
