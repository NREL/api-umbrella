import { LineChart, MapChart, ScatterChart } from 'echarts/charts';
import { GeoComponent, GridComponent, TooltipComponent, VisualMapComponent } from 'echarts/components';
import * as echarts from 'echarts/core';
import { CanvasRenderer } from 'echarts/renderers';

echarts.use([
  CanvasRenderer,
  GeoComponent,
  GridComponent,
  LineChart,
  MapChart,
  ScatterChart,
  TooltipComponent,
  VisualMapComponent,
]);

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
        color: 'transparent',
        areaColor: '#f5f5f5',
        borderColor: '#bbb',
      },
      label: {
        show: false,
      },
      emphasis: {
        itemStyle: {
          borderColor: '#999',
          borderWidth: 1,
        },
        label: {
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
      opacity: 0.2,
    },
    timeAxis: axisCommon(),
    logAxis: axisCommon(),
    valueAxis: axisCommon(),
    categoryAxis: axisCommon(),
    geo: mapCommon(),
    map: mapCommon(),
    scatter: {
      itemStyle: {
        borderColor: '#bbb',
        borderWidth: 1,
      },
      emphasis: {
        itemStyle: {
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
