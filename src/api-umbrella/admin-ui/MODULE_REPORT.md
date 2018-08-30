## Module Report
### Unknown Global

**Global**: `Ember.mixin`

**Location**: `app/components/form-fields/field-wrapper.js` at line 18

```js
    let fieldName = this.get('fieldName');
    let fieldValidations = 'model.validations.attrs.' + fieldName;
    Ember.mixin(this, {
      fieldErrorMessages: computed(fieldValidations + '.messages', 'canShowErrors', function() {
        if(this.get('canShowErrors')) {
```
