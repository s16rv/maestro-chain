# interchainauth
**interchainauth** is a blockchain built using Cosmos SDK and Tendermint and created with [Ignite CLI](https://ignite.com/cli).

## Get started

```
ignite chain serve
```

`serve` command installs dependencies, builds, initializes, and starts your blockchain in development.

### Configure

Your blockchain in development can be configured with `config.yml`. To learn more, see the [Ignite CLI docs](https://docs.ignite.com).

### Web Frontend

Ignite CLI has scaffolded a Vue.js-based web app in the `vue` directory. Run the following commands to install dependencies and start the app:

```
cd vue
npm install
npm run serve
```

The frontend app is built using the `@starport/vue` and `@starport/vuex` packages. For details, see the [monorepo for Ignite front-end development](https://github.com/ignite/web).

## Release
To release a new version of your blockchain, create and push a new tag with `v` prefix. A new draft release with the configured targets will be created.

```
git tag v0.1
git push origin v0.1
```

After a draft release is created, make your final changes from the release page and publish it.

### Install
To install the latest version of your blockchain node's binary, execute the following command on your machine:

```
curl https://get.ignite.com/username/interchain-auth@latest! | sudo bash
```
`username/interchain-auth` should match the `username` and `repo_name` of the Github repository to which the source code was pushed. Learn more about [the install process](https://github.com/allinbits/starport-installer).

### For Contributor
First time setup will consist of:

1. Install docker or docker desktop. If not you will get these messages and can’t proceed with the testing.
    
    ```go
    Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
    ```
2. Since our project use private repository use your preferred method to allow private repository when executing go get or go mod operation, the author use `go env -w GOPRIVATE=github.com/s16rv/maestro-chain`
3. Execute `make get-heighliner`

A typical e2e test consist of:

1. Dev make changes to the code.
2. Dev make or adjust e2e test file for the new changes.
3. Dev runs `make local-image` -> builds current iteration of chain inside the docker image
4. Dev runs `make test-the-thing` -> runs test using new image
5. Ensure all test passed.
6. Development is done, code pushed, PR created, Attached proof of test passed.
7. Ask for review/approval. Go to first step if there are code review or feedback. If not continue to next step.
8. If all reviewer approve, merge.

## Learn more

- [Ignite CLI](https://ignite.com/cli)
- [Tutorials](https://docs.ignite.com/guide)
- [Ignite CLI docs](https://docs.ignite.com)
- [Cosmos SDK docs](https://docs.cosmos.network)
- [Developer Chat](https://discord.gg/ignite)
