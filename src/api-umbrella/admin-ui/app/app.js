import Application from '@ember/application';
import Resolver from './resolver';
import config from './config/environment';
import loadInitializers from 'ember-load-initializers';

const App = Application.extend({
  modulePrefix: config.modulePrefix,
  podModulePrefix: config.podModulePrefix,
  Resolver,
});

loadInitializers(App, config.modulePrefix);

export default App;
