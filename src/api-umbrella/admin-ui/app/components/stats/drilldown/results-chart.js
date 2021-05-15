// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
// eslint-disable-next-line ember/no-observers
import { observer } from '@ember/object';
import { on } from '@ember/object/evented';
import echarts from 'echarts/lib/echarts';
import $ from 'jquery';
import debounce from 'lodash-es/debounce';

// eslint-disable-next-line ember/no-classic-classes
export default Component.extend({
  // eslint-disable-next-line ember/no-component-lifecycle-hooks
  didInsertElement() {
    this._super(...arguments);
    this.renderChart();
  },

  renderChart() {
    this.chart = echarts.init(this.$()[0], 'api-umbrella-theme');
    this.draw();

    $(window).on('resize', debounce(this.chart.resize, 100));
  },

  // eslint-disable-next-line ember/no-on-calls-in-components, ember/no-observers
  refreshData: on('init', observer('hitsOverTime', function() {
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
          normal: {},
        },
        lineStyle: {
          normal: {
            width: 1,
          },
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

    this.setProperties({
      chartData: data,
      chartLabels: labels,
    });

    this.draw();
  })),

  draw() {
    if(!this.chart || !this.chartData) {
      return;
    }

    this.chart.setOption({
      animation: false,
      tooltip: {
        trigger: 'axis',
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
          dataZoom: {
            yAxisIndex: 'none',
            title: {
              zoom: 'zoom',
              back: 'restore zoom',
            },
          },
        },
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
      dataZoom: [
        {
          type: 'slider',
          start: 0,
          end: 100,
        },
      ],
    }, true);
  },
});
