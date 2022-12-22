import { action } from '@ember/object';
import Component from '@glimmer/component';

export default class RemoveInitialLoadIndicator extends Component {
  @action
  removeLoader() {
    document.getElementById('ember_load_indicator').style.display = 'none';
  }
}
