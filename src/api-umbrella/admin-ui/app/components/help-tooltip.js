// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { computed } from '@ember/object';
import { tagName } from '@ember-decorators/component';
import classic from 'ember-classic-decorator';
import { marked } from 'marked';

marked.use({
  gfm: true,
  breaks: true,
});

@classic
@tagName("")
export default class HelpTooltip extends Component {
  @computed('tooltip')
  get tooltipHtml() {
    return marked(this.tooltip);
  }
}
