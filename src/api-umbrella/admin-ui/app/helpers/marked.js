import { helper } from '@ember/component/helper';
import { marked } from 'marked';

marked.use({
  mangle: false,
  headerIds: false,
});

export function markedHelper(params) {
  return marked(params[0]);
}

export default helper(markedHelper);
