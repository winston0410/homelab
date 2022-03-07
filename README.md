# My homelab configuration

My homelab configuration. Everything is reproducible with the help of Nix and NixOS.

## Deployment

```sh
# Single command to check, deploy and rollback if needed!
nix run github:serokell/deploy-rs
```

To deploy without rollback, do this:

```sh
deploy --magic-rollback false
```

## Tools used

[deploy-rs](https://github.com/serokell/deploy-rs)

[agenix](https://github.com/ryantm/agenix)

## Reference

Specific reference to providers

### Oracle Cloud

https://blogs.oracle.com/cloud-infrastructure/post/bring-your-domain-name-to-oracle-cloud-infrastructures-edge-services
