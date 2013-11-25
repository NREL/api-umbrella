Admin.StatsUsersTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().dataTable({
      "bProcessing": true,
      "bServerSide": true,
      "bFilter": false,
      "bSearchable": false,
      "sAjaxSource": "/admin/stats/users.json",
      "fnServerParams": _.bind(function(aoData) {
        var query = this.get('controller.query.params');
        for(var key in query) {
          aoData.push({ name: key, value: query[key] });
        }
      }, this),
      "sDom": 'rt<"row-fluid"<"span3 table-info"i><"span6 table-pagination"p><"span3 table-length"l>>',
      "oLanguage": {
        "sProcessing": '<i class="icon-spinner icon-spin icon-large"></i>'
      },
      "aaSorting": [[4, "desc"]],
      "aoColumns": [
        {
          mData: "email",
          sTitle: "Email",
          sDefaultContent: "-",
          mRender: _.bind(function(email, type, data) {
            if(type === 'display' && email && email !== '-') {
              var params = _.clone(this.get('controller.query.params'));
              params.search = 'user_id:"' + data.id + '"';
              var link = '#/stats/logs/' + $.param(params);

              return '<a href="' + link + '">' + _.escape(email) + '</a>';
            }

            return email;
          }, this),
        },
        {
          mData: "first_name",
          sTitle: "First Name",
          sDefaultContent: "-",
        },
        {
          mData: "last_name",
          sTitle: "Last Name",
          sDefaultContent: "-",
        },
        {
          mData: "created_at",
          sType: "date",
          sTitle: "Signed Up",
          sDefaultContent: "-",
          mRender: function(time, type) {
            if(type === 'display' && time && time !== '-') {
              return moment(time).format('YYYY-MM-DD HH:mm:ss');
            }
          },
        },
        {
          mData: "hits",
          sTitle: "Hits",
          sDefaultContent: "-",
          mRender: function(number, type) {
            if(type === 'display' && number && number !== '-') {
              return numeral(number).format('0,0')
            }

            return number;
          },
        },
        {
          mData: "last_request_at",
          sType: "date",
          sTitle: "Last Request",
          sDefaultContent: "-",
          mRender: function(time, type) {
            if(type === 'display' && time && time !== '-') {
              return moment(time).format('YYYY-MM-DD HH:mm:ss');
            }

            return time;
          },
        },
        {
          mData: "use_description",
          sTitle: "Use Description",
          sDefaultContent: "-",
        },
      ]
    });
  },

  refreshData: function() {
    this.$().dataTable().fnDraw();
  }.observes('controller.query.params.search', 'controller.query.params.start', 'controller.query.params.end'),
});
