import { library, dom } from '@fortawesome/fontawesome-svg-core';
import { faFacebook } from '@fortawesome/free-brands-svg-icons/faFacebook';
import { faGithub } from '@fortawesome/free-brands-svg-icons/faGithub';
import { faGitlab } from '@fortawesome/free-brands-svg-icons/faGitlab';
import { faGoogle } from '@fortawesome/free-brands-svg-icons/faGoogle';
import './login.scss';

library.add(
  faFacebook,
  faGithub,
  faGitlab,
  faGoogle,
);

dom.watch();
