// eslint-disable-next-line import/no-unresolved
import * as params from "@params";
import A11yDialog from "a11y-dialog";
import escapeHtml from "escape-html";
import serialize from "form-serialize";

const styleEl = document.createElement("link");
styleEl.rel = "stylesheet";
styleEl.type = "text/css";
styleEl.href = params.stylesheetPath;

function insertLink(root, options) {
  const link = document.createElement("link");
  link.rel = options.rel;
  link.href = options.href;
  if (options.as) {
    link.as = options.as;
  }
  root.appendChild(link);
}

const webSiteRoot = params.webSiteRoot.replace(/\/$/, "");

const defaultOptions = {
  containerSelector: "#api_umbrella_signup",
  apiUrlRoot: `${webSiteRoot}/api-umbrella`,
  contactUrl: `${webSiteRoot}/contact/`,
  exampleApiUrl: `${webSiteRoot}/example.json?api_key={{api_key}}`,
  signupConfirmationMessage: "",
  sendWelcomeEmail: true,
  showIntroText: false,
  showRequiredAsteriskExplainText: true,
  showFirstNameInput: true,
  showLastNameInput: true,
  showUseDescriptionInput: true,
  showWebsiteInput: false,
  showTermsInput: true,
  termsUrl: `${webSiteRoot}/terms/`,
  verifyEmail: false,
};

const embedOptions = window.apiUmbrellaSignupOptions || {};

// Handle legacy option names.
if (
  embedOptions.showWebsiteInput === undefined &&
  embedOptions.websiteInput !== undefined
) {
  embedOptions.showWebsiteInput = embedOptions.websiteInput;
}
if (
  embedOptions.showTermsInput === undefined &&
  embedOptions.termsCheckbox !== undefined
) {
  embedOptions.showTermsInput = embedOptions.termsCheckbox;
}

const options = {
  ...defaultOptions,
  ...embedOptions,
};

if (!options.apiKey) {
  // eslint-disable-next-line no-alert
  alert("apiUmbrellaSignupOptions.apiKey must be set");
}

if (!options.registrationSource) {
  // eslint-disable-next-line no-alert
  alert("apiUmbrellaSignupOptions.registrationSource must be set");
}

let signupFormTemplate = "";

if (options.showIntroText) {
  signupFormTemplate += `
    <p>Sign up for an application programming interface (API) key to access and use web services.</p>
  `;
}

if (options.showRequiredAsteriskExplainText) {
  signupFormTemplate += `
    <p class="required-fields">Required fields are marked with an asterisk (<abbr title="required" class="required">*</abbr>).</p>
  `;
}

signupFormTemplate += `
  <form id="api_umbrella_signup_form" novalidate>
`;

if (options.showFirstNameInput) {
  signupFormTemplate += `
    <div class="form-group first-name-form-group">
      <label class="form-label" for="user_first_name">First Name <abbr title="required" class="required">*</abbr></label>
      <input class="form-control" id="user_first_name" aria-describedby="user_first_name_feedback" name="user[first_name]" size="50" type="text" required />
      <div id="user_first_name_feedback" class="invalid-feedback">Fill out this field.</div>
    </div>
  `;
} else {
  signupFormTemplate += `<input type="hidden" name="user[first_name]" value="${escapeHtml(
    options.registrationSource
  )} User" />`;
}

if (options.showLastNameInput) {
  signupFormTemplate += `
    <div class="form-group last-name-form-group">
      <label class="form-label" for="user_last_name">Last Name <abbr title="required" class="required">*</abbr></label>
      <input class="form-control" id="user_last_name" aria-describedby="user_last_name_feedback"  name="user[last_name]" size="50" type="text" required />
      <div id="user_last_name_feedback" class="invalid-feedback">Fill out this field.</div>
    </div>
  `;
} else {
  signupFormTemplate += `<input type="hidden" name="user[last_name]" value="${escapeHtml(
    options.registrationSource
  )} User" />`;
}

signupFormTemplate += `
  <div class="form-group email-form-group">
    <label class="form-label" for="user_email">Email <abbr title="required" class="required">*</abbr></label>
    <input class="form-control" id="user_email" aria-describedby="user_email_feedback" name="user[email]" size="50" type="email" required />
    <div id="user_email_feedback" class="invalid-feedback">Enter an email address.</div>
  </div>
`;

if (options.showWebsiteInput) {
  signupFormTemplate += `
    <div class="form-group website-form-group">
      <label class="form-label" for="user_website">Website (optional)</label>
      <input class="form-control" id="user_website" aria-describedby="user_website_feedback" name="user[website]" size="50" type="url" placeholder="https://" />
      <div id="user_website_feedback" class="invalid-feedback">Enter a URL.</div>
    </div>
  `;
}

if (options.showUseDescriptionInput) {
  signupFormTemplate += `
    <div class="form-group use-description-form-group">
      <label class="form-label" for="user_use_description">How will you use the APIs? (optional)</label>
      <textarea class="form-control" cols="40" id="user_use_description" name="user[use_description]" rows="2"></textarea>
    </div>
  `;
}

if (options.showTermsInput) {
  signupFormTemplate += `
    <div class="form-group terms-form-group">
      <div class="form-check">
        <input id="user_terms_and_conditions" aria-describedby="user_terms_and_conditions_feedback" name="user[terms_and_conditions]" type="checkbox" class="form-check-input" value="true" required />
        <label class="form-check-label" for="user_terms_and_conditions">I have read and agree to the <a href="${escapeHtml(
          options.termsUrl
        )}" onclick="window.open(this.href, &#x27;api_umbrella_terms&#x27;, &#x27;height=500,width=790,menubar=no,toolbar=no,location=no,personalbar=no,status=no,resizable=yes,scrollbars=yes&#x27;); return false;" title="Opens new window to terms and conditions">terms and conditions</a>.</label>
        <div id="user_terms_and_conditions_feedback" class="invalid-feedback">You must agree to the terms and conditions to signup.</div>
      </div>
    </div>
  `;
} else {
  signupFormTemplate += `<input type="hidden" name="user[terms_and_conditions]" value="true" />`;
}

signupFormTemplate += `
    <div class="submit">
      <input type="hidden" name="user[registration_source]" value="${escapeHtml(
        options.registrationSource
      )}" />
      <button type="submit" class="btn btn-lg btn-primary" data-loading-text="Loading...">Signup</button>
    </div>
  </form>
`;

const modalTemplate = `
  <div id="alert_modal" class="dialog-container" aria-describedby="alert_modal_message" aria-hidden="true">
    <div class="modal-backdrop show" data-a11y-dialog-hide></div>
    <div role="document" class="modal show d-block">
      <div class="modal-dialog">
        <div class="modal-content" autofocus>
          <div class="modal-body">
            <button type="button" class="btn-close float-end" aria-label="Close" data-a11y-dialog-hide></button>
            <div id="alert_modal_message"></div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-primary" data-a11y-dialog-hide>OK</button>
          </div>
        </div>
      </div>
    </div>
  </div>
`;

const containerEl = document.querySelector(options.containerSelector);
const containerShadowRootEl = containerEl.attachShadow({ mode: "open" });

// Compute how big the font size is wherever the container is being injected
// and then compare that to the root font size, so we can fix `rem` units with
// the help of https://github.com/GUI/postcss-relative-rem
const rootFontSize = parseFloat(
  window
    .getComputedStyle(document.documentElement)
    .getPropertyValue("font-size")
);
const containerFontSize = parseFloat(
  window.getComputedStyle(containerEl).getPropertyValue("font-size")
);
const remRelativeBaseSize = `${containerFontSize / rootFontSize}rem`;

const containerStyleRootEl = document.createElement("div");
containerStyleRootEl.className = "app-style-root";
containerStyleRootEl.innerHTML = signupFormTemplate;
containerStyleRootEl.style.setProperty(
  "--api-umbrella-rem-relative-base",
  remRelativeBaseSize
);
containerShadowRootEl.appendChild(containerStyleRootEl);

const bodyContainerEl = document.createElement("div");
bodyContainerEl.id = "api-umbrella-signup-embed-body-container";
const bodyContainerShadowRootEl = bodyContainerEl.attachShadow({
  mode: "open",
});
const bodyContainerStyleRootEl = document.createElement("div");
bodyContainerStyleRootEl.className = "app-style-root";
bodyContainerStyleRootEl.innerHTML = modalTemplate;
bodyContainerStyleRootEl.style.setProperty(
  "--api-umbrella-rem-relative-base",
  remRelativeBaseSize
);
bodyContainerShadowRootEl.appendChild(bodyContainerStyleRootEl);
document.body.appendChild(bodyContainerEl);

insertLink(containerShadowRootEl, {
  rel: "stylesheet",
  href: params.stylesheetPath,
});

insertLink(bodyContainerShadowRootEl, {
  rel: "stylesheet",
  href: params.stylesheetPath,
});

const modalEl = bodyContainerShadowRootEl.getElementById("alert_modal");
const modalMessageEl = modalEl.querySelector("#alert_modal_message");
const modal = new A11yDialog(modalEl);

const formEl = containerShadowRootEl.querySelector("form");
formEl.addEventListener("submit", (event) => {
  event.preventDefault();

  if (!formEl.checkValidity()) {
    formEl.classList.add("was-validated");
    return false;
  }

  const submitButtonEl = formEl.querySelector("button[type=submit]");
  const submitButtonOrig = submitButtonEl.innerHTML;
  setTimeout(() => {
    submitButtonEl.disabled = true;
    submitButtonEl.innerText = "Loading...";
  }, 0);

  const formData = {
    ...serialize(formEl, { hash: true }),
    options: {
      example_api_url: options.exampleApiUrl,
      contact_url: options.contactUrl,
      site_name: options.siteName,
      send_welcome_email: options.sendWelcomeEmail,
      email_from_name: options.emailFromName,
      email_from_address: options.emailFromAddress,
      verify_email: options.verifyEmail,
    },
  };

  if (formData?.user?.terms_and_conditions === "true") {
    formData.user.terms_and_conditions = true;
  }

  return fetch(`${options.apiUrlRoot}/v1/users.json`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Api-Key": options.apiKey,
    },
    body: JSON.stringify(formData),
  })
    .then((response) => {
      const contentType = response.headers.get("Content-Type");
      if (!contentType || !contentType.includes("application/json")) {
        throw new Error("Response is not JSON");
      }

      return response.json().then((data) => ({
        response,
        data,
      }));
    })
    .then(({ response, data }) => {
      if (!response.ok) {
        // eslint-disable-next-line no-throw-literal
        throw { responseData: data };
      }

      const { user } = data;

      let confirmationTemplate = "";
      if (data.options.verify_email) {
        confirmationTemplate += `
          <p>Your API key for <strong>${escapeHtml(
            user.email
          )}</strong> has been e-mailed to you. You can use your API key to begin making web service requests immediately.</p>
          <p>If you don't receive your API Key via e-mail within a few minutes, please <a href="${escapeHtml(
            data.options.contact_url
          )}">contact us</a>.</p>
        `;
      } else {
        confirmationTemplate += `
          <p>Your API key for <strong>${escapeHtml(user.email)}</strong> is:</p>
          <pre class="signup-key"><code>${escapeHtml(user.api_key)}</code></pre>
          <p>You can start using this key to make web service requests. Simply pass your key in the URL when making a web request. Here's an example:</p>
          <pre class="signup-example"><a href="${escapeHtml(
            data.options.example_api_url
          )}">${data.options.example_api_url_formatted_html}</a></pre>
        `;
      }

      confirmationTemplate += `
        ${options.signupConfirmationMessage}
        <div class="signup-footer">
          <p>For additional support, please <a href="${escapeHtml(
            data.options.contact_url
          )}">contact us</a>. When contacting us, please tell us what API you're accessing and provide the following account details so we can quickly find you:</p>
          Account Email: ${escapeHtml(user.email)}<br>
          Account ID: ${escapeHtml(user.id)}
        </div>
      `;

      containerStyleRootEl.innerHTML = confirmationTemplate;
      containerStyleRootEl.scrollIntoView();
    })
    .catch((error) => {
      const messages = [];
      let messageStr = "";
      try {
        if (error?.responseData?.errors) {
          for (let i = 0; i < error.responseData.errors.length; i += 1) {
            const err = error.responseData.errors[i];
            if (err.full_message || err.message) {
              messages.push(escapeHtml(err.full_message || err.message));
            }
          }
        }

        if (error?.responseData?.error?.message) {
          messages.push(escapeHtml(error.responseData.error.message));
        }

        if (messages.length > 0) {
          messageStr = `<br><ul><li>${messages.join("</li><li>")}</li></ul>`;
        } else {
          // eslint-disable-next-line no-console
          console.error(error);
        }
      } catch (e) {
        // eslint-disable-next-line no-console
        console.error(e);
      }

      modalMessageEl.innerHTML = `API key signup unexpectedly failed.${messageStr}<br>Please try again or <a href="${escapeHtml(
        options.issuesUrl
      )}">file an issue</a> for assistance.`;
      modal.show();
    })
    .finally(() => {
      submitButtonEl.disabled = false;
      submitButtonEl.innerHTML = submitButtonOrig;
    });
});
