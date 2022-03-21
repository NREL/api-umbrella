import { helper } from '@ember/component/helper';
import { marked } from 'marked';

export function markedHelper(params) {
  return marked(params[0]);
}

export default helper(markedHelper);
