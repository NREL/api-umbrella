import { run } from '@ember/runloop';

// Call before fetching a model to clear any client-side cache data.
//
// This works around a couple different issues with ember-data, which is why
// we're explicitly documenting this approach with a mixin. It's a bit
// heavy-handed by clearing the entire client-side cache, but since we
// generally want to re-fetch data from the server (in case other users are
// making edits at the same time), it's the simplest current approach.
//
// - Prevents duplicate embedded records from showing up after edits. Without
//   this, if you add a new embedded record, save, and then visit the parent
//   record again, the new embedded record will be duplicated twice. This is
//   because we don't add client-side IDs for these embedded records so the
//   ID-less embedded record and the one with the ID after saving will both
//   be present. See https://github.com/emberjs/data/issues/1829
// - Clears local edits if you make changes to a record, then navigate away
//   (while explicitly confirming that you wanted to navigate away), and then
//   come back to edit the same record. Other approaches to clear these
//   changes don't seem to work as intended or as we want:
//     - reload or shouldReloadRecord continues to persist the local edits
//       despite fetching the record from the remote ajax call again.
//     - rollbackAttributes doesn't work for embedded relationship data.
//
// Note that this should be combined with { reload: true } options on the
// subsequent finds. unloadAll only schedules the unloading for the next
// Ember run cycle, and this combination seems necessary to fully refresh
// things:
//
// https://github.com/emberjs/data/issues/4564
// https://github.com/emberjs/data/issues/4595
function clearStoreCache(store) {
  // Must explicitly wrap in run loop or else the _idToModel mapping is still
  // present (at least in development, but oddly not in production mode).
  // Semi-related: https://github.com/emberjs/data/issues/5041
  run(() => {
    store.unloadAll();
  });
}

export {
  clearStoreCache,
}
