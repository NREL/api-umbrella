import * as PNotifyBootstrap4 from '@pnotify/bootstrap4';
import { defaultModules, defaults } from '@pnotify/core';
import * as PNotifyFontAwesome5 from '@pnotify/font-awesome5';
import * as PNotifyFontAwesome5Fix from '@pnotify/font-awesome5-fix';
import * as PNotifyMobile from '@pnotify/mobile';

export function initialize() {
  defaults.width = '400px';
  defaults.icon = false;
  defaults.animation = 'none';
  defaults.sticker = false;
  defaultModules.set(PNotifyMobile, {});
  defaultModules.set(PNotifyBootstrap4, {});
  defaultModules.set(PNotifyFontAwesome5Fix, {});
  defaultModules.set(PNotifyFontAwesome5, {});
}

export default {
  name: 'pnotify',
  initialize,
};
