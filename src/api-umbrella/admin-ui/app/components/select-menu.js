import { action } from '@ember/object';
import { next } from '@ember/runloop';
import Component from '@glimmer/component';

export default class SelectMenu extends Component {
  constructor(owner, args) {
    super(owner, args);

    // If a select menu doesn't have a value set on the model, set it to the
    // value of the first option. This better aligns with the default behavior of
    // select menus (so even if the user doesn't interact with the menu, the
    // model still gets set with the first value that will always be selected).
    if(this.args.value === undefined) {
      const options = this.args.options;
      if(options) {
        const firstOption = options[0];
        if(firstOption && firstOption.id !== undefined) {
          next(() => {
            this.args.action(firstOption.id);
          });
        }
      }
    }
  }

  @action
  handleSelect(value) {
    this.args.action(value);
  }
}
