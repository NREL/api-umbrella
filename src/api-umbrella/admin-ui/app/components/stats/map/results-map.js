import $ from 'jquery';
import Component from '@ember/component';
import echarts from 'npm:echarts';
import { inject } from '@ember/service';
import { observer } from '@ember/object';
import { on } from '@ember/object/evented';

export default Component.extend({
  classNames: ['stats-map-results-map'],
  router: inject(),

  didInsertElement() {
    this.renderChart();
  },

  renderChart() {
    this.chart = echarts.init(this.$()[0], 'api-umbrella-theme');
    this.chart.showLoading();
    this.chart.on('mapselectchanged', this.handleRegionClick.bind(this));
    this.chart.on('click', this.handleCityClick.bind(this));
    this.draw();

    $(window).on('resize', _.debounce(this.chart.resize, 100));
  },

  handleRegionClick(event) {
    let queryParams = _.clone(this.get('presentQueryParamValues'));
    queryParams.region = event.batch[0].name;
    this.get('router').transitionTo('stats.map', { queryParams });
  },

  handleCityClick(event) {
    if(event.seriesType === 'scatter') {
      let currentRegion = this.get('allQueryParamValues.region').split('-');
      let currentCountry = currentRegion[0];
      currentRegion = currentRegion[1];
      let queryParams = _.clone(this.get('presentQueryParamValues'));
      queryParams.query = JSON.stringify({
        condition: 'AND',
        rules: [
          {
            field: 'gatekeeper_denied_code',
            id: 'gatekeeper_denied_code',
            input: 'select',
            operator: 'is_null',
            type: 'string',
            value: null,
          },
          {
            field: 'request_ip_country',
            id: 'request_ip_country',
            input: 'text',
            operator: 'equal',
            type: 'string',
            value: currentCountry,
          },
          {
            field: 'request_ip_region',
            id: 'request_ip_region',
            input: 'text',
            operator: 'equal',
            type: 'string',
            value: currentRegion,
          },
          {
            field: 'request_ip_city',
            id: 'request_ip_city',
            input: 'text',
            operator: 'equal',
            type: 'string',
            value: event.name,
          },
        ],
      });

      this.get('router').transitionTo('stats.logs', { queryParams });
    }
  },

  // eslint-disable-next-line ember/no-on-calls-in-components
  refreshMap: on('init', observer('allQueryParamValues.region', function() {
    let currentRegion = this.get('allQueryParamValues.region');
    $.get('/admin/maps/' + currentRegion + '.json', (geojson) => {
      this.labels = geojson._labels || {};

      let specialMapAreas = {};
      if(currentRegion === 'US') {
        specialMapAreas = {
          'US-AK': {
            left: -131,
            top: 25,
            width: 15,
          },
          'US-HI': {
            left: -112,
            top: 26,
            width: 5,
          },
        };
      }

      echarts.registerMap('region', geojson, specialMapAreas);

      this.set('loadedMapRegion', this.get('allQueryParamValues.region'));
      this.draw();
    });
  })),

  // eslint-disable-next-line ember/no-on-calls-in-components
  refreshData: on('init', observer('regions', function() {
    let currentRegion = this.get('allQueryParamValues.region');

    let data = [];
    let maxValue = 2;
    let maxValueDisplay = '2';
    let hits = this.get('regions');
    let regionField = this.get('regionField');
    for(let i = 0; i < hits.length; i++) {
      let value, valueDisplay;
      if(regionField === 'request_ip_city') {
        value = hits[i].c[3].v;
        valueDisplay = hits[i].c[3].f;
        let lat = hits[i].c[0].v;
        let lng = hits[i].c[1].v;
        data.push({
          name: hits[i].c[2].v,
          value: [lng, lat, value],
          valueDisplay: valueDisplay,
        });
      } else {
        value = hits[i].c[1].v;
        valueDisplay = hits[i].c[1].f;
        let code = hits[i].c[0].v;
        if(currentRegion === 'US') {
          code = 'US-' + code;
        }

        data.push({
          name: code,
          value: value,
          valueDisplay: valueDisplay,
        });
      }

      if(value > maxValue) {
        maxValue = value;
        maxValueDisplay = valueDisplay;
      }
    }

    this.set('chartData', data);
    this.set('chartDataMaxValue', maxValue);
    this.set('chartDataMaxValueDisplay', maxValueDisplay);
    this.set('loadedDataRegion', this.get('allQueryParamValues.region'));

    this.draw();
  })),

  draw() {
    let currentRegion = this.get('allQueryParamValues.region');
    if(!this.chart || this.get('loadedDataRegion') !== currentRegion || this.get('loadedMapRegion') !== currentRegion) {
      return;
    }

    let geo;
    let series = {};
    if(this.get('regionField') === 'request_ip_city') {
      geo = {
        map: 'region',
        silent: true,
      };

      let maxValue = this.get('chartDataMaxValue');
      series = [
        {
          name: 'Hits Scatter',
          type: 'scatter',
          coordinateSystem: 'geo',
          data: this.get('chartData'),
          symbolSize: (val) => {
            return Math.max(Math.round((val[2] / maxValue) * 30), 6);
          },
        },
      ];
    } else {
      series = [
        {
          name: 'Hits',
          type: 'map',
          map: 'region',
          selectedMode: 'single',
          data: this.get('chartData'),
        },
      ];
    }

    this.chart.hideLoading();
    this.chart.setOption({
      animation: false,
      tooltip: {
        trigger: 'item',
        formatter: function(params) {
          let label = this.labels[params.name] || params.name;
          let valueDisplay = params.data.valueDisplay || 0;
          return '<strong>' + label + '</strong><br>Hits: <strong>' + valueDisplay + '</strong>';
        }.bind(this),
      },
      toolbox: {
        orient: 'vertical',
        iconStyle: {
          emphasis: {
            textPosition: 'left',
            textAlign: 'right',
          },
        },
        feature: {
          saveAsImage: {
            title: 'save as image',
            name: 'api_umbrella_chart',
            excludeComponents: ['toolbox', 'dataZoom'],
            pixelRatio: 2,
          },
        },
      },
      visualMap: {
        type: 'continuous',
        min: 1,
        max: this.get('chartDataMaxValue'),
        orient: 'horizontal',
        text: [
          this.get('chartDataMaxValueDisplay'),
          '1',
        ],
      },
      geo: geo,
      series: series,
      title: {
        show: false,
      },
      legend: {
        show: false,
      },
      grid: {
        show: false,
        left: 90,
        top: 10,
        right: 30,
      },
    }, true);
  },
});
