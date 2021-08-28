import { classNames } from '@ember-decorators/component';
import classic from 'ember-classic-decorator';

import BaseField from './base-field';

@classic
@classNames('form-fields-checkboxes-field')
export default class CheckboxesField extends BaseField {}
