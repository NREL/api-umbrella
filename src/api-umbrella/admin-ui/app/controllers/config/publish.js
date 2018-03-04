import Controller from '@ember/controller';

export default Controller.extend({
  actions: {
    refreshCurrentRouteController(){
      this.send('refreshCurrentRoute');
    },
  },
});
