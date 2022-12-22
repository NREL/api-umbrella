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
    for(let i = 0; i < hits.length; i++) {
      data.push(hits[i].c[1].v);
      labels.push(hits[i].c[0].f);
    }

    this.chartData = data;
    this.chartLabels = labels;

    this.draw();
  }

  draw() {
    if(!this.chart || !this.chartData) {
      return;
    }

    let showAllSymbol = false;
    let lineWidth = 2;
    if(this.chartData.length < 100) {
      showAllSymbol = true;
      lineWidth = 4;
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
      series: [
        {
          name: 'Hits',
          type: 'line',
          sampling: 'average',
          showAllSymbol: showAllSymbol,
          symbolSize: lineWidth + 4,
          areaStyle: {
          },
          lineStyle: {
            width: lineWidth,
          },
          data: this.chartData,
        },
      ],
      grid: {
        show: false,
        left: 90,
        top: 10,
        right: 30,
      },
    }, true);
  }
}
