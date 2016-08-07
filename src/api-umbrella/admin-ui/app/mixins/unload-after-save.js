import Ember from 'ember';

// A mixin that clears all the client-side model caches after a record is
// saved.
//
// This is to workaround ember-data's current issues of duplicating embedded
// records after saves: https://github.com/emberjs/data/issues/1829 Without
// this, if you add a new embedded record, save, and then visit the parent
// record again, the new embedded record will be duplicated twice. This is
// because we don't add client-side IDs for these embedded records so the
// ID-less embedded record and the one with the ID after saving will both be
// present.
//
// unloadAll is a bit brute-force, but since we generally want to re-fetch
// results from the server anyway (in case other users have made edits), this
// should be fine (but see
// https://github.com/emberjs/data/issues/1829#issuecomment-230282886 for a
// less brute-force, but more complex solution).
export default Ember.Mixin.create({
  didCreate() {
    this.get('store').unloadAll();
    return this._super(...arguments);
  },

  didDelete() {
    this.get('store').unloadAll();
    return this._super(...arguments);
  },

  didUpdate() {
    this.get('store').unloadAll();
    return this._super(...arguments);
  },
});
