Admin.LogsTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().dataTable({
      "bProcessing": true,
      "bServerSide": true,
      "bFilter": false,
      "bSearchable": false,
      "sAjaxSource": "/admin/stats/logs.json",
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
      "aaSorting": [[0, "desc"]],
      "aoColumns": [
        {
          mData: "request_at",
          sType: "date",
          sTitle: "Time",
          sDefaultContent: "-",
          mRender: function(time, type) {
            if(type === 'display' && time && time !== '-') {
              return moment(time).format('YYYY-MM-DD HH:mm:ss');
            }

            return time;
          },
        },
        {
          mData: "request_method",
          sTitle: "Method",
          sDefaultContent: "-",
        },
        {
          mData: "request_url",
          sTitle: "URL",
          sDefaultContent: "-",
        },
        {
          mData: "user_email",
          sTitle: "User",
          sDefaultContent: "-",
          mRender: _.bind(function(email, type, data) {
            if(type === 'display' && email && email !== '-') {
              var params = _.clone(this.get('controller.query.params'));
              params.search = _.compact([params.search, 'user_id:"' + data.user_id + '"']).join(' AND ');
              var link = '#/stats/logs/' + $.param(params);

              return '<a href="' + link + '">' + email + '</a>';
            }

            return email;
          }, this),
        },
        {
          mData: "request_ip",
          sTitle: "IP Address",
          sDefaultContent: "-",
        },
        {
          mData: "request_ip_country",
          sTitle: "Country",
          sDefaultContent: "-",
        },
        {
          mData: "request_ip_region",
          sTitle: "State",
          sDefaultContent: "-",
        },
        {
          mData: "request_ip_city",
          sTitle: "City",
          sDefaultContent: "-",
        },
        {
          mData: "response_status",
          sTitle: "Status",
          sDefaultContent: "-",
        },
        {
          mData: "response_content_type",
          sTitle: "Content Type",
          sDefaultContent: "-",
        },
        {
          mData: "request_accept_encoding",
          sTitle: "Accept Encoding",
          sDefaultContent: "-",
        },
        {
          mData: "request_user_agent",
          sTitle: "User Agent",
          sDefaultContent: "-",
        },
      ]
    });
  },

  refreshData: function() {
    this.$().dataTable().fnDraw();
  }.observes('controller.query.params.search', 'controller.query.params.start', 'controller.query.params.end'),
});
