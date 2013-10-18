Admin.StatsUsers = Ember.Object.extend(Ember.Evented, {
  users: null,
});

Admin.StatsUsers.reopenClass({
  find: function(params) {
    var promise = Ember.Deferred.create();

    $.ajax({
      url: "/admin/stats/users.json",
      data: params,
    }).done(function(data) {
      var users = Admin.StatsUsers.create(data);
      promise.resolve(users);
    }).fail(function() {
      promise.reject();
    });

    return promise;
  },
});
