import $ from 'jquery';
import Modal from 'bootstrap/js/src/modal';
import escapeHtml from 'escape-html';
import 'parsleyjs';

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

const form = $("#api_umbrella_contact_form");
form.parsley();
form.submit(function(event) {
  event.preventDefault();

  const submitButton = document.querySelector('#api_umbrella_contact_form button[type=submit]');
  const submitButtonOrig = submitButton.innerHTML;
  setTimeout(function() {
    submitButton.disabled = true;
    submitButton.innerText = 'Sending...';
  }, 0);

  $.ajax({
    url: '/api-umbrella/v1/contact.json?api_key=' + options.apiKey,
    type: 'POST',
    data: $(this).serialize(),
    dataType: 'json',
  }).done(function(response) {
    form.trigger('reset');

    modalMessageEl.innerText = 'Thanks for sending your message. We\'ll be in touch.';
    modal.show();
  }).fail(function(xhr, message, error) {
    const messages = [];
    let messageStr = '';
    if (xhr.responseJSON && xhr.responseJSON.errors) {
      $.each(xhr.responseJSON.errors, function(idx, error) {
        if (error.full_message || error.message) {
          messages.push(escapeHtml(error.full_message || error.message));
        }
      });
    }
    if (xhr.responseJSON && xhr.responseJSON.error && xhr.responseJSON.error.message) {
      messages.push(escapeHtml(xhr.responseJSON.error.message));
    }
    if (messages && messages.length > 0) {
      messageStr = '<br><ul><li>' + messages.join('</li><li>') + '</li></ul>';
    }

    modalMessageEl.innerHTML = 'Sending your message unexpectedly failed.' + messageStr + '<br>Please try again or <a href="' + escapeHtml(options.issuesUrl) + '">file an issue</a> for assistance.';
    modal.show();
  }).always(function() {
    submitButton.disabled = false;
    submitButton.innerHTML = submitButtonOrig;
  });
});
