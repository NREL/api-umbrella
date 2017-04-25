# Website Backends

By default, API Umbrella ships with a very basic public website. Any URL that does not match the routes defined by your API backends will get routed to your website backend. The default website provided by API Umbrella is intended to be customized or replaced. There are several different approaches to managing and hosting your website content:

- Using an [External Website Backend](#external-website-backends)
- Using the [Example Static Site](#example-static-site)

## External Website Backends

If you already have a website or content management system you'd like to use for managing your API website, you can point API Umbrella's website backend to wherever your website is hosted:

1. In the API Umbrella admin, under the "Configuration" menu pick "Website Backends" and then click "Add Website Backend"
2. Fill in the details for where your underlying website backend is hosted.
   - The "Frontend Host" field can be used if you'd like API Umbrella to handle multiple domain names and present different websites for each domain.
3. Save your website backend, and publish the changes under Configuration > Publish Changes.

## Example Static Site

If you don't already have a preferred way for managing your websites, API Umbrella ships with a basic, example website. The default API Umbrella website content comes from the [api-umbrella-static-site](https://github.com/NREL/api-umbrella-static-site) repository. This repository provides a [Middleman](https://middlemanapp.com) site that can be forked and customized. As a static site, this site will compile to static HTML files and can be hosted in a variety of simple locations (GitHub Pages, an S3 Bucket, or on the API Umbrella servers).

### Deployment

If you fork and customize the static site repository, you can then deploy it in a variety of ways. A few examples include:

- **External (GitHub Pages, S3 Bucket, etc):** You can deploy the resulting HTML files to these external locations, and then configure API Umbrella to point to these locations as you would any [external website backend](#external-website-backends). 
- **On the API Umbrella servers:** You'll need to configure your API Umbrella servers to allow for [deployments](../developer/deploying.html), then you'll need to adjust the deploy configuration in `config/deploy/production.rb` to point to your servers, and then you should be able to deploy via `cap production deploy`.

### Example Forks

Here are a couple examples of website repositories based on the api-umbrella-static-site repo, and deployed with GitHub Pages:

- [api.data.gov](https://github.com/18F/api.data.gov/)
- [developer.nrel.gov](https://github.com/NREL/developer.nrel.gov)
