import echarts from 'npm:echarts';

export function initialize() {
  let colorPalette = [
    '#3366CC',
    '#DC3912',
    '#FF9900',
    '#109618',
    '#990099',
    '#3B3EAC',
    '#0099C6',
    '#DD4477',
    '#66AA00',
    '#B82E2E',
    '#316395',
    '#994499',
    '#22AA99',
    '#AAAA11',
    '#6633CC',
    '#E67300',
    '#8B0707',
    '#329262',
    '#5574A6',
    '#3B3EAC',
  ];

  function axisCommon() {
    return {
      splitLine: {
        lineStyle: {
          color: '#ddd',
        },
      },
    };
  }

  function mapCommon() {
    return {
      itemStyle: {
        normal: {
          color: 'transparent',
          areaColor: '#f5f5f5',
          borderColor: '#bbb',
        },
        emphasis: {
          borderColor: '#999',
          borderWidth: 1,
        },
      },
      label: {
        normal: {
          show: false,
        },
        emphasis: {
          show: false,
        },
      },
    };
  }

  echarts.registerTheme('api-umbrella-theme', {
    color: colorPalette,
    graph: {
      color: colorPalette,
    },
    areaStyle: {
      normal: {
        opacity: 0.2,
      },
    },
    timeAxis: axisCommon(),
    logAxis: axisCommon(),
    valueAxis: axisCommon(),
    categoryAxis: axisCommon(),
    geo: mapCommon(),
    map: mapCommon(),
    scatter: {
      itemStyle: {
        normal: {
          borderColor: '#bbb',
          borderWidth: 1,
        },
        emphasis: {
          borderColor: '#666',
          borderWidth: 1,
        },
      },
    },
    visualMap: {
      inRange: {
        color: ['#add9ff', '#4481b6'],
      },
    },
  });
}

export default {
  name: 'echarts',
  initialize,
};
