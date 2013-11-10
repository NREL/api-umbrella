(function() {

var VERSION = '0.0.10';

if (Ember.libraries) {
  Ember.libraries.register('Ember Model', VERSION);
}


})();

(function() {

function mustImplement(message) {
  var fn = function() {
    var className = this.constructor.toString();

    throw new Error(message.replace('{{className}}', className));
  };
  fn.isUnimplemented = true;
  return fn;
}

Ember.Adapter = Ember.Object.extend({
  find: mustImplement('{{className}} must implement find'),
  findQuery: mustImplement('{{className}} must implement findQuery'),
  findMany: mustImplement('{{className}} must implement findMany'),
  findAll: mustImplement('{{className}} must implement findAll'),
  createRecord: mustImplement('{{className}} must implement createRecord'),
  saveRecord: mustImplement('{{className}} must implement saveRecord'),
  deleteRecord: mustImplement('{{className}} must implement deleteRecord'),

  load: function(record, id, data) {
    record.load(id, data);
  }
});


})();

(function() {

var get = Ember.get;

Ember.FixtureAdapter = Ember.Adapter.extend({
  _findData: function(klass, id) {
    var fixtures = klass.FIXTURES,
        idAsString = id.toString(),
        primaryKey = get(klass, 'primaryKey'),
        data = Ember.A(fixtures).find(function(el) { return (el[primaryKey]).toString() === idAsString; });

    return data;
  },

  find: function(record, id) {
    var data = this._findData(record.constructor, id);

    return new Ember.RSVP.Promise(function(resolve, reject) {
      Ember.run.later(this, function() {
        Ember.run(record, record.load, id, data);
        resolve(record);
      }, 0);
    });
  },

  findMany: function(klass, records, ids) {
    var fixtures = klass.FIXTURES,
        requestedData = [];

    for (var i = 0, l = ids.length; i < l; i++) {
      requestedData.push(this._findData(klass, ids[i]));
    }

    return new Ember.RSVP.Promise(function(resolve, reject) {
      Ember.run.later(this, function() {
        Ember.run(records, records.load, klass, requestedData);
        resolve(records);
      }, 0);
    });
  },

  findAll: function(klass, records) {
    var fixtures = klass.FIXTURES;

    return new Ember.RSVP.Promise(function(resolve, reject) {
      Ember.run.later(this, function() {
        Ember.run(records, records.load, klass, fixtures);
        resolve(records);
      }, 0);
    });
  },

  createRecord: function(record) {
    var klass = record.constructor,
        fixtures = klass.FIXTURES;

    return new Ember.RSVP.Promise(function(resolve, reject) {
      Ember.run.later(this, function() {
        fixtures.push(klass.findFromCacheOrLoad(record.toJSON()));
        record.didCreateRecord();
        resolve(record);
      }, 0);
    });
  },

  saveRecord: function(record) {
    return new Ember.RSVP.Promise(function(resolve, reject) {
      Ember.run.later(this, function() {
        record.didSaveRecord();
        resolve(record);
      }, 0);
    });
  },

  deleteRecord: function(record) {
    return new Ember.RSVP.Promise(function(resolve, reject) {
      Ember.run.later(this, function() {
        record.didDeleteRecord();
        resolve(record);
      }, 0);
    });
  }
});


})();

(function() {

var get = Ember.get,
    set = Ember.set;

Ember.RecordArray = Ember.ArrayProxy.extend(Ember.Evented, {
  isLoaded: false,
  isLoading: Ember.computed.not('isLoaded'),

  load: function(klass, data) {
    set(this, 'content', this.materializeData(klass, data));
    this.notifyLoaded();
  },

  loadForFindMany: function(klass) {
    var content = get(this, '_ids').map(function(id) { return klass.cachedRecordForId(id); });
    set(this, 'content', Ember.A(content));
    this.notifyLoaded();
  },

  notifyLoaded: function() {
    set(this, 'isLoaded', true);
    this.trigger('didLoad');
  },

  materializeData: function(klass, data) {
    return Ember.A(data.map(function(el) {
      return klass.findFromCacheOrLoad(el); // FIXME
    }));
  },

  reload: function() {
    var modelClass = this.get('modelClass'),
        self = this,
        promises;
    
    set(this, 'isLoaded', false);
    if (modelClass._findAllRecordArray === this) {
      modelClass.adapter.findAll(modelClass, this);
    } else if (this._query) {
      modelClass.adapter.findQuery(modelClass, this, this._query);
    } else {
      promises = this.map(function(record) {
        return record.reload();
      });
      Ember.RSVP.all(promises).then(function(data) {
        self.notifyLoaded();
      });
    }
  }
});


})();

(function() {

var get = Ember.get;

Ember.FilteredRecordArray = Ember.RecordArray.extend({
  init: function() {
    if (!get(this, 'modelClass')) {
      throw new Error('FilteredRecordArrays must be created with a modelClass');
    }
    if (!get(this, 'filterFunction')) {
      throw new Error('FilteredRecordArrays must be created with a filterFunction');
    }
    if (!get(this, 'filterProperties')) {
      throw new Error('FilteredRecordArrays must be created with filterProperties');
    }

    var modelClass = get(this, 'modelClass');
    modelClass.registerRecordArray(this);

    this.registerObservers();
    this.updateFilter();

    this._super();
  },

  updateFilter: function() {
    var self = this,
        results = [];
    get(this, 'modelClass').forEachCachedRecord(function(record) {
      if (self.filterFunction(record)) {
        results.push(record);
      }
    });
    this.set('content', Ember.A(results));
  },

  updateFilterForRecord: function(record) {
    var results = get(this, 'content');
    if (this.filterFunction(record) && !results.contains(record)) {
      results.pushObject(record);
    }
  },

  registerObservers: function() {
    var self = this;
    get(this, 'modelClass').forEachCachedRecord(function(record) {
      self.registerObserversOnRecord(record);
    });
  },

  registerObserversOnRecord: function(record) {
    var self = this,
        filterProperties = get(this, 'filterProperties');

    for (var i = 0, l = get(filterProperties, 'length'); i < l; i++) {
      record.addObserver(filterProperties[i], self, 'updateFilterForRecord');
    }
  }
});

})();

(function() {

var get = Ember.get, set = Ember.set;

Ember.ManyArray = Ember.RecordArray.extend({
  _records: null,
  originalContent: null,

  isDirty: function() {
    var originalContent = get(this, 'originalContent'),
        originalContentLength = get(originalContent, 'length'),
        content = get(this, 'content'),
        contentLength = get(content, 'length');

    if (originalContentLength !== contentLength) { return true; }

    var isDirty = false;

    for (var i = 0, l = contentLength; i < l; i++) {
      if (!originalContent.contains(content[i])) {
        isDirty = true;
        break;
      }
    }

    return isDirty;
  }.property('content.[]', 'originalContent'),

  objectAtContent: function(idx) {
    var content = get(this, 'content');

    if (!content.length) { return; }

    return this.materializeRecord(idx);
  },

  save: function() {
    // TODO: loop over dirty records only
    return Ember.RSVP.all(this.map(function(record) {
      return record.save();
    }));
  },

  replaceContent: function(index, removed, added) {
    added = Ember.EnumerableUtils.map(added, function(record) {
      return record._reference;
    }, this);

    this._super(index, removed, added);
  },

  _contentWillChange: function() {
    var content = get(this, 'content');
    if (content) {
      content.removeArrayObserver(this);
      this._setupOriginalContent(content);
    }
  }.observesBefore('content'),

  _contentDidChange: function() {
    var content = get(this, 'content');
    if (content) {
      content.addArrayObserver(this);
      this.arrayDidChange(content, 0, 0, get(content, 'length'));
    }
  }.observes('content'),

  arrayWillChange: function(item, idx, removedCnt, addedCnt) {},

  arrayDidChange: function(item, idx, removedCnt, addedCnt) {
    var parent = get(this, 'parent'), relationshipKey = get(this, 'relationshipKey'),
        isDirty = get(this, 'isDirty');

    if (isDirty) {
      parent._relationshipBecameDirty(relationshipKey);
    } else {
      parent._relationshipBecameClean(relationshipKey);
    }
  },

  _setupOriginalContent: function(content) {
    content = content || get(this, 'content');
    if (content) {
      set(this, 'originalContent', content.slice());
    }
  },

  init: function() {
    this._super();
    this._setupOriginalContent();
    this._contentDidChange();
  }
});

Ember.HasManyArray = Ember.ManyArray.extend({
  materializeRecord: function(idx) {
    var klass = get(this, 'modelClass'),
        content = get(this, 'content'),
        reference = content.objectAt(idx),
        record;

    if (reference.record) {
      record = reference.record;
    } else {
      record = klass.find(reference.id);
    }

    return record;
  },

  toJSON: function() {
    var ids = [], content = this.get('content');

    content.forEach(function(reference) {
      if (reference.id) {
        ids.push(reference.id);
      }
    });

    return ids;
  }
});

Ember.EmbeddedHasManyArray = Ember.ManyArray.extend({
  create: function(attrs) {
    var klass = get(this, 'modelClass'),
        record = klass.create(attrs);

    this.pushObject(record);

    return record; // FIXME: inject parent's id
  },

  materializeRecord: function(idx) {
    var klass = get(this, 'modelClass'),
        primaryKey = get(klass, 'primaryKey'),
        content = get(this, 'content'),
        reference = content.objectAt(idx),
        attrs = reference.data;

    if (reference.record) {
      return reference.record;
    } else {
      var record = klass.create({ _reference: reference });
      reference.record = record;
      if (attrs) {
        record.load(attrs[primaryKey], attrs);
      }
      return record;
    }
  },

  toJSON: function() {
    return this.map(function(record) {
      return record.toJSON();
    });
  }
});


})();

(function() {

var get = Ember.get,
    set = Ember.set,
    setProperties = Ember.setProperties,
    meta = Ember.meta,
    underscore = Ember.String.underscore;

function contains(array, element) {
  for (var i = 0, l = array.length; i < l; i++) {
    if (array[i] === element) { return true; }
  }
  return false;
}

function concatUnique(toArray, fromArray) {
  var e;
  for (var i = 0, l = fromArray.length; i < l; i++) {
    e = fromArray[i];
    if (!contains(toArray, e)) { toArray.push(e); }
  }
  return toArray;
}

function hasCachedValue(object, key) {
  var objectMeta = meta(object, false);
  if (objectMeta) {
    return key in objectMeta.cache;
  }
}

Ember.run.queues.push('data');

Ember.Model = Ember.Object.extend(Ember.Evented, {
  isLoaded: true,
  isLoading: Ember.computed.not('isLoaded'),
  isNew: true,
  isDeleted: false,
  _dirtyAttributes: null,

  /**
    Called when attribute is accessed.

    @method getAttr
    @param key {String} key which is being accessed
    @param value {Object} value, which will be returned from getter by default
  */
  getAttr: function(key, value) {
    return value;
  },

  isDirty: function() {
    var dirtyAttributes = get(this, '_dirtyAttributes');
    return dirtyAttributes && dirtyAttributes.length !== 0 || false;
  }.property('_dirtyAttributes.length'),

  _relationshipBecameDirty: function(name) {
    var dirtyAttributes = get(this, '_dirtyAttributes');
    if (!dirtyAttributes.contains(name)) { dirtyAttributes.pushObject(name); }
  },

  _relationshipBecameClean: function(name) {
    var dirtyAttributes = get(this, '_dirtyAttributes');
    dirtyAttributes.removeObject(name);
  },

  dataKey: function(key) {
    var camelizeKeys = get(this.constructor, 'camelizeKeys');
    var meta = this.constructor.metaForProperty(key);
    if (meta.options && meta.options.key) {
      return camelizeKeys ? underscore(meta.options.key) : meta.options.key;
    }
    return camelizeKeys ? underscore(key) : key;
  },

  init: function() {
    this._createReference();
    if (!this._dirtyAttributes) {
      set(this, '_dirtyAttributes', []);
    }
    this._super();
  },

  _createReference: function() {
    var reference = this._reference,
        id = this.getPrimaryKey();

    if (!reference) {
      reference = this.constructor._getOrCreateReferenceForId(id);
      reference.record = this;
      this._reference = reference;
    } else if (reference.id !== id) {
      reference.id = id;
      this.constructor._cacheReference(reference);
    }

    if (!reference.id) {
      reference.id = id;
    }

    return reference;
  },

  getPrimaryKey: function() {
    return get(this, get(this.constructor, 'primaryKey'));
  },

  load: function(id, hash) {
    var data = {};
    data[get(this.constructor, 'primaryKey')] = id;
    set(this, '_data', Ember.merge(data, hash));

    // eagerly load embedded data
    var relationships = this.constructor._relationships || [], meta = Ember.meta(this), relationshipKey, relationship, relationshipMeta, relationshipData, relationshipType;
    for (var i = 0, l = relationships.length; i < l; i++) {
      relationshipKey = relationships[i];
      relationship = meta.descs[relationshipKey];
      relationshipMeta = relationship.meta();

      if (relationshipMeta.options.embedded) {
        relationshipType = relationshipMeta.type;
        if (typeof relationshipType === "string") {
          relationshipType = Ember.get(Ember.lookup, relationshipType);
        }

        relationshipData = data[relationshipKey];
        if (relationshipData) {
          relationshipType.load(relationshipData);
        }
      }
    }

    set(this, 'isLoaded', true);
    set(this, 'isNew', false);
    this._createReference();
    this.trigger('didLoad');
  },

  didDefineProperty: function(proto, key, value) {
    if (value instanceof Ember.Descriptor) {
      var meta = value.meta();
      var klass = proto.constructor;

      if (meta.isAttribute) {
        if (!klass._attributes) { klass._attributes = []; }
        klass._attributes.push(key);
      } else if (meta.isRelationship) {
        if (!klass._relationships) { klass._relationships = []; }
        klass._relationships.push(key);
        meta.relationshipKey = key;
      }
    }
  },

  serializeHasMany: function(key, meta) {
    return this.get(key).toJSON();
  },

  serializeBelongsTo: function(key, meta) {
    if (meta.options.embedded) {
      var record = this.get(key);
      return record ? record.toJSON() : null;
    } else {
      var primaryKey = get(meta.getType(), 'primaryKey');
      return this.get(key + '.' + primaryKey);
    }
  },

  toJSON: function() {
    var key, meta,
        json = {},
        attributes = this.constructor.getAttributes(),
        relationships = this.constructor.getRelationships(),
        properties = attributes ? this.getProperties(attributes) : {},
        rootKey = get(this.constructor, 'rootKey');

    for (key in properties) {
      meta = this.constructor.metaForProperty(key);
      if (meta.type && meta.type.serialize) {
        json[this.dataKey(key)] = meta.type.serialize(properties[key]);
      } else if (meta.type && Ember.Model.dataTypes[meta.type]) {
        json[this.dataKey(key)] = Ember.Model.dataTypes[meta.type].serialize(properties[key]);
      } else {
        json[this.dataKey(key)] = properties[key];
      }
    }

    if (relationships) {
      var data, relationshipKey;

      for(var i = 0; i < relationships.length; i++) {
        key = relationships[i];
        meta = this.constructor.metaForProperty(key);
        relationshipKey = meta.options.key || key;

        if (meta.kind === 'belongsTo') {
          data = this.serializeBelongsTo(key, meta);
        } else {
          data = this.serializeHasMany(key, meta);
        }

        json[relationshipKey] = data;

      }
    }

    if (rootKey) {
      var jsonRoot = {};
      jsonRoot[rootKey] = json;
      return jsonRoot;
    } else {
      return json;
    }
  },

  save: function() {
    var adapter = this.constructor.adapter;
    set(this, 'isSaving', true);
    if (get(this, 'isNew')) {
      return adapter.createRecord(this);
    } else if (get(this, 'isDirty')) {
      return adapter.saveRecord(this);
    } else { // noop, return a resolved promise
      var self = this,
          promise = new Ember.RSVP.Promise(function(resolve, reject) {
            resolve(self);
          });
      set(this, 'isSaving', false);
      return promise;
    }
  },

  reload: function() {
    return this.constructor.reload(this.get(get(this.constructor, 'primaryKey')));
  },

  revert: function() {
    this.getWithDefault('_dirtyAttributes', []).clear();
    this.notifyPropertyChange('_data');
  },

  didCreateRecord: function() {
    var primaryKey = get(this.constructor, 'primaryKey'),
        id = get(this, primaryKey);

    set(this, 'isNew', false);

    set(this, '_dirtyAttributes', []);
    this.constructor.addToRecordArrays(this);
    this.trigger('didCreateRecord');
    this.didSaveRecord();
  },

  didSaveRecord: function() {
    set(this, 'isSaving', false);
    this.trigger('didSaveRecord');
    if (this.get('isDirty')) { this._copyDirtyAttributesToData(); }
  },

  deleteRecord: function() {
    return this.constructor.adapter.deleteRecord(this);
  },

  didDeleteRecord: function() {
    this.constructor.removeFromRecordArrays(this);
    set(this, 'isDeleted', true);
    this.trigger('didDeleteRecord');
  },

  _copyDirtyAttributesToData: function() {
    if (!this._dirtyAttributes) { return; }
    var dirtyAttributes = this._dirtyAttributes,
        data = get(this, '_data'),
        key;

    if (!data) {
      data = {};
      set(this, '_data', data);
    }
    for (var i = 0, l = dirtyAttributes.length; i < l; i++) {
      // TODO: merge Object.create'd object into prototype
      key = dirtyAttributes[i];
      data[this.dataKey(key)] = this.cacheFor(key);
    }
    set(this, '_dirtyAttributes', []);
  },

  dataDidChange: Ember.observer(function() {
    this._reloadHasManys();
  }, '_data'),

  _registerHasManyArray: function(array) {
    if (!this._hasManyArrays) { this._hasManyArrays = Ember.A([]); }

    this._hasManyArrays.pushObject(array);
  },

  _reloadHasManys: function() {
    if (!this._hasManyArrays) { return; }
    var i, j;
    for (i = 0; i < this._hasManyArrays.length; i++) {
      var array = this._hasManyArrays[i],
          hasManyContent = this._getHasManyContent(get(array, 'key'), get(array, 'modelClass'), get(array, 'embedded'));
        for (j = 0; j < array.get('length'); j++) {
          if (array.objectAt(j).get('isNew')) {
            hasManyContent.addObject(array.objectAt(j)._reference);
          }
        }
      set(array, 'content', hasManyContent);
    }
  },

  _getHasManyContent: function(key, type, embedded) {
    var content = get(this, '_data.' + key);

    if (content) {
      var mapFunction, primaryKey, reference;
      if (embedded) {
        primaryKey = get(type, 'primaryKey');
        mapFunction = function(attrs) {
          reference = type._getOrCreateReferenceForId(attrs[primaryKey]);
          reference.data = attrs;
          return reference;
        };
      } else {
        mapFunction = function(id) { return type._getOrCreateReferenceForId(id); };
      }
      content = Ember.EnumerableUtils.map(content, mapFunction);
    }

    return Ember.A(content || []);
  }
});

Ember.Model.reopenClass({
  primaryKey: 'id',

  adapter: Ember.Adapter.create(),

  _clientIdCounter: 1,

  getAttributes: function() {
    this.proto(); // force class "compilation" if it hasn't been done.
    var attributes = this._attributes || [];
    if (typeof this.superclass.getAttributes === 'function') {
      attributes = this.superclass.getAttributes().concat(attributes);
    }
    return attributes;
  },

  getRelationships: function() {
    this.proto(); // force class "compilation" if it hasn't been done.
    var relationships = this._relationships || [];
    if (typeof this.superclass.getRelationships === 'function') {
      relationships = this.superclass.getRelationships().concat(relationships);
    }
    return relationships;
  },

  fetch: function(id) {
    if (!arguments.length) {
      return this._findFetchAll(true);
    } else if (Ember.isArray(id)) {
      return this._findFetchMany(id, true);
    } else if (typeof id === 'object') {
      return this._findFetchQuery(id, true);
    } else {
      return this._findFetchById(id, true);
    }
  },

  find: function(id) {
    if (!arguments.length) {
      return this._findFetchAll(false);
    } else if (Ember.isArray(id)) {
      return this._findFetchMany(id, false);
    } else if (typeof id === 'object') {
      return this._findFetchQuery(id, false);
    } else {
      return this._findFetchById(id, false);
    }
  },

  findQuery: function(params) {
    return this._findFetchQuery(params, false);
  },

  fetchQuery: function(params) {
    return this._findFetchQuery(params, true);
  },

  _findFetchQuery: function(params, isFetch) {
    var records = Ember.RecordArray.create({modelClass: this, _query: params});

    var promise = this.adapter.findQuery(this, records, params);

    return isFetch ? promise : records;
  },

  findMany: function(ids) {
    return this._findFetchMany(ids, false);
  },

  fetchMany: function(ids) {
    return this._findFetchMany(ids, true);
  },

  _findFetchMany: function(ids, isFetch) {
    Ember.assert("findFetchMany requires an array", Ember.isArray(ids));

    var records = Ember.RecordArray.create({_ids: ids, modelClass: this}),
        deferred;

    if (!this.recordArrays) { this.recordArrays = []; }
    this.recordArrays.push(records);

    if (this._currentBatchIds) {
      concatUnique(this._currentBatchIds, ids);
      this._currentBatchRecordArrays.push(records);
    } else {
      this._currentBatchIds = concatUnique([], ids);
      this._currentBatchRecordArrays = [records];
    }

    if (isFetch) {
      deferred = Ember.Deferred.create();
      Ember.set(deferred, 'resolveWith', records);

      if (!this._currentBatchDeferreds) { this._currentBatchDeferreds = []; }
      this._currentBatchDeferreds.push(deferred);
    }

    Ember.run.scheduleOnce('data', this, this._executeBatch);

    return isFetch ? deferred : records;
  },

  findAll: function() {
    return this._findFetchAll(false);
  },

  fetchAll: function() {
    return this._findFetchAll(true);
  },

  _findFetchAll: function(isFetch) {
    var self = this;

    if (this._findAllRecordArray) {
      if (isFetch) {
        return new Ember.RSVP.Promise(function(resolve) {
          resolve(self._findAllRecordArray);
        });
      } else {
        return this._findAllRecordArray;
      }
    }

    var records = this._findAllRecordArray = Ember.RecordArray.create({modelClass: this});

    var promise = this.adapter.findAll(this, records);

    // Remove the cached record array if the promise is rejected
    if (promise.then) {
      promise.then(null, function() {
        self._findAllRecordArray = null;
        return Ember.RSVP.reject.apply(null, arguments);
      });
    }

    return isFetch ? promise : records;
  },

  findById: function(id) {
    return this._findFetchById(id, false);
  },

  fetchById: function(id) {
    return this._findFetchById(id, true);
  },

  _findFetchById: function(id, isFetch) {
    var record = this.cachedRecordForId(id),
        isLoaded = get(record, 'isLoaded'),
        adapter = get(this, 'adapter'),
        deferredOrPromise;

    if (isLoaded) {
      if (isFetch) {
        return new Ember.RSVP.Promise(function(resolve, reject) {
          resolve(record);
        });
      } else {
        return record;
      }
    }

    deferredOrPromise = this._fetchById(record, id);

    return isFetch ? deferredOrPromise : record;
  },

  _currentBatchIds: null,
  _currentBatchRecordArrays: null,
  _currentBatchDeferreds: null,

  reload: function(id) {
    var record = this.cachedRecordForId(id);
    record.set('isLoaded', false);
    return this._fetchById(record, id);
  },

  _fetchById: function(record, id) {
    var adapter = get(this, 'adapter'),
        deferred;

    if (adapter.findMany && !adapter.findMany.isUnimplemented) {
      if (this._currentBatchIds) {
        if (!contains(this._currentBatchIds, id)) { this._currentBatchIds.push(id); }
      } else {
        this._currentBatchIds = [id];
        this._currentBatchRecordArrays = [];
      }

      deferred = Ember.Deferred.create();

      //Attached the record to the deferred so we can resolove it later.
      Ember.set(deferred, 'resolveWith', record);

      if (!this._currentBatchDeferreds) { this._currentBatchDeferreds = []; }
      this._currentBatchDeferreds.push(deferred);

      Ember.run.scheduleOnce('data', this, this._executeBatch);

      return deferred;
    } else {
      return adapter.find(record, id);
    }
  },

  _executeBatch: function() {
    var batchIds = this._currentBatchIds,
        batchRecordArrays = this._currentBatchRecordArrays,
        batchDeferreds = this._currentBatchDeferreds,
        self = this,
        requestIds = [],
        promise,
        i;

    this._currentBatchIds = null;
    this._currentBatchRecordArrays = null;
    this._currentBatchDeferreds = null;

    for (i = 0; i < batchIds.length; i++) {
      if (!this.cachedRecordForId(batchIds[i]).get('isLoaded')) {
        requestIds.push(batchIds[i]);
      }
    }

    if (batchIds.length === 1) {
      promise = get(this, 'adapter').find(this.cachedRecordForId(batchIds[0]), batchIds[0]);
    } else {
      var recordArray = Ember.RecordArray.create({_ids: batchIds});
      if (requestIds.length === 0) {
        promise = new Ember.RSVP.Promise(function(resolve, reject) { resolve(recordArray); });
        recordArray.notifyLoaded();
      } else {
        promise = get(this, 'adapter').findMany(this, recordArray, requestIds);
      }
    }

    promise.then(function() {
      for (var i = 0, l = batchRecordArrays.length; i < l; i++) {
        batchRecordArrays[i].loadForFindMany(self);
      }

      if (batchDeferreds) {
        for (i = 0, l = batchDeferreds.length; i < l; i++) {
          var resolveWith = Ember.get(batchDeferreds[i], 'resolveWith');
          batchDeferreds[i].resolve(resolveWith);
        }
      }
    }).then(null, function(errorXHR) {
      if (batchDeferreds) {
        for (var i = 0, l = batchDeferreds.length; i < l; i++) {
          batchDeferreds[i].reject(errorXHR);
        }
      }
    });
  },

  getCachedReferenceRecord: function(id){
    var ref = this._getReferenceById(id);
    if(ref) return ref.record;
    return undefined;
  },

  cachedRecordForId: function(id) {
    var record = this.getCachedReferenceRecord(id);

    if (!record) {
      var primaryKey = get(this, 'primaryKey'),
        attrs = {isLoaded: false};
      attrs[primaryKey] = id;
      record = this.create(attrs);
      var sideloadedData = this.sideloadedData && this.sideloadedData[id];
      if (sideloadedData) {
        record.load(id, sideloadedData);
      }
    }

    return record;
  },


  addToRecordArrays: function(record) {
    if (this._findAllRecordArray) {
      this._findAllRecordArray.pushObject(record);
    }
    if (this.recordArrays) {
      this.recordArrays.forEach(function(recordArray) {
        if (recordArray instanceof Ember.FilteredRecordArray) {
          recordArray.registerObserversOnRecord(record);
          recordArray.updateFilter();
        } else {
          recordArray.pushObject(record);
        }
      });
    }
  },

  unload: function (record) {
    this.removeFromRecordArrays(record);
    var primaryKey = record.get(get(this, 'primaryKey'));
    this.removeFromCache(primaryKey);
  },

  clearCache: function () {
    this.sideloadedData = undefined;
    this._referenceCache = undefined;
  },

  removeFromCache: function (key) {
    if (this.sideloadedData && this.sideloadedData[key]) {
      delete this.sideloadedData[key];
    }
    if(this._referenceCache && this._referenceCache[key]) {
      delete this._referenceCache[key];
    }
  },

  removeFromRecordArrays: function(record) {
    if (this._findAllRecordArray) {
      this._findAllRecordArray.removeObject(record);
    }
    if (this.recordArrays) {
      this.recordArrays.forEach(function(recordArray) {
        recordArray.removeObject(record);
      });
    }
  },

  // FIXME
  findFromCacheOrLoad: function(data) {
    var record;
    if (!data[get(this, 'primaryKey')]) {
      record = this.create({isLoaded: false});
    } else {
      record = this.cachedRecordForId(data[get(this, 'primaryKey')]);
    }
    // set(record, 'data', data);
    record.load(data[get(this, 'primaryKey')], data);
    return record;
  },

  registerRecordArray: function(recordArray) {
    if (!this.recordArrays) { this.recordArrays = []; }
    this.recordArrays.push(recordArray);
  },

  unregisterRecordArray: function(recordArray) {
    if (!this.recordArrays) { return; }
    Ember.A(this.recordArrays).removeObject(recordArray);
  },

  forEachCachedRecord: function(callback) {
    var ids = Object.keys(this._referenceCache);
    ids.map(function(id) {
      return this._getReferenceById(id).record;
    }, this).forEach(callback);
  },

  load: function(hashes) {
    if (Ember.typeOf(hashes) !== 'array') { hashes = [hashes]; }

    if (!this.sideloadedData) { this.sideloadedData = {}; }

    for (var i = 0, l = hashes.length; i < l; i++) {
      var hash = hashes[i],
          primaryKey = hash[get(this, 'primaryKey')],
          record = this.getCachedReferenceRecord(primaryKey);

      if (record) {
        record.load(primaryKey, hash);
      } else {
        this.sideloadedData[primaryKey] = hash;
      }
    }
  },

  _getReferenceById: function(id) {
    if (!this._referenceCache) { this._referenceCache = {}; }
    return this._referenceCache[id];
  },

  _getOrCreateReferenceForId: function(id) {
    var reference = this._getReferenceById(id);

    if (!reference) {
      reference = this._createReference(id);
    }

    return reference;
  },

  _createReference: function(id) {
    if (!this._referenceCache) { this._referenceCache = {}; }

    Ember.assert('The id ' + id + ' has alread been used with another record of type ' + this.toString() + '.', !id || !this._referenceCache[id]);

    var reference = {
      id: id,
      clientId: this._clientIdCounter++
    };

    this._cacheReference(reference);

    return reference;
  },

  _cacheReference: function(reference) {
    // if we're creating an item, this process will be done
    // later, once the object has been persisted.
    if (reference.id) {
      this._referenceCache[reference.id] = reference;
    }
  }
});


})();

(function() {

var get = Ember.get;

Ember.hasMany = function(type, options) {
  options = options || {};

  var meta = { type: type, isRelationship: true, options: options, kind: 'hasMany' },
      key = options.key;

  return Ember.computed(function() {
    if (typeof type === "string") {
      type = Ember.get(Ember.lookup, type);
    }

    return this.getHasMany(key, type, meta);
  }).property().meta(meta);
};

Ember.Model.reopen({
  getHasMany: function(key, type, meta) {
    var embedded = meta.options.embedded,
        collectionClass = embedded ? Ember.EmbeddedHasManyArray : Ember.HasManyArray;

    var collection = collectionClass.create({
      parent: this,
      modelClass: type,
      content: this._getHasManyContent(key, type, embedded),
      embedded: embedded,
      key: key,
      relationshipKey: meta.relationshipKey
    });

    this._registerHasManyArray(collection);

    return collection;
  }
});


})();

(function() {

var get = Ember.get,
    set = Ember.set;

function getType() {
  if (typeof this.type === "string") {
    this.type =  Ember.get(Ember.lookup, this.type);
  }
  return this.type;
}

Ember.belongsTo = function(type, options) {
  options = options || {};

  var meta = { type: type, isRelationship: true, options: options, kind: 'belongsTo', getType: getType },
      relationshipKey = options.key;

  return Ember.computed(function(key, value, oldValue) {
    type = meta.getType();

    var dirtyAttributes = get(this, '_dirtyAttributes'),
        createdDirtyAttributes = false;

    if (!dirtyAttributes) {
      dirtyAttributes = [];
      createdDirtyAttributes = true;
    }

    if (arguments.length > 1) {
      if (value) {
        Ember.assert(Ember.String.fmt('Attempted to set property of type: %@ with a value of type: %@',
                     [value.constructor, type]),
                     value instanceof type);

        if (oldValue !== value) {
          dirtyAttributes.pushObject(key);
        } else {
          dirtyAttributes.removeObject(key);
        }

        if (createdDirtyAttributes) {
          set(this, '_dirtyAttributes', dirtyAttributes);
        }
      }
      return value === undefined ? null : value;  
    } else {
      return this.getBelongsTo(relationshipKey, type, meta);
    }
  }).property('_data').meta(meta);
};

Ember.Model.reopen({
  getBelongsTo: function(key, type, meta) {
    var idOrAttrs = get(this, '_data.' + key),
        record;

    if (Ember.isNone(idOrAttrs)) {
      return null;
    }

    if (meta.options.embedded) {
      var primaryKey = get(type, 'primaryKey'),
        id = idOrAttrs[primaryKey];
      record = type.create({ isLoaded: false, id: id });
      record.load(id, idOrAttrs);
    } else {
      record = type.find(idOrAttrs);
    }

    return record;
  }
});


})();

(function() {

var get = Ember.get,
    set = Ember.set,
    meta = Ember.meta;

Ember.Model.dataTypes = {};

Ember.Model.dataTypes[Date] = {
  deserialize: function(string) {
    if (!string) { return null; }
    return new Date(string);
  },
  serialize: function (date) {
    if (!date) { return null; }
    return date.toISOString();
  },
  isEqual: function(obj1, obj2) {
    if (obj1 instanceof Date) { obj1 = this.serialize(obj1); }
    if (obj2 instanceof Date) { obj2 = this.serialize(obj2); }
    return obj1 === obj2;
  }
};

Ember.Model.dataTypes[Number] = {
  deserialize: function(string) {
    if (!string && string !== 0) { return null; }
    return Number(string);
  },
  serialize: function (number) {
    if (!number && number !== 0) { return null; }
    return Number(number);
  }
};

function deserialize(value, type) {
  if (type && type.deserialize) {
    return type.deserialize(value);
  } else if (type && Ember.Model.dataTypes[type]) {
    return Ember.Model.dataTypes[type].deserialize(value);
  } else {
    return value;
  }
}

function serialize(value, type) {
  if (type && type.serialize) {
    return type.serialize(value);
  } else if (type && Ember.Model.dataTypes[type]) {
    return Ember.Model.dataTypes[type].serialize(value);
  } else {
    return value;
  }
}

Ember.attr = function(type, options) {
  return Ember.computed(function(key, value) {
    var data = get(this, '_data'),
        dataKey = this.dataKey(key),
        dataValue = data && get(data, dataKey),
        beingCreated = meta(this).proto === this,
        dirtyAttributes = get(this, '_dirtyAttributes'),
        createdDirtyAttributes = false;

    if (!dirtyAttributes) {
      dirtyAttributes = [];
      createdDirtyAttributes = true;
    }

    if (arguments.length === 2) {
      if (beingCreated) {
        if (!data) {
          data = {};
          set(this, '_data', data);
        }
        dataValue = data[dataKey] = value;
      }

      if (dataValue !== serialize(value, type)) {
        dirtyAttributes.pushObject(key);
      } else {
        dirtyAttributes.removeObject(key);
      }

      if (createdDirtyAttributes) {
        set(this, '_dirtyAttributes', dirtyAttributes);
      }

      return value;
    }

    return this.getAttr(key, deserialize(dataValue, type));
  }).property('_data').meta({isAttribute: true, type: type, options: options});
};


})();

(function() {

var get = Ember.get;

Ember.RESTAdapter = Ember.Adapter.extend({
  find: function(record, id) {
    var url = this.buildURL(record.constructor, id),
        self = this;

    return this.ajax(url).then(function(data) {
      self.didFind(record, id, data);
      return record;
    });
  },

  didFind: function(record, id, data) {
    var rootKey = get(record.constructor, 'rootKey'),
        dataToLoad = rootKey ? data[rootKey] : data;

    record.load(id, dataToLoad);
  },

  findAll: function(klass, records) {
    var url = this.buildURL(klass),
        self = this;

    return this.ajax(url).then(function(data) {
      self.didFindAll(klass, records, data);
      return records;
    });
  },

  didFindAll: function(klass, records, data) {
    var collectionKey = get(klass, 'collectionKey'),
        dataToLoad = collectionKey ? data[collectionKey] : data;

    records.load(klass, dataToLoad);
  },

  findQuery: function(klass, records, params) {
    var url = this.buildURL(klass),
        self = this;

    return this.ajax(url, params).then(function(data) {
      self.didFindQuery(klass, records, params, data);
      return records;
    });
  },

  didFindQuery: function(klass, records, params, data) {
      var collectionKey = get(klass, 'collectionKey'),
          dataToLoad = collectionKey ? data[collectionKey] : data;

      records.load(klass, dataToLoad);
  },

  createRecord: function(record) {
    var url = this.buildURL(record.constructor),
        self = this;

    return this.ajax(url, record.toJSON(), "POST").then(function(data) {
      self.didCreateRecord(record, data);
      return record;
    });
  },

  didCreateRecord: function(record, data) {
    var rootKey = get(record.constructor, 'rootKey'),
        primaryKey = get(record.constructor, 'primaryKey'),
        dataToLoad = rootKey ? data[rootKey] : data;
    record.load(dataToLoad[primaryKey], dataToLoad);
    record.didCreateRecord();
  },

  saveRecord: function(record) {
    var primaryKey = get(record.constructor, 'primaryKey'),
        url = this.buildURL(record.constructor, get(record, primaryKey)),
        self = this;

    return this.ajax(url, record.toJSON(), "PUT").then(function(data) {  // TODO: Some APIs may or may not return data
      self.didSaveRecord(record, data);
      return record;
    });
  },

  didSaveRecord: function(record, data) {
    record.didSaveRecord();
  },

  deleteRecord: function(record) {
    var primaryKey = get(record.constructor, 'primaryKey'),
        url = this.buildURL(record.constructor, get(record, primaryKey)),
        self = this;

    return this.ajax(url, record.toJSON(), "DELETE").then(function(data) {  // TODO: Some APIs may or may not return data
      self.didDeleteRecord(record, data);
    });
  },

  didDeleteRecord: function(record, data) {
    record.didDeleteRecord();
  },

  ajax: function(url, params, method, settings) {
    return this._ajax(url, params, (method || "GET"), settings);
  },

  buildURL: function(klass, id) {
    var urlRoot = get(klass, 'url');
    if (!urlRoot) { throw new Error('Ember.RESTAdapter requires a `url` property to be specified'); }

    if (!Ember.isEmpty(id)) {
      return urlRoot + "/" + id + ".json";
    } else {
      return urlRoot + ".json";
    }
  },

  ajaxSettings: function(url, method) {
    return {
      url: url,
      type: method,
      dataType: "json"
    };
  },

  _ajax: function(url, params, method, settings) {
    if (!settings) {
      settings = this.ajaxSettings(url, method);
    }

    return new Ember.RSVP.Promise(function(resolve, reject) {
      if (params) {
        if (method === "GET") {
          settings.data = params;
        } else {
          settings.contentType = "application/json; charset=utf-8";
          settings.data = JSON.stringify(params);
        }
      }

      settings.success = function(json) {
        Ember.run(null, resolve, json);
      };

      settings.error = function(jqXHR, textStatus, errorThrown) {
        // https://github.com/ebryn/ember-model/issues/202
        if (jqXHR) {
          jqXHR.then = null;
        }

        Ember.run(null, reject, jqXHR);
      };


      Ember.$.ajax(settings);
   });
  }
});


})();

(function() {

var get = Ember.get;

Ember.LoadPromise = Ember.Object.extend(Ember.DeferredMixin, {
  init: function() {
    this._super.apply(this, arguments);

    var target = get(this, 'target');

    if (get(target, 'isLoaded') && !get(target, 'isNew')) {
      this.resolve(target);
    } else {
      target.one('didLoad', this, function() {
        this.resolve(target);
      });
    }
  }
});

Ember.loadPromise = function(target) {
  if (Ember.isNone(target)) {
    return null;
  } else if (target.then) {
    return target;
  } else {
    return Ember.LoadPromise.create({target: target});
  }
};


})();

(function() {

// This is a debug adapter for the Ember Extension, don't let the fact this is called an "adapter" confuse you.
// Most copied from: https://github.com/emberjs/data/blob/master/packages/ember-data/lib/system/debug/debug_adapter.js

if (!Ember.DataAdapter) { return; }

var get = Ember.get, capitalize = Ember.String.capitalize, underscore = Ember.String.underscore;

var DebugAdapter = Ember.DataAdapter.extend({
  getFilters: function() {
    return [
      { name: 'isNew', desc: 'New' },
      { name: 'isModified', desc: 'Modified' },
      { name: 'isClean', desc: 'Clean' }
    ];
  },

  detect: function(klass) {
    return klass !== Ember.Model && Ember.Model.detect(klass);
  },

  columnsForType: function(type) {
    var columns = [], count = 0, self = this;
    Ember.A(get(type.proto(), 'attributes')).forEach(function(name, meta) {
        if (count++ > self.attributeLimit) { return false; }
        var desc = capitalize(underscore(name).replace('_', ' '));
        columns.push({ name: name, desc: desc });
    });
    return columns;
  },

  getRecords: function(type) {
    var records = [];
    type.forEachCachedRecord(function(record) { records.push(record); });
    return records;
  },

  getRecordColumnValues: function(record) {
    var self = this, count = 0,
        columnValues = { id: get(record, 'id') };

    record.get('attributes').forEach(function(key) {
      if (count++ > self.attributeLimit) {
        return false;
      }
      var value = get(record, key);
      columnValues[key] = value;
    });
    return columnValues;
  },

  getRecordKeywords: function(record) {
    var keywords = [], keys = Ember.A(['id']);
    record.get('attributes').forEach(function(key) {
      keys.push(key);
    });
    keys.forEach(function(key) {
      keywords.push(get(record, key));
    });
    return keywords;
  },

  getRecordFilterValues: function(record) {
    return {
      isNew: record.get('isNew'),
      isModified: record.get('isDirty') && !record.get('isNew'),
      isClean: !record.get('isDirty')
    };
  },

  getRecordColor: function(record) {
    var color = 'black';
    if (record.get('isNew')) {
      color = 'green';
    } else if (record.get('isDirty')) {
      color = 'blue';
    }
    return color;
  },

  observeRecord: function(record, recordUpdated) {
    var releaseMethods = Ember.A(), self = this,
        keysToObserve = Ember.A(['id', 'isNew', 'isDirty']);

    record.get('attributes').forEach(function(key) {
      keysToObserve.push(key);
    });

    keysToObserve.forEach(function(key) {
      var handler = function() {
        recordUpdated(self.wrapRecord(record));
      };
      Ember.addObserver(record, key, handler);
      releaseMethods.push(function() {
        Ember.removeObserver(record, key, handler);
      });
    });

    var release = function() {
      releaseMethods.forEach(function(fn) { fn(); } );
    };

    return release;
  }
});

Ember.onLoad('Ember.Application', function(Application) {
  Application.initializer({
    name: "dataAdapter",

    initialize: function(container, application) {
      application.register('dataAdapter:main', DebugAdapter);
    }
  });
});

})();