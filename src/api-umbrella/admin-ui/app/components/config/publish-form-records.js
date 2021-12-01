// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import { tagName } from "@ember-decorators/component";
import classic from 'ember-classic-decorator';
import $ from 'jquery';

@tagName("")
@classic
export default class PublishFormRecords extends Component {
  @action
  toggleConfigDiff(id) {
    $('[data-diff-id=' + id + ']').toggle();
  }
}
