import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';

moduleForComponent('apis/url-match-table', 'Integration | Component | apis/url match table', {
  integration: true
});

test('it renders', function(assert) {
  // Set any properties with this.set('myProperty', 'value');
  // Handle any actions with this.on('myAction', function(val) { ... });

  this.render(hbs`{{apis/url-match-table}}`);

  assert.equal(this.$().text().trim(), '');

  // Template block usage:
  this.render(hbs`
    {{#apis/url-match-table}}
      template block text
    {{/apis/url-match-table}}
  `);

  assert.equal(this.$().text().trim(), 'template block text');
});
