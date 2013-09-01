Admin.NestedFormController = Ember.ObjectController.extend({
  needs: ['modal'],

  titleBase: null,
  apiModel: null,
  parentCollection: null,
  isNew: null,
  originalData: null,

  setup: function(apiModel, parentCollectionName) {
    this.set('apiModel', apiModel);
    this.set('parentCollection', apiModel.get(parentCollectionName));
  },

  add: function(apiModel, parentCollectionName) {
    this.setup(apiModel, parentCollectionName);
    this.set('model', this.get('parentCollection').create());

    this.set('controllers.modal.title', 'Add ' + this.get('titleBase'));
    this.set('isNew', true);
  },

  edit: function(apiModel, parentCollectionName, record) {
    this.setup(apiModel, parentCollectionName);
    this.set('model', record);

    this.set('controllers.modal.title', 'Edit ' + this.get('titleBase'));
    this.set('isNew', false);
    this.set('originalData', record.toJSON());
  },

  actions: {
    ok: function() {
      this.send('closeModal');
    },

    cancel: function() {
      if(this.get('isNew')) {
        this.get('parentCollection').removeObject(this.get('model'));
      } else {
        var data = this.get('originalData');
        this.get('model').load(data._id, data);
      }

      this.send('closeModal');
    },
  },
});
