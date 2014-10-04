'use strict';

var _ = require('lodash'),
    async = require('async'),
    config = require('api-umbrella-config').global(),
    elasticSearchConnect = require('../lib/elasticsearch_connect');

exports.migrate = function(client, done) {
  elasticSearchConnect(function(error, elasticSearch, elasticSearchConnection) {
    elasticSearch.indices.getAliases({}, function(error, aliasResponse) {
      elasticSearch.indices.status({}, function(error, statusResponse) {
        var indexNames = _.keys(aliasResponse);
        var aliasNames = _.flatten(_.map(aliasResponse, function(index) { return _.keys(index.aliases) }));
        console.info(indexNames);
        console.info(aliasNames);

        async.eachSeries(indexNames, function(indexName, indexCallback) {
          var regex = new RegExp('^api-umbrella-logs-v(\\d+)-' + config.get('app_env'));
          if(indexName.match(regex)) {
            var indexAliases = [
              indexName.replace(regex, 'api-umbrella-logs-v$1'),
              indexName.replace(regex, 'api-umbrella-logs'),
              indexName.replace(regex, 'api-umbrella-logs-write'),
            ]; 

            async.eachSeries(indexAliases, function(indexAlias, aliasCallback) {
              if(_.contains(indexNames, indexAlias)) {
                if(statusResponse.indices[indexAlias].docs.num_docs > 0) {
                  console.info('Index with alias name already exists with data - skipping: ' + indexAlias);
                  aliasCallback();
                } else {
                  console.info('Index with alias name already exists with no data - deleting: ' + indexAlias);
                  elasticSearch.indices.delete({ index: indexAlias }, function() {
                    indexNames = _.without(indexNames, indexAlias);
                    aliasNames = _.without(aliasNames, aliasResponse[indexAlias].aliases);

                    console.info('Creating new alias: ' + indexAlias + ' => ' + indexName);
                    elasticSearch.indices.putAlias({
                      index: indexName,
                      name: indexAlias,
                    }, aliasCallback);
                  });
                }
              } else if(_.contains(aliasNames, indexAlias)) {
                console.info('Alias already exists - skipping: ' + indexAlias);
                aliasCallback();
              } else {
                console.info('Creating new alias: ' + indexAlias + ' => ' + indexName);
                elasticSearch.indices.putAlias({
                  index: indexName,
                  name: indexAlias,
                }, aliasCallback);
              }
            }, indexCallback);
          } else {
            console.info('Skipping unrelated index: ' + indexName);
            indexCallback();
          }
        }, function() {
          elasticSearchConnection.close();
          done();
        });
      });
    });
  });
};

exports.rollback = function(client, done) {
	done();
};
