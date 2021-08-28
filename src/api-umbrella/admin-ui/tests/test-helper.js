import { setApplication } from '@ember/test-helpers';
import Application from 'api-umbrella-admin-ui/app';
import config from 'api-umbrella-admin-ui/config/environment';
import { start } from 'ember-qunit';

setApplication(Application.create(config.APP));

start();
