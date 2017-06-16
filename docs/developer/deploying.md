# Deploying From Git

API Umbrella should be installed onto servers using the [binary packages](../getting-started.html#installation). However, if you want to deploy more recent updates from master (or your own forked changes), then newer versions of the app can be deployed on top of a package-based installation. Deployments are automated through [Capistrano](http://capistranorb.com).

## Prerequisites

In order to run the deployment scripts, your local computer (or wherever you're deploying from) must have:

- git
- rsync
- Ruby 1.9+
- Ruby Bundler

If you have trouble getting any of these setup locally, you can also run deployments from the [development virtual machine](dev-setup.html), which includes these dependencies.

## Initial Server Setup

### SSH Key Setup

On each server you wish to deploy to, you must setup SSH keys so that you can deploy as the `api-umbrella-deploy` user (this user is automatically created as part of the package installation). These steps only need to be performed once per server.

- On your computer:
  - Ensure you have SSH keys: You must have SSH keys setup on your local computer (or wherever you're deploying from). If you do not have SSH keys, see steps 1 & 2 from GitHub's [Generating SSH keys](https://help.github.com/articles/generating-ssh-keys/) guide for instructions.
  - Copy your public key: Copy the contents of your public key (often at `~/.ssh/id_rsa.pub`). For more tips on copying, or alternative locations for your public key, see step 4 from GitHub's [Generating SSH keys](https://help.github.com/articles/generating-ssh-keys/#step-4-add-your-ssh-key-to-your-account) guide.
- On each server:
  - With your public SSH key in hand from your own computer, follow these steps on each server, replacing `YOUR_PUBLIC_KEY` as appropriate:

    ```sh
    $ echo "YOUR_PUBLIC_KEY" | sudo tee --append /home/api-umbrella-deploy/.ssh/authorized_keys
    ```

### Install Build Dependencies

On each server you wish to deploy to, you must install the system packages needed for building dependencies (for example, make, gcc, etc). This can be automated through the `build/scripts/install_build_dependencies` shell script:

- On each server:

  ```sh
  $ curl -OLJ https://github.com/NREL/api-umbrella/archive/master.tar.gz
  $ tar -xvf api-umbrella-master.tar.gz
  $ cd api-umbrella-master
  $ sudo ./build/scripts/install_build_dependencies
  ```

## Deploying

- One-time local setup:
  - Check out the [api-umbrella](https://github.com/NREL/api-umbrella) repository from git:

    ```sh
    $ git clone https://github.com/NREL/api-umbrella.git
    ```

  - Install the deployment dependencies from inside the `deploy` directory:

    ```sh
    $ cd api-umbrella/deploy
    $ bundle install
    ```

  - Define your destination servers: Add a `.env` file inside the `api-umbrella/deploy` directory defining the servers to deploy to for the "staging" or "production" environments:

    ```
    API_UMBRELLA_STAGING_SERVERS="10.0.0.1,10.0.0.2"
    API_UMBRELLA_PRODUCTION_SERVERS="10.0.10.1,10.0.10.2"
    ```

    Servers can be defined using hostnames or IP address. Multiple servers can be comma-delimited. In this example there are two staging servers (`10.0.0.1` and `10.0.0.2`), and two production servers (`10.0.10.1` and `10.0.10.2`).

- Deploy to either the "staging" or "production" environments:

  ```sh
  $ cd api-umbrella/deploy
  $ bundle exec cap staging deploy
  $ bundle exec cap production deploy
  ```
