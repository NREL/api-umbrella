import Modal from 'bootstrap/js/src/modal';
import escapeHtml from 'escape-html';
import serialize from 'form-serialize';
import 'whatwg-fetch'
import 'promise-polyfill/src/polyfill';

const defaults = {};
const options = {
  ...defaults,
  ...(apiUmbrellaContactOptions || {}),
};

if(!options.apiKey) {
  alert('apiUmbrellaSignupOptions.apiKey must be set');
}

const modalEl = document.getElementById('alert_modal');
const modalMessageEl = document.getElementById('alert_modal_message');
const modal = new Modal(modalEl);

const formEl = document.getElementById('api_umbrella_contact_form');
formEl.addEventListener('submit', function(event) {
  event.preventDefault();

  if (!formEl.checkValidity()) {
    formEl.classList.add('was-validated')
    return false;
  }

  const submitButtonEl = formEl.querySelector('button[type=submit]');
  const submitButtonOrig = submitButtonEl.innerHTML;
  setTimeout(function() {
    submitButtonEl.disabled = true;
    submitButtonEl.innerText = 'Sending...';
  }, 0);

  fetch(`/api-umbrella/v1/contact.json?api_key=${options.apiKey}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(serialize(formEl, { hash: true })),
  }).then(function(response) {
    const contentType = error.response.headers.get('Content-Type');
    if (!contentType || !contentType.includes('application/json')) {
      throw new Error('Response is not JSON');
    }

    return response.json();
  }).then(function(data) {
    if (!response.ok) {
      throw { responseData: data };
    }

    formEl.reset();

    modalMessageEl.innerText = 'Thanks for sending your message. We\'ll be in touch.';
    modal.show();
  }).catch(function(error) {
    const messages = [];
    let messageStr = '';
    try {
      if(error?.responseData?.errors) {
        for (let i = 0; i < error.responseData.errors.length; i++) {
          const err = error.responseData.errors[i];
          if (err.full_message || err.message) {
            messages.push(escapeHtml(err.full_message || err.message));
          }
        }
      }

      if (error?.responseData?.error?.message) {
        messages.push(escapeHtml(error.responseData.error.message));
      }

      if (messages && messages.length > 0) {
        messageStr = `<br><ul><li>${messages.join('</li><li>')}</li></ul>`;
      }
    } catch(e) {
      console.error(e);
    }

    modalMessageEl.innerHTML = `Sending your message unexpectedly failed.${messageStr}<br>Please try again or <a href="${escapeHtml(options.issuesUrl)}">file an issue</a> for assistance.`;
    modal.show();
  }).finally(function() {
    submitButtonEl.disabled = false;
    submitButtonEl.innerHTML = submitButtonOrig;
  });
});
