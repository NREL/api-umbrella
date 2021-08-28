// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import { inject } from '@ember/service';
import { observes, on } from '@ember-decorators/object';
import * as echarts from 'echarts/core';
import classic from 'ember-classic-decorator';
import $ from 'jquery';
import clone from 'lodash-es/clone';
import debounce from 'lodash-es/debounce';

@classic
export default class ResultsMap extends Component {
  tagName = '';

  @inject()
  router;

  @action
  didInsert(element) {
    this.chart = echarts.init(element, 'api-umbrella-theme');
    this.chart.showLoading();
    this.chart.on('click', this.handleMapClick.bind(this));
    this.draw();

    $(window).on('resize', debounce(this.chart.resize, 100));
  }

  handleMapClick(event) {
    if(event.seriesType === 'map') {
      let queryParams = clone(this.presentQueryParamValues);
      queryParams.region = event.name;
      this.router.transitionTo('stats.map', { queryParams });
    } else if(event.seriesType === 'scatter') {
      let currentRegion = this.allQueryParamValues.region.split('-');
      let currentCountry = currentRegion[0];
      currentRegion = currentRegion[1];
      let queryParams = clone(this.presentQueryParamValues);
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

      this.router.transitionTo('stats.logs', { queryParams });
    }
  }

  @on('init')
  // eslint-disable-next-line ember/no-observers
  @observes('allQueryParamValues.region')
  refreshMap() {
    let currentRegion = this.allQueryParamValues.region;
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

      this.set('loadedMapRegion', this.allQueryParamValues.region);

      this.fillInChartDataMissingRegions();
      this.draw();
    });
  }

  @on('init')
  // eslint-disable-next-line ember/no-observers
  @observes('regions')
  refreshData() {
    let currentRegion = this.allQueryParamValues.region;

    let data = {};
    let maxValue = 2;
    let maxValueDisplay = '2';
    let hits = this.regions;
    let regionField = this.regionField;
    for(let i = 0; i < hits.length; i++) {
      let value, valueDisplay;
      if(regionField === 'request_ip_city') {
        value = hits[i].c[3].v;
        valueDisplay = hits[i].c[3].f;
        let lat = hits[i].c[0].v;
        let lng = hits[i].c[1].v;
        data[i] = {
          name: hits[i].c[2].v,
          value: [lng, lat, value],
          valueDisplay: valueDisplay,
        };
      } else {
        value = hits[i].c[1].v;
        valueDisplay = hits[i].c[1].f;
        let code = hits[i].c[0].v;
        if(currentRegion === 'US') {
          code = 'US-' + code;
        }

        data[code] = {
          name: code,
          value: value,
          valueDisplay: valueDisplay,
        };
      }

      if(value > maxValue) {
        maxValue = value;
        maxValueDisplay = valueDisplay;
      }
    }

    this.set('chartData', data);
    this.set('chartDataMaxValue', maxValue);
    this.set('chartDataMaxValueDisplay', maxValueDisplay);
    this.set('loadedDataRegion', this.allQueryParamValues.region);

    this.fillInChartDataMissingRegions();
    this.draw();
  }

  // In order to generate tooltips with the region names, the region data must
  // contain a record for each region, even if no data is present (otherwise
  // the "params" passed to the tooltip's formatter function doesn't contain
  // the hovered region code as of ECharts 4). To fix this when no data is
  // present, ensure that anytime the chart data or labels are changed, this
  // function gets called to fill in any missing data.
  fillInChartDataMissingRegions() {
    if(this.chartData && this.labels && this.regionField !== 'request_ip_city') {
      let data = this.chartData
      const regionCodes = Object.keys(this.labels);
      for(let i = 0, len = regionCodes.length; i < len; i++) {
        const regionCode = regionCodes[i];
        if(!data[regionCode]) {
          data[regionCode] = {
            name: regionCode,
          };
        }
      }

      this.set('chartData', data);
    }
  }

  draw() {
    let currentRegion = this.allQueryParamValues.region;
    if(!this.chart || this.loadedDataRegion !== currentRegion || this.loadedMapRegion !== currentRegion) {
      return;
    }

    let geo;
    let series = {};
    const data = Object.values(this.chartData);
    if(this.regionField === 'request_ip_city') {
      geo = {
        map: 'region',
        silent: true,
      };

      let maxValue = this.chartDataMaxValue;
      series = [
        {
          name: 'Hits Scatter',
          type: 'scatter',
          coordinateSystem: 'geo',
          data,
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
          data,
          emphasis: {
            label: {
              show: false,
            },
          },
          select: {
            label: {
              show: false,
            },
          },
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
          let valueDisplay = (params.data && params.data.valueDisplay) ? params.data.valueDisplay : 0;
          return '<strong>' + label + '</strong><br>Hits: <strong>' + valueDisplay + '</strong>';
        }.bind(this),
      },
      visualMap: {
        type: 'continuous',
        min: 1,
        max: this.chartDataMaxValue,
        orient: 'horizontal',
        text: [
          this.chartDataMaxValueDisplay,
          '1',
        ],
      },
      geo: geo,
      series: series,
      grid: {
        show: false,
        left: 90,
        top: 10,
        right: 30,
      },
    }, true);
  }
}
