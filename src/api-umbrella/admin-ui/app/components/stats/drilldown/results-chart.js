import Ember from 'ember';
import echarts from 'npm:echarts';

export default Ember.Component.extend({
  classNames: ['stats-drilldown-results-chart'],

  didInsertElement() {
    this.renderChart();
  },

  renderChart() {
    this.chart = echarts.init(this.$()[0], 'api-umbrella-theme');
    this.draw();

    $(window).on('resize', _.debounce(this.chart.resize, 100));
  },

  refreshData: Ember.on('init', Ember.observer('hitsOverTime', function() {
    let data = []
    let labels = [];

    let hits = this.get('hitsOverTime');
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
    if(!this.chart || !this.get('chartData')) {
      return;
    }

    this.chart.setOption({
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
        data: this.get('chartLabels'),
      },
      series: this.get('chartData'),
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
    });
  },
});
