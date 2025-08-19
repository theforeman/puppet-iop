# Changelog

## [0.2.0](https://github.com/theforeman/puppet-iop/tree/0.2.0) (2025-08-19)

[Full Changelog](https://github.com/theforeman/puppet-iop/compare/0.1.0...0.2.0)

**Implemented enhancements:**

- Add a timer to cleanup inventory [\#52](https://github.com/theforeman/puppet-iop/pull/52) ([ehelms](https://github.com/ehelms))
- Add restart on-failure for quadlets [\#51](https://github.com/theforeman/puppet-iop/pull/51) ([ehelms](https://github.com/ehelms))
- Metadata downloader using curl [\#38](https://github.com/theforeman/puppet-iop/pull/38) ([ehelms](https://github.com/ehelms))

## [0.1.0](https://github.com/theforeman/puppet-iop/tree/0.1.0) (2025-08-07)

[Full Changelog](https://github.com/theforeman/puppet-iop/compare/920f3ee834c5e10486e08d938648158c72e35fc3...0.1.0)

**Merged pull requests:**

- Ensure iop\_advisor\_engine is removed [\#49](https://github.com/theforeman/puppet-iop/pull/49) ([ehelms](https://github.com/ehelms))
- Register by default [\#48](https://github.com/theforeman/puppet-iop/pull/48) ([ehelms](https://github.com/ehelms))
- Use secrets as environment variables for database configuration [\#47](https://github.com/theforeman/puppet-iop/pull/47) ([ehelms](https://github.com/ehelms))
- Add foreman\_base\_url parameter [\#46](https://github.com/theforeman/puppet-iop/pull/46) ([ehelms](https://github.com/ehelms))
- Allow Puppet 7 [\#45](https://github.com/theforeman/puppet-iop/pull/45) ([ehelms](https://github.com/ehelms))
- Fix insights-client --unregister [\#44](https://github.com/theforeman/puppet-iop/pull/44) ([dkuc](https://github.com/dkuc))
- Require at least puppet-certs 21.0.0 [\#43](https://github.com/theforeman/puppet-iop/pull/43) ([ehelms](https://github.com/ehelms))
- Ensure selinux context when copying frontend assets [\#42](https://github.com/theforeman/puppet-iop/pull/42) ([ehelms](https://github.com/ehelms))
- feat\(vuln\): configurable and disconnected taskomatic jobs [\#41](https://github.com/theforeman/puppet-iop/pull/41) ([vkrizan](https://github.com/vkrizan))
- Use podman volume for /var/lib/kafka [\#40](https://github.com/theforeman/puppet-iop/pull/40) ([ehelms](https://github.com/ehelms))
- Add inventory frontend [\#39](https://github.com/theforeman/puppet-iop/pull/39) ([ehelms](https://github.com/ehelms))
- Refactoring updates [\#37](https://github.com/theforeman/puppet-iop/pull/37) ([ehelms](https://github.com/ehelms))
- Handle oauth credentials the same as puppet-foreman\_proxy [\#36](https://github.com/theforeman/puppet-iop/pull/36) ([ehelms](https://github.com/ehelms))
- Update curl tests to check for 200 [\#35](https://github.com/theforeman/puppet-iop/pull/35) ([ehelms](https://github.com/ehelms))
- Add smart proxy [\#34](https://github.com/theforeman/puppet-iop/pull/34) ([ehelms](https://github.com/ehelms))
- Vmaas timer [\#33](https://github.com/theforeman/puppet-iop/pull/33) ([ehelms](https://github.com/ehelms))
- Add advisor services [\#31](https://github.com/theforeman/puppet-iop/pull/31) ([ehelms](https://github.com/ehelms))
- Ensure asserts/apps exists [\#30](https://github.com/theforeman/puppet-iop/pull/30) ([ehelms](https://github.com/ehelms))
- feat\(vmaas\): configure CVEMAP location [\#29](https://github.com/theforeman/puppet-iop/pull/29) ([vkrizan](https://github.com/vkrizan))
- Fix FDW access [\#28](https://github.com/theforeman/puppet-iop/pull/28) ([ehelms](https://github.com/ehelms))
- fix\(inventory\): fix view insights\_id column and condition [\#27](https://github.com/theforeman/puppet-iop/pull/27) ([vkrizan](https://github.com/vkrizan))
- fix: writable vmaas data volume [\#26](https://github.com/theforeman/puppet-iop/pull/26) ([vkrizan](https://github.com/vkrizan))
- Ensure mode of the frontend directory [\#24](https://github.com/theforeman/puppet-iop/pull/24) ([ehelms](https://github.com/ehelms))
- Fix assets directory for vulnerability frontend [\#23](https://github.com/theforeman/puppet-iop/pull/23) ([ehelms](https://github.com/ehelms))
- Enable vulnerability frontend [\#22](https://github.com/theforeman/puppet-iop/pull/22) ([ehelms](https://github.com/ehelms))
- feat\(vmaas\): use gateway for katello access [\#19](https://github.com/theforeman/puppet-iop/pull/19) ([vkrizan](https://github.com/vkrizan))
- feat\(gateway\): configure smart proxy relay [\#18](https://github.com/theforeman/puppet-iop/pull/18) ([vkrizan](https://github.com/vkrizan))
- Add vulns service to init [\#17](https://github.com/theforeman/puppet-iop/pull/17) ([ShimShtein](https://github.com/ShimShtein))
- fix: align naming convetion of hbi [\#16](https://github.com/theforeman/puppet-iop/pull/16) ([vkrizan](https://github.com/vkrizan))
- Add vulnerability [\#14](https://github.com/theforeman/puppet-iop/pull/14) ([ehelms](https://github.com/ehelms))
- feat: use shared nginx config from iop-gateway [\#13](https://github.com/theforeman/puppet-iop/pull/13) ([vkrizan](https://github.com/vkrizan))
- Add FDW for host inventory [\#12](https://github.com/theforeman/puppet-iop/pull/12) ([ehelms](https://github.com/ehelms))
- Update host inventory name in gateway config [\#11](https://github.com/theforeman/puppet-iop/pull/11) ([ehelms](https://github.com/ehelms))
- Drop need for createrole for vmaas [\#10](https://github.com/theforeman/puppet-iop/pull/10) ([ehelms](https://github.com/ehelms))
- Deploy vulnerability UI as static assets for Apache to serve [\#9](https://github.com/theforeman/puppet-iop/pull/9) ([ehelms](https://github.com/ehelms))
- Include vmaas in the base class [\#8](https://github.com/theforeman/puppet-iop/pull/8) ([ehelms](https://github.com/ehelms))
- Add vmaas [\#7](https://github.com/theforeman/puppet-iop/pull/7) ([ehelms](https://github.com/ehelms))
- Mount socket for Postgres to host inventory [\#6](https://github.com/theforeman/puppet-iop/pull/6) ([ehelms](https://github.com/ehelms))
- Make host inventory deployment work [\#5](https://github.com/theforeman/puppet-iop/pull/5) ([ehelms](https://github.com/ehelms))
- Add yuptoo [\#4](https://github.com/theforeman/puppet-iop/pull/4) ([ehelms](https://github.com/ehelms))
- Add engine ingress [\#3](https://github.com/theforeman/puppet-iop/pull/3) ([ehelms](https://github.com/ehelms))
- Add puptoo [\#2](https://github.com/theforeman/puppet-iop/pull/2) ([ehelms](https://github.com/ehelms))
- Add kafka spec tests and idempotent init [\#1](https://github.com/theforeman/puppet-iop/pull/1) ([ehelms](https://github.com/ehelms))



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
