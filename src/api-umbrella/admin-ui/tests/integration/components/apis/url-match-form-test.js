import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('apis/url-match-form', 'Integration | Component | apis/url match form', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{apis/url-match-form}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#apis/url-match-form}}
      template block text
    {{/apis/url-match-form}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
