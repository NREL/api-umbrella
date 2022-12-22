// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import { observes, on } from '@ember-decorators/object';
import * as echarts from 'echarts/core';
import classic from 'ember-classic-decorator';
import $ from 'jquery';
import debounce from 'lodash-es/debounce';

@classic
export default class ResultsChart extends Component {
  tagName = '';

  @action
  didInsert(element) {
    this.chart = echarts.init(element, 'api-umbrella-theme');
    this.draw();

    $(window).on('resize', debounce(this.chart.resize, 100));
  }

  @on('init')
  // eslint-disable-next-line ember/no-observers
  @observes('hitsOverTime')
  refreshData() {
    let data = []
    let labels = [];

    let hits = this.hitsOverTime;
    for(let i = 1; i < hits.cols.length; i++) {
      data.push({
        name: hits.cols[i].label,
        type: 'line',
        sampling: 'average',
        stack: 'hits',
        areaStyle: {
        },
        lineStyle: {
          width: 1,
        },
        data: [],
      });
    }

    for(let i = 0; i < hits.rows.length; i++) {
      labels.push(hits.rows[i].c[0].f);

      for(let j = 1; j < hits.rows[i].c.length; j++) {
        data[j - 1].data.push(hits.rows[i].c[j].v);
      }
    }

    this.chartData = data;
    this.chartLabels = labels;

    this.draw();
  }

  draw() {
    if(!this.chart || !this.chartData) {
      return;
    }

    this.chart.setOption({
      animation: false,
      tooltip: {
        trigger: 'axis',
      },
      yAxis: {
        type: 'value',
        min: 0,
        minInterval: 1,
        splitNumber: 3,
      },
      xAxis: {
        type: 'category',
        boundaryGap: false,
        data: this.chartLabels,
      },
      series: this.chartData,
      grid: {
        show: false,
        left: 90,
        top: 10,
        right: 30,
      },
    }, true);
  }
}
